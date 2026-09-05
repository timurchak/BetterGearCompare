# Weapons and equipment states

## Central rule

The comparison unit is a complete legal equipment state, not a candidate item and an arbitrarily selected worn slot.

```text
currentState -> enumerate candidate-containing legal states
             -> evaluate every supported state
             -> choose the best supported state
             -> report exactly which item(s) change
```

This rule resolves rings, trinkets, unique-equipped limits, and one-hand/two-hand transitions with one abstraction.

## Structured inventory and eligibility inputs

Use these APIs as inputs, with a versioned rule layer where Blizzard does not expose a pure hypothetical-equip validator:

| Need | API | Notes |
|---|---|---|
| Worn link | `GetInventoryItemLink("player", slotID)` | Structured link for slots 1–19 ([reference](https://warcraft.wiki.gg/wiki/API:GetInventoryItemLink)) |
| Bag enumeration | `C_Container.GetContainerNumSlots`, `C_Container.GetContainerItemLink`, `C_Container.GetContainerItemInfo` | Preserve bag/slot `ItemLocation` and GUID; do not key by item ID only |
| Native slot candidates | `GetInventoryItemsForSlot(slotID, table)` | Useful cross-check for items Blizzard considers for a slot ([reference](https://warcraft.wiki.gg/wiki/API:GetInventoryItemsForSlot)) |
| Basic item kind | `C_Item.GetItemInfoInstant` | Item ID, `itemEquipLoc`, class/subclass; may still return nothing for invalid input |
| Equippable | `C_Item.IsEquippableItem` | Basic filter, not a complete hypothetical loadout validator |
| Player can use | `C_PlayerInfo.CanUseItem(itemID)` | Class/level/useability gate ([reference](https://warcraft.wiki.gg/wiki/API:C_PlayerInfo.CanUseItem)) |
| Spec association | `C_Item.DoesItemContainSpec(itemInfo, classID, specID)` / `GetItemSpecInfo` | Treat as suitability/loot-spec evidence, not sole equip legality |
| Unique category | `C_Item.GetItemUniquenessByID` | Returns unique flag, limit-category name/count/ID ([reference](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemUniquenessByID)) |
| Dual wield capability | `CanDualWield()`, `IsDualWielding()` | Current character capability/state; insufficient for all talent-specific weapon rules |
| Spec/build | `C_SpecializationInfo.GetSpecialization`, `GetSpecializationInfo`, `C_ClassTalents.GetActiveConfigID`, `C_Traits.*` | Use selected-node/rank fingerprint, not the local config ID alone |
| Item instance | `C_Item.GetItemGUID(itemLocation)` | Prevents synthesizing a second copy and distinguishes duplicate instances |

`C_PaperDollInfo.CanCursorCanGoInSlot(slotIndex)` requires an item on the cursor and is therefore inappropriate for passive tooltip evaluation. The addon should never pick up or equip an item merely to test legality.

## Slot topology

The relevant inventory topology is:

- ordinary single slots: head 1, neck 2, shoulder 3, back 15, chest 5, wrist 9, hands 10, waist 6, legs 7, feet 8;
- rings: slots 11 and 12, treated as an unordered pair plus instance/unique constraints;
- trinkets: slots 13 and 14, treated as a pair plus effect/use constraints;
- weapons: main hand 16 and off hand 17, treated as one configuration;
- shirt/tabard/profession equipment are outside the performance loadout.

`C_Item.GetItemInventoryType` / `GetItemInventoryTypeByID` and `C_Item.GetItemInventorySlotInfo` expose inventory types, while `itemEquipLoc` strings distinguish `INVTYPE_WEAPON`, `INVTYPE_WEAPONMAINHAND`, `INVTYPE_WEAPONOFFHAND`, `INVTYPE_2HWEAPON`, `INVTYPE_SHIELD`, `INVTYPE_HOLDABLE`, and ranged forms ([inventory-slot reference](https://warcraft.wiki.gg/wiki/API:C_Item.GetItemInventorySlotInfo)).

Do not treat equip location alone as proof that the current spec can use that item or combination.

## State model

An immutable state should retain exact instances and normalized performance inputs:

```lua
LoadoutState = {
  specID = 71,
  archetypeID = "arms_colossus_12_1_a",
  talentFingerprint = "...",
  slots = {
    [11] = ItemSnapshot,
    [12] = ItemSnapshot,
    [16] = ItemSnapshot,
    [17] = nil,
    -- ...
  },
  uniqueCategoryCounts = { [categoryID] = count },
  setCounts = { [setID] = count },
  aggregateStats = { ... },
  revision = 42,
}
```

The state revision changes on equipment, bag/item-instance, spec, talent, enchant, or socket changes. An evaluation captures the revision and is discarded if the live revision changes before presentation.

## Rings

For a candidate ring, enumerate at least:

```text
state A = candidate in slot 11, current slot 12 retained
state B = current slot 11 retained, candidate in slot 12
```

Reject either state if the candidate instance is already used elsewhere or a unique category/count would be violated. Evaluate both complete states and report the better legal one:

```text
Replaces Signet of A in Ring 1
Keeps Band of B in Ring 2
```

Never collapse two rings to a single virtual worn item. Never decide from item level alone. If both results are within uncertainty, say that either replacement is effectively tied rather than implying exact ordering.

## Trinkets

Use the same two-state enumeration, but pass each pair to the special-effect evaluator. Two individually valid trinkets can interact through on-use timing, shared lockouts, proc overlap, role, or unique categories. A simple stat-only trinket can use the ordinary model; any recognized trigger routes to the special path.

An unknown special candidate must not be compared as zero against a known one. The result is “special effect unsupported,” with both possible replacement states retained for an external simulation recommendation.

## Weapon configuration types

Represent the weapon state explicitly:

```lua
WeaponState = {
  main = ItemSnapshot or nil,
  off = ItemSnapshot or nil,
  kind = "two_hand" | "dual_wield_1h" | "dual_wield_2h"
       | "one_hand_shield" | "one_hand_holdable"
       | "one_hand_empty" | "ranged",
}
```

### Two-handed candidate

A two-handed candidate occupies main hand and clears off hand:

```text
(candidate 2H, empty) versus (current main, current off)
```

The removed off-hand stats/effects are part of the delta. For an ordinary weapon, weapon DPS/speed and all stats must be present in the model. For a cantrip/special weapon, route to the special path.

### Generic one-handed candidate

If the current state is a two-hander, the candidate is not evaluated as `candidate × 2`. Enumerate actual companion instances in the configured availability scope:

- eligible one-handed off-hand weapons if the build can dual wield them;
- an eligible shield for a shield configuration;
- an eligible held-in-off-hand item for a caster configuration;
- optionally a legal empty off-hand state, labeled incomplete and never substituted for “best valid available off-hand.”

Each candidate state contains the received item instance exactly once. Example:

```text
(new 1H, bag shield A)
(new 1H, bag off-hand B)
(new 1H, existing off-hand C) -- only if C actually exists outside the 2H state
```

The tooltip should identify the winning companion:

```text
With: Bulwark of X from your bags
Compared with: current two-handed weapon
```

If no suitable companion is available, return:

```text
Needs a compatible off-hand to compare with your two-hander
```

That is more correct than manufacturing an item or declaring the one-hander bad in isolation.

### Main-hand-only candidate

Place only in slot 16. Retain slot 17 only if that resulting combination is legal. If current main hand is a two-hander, the old off-hand is already empty; companion enumeration follows the one-hand rules.

### Off-hand weapon, shield, or held-in-off-hand candidate

Place only in slot 17 and pair it with:

- the current compatible one-hand main weapon, or
- each compatible owned main-hand candidate in inventory when the current main hand is a two-hander.

Do not compare an off-hand item independently to a two-handed weapon.

### Dual wield and Titan's Grip

`CanDualWield()` is a useful live capability signal, but it does not fully state which subclasses/hands a particular spec/build permits. Fury's one-hand and two-hand dual-wield cases, rogue dagger requirements, Enhancement weapon constraints, and shield builds require a versioned capability manifest plus talent fingerprint where relevant. Every manifest rule needs in-client fixture tests.

Fallback policy must be deny/unsupported, not “all one-hand and two-hand combinations are probably fine.”

### Ranged weapons

Bows, guns, and crossbows occupy the main-hand configuration and normally exclude an off-hand. Wands and other subclass-specific cases must follow the live inventory type and the spec capability manifest. Do not reuse melee weapon-speed coefficients for ranged states.

## Armor and specialization rules

There are two distinct questions:

1. **Can the character equip/use it?** Use Blizzard's structured class/level/equippable signals.
2. **Is it a supported performance state for this specialization?** Use the model/archetype manifest.

A plate wearer may technically equip a lower armor type but lose armor specialization assumptions. V1 should classify nonpreferred armor as unsupported/not recommended rather than calculate a deceptively precise DPS delta. `DoesItemContainSpec` can be an additional consistency check, but it is not a substitute for the performance model or complete legality rules.

## Unique-equipped, crafted, and set constraints

Before scoring a state:

- count every `limitCategoryID` and enforce `limitCategoryCount` from `C_Item.GetItemUniquenessByID`;
- also enforce exact-instance uniqueness by GUID/location;
- treat embellishment/category limits as special constraints from the generated effect manifest if the generic API does not expose enough detail;
- retain the item's exact crafted bonus/quality and do not invent a recraft;
- count set pieces and compare active thresholds before and after.

`C_Item.GetItemInfo` returns a `setID`, and `C_Item.GetSetBonusesForSpecializationByItemID(specID, itemID)` exposes relevant set-bonus spell IDs ([live Item API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)). If a candidate activates, removes, or changes a modeled set bonus, the ordinary stat result is not sufficient.

## Availability scope

The default “best valid companion” scope should be explicit and fresh:

- currently equipped items;
- backpack and equipped bags;
- the candidate item itself.

Bank, reagent bank, Warband bank, mail, and void storage should not be assumed available or current when their UI/data is not loaded. Later versions may offer “include known bank items” with a timestamp and a clearly labeled stale-data risk. V1 should say “best compatible item in your bags,” not “best item you own.”

## Enumeration algorithm

```text
1. Snapshot current complete loadout and bag item instances.
2. Classify candidate inventory type and special constraints.
3. Generate only topologically possible slot/configuration substitutions.
4. Add actual companions from the availability scope.
5. Validate each item, hand, spec/build, unique category, armor, and set constraint.
6. Normalize replaceable enhancements according to one declared policy.
7. Route each state to ordinary, special, or unsupported evaluation.
8. Rank only mutually comparable supported states.
9. Report the winning state, runner-up/tie when relevant, and reason codes.
```

Because inventory size is small, correctness is more important than clever pruning. Cache normalized item snapshots and aggregate-state deltas, but preserve exhaustive enumeration in tests.

## Failure behavior

Return typed outcomes, never `nil` or score zero:

- `not_equippable`
- `wrong_spec_or_armor`
- `no_compatible_companion`
- `unique_limit_violation`
- `unsupported_weapon_rule`
- `missing_weapon_dps_or_speed`
- `special_effect_unsupported`
- `set_threshold_changed`
- `item_data_pending` / `item_data_failed`

These reason codes drive both tooltip language and diagnostics. They also prevent the presenter from turning an internal absence into a confident downgrade.
