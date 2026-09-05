# Trinkets and special effects

## Separate classification from valuation

Midnight 12.1 makes it possible to detect many special items without parsing localized prose. It does **not** make their performance value a structured Blizzard stat.

The addon needs two independent answers:

1. Does this item/state contain an effect outside the ordinary stat model?
2. If so, does the packaged model explicitly support that effect for this spec/build/profile/item level and pair state?

An item may be confidently classified as special while remaining unvalued.

## Conservative structured detection

Use all available signals:

- `C_TooltipInfo.GetHyperlink(itemLink)` or `GetInventoryItem` returns `TooltipData` with structured lines.
- In 12.1, `Enum.TooltipDataLineType` contains `ItemSpellTriggerOnUse` (44), `ItemSpellTriggerOnEquip` (45), and `ItemSpellTriggerOnProc` (46). These values are in Blizzard's current [TooltipInfo shared documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua).
- `C_Item.GetItemSpell(itemInfo)` and `C_Item.GetFirstTriggeredSpellForItem(itemID, quality)` identify some item-triggered spells ([live Item API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)).
- `setID` plus `C_Item.GetSetBonusesForSpecializationByItemID(specID, itemID)` identifies set involvement.
- a build-generated catalog from client DB2/SimC data identifies item-effect records, embellishments, cantrips, limit categories, and known exceptions.
- unknown `C_Item.GetItemStats` keys or a known bonus-effect ID not classified as ordinary forces the special/unsupported path.

Use line **types and spell IDs**, not `leftText` string matching. Localized text may be shown to the user, but it must not determine semantics.

```lua
local data = C_TooltipInfo.GetHyperlink(itemLink)
for _, line in ipairs(data.lines or {}) do
  local t = line.type
  if t == Enum.TooltipDataLineType.ItemSpellTriggerOnUse
      or t == Enum.TooltipDataLineType.ItemSpellTriggerOnEquip
      or t == Enum.TooltipDataLineType.ItemSpellTriggerOnProc then
    classification.hasTriggeredEffect = true
  end
end
```

Tooltip data can also be asynchronous/incomplete. Classification is `pending` until the item snapshot and effect probes complete; absence of a line in incomplete data is not proof of a stat stick.

## Special categories

At minimum classify:

- passive stat-only item;
- random proc stat buff;
- damage/healing proc;
- on-use stat buff;
- on-use damage/healing/utility;
- special/cantrip weapon;
- embellishment or crafted special effect;
- tier/set item;
- scripted ring/neck/armor effect;
- defensive/utility effect outside the selected objective;
- unknown special effect.

The category is diagnostic and helps choose a generator. It is not itself a numeric score.

## Why normal stat weights fail here

An on-use or proc effect depends on uptime, internal cooldown, proc-per-minute rules, target count, damage school, stat snapshotting, cooldown synchronization, movement, encounter duration, execute windows, and the action priority list. Two trinkets can compete for use timing or gain value together. A tier item can alter the rotation. A weapon can change both DPS coefficients and triggered effects.

None of these are represented by primary/Crit/Haste/Mastery/Versatility totals. Assigning an ordinal letter tier a number and displaying a percentage difference is equally invalid: ranks are ordered categories, not ratio-scale performance measurements.

## Recommended special-effect data model

Handle ordinary stats through the regular state response surface. Store only the modeled **incremental effect contribution** and its uncertainty for recognized effects:

```lua
EffectCatalog[itemID] = {
  effectKey = "mid2_item_123456_effect_a",
  category = "on_use_damage",
  spellIDs = { 123, 456 },
  supportedSlots = { 13, 14 },
  uniqueCategoryID = 789,
  model = {
    [specID] = {
      [archetypeProfileKey] = {
        itemLevelKnots = { 305, 308, 311, 315, 318, 321 },
        deltaLogPerformance = { ... },
        errorP95 = { ... },
        anchorSpread = { ... },
        partnerPolicy = "one_on_use_only",
      },
    },
  },
}
```

Using log-performance deltas lets the contribution combine with the ordinary model as a relative effect rather than an arbitrary “equivalent-stat” number. Keep explicit item-level knots and bounded piecewise interpolation. Six values are cheap, preserve rounding/non-smooth changes, and are safer than assuming a polynomial curve.

The full state score is conceptually:

```text
log score = ordinaryStateSurface(stats, weapon)
          + supportedEffectDelta(item A, context)
          + supportedEffectDelta(item B, context)
          + supportedPairCorrection(A, B, context)
```

If a required effect or pair correction is missing, do not compute a confident total.

## Generation pipeline

For each supported item/spec/archetype/profile/rank:

