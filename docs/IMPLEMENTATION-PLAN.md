# Better Gear Advisor — implementation plan

Status: **approved; implementation in progress**.

Basis: the completed research package and Phase 0 evidence for Retail `12.1.0.69587`. Spike A is `PASS`; Spike B is `PASS` only for one Retribution Paladin single-target archetype; Spike C remains factually `PARTIAL`. Its missing genuinely uncached/stale-callback live case is a pre-release integration gate, not an architecture-planning blocker. Loot, merchant, and encounter-journal tooltip sources are deferred and are not V1 requirements. A post-plan product decision changes the first production target to Arms Warrior AoE; the Ret single-target spike remains architectural evidence only and is not evidence for the new capability.

## Implementation progress

Updated after implementation approval:

- Stage 0: complete in source; clean addon root, TOC allowlist, namespace, contracts, and boundary checker exist.
- Stage 1: complete for the initial V1 domain slice; ordinary item snapshots, fail-closed classification, single-slot/ring enumeration, plate/unique/GUID validation, and immutability regressions exist.
- Stage 2: complete for runtime mechanics; generic bounded piecewise evaluator, exact registry selection, and materiality/abstention policy exist. The Arms/AoE generated model does not yet exist and numeric advice remains disabled.
- Stage 3: complete for pure projection mechanics; parser, exact-one-bonus substitution, build/eligibility/crafted guards, and item-level verification exist. The packaged season manifest remains deliberately unavailable and projection remains disabled pending production generation.
- Stage 4: implemented and offline-tested; Blizzard adapters, revision counters, coalescing item repository, equipment fan-out, timeout/retry, and synchronous-callback regressions exist. Live client qualification remains pending.
- Stage 5: complete for runtime mechanics and offline tests. Current and independently verified future ranks use the same complete-state evaluator; every ring rank re-enumerates both slots; first confirmed upgrade rank is derived without a monotonicity assumption. The packaged projection manifest remains disabled, so production data generation/goldens remain a later evidence gate rather than runtime code debt.
- Stage 6: default-tooltip controller/presenter/runtime wiring is implemented and offline-tested, including independent comparison frames and stale callback rejection. Live Retail qualification remains pending, so Spike C remains `PARTIAL`.
- Stages 7–9: pending. In particular, no Ret coefficients are used for Arms, and the packaged capability manifest is `planned` with `numericAdviceEnabled=false`.

## 1. Product boundary and exact V1 scope

### Product identity

- Product/display name: **Better Gear Advisor**.
- Addon folder and TOC name: `BetterGearAdvisor`.
- Lua namespace: the private table passed through `local addonName, BGA = ...`; no public `BetterGearCompare` globals.
- Planned production root after approval: `C:\projects\BetterGearCompare\BetterGearAdvisor\`.
- Offline production tooling root after approval: `C:\projects\BetterGearCompare\tools\better-gear-advisor\`.
- Tests and generated reports remain outside the packaged addon unless a fixture is explicitly needed by a developer build.
- The old root-level `BetterGearCompare*.lua`, its TOC, generated Wowhead data, and `PopularSlotsAndChants` concepts are neither migrated nor imported. Phase 0 code is evidence/prototype input, not production code.

### Included in V1

1. Exactly one initial production capability: Arms Warrior, one explicitly fingerprinted MID2 AoE archetype. Proposed stable capability ID: `arms-warrior-mid2-dungeon-aoe-v1`. Before model generation, the AoE contract must pin target count/spawn schedule, duration distribution, movement assumptions, APL, talents, and base-state families; “AoE” by itself is not a reproducible profile. The generated record must contain the exact portable talent fingerprint; a local trait config ID is never the identity.
2. Ordinary stat-only head, shoulder, chest, wrist, hands, waist, legs, feet, cloak/back, neck, and rings.
3. Candidate comparison against an immutable snapshot of the complete currently equipped state. Single slots produce one substitution; rings produce both slot 11 and slot 12 substitutions, then choose the best legal complete state.
4. Exact, structured, already-present Strength/Crit/Haste/Mastery/Versatility values. Socket and enchant contributions are treated according to the explicit `as_observed_v1` enhancement policy: only stats present in the resolved link count; an empty socket is not filled hypothetically and the addon gives no gem advice. The policy is included in result provenance and details.
5. Current-rank comparison plus every reachable legal future rank through the current ordinary six-rank track, but only for an owned item whose location-aware eligibility is explicitly `true` and whose link exactly matches the active build manifest.
6. Runtime outcomes `upgrade`, `downgrade`, `too_close`, `special`, `unsupported`, and `pending`, always with reason codes and provenance. Resolution failures are represented as `unsupported` with a data-failure reason; they are never scored as zero.
7. Blizzard default tooltips for bags, equipped/character items, chat links/`ItemRefTooltip`, and comparison/`ShoppingTooltip` frames through one `TooltipDataProcessor` item post-call.
8. A concise tooltip block plus modifier-key details and a privacy-safe `/bga debug` diagnostic export.
9. Fully offline packaged operation: no runtime network and no required addon.

### Explicit V1 exclusions

- Every other specialization, Arms talent archetype, and encounter profile outside the one pinned V1 AoE schedule.
- Weapons of every kind, weapon DPS/speed comparison, and all 1H/2H/off-hand transitions.
- Trinkets, procs, on-use effects, cantrip/special weapons, scripted armor/jewelry, embellishments, and crafted special effects.
- Any tier item or state whose set/effect semantics are not explicitly proven ordinary; V1 has no tier-breakpoint valuation.
- Crafted-quality/recraft projections. An exact current crafted item is classified conservatively; no ordinary-track future link is created for it.
- Hypothetical gems, gem recommendations, assumed enchants, and best-in-slot enhancement normalization.
- PvP-context, Timewalking, heirloom, legacy scaling, post-track/Venomstone, or ranks beyond `6/6`.
- Upgrade-cost efficiency, sell/destroy/vendor advice, BiS/popularity browsing, Archon-derived weights, global Pawn-style weights, and runtime SimulationCraft.
- Loot, merchant, encounter-journal, third-party tooltip, bag-addon, and auction-addon integration.
- A claim that the model output is universal or the player's actual DPS. The number is only a relative delta from the declared generated archetype/profile model.

## 2. Complete planned file layout

No files in this tree are to be created until plan approval.

```text
BetterGearAdvisor/
  BetterGearAdvisor.toc
  Bootstrap.lua
  Core/
    Constants.lua
    Result.lua
    ReasonCodes.lua
    Keys.lua
    TableUtil.lua
  Generated/
    ArtifactManifest.lua
    SeasonManifest.lua
    CapabilityManifest.lua
    SpecialItemManifest.lua
    Models/
      ArmsWarriorMID2DungeonAoE.lua
  Domain/
    ItemLink.lua
    ItemSnapshot.lua
    EffectClassifier.lua
    EquipmentState.lua
    CandidateEnumerator.lua
    StateValidator.lua
    RankProjector.lua
    ModelRegistry.lua
    OrdinaryModel.lua
    ConfidencePolicy.lua
    GearEvaluator.lua
  Ports/
    ItemDataPort.lua
    InventoryPort.lua
    CharacterPort.lua
    UpgradePort.lua
    TooltipPort.lua
    ClockPort.lua
  Blizzard/
    ItemDataAdapter.lua
    InventoryAdapter.lua
    CharacterAdapter.lua
    UpgradeAdapter.lua
    TooltipAdapter.lua
    ClockAdapter.lua
    EventAdapter.lua
  Application/
    Revisions.lua
    ItemRepository.lua
    EquipmentRepository.lua
    EvaluationCache.lua
    EvaluationCoordinator.lua
    Diagnostics.lua
    Settings.lua
  Presentation/
    TooltipController.lua
    TooltipPresenter.lua
    DebugPresenter.lua
  Locale/
    enUS.lua
    ruRU.lua

