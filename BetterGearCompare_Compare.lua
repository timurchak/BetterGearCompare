local _, ns = ...

ns.Compare = {}

local Constants = ns.Constants
local L = ns.L

local ARMOR_SUBCLASS = {
  CLOTH = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Cloth or 1,
  LEATHER = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Leather or 2,
  MAIL = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Mail or 3,
  PLATE = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Plate or 4,
  GENERIC = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Generic or 0,
  COSMETIC = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Cosmetic or -1,
}

local WEAPON_SUBCLASS = {
  AXE1H = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Axe1H or 0,
  AXE2H = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Axe2H or 1,
  BOW = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Bows or 2,
  GUN = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Guns or 3,
  MACE1H = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Mace1H or 4,
  MACE2H = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Mace2H or 5,
  POLEARM = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Polearm or 6,
  SWORD1H = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Sword1H or 7,
  SWORD2H = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Sword2H or 8,
  WARGLAIVE = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Warglaive or 9,
  STAFF = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Staff or 10,
  FIST = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Unarmed or 13,
  DAGGER = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Dagger or 15,
  CROSSBOW = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Crossbow or 18,
  WAND = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Wand or 19,
}

local CLASS_ARMOR_PREFERENCE = {
  WARRIOR = ARMOR_SUBCLASS.PLATE,
  PALADIN = ARMOR_SUBCLASS.PLATE,
  DEATHKNIGHT = ARMOR_SUBCLASS.PLATE,
  HUNTER = ARMOR_SUBCLASS.MAIL,
  SHAMAN = ARMOR_SUBCLASS.MAIL,
  EVOKER = ARMOR_SUBCLASS.MAIL,
  ROGUE = ARMOR_SUBCLASS.LEATHER,
  DRUID = ARMOR_SUBCLASS.LEATHER,
  MONK = ARMOR_SUBCLASS.LEATHER,
  DEMONHUNTER = ARMOR_SUBCLASS.LEATHER,
  PRIEST = ARMOR_SUBCLASS.CLOTH,
  MAGE = ARMOR_SUBCLASS.CLOTH,
  WARLOCK = ARMOR_SUBCLASS.CLOTH,
}

local DUAL_WIELD_CLASSES = {
  WARRIOR = true,
  ROGUE = true,
  SHAMAN = true,
  MONK = true,
  DEMONHUNTER = true,
  DEATHKNIGHT = true,
}

local CLASS_WEAPON_PROFICIENCIES = {
  WARRIOR = {
    [WEAPON_SUBCLASS.AXE1H] = true, [WEAPON_SUBCLASS.AXE2H] = true,
    [WEAPON_SUBCLASS.MACE1H] = true, [WEAPON_SUBCLASS.MACE2H] = true,
    [WEAPON_SUBCLASS.POLEARM] = true,
    [WEAPON_SUBCLASS.SWORD1H] = true, [WEAPON_SUBCLASS.SWORD2H] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
    [WEAPON_SUBCLASS.FIST] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.BOW] = true, [WEAPON_SUBCLASS.GUN] = true, [WEAPON_SUBCLASS.CROSSBOW] = true,
  },
  PALADIN = {
    [WEAPON_SUBCLASS.AXE1H] = true, [WEAPON_SUBCLASS.AXE2H] = true,
    [WEAPON_SUBCLASS.MACE1H] = true, [WEAPON_SUBCLASS.MACE2H] = true,
    [WEAPON_SUBCLASS.POLEARM] = true,
    [WEAPON_SUBCLASS.SWORD1H] = true, [WEAPON_SUBCLASS.SWORD2H] = true,
  },
  DEATHKNIGHT = {
    [WEAPON_SUBCLASS.AXE1H] = true, [WEAPON_SUBCLASS.AXE2H] = true,
    [WEAPON_SUBCLASS.MACE1H] = true, [WEAPON_SUBCLASS.MACE2H] = true,
    [WEAPON_SUBCLASS.POLEARM] = true,
    [WEAPON_SUBCLASS.SWORD1H] = true, [WEAPON_SUBCLASS.SWORD2H] = true,
  },
  HUNTER = {
    [WEAPON_SUBCLASS.AXE1H] = true, [WEAPON_SUBCLASS.AXE2H] = true,
    [WEAPON_SUBCLASS.POLEARM] = true,
    [WEAPON_SUBCLASS.SWORD1H] = true, [WEAPON_SUBCLASS.SWORD2H] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.BOW] = true, [WEAPON_SUBCLASS.GUN] = true, [WEAPON_SUBCLASS.CROSSBOW] = true,
  },
  SHAMAN = {
    [WEAPON_SUBCLASS.AXE1H] = true, [WEAPON_SUBCLASS.AXE2H] = true,
    [WEAPON_SUBCLASS.MACE1H] = true, [WEAPON_SUBCLASS.MACE2H] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.FIST] = true,
  },
  EVOKER = {
    [WEAPON_SUBCLASS.AXE1H] = true,
    [WEAPON_SUBCLASS.MACE1H] = true,
    [WEAPON_SUBCLASS.SWORD1H] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.FIST] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
  },
  ROGUE = {
    [WEAPON_SUBCLASS.AXE1H] = true,
    [WEAPON_SUBCLASS.MACE1H] = true,
    [WEAPON_SUBCLASS.SWORD1H] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.FIST] = true,
    [WEAPON_SUBCLASS.BOW] = true, [WEAPON_SUBCLASS.GUN] = true, [WEAPON_SUBCLASS.CROSSBOW] = true,
  },
  DRUID = {
    [WEAPON_SUBCLASS.MACE1H] = true, [WEAPON_SUBCLASS.MACE2H] = true,
    [WEAPON_SUBCLASS.POLEARM] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.FIST] = true,
  },
  MONK = {
    [WEAPON_SUBCLASS.AXE1H] = true,
    [WEAPON_SUBCLASS.MACE1H] = true,
    [WEAPON_SUBCLASS.SWORD1H] = true,
    [WEAPON_SUBCLASS.POLEARM] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
    [WEAPON_SUBCLASS.FIST] = true,
  },
  DEMONHUNTER = {
    [WEAPON_SUBCLASS.AXE1H] = true,
    [WEAPON_SUBCLASS.SWORD1H] = true,
    [WEAPON_SUBCLASS.WARGLAIVE] = true,
    [WEAPON_SUBCLASS.FIST] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
  },
  PRIEST = {
    [WEAPON_SUBCLASS.MACE1H] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
    [WEAPON_SUBCLASS.WAND] = true,
  },
  MAGE = {
    [WEAPON_SUBCLASS.SWORD1H] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
    [WEAPON_SUBCLASS.WAND] = true,
  },
  WARLOCK = {
    [WEAPON_SUBCLASS.SWORD1H] = true,
    [WEAPON_SUBCLASS.DAGGER] = true,
    [WEAPON_SUBCLASS.STAFF] = true,
    [WEAPON_SUBCLASS.WAND] = true,
  },
}

