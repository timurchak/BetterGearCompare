# Midnight 12.1 item and upgrade system

Research snapshot: 2026-09-05, Retail 12.1.0. Every generated season artifact must carry a client build and generation date; this document is not a substitute for regenerating data after a hotfix or patch.

## Current Season 2 upgrade ladder

Midnight Season 2 has five normal PvE upgrade tracks, each with six ranks and its own Mistcrest currency. The client-derived live data exposed by Raidbots identifies upgrade groups 614–618 and a flat 20 matching Mistcrests for each paid step. This research snapshot resolved `live` metadata to WoW build `12.1.0.69587`, content hash `cbc0c66f5fe503d7e455cd2463fe0e28`, generated 2026-09-04 UTC. Raidbots documents that its static files are generated from game-client data and are available by exact build/content hash; consumers are asked to cache them and accept that they are provided without warranty. See the [Raidbots developer documentation](https://www.raidbots.com/developers), [current metadata](https://www.raidbots.com/static/data/live/metadata.json), and [current bonus-upgrade sets](https://www.raidbots.com/static/data/live/bonus-upgrade-sets.json).

| Track | Client-derived group | Ranks / item levels | Upgrade bonus IDs | Currency ID | Paid cost |
|---|---:|---|---|---:|---:|
| Adventurer | 614 | 1/6 266; 2/6 269; 3/6 272; 4/6 276; 5/6 279; 6/6 282 | 12817–12822 | 3442 | 20 Adventurer Mistcrests/step |
| Veteran | 615 | 279; 282; 285; 289; 292; 295 | 12825–12830 | 3443 | 20 Veteran Mistcrests/step |
| Champion | 616 | 292; 295; 298; 302; 305; 308 | 12833–12838 | 3444 | 20 Champion Mistcrests/step |
| Hero | 617 | 305; 308; 311; 315; 318; 321 | 12841–12846 | 3445 | 20 Hero Mistcrests/step |
| Myth | 618 | 318; 321; 324; 328; 331; 334 | 12849–12854 | 3446 | 20 Myth Mistcrests/step |

Rank 1 is the item's entry state, so 1/6 to 6/6 is five paid steps, normally 100 matching Mistcrests. Current player-facing guides independently report the same six-rank ladder and flat costs ([Wowhead](https://www.wowhead.com/guide/midnight/item-level-gear-upgrades-dawncrests), [Method](https://www.method.gg/guides/all-midnight-season-2-upgrade-tracks-and-item-levels)). Blizzard's PTR notes explicitly state that 12.1 returned to flat track costs like Season 1 ([12.1 development notes](https://us.forums.blizzard.com/en/wow/t/midnight-curse-of-ulatek-ptr-development-notes/2317811/6)).

The Season 2 item levels are seven above the originally announced PTR values. Blizzard announced that all 12.1 reward item levels were shifted by +7, making the season-to-season increase +46 ([official item-level update](https://us.forums.blizzard.com/en/wow/t/item-levels-increasing-in-midnight-season-2/2325009)). This is a concrete example of why values must be generated from a pinned live build rather than copied from an article or prior season.

### Above the normal ladder

Myth still has six normal crest ranks ending at 334. Higher item-level rewards are often described as “Myth 8” or “Myth 9 equivalent,” but those labels are not additional normal crest ranks. Blizzard says that later-season Ascendant Venomstones can raise a fully upgraded Hero, Myth, or maximum-quality crafted weapon, trinket, or necklace to a Myth-8-equivalent maximum, at ten stones per piece; the final raid rewards can occupy a still higher equivalent level ([official 12.1 reward changes](https://us.forums.blizzard.com/en/wow/t/curse-of-ulatek-endgame-reward-changes/2317450)).

For the advisor:

- do not invent ranks 7/6–9/6 in the regular track model;
- represent Venomstone conversion as a separate transformation with its own eligibility and data;
- exclude it from V1 projection unless the live API and fixtures prove the exact resulting item link and item level;
- display an exceptional source item at its actual structured item level without pretending that it has a normal rank.

## Structured upgrade APIs

### `C_Item.GetItemUpgradeInfo(itemInfo)`

This is the best general link/ID-level metadata call. It returns an optional `ItemUpgradeInfo` structure:

```lua
local info = C_Item.GetItemUpgradeInfo(itemLink)
-- info.currentLevel
-- info.maxLevel
-- info.maxItemLevel
-- info.trackString      -- localized display text
-- info.trackStringID
```

The API was added in 11.1.5 and is present in current Mainline ([API reference](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemUpgradeInfo); [live Blizzard-generated Item documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)). It avoids parsing localized “Upgrade Level” text. `trackString` is presentation, not a stable season identifier; neither it nor `trackStringID` proves that the item is upgradeable now.

### `C_ItemUpgrade.CanUpgradeItem(itemLocation)`

For an actually owned bag/equipment item, this is the authoritative simple eligibility check:

```lua
local location = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
local eligibleNow = C_ItemUpgrade.CanUpgradeItem(location)
```

It requires `ItemLocation`, not a detached item link ([API reference](https://warcraft.wiki.gg/wiki/API:C_ItemUpgrade.CanUpgradeItem)). This distinction is essential. A prior-season link can still contain and display its historic track/rank while the season is over and the item cannot be upgraded. Player reports from the Midnight pre-patch show the expected behavior: Season 3 rank text remained, but the items could no longer be upgraded ([Blizzard forum example](https://us.forums.blizzard.com/en/wow/t/anyone-else-unable-to-upgrade-gear/2231554)).

The decision rule should be:

1. if an owned `ItemLocation` exists, require `CanUpgradeItem(location) == true` for a “currently upgradeable” claim;
2. require its rank bonus to belong to the build-pinned current-season manifest before constructing projections;
3. for a link without a location, report track metadata but call eligibility **unverified**; only project if the current manifest can prove the link's track and the product wording does not claim the item can actually be paid-upgraded;
4. when either check conflicts or is unavailable, fail closed.

### Upgrade-vendor APIs

`C_ItemUpgrade.GetItemUpgradeItemInfo()` is much richer, but it describes the item currently placed in Blizzard's upgrade frame. Its `ItemUpgradeItemInfo` includes:

- `itemUpgradeable`, `currUpgrade`, `maxUpgrade`;
- `minItemLevel`, `maxItemLevel`;
- `upgradeLevelInfos`;
- seasonal cost types.

Each `ItemUpgradeLevelInfo` includes `upgradeLevel`, `itemLevelIncrement`, `levelStats`, currency/item/money costs, and a failure message. The current structure is visible in Blizzard's [generated ItemUpgrade documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemUpgradeDocumentation.lua).

This is an excellent optional adapter while the user is already using the upgrade UI. It is not a general hover API: the addon should not move cursor items into the vendor frame or manipulate protected UI to get a prediction. `C_ItemUpgrade.GetHighWatermarkForItem`, `GetHighWatermarkForSlot`, and `GetHighWatermarkSlotForItem` can inform discounts, but they do not by themselves return the user's exact cost for every arbitrary tooltip item.

## Item identity and levels

### Link anatomy

An item hyperlink encodes far more than an item ID:

```text
itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:uniqueID:
linkLevel:specializationID:modifiersMask:itemContext:
numBonusIDs:bonusIDs...:numModifiers:type/value...:...:extraEnchantID
```

See the current [ItemLink format](https://warcraft.wiki.gg/wiki/ItemLink). The snapshot/cache identity must therefore use the canonical full link (and item GUID/location when possessed), not item ID alone. Enchantments, gems, crafted quality, upgrade rank, sockets, tertiary rolls, and contextual scaling can differ between two links with the same item ID.

### Generic, sparse/base, actual, and location-effective level

- `C_Item.GetItemInfo(itemInfo)` returns a generic cached `itemLevel` field. Its precise result depends on the supplied item info/link and it may return nothing until cached; do not label it “base” or use it as the exact upgraded-instance level.
- `C_Item.GetDetailedItemLevelInfo(itemInfo)` returns `actualItemLevel`, `previewLevel`, and `sparseItemLevel`. Use actual for a resolved link, retain the preview flag in diagnostics, and treat sparse level as the underlying sparse/database level rather than the upgraded instance.
- `C_Item.GetCurrentItemLevel(itemLocation)` is preferable for an owned location whose effective level can depend on current context, such as timewalking/scaling.

References: [`C_Item.GetItemInfo`](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemInfo), [`C_Item.GetDetailedItemLevelInfo`](https://warcraft.wiki.gg/wiki/API:C_Item.GetDetailedItemLevelInfo), and [`C_Item.GetCurrentItemLevel`](https://warcraft.wiki.gg/wiki/API:C_Item.GetCurrentItemLevel).

Never substitute `GetItemInfo`'s generic level for a verified actual/effective level. Never use “higher item level” as a complete performance decision.

## Item data is asynchronous

The current C APIs explicitly mark several item calls as `MayReturnNothing`. A safe flow is:

```lua
local item = Item:CreateFromItemLink(itemLink)
local cancel = item:ContinueWithCancelOnItemLoad(function()
  -- Re-read every required structured field here.
end)
```

`ContinueOnItemLoad` itself does not return a cancel handle; the current object API provides the separate `ContinueWithCancelOnItemLoad` method used above. Alternatively call `C_Item.RequestLoadItemData(itemLocation)` / `RequestLoadItemDataByID` and observe `ITEM_DATA_LOAD_RESULT(itemID, success)`. `GET_ITEM_INFO_RECEIVED(itemID, success)` is older and item-ID-granular. See [`ItemMixin`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ObjectAPI/Mainline/Item.lua), [`C_Item.RequestLoadItemData`](https://warcraft.wiki.gg/wiki/API:C_Item.RequestLoadItemData), and [`ITEM_DATA_LOAD_RESULT`](https://warcraft.wiki.gg/wiki/Event:ITEM_DATA_LOAD_RESULT).

Requirements for the adapter:

- distinguish `pending`, `ready`, `failed`, and `timed_out`;
- coalesce concurrent requests for the same full-link/static backing item;
- do not convert `nil` to zero;
- use a cancelable callback and a timeout because invalid/unavailable items may never complete;
- reread data after success rather than trusting fields captured before the load;
- bind each callback to an evaluation generation so a stale result cannot annotate a new tooltip item.

## Structured stats and enhancements

`C_Item.GetItemStats(itemLink)` returns a table keyed by stable global-string tokens such as `ITEM_MOD_STRENGTH_SHORT`, `ITEM_MOD_CRIT_RATING_SHORT`, `ITEM_MOD_HASTE_RATING_SHORT`, `ITEM_MOD_MASTERY_RATING_SHORT`, `ITEM_MOD_VERSATILITY`, armor, tertiary keys, and generally weapon DPS under `ITEM_MOD_DAMAGE_PER_SECOND_SHORT`. It may return nothing when unresolved. `C_Item.GetItemStatDelta(link1, link2)` can return a structured delta, but the evaluator needs complete state totals and should not make pairwise item deltas its domain model. See [`C_Item.GetItemStats`](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemStats) and [`C_Item.GetItemStatDelta`](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemStatDelta).

At startup/test time, log unknown returned stat keys. A new key must default to “unmodeled, confidence reduced,” not be silently discarded in a high-confidence result.

Useful enhancement calls:

- `C_Item.GetItemNumSockets(itemInfo)` and `GetItemNumAddedSockets(itemInfo)`;
- `C_Item.GetItemGemID(itemInfo, index)` / `GetItemGem(link, index)`;
- the link's `enchantID`, gem fields, bonus IDs, and `extraEnchantID`;
- `C_Item.GetItemCreationContext(itemInfo)` for diagnostics/context.

Default comparison should normalize replaceable enhancements. Comparing a fully enchanted/gemmed worn item to a fresh drop as-is systematically underrates the drop. The proposed policy is:

- remove/normalize ordinary enchants on both states;
- preserve the number/type of sockets as an item property;
- value empty sockets using a declared profile gem (or mark them unfilled and lower confidence);
- expose “as currently configured” only as an advanced alternative;
- treat embellishments and nonordinary enchant effects as special effects, not replaceable decoration.

Tertiary stats should be shown as unmodeled utility unless a dedicated tank/healer/survival model exists. A DPS percentage must not quietly include an invented value for Leech, Avoidance, or Speed.

## Predicting future-rank stats

There is no documented, general API that takes an arbitrary item and a desired rank and returns that rank's full link/stats. `GetItemUpgradeInfo` supplies current/max metadata, and the vendor API supplies detailed level records only for the vendor-selected item.

The practical V1 projection is a validated hybrid:

1. generate a build-pinned manifest of every current upgrade group, rank bonus, item level, and currency from client data;
2. parse the full hyperlink structurally;
3. locate exactly one manifest-known rank bonus and replace only that bonus with the target rank bonus, preserving item context, all unrelated bonuses, modifiers, enchant, gems, suffix, crafter, and extra enchant;
4. asynchronously ask `C_Item.GetDetailedItemLevelInfo` and `C_Item.GetItemStats` for the projected link;
5. accept it only when its actual item level equals the manifest expectation and all mandatory fields resolve;
6. otherwise return `projection_unavailable`—never fall back to localized tooltip parsing or a guessed linear formula.

This use of a constructed link is not documented by Blizzard as a stable projection contract. It must therefore be guarded by live-client fixtures on every supported build. The fallback for a failed validation is an honest unsupported result.

An offline exact scaler based on client DB2 curves/item budgets is possible in principle—SimulationCraft consumes client item, curve, enchant, gem, rating, and stat-conversion data ([SimC game-client data](https://github.com/simulationcraft/simc/wiki/GameClientData))—but reimplementing all slot, quality, budget, bonus-tree, and rounding rules inside Lua is a larger and riskier project. It belongs after V1 and should be verified against Blizzard-resolved links.

## Crafted quality, sockets, tertiary stats, and special bonuses

Crafted quality is represented through the item's link/bonus data and can be surfaced with structured tooltip line type `ProfessionCraftingQuality`. A currently resolved crafted item can be evaluated on its actual stats. Recrafting with a different crest/quality is not the same as advancing a normal 1/6 track, so V1 should not promise future crafted-quality projections.

Similarly:

- random/additional sockets and tertiary bonuses are part of this exact item instance/link;
- socket opportunity is modeled separately from the stats of a currently inserted gem;
- tier/set identity uses `setID` from `C_Item.GetItemInfo` plus `C_Item.GetSetBonusesForSpecializationByItemID`;
- on-use/equip/proc effects enter the special-effect path described in `05-trinkets-and-special-effects.md`.

## Season-proof manifest rules

Every packaged season table should contain:

```lua
SeasonManifest = {
  schema = 1,
  product = "wow_retail",
  patch = "12.1.0",
  build = 69587,
  generatedAtUTC = "...",
  sourceContentHash = "...",
  -- mythicPlusRewardSeasonID = <generated numeric ID>,
  upgradeGroups = { ... },
}
```

Runtime should compare `GetBuildInfo()` and, as corroborating context, `C_MythicPlus.GetCurrentSeasonValues()`. A patch/build newer than the validated range should disable future-rank projection and special-effect claims until explicitly allowed. It may continue current-stat comparisons if the structured input contract still passes self-tests, but confidence must include a `data_build_mismatch` reason.

Do not identify a season by localized track names, a broad numeric bonus interval, current date, or expansion ID. Do not classify legacy items as upgradeable merely because `GetItemUpgradeInfo` returns historic metadata.
