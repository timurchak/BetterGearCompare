# Spike A — current-season upgrade-rank projection

**Verdict: PASS.** Live Retail 12.1.0.69587 sessions produced eight selected fixtures and all eight pass the strict validator. Across four unique current-season items, 11 unique future item/rank states (15 captured projection rows because one socketed neck also serves as the socket category) matched expected item level and structured upgrade-vendor stat values. A crafted item remained safely unprojected, a current Hero 6/6 item was explicitly ineligible, and an old-season item with historical bonus metadata was not matched to the active manifest, reported `currentlyUpgradeable=false`, and produced no projection.

## What was built

- [`Phase0UpgradeProbe.lua`](addons/Phase0UpgradeProbe/Phase0UpgradeProbe.lua) is a standalone diagnostic addon. It is not referenced by `BetterGearCompare.toc`.
- [`fetch_manifest.py`](tools/upgrade/fetch_manifest.py) downloads two versioned JSON resources, pins their client build and content hash, and generates both [`season-manifest.generated.json`](fixtures/upgrade/season-manifest.generated.json) and [`Manifest.lua`](addons/Phase0UpgradeProbe/Manifest.lua). This is structured JSON consumption, not HTML scraping.
- [`fixture-schema.json`](fixtures/upgrade/fixture-schema.json) defines the machine-readable record and [`validate_fixtures.py`](tools/upgrade/validate_fixtures.py) enforces category coverage, build identity, current-season eligibility, exact projected levels, vendor-backed stat verification, and safe legacy handling.
- [`validation-report.json`](fixtures/upgrade/validation-report.json) records the present result instead of treating absent fixtures as success.
- [`client`](fixtures/upgrade/client/) contains the selected JSON fixtures. [`client/raw`](fixtures/upgrade/client/raw/) preserves the unedited SavedVariables sessions before deduplication/selection.
- [`import_savedvariables.lua`](tools/upgrade/import_savedvariables.lua) reproducibly exports explicitly selected capture indices; it never silently chooses or rewrites source evidence.

