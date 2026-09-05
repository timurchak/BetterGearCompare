#!/usr/bin/env python3
"""Fit and benchmark five surrogate families on held-out SimC states."""

from __future__ import annotations

import csv
import itertools
import json
import math
import pathlib
import statistics
import time
from dataclasses import dataclass
from typing import Callable

import numpy as np


ROOT = pathlib.Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "fixtures" / "simc"
INPUT = FIXTURES / "simc-states.csv"
SAMPLE_META = FIXTURES / "samples-metadata.json"
REPORT_PATH = FIXTURES / "model-benchmark.json"
PAIR_PATH = FIXTURES / "heldout-pairs.csv"
LUA_PATH = FIXTURES / "model-piecewise.lua"
FEATURE_NAMES = ("primary", "crit", "haste", "mastery", "versatility")
RIDGES = (0.0, 1e-8, 1e-6, 1e-4, 1e-2, 1e-1)
MATERIALITY_PP = 0.5


@dataclass
class Dataset:
    ids: np.ndarray
    split: np.ndarray
    kind: np.ndarray
    x: np.ndarray
    secondary: np.ndarray
    dps: np.ndarray
    sim_error: np.ndarray


def load_dataset() -> Dataset:
    with INPUT.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return Dataset(
        ids=np.array([row["sample_id"] for row in rows]),
        split=np.array([row["split"] for row in rows]),
        kind=np.array([row["sample_kind"] for row in rows]),
        x=np.array([[float(row[name]) for name in FEATURE_NAMES] for row in rows]),
        secondary=np.array([float(row["total_secondary"]) for row in rows]),
        dps=np.array([float(row["simc_dps"]) for row in rows]),
        sim_error=np.array([float(row["simc_relative_mean_error"]) for row in rows]),
    )


def ridge_fit(design: np.ndarray, target: np.ndarray, ridge: float) -> np.ndarray:
    penalty = np.eye(design.shape[1]) * ridge
    penalty[0, 0] = 0.0
    return np.linalg.solve(design.T @ design + penalty, design.T @ target)


def choose_ridge(
    train_design: np.ndarray,
    train_y: np.ndarray,
    validation_design: np.ndarray,
    validation_y: np.ndarray,
) -> tuple[np.ndarray, float, float]:
    candidates = []
    for ridge in RIDGES:
        try:
            coefficients = ridge_fit(train_design, train_y, ridge)
        except np.linalg.LinAlgError:
            continue
        mse = float(np.mean((validation_design @ coefficients - validation_y) ** 2))
        candidates.append((mse, ridge, coefficients))
    if not candidates:
        raise RuntimeError("no ridge candidate could be fit")
    mse, ridge, coefficients = min(candidates, key=lambda row: row[0])
    return coefficients, ridge, mse


def linear_design(x: np.ndarray) -> np.ndarray:
    return np.column_stack((np.ones(len(x)), x))


def polynomial_design(x: np.ndarray) -> np.ndarray:
    columns = [np.ones(len(x))]
    columns.extend(x[:, index] for index in range(x.shape[1]))
    columns.extend(
        x[:, left] * x[:, right]
        for left in range(x.shape[1])
        for right in range(left, x.shape[1])
    )
    return np.column_stack(columns)


def piecewise_knots(train_x: np.ndarray) -> np.ndarray:
    return np.quantile(train_x, [0.2, 0.4, 0.6, 0.8], axis=0).T


def piecewise_design(x: np.ndarray, knots: np.ndarray) -> np.ndarray:
    columns = [np.ones(len(x))]
    for dimension in range(x.shape[1]):
        columns.append(x[:, dimension])
        columns.extend(np.maximum(0.0, x[:, dimension] - knot) for knot in knots[dimension])
    interaction = []
    for dimension in range(x.shape[1]):
        interaction.append(
            np.column_stack(
                (
                    x[:, dimension],
                    np.maximum(0.0, x[:, dimension] - knots[dimension, 1]),
                    np.maximum(0.0, x[:, dimension] - knots[dimension, 3]),
                )
            )
        )
    columns.extend(
        interaction[left][:, left_basis] * interaction[right][:, right_basis]
        for left in range(x.shape[1])
        for right in range(left + 1, x.shape[1])
        for left_basis in range(3)
        for right_basis in range(3)
    )
    return np.column_stack(columns)


