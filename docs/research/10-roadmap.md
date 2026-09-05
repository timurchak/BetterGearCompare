# Roadmap

## Delivery principle

Ship a narrow advisor that is trustworthy before expanding item and spec coverage. Coverage is a declared capability matrix, not an aspiration hidden behind fallback math. Every phase must remain useful with Blizzard's default UI and without a runtime web service.

## Phase 0 — validation spikes

Time-box the risks that could invalidate the product before building polished UI.

### Client API spike

- Capture real 12.1 responses from `C_Item.GetItemUpgradeInfo`, `C_ItemUpgrade.CanUpgradeItem`, `C_Item.GetDetailedItemLevelInfo`, `C_Item.GetItemStats`, `C_Item.GetItemStatDelta`, uniqueness/spec APIs, item spell APIs, and tooltip data.
- Verify full-link rank-bonus substitution across representative current-season tracks, sockets, gems, enchants, crafted items, and items with several bonus IDs.
- Confirm each projected link resolves asynchronously to the manifest's expected item level and stats.
- Verify old-season behavior with owned items, not only database links.
- Verify `TooltipDataProcessor` refresh/idempotence on the exact target client build.
- Capture anonymized regression fixtures.

Exit criterion: current-season ordinary-item rank projection is reproducible and fails closed. If arbitrary-rank stat snapshots cannot be produced robustly, revise V1 to compare current items only rather than parsing localized tooltips.

### Simulation surrogate spike

- Select one well-maintained DPS specialization and one single-target profile.
- Generate a deliberately broad sample in primary stat, total secondary budget, secondary distribution, and relevant weapon features.
- Benchmark local linear weights, global quadratic response, sparse multilinear interpolation, and the recommended piecewise-additive spline plus selected pair interactions.
- Validate pairwise upgrade deltas on held-out and adversarial samples.
- Measure serialized Lua size and evaluation cost.

