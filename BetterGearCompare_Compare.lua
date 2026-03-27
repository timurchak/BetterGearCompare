local _, ns = ...

ns.Compare = {}

local Constants = ns.Constants
local L = ns.L
local SpecRules = ns.SpecRules

local ARMOR_SUBCLASS = {
  CLOTH = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Cloth or 1,
  LEATHER = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Leather or 2,
  MAIL = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Mail or 3,
  PLATE = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Plate or 4,
  GENERIC = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Generic or 0,
  COSMETIC = Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Cosmetic or -1,
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

local function GetItemLevel(itemLink)
  return ns.Stats:GetItemLevel(itemLink)
end

local function GetItemID(itemLink)
  return C_Item.GetItemInfoInstant(itemLink)
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

local function IsRangedEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_RANGED"
    or equipLocation == "INVTYPE_RANGEDRIGHT"
    or equipLocation == "INVTYPE_THROWN"
end

local function IsTrinketEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_TRINKET"
end

local function IsTwoHandEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_2HWEAPON"
end

local function IsGenericOneHandEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_WEAPON"
end

local function IsMainHandOnlyEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_WEAPONMAINHAND"
end

local function IsOffHandOnlyEquipLocation(equipLocation)
  return equipLocation == "INVTYPE_WEAPONOFFHAND"
    or equipLocation == "INVTYPE_HOLDABLE"
    or equipLocation == "INVTYPE_SHIELD"
end

local function IsWeaponInOffhand(equipLocation)
  return equipLocation == "INVTYPE_WEAPON" or equipLocation == "INVTYPE_WEAPONOFFHAND"
end

local function GetPlayerPreferredArmorSubclass()
  local _, classTag = UnitClass("player")
  return classTag and CLASS_ARMOR_PREFERENCE[classTag] or nil
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

local function IsAllowedBySpecRules(itemLink)
  local equipLocation = GetEquipLocation(itemLink)
  if not equipLocation or not IsWeaponEquipLocation(equipLocation) then
    return true
  end

  local classID, subClassID = GetItemClassAndSubclass(itemLink)
  if classID ~= Enum.ItemClass.Weapon then
    return true
  end

  local policy, classTag, specID = SpecRules:GetCurrentWeaponPolicy()
  local allowed = SpecRules:IsWeaponSubclassAllowed(subClassID)
  Debug("spec policy", policy and policy.name or "nil", "class=", classTag or "nil", "specID=", specID or "nil", "subclass=", subClassID, "allowed=", allowed)
  return allowed
end

local function GetEquippedItemState(slotID, weights)
  local itemLink = GetInventoryItemLink("player", slotID)
  if not itemLink then
    return nil
  end

  local classID, subClassID = GetItemClassAndSubclass(itemLink)
  return {
    slotID = slotID,
    itemLink = itemLink,
    score = ns.Stats:CalculateScore(itemLink, weights),
    itemLevel = GetItemLevel(itemLink),
    equipLocation = GetEquipLocation(itemLink),
    classID = classID,
    subClassID = subClassID,
  }
end

local function IsItemBis(itemLink)
  local bisData = ns.BisData
  if not bisData or not bisData.specIDs or not bisData.specs then
    return false
  end

  local specID = ns.DB:GetCurrentSpecID()
  local specSlug = specID and bisData.specIDs[specID] or nil
  if not specSlug then
    return false
  end

  local specData = bisData.specs[specSlug]
  if not specData or not specData.bisItems then
    return false
  end

  local itemID = GetItemID(itemLink)
  return itemID and specData.bisItems[itemID] == true or false
end

local function GetCurrentSpecTrinketData()
  local trinketData = ns.TrinketData
  if not trinketData or not trinketData.specIDs or not trinketData.specs then
    return nil
  end

  local specID = ns.DB:GetCurrentSpecID()
  local specSlug = specID and trinketData.specIDs[specID] or nil
  if not specSlug then
    return nil
  end

  return trinketData.specs[specSlug]
end

local function GetTrinketRankingState(itemLink, specData)
  local itemID = GetItemID(itemLink)
  if not itemID then
    return nil
  end

  local itemScores = specData and specData.itemScores or nil
  local itemTiers = specData and specData.itemTiers or nil

  return {
    itemID = itemID,
    itemLink = itemLink,
    score = itemScores and itemScores[itemID] or 0,
    tier = itemTiers and itemTiers[itemID] or nil,
    itemLevel = GetItemLevel(itemLink),
    equipLocation = GetEquipLocation(itemLink),
  }
end

local function GetEquippedTrinketState(slotID, specData)
  local itemLink = GetInventoryItemLink("player", slotID)
  if not itemLink then
    return nil
  end

  local state = GetTrinketRankingState(itemLink, specData)
  if not state then
    return nil
  end

  state.slotID = slotID
  return state
end

local function BuildTrinketComparison(itemLink)
  local specData = GetCurrentSpecTrinketData()
  if not specData then
    return nil
  end

  local newState = GetTrinketRankingState(itemLink, specData)
  if not newState then
    return nil
  end

  local slots = Constants.slotCandidates.INVTYPE_TRINKET
  local chosenState

  for _, slotID in ipairs(slots) do
    local equippedState = GetEquippedTrinketState(slotID, specData)
    if equippedState then
      if not chosenState or equippedState.score < chosenState.score then
        chosenState = equippedState
      end

      if #slots == 1 then
        chosenState = equippedState
      end
    end
  end

  if not chosenState then
    return {
      state = "no_compare",
      slotID = slots[1],
      newScore = newState.score,
      newItemLevel = newState.itemLevel,
      comparisonMethod = "trinket_tier",
      newTier = newState.tier,
      newItemID = newState.itemID,
      isBis = IsItemBis(itemLink),
    }
  end

  local delta = newState.score - chosenState.score
  local state
  if delta > 0.01 then
    state = "better"
  elseif delta < -0.01 then
    state = "worse"
  else
    state = "equal"
  end

  local percent = 0
  if math.abs(chosenState.score) > 0.001 then
    percent = (delta / chosenState.score) * 100
  elseif delta > 0 then
    percent = 100
  elseif delta < 0 then
    percent = -100
  end

  return {
    state = state,
    slotID = chosenState.slotID,
    slotLabelOverride = nil,
    itemLink = itemLink,
    equippedLink = chosenState.itemLink,
    newScore = newState.score,
    equippedScore = chosenState.score,
    newItemLevel = newState.itemLevel or 0,
    equippedItemLevel = chosenState.itemLevel or 0,
    delta = delta,
    percent = percent,
    comparisonMethod = "trinket_tier",
    newTier = newState.tier,
    equippedTier = chosenState.tier,
    newItemID = newState.itemID,
    equippedItemID = chosenState.itemID,
    isBis = IsItemBis(itemLink),
  }
end

local function BuildComparisonResult(state, slotID, itemLink, equippedLink, newScore, equippedScore, slotLabelOverride, newItemLevel, equippedItemLevel)
  local delta = newScore - equippedScore
  local percent = 0

  if math.abs(equippedScore) > 0.001 then
    percent = (delta / equippedScore) * 100
  elseif delta > 0 then
    percent = 100
  elseif delta < 0 then
    percent = -100
  end

  Debug("comparison result", "state=", state, "slot=", slotID, "new=", newScore, "equipped=", equippedScore, "percent=", percent, "newIlvl=", newItemLevel or 0, "equippedIlvl=", equippedItemLevel or 0, "label=", slotLabelOverride or "-")

  return {
    state = state,
    slotID = slotID,
    slotLabelOverride = slotLabelOverride,
    itemLink = itemLink,
    equippedLink = equippedLink,
    newScore = newScore,
    equippedScore = equippedScore,
    newItemLevel = newItemLevel or 0,
    equippedItemLevel = equippedItemLevel or 0,
    delta = delta,
    percent = percent,
    isBis = IsItemBis(itemLink),
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
  local main = GetEquippedItemState(INVSLOT_MAINHAND, weights)
  local off = GetEquippedItemState(INVSLOT_OFFHAND, weights)

  Debug(
    "equipped weapons",
    "mh=", main and (main.equipLocation or "nil") or "nil",
    "mhScore=", main and main.score or "nil",
    "mhIlvl=", main and main.itemLevel or "nil",
    "oh=", off and (off.equipLocation or "nil") or "nil",
    "ohScore=", off and off.score or "nil",
    "ohIlvl=", off and off.itemLevel or "nil"
  )

  return {
    main = main,
    off = off,
  }
end

local function AddCandidate(candidates, slotID, itemLink, equippedLink, newScore, equippedScore, slotLabelOverride, newItemLevel, equippedItemLevel)
  if not equippedLink or equippedScore == nil then
    return
  end

  candidates[#candidates + 1] = {
    slotID = slotID,
    itemLink = itemLink,
    equippedLink = equippedLink,
    newScore = newScore,
    equippedScore = equippedScore,
    newItemLevel = newItemLevel or 0,
    equippedItemLevel = equippedItemLevel or 0,
    slotLabelOverride = slotLabelOverride,
    delta = newScore - equippedScore,
  }
end

local function ChooseBestCandidate(candidates)
  local best
  for _, candidate in ipairs(candidates) do
    if not best or candidate.delta > best.delta then
      best = candidate
    end
  end
  return best
end

local function GetWeaponSetLabel(offState)
  if offState and IsWeaponInOffhand(offState.equipLocation) then
    return L.SLOT_WEAPON_PAIR
  end
  return L.SLOT_WEAPON_SET or L.SLOT_WEAPON_PAIR
end

local function IsRangedWeaponSubclass(subClassID)
  local weaponSubclass = SpecRules:GetWeaponSubclassConstants()
  return subClassID == weaponSubclass.BOW
    or subClassID == weaponSubclass.CROSSBOW
    or subClassID == weaponSubclass.GUN
end

local function BuildWeaponCandidates(itemLink, baseNewScore, weights)
  local equipLocation = GetEquipLocation(itemLink)
  if not equipLocation or not IsWeaponEquipLocation(equipLocation) then
    return nil
  end

  local classID = GetItemClassAndSubclass(itemLink)
  if classID ~= Enum.ItemClass.Weapon then
    return nil
  end

  local policy, classTag, specID = SpecRules:GetCurrentWeaponPolicy()
  local weapons = GetEquippedWeaponState(weights)
  local candidates = {}
  local newItemLevel = GetItemLevel(itemLink)
  local _, newSubClassID = GetItemClassAndSubclass(itemLink)

  Debug("weapon candidates", policy and policy.name or "nil", "class=", classTag or "nil", "specID=", specID or "nil", "equipLoc=", equipLocation, "newIlvl=", newItemLevel)

  if not policy then
    return candidates
  end

  if IsRangedEquipLocation(equipLocation) then
    local equippedMain = weapons.main
    local equippedIsRanged = equippedMain
      and IsRangedEquipLocation(equippedMain.equipLocation)
      and IsRangedWeaponSubclass(equippedMain.subClassID)

    if not IsRangedWeaponSubclass(newSubClassID) then
      Debug("branch miss", "ranged item subclass unsupported", "subclass=", newSubClassID)
      return candidates
    end

    if equippedIsRanged then
      AddCandidate(candidates, INVSLOT_MAINHAND, itemLink, equippedMain.itemLink, baseNewScore, equippedMain.score, nil, newItemLevel, equippedMain.itemLevel)
      Debug("branch", "ranged family compare", "slot=", INVSLOT_MAINHAND, "equippedSubClass=", equippedMain.subClassID, "newSubClass=", newSubClassID)
    else
      Debug("branch miss", "no equipped ranged weapon to compare")
    end

    return candidates
  end

  if IsTwoHandEquipLocation(equipLocation) then
    if not policy.twoHand then
      Debug("branch miss", "2h disallowed by spec")
      return candidates
    end

    if policy.dualWieldTwoHand then
      if weapons.main then
        AddCandidate(candidates, INVSLOT_MAINHAND, itemLink, weapons.main.itemLink, baseNewScore, weapons.main.score, nil, newItemLevel, weapons.main.itemLevel)
      end
      if weapons.off and IsTwoHandEquipLocation(weapons.off.equipLocation) then
        AddCandidate(candidates, INVSLOT_OFFHAND, itemLink, weapons.off.itemLink, baseNewScore, weapons.off.score, nil, newItemLevel, weapons.off.itemLevel)
      end
    end

    if (policy.mainHandOffHand or policy.dualWieldOneHand) and weapons.main and not IsTwoHandEquipLocation(weapons.main.equipLocation) then
      local equippedScore = (weapons.main.score or 0) + (weapons.off and weapons.off.score or 0)
      local equippedLink = weapons.off and (weapons.main.itemLink .. "\n" .. weapons.off.itemLink) or weapons.main.itemLink
      local equippedItemLevel = math.max(weapons.main.itemLevel or 0, weapons.off and weapons.off.itemLevel or 0)
      AddCandidate(candidates, INVSLOT_MAINHAND, itemLink, equippedLink, baseNewScore, equippedScore, GetWeaponSetLabel(weapons.off), newItemLevel, equippedItemLevel)
    elseif weapons.main and not policy.dualWieldTwoHand then
      AddCandidate(candidates, INVSLOT_MAINHAND, itemLink, weapons.main.itemLink, baseNewScore, weapons.main.score, nil, newItemLevel, weapons.main.itemLevel)
    end

    return candidates
  end

  if IsMainHandOnlyEquipLocation(equipLocation) then
    if not (policy.oneHand or policy.mainHandOffHand or policy.dualWieldOneHand) then
      Debug("branch miss", "main-hand item disallowed by spec")
      return candidates
    end

    if weapons.main then
      AddCandidate(candidates, INVSLOT_MAINHAND, itemLink, weapons.main.itemLink, baseNewScore, weapons.main.score, nil, newItemLevel, weapons.main.itemLevel)
    end

    return candidates
  end

  if IsOffHandOnlyEquipLocation(equipLocation) then
    if not (policy.mainHandOffHand or policy.dualWieldOneHand) then
      Debug("branch miss", "off-hand item disallowed by spec")
      return candidates
    end

    if weapons.off then
      AddCandidate(candidates, INVSLOT_OFFHAND, itemLink, weapons.off.itemLink, baseNewScore, weapons.off.score, nil, newItemLevel, weapons.off.itemLevel)
    end

    return candidates
  end

  if IsGenericOneHandEquipLocation(equipLocation) then
    if not policy.oneHand then
      Debug("branch miss", "1h disallowed by spec")
      return candidates
    end

    if weapons.main and IsTwoHandEquipLocation(weapons.main.equipLocation) then
      if policy.dualWieldOneHand then
        AddCandidate(candidates, INVSLOT_MAINHAND, itemLink, weapons.main.itemLink, baseNewScore * 2, weapons.main.score, L.SLOT_TWO_HAND_WEAPON, newItemLevel, weapons.main.itemLevel)
      else
        Debug("branch miss", "1h vs equipped 2h invalid for this spec")
      end
      return candidates
    end

    if weapons.main then
      AddCandidate(candidates, INVSLOT_MAINHAND, itemLink, weapons.main.itemLink, baseNewScore, weapons.main.score, nil, newItemLevel, weapons.main.itemLevel)
    end

    if policy.dualWieldOneHand and weapons.off and IsWeaponInOffhand(weapons.off.equipLocation) then
      AddCandidate(candidates, INVSLOT_OFFHAND, itemLink, weapons.off.itemLink, baseNewScore, weapons.off.score, nil, newItemLevel, weapons.off.itemLevel)
    end

    return candidates
  end

  return candidates
end

function ns.Compare:CanCompareItem(itemLink)
  local equipLocation = itemLink and GetEquipLocation(itemLink)
  local hasSlot = equipLocation and Constants.slotCandidates[equipLocation] ~= nil
  local armorOk = itemLink and IsPreferredArmorType(itemLink) or false
  local specOk = itemLink and IsAllowedBySpecRules(itemLink) or false

  Debug("can compare", equipLocation or "nil", "hasSlot=", hasSlot, "armorOk=", armorOk, "specOk=", specOk)

  return equipLocation and hasSlot and armorOk and specOk
end

function ns.Compare:GetComparison(itemLink)
  Debug("start compare", itemLink or "nil")

  if not self:CanCompareItem(itemLink) then
    Debug("stop compare", "CanCompareItem=false")
    return nil
  end

  local weights = ns.DB:GetActiveWeights()
  local baseNewScore = ns.Stats:CalculateScore(itemLink, weights)
  local baseNewItemLevel = GetItemLevel(itemLink)
  local equipLocation = GetEquipLocation(itemLink)
  local slots = Constants.slotCandidates[equipLocation]

  Debug("item context", "equipLoc=", equipLocation, "score=", baseNewScore, "newIlvl=", baseNewItemLevel, "slots=", table.concat(slots, ","))

  if IsTrinketEquipLocation(equipLocation) then
    local trinketComparison = BuildTrinketComparison(itemLink)
    if trinketComparison then
      Debug(
        "branch",
        "trinket tier comparison",
        "state=",
        trinketComparison.state,
        "newTier=",
        trinketComparison.newTier or "nil",
        "equippedTier=",
        trinketComparison.equippedTier or "nil"
      )
      return trinketComparison
    end
  end

  local weaponCandidates = BuildWeaponCandidates(itemLink, baseNewScore, weights)
  if weaponCandidates then
    local bestWeaponCandidate = ChooseBestCandidate(weaponCandidates)
    if bestWeaponCandidate then
      Debug("branch", "spec-rule weapon candidate", "slot=", bestWeaponCandidate.slotID, "delta=", bestWeaponCandidate.delta)
      return BuildComparisonResult(
        GetStateFromDelta(bestWeaponCandidate.delta),
        bestWeaponCandidate.slotID,
        bestWeaponCandidate.itemLink,
        bestWeaponCandidate.equippedLink,
        bestWeaponCandidate.newScore,
        bestWeaponCandidate.equippedScore,
        bestWeaponCandidate.slotLabelOverride,
        bestWeaponCandidate.newItemLevel,
        bestWeaponCandidate.equippedItemLevel
      )
    end

    Debug("branch miss", "no valid weapon candidates")
    return nil
  end

  local chosenState

  for _, slotID in ipairs(slots) do
    local equippedState = GetEquippedItemState(slotID, weights)
    if equippedState then
      if not chosenState or equippedState.score < chosenState.score then
        chosenState = equippedState
      end

      if #slots == 1 then
        chosenState = equippedState
      end
    end
  end

  if not chosenState then
    Debug("no compare target", "slot=", slots[1])
    return {
      state = "no_compare",
      newScore = baseNewScore,
      newItemLevel = baseNewItemLevel,
      slotID = slots[1],
      isBis = IsItemBis(itemLink),
    }
  end

  Debug("fallback branch", "slot=", chosenState.slotID, "equippedScore=", chosenState.score, "equippedIlvl=", chosenState.itemLevel)
  return BuildComparisonResult(
    GetStateFromDelta(baseNewScore - chosenState.score),
    chosenState.slotID,
    itemLink,
    chosenState.itemLink,
    baseNewScore,
    chosenState.score,
    nil,
    baseNewItemLevel,
    chosenState.itemLevel
  )
end

function ns.Compare:IsUpgrade(itemLink)
  local comparison = self:GetComparison(itemLink)
  return comparison and comparison.state == "better" or false
end

function ns.Compare:ShouldShowUpgradeIcon(itemLink)
  local comparison = self:GetComparison(itemLink)
  if not comparison or comparison.state == "no_compare" then
    return false
  end

  if comparison.comparisonMethod == "trinket_tier" then
    return comparison.state == "better"
  end

  if not ns.DB:GetConsiderItemLevelForIcons() then
    return comparison.state == "better"
  end

  if comparison.newItemLevel > comparison.equippedItemLevel then
    return true
  end

  if comparison.newItemLevel < comparison.equippedItemLevel then
    return false
  end

  return comparison.state == "better"
end

function ns.Compare:GetSlotLabel(slotID)
  return Constants.slotLabels[slotID] or L.SLOT_GENERIC
end
