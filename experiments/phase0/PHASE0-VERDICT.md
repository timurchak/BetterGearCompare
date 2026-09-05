# Phase 0 integrated verdict

> Post-Phase-0 product decision: the first production capability is now planned as Arms Warrior AoE rather than the Ret Paladin single-target archetype used by Spike B. This does not change Spike B's narrow `PASS`; it means a new pinned Arms/AoE model and validation report are required before numeric production advice is enabled.

Phase 0 validates the upgrade-projection and one-spec surrogate assumptions and leaves the live asynchronous-tooltip evidence honestly partial. **Architecture and implementation planning may proceed, but production addon implementation still requires explicit user approval.** The evidence supports the originally proposed future-rank calculation for the strictly recognized current-season subset. The missing live uncached/stale-callback ordering case is a focused pre-release integration gate, not a blocker for planning or staged implementation after approval.

| Assumption | Result | Evidence | Consequence |
|---|---|---|---|
| Future-rank projection | **PASS** | All 8 mandatory live fixtures pass; 11 unique future item/rank states across Champion/Hero ordinary items match structured vendor evidence, while crafted, max-rank-ineligible, and old-season cases fail closed in [`validation-report.json`](fixtures/upgrade/validation-report.json); see [`A-upgrade-projection.md`](A-upgrade-projection.md). | Implement projection only for exact active-build manifest matches with positive eligibility; preserve safe unsupported outcomes for crafted/legacy/ambiguous items. |
| SimC surrogate | **PASS (narrow)** | 720 pinned simulations, 1,336 held-out pairs, all declared gates pass in [`model-benchmark.json`](fixtures/simc/model-benchmark.json), and generated Lua passes [`lua-runtime-benchmark.json`](fixtures/simc/lua-runtime-benchmark.json); see [`B-simc-surrogate.md`](B-simc-surrogate.md). | Use offline generated response surfaces with explicit domain/uncertainty, never average-player distributions or global weights. Expand coverage before production. |
| Tooltip lifecycle | **PARTIAL (V1 sources observed)** | Offline stress passes; the live [`live-lifecycle-report.json`](fixtures/tooltip/live-lifecycle-report.json) covers bags, character, chat, comparison frames, duplicate suppression, and equipment refresh with no blocked protected action. It lacks a genuinely uncached refresh/stale rejection; loot, merchant, and encounter-journal marks are also absent but are not required V1 sources. See [`C-tooltip-lifecycle.md`](C-tooltip-lifecycle.md). | Keep the revision/key/repository design. Proceed with planning; require a real uncached/stale-order integration regression before release. Do not block V1 on loot, merchant, or encounter-journal coverage. |

## 1. Is the proposed V1 still viable?

The product is technically worth building. The surrogate result removes the largest modeling feasibility risk, and the current-season rank mechanism—including old-season rejection—passes its representative live gate. The proposed V1 is ready for a concrete implementation plan and may enter staged implementation only after explicit user approval. The incomplete live asynchronous lifecycle evidence remains **PARTIAL** and becomes a pre-release integration requirement. Future ranks are viable for exact active-build manifest matches, with every unmatched, crafted, legacy, or ambiguous case failing closed.

## 2. Functionality to remove or narrow

Future-rank rows and “becomes an upgrade at rank N” may remain in the first approved scope for recognized current-season ordinary items. Do not project crafted gear or any item without an exact active-build manifest match and positive eligibility. Defer upgrade-cost efficiency until costs and discount rules receive a separate live gate.

Keep intentionally unsupported in initial V1 regardless:

- trinkets, proc/on-use gear, special-effect weapons, embellishments, and unusual scripted items;
- tier changes or any state that activates/breaks a set threshold;
- weapons and 1H/2H/off-hand configuration transitions;
- crafted recrafting/quality projections;
- out-of-model-domain stats, unrecognized specs/builds, and unsupported encounter profiles;
- advice from population averages, Archon scraping, or a runtime web service.

The smallest useful V1 is one supported DPS spec/build/profile, current-rank ordinary stat-only armor/neck/rings, valid complete equipped-state comparisons for dual slots, transparent `too_close/special/unsupported` outcomes, and the default Blizzard tooltip. Future ranks are a separately enabled capability backed by the passed manifest/projection artifact, not assumed by the evaluator. Loot, merchant, and encounter-journal tooltip sources are deferred and nonessential for V1.

