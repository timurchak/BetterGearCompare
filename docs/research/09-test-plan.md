# Test plan

## Quality objective

The primary test oracle is not “a number appeared.” A result is correct only when the addon:

1. resolved the exact item instances;
2. constructed complete legal equipment states;
3. used the intended season, spec, talent archetype, and profile model;
4. handled special and set effects through an explicit supported path;
5. reported uncertainty and support status honestly; and
6. remained correct when item data arrived late or the character state changed.

The suite therefore tests decisions, chosen configurations, reason codes, provenance, and asynchronous behavior in addition to numeric deltas.

## Test layers

### Pure Lua domain tests

Run outside WoW with a small Lua test runner. Mock no frames because domain code has no UI dependencies. Cover:

- link/fixture normalization;
- loadout enumeration and legality;
- rank projection against a pinned manifest;
- ordinary model evaluation;
- special-effect and set guards;
- best-state selection, ties, and first worthwhile rank;
- confidence and action policies;
- cache-key construction and revision checks.

These tests run on every change and require no network.

### Adapter contract tests

Use recorded Blizzard-shaped responses and a fake event loop to verify each adapter's contract. Include `nil`, pending, failure, partial, and changed-instance results. Contract tests should assert that adapter failures become typed statuses, never zero-valued snapshots.

### In-client integration tests

Use a developer build on the target Retail client to capture real item links and verify:

- live API response shapes and return ordering;
- `C_Item` asynchronous behavior;
- actual `C_ItemUpgrade.CanUpgradeItem` results for owned current- and old-season items;
- tooltip refresh/idempotence on Blizzard bags, character sheet, loot, chat links, and merchant views;
- combat behavior and taint logs;
- event invalidation after equipment, talents, specialization, gems, enchants, and bag contents change.

Tests that require particular live items should export anonymized fixtures so most regressions remain reproducible offline.

### Generator and data-schema tests

Build-time tests validate:

- every upgrade track has unique, contiguous ranks;
- every rank bonus resolves to the expected item level on reference items;
- currency and track identifiers are internally consistent;
- generated Lua loads without globals or duplicate keys;
- every model/effect record has complete provenance and compatible schema versions;
- all declared capability combinations have a model and validation report;
- removed or newly unrecognized data produces an explicit manifest diff for review.

### Simulation model validation

Keep training and validation actors separate. Report median, p90/p95, and maximum error in predicted pairwise percentage deltas, sign accuracy by true-delta band, calibration of the uncertainty bound, and errors by region of stat space. Include adversarial points at secondary-stat penalty boundaries, model-domain edges, unusual primary/secondary budgets, and supported weapon transitions.

The proposed initial release gates are:

- median absolute delta error no greater than 0.20 percentage points;
- p95 absolute delta error no greater than 0.60 percentage points;
- at least 98% sign accuracy where the true absolute delta is at least 1.0%;
- no high-confidence sign errors in the adversarial suite;
- at least the advertised coverage of validation cases inside the reported uncertainty interval.

These are engineering starting points, not eternal constants. A release report may tighten them. It may not silently weaken them.

## Fixture policy

Each real-item fixture should store:

- exact full item link and, when necessary, anonymized owned-instance fields;
- client build, locale, character level, class/spec, and captured time;
- raw relevant API returns;
- normalized expected snapshot;
- current-season manifest version;
- why the fixture exists and the bug or rule it protects.

Keep English and at least one non-English locale capture for tooltip classification tests, although localized prose must not be the source of upgrade-track logic. Do not manually synthesize opaque item links when a client-captured link is available.

## Core regression matrix

`Supported` below means the evaluator produces a numeric result only when the active spec/archetype/profile is in the capability manifest. Otherwise the expected result is the corresponding typed unsupported status.