The generated manifest is for client `12.1.0.69587`, content hash `cbc0c66f5fe503d7e455cd2463fe0e28`. It contains current groups 614–618: Adventurer, Veteran, Champion, Hero, and Myth, each with six rank bonus IDs and expected item levels. The upstream metadata explicitly identifies its environment, build, content hash, generation time, and `bonus-upgrade-sets.json` file ([Raidbots static metadata](https://www.raidbots.com/static/data/live/metadata.json)). This manifest is supporting build-time data, not authoritative proof that an invented item link is legal or upgradeable.

## Exact mechanism under test

1. Acquire the complete item hyperlink and, where owned, its `ItemLocation` and GUID.
2. Wait for `Item:CreateFromItemLink(link):ContinueWithCancelOnItemLoad(...)` before reading data.
3. Read current structured values with:
   - `C_Item.GetItemInfoInstant`
   - `C_Item.GetDetailedItemLevelInfo`
   - `C_Item.GetItemStats`
   - `C_Item.GetItemNumSockets`
   - `C_Item.GetItemNumAddedSockets`
   - `C_Item.GetItemGem`
   - `C_Item.GetItemGUID`
   - `C_ItemUpgrade.CanUpgradeItem(ItemLocation)`
4. Parse only the item-link payload—not rendered tooltip lines—and require exactly one bonus ID present in the pinned active-season rank manifest.
5. Preserve every other link field and bonus ID, substitute only that track's rank bonus, resolve the resulting link asynchronously, and read its structured item level/stats.
6. When the same physical item is selected in Blizzard's upgrade frame, capture `C_ItemUpgrade.GetItemHyperlink()` and `C_ItemUpgrade.GetItemUpgradeItemInfo()`. A projected rank is `verified=true` only when:
   - projected item level exactly equals the manifest level; and
   - the structured numeric values in the vendor's `levelStats` for that rank match the structured `C_Item.GetItemStats(projectedLink)` values.

The addon deliberately does **not** call a constructed link “verified” merely because the client resolves it. `tooltipParsingUsed` is always false.

## Recorded fixture fields

Each capture includes client version/build/locale; category and timestamp; item ID; complete link; GUID and location when available; current, preview, and sparse item levels; inventory/item/equipment type; all stats; socket/gem state; all bonus IDs; detected active group/track/rank; `CanUpgradeItem`; raw vendor observation; and a future-rank array containing expected level, constructed key/link, projected level/stats/sockets, level match, vendor stat match, mismatches, and final verification.

Use `/p0a vendor <category>` with an item selected in Blizzard's upgrade frame for authoritative rank observations. Other commands are documented by `/p0a help` and implemented near the bottom of the probe.

## Safety and unresolved cases

- A known rank bonus is insufficient evidence of present eligibility. Production code must require the current build/season manifest **and** positive location-aware eligibility. A link without a usable `ItemLocation` has eligibility `unknown`, not true.
- An old-season item may retain historic upgrade metadata. The `old-season` and `upgrade-like-ineligible` categories are never projected as verified, even if a bonus resembles the current scheme.
- Crafted gear, source/difficulty modifiers, sockets, and other bonuses may interact with rank substitution. The probe preserves them but makes no compatibility claim until a live fixture verifies the result.
- `C_ItemUpgrade.GetItemUpgradeItemInfo()` is contextual to Blizzard's selected upgrade item. It is useful as an observable structured oracle, not a general arbitrary-link projection API.
- The static rank feed is third-party-derived. A production generator must pin the build and validate it against client evidence; runtime must ship the generated manifest and never contact the service.

## Findings from the live run

The live session exposed three implementation bugs that an offline review did not:

1. `C_Item.GetItemInventoryType` accepts an `ItemLocation`, not an item link. Link-only fallback must use `C_Item.GetItemInventoryTypeByID`.
2. `ContinueOnItemLoad` may invoke immediately for cached projected records. Incrementing `pending` while subscribing caused repeated premature completion. The probe now constructs the full target list first, initializes the count once, and makes completion idempotent.
3. Lua's `location and CanUpgradeItem(location) or nil` collapses a legitimate `false` to `nil`. Eligibility now stores an explicit boolean whenever a valid location exists.
4. `TooltipDataProcessor` also processes automatic comparison tooltips. Recording the last item from every item post-call made `/p0a hover` select the equipped comparison item instead of the primary hovered item. Source capture now accepts only `GameTooltip` and `ItemRefTooltip` and explicitly ignores `ShoppingTooltip1/2`.

These failures explain the initial hangs and duplicate fixture rows and are regression requirements for production code.

## Required live matrix

| Fixture | Required observation | Current status |
|---|---|---|
| Current ordinary armor | Hero 3/6, item 271484; ranks 4–6 vendor-verified | Passed |
| Current ring | Champion 5/6, item 158366; rank 6 vendor-verified | Passed |
| Current neck | Hero 3/6 item 251173 and Champion 2/6 item 272147; seven future rows verified | Passed |
| Socketed current item | Champion 2/6 item 272147 with one socket; ranks 3–6 verified | Passed |
| Crafted item | Item 244577 captured safely with no invented track/projection | Passed |
| Old-season track item | Item 249982; no active manifest track/rank, `currentlyUpgradeable=false`, zero projections | Passed |
| Upgrade-looking but ineligible item | Hero 6/6 item 271482; `currentlyUpgradeable=false`, zero projections | Passed |
| More than one track | Champion and Hero fixtures; non-rank bonuses preserved | Passed for tested items |

The checked-in validator reports 8/8 fixtures passed with no missing categories. See [`validation-report.json`](fixtures/upgrade/validation-report.json).

## Pass gate

Spike A becomes PASS only on the target Retail build when all of the following are true:

1. Required categories above are present as unedited machine captures.
2. Every current-season projected rank has exact expected item level.
3. Every projected scalable stat exactly matches the upgrade UI's structured rank values, or a reviewed deterministic representation difference is documented and tested.
4. No old-season or ineligible fixture is reported currently upgradeable or verified.
5. No localized tooltip text is consulted.
6. Missing/ambiguous track, multiple known track bonuses, missing item data, build mismatch, or absent vendor evidence produces `unsupported/unverified`, never an upgrade claim.

Reproduce the current partial result:

```powershell
$python = 'C:\Users\timur\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python experiments\phase0\tools\upgrade\fetch_manifest.py
& $python experiments\phase0\tools\upgrade\validate_fixtures.py
```

The validator exits zero with `PASS`. Any missing mandatory category would produce `PARTIAL`; a captured mismatch produces `FAIL`.
