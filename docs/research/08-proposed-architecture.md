# Proposed architecture

## Architectural decision

Build a new addon around a pure loadout evaluator. Do not incrementally untangle the prototype. The parts worth retaining are requirements and captured item fixtures, not the current module boundaries or control flow.

The central operation is:

```lua
local result = evaluator:Evaluate({
    currentState = equipmentState,
    candidate = candidateItem,
    requestedRanks = { 1, 2, 3, 4, 5, 6 },
    context = {
        specID = 70,
        archetypeID = "ret-default-season2",
        profileID = "single-target",
    },
})
```

It accepts immutable data and returns immutable data. It does not know that a tooltip exists.

## Dependency direction

```text
Blizzard UI events and tooltips
            |
            v
Application coordinator and presentation
            |
            v
Pure domain evaluator <---- generated, versioned data
            ^
            |
Blizzard API adapters and asynchronous item repository
```

The domain layer must not call `GameTooltip`, register events, inspect bags, or wait for item data. Blizzard API calls live behind adapters. Generated data is immutable for an addon release and is an input to the evaluator, not hidden global state.

## Proposed packages

### `GeneratedData`

Build artifacts produced outside the game:

- `SeasonManifest`: season identifier, build range, upgrade tracks, rank bonus IDs, expected item levels, currency IDs, and provenance.
- `ModelRegistry`: one validated ordinary-stat model per supported spec, build archetype, and encounter profile.
- `EffectCatalog`: recognized item/spell effects, per-spec effect curves, pair policies, and uncertainty.
- `CapabilityRules`: supported specs, profiles, inventory types, and explicit exclusion reasons.

Every artifact carries schema version, generator version, upstream version or commit, input hashes, generation time, and validation metrics. Runtime code refuses an incompatible schema and downgrades expired or mismatched season data to `UNVERIFIED_SEASON_DATA`; it must not silently reuse old constants.

### `Platform`

Thin wrappers over the live client:

- `ItemRepository` resolves full item links into normalized snapshots, coalesces duplicate load requests, and reports pending/ready/failed states.
- `InventoryAdapter` captures equipped items and eligible bag companions with stable item GUIDs and locations.
- `CharacterAdapter` captures class, spec, level, talent/loadout fingerprint, dual-wield capability, and other eligibility facts.
- `UpgradeAdapter` asks `C_Item.GetItemUpgradeInfo` for metadata and `C_ItemUpgrade.CanUpgradeItem` for the owned item's present eligibility.
- `TooltipAdapter` owns the single Blizzard tooltip callback and refresh behavior.
- `Clock` and `Logger` make timeout and diagnostic behavior testable.

Wrappers return explicit results such as `{ status = "pending" }` or `{ status = "failed", reason = "ITEM_DATA_LOAD_FAILED" }`. `nil` must never ambiguously mean zero stats, unsupported, uncached, or not equippable.

### `Domain`

