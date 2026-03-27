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
| `verify_wowhead_trinket_guides.py` | Validate guide URLs are still reachable |
| `install.py` | Copy addon files to local WoW AddOns directory |

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

## BIS Item Strings

Items in the BIS window use WoW item strings with bonus IDs to show correct item levels per difficulty tier:

```
item:ITEMID::::::::::::NUM_BONUSES:BONUSID[:CONTEXT_BONUS]
```

Upgrade tracks (fixed at 6/8 per tier):

| Tier | Bonus ID | Context Bonus |
|------|----------|---------------|
| Veteran (LFR) | 12782 | 13332 |
| Champion (Normal) | 12790 | — |
| Hero (Heroic) | 12798 | 13334 |
| Myth (Mythic) | 12806 | 13335 |

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
2. Runs both data generators (fetches live Wowhead data)
3. Packages release zip
4. Publishes GitHub release

## Slash Commands

| Command | Action |
|---------|--------|
| `/bgc` | Open settings |
| `/bgc bis` | Open BIS gear browser |
| `/bgc debug` | Toggle debug mode |