tools/better-gear-advisor/
  README.md
  requirements.lock
  schemas/
    artifact-manifest.schema.json
    season-manifest.schema.json
    capability-manifest.schema.json
    model.schema.json
    fixture.schema.json
  simc/
    simc.lock.json
    profiles/
      arms-warrior-mid2-dungeon-aoe.simc
    generate_samples.py
    generate_profilesets.py
    run_simc.py
    fit_models.py
    validate_model.py
    export_lua.py
    verify_lua.py
  game-data/
    fetch_pinned_metadata.py
    build_season_manifest.py
    build_special_item_manifest.py
    diff_manifest.py
  fixtures/
    import_upgrade_capture.lua
    import_tooltip_capture.lua
    sanitize_fixture.py
  validation/
    validate_artifacts.py
    validate_upgrade_fixtures.py
    validate_release.py
    hash_artifacts.py
  release/
    build_addon.ps1
    package_addon.py

tests/better-gear-advisor/
  lua/
    runner.lua
    fakes/
      FakeClock.lua
      FakeItemDataPort.lua
      FakeInventoryPort.lua
      FakeCharacterPort.lua
      FakeUpgradePort.lua
      FakeTooltipPort.lua
    core/
    domain/
    application/
    presentation/
    contracts/
  fixtures/
    phase0-upgrade/
    phase0-tooltip/
    normalized-items/
    equipment-states/
    model-vectors/
    golden-decisions/
  integration/
    BetterGearAdvisorIntegration/
      BetterGearAdvisorIntegration.toc
      BetterGearAdvisorIntegration.lua
    checklists/
      retail-default-ui.md
      patch-qualification.md
  reports/
    .gitkeep

docs/
  IMPLEMENTATION-PLAN.md
  release/
    capability-matrix.md
    patch-update-runbook.md
    data-provenance.md
```

The packaged zip contains only `BetterGearAdvisor/`. Test runners, source JSON/CSV, SimC profilesets, raw captures, and Python code never ship in the addon.

## 3. Module boundaries and dependency direction

Allowed dependency graph:

```text
Bootstrap
  -> Blizzard adapters + Application wiring + Presentation wiring
Presentation
  -> Application public interfaces + Core result/reason types
Application
  -> Domain + Ports + Generated + Core
Blizzard adapters
  -> Ports contracts + WoW API only
Domain
  -> Core + immutable Generated data passed as arguments
Generated
  -> data only (plus a pure model-evaluate function), no WoW API
Core
  -> nothing