- `ItemNormalizer` converts API results into a canonical `ItemSnapshot`. It separates inherent stats, socket capacity, inserted gems, enchantments, tertiary stats, structured spell/effect evidence, set membership, and upgrade metadata.
- `EquipmentState` is the complete equipped configuration plus the finite companion-item pool allowed for this evaluation.
- `LoadoutEnumerator` constructs possible successor states: each ring slot, each trinket pair, and every legal complete weapon configuration.
- `LoadoutValidator` applies slot, handedness, armor, class/spec, unique-equipped, exact-instance, and known capability rules. Unknown rules reject a state instead of assuming it is legal.
- `RankProjector` creates and verifies a candidate snapshot at each requested current-season rank, as described in [the upgrade-system chapter](02-wow-item-and-upgrade-system.md#projecting-a-current-season-rank).
- `OrdinaryPerformanceModel` evaluates supported visible-stat configurations with the pinned SimulationCraft surrogate.
- `SpecialEffectEvaluator` handles only effects present in the generated catalog. It never falls back to treating effect text as ordinary stats.
- `SetStateGuard` detects set-bonus transitions and requires a supported set-interaction model.
- `EvaluationEngine` scores current and candidate states, chooses the best legal replacement, and calculates deltas and the first worthwhile rank.
- `ConfidencePolicy` derives an evidence interval, category, reason codes, and permitted user-facing language.

This grouping is slightly smaller than the initially suggested module list. In particular, `WeaponEvaluator` should not be a separate scoring engine: weapons need special state enumeration, but the resulting complete state should use the same evaluator. Likewise, cache and diagnostics are infrastructure services rather than domain concepts.

### `Application`

- `EvaluationCoordinator` takes UI requests, captures a revision-consistent context, resolves missing item data, submits a pure evaluation, and discards stale completions.
- `EvaluationCache` stores successful normalized snapshots, projections, and final results under versioned keys.
- `Diagnostics` records reason codes and optionally exports a privacy-safe fixture for bug reports.
- `Settings` selects profile and display density; it cannot turn an unsupported case into a supported one.

### `Presentation`

- `TooltipController` integrates with Blizzard's tooltip data pipeline.
- `TooltipPresenter` maps typed results to concise localized lines. It performs no calculations.
- `DetailsPanel` provides the all-ranks table, compared configuration, uncertainty explanation, and provenance on demand.
- `OptionsPanel` exposes profile choices and diagnostic controls.

Third-party tooltip adapters, if ever added, depend on the same coordinator and presenter. They are optional packages, not core dependencies.

## Core data contracts

An illustrative normalized item:

```lua
ItemSnapshot = {
    key = "full-link-and-instance-identity",
    itemID = 123456,
    itemGUID = "Item-...",       -- present for owned instances
    fullLink = "|c...|Hitem:...|h[...]|h|r",
    inventoryType = "INVTYPE_CHEST",
    quality = 4,
    currentItemLevel = 305,
    requiredLevel = 90,
    stats = {
        strength = 1032,
        stamina = 2241,
        crit = 510,
        haste = 0,
        mastery = 478,
        versatility = 0,
    },
    weapon = nil,                -- or handedness, speed, min/max damage
    sockets = { "PRISMATIC" },
    insertedGems = {},
    enchantmentID = nil,
    tertiaryStats = { leech = 0, avoidance = 0, speed = 0 },
    setID = nil,
    effectEvidence = {},         -- structured item spell / tooltip line types
    upgrade = {
        trackID = 617,
        trackName = "Hero",
        rank = 1,
        maxRank = 6,
        liveEligibility = true,
        manifestVerified = true,
    },
}
```

The public result is deliberately typed:

```lua
EvaluationResult = {
    status = "SUPPORTED",        -- PENDING, UNSUPPORTED, FAILED
    replacement = {
        slots = { 11 },
        removedItemKeys = { "..." },
        companionItemKey = nil,
    },
    ranks = {
        {
            rank = 1,
            actualItemLevel = 305,
            deltaPercent = -1.7,
            uncertaintyPercent = 0.35,
            confidence = "HIGH",
        },
    },
    firstWorthwhileRank = 4,
    action = "KEEP_FOR_UPGRADE",
    reasonCodes = {},
    provenance = {
        modelID = "...",
        seasonManifestID = "...",
        effectCatalogID = "...",
    },
}
```

Unsupported results still identify the rejected configurations and precise reasons, for example `NO_VALID_OFFHAND`, `UNKNOWN_SPECIAL_EFFECT`, `SET_BONUS_TRANSITION`, `MODEL_ARCHETYPE_MISMATCH`, or `RANK_PROJECTION_UNVERIFIED`.

## Evaluation flow

1. Capture candidate key, equipment revision, inventory revision, spec/talent fingerprint, profile, and generated-data versions.
2. Resolve every required owned item and candidate through `ItemRepository`.
3. Classify effects and set membership before scoring.
4. Ask `LoadoutEnumerator` for complete successor states and `LoadoutValidator` to retain only proven-valid ones.
5. For each meaningful candidate rank, project and verify the candidate snapshot.
6. Score current and candidate states with the ordinary model, then add only recognized effect/set corrections.
7. Select the highest supported legal candidate state for each rank. Preserve ties and near-ties instead of inventing a decisive slot choice.
8. Compute the uncertainty interval and confidence category.
9. Produce a typed result and cache it only if the captured revisions still match.
10. Present the compact result; make the compared state and reason codes available in details.

The current worn state remains fixed when answering “if I upgrade this item.” A separate ceiling-to-ceiling view may compare both upgrade maxima, but the two questions must never be mixed.

## Asynchronous item-data design

Item information is an asynchronous dependency, not an exceptional edge case. A request has this state machine:

```text
NEW -> RESOLVING -> READY -> EVALUATING -> COMPLETE
                 \-> FAILED
       any state --new revision/item--> STALE (discard)
```

`ItemRepository` should:

- request data with an `Item` object and `ContinueWithCancelOnItemLoad` when cancellation is needed, using `C_Item.RequestLoadItemData`/`ITEM_DATA_LOAD_RESULT` where appropriate;
- coalesce waiters by a canonical full-link key rather than only `itemID`;
- retain the full item link because bonus IDs, gems, enchantments, modifiers, and context distinguish instances;
- apply a bounded retry/timeout policy and never convert a timeout into zero stats;
- avoid permanent negative caching because a later client response can succeed;
- return a cancellation token tied to request and state revisions.

The coordinator rechecks all captured revisions before publishing. A late result for a tooltip that now shows another item, a changed bag, a new spec, or a changed talent loadout is discarded.

## Cache design

Use separate caches because their invalidation scopes differ:

| Cache | Key includes | Invalidate when |
|---|---|---|
| Item snapshot | canonical full link, owned GUID where relevant, parser/schema version | item instance changes, socket/enchant changes, schema changes |
| Rank projection | source canonical link, target rank bonus, manifest hash | manifest changes |
| Equipment state | equipment revision, inventory revision, spec/talent fingerprint | equipment, bag, spec, talent, socket, or level event |
| Evaluation | candidate snapshot key, state key, model/profile, manifest/effect versions, display policy version | any component changes |

Successful immutable snapshots may use an LRU cache. Pending entries carry waiters and a generation. Failures should be short-lived and retain their reason. SavedVariables must not persist opaque live item objects; persist only settings and compact diagnostics. Generated models already ship as addon data.

Recommended invalidation inputs include:

- `PLAYER_EQUIPMENT_CHANGED` and `UNIT_INVENTORY_CHANGED` for worn-state changes;
- `BAG_UPDATE_DELAYED` for companion availability;
- `PLAYER_SPECIALIZATION_CHANGED`, `ACTIVE_TALENT_GROUP_CHANGED`, `TRAIT_CONFIG_UPDATED`, `TRAIT_NODE_CHANGED`, and `PLAYER_TALENT_UPDATE` for model context;
- `SOCKET_INFO_UPDATE` for an owned item's gems;
- `PLAYER_LEVEL_UP` for level-scaled or eligibility-sensitive items;
- `ITEM_DATA_LOAD_RESULT` and, where compatibility requires it, `GET_ITEM_INFO_RECEIVED` to complete pending reads.

Events are hints to bump revisions or complete waiters, not invitations to recompute every bag item immediately. Work remains demand-driven.

## Blizzard tooltip integration

Register one supported callback:

```lua
TooltipDataProcessor.AddTooltipPostCall(
    Enum.TooltipDataType.Item,
    function(tooltip, tooltipData)
        TooltipController:OnItemTooltip(tooltip, tooltipData)
    end
)
```

The current supported mechanism is documented by the community API reference for [`TooltipDataProcessor.AddTooltipPostCall`](https://warcraft.wiki.gg/wiki/API_TooltipDataProcessor.AddTooltipPostCall), and Blizzard's live tooltip data structures are visible in [`TooltipInfoSharedDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua). The core addon should not hook `GameTooltip:SetHyperlink`, `SetBagItem`, `SetInventoryItem`, or bag-addon internals.

Safe behavior:

- derive a canonical displayed-item key from tooltip data and the exact link;
- keep weak-key per-tooltip state: displayed key, request generation, rendered signature, and line handles if the current API provides them;
- if data is pending, optionally show one neutral “loading item data” line, then resolve asynchronously;
- when resolution finishes, confirm the tooltip still displays the same key and the coordinator revisions match;
- request a supported data refresh (`tooltip:RefreshData()` on current `GameTooltipTemplate` consumers) and let the post-call render from the ready cache; do not mutate a stale tooltip from a delayed callback;
- make rendering idempotent through a deterministic signature so refresh and repeated post-calls cannot duplicate lines;
- clear state on hide and cancel obsolete requests;
- perform no protected action, equipment change, or insecure frame mutation, including in combat.

The exact availability of `RefreshData` and the tooltip mixin contract should be verified against the target 12.1 client build during the API spike. Blizzard's live [`GameTooltip.xml`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml) currently marks the standard template as supporting data refresh, but that is an implementation detail guarded by a capability check.

Never set an “annotated” flag before a complete result exists. That mistake makes an initial cache miss permanently suppress the answer until the tooltip is reconstructed.

## Patch and season safety

At login, compare the running client build and season evidence against the generated manifest:

- matching supported build and recognized rank mapping: enable projected-rank evaluation;
- newer client build but same verified runtime observations: ordinary current-item comparison may remain enabled, while projections receive a visible “data update required” state;
- unknown track, unexpected rank/item-level result, or modified link that resolves differently from the manifest: stop that path and emit diagnostics;
- incompatible generated-data schema: disable evaluation cleanly.

This is a circuit breaker, not a best-effort guessing system. A tooltip without a projection for several days after a patch is preferable to a confident wrong claim.

## Diagnostics and transparency

The optional details/debug view should expose:

- candidate and removed item links;
- complete configuration chosen at every evaluated rank;
- current/rank scores, delta, uncertainty, and confidence rule;
- model, profile, archetype, season-manifest, and effect-catalog versions;
- rank projection expected versus observed item level;
- unsupported or rejected-state reason codes;
- pending item keys and most recent item-load failure.

A fixture export should omit character name, realm, account identifiers, and unrelated inventory. It should contain normalized data and the exact item links necessary to reproduce the result.

## Suggested source tree

```text
BetterGearAdvisor/
  BetterGearAdvisor.toc
  Generated/
    SeasonManifest.lua
    ModelRegistry.lua
    EffectCatalog.lua
    CapabilityRules.lua
  Platform/
    ItemRepository.lua
    InventoryAdapter.lua
    CharacterAdapter.lua
    UpgradeAdapter.lua
    TooltipAdapter.lua
  Domain/
    ItemNormalizer.lua
    LoadoutEnumerator.lua
    LoadoutValidator.lua
    RankProjector.lua
    OrdinaryPerformanceModel.lua
    SpecialEffectEvaluator.lua
    SetStateGuard.lua
    EvaluationEngine.lua
    ConfidencePolicy.lua
  Application/
    EvaluationCoordinator.lua
    EvaluationCache.lua
    Diagnostics.lua
    Settings.lua
  Presentation/
    TooltipController.lua
    TooltipPresenter.lua
    DetailsPanel.lua
    OptionsPanel.lua
  Locale/
  Tests/
  tools/
```

Names may change, but the dependency boundaries should not. In particular, no file in `Domain` should refer to a Blizzard frame or event.

## Architecture acceptance criteria

Before tooltip polish, the implementation must demonstrate:

1. The same pure input produces byte-for-byte equivalent normalized output and result reason codes.
2. All dual-slot and weapon comparisons enumerate complete, legal states.
3. A cache miss never produces a zero-stat score or permanent missing annotation.
4. A stale asynchronous completion never updates a different item tooltip.
5. Unknown seasons, effects, talent archetypes, and legality rules fail closed.
6. Generated data is traceable and rejected when incompatible.
7. The addon loads and provides its full core experience with only Blizzard's default UI enabled.