def local_linear_predict(
    train_x: np.ndarray,
    train_y: np.ndarray,
    query_x: np.ndarray,
    neighbors: int,
) -> np.ndarray:
    predictions = []
    for query in query_x:
        distances = np.linalg.norm(train_x - query, axis=1)
        indices = np.argpartition(distances, neighbors)[:neighbors]
        local_x = train_x[indices] - query
        bandwidth = max(float(np.max(distances[indices])), 1e-6)
        weights = np.exp(-((distances[indices] / bandwidth) ** 2))
        design = np.column_stack((np.ones(neighbors), local_x))
        weighted_design = design * np.sqrt(weights[:, None])
        weighted_target = train_y[indices] * np.sqrt(weights)
        coefficients = ridge_fit(weighted_design, weighted_target, 1e-4)
        predictions.append(coefficients[0])
    return np.array(predictions)


def knn_predict(
    train_x: np.ndarray,
    train_y: np.ndarray,
    query_x: np.ndarray,
    neighbors: int,
    power: int,
) -> np.ndarray:
    predictions = []
    for query in query_x:
        distances = np.linalg.norm(train_x - query, axis=1)
        indices = np.argpartition(distances, neighbors)[:neighbors]
        selected = np.maximum(distances[indices], 1e-8)
        weights = 1.0 / selected**power
        predictions.append(float(np.sum(weights * train_y[indices]) / np.sum(weights)))
    return np.array(predictions)


def choose_local(
    train_x: np.ndarray,
    train_y: np.ndarray,
    validation_x: np.ndarray,
    validation_y: np.ndarray,
) -> tuple[int, float]:
    candidates = []
    for neighbors in (24, 40, 64, 96):
        predicted = local_linear_predict(train_x, train_y, validation_x, neighbors)
        candidates.append((float(np.mean((predicted - validation_y) ** 2)), neighbors))
    mse, neighbors = min(candidates)
    return neighbors, mse


def choose_knn(
    train_x: np.ndarray,
    train_y: np.ndarray,
    validation_x: np.ndarray,
    validation_y: np.ndarray,
) -> tuple[int, int, float]:
    candidates = []
    for neighbors in (4, 8, 16, 24, 32):
        for power in (1, 2, 3):
            predicted = knn_predict(train_x, train_y, validation_x, neighbors, power)
            candidates.append(
                (float(np.mean((predicted - validation_y) ** 2)), neighbors, power)
            )
    mse, neighbors, power = min(candidates)
    return neighbors, power, mse


def pair_indices(
    x: np.ndarray, secondary: np.ndarray, minimum_pairs: int
) -> np.ndarray:
    pairs = []
    for left, right in itertools.combinations(range(len(x)), 2):
        if abs(x[left, 0] - x[right, 0]) > 250:
            continue
        if abs(secondary[left] - secondary[right]) > 500:
            continue
        # Moving 1,100 rating from one secondary to another has L1 distance 2,200.
        # This upper bound admits a large two-slot-like redistribution while the
        # primary and total-budget limits keep the pair in ordinary replacement scale.
        if np.sum(np.abs(x[left, 1:] - x[right, 1:])) > 2200:
            continue
        pairs.append((left, right))
    if len(pairs) < minimum_pairs:
        raise RuntimeError(
            f"only {len(pairs)} item-like pairs generated; required {minimum_pairs}"
        )
    return np.array(pairs, dtype=int)


def pair_deltas(log_values: np.ndarray, pairs: np.ndarray) -> np.ndarray:
    return np.expm1(log_values[pairs[:, 1]] - log_values[pairs[:, 0]]) * 100.0


def sign_accuracy(true: np.ndarray, predicted: np.ndarray, threshold: float) -> float | None:
    mask = np.abs(true) >= threshold
    if not np.any(mask):
        return None
    return float(np.mean(np.sign(true[mask]) == np.sign(predicted[mask])))