Exit criterion: the surrogate meets the accuracy gates in [the test plan](09-test-plan.md#simulation-model-validation) at acceptable data size. If it does not, do not compensate with population averages; narrow the modeled domain or use a denser/local model.

### State-legality spike

- Prototype the pure ring and weapon-state enumerator with recorded item fixtures.
- Prove exact-instance, unique-equipped, two-hand/off-hand, dual-wield, and shield cases.
- Identify rules that the client APIs do not expose reliably and encode those cases as unsupported.

Exit criterion: the enumerator never needs an item-level-only or “double a one-hander” shortcut.

## V1 — smallest useful trustworthy advisor

V1 should answer the core “keep this ordinary item?” question for a deliberately limited set of DPS specs.

### Included

- A new clean addon/package; the prototype is not the runtime foundation.
- Blizzard-default item tooltips through one `TooltipDataProcessor` integration.
- Asynchronous exact-item resolution, revision-safe refresh, and typed failures.
- Current equipped-state comparison for ordinary head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, and rings.
- Correct enumeration of both ring replacement slots and unique-equipped validation.
- Current Midnight 12.1 six-rank track manifest and verified rank projections for eligible current-season non-crafted items.
- “now,” maximum eligible ordinary-track rank, and first meaningful upgrade rank.
- One single-target and one dungeon profile for a pilot set of roughly three to five DPS specializations whose generated models pass validation.
- Deterministic high/medium/too-close/unsupported confidence and action wording.
- Enhancement normalization policy for ordinary sockets/gems/enchants, with details disclosure.
- Explicit guards for any effect-bearing, set-transition, crafted-future-quality, legacy-scaling, PvP-scaling, weapon, and trinket case outside the capability manifest.
- Shift/details view with all meaningful ranks, removed slot, profile, uncertainty, reasons, and data provenance.
- Pure Lua regression suite, real-link fixtures, generator validation, model validation report, and patch-day circuit breaker.
- No runtime network and no required third-party addon.

The first public build should be labeled a limited-spec technical preview until patch-day operation and model calibration have been observed in the wild.

### Why weapons and special trinkets are not in the smallest V1

Weapons require complete companion enumeration and a spec-sensitive damage model. Special trinkets require an item-specific effect corpus and interaction rules. Both can be done, but including them before the ordinary-item pipeline is proven greatly increases the chance of a deceptively complete but wrong product. V1 should show a useful transparent warning for them.

## V1.5 — complete ordinary DPS equipment states

Expand only after V1 telemetry and bug fixtures demonstrate stable async and season behavior.

- Extend validated surrogate coverage to all DPS specializations/build archetypes that meet the gates.
- Add one-hand/two-hand/off-hand/shield/dual-wield state enumeration using equipped items, bags, and the candidate only.
- Add spec-specific weapon features and validate weapon deltas against SimulationCraft.
- Support simple trinkets whose value is completely represented by structured ordinary stats.
- Evaluate tier-tagged items only when the active set-bonus state is unchanged and no unmodeled effect remains.
- Add clearer build-archetype selection and explain unknown-talent fallbacks.
- Add model-domain/uncertainty visualization and fixture export.
- Automate build-time manifest generation and client-build compatibility checks.
- Consider an optional compact character-window details view; keep the default tooltip terse.

V1.5 is the point at which the addon can reasonably answer the user's one-hand-versus-two-hand question, because it can name the exact off-hand or second weapon used in the winning legal configuration.

## V2 — curated special effects and planning

- Generate and ship a reviewed per-spec/profile special-effect catalog with item-level knots and uncertainty.
- Add trinket pair policies and explicit pair corrections where validation demonstrates non-additivity.
- Support selected special weapons, embellishments, rings, and set transitions only when their SimulationCraft representation and effect identity are stable.
- Add automated effect-catalog diffs and “recognized item changed spell/model” circuit breakers.
- Explore healer and tank decision support as separate multi-objective products; do not reuse a DPS percentage label.
- Add a cost-efficiency planner using exact, current cost data only where the APIs and context support it. Keep cost/crest recommendations outside the basic tooltip.
- Evaluate crafted recraft/quality projections and post-track upgrade systems such as Venomstone-style improvements only after their structured representation is verified.
- Add optional third-party tooltip adapters behind the core interface if users request them; never make them required.

## Explicitly not in the initial product

- Runtime calls to Archon, Wowhead, Raidbots, Warcraft Logs, Raider.IO, or any other web service.
- Website scraping as a required build pipeline.
- Average-player stat distributions converted into weights.
- A user-facing global Pawn-style stat-weight answer presented as precise truth.
- A BiS/popularity browser copied from `PopularSlotsAndChants`.
- Unknown proc/on-use trinkets, special weapons, embellishments, unusual rings, or set-bonus transitions receiving an overall percentage.
- Healing or tank survival compressed into the same single DPS score.
- Legacy, Timewalking, heirloom, PvP-context, or future crafted-quality projections without a separately proven model.
- Venomstone/post-track projection represented as additional normal upgrade ranks.
- Bank/warband-bank searching for weapon companions in the default comparison.
- Automatic equipping, selling, destroying, upgrading, or purchase recommendations.
- Exact upgrade-cost planning from stale static tables or link-only metadata.
- Third-party bag, tooltip, UI replacement, or auction-addon dependencies.
- Item-level-only arrows, doubling one-hand weapon scores, arbitrary trinket-tier percentages, or localized track-name parsing.
- Promising every specialization and build on day one.

## Implementation sequence

1. **Repository boundary:** create the clean addon tree and a separate build-tools area; preserve the existing prototypes only as research/fixture sources.
2. **Contracts and fixtures:** define typed snapshots, states, results, reason codes, capability records, and generated-data schemas before writing a tooltip.
3. **Pure state engine:** implement and exhaustively test normal slots and rings, then weapon enumeration behind a disabled capability flag.
4. **Client adapters:** implement exact item loading, normalization, live eligibility, character context, and revision tracking against recorded contracts.
5. **Season generator:** produce the signed/pinned manifest, projection verifier, schema checks, and patch circuit breaker.
6. **Simulation pilot:** build the reproducible SimC sampling/fitting/validation pipeline and ship the first limited capability records.
7. **Evaluation and confidence:** combine complete-state scoring, uncertainty, rank threshold, and transparent actions.
8. **Default tooltip:** add the single modern hook, async refresh, idempotent presentation, details, and diagnostics.
9. **Client qualification:** run real-link, locale, combat/taint, old-season, and patch mismatch tests.
10. **Coverage expansion:** add specs, weapons, and effects only through reviewed capability/data changes.

## Data maintenance cadence

### Every client patch

- diff generated Blizzard API documentation and live client behavior;
- rerun adapter and tooltip smoke tests;
- invalidate any model affected by class tuning, talent, item, stat, or encounter-profile changes;
- publish capability changes rather than silently retaining stale support.

### Every season

- regenerate and verify the entire track/rank/bonus/item-level/currency manifest;
- capture old-season eligibility fixtures;
- regenerate supported ordinary models from a pinned SimulationCraft commit/APL/profile;
- regenerate special-effect curves for supported items;
- review model error, Lua size, and unsupported coverage;
- update user-visible season/model provenance.

### Between seasons

- accept bug reports as anonymized fixtures;
- add regression tests before fixes;
- monitor SimulationCraft representation changes and Blizzard hotfixes;
- release data-only updates when possible, but retain schema and compatibility guards.

## Go/no-go gates

Proceed to a V1 public release only if:

- exact current-season rank projection works across representative live items;
- the pilot surrogate passes its published error and sign gates;
- async tooltip refresh has no stale-result or duplicate-line failures;
- ring state and uniqueness tests pass;
- unknown effects and set transitions reliably suppress numeric recommendations;
- generated artifacts are reproducible and legally redistributable;
- the addon works with only Blizzard UI enabled.

Pause or narrow the product if any one of those conditions cannot be made deterministic. The most acceptable scope reduction is fewer supported specs/items; the least acceptable compromise is displaying a precise answer from an unverified fallback.

## Success measures

Measure correctness and clarity rather than recommendation coverage alone:

- zero known high-confidence sign errors;
- percentage of tooltips producing a supported, too-close, or explicit unsupported outcome;
- item-load completion/failure and stale-result discard rates;
- projection-verification failure rate by build and track;
- model validation metrics by capability;
- number of bug reports reproducible from exported fixtures;
- user comprehension of “now,” “at max,” chosen replacement, and warning states.

