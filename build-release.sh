#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

SOURCE="$(cd "$(dirname "$0")" && pwd)"
RELEASE_ROOT="$SOURCE/Release"
STAGING_ROOT="$RELEASE_ROOT/staging"
ADDON_NAME="BetterGearCompare"
ADDON_ROOT="$STAGING_ROOT/$ADDON_NAME"

TRINKET_GENERATOR="$SOURCE/scripts/generate_wowhead_trinket_lua.py"
TRINKET_LUA="$SOURCE/BetterGearCompare_TrinketData.lua"

BIS_GENERATOR="$SOURCE/scripts/generate_wowhead_bis_lua.py"
BIS_LUA="$SOURCE/BetterGearCompare_BisData.lua"

TOC_PATH="$SOURCE/BetterGearCompare.toc"

if [[ ! -f "$TOC_PATH" ]]; then
  echo "Error: TOC file not found: $TOC_PATH" >&2; exit 1
fi
if [[ ! -f "$TRINKET_GENERATOR" ]]; then
  echo "Error: Trinket generator script not found: $TRINKET_GENERATOR" >&2; exit 1
fi
if [[ ! -f "$BIS_GENERATOR" ]]; then
  echo "Error: BIS generator script not found: $BIS_GENERATOR" >&2; exit 1
fi

echo "Generating trinket data Lua file..."
python3 "$TRINKET_GENERATOR"
if [[ ! -f "$TRINKET_LUA" ]]; then
  echo "Error: Generated trinket Lua not found: $TRINKET_LUA" >&2; exit 1
fi

echo "Generating BIS gear data Lua file..."
python3 "$BIS_GENERATOR"
if [[ ! -f "$BIS_LUA" ]]; then
  echo "Error: Generated BIS Lua not found: $BIS_LUA" >&2; exit 1
fi

if [[ -z "$VERSION" ]]; then
  VERSION=$(grep -oP '## Version:\s*\K.+' "$TOC_PATH" | tr -d '[:space:]' || echo "dev")
fi

rm -rf "$RELEASE_ROOT"
mkdir -p "$ADDON_ROOT"

FILES=(
  BetterGearCompare.toc
  BetterGearCompare.lua
  BetterGearCompare_Localization.lua
  BetterGearCompare_Constants.lua
  BetterGearCompare_DB.lua
  BetterGearCompare_Stats.lua
  BetterGearCompare_SpecRules.lua
  BetterGearCompare_TrinketData.lua
  BetterGearCompare_BisData.lua
  BetterGearCompare_BisUI.lua
  BetterGearCompare_Compare.lua
  BetterGearCompare_Tooltip.lua
  BetterGearCompare_Options.lua
  BetterGearCompare_Icons.lua
  README.md
)

for file in "${FILES[@]}"; do
  cp "$SOURCE/$file" "$ADDON_ROOT/$file"
done

cp -r "$SOURCE/Locales" "$ADDON_ROOT/Locales"
cp -r "$SOURCE/Media" "$ADDON_ROOT/Media"

ZIP_NAME="${ADDON_NAME}-${VERSION}.zip"
ZIP_PATH="$RELEASE_ROOT/$ZIP_NAME"
(cd "$STAGING_ROOT" && zip -r "$ZIP_PATH" "$ADDON_NAME")

echo "Created release archive: $ZIP_PATH"
