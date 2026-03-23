# BetterGearCompare

BetterGearCompare is a lightweight World of Warcraft addon for Retail that helps you decide whether a new item is better or worse for your current specialization.

Instead of relying on generic item level alone, the addon compares gear based on stat weights that you set yourself. This makes it useful for players who want a simple recommendation system without a full simulation workflow inside the game.

## What the addon does

- Adds a short comparison block to item tooltips.
- Compares regular gear using your custom stat priority weights.
- Supports separate setups for different specializations.
- Shows an upgrade icon on bag items.
- Uses a separate tier-based system for trinkets.

## How to open the settings

You can open the addon settings in two ways:

- Type `/bgc` in chat.
- Open `Game Menu -> Options -> AddOns -> BetterGearCompare`.

## Stat weights

For most items, BetterGearCompare uses weighted stat comparison.

You choose how valuable each stat is for your specialization. You can use priorities from sites such as Archon, Wowhead, or other class guides.

A common example looks like this:

- Main stat: `10`
- Secondary stats: `7.52`, `6.80`, and so on

The exact numbers are up to you. The addon will compare items based on the weights you enter and estimate whether a new piece of gear is better, worse, or roughly equal for your spec.

## Trinket support

Trinkets are handled differently.

Because trinkets usually cannot be evaluated well through normal stat weights alone, BetterGearCompare uses spec-based trinket tier data instead of standard stat comparison.

For each class and specialization, the addon includes a trinket tier list based on official Wowhead guides. When you hover a trinket, the addon can show which tier it belongs to:

- `S`
- `A`
- `B`
- `C`
- `D`

If a trinket is not present in the tier list for your specialization, the addon will tell you that it is not included in the tier list instead of making a misleading stat-based comparison.

## Localization

BetterGearCompare includes built-in localization support.

Current language support:

- English
- German
- Italian
- Russian
- Simplified Chinese
- Traditional Chinese

## Notes

- Stat weights are only as good as the values you enter.
- Trinket recommendations depend on the current Wowhead guide data included with the addon.
- Different specs should usually have different weight profiles.

## Summary

BetterGearCompare is built for players who want fast and practical tooltip advice:

- weighted comparison for normal gear
- specialization-specific profiles
- trinket recommendations based on Wowhead tier lists
- quick setup directly in-game
