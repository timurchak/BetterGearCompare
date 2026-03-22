local _, ns = ...

ns.DB = {}

local Constants = ns.Constants

local function DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for key, nestedValue in pairs(value) do
    copy[key] = DeepCopy(nestedValue)
  end
  return copy
end

local function BuildDefaultWeights()
  local weights = {}
  for _, stat in ipairs(Constants.statDefinitions) do
    weights[stat.key] = 1.0
  end
  return weights
end

local function GetSpecName(specID)
  local specs = ns.DB:GetSpecializations()
  for _, spec in ipairs(specs) do
    if spec.id == specID then
      return spec.name
    end
  end

  return Constants.defaultProfileName
end

function ns.DB:Init()
  BetterGearCompareDB = BetterGearCompareDB or {}
  BetterGearCompareDB.profiles = BetterGearCompareDB.profiles or {}

  if not BetterGearCompareDB.profiles[Constants.defaultProfileName] then
    BetterGearCompareDB.profiles[Constants.defaultProfileName] = {
      weights = BuildDefaultWeights(),
    }
  end

  for _, profile in pairs(BetterGearCompareDB.profiles) do
    profile.weights = profile.weights or {}
    for _, stat in ipairs(Constants.statDefinitions) do
      if profile.weights[stat.key] == nil then
        profile.weights[stat.key] = 1.0
      end
    end
  end

  BetterGearCompareCharDB = BetterGearCompareCharDB or {}
  BetterGearCompareCharDB.specProfiles = BetterGearCompareCharDB.specProfiles or {}

  if BetterGearCompareCharDB.debugEnabled == nil then
    BetterGearCompareCharDB.debugEnabled = false
  end

  if ns.SetDebugEnabled then
    ns:SetDebugEnabled(BetterGearCompareCharDB.debugEnabled)
  end

  self:EnsureSpecProfile()
end

function ns.DB:GetSpecializations()
  local specs = {}
  local count = GetNumSpecializations and GetNumSpecializations(false, false) or 0

  for index = 1, count do
    local specID, name = GetSpecializationInfo(index)
    if specID then
      specs[#specs + 1] = {
        id = specID,
        name = name or ("Spec " .. index),
        index = index,
      }
    end
  end

  if #specs == 0 then
    specs[1] = {
      id = 0,
      name = Constants.defaultProfileName,
      index = 1,
    }
  end

  return specs
end

function ns.DB:GetCurrentSpecID()
  local currentSpecIndex = GetSpecialization and GetSpecialization()
  if currentSpecIndex then
    local specID = GetSpecializationInfo(currentSpecIndex)
    if specID then
      return specID
    end
  end

  local specs = self:GetSpecializations()
  return specs[1] and specs[1].id or 0
end

function ns.DB:EnsureProfile(profileName)
  if not BetterGearCompareDB.profiles[profileName] then
    BetterGearCompareDB.profiles[profileName] = {
      weights = DeepCopy(BetterGearCompareDB.profiles[Constants.defaultProfileName].weights),
    }
  end

  return BetterGearCompareDB.profiles[profileName]
end

function ns.DB:EnsureSpecProfile(specID)
  specID = specID or self:GetCurrentSpecID()

  if not BetterGearCompareCharDB.specProfiles[specID] then
    BetterGearCompareCharDB.specProfiles[specID] = GetSpecName(specID)
  end

  local profileName = BetterGearCompareCharDB.specProfiles[specID]
  self:EnsureProfile(profileName)
end

function ns.DB:GetProfileNames()
  local names = {}
  for name in pairs(BetterGearCompareDB.profiles) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

function ns.DB:GetProfileNameForSpec(specID)
  self:EnsureSpecProfile(specID)
  return BetterGearCompareCharDB.specProfiles[specID]
end

function ns.DB:SetProfileForSpec(specID, profileName)
  self:EnsureProfile(profileName)
  BetterGearCompareCharDB.specProfiles[specID] = profileName
end

function ns.DB:GetProfile(profileName)
  return self:EnsureProfile(profileName)
end

function ns.DB:GetWeightsForSpec(specID)
  return self:GetProfile(self:GetProfileNameForSpec(specID)).weights
end

function ns.DB:GetActiveWeights()
  return self:GetWeightsForSpec(self:GetCurrentSpecID())
end

function ns.DB:SaveProfile(profileName, weights)
  local profile = self:EnsureProfile(profileName)
  profile.weights = DeepCopy(weights)
end

function ns.DB:DeleteProfile(profileName)
  if profileName == Constants.defaultProfileName then
    return false
  end

  BetterGearCompareDB.profiles[profileName] = nil

  for specID, assignedProfileName in pairs(BetterGearCompareCharDB.specProfiles) do
    if assignedProfileName == profileName then
      BetterGearCompareCharDB.specProfiles[specID] = Constants.defaultProfileName
    end
  end

  return true
end

function ns.DB:CloneWeightsFromSpec(specID)
  return DeepCopy(self:GetWeightsForSpec(specID))
end