local function Debug(...)
  if ns.DebugLog then
    ns:DebugLog(...)
  end
end

local function GetEquipLocation(itemLink)
  return select(4, C_Item.GetItemInfoInstant(itemLink))
end

local function GetItemClassAndSubclass(itemLink)
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
  return classID, subClassID
end

local function IsArmorEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_HEAD"
    or equipLocation == "INVTYPE_SHOULDER"
    or equipLocation == "INVTYPE_CHEST"
    or equipLocation == "INVTYPE_ROBE"
    or equipLocation == "INVTYPE_WAIST"
    or equipLocation == "INVTYPE_LEGS"
    or equipLocation == "INVTYPE_FEET"
    or equipLocation == "INVTYPE_WRIST"
    or equipLocation == "INVTYPE_HAND"
    or equipLocation == "INVTYPE_CLOAK"
end

local function IsWeaponEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_WEAPON"
    or equipLocation == "INVTYPE_2HWEAPON"
    or equipLocation == "INVTYPE_WEAPONMAINHAND"
    or equipLocation == "INVTYPE_WEAPONOFFHAND"
    or equipLocation == "INVTYPE_RANGED"
    or equipLocation == "INVTYPE_RANGEDRIGHT"
    or equipLocation == "INVTYPE_THROWN"
    or equipLocation == "INVTYPE_RELIC"
end

local function IsTwoHandEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_2HWEAPON"
end

local function IsMainHandOnlyEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_WEAPONMAINHAND"
end

local function IsOffHandOnlyEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_WEAPONOFFHAND"
    or equipLocation == "INVTYPE_HOLDABLE"
    or equipLocation == "INVTYPE_SHIELD"
end

local function IsPairableOneHandEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_WEAPON"
end

local function GetPlayerPreferredArmorSubclass()
  local _, classTag = UnitClass("player")
  return classTag and CLASS_ARMOR_PREFERENCE[classTag] or nil
end

local function CanPlayerDualWield()
  local _, classTag = UnitClass("player")
  return classTag and DUAL_WIELD_CLASSES[classTag] or false
end

local function IsPreferredArmorType(itemLink)
  local equipLocation = GetEquipLocation(itemLink)
  if not equipLocation or not IsArmorEquipLocation(equipLocation) then
    return true
  end

  local classID, subClassID = GetItemClassAndSubclass(itemLink)
  if classID ~= Enum.ItemClass.Armor then
    return true
  end

  if subClassID == ARMOR_SUBCLASS.GENERIC or subClassID == ARMOR_SUBCLASS.COSMETIC or equipLocation == "INVTYPE_CLOAK" then
    return true
  end

  local preferredSubclass = GetPlayerPreferredArmorSubclass()
  if not preferredSubclass then
    return true
  end

  return subClassID == preferredSubclass
