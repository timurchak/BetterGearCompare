# Existing codebase review

Reviewed 2026-09-05. This is a review of behavior and requirements, not a proposal to preserve either implementation.

## Executive finding

`BetterGearCompare` should be replaced behind a clean boundary, not incrementally refactored into the new product. Its useful ideas are product requirements—per-specialization behavior, dual-slot awareness, current/max-rank comparisons, default tooltip output—not reusable architecture. The current score is a synchronous sum of a handful of stats, while item data is asynchronous and valid gear comparison is a loadout-state problem. Several paths silently turn missing data into zero and then permanently annotate the tooltip, which explains much of the reported inconsistency.

`PopularSlotsAndChants` is a separate “what is popular?” browser. Its Archon acquisition is undocumented web-page scraping, including handling Archon's human-verification endpoint, and its conversion from observed stat totals to “weights” is mathematically invalid. No part of that pipeline should feed the gear advisor.

## BetterGearCompare: current shape

### Load order and modules

The TOC loads a shared global namespace and these major responsibilities:

- bootstrap/events/public import API: [`BetterGearCompare.lua`](../../BetterGearCompare.lua)
- constants and season/slot tables: [`BetterGearCompare_Constants.lua`](../../BetterGearCompare_Constants.lua)
- SavedVariables and manual profiles: [`BetterGearCompare_DB.lua`](../../BetterGearCompare_DB.lua)
- structured stat reads and flat scoring: [`BetterGearCompare_Stats.lua`](../../BetterGearCompare_Stats.lua)
- partial class/spec weapon policy: [`BetterGearCompare_SpecRules.lua`](../../BetterGearCompare_SpecRules.lua)
- all comparison, upgrade-link, ring, weapon, trinket, and icon decisions: [`BetterGearCompare_Compare.lua`](../../BetterGearCompare_Compare.lua)
- tooltip hooks and rendering: [`BetterGearCompare_Tooltip.lua`](../../BetterGearCompare_Tooltip.lua)
- Baganator/Syndicator bag icons: [`BetterGearCompare_Icons.lua`](../../BetterGearCompare_Icons.lua)
- manual options and weights: [`BetterGearCompare_Options.lua`](../../BetterGearCompare_Options.lua)
- generated Wowhead trinket tiers and BiS guides plus their browser UI.

This looks modular by filename, but the domain boundary is not real. `Compare` directly calls WoW inventory APIs, reads global generated tables, applies the scoring formula, chooses replacement slots, fabricates future links, and returns display-shaped fields. Tooltip, bag icon, BiS, and profile concerns cross through the same namespace.

### Addon dependencies