```

Forbidden dependencies:

- `Domain` must not import frames, events, `C_Item`, `C_Container`, tooltip objects, SavedVariables, or clocks.
- `Generated` must not perform network access, read live player state, register globals, or select a model by itself.
- `Presentation` must not calculate deltas, determine confidence, parse links, or decide eligibility.
- `Blizzard` must not score gear or choose replacement slots.
- `Application` may coordinate asynchronous work but must not interpret localized tooltip prose.
- No layer may import old BetterGearCompare modules or Baganator/Syndicator/Archon/Wowhead data.

The TOC load order follows this graph: Core, Generated, Domain, Ports, Blizzard, Application, Presentation, then Bootstrap. Every source file receives `BGA` through `...`; the only intentional saved global is `BetterGearAdvisorDB` declared in the TOC.

## 4. Domain structures and public interfaces

All domain values are treated as immutable. Constructors copy input tables in development tests; evaluation never mutates snapshots, states, manifests, or model records.

```lua
ItemRef = {
  fullLink = string,
  itemID = number,
  itemLocation = opaque_or_nil,
  itemGUID = string_or_nil,
  source = "bag" | "equipped" | "chat" | "comparison",
}

ItemSnapshot = {
  schema = 1,
  key = string,                 -- canonical link + owned identity when relevant
  fullLink = string,
  itemID = number,
  itemGUID = string_or_nil,
  locationKey = string_or_nil,  -- serialized bag/slot or equipment slot, no live object
  inventoryType = string,
  itemClassID = number,
  itemSubClassID = number,
  quality = number,
  requiredLevel = number_or_nil,
  actualItemLevel = number,
  previewItemLevel = number_or_nil,
  stats = {
    strength = number,
    crit = number,
    haste = number,
    mastery = number,
    versatility = number,
  },
  unknownStatKeys = { string, ... },
  sockets = { { kind = string, gemItemID = number_or_nil } },
  enchantID = number_or_nil,
  tertiary = { leech = number, avoidance = number, speed = number },
  setID = number_or_nil,
  effectEvidence = {
    tooltipLineTypes = { number, ... },
    itemSpellID = number_or_nil,
    triggeredSpellID = number_or_nil,
    knownSpecialKey = string_or_nil,
  },
  upgrade = {
    metadataPresent = boolean,
    groupID = number_or_nil,
    rank = number_or_nil,
    maxRank = number_or_nil,
    eligibility = true | false | "unknown",
    manifestStatus = "match" | "none" | "ambiguous" | "build_mismatch",
  },
}

CharacterContext = {
  classID = number,
  specID = number,
  level = number,
  talentFingerprint = string,
  archetypeID = string_or_nil,
  profileID = "dungeon_aoe",
  enhancementPolicyID = "as_observed_v1",
  contextRevision = number,
}

EquipmentState = {
  id = string,
  slots = { [number] = ItemSnapshot },
  aggregateStats = { strength, crit, haste, mastery, versatility },
  uniqueCategoryCounts = { [number] = number },
  setCounts = { [number] = number },
  materialEffectSignature = string,
  equipmentRevision = number,
  inventoryRevision = number,
}

CandidateState = {
  id = string,
  slots = { [number] = ItemSnapshot },
  replacedSlots = { number, ... },
  removedItemKeys = { string, ... },
  retainedRingSlot = number_or_nil,
  validation = { status = "valid" | "invalid", reasonCodes = { string, ... } },
}
```

Public port/application/domain interfaces:

```lua
ItemDataPort:ReadResolved(itemRef) -> { status, rawFields | reasonCode }
ItemDataPort:Load(itemRef, onComplete) -> cancelFn
InventoryPort:CaptureEquippedRefs() -> { revision, refsBySlot }
CharacterPort:CaptureContext() -> CharacterContext
UpgradePort:GetMetadata(itemRef) -> typed result
UpgradePort:GetEligibility(itemLocation) -> true | false | "unknown"
TooltipPort:GetDisplayedItem(tooltip, tooltipData) -> ItemRef | nil
TooltipPort:Refresh(tooltip) -> boolean

