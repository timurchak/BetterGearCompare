# Spike B — offline SimulationCraft surrogate

**Verdict: PASS for the narrow hypothesis; no claim of general spec coverage.** A compact deterministic model can reproduce ordinary non-weapon stat decisions for one pinned spec/build/profile closely enough to drive an abstention-first advisor. This does not validate weapons, special effects, other talents, other encounter profiles, or other specs.

## Reproducible target

| Property | Value |
|---|---|
| Spec | Retribution Paladin |
| Profile | `profiles/MID2/MID2_Paladin_Retribution.simc`, actor `MID2_Paladin_Retribution_Herald` |
| Scenario | Patchwerk single target, 300 seconds, ±20% fight length |
| SimC | `SimulationCraft 1210-01`, WoW `12.1.0.69587` |
| Commit | [`aa9de89aac3dd5ead4976db1f091483f462687b4`](https://github.com/simulationcraft/simc/commit/aa9de89aac3dd5ead4976db1f091483f462687b4) |
| Profile SHA-256 | `864e857c5d8cdbaa5b03939f077fcb657a4784aa` |
| Seed | `20260905` |
| Sim threads | 8 |

Retribution was selected because the current Midnight branch contains a maintained MID2 profile and complete class model, while the experiment can hold its two-handed weapon, talents, APL, tier, and effects constant and isolate normal primary/secondary-stat response. SimulationCraft's own project describes why closed-form calculators lose accuracy under interacting combat modifiers ([official repository](https://github.com/simulationcraft/simc)). The selected profile is an archetype, not “the Ret model.”

Pinning is enforced by [`simc.lock.json`](tools/simc/simc.lock.json); [`run_simc.py`](tools/simc/run_simc.py) rejects a different commit/build/profile hash. Full run identity and wall times are in [`simc-run-metadata.json`](fixtures/simc/simc-run-metadata.json).

## Dataset and decision construction

[`generate_samples.py`](tools/simc/generate_samples.py) creates 720 whole-rating states using Latin hypercube sampling over primary stat and total secondary budget, then a transformed four-stat simplex. It includes explicit concentrated/DR-edge distributions and 32 deliberately out-of-domain states.

| Split | States | Sim iterations/state | Use |
|---|---:|---:|---|
| Train | 400 | 400 | Fit coefficients/data models |
| Validation | 128 | 400 | Select ridge, neighbors, and residual envelope |
| Held-out in-domain | 160 | 2,000 | Final decision metrics only |
| Held-out extrapolation | 32 | 2,000 | Raw diagnostic error; recommendation coverage forced to zero |

In-domain ranges are primary 1,600–2,300 and total secondary 2,600–3,900. Weapons, talents, race, APL, items/effects, and encounter configuration are fixed. Inputs and split labels are in [`samples.csv`](fixtures/simc/samples.csv); SimC results and mean errors are in [`simc-states.csv`](fixtures/simc/simc-states.csv).

Pairs are generated without looking at model results. They permit primary differences up to 250, total-secondary budget differences up to 500, and secondary L1 movement up to 2,200 rating (equivalent to moving at most 1,100 from one secondary to another). This produced 896 validation and 1,336 completely held-out item-like pairs. Pairs and predictions are preserved in [`heldout-pairs.csv`](fixtures/simc/heldout-pairs.csv).

## Compared models

[`benchmark_models.py`](tools/simc/benchmark_models.py) compares five families on the same states and pairs:

1. one global affine/fixed-weight model;
2. K-nearest local affine fits (“dynamic weights”);
3. a global quadratic response surface;
4. an additive four-knot hinge model with compact 3×3 pairwise interaction grids;
5. inverse-distance KNN interpolation.

The response is `log(DPS)`, so score differences convert naturally to percentage differences. Models are selected on validation only; the held-out split is reported once. Near-zero pairs receive 4× weight under 0.5 points and 2× under 1 point for the weighted diagnostic, though the declared gates use explicit true-difference bands.

## Held-out result

All deltas below are percentage-point errors in the predicted relative difference.

| Family | >1 pp winner | >0.5 pp winner | Median error | P95 error | Near-zero MAE | Confidence coverage | Confident FP/FN | Stored doubles |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Fixed linear | 84.00% | 82.15% | 2.370 | 6.853 | 1.866 | 9.88% | 0 / 0 | 16 |
| Local affine | 98.20% | 97.45% | 0.475 | 2.086 | 0.731 | 69.09% | 1 / 1 | 2,410 |
| Quadratic | 98.20% | 96.81% | 0.556 | 2.073 | 0.724 | 67.29% | 0 / 1 | 31 |
| **Piecewise interaction grid** | **99.49%** | **98.88%** | **0.398** | **1.300** | **0.478** | **74.63%** | **0 / 0** | **146** |
| Inverse-distance lookup | 76.39% | 74.66% | 3.157 | 9.129 | 2.692 | 6.14% | 0 / 1 | 2,410 |

Canonical machine results are in [`model-benchmark.json`](fixtures/simc/model-benchmark.json). “FP” means confidently saying upgrade when SimC says non-upgrade; “FN” means confidently saying downgrade when SimC says upgrade. Abstention is intentional and not counted as an incorrect recommendation.

The global fixed-weight baseline is decisively inadequate. Local weights improve ranking but require the training cloud at runtime and still underperform the compact grid. A simple polynomial also misses the >0.5-point gate. The selected piecewise interaction-grid model passes every declared gate:

- >99% agreement where the true difference exceeds 1 point;
- >97% agreement where it exceeds 0.5 points;
- ≤0.5% confident false-positive and false-negative rates (both observed zero);
- zero recommendations when the uncertainty interval overlaps the materiality boundary;
- under 32 KiB compact numeric footprint;
- zero supported coverage outside the trained domain.

## Confidence rule

The selected deterministic uncertainty half-width is:

```text
validation P95 absolute pair residual (1.2419 pp)
+ held-out SimC pair mean-error P95 (0.2097 pp)
= 1.4516 pp
```

For predicted delta `d` and materiality threshold `m = 0.5 pp`:

```text
upgrade   only if d - 1.4516 >  0.5
downgrade only if d + 1.4516 < -0.5
otherwise too_close
```

This is an empirical release policy, not a probabilistic confidence interval. It abstains on 25.37% of held-out pairs and made no confident sign errors in this sample. Production data generation must recompute the envelope per model/profile/build and fail the artifact if its gates fail.

## Payload and runtime

[`model-piecewise.lua`](fixtures/simc/model-piecewise.lua) is a 5,184-byte generated Lua payload (146 numeric values; 1,168 bytes if packed as doubles). It performs a bounded number of normalizations, hinge evaluations, and 90 interaction terms: constant time and no allocation-heavy search structure.

[`verify_lua_payload.py`](tools/simc/verify_lua_payload.py) executed it in unmodified Lua 5.1.5. [`lua-runtime-benchmark.json`](fixtures/simc/lua-runtime-benchmark.json) records:

- one million evaluations;
- 10.36 µs/evaluation in the final WSL-hosted stock-interpreter rerun on this machine;
- maximum Python/Lua log-score difference `8.88e-15` across reference vectors;
- correct `OUT_OF_DOMAIN` rejection.

This is suitable for tooltip-time evaluation, though WoW-client profiling remains a production test.

## The preserved failed experiment

The first run used a fixed 60-second fight and a simpler additive-plus-global-pair model. It failed: the best compact family reached 97.01% agreement above 1 point and 95.96% above 0.5 points, with 4.35-point P95 delta error. That result is retained in [`model-benchmark-60s-failed.json`](fixtures/simc/model-benchmark-60s-failed.json), [`simc-states-60s.csv`](fixtures/simc/simc-states-60s.csv), and [`simc-run-metadata-60s.json`](fixtures/simc/simc-run-metadata-60s.json).

The canonical rerun changed two documented experimental defects: it used the conventional 300-second ±20% duration to reduce hard cooldown-boundary discontinuities, and it evaluated the originally proposed compact local interaction grids rather than one global product per stat pair. Both outcomes are reported; the failed run was not deleted or relabeled.

## Limits and production consequence

- Shared-state pairs are not 1,336 statistically independent character simulations. The gate is an engineering benchmark, not a population confidence statement.
- One gear/talent archetype does not cover alternative builds. Model identity must include spec, build archetype, profile, client/SimC build, domain, and generation hash.
- Results do not cover weapons, weapon DPS/speed, trinkets, on-use/proc items, embellishments, set changes, racial/profile changes, or dungeon/AoE behavior.
- Raw extrapolation errors are diagnostics only. Runtime must return `unsupported` outside the explicit domain.
- Before shipping even this spec, repeat with multiple representative base gearsets and an additional untouched pair-generation seed. The spike nevertheless answers its architectural question: compact offline SimC surrogates are practical.

## Reproduction

Commands are in [`README.md`](README.md). The source build is external because it is large; every required identity is pinned in-repository. Generated profilesets and raw JSON/log output are preserved under [`fixtures/simc`](fixtures/simc/).