| ID | Scenario | Expected assertion |
|---|---|---|
| U01 | Hero 1/6 ordinary chest versus equipped Hero 6/6 chest | Current rank is evaluated against the worn item; every projected rank is verified; no “upgrade” if none clears the confidence threshold. |
| U02 | Hero 1/6 candidate becomes better at Hero 4/6 | Ranks 1–3 are negative/indeterminate as modeled, rank 4 is the first meaningful positive rank, and action is `KEEP_FOR_UPGRADE`. |
| U03 | Candidate already at Hero 3/6 | Only rank 3 through 6 are presented as actionable; no fictional downgrade to rank 1/2. |
| U04 | Old Hero-track item retains upgrade-looking metadata | Link metadata alone is insufficient; current-season manifest mismatch or failed live eligibility returns `LEGACY_OR_INELIGIBLE_TRACK`. |
| U05 | Current-season owned item cannot be upgraded at the moment | Current comparison remains possible; future-rank recommendation is unavailable unless eligibility rules distinguish a temporary context from permanent ineligibility. |
| U06 | Unknown track/rank bonus after a patch | Projection fails closed with `UNVERIFIED_SEASON_DATA`; current exact-stat comparison may continue. |
| U07 | Modified target-rank link resolves to unexpected item level | Reject the projection and record expected/observed levels. |
| U08 | Adventurer, Veteran, Champion, Hero, and Myth rank endpoints | Each maps to the exact pinned six-rank sequence; no cross-track rank is inferred from name text. |
| U09 | Fully upgraded Hero/Myth item with separate post-track enhancement eligibility | Ordinary ranks stop at 6/6; no invented 7/6 or ordinary rank projection. |
| I01 | `C_Item.GetItemInfo` initially returns unavailable data | Request stays pending; no zero-stat comparison is cached or displayed. |
| I02 | Item load later succeeds | The matching tooltip refreshes once and renders the same result as an initially cached item. |
| I03 | Item load later fails | Show a neutral unavailable reason; allow a later retry; do not permanently annotate the tooltip as complete. |
| I04 | Tooltip changes from item A to B while A loads | A's completion is discarded and never modifies B's tooltip. |
| I05 | Two tooltips request the same full link | One repository load is shared; both current displays can refresh safely. |
| I06 | Same item ID with different bonuses/gems/enchants | They have different canonical keys and normalized snapshots. |
| I07 | Bag or equipment revision changes during evaluation | Completion using the old revision is discarded and recomputed on demand. |
| I08 | Spec or talent archetype changes during evaluation | Old-model result is discarded; cache key cannot collide. |
| S01 | Ring candidate versus slot 11 and slot 12 | Two complete successor states are evaluated and the better legal replacement is selected. |
| S02 | Candidate ring worse than ring A but better than ring B | It replaces B; the tooltip names the removed ring/slot. |
| S03 | Ring results are within the tie tolerance | Result reports both near-equivalent choices or a deterministic tie without pretending the slot choice is material. |
| S04 | Candidate violates unique-equipped category with the retained ring | That state is rejected even if its score is higher; another legal state may win. |
| S05 | Same exact ring instance is considered as its own companion/replacement | Exact GUID reuse is rejected. |
| S06 | Trinket with only ordinary structured stats | Supported only under the declared simple-trinket capability; both trinket replacement states are evaluated. |
| S07 | Proc or on-use trinket absent from effect catalog | No overall numeric recommendation; `UNKNOWN_SPECIAL_EFFECT`. |
| W01 | Two-handed candidate versus current one-hand plus off-hand | Candidate state clears both weapon slots and compares total complete-state value. |
| W02 | One-handed candidate versus current two-hander, no legal off-hand in scope | `NO_VALID_OFFHAND`; candidate is never doubled. |
| W03 | One-handed candidate versus current two-hander, one legal bag off-hand | Candidate plus that exact off-hand is compared with the current two-hander. |
| W04 | Same as W03 with several companions | Enumerate all legal companions and report the winning complete configuration. |
| W05 | Dual-wield spec with candidate one-hander | Enumerate candidate main-hand and off-hand placements only where weapon rules permit; no instance may occupy both. |
| W06 | Shield spec with one-handed candidate | Only valid one-hand plus shield/allowed off-hand states survive; capability is proven from structured character/item data. |
| W07 | Two off-hand-only items | No invalid main-hand state is constructed. |
| W08 | Ranged, artifact-like, or unknown weapon inventory type | Typed unsupported result unless an explicit capability rule exists. |
| W09 | Weapon with recognized damage/speed but unsupported spec weapon model | `UNSUPPORTED_WEAPON_MODEL`; secondary stats alone must not produce an overall score. |
| W10 | Candidate or companion has an unknown special weapon effect | Complete configuration is classified special and withheld, not partially ranked as ordinary. |
| E01 | Ordinary armor with primary and secondary stats | Numeric result from the exact supported model and profile. |
| E02 | Candidate has an empty socket | Socket capacity follows the configured normalization policy and is disclosed; it is not silently treated as a chosen best gem. |
| E03 | Candidate has an inserted gem | Inherent stats and enhancement stats remain separate; configured current/baseline policy is applied symmetrically. |
| E04 | Candidate has an enchant but equipped comparison item does not | Result follows the explicit enchant normalization policy and details show the adjustment. |
| E05 | Candidate has leech, avoidance, or speed | Throughput score does not assign an invented value; utility is shown separately if enabled. |
| E06 | Heirloom or level-scaling item | Unsupported unless an exact level-scaled snapshot and capability rule exist. |
| E07 | Crafted current-quality ordinary item | Exact current snapshot may be evaluated; a hypothetical recraft/quality upgrade is unsupported in V1. |
| E08 | PvP-context item level differs | PvE result uses the relevant exact PvE state; PvP projection is unsupported unless separately modeled. |
| E09 | Legacy/timewalking item | Exact current ordinary stats may be displayable, but no current-season upgrade path is invented and context-sensitive scaling is guarded. |
| T01 | Recognized passive proc trinket with a generated per-spec curve | Ordinary stats plus effect delta are applied once; catalog/model provenance is returned. |
| T02 | Recognized on-use trinket paired with another on-use trinket | Use the catalog's pair rule/table or return unsupported; never blindly add two independent ideal-use values. |
| T03 | Special-effect score requested outside trained item-level knots | Interpolation within an allowed interval is bounded; extrapolation beyond policy lowers confidence or is rejected. |
| T04 | Special item recognized for another spec only | `UNSUPPORTED_EFFECT_FOR_SPEC`, not a zero effect. |
| T05 | Effect spell ID changes while item ID remains the same | Catalog validation detects the mismatch and disables that record. |
| T06 | Embellishment/special ring/weapon absent from catalog | Warning result with no overall percentage. |
| B01 | Candidate tier item activates two-piece | Require an explicit supported set transition; otherwise `SET_BONUS_TRANSITION`. |
| B02 | Candidate tier item breaks four-piece | Same guard applies even if visible stats look better. |
| B03 | Tier-tagged candidate leaves active set bonuses unchanged | It may use ordinary evaluation only if no unmodeled special effect remains. |
| M01 | Exact supported spec, archetype, profile, inside training hull | Ordinary model can qualify for high confidence if its interval clears materiality. |
| M02 | Supported spec but unknown talent fingerprint | Select only a documented compatible fallback; otherwise `MODEL_ARCHETYPE_MISMATCH`. |
| M03 | Candidate lies near/outside the trained stat domain | Uncertainty grows deterministically; beyond the hard boundary result is unsupported. |
| M04 | Predicted delta is +0.3% with ±0.5% uncertainty | “Too close to call”; no green upgrade. |
| M05 | Predicted delta is +2.0% with ±0.4% uncertainty | High/medium follows the deterministic evidence rules and supported item class. |
| M06 | Same item evaluated under single-target and dungeon profiles | Results and cache keys may differ and always label the profile. |
| M07 | Secondary stat crosses a game penalty boundary | Prediction remains within validation tolerance; no discontinuity from an incorrect smooth-only model. |
| P01 | Candidate worse now, better at rank 4 | Compact tooltip shows now/max/keep/threshold; Shift view lists all actionable ranks in order. |
| P02 | Candidate never becomes meaningfully better | Action says no modeled upgrade for this spec/profile, not “sell” or “destroy.” |
| P03 | Unsupported special effect | Purple/warning wording appears; no percentage styled as an overall answer. |
| P04 | Tooltip post-call fires repeatedly | Exactly one addon block appears for the same render signature. |
| P05 | Tooltip refresh fires after async completion | No duplicate lines and no refresh loop. |
| P06 | Two tooltip frames display different items | Per-tooltip state remains isolated. |
| P07 | Default UI only | Character, bag, loot, chat-link, and merchant tooltips work with all third-party addons disabled. |
| P08 | Combat lockdown and taint logging enabled | No protected action, blocked action, or taint attributed to the addon. |
| P09 | Non-English locale | Logic is unchanged; localized names/text affect presentation only. |
| P10 | Details opened for a ring/weapon | It lists the exact removed items, companion, profile, ranks, uncertainty, and provenance. |

