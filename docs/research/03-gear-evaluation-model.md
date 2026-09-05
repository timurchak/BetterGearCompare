# Gear evaluation model

## The current “average stats become weights” method is invalid

Suppose a sampled population averages 900 Crit and 700 Haste. Converting those observations into weights 9.0 and 7.0 commits several errors:

1. **Amount is not marginal value.** A stat weight is approximately a derivative: how performance changes if a small amount of one stat is added or exchanged at a particular character state. A population average is a stock, not a derivative.
2. **Gear availability is a confounder.** Players have the stats found on high-item-level drops, tier pieces, crafted slots, and special items they could acquire. A common stat can be common because the best available pieces contain it, not because each next point is best.
3. **The sample is selected.** Ranking filters select successful players, builds, encounters, kill times, teams, and acquisition histories. Averaging them does not produce a causal counterfactual for this character.
4. **Item level and primary stat dominate allocation.** Players frequently wear a higher-level piece despite less-preferred secondaries. Observed totals blend item budget with preference.
5. **Values are state-dependent.** Crit, Haste, Mastery, and Versatility interact with one another, talents, cooldown alignment, resource flow, weapon speed, and encounter shape.
6. **Diminishing returns are nonlinear.** Rating beyond current percentage bands receives a penalty; the marginal value can fall even while the observed total remains high. The current rating-based bands are summarized in [Wowhead's secondary-stat DR guide](https://www.wowhead.com/guide/diminishing-returns-on-secondary-stats-in-world-of-warcraft).
7. **Special effects are omitted.** A player may wear a piece for a proc, use effect, set threshold, or cantrip. Its raw stat distribution does not reveal that value.
8. **The normalization is arbitrary.** Dividing an observed count by 100, while forcing the first-ranked stat to exactly 10, has no invariant unit and cannot yield a meaningful percentage.

Population data is useful for “what do similar players commonly equip?” It is not a source of gear-value coefficients.

## What conventional stat weights actually mean

SimulationCraft scale factors are local finite-difference estimates around one exact profile. SimC perturbs a stat, observes the change in the simulated objective, and reports a slope with sampling error. Its documentation notes that the result is centered around the perturbed point and can change because of diminishing returns and noise ([SimulationCraft Stats Scaling](https://github.com/simulationcraft/simc/wiki/StatsScaling)).

That is much more defensible than population averages, but still not a universal item scorer:

- the derivative is local to the character's current stats, gear, talents, and action list;
- a large item swap can move to a region with different slopes;
- a linear sum cannot correctly price procs, weapon changes, set bonuses, gems, enchants, or nonlinear interactions;
- scale factors can change after the swap;
- close differences can be smaller than simulation and surrogate error.

Raidbots recommends direct Top Gear simulation rather than relying on stat weights for these reasons, including multiplicative stat interactions and items with non-stat effects ([Beware of Stat Weights](https://support.raidbots.com/article/66-beware-of-stat-weights)). Raidbots also treats results within roughly twice the reported simulation error as effectively tied in its sidegrade guidance ([Top Gear sidegrades](https://support.raidbots.com/article/61-top-gear-sidegrades)).

Pawn-style weights remain useful as a user-supplied expert mode or a transparent fallback labeled “linear approximation.” They should not power the default percentage or confidence claim.

## Objective and boundary

The addon should evaluate a complete, legal equipment state:

```text
delta = modeledPerformance(candidateState) / modeledPerformance(currentState) - 1
```

For an embedded model, “modeledPerformance” must mean the output for a declared specialization, build archetype, and encounter profile. It is not a promise of the player's real DPS/HPS. The user-facing percentage should be a relative model delta, rounded to avoid false precision.

The first supported objective should be sustained damage for selected DPS specializations. Healing and tank value are multi-objective (throughput, damage, survival, encounter-specific damage patterns) and should not be represented by a single green DPS-style percentage until dedicated objectives exist.

## Candidate model families

| Model | Advantages | Failure modes | Recommendation |
|---|---|---|---|
| One static weight vector/spec | Tiny, transparent | Only one local slope; no current-state or interaction response | Do not use as default |
| Dynamic local weights at anchors | Small and interpretable | Linear only within a neighborhood; integrating gradients can be inconsistent | Useful baseline/diagnostic |
| Full multidimensional grid | Direct interpolation and bounded domain | Exponential growth with five or more dimensions | Impractical as a dense grid |
| Global quadratic polynomial | Very compact and fast | Poor near breakpoints/DR knots; unstable extrapolation; forces one curvature globally | Baseline challenger, not preferred |
| Higher-order polynomial | Can reduce training error | Oscillation, opaque coefficients, dangerous extrapolation | Reject |
| Regression tree / tiny neural network | Flexible and compact | Harder to audit, may be discontinuous, weak explanation story in Lua | Possible research challenger |
| Local nearest-neighbor/RBF surface | Flexible; supports uncertainty by distance | More runtime work and anchor storage; extrapolation weak | Viable challenger |
| Piecewise additive splines plus sparse pair interactions | Compact, deterministic, captures DR curves and key interactions, easy bounded interpolation | Misses high-order/discrete effects; needs careful sampling | Recommended ordinary-stat surrogate |

## Recommended offline SimulationCraft surrogate

### Model form

Fit the logarithm of the simulated objective so differences naturally become relative changes:

```text
log(performance) = intercept
                 + fPrimary(primary)
                 + fCrit(crit) + fHaste(haste)
                 + fMastery(mastery) + fVers(versatility)
                 + sum(pairwise residual surfaces)
                 + weapon terms
```

Each `f` is a bounded piecewise-linear or monotone cubic spline. Pair surfaces are small bilinear grids for the interactions that cross-validation shows matter. The runtime evaluator is additions and table interpolation—compact, deterministic, and auditable. A global quadratic is kept as a benchmark; it ships only if it unexpectedly wins on sign accuracy, calibration, and worst-case error.

Do not include special effects or set state as anonymous numeric features. They use explicit models/guards. Weapon DPS, speed, handed configuration, and the relevant hand are separate features and only appear in weapon-capable models.

### Representing total budget and stat distribution

Sampling should be designed in:

- total secondary budget `T`;
- three independent proportions on the four-stat simplex (the fourth is the remainder);
- primary-stat/item-budget band;
- weapon features when relevant.

The fitted runtime functions can operate on absolute gear-derived stat totals. Designing on `(T, proportions)` prevents the training set from wasting points on impossible combinations and ensures balanced coverage of distributions. Absolute rating still matters because diminishing-return thresholds are based on the resulting percentage, not just proportions.

The model's fixed profile supplies level, race assumptions, talents, action list, consumables, and encounter definition. Runtime input is the sum of normalized item stats for the whole loadout. This avoids dependence on combat-sensitive unit-stat APIs and makes the pure evaluator reproducible.

### Build archetypes

One model per specialization is not enough when materially different hero trees/talents change stat interactions or weapon rules. A `ModelContext` should identify:

- specialization ID;
- a versioned archetype ID;
- encounter profile (`single_target`, `dungeon_slice`, later others);
- SimC commit/build;
- action-list/profile hash;
- training domain and validation error.

The addon fingerprints the active selected talent entries/ranks using `C_ClassTalents.GetActiveConfigID` plus the `C_Traits` configuration APIs, then matches a supported archetype signature. The local config ID itself is not portable. Exact/declared matching can earn high confidence; nearest-archetype matching is at most medium and must say which archetype was used. An unrecognized material build is unsupported, not silently mapped to a generic profile.

Population data may help discover which archetypes deserve models, but those models are generated and validated with SimulationCraft.

### Sampling budget and practicality

A reasonable first experiment per archetype/profile is:

- 5–7 total-budget/primary bands across the supported season range;
- 80–150 space-filling secondary distributions per band;
- targeted samples on each diminishing-return boundary and known spec breakpoint;
- 50–150 weapon/primary perturbations where applicable;
- an independent 20–30% holdout set plus adversarial real-gear swaps.

This is roughly 600–1,500 simulated actors per model. SimulationCraft profilesets can amortize startup and shared baseline work; iteration count should be chosen from the desired confidence interval rather than fixed blindly. SimC is explicitly an event-driven simulator with current Midnight development in its [`midnight` branch](https://github.com/simulationcraft/simc).

Order-of-magnitude planning:

- 5 pilot specs × 2 profiles × 2 archetypes × 1,000 actors ≈ 20,000 actor simulations;
- 26 DPS specs × 2 profiles × 2 archetypes × 1,000 ≈ 104,000 actor simulations;
- more archetypes and special-item grids multiply that count.

The work is practical on a repeatable build farm, but full spec coverage is a maintained data product, not a one-time addon task. Runtime model storage can remain modest: about 300–700 quantized coefficients/knots per model is a few kilobytes packed, though ordinary Lua tables inflate it. Generate packed numeric arrays or delta-coded strings and decode lazily per active spec. A DPS-wide bundle should target low single-digit compressed megabytes, with actual size enforced in CI.

### Validation gates

No model ships based only on training fit. For held-out legal ordinary-stat states, record:

- error in the predicted **difference** between two states, in percentage points;
- sign agreement;
- calibration by predicted uncertainty;
- error by distance from the training domain;
- separate results for small, medium, and large upgrades;
- errors around DR thresholds and archetype boundaries.

Suggested initial release gates (to be revised from empirical pilot results):

- median absolute delta error ≤ 0.20 percentage points;
- 95th-percentile absolute delta error ≤ 0.60 points inside the supported domain;
- ≥98% sign agreement where the SimC truth magnitude is at least 1.0%;
- zero high-confidence sign errors in the adversarial fixture suite;
- no extrapolated point can receive high confidence.

These are engineering acceptance criteria, not claims that the final model will necessarily meet them. If a spec/profile fails, it is not supported in that release.

### Uncertainty

Package each model with a base holdout error and training bounds. Runtime uncertainty `U` is deterministic:

```text
U = validationP95
  + distanceOutsideSupportedHullPenalty
  + archetypeMismatchPenalty
  + configurationPenalty
```

Special-effect, set-breakpoint, missing-input, and invalid-state conditions do not merely add a large penalty; they route away from the ordinary model.

Report `delta ± U` internally. User-facing confidence rules are in `07-product-and-ux.md`.

## Why direct item tables are not the ordinary model

A direct table of every regular item/spec/item-level result explodes with socket, tertiary, enchant, ring-pair, weapon-pair, talent, and current-stat context. It also cannot reuse information for a new item with the same ordinary stats. A state response surface is the correct reusable abstraction for normal gear.

Direct item-effect curves are appropriate for effects whose mechanics are not represented by raw stats. That separate path is described in `05-trinkets-and-special-effects.md`.

## What can be approximated reliably without in-game simulation

Within a validated domain, the surrogate can reasonably compare:

- ordinary primary/secondary-stat armor and jewelry;
- filled/normalized ordinary gems and enchants;
- simple stat-only trinkets;
- weapon changes only when the model contains weapon features and the complete state is legal;
- every verified future rank of the same ordinary item.

It should not claim reliable default value for:

- unknown proc/on-use/cantrip/embellishment effects;
- set bonus activation/deactivation;
- unsupported build archetypes or encounter objectives;
- healer/tank “overall value” without a declared objective;
- PvP, legacy scaling, heirloom, timewalking, or future crafted recraft states not covered by a dedicated model;
- extrapolation beyond the packaged training domain.

## Reproducible generation contract

Every model bundle should record:

```text
addon data schema
WoW client build / season manifest hash
SimulationCraft commit and build string
base profile and APL hashes
talent archetype signature
fight style, duration distribution, target/add schedule, iterations
sampling seed and design
fit code/version and hyperparameters
training/validation metrics
generation timestamp
```

The generator, profiles, fit code, validation fixtures, and reports belong in source control. SimulationCraft is open source; its project documentation identifies GPL licensing ([SimC FAQ](https://github.com/simulationcraft/simc/wiki/FAQ)). Redistribution obligations for copied code/data and the status of generated numeric output still require a project license review; simply running an external executable at build time is the preferred separation.