The tooltip path has no declared addon dependency. The bag-icon feature is coupled to Baganator and Syndicator internals: [`Icons:InitBaganator`](../../BetterGearCompare_Icons.lua#L19) registers a Baganator corner widget and a Syndicator callback. The bootstrap attempts that integration when Baganator loads. This is not required to add lines to Blizzard tooltips, and it must not be a core dependency of a replacement.

The two large generated datasets are build-time dependencies on Wowhead pages. The extraction scripts use browser impersonation because normal requests are blocked; the release workflow regenerates the tables. This is a fragile, unofficial data dependency even though the packaged addon works offline.

### WoW APIs in use

Notable reads and hooks include:

- `C_Item.GetItemInfoInstant` for item ID, equip location, class, and subclass in [`GetEquipLocation` / `GetItemClassAndSubclass`](../../BetterGearCompare_Compare.lua#L72).
- `C_Item.GetItemStats` and `C_Item.GetDetailedItemLevelInfo` in [`BetterGearCompare_Stats.lua`](../../BetterGearCompare_Stats.lua#L6).
- `GetInventoryItemLink("player", slotID)` for worn items in [`GetEquippedItemState`](../../BetterGearCompare_Compare.lua#L213).
- `C_Container.GetContainerNumSlots` and `C_Container.GetContainerItemLink` for an icon-only bag scan in [`GetBagItemLevel`](../../BetterGearCompare_Compare.lua#L766).
- `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)`, plus legacy `OnTooltipSetItem`, `ProcessInfo`, and numerous `Set*` hooks in [`Tooltip:Init`](../../BetterGearCompare_Tooltip.lua#L208).
- `GET_ITEM_INFO_RECEIVED` only in the BiS browser, not in the gear-comparison tooltip.
- specialization/world events in [`BetterGearCompare.lua`](../../BetterGearCompare.lua#L85), and bag/level/cached-equipment events in the Baganator icon adapter.

### Tooltip path

The modern post-call is the right basic extension point. The implementation nevertheless hooks several older entry points as well. [`ExtractItemLink`](../../BetterGearCompare_Tooltip.lua#L27) tries `TooltipUtil.GetDisplayedItem`, callback data, `tooltip:GetItem()`, `tooltip.itemLink`, and processing arguments. [`HandleTooltipItem`](../../BetterGearCompare_Tooltip.lua#L144) uses per-frame `__bgcProcessing` and `__bgcAnnotated` flags.

The central race is:

1. a tooltip is populated before the item record/stats are cached;
2. comparison code receives `nil` stats or item level `0`;
3. zero/incomplete results produce no useful lines or a wrong comparison;
4. the handler sets `__bgcAnnotated = true` anyway at lines 162–166;
5. no item-load event retries that item, so repeated display can vary according to unrelated cache history.

The flags are not keyed by displayed item identity or an evaluation generation. A future asynchronous callback could therefore also update a tooltip that has already moved to a different item. `OnTooltipCleared` resets only the explicitly enumerated tooltip frames, while the global post-call can receive any `GameTooltipTemplate` tooltip. Multiple hooks increase duplicate and ordering risk without fixing loading.

### Item score

[`Stats:CalculateScore`](../../BetterGearCompare_Stats.lua#L51) sums only configured primary-stat and four-secondary-stat values. Default weights are all `1.0`. It does not model:

- weapon DPS or speed;
- armor/survivability;
- proc or on-use effects;
- set bonuses and thresholds;
- sockets as opportunities rather than only any stats already present;
- enchant normalization;
- embellishments/cantrips;
- tertiary utility;
- nonlinear stat interactions or diminishing returns.

The score returns `(0, nil)` if stats are unavailable. That is indistinguishable from a loaded item with no modeled stats. Consequently, missing data can make an equipped item or candidate look worthless.

### Upgrade-track and season logic

[`FindUpgradeTrackBonus`](../../BetterGearCompare_Compare.lua#L40) parses the raw hyperlink and accepts any bonus ID in a hard-coded numeric interval. [`BuildMaxUpgradeLink`](../../BetterGearCompare_Compare.lua#L63) replaces that field with another hard-coded bonus. The constants are Midnight Season 1 IDs `12769`–`12808`; Midnight 12.1 Season 2 uses different groups and bonuses. The code has no data manifest, season ID, client-build check, or API eligibility check.

Specific failure modes:

- old-season items can retain a track-looking bonus while no longer being upgradeable;
- any unrelated bonus in the numeric range can be misclassified;
- changing only one bonus assumes no coupled context/curve/modifier changes;
- tracks are accepted through `base + 7` even though the current table is six ranks;
- crafted, heirloom, timewalking, PvP, and legacy scaling are not separated;
- [`BuildMaxUpgradeComparison`](../../BetterGearCompare_Compare.lua#L428) upgrades both candidate and equipped links to their maxima. That answers “max versus max,” not “at what candidate rank does this beat what I wear now?”

### Slot comparison

[`slotCandidates`](../../BetterGearCompare_Constants.lua#L18) at least recognizes rings as slots 11/12, trinkets as 13/14, and generic weapons as 16/17. The execution is inconsistent:

- regular comparison chooses the lowest flat score among candidate slots;
- [`GetAllComparisons`](../../BetterGearCompare_Compare.lua#L828) special-cases rings and returns both slot comparisons, leaving the user to interpret the result;
- trinkets use a different single-replacement path;
- matching the same item ID is used as a proxy for unique-equipped behavior, but unique categories can span different item IDs and have category limits;
- set activation/breakage and configuration legality are absent.

The correct retained requirement is “enumerate valid candidate equipment states and choose/report the best legal replacement,” not “map an equip location to one or two slot numbers.”

### Weapons

[`BuildWeaponCandidates`](../../BetterGearCompare_Compare.lua#L520) tries to reason about one-hand, two-hand, and off-hand transitions, but it scores stat fragments rather than complete legal states. The clearest error is line 625: for a dual-wield policy, one received one-hand weapon is valued as `baseNewScore * 2`, synthesizing a second identical weapon the player does not own. A one-hand candidate against a current two-hand setup is otherwise often rejected because no companion item is enumerated.

Other problems:

- no bag search for an actually owned compatible one-hand/off-hand/shield;
- no weapon DPS or speed in the score;
- no unique-category validation across hands;
- main-hand-only/off-hand-only constraints are partial;
- hard-coded policies cover only warrior, paladin, rogue, druid, and shaman; [`BuildFallbackPolicy`](../../BetterGearCompare_SpecRules.lua#L89) is permissive for every other class;
- `CanDualWield`, current talents/passives, and a versioned capability manifest are not used;
- Titan's Grip, shield requirements, caster off-hands, and ranged weapon configurations are not treated as explicit rules.

### Trinkets and other special items

[`BuildTrinketComparison`](../../BetterGearCompare_Compare.lua#L301) maps generated Wowhead letter tiers to ordinal numbers (`S=5` through `D=1`) and calculates percentage differences on those ordinals. “5 versus 4 = +25%” has no DPS meaning. Item level is not part of the tier value, unknown items become zero, and pair/on-use timing interactions are not modeled. The same issue affects special-effect weapons and non-trinket cantrip items because they fall through the regular stat path.

### Cache/event consistency

There is no coherent cache. WoW's internal item cache is queried synchronously; generated datasets are static globals; equipped state is rebuilt per hover; icons separately scan bags. No cache key includes item link, item GUID/location, spec, talents/archetype, enhancement policy, model version, season manifest, or equipped-state revision.

Events do not invalidate a domain result cache because none exists. Important invalidations missing from the comparison path include bag/equipment changes, item data completion/failure, socket/enchant/link changes, talent configuration changes beyond the older talent-group event, generated-model version, and client/season transitions.

### Item-level shortcut

[`ShouldShowUpgradeIcon`](../../BetterGearCompare_Compare.lua#L796) may mark an item as an upgrade from item level alone. That shortcut can contradict the actual recommendation, ignores special effects and complete weapon states, and compares only one target slot. The timewalking workaround (`C_Item.GetCurrentItemLevel(ItemLocation)`) is a useful clue: link-level and location-effective item level can differ. The requirement should be retained, but the “higher item level implies upgrade” decision should be discarded.

### Other fragile categories

- **Heirlooms/scaling/timewalking:** location/context-dependent effective level is not a stable ordinary item projection.
- **Crafted gear:** fabricated regular-track links do not represent quality, recrafting, optional reagents, or embellishment limits.
- **Tier:** `setID` and specialization set-bonus APIs are unused, so 2/4-piece changes are invisible.
- **Sockets/enchants:** comparing an enchanted worn item to a fresh unenchanted drop biases the result unless enhancements are normalized.
- **Legacy/PvP:** no explicit policy, so a recognizable equip location may enter the normal scorer.
- **BiS data:** the large static browser is not necessary to answer the core gear question and adds another volatile, scraped source.

## PopularSlotsAndChants: current shape

### Acquisition

[`scripts/archon_common.py`](../../../PopularSlotsAndChants/scripts/archon_common.py#L58) builds Archon web-page URLs. [`_curl_html`](../../../PopularSlotsAndChants/scripts/archon_common.py#L82) invokes `curl` with browser-like headers and a cookie jar. [`fetch_archon_next_data`](../../../PopularSlotsAndChants/scripts/archon_common.py#L124) detects the human-verification page, posts signed fields to `/human-challenge`, then extracts the private Next.js `__NEXT_DATA__` payload. This is page scraping, not an official API integration.

[`generate_lua.py`](../../../PopularSlotsAndChants/scripts/generate_lua.py#L55) performs five page fetches for every specialization and each of Mythic+ and raid, sleeps 0.5 seconds between them, validates required categories, and emits one large Lua table. The packaged file is approximately 1.14 MB / 38,595 lines and identifies Archon as its source. The release workflow currently validates that a pre-generated table is complete and less than 24 hours old rather than fetching during packaging.

### Extracted and transformed data

The pipeline extracts:

- top items and popularity by slot;
- popular enchants and gems;
- top consumables;
- popular talent builds, hero trees, and export codes;
- an ordered set of aggregate stat values.

The UI is a tabbed browser. [`UI.ItemString`](../../../PopularSlotsAndChants/Core/UI/Pools.lua#L31) fabricates an item link at a selected hard-coded track; `GET_ITEM_INFO_RECEIVED` rerenders rows when item names load. Its season IDs are the same stale Season 1 values as BetterGearCompare ([`Core/UI/Constants.lua`](../../../PopularSlotsAndChants/Core/UI/Constants.lua#L7)).

### Invalid “weights” transformation

[`ConvertArchonWeights`](../../../PopularSlotsAndChants/Core/UI/Stats.lua#L42) assigns the first-ranked stat the constant `10` and every other stat `stat.value / 100`; the button at lines 143–156 imports that table into BetterGearCompare. An aggregate such as 823 Haste therefore becomes 8.23 Haste “weight.” This is not a unit conversion with a theoretical basis.

Population stat amounts are outcomes of available loot, item levels, set requirements, crafted slots, acquisition, chosen builds, and selection into the sampled population. A marginal stat value asks how expected performance changes after adding or exchanging a small amount of a stat while holding the relevant state/profile fixed. The observed amount and that derivative are different quantities and can even move in opposite directions. Diminishing returns, caps, interactions, and missing special effects make the conversion still less meaningful.

### What actually requires population data

Only descriptive questions genuinely need population data:

- “What items/enchants/talents are common among this declared sample?”
- popularity percentages and changes over time;
- representative build discovery.

Gear valuation, item scaling, equip legality, current-character state, and marginal performance do not require population averages. SimulationCraft can generate modeled performance data; Blizzard APIs can supply the player's items and structured metadata. Population sources may identify archetypes to simulate, but must not define value.

## Requirements worth retaining

These are requirements discovered in the prototypes, not implementation endorsements:

- concise default-tooltip answer with progressive detail;
- explicit current rank, maximum supported rank, and first confidently better rank;
- per-specialization and profile-sensitive evaluation;
- two-slot replacement for rings and trinkets;
- complete two-hand / one-hand / off-hand state comparison;
- a distinct path for trinkets and other special effects;
- correct operation when item data is initially unavailable;
- default Blizzard UI support with no bag-addon requirement;
- offline packaged data and diagnostics/provenance;
- optional advanced/manual model import only if its semantics and version are explicit.

## Decisions to discard

- flat average-stat or user-entered weights as the default source of truth;
- arbitrary tier ordinals displayed as percentages;
- item-against-item comparison as the central abstraction;
- hard-coded contiguous bonus-ID ranges without a season/build manifest;
- treating track metadata as proof of current upgrade eligibility;
- synchronous “nil means zero” evaluation;
- multiple tooltip hooks and a boolean annotation flag;
- synthesizing a duplicate off-hand weapon;
- item-level-only upgrade icons;
- Baganator/Syndicator internals in core functionality;
- scraped Wowhead/Archon pages as required data pipelines;
- a built-in BiS browser as part of the first gear-advisor release.

## Why behavior is inconsistent

The primary cause is timing: `GetItemInfo`-family and stat/detail calls may return nothing until item data is cached, but the tooltip path is synchronous and one-shot. The secondary causes are state ambiguity (one item versus a multi-slot loadout), stale season constants, and different algorithms for normal items, rings, trinkets, weapons, and icons. A cached hover can therefore appear correct while the same uncached link, another tooltip frame, a legacy-track item, or a weapon transition produces a different or missing answer.
