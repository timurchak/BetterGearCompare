#!/usr/bin/env python3
"""Generate reproducible stat-budget/distribution samples for the SimC spike."""

from __future__ import annotations

import csv
import json
import math
import pathlib

import numpy as np


ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "fixtures" / "simc"
CSV_PATH = OUT_DIR / "samples.csv"
META_PATH = OUT_DIR / "samples-metadata.json"
SEED = 20260905
COUNTS = {"train": 400, "validation": 128, "test": 160}
EXTRAPOLATION_COUNT = 32
PRIMARY_RANGE = (1600, 2300)
SECONDARY_BUDGET_RANGE = (2600, 3900)
STAT_NAMES = ("crit", "haste", "mastery", "versatility")


def latin_hypercube(rng: np.random.Generator, n: int, dimensions: int) -> np.ndarray:
    result = np.empty((n, dimensions), dtype=float)
    for dimension in range(dimensions):
        order = rng.permutation(n)
        result[:, dimension] = (order + rng.random(n)) / n
    return result


def in_domain_samples(rng: np.random.Generator, split: str, count: int) -> list[dict]:
    lhs = latin_hypercube(rng, count, 6)
    rows = []
    for index, unit in enumerate(lhs):
        primary = round(PRIMARY_RANGE[0] + unit[0] * (PRIMARY_RANGE[1] - PRIMARY_RANGE[0]))
        budget = round(
            SECONDARY_BUDGET_RANGE[0]
            + unit[1] * (SECONDARY_BUDGET_RANGE[1] - SECONDARY_BUDGET_RANGE[0])
        )

        raw = -np.log(np.clip(unit[2:6], 1e-9, 1.0))
        shares = raw / raw.sum()
        sample_kind = "lhs"

        # Deliberately place 12.5% of each split near one-stat concentration/DR regions.
        if index % 8 == 0:
            dominant = (index // 8) % 4
            dominant_share = 0.68 + 0.17 * unit[2 + dominant]
            remainder = 1.0 - dominant_share
            other = np.array([unit[2 + j] + 0.1 for j in range(4) if j != dominant])
            other = remainder * other / other.sum()
            shares = np.empty(4)
            shares[dominant] = dominant_share
            shares[[j for j in range(4) if j != dominant]] = other
            sample_kind = f"dr-edge-{STAT_NAMES[dominant]}"

        ratings = np.floor(shares * budget).astype(int)
        ratings[np.argmax(shares)] += budget - int(ratings.sum())
        row = {
            "sample_id": f"{split}-{index:04d}",
            "split": split,
            "sample_kind": sample_kind,
            "primary": primary,
            **{name: int(value) for name, value in zip(STAT_NAMES, ratings)},
            "total_secondary": int(ratings.sum()),
        }
        rows.append(row)
    return rows


def extrapolation_samples(rng: np.random.Generator, count: int) -> list[dict]:
    rows = []
    for index in range(count):
        side = index % 4
        if side == 0:
            primary = round(rng.uniform(1350, 1525))
            budget = round(rng.uniform(*SECONDARY_BUDGET_RANGE))
            kind = "outside-primary-low"
        elif side == 1:
            primary = round(rng.uniform(2375, 2550))
            budget = round(rng.uniform(*SECONDARY_BUDGET_RANGE))
            kind = "outside-primary-high"
        elif side == 2:
            primary = round(rng.uniform(*PRIMARY_RANGE))
            budget = round(rng.uniform(2200, 2500))
            kind = "outside-budget-low"
        else:
            primary = round(rng.uniform(*PRIMARY_RANGE))
            budget = round(rng.uniform(4050, 4400))
            kind = "outside-budget-high"

        shares = rng.dirichlet(np.full(4, 0.8))
        if index % 5 == 0:
            dominant = index % 4
            shares = np.full(4, 0.025)
            shares[dominant] = 0.925
            kind += f"-extreme-{STAT_NAMES[dominant]}"
        ratings = np.floor(shares * budget).astype(int)
        ratings[np.argmax(shares)] += budget - int(ratings.sum())
        rows.append(
            {
                "sample_id": f"test-extra-{index:04d}",
                "split": "test",
                "sample_kind": kind,
                "primary": primary,
                **{name: int(value) for name, value in zip(STAT_NAMES, ratings)},
                "total_secondary": int(ratings.sum()),
            }
        )
    return rows


def main() -> int:
    rng = np.random.default_rng(SEED)
    rows: list[dict] = []
    for split, count in COUNTS.items():
        rows.extend(in_domain_samples(rng, split, count))
    rows.extend(extrapolation_samples(rng, EXTRAPOLATION_COUNT))

    seen = set()
    for row in rows:
        key = tuple(row[name] for name in ("primary", *STAT_NAMES))
        if key in seen:
            raise RuntimeError(f"duplicate stat point: {key}")
        seen.add(key)
        if row["total_secondary"] != sum(row[name] for name in STAT_NAMES):
            raise RuntimeError("secondary budget mismatch")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    fields = [
        "sample_id",
        "split",
        "sample_kind",
        "primary",
        *STAT_NAMES,
        "total_secondary",
    ]
    with CSV_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    metadata = {
        "schema": 1,
        "seed": SEED,
        "strategy": "Latin hypercube over primary/secondary budget plus transformed four-stat simplex; explicit DR-edge and held-out extrapolation points",
        "counts": {
            "train": COUNTS["train"],
            "validation": COUNTS["validation"],
            "testInDomain": COUNTS["test"],
            "testExtrapolation": EXTRAPOLATION_COUNT,
            "total": len(rows),
        },
        "domain": {
            "primary": list(PRIMARY_RANGE),
            "totalSecondary": list(SECONDARY_BUDGET_RANGE),
            "individualSecondary": [0, SECONDARY_BUDGET_RANGE[1]],
        },
        "notes": [
            "Ratings are whole numbers and exactly sum to total_secondary.",
            "The weapon, items, effects, talents, race, APL, and encounter remain fixed by the pinned SimC profile.",
            "Extrapolation samples are never used for fit or hyperparameter choice.",
        ],
    }
    META_PATH.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"PASS samples: {CSV_PATH}")
    print(json.dumps(metadata["counts"], indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