1. construct a legal reference loadout at several realistic stat-distribution anchors;
2. simulate the actual item with its normal stats and effect;
3. simulate a synthetic clone with the same ordinary stats/weapon properties but no special effect;
4. take the paired difference, retaining SimulationCraft error;
5. repeat at each real item-level knot and anchor;
6. fit/store a bounded curve and the between-anchor spread;
7. validate against independent complete-loadout swaps and direct Top Gear-style simulations.

SimulationCraft supports explicit item stats, weapon properties, and custom use/equip effects, and its own model includes item-level scaling for special effects ([SimulationCraft equipment documentation](https://github.com/simulationcraft/simc/wiki/Equipment)). Its spell/effect data can scale from item level and item budgets ([SimC spell-data implementation](https://github.com/simulationcraft/simc/blob/midnight/engine/dbc/spell_data.cpp)). Some effects still require hand-maintained SimC code, which is precisely why support must be explicit and versioned.

### Context anchors

A one-dimensional item-level curve is insufficient if effect value varies materially with the surrounding stat distribution. Generate at least balanced and relevant stat-skew anchors; store the spread as uncertainty or interpolate across a small anchor set. If anchor spread exceeds the special-model release gate, that item/profile is unsupported rather than given a wider-looking but misleading exact percentage.

### Pair interactions

A complete trinket-pair matrix is quadratic in item count. Prefer this staged policy:

1. passive independent effects: additive if validation passes;
2. one on-use plus passive: supported under the APL's declared use policy;
3. two on-use effects or known shared-timing interactions: require a generated pair correction/table;
4. unknown pair: “simulation recommended.”

Direct pair tables should cover only the current-season supported set and use symmetric packed keys. Never assume “best individual two” equals “best pair.”

## Data volume and compute cost

For 80 special items, 26 DPS specs, two profiles, two archetypes, six ranks, and three context anchors, the upper-bound grid is about 150,000 simulated item actors before pair tests. Curating only relevant item/spec combinations and batching profilesets reduces this substantially, but special data will likely cost as much compute as the ordinary response models.

Storage is manageable if curves are packed. Eighty items × 26 specs × 2 profiles × 2 archetypes × six 16-bit values is roughly 100 KB of raw curve values before error/metadata; Lua-table overhead can multiply that several times. Context anchors and pair corrections can move the practical compressed bundle into low single-digit megabytes. CI should enforce per-spec lazy-loading and bundle budgets.

The maintenance cost, not raw file size, is the limiting factor: every relevant hotfix to an effect, APL, talent, or item-level curve can invalidate generated values.

## Tier and set items

Build a set-state guard before ordinary evaluation:

```text
active set bonuses before = B0
active set bonuses after  = B1
```

- If `B0 == B1`, ordinary stat comparison may proceed, with a note that the same set state was preserved.
- If a 2-piece/4-piece or other set effect activates, deactivates, or changes, require an explicitly supported set model.
- If unsupported, show “Changes your set bonus — simulation recommended.”

Blizzard's 12.1 notes also state that Catalyst conversion retains an item's original secondary stats and cantrip effect, reinforcing the need to identify exact item/effect state rather than assume a generic tier template ([official reward changes](https://us.forums.blizzard.com/en/wow/t/curse-of-ulatek-endgame-reward-changes/2317450)).

## Embellishments and special weapons

Treat embellishments and cantrip weapons like trinket effects:

- enforce their limit category in state legality;
- include the exact effect identity and item level;
- include weapon DPS/speed in the ordinary component;
- require a generated effect curve for the special component;
- require pair/set corrections where applicable.

A high-item-level special weapon without a supported effect is not safely reducible to its visible stats. The UI may display the visible-stat direction separately, but the headline must remain “special effect not evaluated.”

## Direct rankings and equivalent-stat values

- **Direct item rankings** are compact for one fixed profile but do not compose with the player's stats, second trinket, or upgrades.
- **Equivalent-stat values** are easier to add to ordinary scores but inherit the same context dependence as stat weights.
- **Incremental log-performance curves** preserve a meaningful relative unit and expose uncertainty, but still need context/pair validation.

Therefore use incremental effect curves internally, and only generate a ranking as a presentation derived from the same versioned simulations. Never ingest a web tier list as the evaluator.

## Runtime outcomes

The special path returns one of:

- `stat_only_supported`: ordinary model may evaluate it;
- `special_supported`: numeric result with special-model provenance and at most the confidence allowed by validation/pair policy;
- `special_pair_unsupported`: known items, unknown interaction;
- `set_change_unsupported`;
- `effect_detected_unknown`;
- `effect_data_stale`;
- `effect_detection_pending`.

For every unsupported outcome, the correct headline is a warning, not a zero score:

```text
Special effect — unable to evaluate reliably
Visible stats alone: +1.1% (not a full recommendation)
Simulation recommended
```

The optional visible-stat line must never drive KEEP/DISCARD by itself.
