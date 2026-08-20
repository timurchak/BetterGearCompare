local _, ns = ...

local L = ns.L

ns.Constants = {
  defaultProfileName = "Default",
  settingsCategoryName = L.SETTINGS_CATEGORY,
  statDefinitions = {
    { key = "ITEM_MOD_STRENGTH_SHORT", label = ITEM_MOD_STRENGTH_SHORT or "Strength" },
    { key = "ITEM_MOD_AGILITY_SHORT", label = ITEM_MOD_AGILITY_SHORT or "Agility" },
    { key = "ITEM_MOD_INTELLECT_SHORT", label = ITEM_MOD_INTELLECT_SHORT or "Intellect" },
    { key = "ITEM_MOD_STAMINA_SHORT", label = ITEM_MOD_STAMINA_SHORT or "Stamina" },
    { key = "ITEM_MOD_CRIT_RATING_SHORT", label = ITEM_MOD_CRIT_RATING_SHORT or "Critical Strike" },
    { key = "ITEM_MOD_HASTE_RATING_SHORT", label = ITEM_MOD_HASTE_RATING_SHORT or "Haste" },
    { key = "ITEM_MOD_MASTERY_RATING_SHORT", label = ITEM_MOD_MASTERY_RATING_SHORT or "Mastery" },
    { key = "ITEM_MOD_VERSATILITY", label = ITEM_MOD_VERSATILITY or "Versatility" },
  },
  slotCandidates = {
    INVTYPE_HEAD = { INVSLOT_HEAD },
    INVTYPE_NECK = { INVSLOT_NECK },
    INVTYPE_SHOULDER = { INVSLOT_SHOULDER },
    INVTYPE_CHEST = { INVSLOT_CHEST },
    INVTYPE_ROBE = { INVSLOT_CHEST },
    INVTYPE_WAIST = { INVSLOT_WAIST },
    INVTYPE_LEGS = { INVSLOT_LEGS },
    INVTYPE_FEET = { INVSLOT_FEET },
    INVTYPE_WRIST = { INVSLOT_WRIST },
    INVTYPE_HAND = { INVSLOT_HAND },
    INVTYPE_FINGER = { INVSLOT_FINGER1, INVSLOT_FINGER2 },
    INVTYPE_TRINKET = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 },
    INVTYPE_CLOAK = { INVSLOT_BACK },
    INVTYPE_WEAPON = { INVSLOT_MAINHAND, INVSLOT_OFFHAND },
    INVTYPE_2HWEAPON = { INVSLOT_MAINHAND },
    INVTYPE_WEAPONMAINHAND = { INVSLOT_MAINHAND },
    INVTYPE_WEAPONOFFHAND = { INVSLOT_OFFHAND },
    INVTYPE_HOLDABLE = { INVSLOT_OFFHAND },
    INVTYPE_SHIELD = { INVSLOT_OFFHAND },
    INVTYPE_RANGED = { INVSLOT_MAINHAND },
    INVTYPE_RANGEDRIGHT = { INVSLOT_MAINHAND },
    INVTYPE_THROWN = { INVSLOT_MAINHAND },
    INVTYPE_RELIC = { INVSLOT_MAINHAND },
  },
  slotLabels = {
    [INVSLOT_HEAD] = INVTYPE_HEAD or "head",
    [INVSLOT_NECK] = INVTYPE_NECK or "neck",
    [INVSLOT_SHOULDER] = INVTYPE_SHOULDER or "shoulder",
    [INVSLOT_CHEST] = INVTYPE_CHEST or "chest",
    [INVSLOT_WAIST] = INVTYPE_WAIST or "waist",
    [INVSLOT_LEGS] = INVTYPE_LEGS or "legs",
    [INVSLOT_FEET] = INVTYPE_FEET or "feet",
    [INVSLOT_WRIST] = INVTYPE_WRIST or "wrist",
    [INVSLOT_HAND] = INVTYPE_HAND or "hands",
    [INVSLOT_FINGER1] = (INVTYPE_FINGER or "finger") .. " 1",
    [INVSLOT_FINGER2] = (INVTYPE_FINGER or "finger") .. " 2",
    [INVSLOT_TRINKET1] = (INVTYPE_TRINKET or "trinket") .. " 1",
    [INVSLOT_TRINKET2] = (INVTYPE_TRINKET or "trinket") .. " 2",
    [INVSLOT_BACK] = INVTYPE_CLOAK or "back",
    [INVSLOT_MAINHAND] = INVTYPE_WEAPONMAINHAND or "main hand",
    [INVSLOT_OFFHAND] = INVTYPE_WEAPONOFFHAND or "off hand",
  },
  -- Gear upgrade tracks. Every track owns `ranks` consecutive bonus IDs starting
  -- at baseBonus, one per upgrade rank, and Blizzard hands out a fresh block of
  -- IDs each season. Gear from an older season keeps the previous block's IDs, so
  -- all blocks have to be recognised to rebuild an item link at its max rank.
  -- Refresh with: python scripts/extract_upgrade_tracks.py
  upgradeTrackBlocks = {
    { -- bonus 12761-12806, Midnight season 1
      { key = "EXPLORER", baseBonus = 12761, ranks = 8 },
      { key = "ADVENTURER", baseBonus = 12769, ranks = 6 },
      { key = "VETERAN", baseBonus = 12777, ranks = 6 },
      { key = "CHAMPION", baseBonus = 12785, ranks = 6 },
      { key = "HERO", baseBonus = 12793, ranks = 6 },
      { key = "MYTH", baseBonus = 12801, ranks = 6 },
    },
    { -- bonus 12817-12854, Midnight season 2, current season
      { key = "ADVENTURER", baseBonus = 12817, ranks = 6 },
      { key = "VETERAN", baseBonus = 12825, ranks = 6 },
      { key = "CHAMPION", baseBonus = 12833, ranks = 6 },
      { key = "HERO", baseBonus = 12841, ranks = 6 },
      { key = "MYTH", baseBonus = 12849, ranks = 6 },
    },
    { -- bonus 12865-12904, next season
      { key = "ADVENTURER", baseBonus = 12865, ranks = 8 },
      { key = "VETERAN", baseBonus = 12873, ranks = 8 },
      { key = "CHAMPION", baseBonus = 12881, ranks = 8 },
      { key = "HERO", baseBonus = 12889, ranks = 8 },
      { key = "MYTH", baseBonus = 12897, ranks = 8 },
    },
  },
  currentUpgradeBlock = 2,
  -- Raid difficulty context bonus IDs, shared by all seasons.
  upgradeTrackContextBonus = {
    VETERAN = 13332,
    HERO = 13334,
    MYTH = 13335,
  },
  tooltipMethods = {
    "SetBagItem",
    "SetHyperlink",
    "SetInventoryItem",
    "SetItemByID",
    "SetLootItem",
    "SetLootRollItem",
    "SetMerchantItem",
    "SetQuestItem",
    "SetQuestLogItem",
    "SetInboxItem",
    "SetBuybackItem",
    "SetTradePlayerItem",
    "SetTradeTargetItem",
    "SetItemInteractionItem",
  },
}

-- Flatten the upgrade tracks: comparisons match a bonus ID against every season,
-- while the BIS window only offers the tracks of the current one.
local allUpgradeTracks = {}
local minBonus, maxBonus

for blockIndex, block in ipairs(ns.Constants.upgradeTrackBlocks) do
  for _, track in ipairs(block) do
    track.blockIndex = blockIndex
    track.maxBonus = track.baseBonus + track.ranks - 1
    track.contextBonus = ns.Constants.upgradeTrackContextBonus[track.key]

    allUpgradeTracks[#allUpgradeTracks + 1] = track

    if not minBonus or track.baseBonus < minBonus then
      minBonus = track.baseBonus
    end
    if not maxBonus or track.maxBonus > maxBonus then
      maxBonus = track.maxBonus
    end
  end
end

ns.Constants.allUpgradeTracks = allUpgradeTracks
ns.Constants.upgradeTracks = ns.Constants.upgradeTrackBlocks[ns.Constants.currentUpgradeBlock] or {}
ns.Constants.UPGRADE_BONUS_MIN = minBonus or 0
ns.Constants.UPGRADE_BONUS_MAX = maxBonus or 0