ItemRepository:Resolve(itemRef, waiterToken, callback) -> cancelFn
EquipmentRepository:ResolveSnapshot(context, callback) -> cancelFn
CandidateEnumerator:Enumerate(baseline, candidate, context) -> CandidateState[]
StateValidator:Validate(baseline, candidateState, context, capability) -> typed result
RankProjector:Project(candidate, targetRank, projectionContext) -> typed result
ModelRegistry:Select(context, baseline, artifactSet) -> model | unsupported
OrdinaryModel:Evaluate(model, aggregateStats) -> logScore | out_of_domain
ConfidencePolicy:Decide(deltaPP, uncertaintyPP, materialityPP) -> outcome
GearEvaluator:Evaluate(input) -> EvaluationResult
EvaluationCoordinator:Request(viewToken, itemRef, onPublish) -> cancelFn
TooltipController:OnItemTooltip(tooltip, tooltipData) -> nil
```

The public result is a discriminated union. Fields invalid for a variant are absent, not filled with zero.

```lua
EvaluationResult = {
  status = "upgrade" | "downgrade" | "too_close" |
           "special" | "unsupported" | "pending",
  reasonCodes = { string, ... },
  deltaPercent = number_or_nil,
  uncertaintyPercent = number_or_nil,
  interval = { low = number, high = number } | nil,
  materialityPercent = 0.5,
  baselineStateID = string_or_nil,
  chosenStateID = string_or_nil,
  replacement = {
    replacedSlots = { number, ... },
    removedItemKeys = { string, ... },
    retainedSlots = { number, ... },
  } | nil,
  alternatives = { { stateID, replacedSlots, status, deltaPercent, uncertaintyPercent } },
  future = {
    status = "available" | "unverified" | "unsupported",
    ranks = { { rank, itemLevel, status, deltaPercent, uncertaintyPercent, reasonCodes } },
    firstConfirmedUpgradeRank = number_or_nil,
  },
  provenance = {
    clientBuild = string,
    addonVersion = string,
    artifactSetHash = string,
    capabilityID = string_or_nil,
    modelID = string_or_nil,
    modelHash = string_or_nil,
    simcCommit = string_or_nil,
    profileHash = string_or_nil,
    seasonManifestHash = string_or_nil,
    enhancementPolicyID = string,
  },
}
```

Initial stable reason-code groups include `ITEM_DATA_PENDING`, `ITEM_DATA_FAILED`, `ITEM_DATA_TIMEOUT`, `STALE_REQUEST`, `UNSUPPORTED_SPEC`, `ARCHETYPE_MISMATCH`, `BASELINE_EFFECT_CONTEXT_MISMATCH`, `OUT_OF_MODEL_DOMAIN`, `WRONG_ARMOR_TYPE`, `ITEM_NOT_EQUIPPABLE`, `UNIQUE_LIMIT_VIOLATION`, `DUPLICATE_INSTANCE`, `UNKNOWN_STAT_KEY`, `SPECIAL_EFFECT_DETECTED`, `TRINKET_UNSUPPORTED`, `WEAPON_UNSUPPORTED`, `TIER_UNSUPPORTED`, `CRAFTED_PROJECTION_UNSUPPORTED`, `LEGACY_OR_INELIGIBLE_TRACK`, `ELIGIBILITY_UNVERIFIED`, `UNVERIFIED_SEASON_DATA`, `AMBIGUOUS_RANK_BONUS`, `PROJECTION_ITEM_LEVEL_MISMATCH`, and `UNCERTAINTY_OVERLAPS_MATERIALITY`.

## 5. Exact item-resolution and asynchronous state machines

There are two machines with separate ownership.

### Repository entry state

Repository key is the canonical complete hyperlink, plus GUID/location identity when current effective data depends on an owned instance. It is never item ID alone.

```text
ABSENT
  -> LOADING(requestID, waiters, deadline)
  -> READY(snapshot, snapshotSchema)
  -> FAILED(reason, retryAfter)

LOADING --success--> READING --complete fields--> READY
LOADING --API failure--> FAILED
LOADING/READING --deadline--> FAILED(ITEM_DATA_TIMEOUT)
FAILED --after retryAfter and new demand--> LOADING(new requestID)
READY --owned instance/relevant schema invalidation--> ABSENT
```

Resolution algorithm:

1. Normalize and validate the `ItemRef`; reject secret/invalid values before string or arithmetic operations.
2. Build the key from the exact full link and owned identity. Same item ID with different rank, bonuses, gems, or enchant is a different key.
3. Return a ready immutable snapshot synchronously when cached.
4. Join the waiter list when the same key is already loading.
5. For a new batch, first discover and deduplicate **all** dependency keys, set the pending count, and only then subscribe. This ordering is mandatory because cached `ContinueWithCancelOnItemLoad` callbacks may run synchronously.
6. Start one `Item:CreateFromItemLink(link):ContinueWithCancelOnItemLoad(callback)` per new key; keep its cancel function. Use request-load events only as a compatible completion signal, then re-read every field.
7. The completion callback is idempotent by `(key, requestID)`. It re-reads structured data and publishes exactly once; a duplicate/late callback cannot decrement batch pending twice.
8. `ReadResolved` uses `C_Item.GetItemInventoryType(itemLocation)` only with `ItemLocation`; link-only fallback uses `C_Item.GetItemInventoryTypeByID(itemID)`. This is a named regression.
9. Eligibility uses an explicit branch. If a valid location exists, store the literal boolean returned by `CanUpgradeItem`; never use `condition and false or nil`, which erases `false` in Lua.
10. Mandatory fields for V1 are inventory type, actual item level, all modeled stat keys (zero is allowed only when the stats table explicitly lacks a known stat after complete resolution), special-effect evidence status, and exact link identity. An unavailable table/field produces pending/failure, not a zero snapshot.
11. `FAILED` is short-lived; no permanent negative cache. Canceling one waiter does not cancel the shared load while other waiters remain.

### Evaluation/view request state

Each shown tooltip owns weak-key state:

```lua
ViewState = {
  displayedKey,
  viewRevision,
  activeRequestID,
  renderedSignature,
  renderedLineCount,
  cancel,
}
```

Each coordinator request captures:

```lua
RequestToken = {
  requestID,
  tooltipIdentity,
  displayedKey,
  viewRevision,
  equipmentRevision,
  inventoryRevision,
  contextRevision,
  artifactSetHash,
}
```

```text
NEW -> RESOLVING -> EVALUATING -> READY_TO_REFRESH -> COMPLETE
                 \-> FAILED_RESULT
