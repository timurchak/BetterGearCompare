# BetterGearCompare

Lightweight WoW Retail addon — weighted stat comparison in gear tooltips, trinket tier lists, and Best-in-Slot tracking.

## Architecture

```
BetterGearCompare.lua            -- Entry point, event handling
BetterGearCompare_Localization.lua -- Locale framework (L table)
Locales/                         -- Per-language translations (enUS, ruRU, deDE, itIT, zhCN, zhTW)
BetterGearCompare_Constants.lua  -- Stat IDs, slot mappings
BetterGearCompare_DB.lua         -- SavedVariables, profile management
BetterGearCompare_Stats.lua      -- Stat extraction from item links
BetterGearCompare_SpecRules.lua  -- Per-spec comparison rules (dual wield, 2H, ranged)
BetterGearCompare_TrinketData.lua -- Generated trinket tier data (from Wowhead)
BetterGearCompare_BisData.lua    -- Generated BIS gear data (from Wowhead)
BetterGearCompare_BisUI.lua      -- BIS browser window (/bgc bis)
BetterGearCompare_Compare.lua    -- Core comparison logic, score calculation
BetterGearCompare_Tooltip.lua    -- Tooltip hooks, annotation rendering
BetterGearCompare_Options.lua    -- Settings UI, slash commands
BetterGearCompare_Icons.lua      -- Bag item upgrade icons
Media/                           -- Addon textures (wowhead.tga)
```

## Data Generation

Trinket tiers and BIS gear data are scraped from Wowhead guides at build time. Scripts live in `scripts/`:

| Script | Purpose |
|--------|---------|
| `extract_wowhead_trinket_tiers.py` | Parse trinket tier lists from Wowhead guide markup |
| `generate_wowhead_trinket_lua.py` | Generate `BetterGearCompare_TrinketData.lua` for all 40 specs |
| `extract_wowhead_bis_gear.py` | Parse BIS gear tables from Wowhead guide markup |
| `generate_wowhead_bis_lua.py` | Generate `BetterGearCompare_BisData.lua` for all 40 specs |
| `extract_upgrade_tracks.py` | Discover upgrade-track bonus IDs for `BetterGearCompare_Constants.lua` |
| `verify_wowhead_trinket_guides.py` | Validate guide URLs are still reachable |
| `install.py` | Copy addon files to local WoW AddOns directory |

### Tier labels

Tier labels come from the guide itself — besides `S`–`D` the authors also use `S+`,
`A+`, `F` and `G`, and each spec may use its own set. Scores are derived from the
order a guide lists its tiers in: the best tier scores highest, the worst listed
tier scores 1, a trinket that is not listed at all scores 0.

### Dependencies

```
pip install curl_cffi
```

`curl_cffi` is required because Wowhead blocks standard HTTP clients. It impersonates Chrome via `impersonate='chrome'`.

### Running generators

```bash
cd scripts
python generate_wowhead_trinket_lua.py   # writes BetterGearCompare_TrinketData.lua
python generate_wowhead_bis_lua.py       # writes BetterGearCompare_BisData.lua
```

BIS guide URLs are listed in `scripts/wowhead_bis_guide_urls.txt` (one per line, 40 total).

## Upgrade Tracks

Every upgrade track owns a run of consecutive item bonus IDs — one per rank — and
Blizzard hands out a fresh block of IDs each season. Gear from an older season
keeps the previous block's IDs, and some gear (mythic raid drops, older loot) has
no track at all. Comparisons therefore match a bonus ID against every block, while
the BIS window only offers the tracks of the current season.

Blocks live in `BetterGearCompare_Constants.lua` (`upgradeTrackBlocks`,
`currentUpgradeBlock`). Current data:

| Block | Bonus IDs | Tracks | Ranks |
|-------|-----------|--------|-------|
| Midnight season 1 | 12761–12806 | Explorer, Adventurer, Veteran, Champion, Hero, Myth | 8 / 6 |
| Midnight season 2 (current) | 12817–12854 | Adventurer, Veteran, Champion, Hero, Myth | 6 |
| Next season | 12865–12904 | Adventurer, Veteran, Champion, Hero, Myth | 8 |

When a season starts, refresh the table:

```bash
python scripts/extract_upgrade_tracks.py            # prints the Lua block to paste
python scripts/extract_upgrade_tracks.py --verify   # exits 2 when Constants is stale
```

The release workflow runs `--verify` and prints a warning if the table is stale.

## BIS Item Strings

Items in the BIS window use WoW item strings with bonus IDs to show correct item levels per difficulty tier:

```
item:ITEMID::::::::::::NUM_BONUSES:BONUSID[:CONTEXT_BONUS]
```

`BONUSID` is the highest rank of the selected track from the current block, and the
optional context bonus only sets the difficulty label shown in the tooltip:

| Difficulty label | Context bonus |
|------------------|---------------|
| Raid Finder | 13332 |
| Heroic | 13334 |
| Mythic | 13335 |

## Build & Release

### Local install

```bash
python scripts/install.py
```

Copies addon to `/Applications/World of Warcraft/_retail_/Interface/AddOns/BetterGearCompare`.

### Release build

```bash
./build-release.sh 0.4.0
```

Generates trinket + BIS data, packages everything into `Release/BetterGearCompare-0.4.0.zip`.

### CI

GitHub Actions workflow (`.github/workflows/release.yml`) triggers on `v*` tags:

1. Installs `curl_cffi`
2. Checks the upgrade-track table against Wowhead (warning only)
3. Runs both data generators (fetches live Wowhead data)
4. Packages release zip
5. Publishes GitHub release

## Slash Commands

| Command | Action |
|---------|--------|
| `/bgc` | Open settings |
| `/bgc bis` | Open BIS gear browser |
| `/bgc debug` | Toggle debug mode |

## TODO
- [ ] Add game icon
- [ ] Add minimap button
- [ ] Compare both weapons if dual
- [x] Compare max level item (findout bonusID)