## Property and invariant tests

Property-based generation is valuable for the combinatorial state logic. At minimum assert:

- no generated state equips one exact item instance twice;
- every generated state has at most one item per physical slot;
- a two-handed state contains no independent off-hand unless an explicit game rule permits it;
- ring and trinket order does not change total score;
- permuting bag iteration order does not change the winning configuration;
- adding an illegal companion cannot change the result;
- evaluation never mutates the input state or generated manifest;
- a projected rank uses exactly one recognized rank bonus and preserves unrelated link fields;
- the observed projected item level must equal the manifest expectation;
- increasing a modeled positive stat while holding everything else fixed cannot reduce a local prediction except where the pinned source model/penalty rule explicitly demonstrates it;
- widening uncertainty cannot upgrade a confidence category;
- an unsupported component cannot be erased by adding a supported one;
- action text is a pure function of typed result/confidence, never item color or tooltip wording.

## Asynchronous schedule testing

Use a deterministic fake scheduler and enumerate important interleavings:

1. candidate resolves before equipment;
2. equipment resolves before candidate;
3. one dependency fails then succeeds on retry;
4. tooltip hides before all dependencies resolve;
5. tooltip changes items at each await boundary;
6. equipment/bag/spec/talents change before evaluation and before presentation;
7. two callers join a pending repository entry and one cancels;
8. timeout occurs immediately before a late success;
9. a refresh triggers the post-call while the old generation callback is still queued.