def model_metrics(
    true_log: np.ndarray,
    predicted_log: np.ndarray,
    pairs: np.ndarray,
    uncertainty_pp: float,
) -> tuple[dict, np.ndarray, np.ndarray]:
    truth = pair_deltas(true_log, pairs)
    predicted = pair_deltas(predicted_log, pairs)
    error = predicted - truth
    absolute = np.abs(error)
    near = np.abs(truth) < 0.5
    weights = np.where(np.abs(truth) < 0.5, 4.0, np.where(np.abs(truth) < 1.0, 2.0, 1.0))
    sign_equal = np.sign(truth) == np.sign(predicted)

    confident_up = predicted - uncertainty_pp > MATERIALITY_PP
    confident_down = predicted + uncertainty_pp < -MATERIALITY_PP
    confident = confident_up | confident_down
    confident_correct = np.sign(truth[confident]) == np.sign(predicted[confident])
    false_positive_up = confident_up & (truth <= 0)
    false_negative_down = confident_down & (truth >= 0)
    interval_overlaps_zero = confident & (
        (predicted - uncertainty_pp <= 0.0)
        & (predicted + uncertainty_pp >= 0.0)
    )
    interval_violates_materiality = (
        confident_up & (predicted - uncertainty_pp <= MATERIALITY_PP)
    ) | (
        confident_down & (predicted + uncertainty_pp >= -MATERIALITY_PP)
    )

    return {
        "pairs": int(len(pairs)),
        "medianAbsoluteDeltaErrorPP": float(np.median(absolute)),
        "p95AbsoluteDeltaErrorPP": float(np.quantile(absolute, 0.95)),
        "maxAbsoluteDeltaErrorPP": float(np.max(absolute)),
        "meanAbsoluteDeltaErrorNearZeroPP": float(np.mean(absolute[near])) if np.any(near) else None,
        "nearZeroPairs": int(np.sum(near)),
        "winnerAgreementAll": float(np.mean(sign_equal)),
        "winnerAgreementWeightedNearEqual": float(np.average(sign_equal, weights=weights)),
        "winnerAgreementTrueGT1PP": sign_accuracy(truth, predicted, 1.0),
        "winnerAgreementTrueGT0_5PP": sign_accuracy(truth, predicted, 0.5),
        "uncertaintyPP": uncertainty_pp,
        "confidentRecommendations": int(np.sum(confident)),
        "confidentCoverage": float(np.mean(confident)),
        "confidentWinnerAgreement": float(np.mean(confident_correct)) if np.any(confident) else None,
        "confidentFalsePositiveUpgrades": int(np.sum(false_positive_up)),
        "confidentFalsePositiveUpgradeRate": float(np.sum(false_positive_up) / max(np.sum(confident_up), 1)),
        "confidentFalseNegativeUpgrades": int(np.sum(false_negative_down)),
        "confidentFalseNegativeUpgradeRate": float(np.sum(false_negative_down) / max(np.sum(confident_down), 1)),
        "abstentionRate": float(1.0 - np.mean(confident)),
        "intervalPolicyOverlapsZero": int(np.sum(interval_overlaps_zero)),
        "intervalPolicyViolatesMateriality": int(np.sum(interval_violates_materiality)),
    }, truth, predicted


def lua_number(value: float) -> str:
    return format(float(value), ".17g")


def lua_array(values: np.ndarray | list[float]) -> str:
    return "{" + ",".join(lua_number(value) for value in values) + "}"


