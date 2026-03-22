local _, ns = ...

ns.SpecRules = {}

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

local function Set(values)
  local result = {}
  for _, value in ipairs(values) do
    result[value] = true
  end
  return result
end

local function MergeSets(...)
  local result = {}
  for index = 1, select("#", ...) do
    local source = select(index, ...)
    if source then
      for key in pairs(source) do
        result[key] = true
      end
    end
  end
  return result
end

local CLASS_ALLOWED = {
  WARRIOR = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.AXE2H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.SWORD2H, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.FIST, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.BOW, WEAPON_SUBCLASS.GUN, WEAPON_SUBCLASS.CROSSBOW }),
  PALADIN = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.AXE2H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.SWORD2H }),
  DEATHKNIGHT = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.AXE2H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.SWORD2H }),
  HUNTER = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.AXE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.SWORD2H, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.BOW, WEAPON_SUBCLASS.GUN, WEAPON_SUBCLASS.CROSSBOW }),
  SHAMAN = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.AXE2H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST }),
  EVOKER = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST, WEAPON_SUBCLASS.STAFF }),
  ROGUE = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST, WEAPON_SUBCLASS.BOW, WEAPON_SUBCLASS.GUN, WEAPON_SUBCLASS.CROSSBOW }),
  DRUID = Set({ WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST }),
  MONK = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.FIST }),
  DEMONHUNTER = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.WARGLAIVE, WEAPON_SUBCLASS.FIST, WEAPON_SUBCLASS.DAGGER }),
  PRIEST = Set({ WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.WAND }),
  MAGE = Set({ WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.WAND }),
  WARLOCK = Set({ WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.WAND }),
}

local SPEC_POLICIES = {
  WARRIOR = {
    [71] = { name = "arms", allowedSubclasses = Set({ WEAPON_SUBCLASS.AXE2H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.SWORD2H, WEAPON_SUBCLASS.STAFF }), oneHand = false, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = false },
    [72] = { name = "fury", allowedSubclasses = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.AXE2H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.SWORD2H, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.FIST }), oneHand = true, twoHand = true, dualWieldOneHand = true, dualWieldTwoHand = true, mainHandOffHand = false },
    [73] = { name = "protection", allowedSubclasses = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.FIST, WEAPON_SUBCLASS.DAGGER }), oneHand = true, twoHand = false, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = true },
  },
  PALADIN = {
    [65] = { name = "holy", allowedSubclasses = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.SWORD2H }), oneHand = true, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = true },
    [66] = { name = "protection", allowedSubclasses = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.SWORD1H }), oneHand = true, twoHand = false, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = true },
    [70] = { name = "retribution", allowedSubclasses = Set({ WEAPON_SUBCLASS.AXE2H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.SWORD2H }), oneHand = false, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = false },
  },
  ROGUE = {
    [259] = { name = "assassination", allowedSubclasses = Set({ WEAPON_SUBCLASS.DAGGER }), oneHand = true, twoHand = false, dualWieldOneHand = true, dualWieldTwoHand = false, mainHandOffHand = false },
    [260] = { name = "outlaw", allowedSubclasses = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.SWORD1H, WEAPON_SUBCLASS.FIST }), oneHand = true, twoHand = false, dualWieldOneHand = true, dualWieldTwoHand = false, mainHandOffHand = false },
    [261] = { name = "subtlety", allowedSubclasses = Set({ WEAPON_SUBCLASS.DAGGER }), oneHand = true, twoHand = false, dualWieldOneHand = true, dualWieldTwoHand = false, mainHandOffHand = false },
  },
  DRUID = {
    [102] = { name = "balance", allowedSubclasses = Set({ WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST }), oneHand = true, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = true },
    [103] = { name = "feral", allowedSubclasses = Set({ WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.STAFF }), oneHand = false, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = false },
    [104] = { name = "guardian", allowedSubclasses = Set({ WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.STAFF }), oneHand = false, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = false },
    [105] = { name = "restoration", allowedSubclasses = Set({ WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.MACE2H, WEAPON_SUBCLASS.POLEARM, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST }), oneHand = true, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = true },
  },
  SHAMAN = {
    [262] = { name = "elemental", allowedSubclasses = Set({ WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST }), oneHand = true, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = true },
    [263] = { name = "enhancement", allowedSubclasses = Set({ WEAPON_SUBCLASS.AXE1H, WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST }), oneHand = true, twoHand = false, dualWieldOneHand = true, dualWieldTwoHand = false, mainHandOffHand = false },
    [264] = { name = "restoration", allowedSubclasses = Set({ WEAPON_SUBCLASS.MACE1H, WEAPON_SUBCLASS.STAFF, WEAPON_SUBCLASS.DAGGER, WEAPON_SUBCLASS.FIST }), oneHand = true, twoHand = true, dualWieldOneHand = false, dualWieldTwoHand = false, mainHandOffHand = true },
  },
}

local function BuildFallbackPolicy(classTag)
  local allowedSubclasses = CLASS_ALLOWED[classTag]
  if not allowedSubclasses then
    return nil
  end

  return {
    name = "fallback",
    allowedSubclasses = allowedSubclasses,
    oneHand = true,
    twoHand = true,
    dualWieldOneHand = false,
    dualWieldTwoHand = false,
    mainHandOffHand = true,
  }
end

function ns.SpecRules:GetCurrentSpecID()
  return ns.DB and ns.DB:GetCurrentSpecID() or nil
end

function ns.SpecRules:GetCurrentWeaponPolicy()
  local _, classTag = UnitClass("player")
  local specID = self:GetCurrentSpecID()
  local classPolicies = classTag and SPEC_POLICIES[classTag] or nil
  local policy = classPolicies and specID and classPolicies[specID] or nil

  if policy then
    return policy, classTag, specID
  end

  return BuildFallbackPolicy(classTag), classTag, specID
end

function ns.SpecRules:IsWeaponSubclassAllowed(subClassID)
  local policy = self:GetCurrentWeaponPolicy()
  if not policy or not policy.allowedSubclasses then
    return true
  end

  return policy.allowedSubclasses[subClassID] == true
end

function ns.SpecRules:GetWeaponSubclassConstants()
  return WEAPON_SUBCLASS
end

function ns.SpecRules:DebugDescribeCurrentPolicy()
  local policy, classTag, specID = self:GetCurrentWeaponPolicy()
  if not policy then
    return "none", classTag, specID
  end

  return policy.name or "unnamed", classTag, specID
end