## 3. Architecture assumptions that changed

- **Projection is evidence, not link arithmetic.** Bonus substitution may be a candidate representation, but only a current build, positive eligibility, and independently observed structured rank values may authorize advice.
- **The surrogate is not a polynomial mandate.** For the measured archetype, compact piecewise hinge terms with local pairwise interaction grids beat global linear, quadratic, local-weight, and KNN alternatives.
- **Confidence is an abstention policy.** It is derived per generated model from validation residuals plus SimC error; it is not a fabricated universal percentage. Out-of-domain evaluation returns unsupported.
- **Async work belongs in a repository, not a tooltip callback.** Tooltip state is a short-lived view subscription keyed by exact item identity and revision. Completion refreshes current data; it never writes a delayed result directly.
- **Generated artifacts are release-gated.** Client build, SimC commit/profile, stat domain, residual envelope, payload hash, special-item policy, and upgrade manifest are provenance, not comments.

## 4. Exact V1 scope after validation

No production implementation is authorized by this Phase 0 result; it still requires explicit user approval. With A passed, B passed for the narrow archetype, and C retained as an accepted PARTIAL risk, plan this exact first slice:

1. One explicitly named Retribution Paladin build archetype, single-target only.
2. Ordinary stat-only head/shoulder/chest/wrist/hands/waist/legs/feet/back/neck and rings at their observed current state.
3. Candidate **equipment-state** enumeration, including both legal ring replacement states; never raw item-versus-item scoring.
4. Generated piecewise response-surface score plus empirical uncertainty policy.
5. Outcomes: `upgrade`, `downgrade`, `too_close`, `special`, `unsupported`, or `pending`—with reason codes and provenance.
6. Blizzard-default tooltip adapter only, with compact basic text and diagnostic detail behind a modifier/debug command.
7. Future ranks for exact active-build manifest matches using the validated projection path; otherwise show “future ranks unavailable,” not an estimate.

Sockets may contribute only their actually observed structured stats. The addon must not recommend hypothetical gems. Tier-looking and special-effect items are classified before numeric evaluation and fail closed.

## 5. Required data-generation tooling

Build tooling, kept outside the addon package, must provide:

- pinned SimulationCraft acquisition/build verification;
- profile registry and hashes;
- reproducible stat-space sampling and profileset generation;
- batch runner retaining raw output and simulation error;
- train/validation/held-out benchmark with pair decision gates;
- model-family comparison and deterministic Lua exporter;
- stock-Lua cross-language and runtime verification;
- current-season structured upgrade-manifest generator;
- live projection fixture importer/validator;
- generated-artifact manifest with hashes, provenance, supported domains, and expiry/client-build rules.

The Phase 0 implementations are under [`tools`](tools/) and are evidence prototypes, not yet a polished production pipeline.

## 6. What runs at addon build time

- SimC simulations, model fitting/selection, uncertainty calibration, and all accuracy gates.
- Upgrade-manifest fetch/normalization and live-fixture validation.
- Special-item/tier classification generation and coverage audit.
- Lua payload generation, schema validation, hashes, syntax checks, cross-language golden vectors, footprint tests, and release manifest creation.

A failing or stale artifact blocks release. No simulation, web access, model fitting, or website scraping runs in WoW.

## 7. What exists only at runtime

- Blizzard API adapters and asynchronous exact-item repository.
- Current player spec/talent/build-archetype match and supported-domain check.
- Equipped-state snapshot and legal replacement-state enumeration.
- Special/unsupported classification before scoring.
- Constant-time generated-model evaluation and confidence policy.
- Optional evidence-backed rank lookup/projection.
- Tooltip subscription/controller/presentation and diagnostics.
- Bounded caches keyed by full item identity, equipment revision, model version, and client build.

## 8. Remaining unknowns