end

local function IsUsableWeaponType(itemLink)
  local equipLocation = GetEquipLocation(itemLink)
  if not equipLocation or not IsWeaponEquipLocation(equipLocation) then
    return true
  end

  local classID, subClassID = GetItemClassAndSubclass(itemLink)
  if classID ~= Enum.ItemClass.Weapon then
    return true
  end

  local _, classTag = UnitClass("player")
  local allowed = classTag and CLASS_WEAPON_PROFICIENCIES[classTag] or nil
  if not allowed then
    Debug("weapon proficiency", equipLocation, "subclass=", subClassID, "class=", classTag or "nil", "allowed=", true, "reason=no map")
    return true
  end

  local result = allowed[subClassID] == true
  Debug("weapon proficiency", equipLocation, "subclass=", subClassID, "class=", classTag or "nil", "allowed=", result)
  return result
end

local function GetEquippedItemScore(slotID, weights)
  local itemLink = GetInventoryItemLink("player", slotID)
  if not itemLink then
    return nil, nil
  end

  return itemLink, ns.Stats:CalculateScore(itemLink, weights)
end

local function BuildComparisonResult(state, slotID, itemLink, equippedLink, newScore, equippedScore, slotLabelOverride)
  local delta = newScore - equippedScore
  local percent = 0

  if math.abs(equippedScore) > 0.001 then
    percent = (delta / equippedScore) * 100
  elseif delta > 0 then
    percent = 100
  elseif delta < 0 then
    percent = -100
  end

  Debug("comparison result", "state=", state, "slot=", slotID, "new=", newScore, "equipped=", equippedScore, "percent=", percent, "label=", slotLabelOverride or "-")

  return {
    state = state,
    slotID = slotID,
    slotLabelOverride = slotLabelOverride,
    itemLink = itemLink,
    equippedLink = equippedLink,
    newScore = newScore,
    equippedScore = equippedScore,
    delta = delta,
    percent = percent,
  }
end

local function GetStateFromDelta(delta)
  if delta > 0.01 then
    return "better"
  end

  if delta < -0.01 then
    return "worse"
  end

  return "equal"
end

local function GetEquippedWeaponState(weights)
  local mainLink, mainScore = GetEquippedItemScore(INVSLOT_MAINHAND, weights)
  local offLink, offScore = GetEquippedItemScore(INVSLOT_OFFHAND, weights)
  local mainEquipLocation = mainLink and GetEquipLocation(mainLink) or nil
  local offEquipLocation = offLink and GetEquipLocation(offLink) or nil

  Debug("equipped weapons", "mh=", mainEquipLocation or "nil", "mhScore=", mainScore or "nil", "oh=", offEquipLocation or "nil", "ohScore=", offScore or "nil")

  return {
    mainLink = mainLink,
    mainScore = mainScore,
    mainEquipLocation = mainEquipLocation,
    offLink = offLink,
    offScore = offScore,
    offEquipLocation = offEquipLocation,
  }
end

local function IsWeaponInOffhand(equipLocation)
  return equipLocation == "INVTYPE_WEAPON" or equipLocation == "INVTYPE_WEAPONOFFHAND"
end

function ns.Compare:CanCompareItem(itemLink)
  local equipLocation = itemLink and GetEquipLocation(itemLink)
  local hasSlot = equipLocation and Constants.slotCandidates[equipLocation] ~= nil
  local armorOk = itemLink and IsPreferredArmorType(itemLink) or false
  local weaponOk = itemLink and IsUsableWeaponType(itemLink) or false

  Debug("can compare", equipLocation or "nil", "hasSlot=", hasSlot, "armorOk=", armorOk, "weaponOk=", weaponOk)

  return equipLocation and hasSlot and armorOk and weaponOk
end