any nonterminal state --key/hide/revision/context/artifact change--> STALE
```

Rules:

1. A post-call captures its item from that exact tooltip frame. `GameTooltip`/`ItemRefTooltip` primary capture is never overwritten by automatic `ShoppingTooltip1/2`; every comparison frame has independent state.
2. Key change or `OnHide` increments `viewRevision`, cancels the view subscription, clears its render signature, and makes earlier tokens stale.
3. Equipment, inventory, spec, talent, level, socket, or relevant artifact change increments the corresponding application revision. No old token can publish afterward.
4. A callback may advance only if all token fields still equal live state and the tooltip is shown with the same exact key. Otherwise it increments a diagnostic stale-discard counter and does nothing.
5. Async completion never adds tooltip lines directly. It requests `tooltip:RefreshData()` when supported; the next cache-backed post-call performs rendering.
6. Render signature is deterministic over `displayedKey | requestID/resultHash | equipmentRevision | contextRevision | artifactSetHash`. Identical signatures add no second block. A changed Blizzard data generation may render the same logical result once again after the frame was rebuilt.
7. `pending` may render one neutral loading line. It is never stored as a final evaluation-cache entry.
8. Bounded timeout produces a neutral unavailable result and permits a later retry.

## 6. Equipment-state comparison rules

1. Snapshot every equipped slot needed to compute the model's whole-loadout five-stat input, even though only the listed V1 candidate slots can be replaced.
2. Require the active Arms Warrior capability, preferred plate armor for armor slots, player usability/equippability, resolved item facts, and a baseline material-effect context allowed by the capability record. If current weapon/trinket/tier/effect context is outside the model's validated envelope, return `BASELINE_EFFECT_CONTEXT_MISMATCH`; do not transfer the fixed Ret single-target Spike B context to Arms/AoE.
3. Current baseline uses exact resolved equipped links and `as_observed_v1` stats. A candidate state is formed by structural replacement, then aggregate stats are recomputed/delta-checked from immutable snapshots.
4. Single physical slots: candidate must match the allowed inventory type and replaces only that slot.
5. Ring candidate: enumerate exactly two states:
   - candidate in slot 11, original slot 12 retained;
   - original slot 11 retained, candidate in slot 12.
6. For each ring state, reject duplicate exact GUID use and unique-category/count violations. The candidate may replace itself if the tooltip is the equipped instance only through an explicit no-change state; it may never occupy both slots.
7. Evaluate every valid complete ring state independently. Select the highest modeled candidate log score. Preserve the other state in `alternatives`.
8. If both ring replacements' delta intervals overlap each other within the model uncertainty/tie policy, return a deterministic chosen state for reproducibility but present “either ring slot is effectively tied”; do not assert the slot difference is material.
9. Baseline and candidate must both fall inside model domain. A supported candidate cannot erase an unsupported baseline component.
10. Future ranks repeat enumeration and validation independently for every actual reachable rank. Do not assume monotonicity and do not binary-search the first upgrade.

## 7. Current-season projection and manifest validation

Projection is an evidence-gated capability, not generic link manipulation.

1. `ArtifactManifest.lua` names the exact season-manifest hash, schema, target product, patch/build allowlist, generation time, source content hash, fixture report hash, and validation verdict.
2. At login, compare `GetBuildInfo()` with the allowed build record. A newer/unknown build disables projection with `UNVERIFIED_SEASON_DATA`; current exact-stat comparison may remain available if runtime contracts pass.
3. For the owned candidate require:
   - exact usable `ItemLocation` and GUID;
   - `C_ItemUpgrade.CanUpgradeItem(location) == true` stored without truthiness collapse;
   - exactly one bonus ID matching exactly one active manifest group/rank;
   - ordinary non-crafted/nonlegacy classification;
   - current rank below the manifest maximum.
4. A link-only chat/comparison item may be compared at its exact current stats, but its eligibility is `unknown`, so V1 exposes no future-rank directional advice.
5. Parse the item payload structurally, replace only the recognized rank bonus, and preserve every other field/bonus/modifier/enchant/gem/suffix/context.
6. Resolve each target link asynchronously using the same repository contract.
7. Accept a projected snapshot only when its actual item level equals the exact manifest value and mandatory structured stats resolve. Multiple rank bonuses, missing data, or an unexpected level fail only that projection path with a typed reason.
8. Present current through max reachable ranks; never create lower historical ranks, `7/6`, post-track ranks, crafted ranks, or “max both sides” silently.
9. The baseline stays the currently worn exact state for candidate-investment rows. A ceiling-to-ceiling comparison is outside V1.

## 8. Generated SimC registry, domain, provenance, and abstention

`CapabilityManifest.lua` is the allowlist. A numeric evaluation requires one exact record matching spec, archetype fingerprint, profile, enhancement policy, model schema, artifact set, and compatible baseline effect context.

The V1 model record contains at least:

```lua
{
  modelID = "arms-warrior-mid2-dungeon-aoe-v1",
  family = "piecewise-additive-interaction-grids",
  objective = "relative modeled damage in the pinned dungeon AoE schedule",
  specID = 71,
  archetypeID = "arms-warrior-mid2-dungeon-aoe-v1",
  profileID = "dungeon_aoe",
  talentFingerprint = "<generated portable fingerprint>",
  wowBuild = 69587,
  simcCommit = "<pinned Arms/AoE generation commit>",
  simcBuild = "<pinned build string>",
  profileSHA256 = "<generated Arms/AoE profile hash>",
  samplingSeed = "<declared independent seeds>",
  trainingBounds = { ... },
  hardDomain = { ... },
  uncertaintyPP = "<calibrated Arms/AoE envelope>",
  materialityPP = 0.5,
  validation = { heldoutPairs = "<generated>", winnerGT1 = "<generated>", winnerGT0_5 = "<generated>", confidentSignErrors = 0 },
  payloadSHA256 = "<generated>",
}
```

The Arms/AoE production artifact must be generated and validated from scratch across the planned representative base-state and independent-seed suite before numeric advice is enabled. The Ret single-target Phase 0 numbers remain provenance for the architecture spike, not coefficients, uncertainty, or an automatic public-release claim for Arms.

Runtime model policy:

1. Select by exact portable talent fingerprint. No nearest-build fallback in V1.
2. Validate each five-stat whole-loadout vector against every hard bound before evaluation. Any input outside the domain returns `OUT_OF_MODEL_DOMAIN`; there is no extrapolation.
3. Evaluate the bounded piecewise-additive/pair-grid payload to a log score. Compute `D = 100 * (exp(candidateLog - baselineLog) - 1)`.
4. Use the artifact's deterministic uncertainty half-width `U`; do not label it a personal DPS confidence interval.
5. With materiality `M = 0.5` percentage points:
   - `upgrade` only when `D - U > M`;
   - `downgrade` only when `D + U < -M`;
   - otherwise `too_close` with `UNCERTAINTY_OVERLAPS_MATERIALITY`.
6. If either state, model context, or provenance gate fails, return `unsupported`; never widen uncertainty to disguise an out-of-domain result.
7. UI rounds `D` to one decimal only after the decision. Stored comparisons use full precision.
8. Copy must say “modeled difference for the supported Arms build in the pinned AoE profile,” never “your DPS will change by”.

## 9. Fail-closed classification matrix

Classification runs after complete structured resolution and before model selection/scoring.

| Detection | V1 outcome | Required reason |
|---|---|---|
| Inventory type weapon/main/off/2H/ranged/shield/holdable | `unsupported` | `WEAPON_UNSUPPORTED` |
| Inventory slot trinket | `special` | `TRINKET_UNSUPPORTED` |
| Tooltip line type `ItemSpellTriggerOnUse`, `...OnEquip`, or `...OnProc` | `special` | `SPECIAL_EFFECT_DETECTED` |
| `GetItemSpell`/first triggered spell or generated special-item manifest match | `special` | specific effect reason |
| `setID` or specialization set-bonus evidence | `special` | `TIER_UNSUPPORTED` |
| Embellishment/crafted special evidence | `special` | `SPECIAL_EFFECT_DETECTED` |
| Crafted item requested at a future quality/rank | `unsupported` | `CRAFTED_PROJECTION_UNSUPPORTED` |
| Unknown stat key, effect bonus, incomplete tooltip effect probe, or contradictory evidence | `pending` while resolvable, otherwise `special`/`unsupported` | `UNKNOWN_STAT_KEY` or typed evidence reason |
| Legacy/PvP/timewalking/heirloom/context scaling | `unsupported` | category-specific reason |
| Ordinary supported inventory type with no special evidence | continue | none |

No localized `leftText`, track name, item name, or color participates in classification. An absent effect line is accepted as ordinary only after the structured tooltip/item probes are complete. V1 does not show a visible-stats-only directional recommendation for a special item.

## 10. Blizzard-default tooltip presentation

Register exactly one item post-call via `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)`. Do not hook `SetBagItem`, `SetInventoryItem`, `SetHyperlink`, legacy `OnTooltipSetItem`, or third-party internals.

Default block, target 2–6 lines:

```text
BETTER GEAR ADVISOR
▲ Upgrade  +2.1% modeled (AoE profile)
At 6/6: ≈ Too close
Replaces: Ring 1 — <item>
Shift: ranks  Alt: evidence
```

Outcome mapping:

- `pending`: one gray “Loading item data…” line or no block; never a temporary downgrade.
- `upgrade`: green arrow/text plus modeled delta and exact replaced slot.
- `downgrade`: red arrow/text plus modeled delta; wording remains scoped to the supported model, never sell/destroy.
- `too_close`: yellow/neutral “Too close to call”; a center estimate may be shown only as estimate, not directional advice.
- `special`: purple “Special item — not evaluated reliably”; no overall percentage.
- `unsupported`: gray explanation using the highest-priority reason code.

Shift lists every reachable verified rank, its item level, outcome, rounded center estimate where numeric, and first **confirmed** upgrade. Alt lists capability/profile, interval/uncertainty, exact removed/retained ring, enhancement policy, client/model/manifest versions, and reason codes. Color never carries meaning alone.

`TooltipPresenter` receives only `EvaluationResult` and localization; it cannot access WoW item APIs. Render is deterministic and idempotent. Only bag, equipped/character, chat/ItemRef, and comparison frames are release-qualified in V1.

## 11. Offline generation pipeline and release gates

Pipeline order:

1. Verify the pinned SimC executable/source commit/build/profile hashes; refuse drift unless the lock update is explicit and reviewed.
2. Generate versioned stat-space samples and independent splits/seeds; retain source CSV, profilesets, raw SimC JSON/log, and mean errors.
3. Fit challenger models; select only by the declared validation rule, never by held-out test tuning.
4. Validate item-like pair decisions, adversarial DR/domain points, representative base states, talent fingerprint scope, and confidence abstention.
5. Export deterministic Lua, run Lua 5.1 syntax, Python/Lua golden-vector agreement, out-of-domain, size, and runtime checks.
6. Generate the pinned season manifest from structured versioned data, then validate against live captured projection fixtures. No HTML scraping.
7. Generate the conservative special-item/tier classification manifest and a coverage report. Unknown evidence must map to fail-closed.
8. Hash all artifacts and emit one `ArtifactManifest.lua`; generated files are never hand-edited.
9. Run all pure Lua/contract/golden tests against the exact artifacts.
10. Build the addon zip from an allowlist, inspect contents, and emit a release report/capability matrix.

Blocking gates:

- Artifact schema/provenance/hash mismatch or an unpinned input.
- Model fails its declared winner/sign/abstention gates, any high-confidence adversarial sign error, cross-language mismatch, or nonzero out-of-domain coverage.
- Projection fixture mismatch, ambiguous current rank, unexpected projected item level, or stale client build.
- Numeric result for any unknown effect, tier, trinket, weapon, unsupported archetype, or unsupported baseline effect context.
- Stale callback can publish, pending becomes zero, ring legality fails, or tooltip duplicates/refresh-loops.
- Packaged code performs network access, imports old addon code/data, or requires a third-party addon.
- Missing license/redistribution review for generated inputs/output.
- Before public release specifically: the genuinely uncached live refresh and stale-rejection integration scenario must pass. Loot/merchant/journal remain non-gates.

## 12. Test plan and Phase 0 regressions

### Pure Lua tests

- Canonical keys distinguish same item ID with different full links, rank bonuses, gems, enchants, GUIDs, and contexts.
- Item snapshots reject missing structured data and preserve explicit stat zero versus unavailable.
- Single-slot and both ring-slot enumeration; legal winner, unique limit, duplicate GUID, equipped-candidate no-op, tie, and bag-order determinism.
- Input immutability and deterministic result serialization/reason ordering.
- Exact manifest match, exactly-one-rank-bonus invariant, unrelated-link-field preservation, current-to-max rank iteration, old season, max rank, crafted, unknown build, multiple known bonuses, projected-level mismatch.
- Model golden vectors, Python/Lua tolerance, hard-domain boundaries, log-delta conversion, uncertainty/materiality truth table, and widening-uncertainty monotonicity.
- Special/tier/trinket/weapon/unknown-stat classification suppresses numeric results.
- Presenter goldens for every status and ring alternative; localized text changes presentation only.

### Adapter and deterministic scheduler tests

- Synchronous cached callback: dependency fan-out count is initialized before subscription and completion publishes once.
- Duplicate callback: idempotent request ID prevents double completion.
- `GetItemInventoryType` is called with `ItemLocation`; link fallback calls `GetItemInventoryTypeByID`.
- Location-aware `CanUpgradeItem == false` remains boolean false, not nil/unknown.
- Primary hovered item is never replaced by automatic `ShoppingTooltip1/2` capture.
- Uncached success, failure, timeout, retry, two coalesced tooltips, one waiter cancellation, hide-before-complete, A→B→C with C/B/A callbacks, equipment/spec/talent/artifact change at every await boundary.
- Completion causes refresh only; stale completion never writes lines directly.
- One render signature per tooltip generation and no refresh loop.

### Reused Phase 0 fixtures

- Import all eight upgrade fixtures and assert the existing 15 captured projection rows/11 unique projected states, plus crafted/max-rank/old-season fail-closed behavior.
- Keep the 1,336 held-out SimC pair report and Lua vectors as provenance/goldens; production regeneration adds evidence rather than replacing the Phase 0 record.
- Re-run the seven offline lifecycle scenarios and the seeded 100,000-transition stress suite against production state-machine contracts.
- Replay the live report as a contract fixture for supported frames, balanced load starts/readies, equipment revisions, duplicate suppression, and protected-action expectations.

### Live integration tests

Run with default Blizzard UI only, taint logging enabled, and a developer diagnostic addon:

- bags with primary and both shopping frames;
- character/equipped items and equipment revision while open;
- chat links, `ItemRefTooltip`, and ItemRef comparison frames;
- comparison tooltip isolation and duplicate suppression;
- current-season eligible projection and old-season/current-max rejection;
- spec/talent change invalidation;
- missing data produces no numeric recommendation;
- combat/taint smoke test with no blocked/forbidden protected action;
- ruRU and enUS presentation with identical domain decisions;
- **pre-release focused gate:** a genuinely uncached load refreshes the still-current tooltip, and close/rapid item change causes a logged stale rejection with no late block.

Loot, merchant, and encounter journal are not in this matrix for V1.

## 13. Patch and season update procedure

1. Freeze the current released artifact set and create a new candidate set; never overwrite provenance in place.
2. Record Retail patch/build and diff Blizzard API documentation/contracts used by adapters.
3. Regenerate the season manifest from pinned structured sources and review group/rank/bonus/item-level/currency diffs.
4. Capture/validate representative live current-season items and retain at least the old-season, crafted, max-rank, socketed, ring, neck, and armor regressions. Expand tracks/sources as obtainable without relabeling missing evidence.
5. Review class tuning, talents, APL, profile, stat rules, item effects, and baseline equipment context. Any material change invalidates the affected capability until its model is regenerated.
6. Update SimC lock/profile hashes, generate new samples, refit, validate, and review the machine report. Never carry the old uncertainty envelope forward silently.
7. Regenerate special-item classification and review newly unknown or changed spell/effect IDs.
8. Run pure Lua, adapter, artifact, golden, packaging, default-UI, locale, taint, and uncached/stale live gates.
9. Publish an explicit capability diff: supported/removed archetype, build range, model hash, manifest hash, uncertainty, and known exclusions.
10. If live data are not yet qualified, release no projection/model claim for that path. A fail-closed temporary unsupported result is the intended patch-day behavior.

## 14. Staged implementation sequence after approval

### Stage 0 — repository boundary and contracts

Create the new folder, TOC, namespace, Core result/reason/key contracts, port interfaces, test runner, and packaging allowlist. Add an automated rule that rejects imports/references to root-level BetterGearCompare runtime modules.

Acceptance: addon skeleton loads with default UI but registers no tooltip behavior; pure contract tests pass; packaged zip contains only the new addon; no old code/data dependency exists.

### Stage 1 — pure item/state domain

Implement `ItemLink`, immutable snapshots/states, ordinary/special classification types, single-slot and ring enumeration, and legality/unique-instance validation using recorded normalized fixtures.

Acceptance: both ring alternatives and all rejection paths pass; permutation/property tests are deterministic; no domain file references Blizzard APIs or frames; unknown/special inputs cannot reach scoring.

### Stage 2 — model registry and confidence engine

Formalize generated schemas, import the validated pilot payload as a development artifact, implement exact capability selection, hard-domain checks, log-score deltas, and abstention policy.

Acceptance: Lua golden vectors match; out-of-domain is always unsupported; interval overlap always becomes `too_close`; result provenance is complete; documentation explicitly avoids universal-DPS wording.

### Stage 3 — projection domain and artifact circuit breaker

Implement structural rank parsing/substitution, exact manifest matching, eligibility contract, per-rank verification, and client-build circuit breaker without live API calls in Domain.

Acceptance: all Phase 0 upgrade fixtures pass, including old-season/crafted/max-rank negatives; only current/future legal ranks appear; unexpected item level disables that rank; unrelated link fields remain byte-equivalent.

### Stage 4 — Blizzard adapters and repositories

Implement item/inventory/character/upgrade adapters, revision counters, coalescing item repository, equipment repository, timeout/retry, and deterministic coordinator using fake ports first.

Acceptance: every asynchronous interleaving passes; synchronous callback fan-out cannot finish early; false eligibility is preserved; correct inventory-type API overload is used; no nil-to-zero path exists; stale tokens cannot publish.

### Stage 5 — pure evaluation orchestration

Combine context/capability checks, baseline guard, enumeration, rank projection, model scoring, best-state/tie selection, future rows, and typed result construction. Add versioned bounded caches.

Acceptance: golden complete-state decisions pass; both rings are considered at every rank; cache keys include full identity/revisions/model/manifest/policy; pending is never final-cached; unsupported components dominate numeric paths.

### Stage 6 — default tooltip and diagnostics

Add the single post-call, weak per-tooltip state, refresh-only completion, deterministic presenter, enUS/ruRU strings, modifier details, settings, and privacy-safe debug export.

Acceptance: one block per render signature; no shopping-tooltip cross-contamination; hide/key/revision change cancels the view; all six outcomes render correctly; only supported V1 sources are claimed; no third-party dependency or protected action.

### Stage 7 — production data pipeline

Turn Phase 0 prototypes into pinned production generators/schemas/reports. Add representative base-state and extra-seed model validation, talent fingerprint generation, baseline effect-context definition, special classification audit, artifact hashing, and release packaging validation.

Acceptance: a clean offline build reproduces byte-identical Lua artifacts from locked inputs; all model/artifact gates pass; license/provenance review is recorded; model size/runtime budgets pass; one exact Arms/AoE capability is published and everything else is absent/unsupported.

### Stage 8 — in-client qualification and release candidate

Run the default-UI matrix on the target Retail build and record anonymized fixtures. Exercise the deferred-from-Phase-0 genuinely uncached refresh and stale-callback rejection.

Acceptance: required bag/character/chat/comparison sources pass; genuinely uncached refresh and live stale rejection pass; no duplicate/late block, unresolved-data recommendation, refresh loop, or blocked protected action; projection fixtures match the release manifest; loot/merchant/journal remain explicitly deferred.

### Stage 9 — limited technical-preview release

Publish the capability matrix, provenance, exclusions, patch circuit-breaker behavior, and known limitations with the packaged addon.

Acceptance: every advertised capability maps to a passing artifact and live gate; no exact support is implied beyond the named Arms archetype and pinned AoE schedule; rollback to the prior artifact set is documented; user-visible wording has been reviewed for false precision.

## Approval checkpoint

Implementation was explicitly approved after review, with the first target changed to Arms Warrior AoE. The approval does not weaken any release gate: numeric advice and projection stay disabled until their Arms/AoE model and production season artifacts pass the declared validation, and public release still requires the focused live uncached/stale-callback check.