1. Whether the successful current-season projection result generalizes beyond the tested Champion/Hero items, bonus combinations, and acquisition sources; artifact release tests must keep expanding the fixture corpus.
2. Whether future seasons expose new crafted/track representations requiring a new manifest schema; the tested old-season and max-rank cases now reject correctly.
3. Whether a genuinely uncached item completion refreshes the current tooltip and rejects a stale tooltip in the live client. Required V1 bags/character/chat/comparison frames are observed. This exact missing ordering case must be exercised before release; loot/merchant/journal sources remain deferred and do not affect the V1 gate.
4. Model stability across multiple representative base gearsets, talents within an archetype, another generation seed, hotfixes, and season transitions.
5. How many build archetypes are needed per spec and how an in-game character is matched without pretending exact talent equivalence.
6. Current-state treatment of weapon DPS/speed, armor, sockets, and primary-stat variants beyond the isolated five-feature experiment.
7. An automated, legally redistributable special-item classification/source pipeline.
8. Performance and cache bounds inside the actual WoW Lua runtime.

## 9. Production module boundaries

These are provisional boundaries for the clean replacement project; they are not an instruction to migrate old code.

```text
BetterGearAdvisor/
  BetterGearAdvisor.toc
  Bootstrap.lua
  Runtime/
    EventCoordinator.lua
    Diagnostics.lua
  Blizzard/
    ItemAPI.lua
    TooltipAPI.lua
    CharacterAPI.lua
  Items/
    ItemRepository.lua
    ItemNormalizer.lua
    SpecialClassifier.lua
    UpgradeEvidence.lua
  Equipment/
    StateSnapshot.lua
    CandidateEnumerator.lua
    EligibilityRules.lua
  Evaluation/
    GearEvaluator.lua
    ModelRegistry.lua
    ConfidencePolicy.lua
  UI/
    TooltipController.lua
    TooltipPresenter.lua
  Generated/
    ArtifactManifest.lua
    Models/
    UpgradeManifests/
    SpecialItems.lua
  Tests/
    Unit/
    Fixtures/
    Integration/
tools/
  simc/
  game-data/
  validation/
```

Dependency direction is `UI -> Evaluation/Items/Equipment -> pure data/types`; Blizzard adapters implement ports consumed by the domain. `Evaluation` never imports tooltip code. Generated artifacts contain data and pure evaluators, not network clients.

### Initial domain interfaces

Avoid a single ambiguous “score this item” API. Separate observation, state construction, and decision:

```lua
ItemRepository:Resolve(itemRef, callback)
EquipmentBuilder:Snapshot(characterContext)
CandidateEnumerator:Enumerate(equipmentState, candidate, context)
GearEvaluator:Evaluate(candidateStates, baselineState, context)
UpgradeEvidence:Project(item, targetRank, context)
TooltipController:Request(tooltip, itemRef)
```

`GearEvaluator:Evaluate` returns a discriminated result, not a precision-looking score bag:

```lua
{
  status = "upgrade" | "downgrade" | "too_close" |
           "special" | "unsupported" | "pending",
  deltaPercent = number | nil,
  uncertaintyPercent = number | nil,
  baselineStateID = string,
  chosenStateID = string | nil,
  replacedSlots = { number, ... },
  alternatives = {
    { stateID = string, replacedSlots = {...}, deltaPercent = number | nil }
  },
  future = {
    status = "available" | "unverified" | "unsupported",
    ranks = { ... },
    firstUpgradeRank = number | nil,
  },
  reasonCodes = { string, ... },
  provenance = {
    clientBuild = string,
    artifactVersion = string,
    modelID = string | nil,
    modelHash = string | nil,
    profileHash = string | nil,
    upgradeManifestHash = string | nil,
  },
}
```

Only `upgrade` and `downgrade` are directional claims. `too_close` is a successful evaluation whose uncertainty policy abstained; `special` and `unsupported` state why the ordinary model was not applied; `pending` is transient and must never be cached as a final answer.

## Go/no-go

**GO for architecture and implementation planning. Production implementation remains NO-GO until the user explicitly approves the plan.** Spike C remains PARTIAL; it does not need to be relabeled or completed before planning. The real uncached/stale-callback case is a focused pre-release integration gate, while loot, merchant, and encounter-journal sources are deferred from V1. Broader surrogate robustness and representative-base-state validation remain release gates for the advertised Ret Paladin capability, not reasons to reuse BetterGearCompare or PopularSlotsAndChants architecture.