function ns.Compare:GetComparison(itemLink)
  Debug("start compare", itemLink or "nil")

  if not self:CanCompareItem(itemLink) then
    Debug("stop compare", "CanCompareItem=false")
    return nil
  end

  local weights = ns.DB:GetActiveWeights()
  local baseNewScore = ns.Stats:CalculateScore(itemLink, weights)
  local equipLocation = GetEquipLocation(itemLink)
  local slots = Constants.slotCandidates[equipLocation]

  Debug("item context", "equipLoc=", equipLocation, "score=", baseNewScore, "slots=", table.concat(slots, ","))

  if IsTwoHandEquipLocation(equipLocation) then
    local weapons = GetEquippedWeaponState(weights)

    if weapons.mainLink and not IsTwoHandEquipLocation(weapons.mainEquipLocation) then
      local equippedScore = (weapons.mainScore or 0) + (weapons.offScore or 0)
      local equippedLink = weapons.offLink and (weapons.mainLink .. "\n" .. weapons.offLink) or weapons.mainLink
      local slotLabelOverride = weapons.offLink and L.SLOT_WEAPON_PAIR or self:GetSlotLabel(INVSLOT_MAINHAND)
      local state = GetStateFromDelta(baseNewScore - equippedScore)

      Debug("branch", "2h vs current weapon set", "equippedScore=", equippedScore)
      return BuildComparisonResult(state, INVSLOT_MAINHAND, itemLink, equippedLink, baseNewScore, equippedScore, slotLabelOverride)
    end

    Debug("branch miss", "2h path not used")
  end

  if IsMainHandOnlyEquipLocation(equipLocation) then
    local mainLink, mainScore = GetEquippedItemScore(INVSLOT_MAINHAND, weights)
    if mainLink then
      Debug("branch", "main-hand only")
      return BuildComparisonResult(GetStateFromDelta(baseNewScore - mainScore), INVSLOT_MAINHAND, itemLink, mainLink, baseNewScore, mainScore)
    end

    Debug("branch miss", "main-hand only no equipped main hand")
  end

  if IsOffHandOnlyEquipLocation(equipLocation) then
    local offLink, offScore = GetEquippedItemScore(INVSLOT_OFFHAND, weights)
    if offLink then
      Debug("branch", "off-hand only")
      return BuildComparisonResult(GetStateFromDelta(baseNewScore - offScore), INVSLOT_OFFHAND, itemLink, offLink, baseNewScore, offScore)
    end

    Debug("branch miss", "off-hand only no equipped off hand")
  end

  if IsPairableOneHandEquipLocation(equipLocation) then
    local weapons = GetEquippedWeaponState(weights)

    if weapons.mainLink and IsTwoHandEquipLocation(weapons.mainEquipLocation) and CanPlayerDualWield() then
      local pairedScore = baseNewScore * 2
      local state = GetStateFromDelta(pairedScore - weapons.mainScore)
      Debug("branch", "1h pair vs equipped 2h", "pairedScore=", pairedScore)
      return BuildComparisonResult(state, INVSLOT_MAINHAND, itemLink, weapons.mainLink, pairedScore, weapons.mainScore, L.SLOT_TWO_HAND_WEAPON)
    end

    if weapons.offLink and IsWeaponInOffhand(weapons.offEquipLocation) and CanPlayerDualWield() then
      local chosenSlot = INVSLOT_MAINHAND
      local chosenLink = weapons.mainLink
      local chosenScore = weapons.mainScore

      if weapons.offScore and weapons.mainScore and weapons.offScore < weapons.mainScore then
        chosenSlot = INVSLOT_OFFHAND
        chosenLink = weapons.offLink
        chosenScore = weapons.offScore
      end

      Debug("branch", "1h vs dual wield weapon", "chosenSlot=", chosenSlot, "chosenScore=", chosenScore)
      return BuildComparisonResult(GetStateFromDelta(baseNewScore - chosenScore), chosenSlot, itemLink, chosenLink, baseNewScore, chosenScore)
    end

    if weapons.mainLink then
      Debug("branch", "1h vs main hand only", "mainEquipLoc=", weapons.mainEquipLocation or "nil")
      return BuildComparisonResult(GetStateFromDelta(baseNewScore - weapons.mainScore), INVSLOT_MAINHAND, itemLink, weapons.mainLink, baseNewScore, weapons.mainScore)
    end

    Debug("branch miss", "1h path no equipped main hand")
  end

  local chosenLink
  local chosenScore
  local chosenSlot

  for _, slotID in ipairs(slots) do
    local equippedLink, equippedScore = GetEquippedItemScore(slotID, weights)
    if equippedLink then
      if not chosenScore or equippedScore < chosenScore then
        chosenLink = equippedLink
        chosenScore = equippedScore
        chosenSlot = slotID
      end

      if #slots == 1 then
        chosenLink = equippedLink
        chosenScore = equippedScore
        chosenSlot = slotID
      end
    end
  end

  if not chosenLink then
    Debug("no compare target", "slot=", slots[1])
    return {
      state = "no_compare",
      newScore = baseNewScore,
      slotID = slots[1],
    }
  end

  Debug("fallback branch", "slot=", chosenSlot, "equippedScore=", chosenScore)
  return BuildComparisonResult(GetStateFromDelta(baseNewScore - chosenScore), chosenSlot, itemLink, chosenLink, baseNewScore, chosenScore)
end

function ns.Compare:IsUpgrade(itemLink)
  local comparison = self:GetComparison(itemLink)
  return comparison and comparison.state == "better" or false
end

function ns.Compare:GetSlotLabel(slotID)
  return Constants.slotLabels[slotID] or L.SLOT_GENERIC
end