def make_lua_payload(
    mean: np.ndarray,
    scale: np.ndarray,
    knots: np.ndarray,
    coefficients: np.ndarray,
    domain: dict,
) -> str:
    return f'''-- Generated Phase 0 evidence. Not production addon data.
local Model = {{
  schema = 1,
  featureNames = {{"primary","crit","haste","mastery","versatility"}},
  mean = {lua_array(mean)},
  scale = {lua_array(scale)},
  knots = {{
    {lua_array(knots[0])},
    {lua_array(knots[1])},
    {lua_array(knots[2])},
    {lua_array(knots[3])},
    {lua_array(knots[4])},
  }},
  coefficients = {lua_array(coefficients)},
  primaryMin = {domain['primary'][0]},
  primaryMax = {domain['primary'][1]},
  secondaryBudgetMin = {domain['totalSecondary'][0]},
  secondaryBudgetMax = {domain['totalSecondary'][1]},
}}

function Model:Evaluate(primary, crit, haste, mastery, versatility)
  local budget = crit + haste + mastery + versatility
  if primary < self.primaryMin or primary > self.primaryMax
      or budget < self.secondaryBudgetMin or budget > self.secondaryBudgetMax
      or crit < 0 or haste < 0 or mastery < 0 or versatility < 0 then
    return nil, "OUT_OF_DOMAIN"
  end
  local input = {{primary, crit, haste, mastery, versatility}}
  local normalized = {{}}
  for index = 1, 5 do
    normalized[index] = (input[index] - self.mean[index]) / self.scale[index]
  end
  local coefficientIndex = 1
  local value = self.coefficients[coefficientIndex]
  coefficientIndex = coefficientIndex + 1
  for dimension = 1, 5 do
    local x = normalized[dimension]
    value = value + self.coefficients[coefficientIndex] * x
    coefficientIndex = coefficientIndex + 1
    for knotIndex = 1, 4 do
      local hinge = math.max(0, x - self.knots[dimension][knotIndex])
      value = value + self.coefficients[coefficientIndex] * hinge
      coefficientIndex = coefficientIndex + 1
    end
  end
  local interaction = {{}}
  for dimension = 1, 5 do
    local x = normalized[dimension]
    interaction[dimension] = {{
      x,
      math.max(0, x - self.knots[dimension][2]),
      math.max(0, x - self.knots[dimension][4]),
    }}
  end
  for left = 1, 5 do
    for right = left + 1, 5 do
      for leftBasis = 1, 3 do
        for rightBasis = 1, 3 do
          value = value + self.coefficients[coefficientIndex]
              * interaction[left][leftBasis] * interaction[right][rightBasis]
          coefficientIndex = coefficientIndex + 1
        end
      end
    end
  end
  return value
end

return Model
'''