Assert published result count, refreshed tooltip identity, cache contents, and discarded generation count. This suite directly protects the inconsistency observed in the prototype.

## Golden decision tests

For a small reviewed set of real loadouts, commit a human-readable golden record containing:

- chosen complete replacement state at each rank;
- current and candidate model outputs;
- deltas and uncertainty bounds;
- first worthwhile rank;
- confidence/action/reason codes;
- data versions.

Numeric goldens should use sensible tolerances only for generator/model revisions; runtime Lua evaluation for a pinned model should be deterministic. Any golden change requires a generated diff and reviewer acknowledgement of whether the source data, model, or logic changed.

## Patch-day qualification

For every supported client patch or season:

1. capture live build and API-contract smoke tests;
2. regenerate and review the season-manifest diff;
3. verify at least one owned item at every obtainable track/rank available to testers;
4. replay the full offline suite against new generated data;
5. regenerate model/effect validation reports if mechanics, APLs, tuning, or items changed;
6. run default-UI tooltip and taint smoke tests;
7. confirm old-season fixtures fail in the intended way;
8. release only supported capability records; leave the remainder visibly unavailable.

## Release gates

A release is blocked by any of the following:

- a high-confidence sign error in a reviewed regression case;
- a numeric result for an unknown special effect or set transition;
- an invalid or incomplete weapon state being selected;
- stale asynchronous data being shown for another item/state;
- projection item level not matching the season manifest;
- tooltip duplication/refresh loop under default UI;
- missing provenance or incompatible generated-data schema;
- undocumented network access or runtime dependency on an external addon/service;
- simulation validation below the declared threshold for an advertised capability.