def main() -> int:
    data = load_dataset()
    sample_meta = json.loads(SAMPLE_META.read_text(encoding="utf-8"))
    train_mask = data.split == "train"
    validation_mask = data.split == "validation"
    test_mask = data.split == "test"
    extra_mask = np.char.startswith(data.kind.astype(str), "outside-")
    test_in_mask = test_mask & ~extra_mask
    test_extra_mask = test_mask & extra_mask

    mean = data.x[train_mask].mean(axis=0)
    scale = data.x[train_mask].std(axis=0)
    normalized = (data.x - mean) / scale
    target = np.log(data.dps)
    train_x, train_y = normalized[train_mask], target[train_mask]
    validation_x, validation_y = normalized[validation_mask], target[validation_mask]
    test_x, test_y = normalized[test_in_mask], target[test_in_mask]

    models: dict[str, dict] = {}

    for name, design_fn in (
        ("fixed-linear-weights", linear_design),
        ("quadratic-polynomial", polynomial_design),
    ):
        coefficient, ridge, mse = choose_ridge(
            design_fn(train_x), train_y, design_fn(validation_x), validation_y
        )
        models[name] = {
            "predict": lambda values, fn=design_fn, coef=coefficient: fn(values) @ coef,
            "validationMSELog": mse,
            "hyperparameters": {"ridge": ridge},
            "storedNumbers": int(len(coefficient) + len(mean) + len(scale)),
            "coefficients": coefficient,
        }

    knots = piecewise_knots(train_x)
    piece_coefficient, piece_ridge, piece_mse = choose_ridge(
        piecewise_design(train_x, knots),
        train_y,
        piecewise_design(validation_x, knots),
        validation_y,
    )
    models["piecewise-additive-interaction-grids"] = {
        "predict": lambda values: piecewise_design(values, knots) @ piece_coefficient,
        "validationMSELog": piece_mse,
        "hyperparameters": {
            "ridge": piece_ridge,
            "knotsPerFeature": 4,
            "pairInteractions": 10,
            "basisTermsPerInteraction": 9,
        },
        "storedNumbers": int(len(piece_coefficient) + knots.size + len(mean) + len(scale)),
        "coefficients": piece_coefficient,
    }

    local_neighbors, local_mse = choose_local(train_x, train_y, validation_x, validation_y)
    models["local-dynamic-weights"] = {
        "predict": lambda values: local_linear_predict(train_x, train_y, values, local_neighbors),
        "validationMSELog": local_mse,
        "hyperparameters": {"neighbors": local_neighbors, "ridge": 1e-4},
        "storedNumbers": int(train_x.size + train_y.size + len(mean) + len(scale)),
    }

    knn_neighbors, knn_power, knn_mse = choose_knn(
        train_x, train_y, validation_x, validation_y
    )
    models["inverse-distance-lookup"] = {
        "predict": lambda values: knn_predict(train_x, train_y, values, knn_neighbors, knn_power),
        "validationMSELog": knn_mse,
        "hyperparameters": {"neighbors": knn_neighbors, "distancePower": knn_power},
        "storedNumbers": int(train_x.size + train_y.size + len(mean) + len(scale)),
    }

    validation_pairs = pair_indices(
        data.x[validation_mask], data.secondary[validation_mask], 500
    )
    test_pairs = pair_indices(
        data.x[test_in_mask], data.secondary[test_in_mask], 1000
    )
    validation_true_log = validation_y
    test_true_log = test_y

    summary = {}
    pair_outputs = {}
    for name, model in models.items():
        validation_prediction = model["predict"](validation_x)
        validation_truth_delta = pair_deltas(validation_true_log, validation_pairs)
        validation_pred_delta = pair_deltas(validation_prediction, validation_pairs)
        validation_pair_error = np.abs(validation_pred_delta - validation_truth_delta)
        surrogate_p95 = float(np.quantile(validation_pair_error, 0.95))

        test_prediction = model["predict"](test_x)
        test_indices_global = np.flatnonzero(test_in_mask)
        sim_relative_errors = data.sim_error[test_indices_global]
        pair_sim_pp = (
            np.sqrt(
                sim_relative_errors[test_pairs[:, 0]] ** 2
                + sim_relative_errors[test_pairs[:, 1]] ** 2
            )
            * 100.0
        )
        sim_error_p95 = float(np.quantile(pair_sim_pp, 0.95))
        uncertainty_pp = surrogate_p95 + sim_error_p95
        metrics, truth_delta, predicted_delta = model_metrics(
            test_true_log, test_prediction, test_pairs, uncertainty_pp
        )

        extra_prediction = model["predict"](normalized[test_extra_mask])
        extra_absolute_dps_error = np.abs(np.expm1(extra_prediction - target[test_extra_mask])) * 100.0
        metrics["extrapolationRawMedianDpsErrorPercent"] = float(np.median(extra_absolute_dps_error))
        metrics["extrapolationRawMaxDpsErrorPercent"] = float(np.max(extra_absolute_dps_error))
        metrics["extrapolationGuardRecommendedCoverage"] = 0.0
        metrics["validationSurrogateP95PP"] = surrogate_p95
        metrics["heldoutSimPairErrorP95PP"] = sim_error_p95
        metrics["stateLogRMSE"] = float(np.sqrt(np.mean((test_prediction - test_true_log) ** 2)))
        summary[name] = {
            "family": name,
            "validationMSELog": model["validationMSELog"],
            "hyperparameters": model["hyperparameters"],
            "storedNumbers": model["storedNumbers"],
            "estimatedBinaryBytes64": model["storedNumbers"] * 8,
            "heldout": metrics,
        }
        pair_outputs[name] = predicted_delta

    compact_candidates = (
        "quadratic-polynomial",
        "piecewise-additive-interaction-grids",
    )
    recommended = max(
        compact_candidates,
        key=lambda name: (
            summary[name]["heldout"]["winnerAgreementTrueGT0_5PP"],
            -summary[name]["heldout"]["p95AbsoluteDeltaErrorPP"],
        ),
    )

    domain = sample_meta["domain"]
    lua_payload = make_lua_payload(mean, scale, knots, piece_coefficient, domain)
    LUA_PATH.write_text(lua_payload, encoding="utf-8")
    summary["piecewise-additive-interaction-grids"]["luaPayloadBytes"] = len(lua_payload.encode("utf-8"))

    sample = data.x[test_in_mask][0]
    normalized_sample = (sample - mean) / scale
    started = time.perf_counter()
    repeats = 10_000
    for _ in range(repeats):
        piecewise_design(normalized_sample.reshape(1, -1), knots) @ piece_coefficient
    runtime_seconds = time.perf_counter() - started
    summary["piecewise-additive-interaction-grids"]["pythonScalarEvaluationMicroseconds"] = runtime_seconds / repeats * 1e6

    truth = pair_deltas(test_true_log, test_pairs)
    with PAIR_PATH.open("w", newline="", encoding="utf-8") as handle:
        fields = ["left_id", "right_id", "true_delta_pp", *compact_candidates]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        test_ids = data.ids[test_in_mask]
        for index, (left, right) in enumerate(test_pairs):
            writer.writerow(
                {
                    "left_id": test_ids[left],
                    "right_id": test_ids[right],
                    "true_delta_pp": truth[index],
                    **{name: pair_outputs[name][index] for name in compact_candidates},
                }
            )

    chosen = summary[recommended]["heldout"]
    gates = {
        "winnerAgreementTrueGT1PP": chosen["winnerAgreementTrueGT1PP"] is not None and chosen["winnerAgreementTrueGT1PP"] > 0.99,
        "winnerAgreementTrueGT0_5PP": chosen["winnerAgreementTrueGT0_5PP"] is not None and chosen["winnerAgreementTrueGT0_5PP"] > 0.97,
        "confidentFalsePositiveUpgradeRateLTE0_5Pct": chosen["confidentFalsePositiveUpgradeRate"] <= 0.005,
        "confidentFalseNegativeUpgradeRateLTE0_5Pct": chosen["confidentFalseNegativeUpgradeRate"] <= 0.005,
        "noRecommendationWhenIntervalOverlapsZero": chosen["intervalPolicyOverlapsZero"] == 0,
        "noRecommendationWhenIntervalViolatesMateriality": chosen["intervalPolicyViolatesMateriality"] == 0,
        "compactFootprintUnder32KiB": summary[recommended]["estimatedBinaryBytes64"] < 32768,
        "outOfDomainFailClosedPolicy": chosen["extrapolationGuardRecommendedCoverage"] == 0.0,
    }
    verdict = "PASS" if all(gates.values()) else "FAIL"
    report = {
        "schema": 1,
        "verdict": verdict,
        "recommendedCompactFamily": recommended,
        "selectionRule": "Among polynomial and piecewise compact models: highest held-out >0.5pp winner agreement, then lowest p95 delta error. Local/KNN are challengers but retain the training dataset at runtime.",
        "materialityPP": MATERIALITY_PP,
        "samples": {
            "train": int(np.sum(train_mask)),
            "validation": int(np.sum(validation_mask)),
            "testInDomain": int(np.sum(test_in_mask)),
            "testExtrapolation": int(np.sum(test_extra_mask)),
        },
        "heldoutItemLikePairs": int(len(test_pairs)),
        "validationItemLikePairs": int(len(validation_pairs)),
        "models": summary,
        "gates": gates,
        "limitations": [
            "One spec, one talent profile, one 300-second +/-20% single-target profile.",
            "Weapon, special items, set bonuses, consumables, and all other profile context remain fixed.",
            "Simulation uncertainty is estimated from SimC mean_error and added to validation residual P95.",
            "A live Lua timing result is separate; Python scalar timing is diagnostic only.",
        ],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
