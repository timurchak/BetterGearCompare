local _, BGA = ...

BGA.Blizzard = BGA.Blizzard or {}

local Constants = BGA.Core.Constants

local CharacterAdapter = {}
CharacterAdapter.__index = CharacterAdapter
BGA.Blizzard.CharacterAdapter = CharacterAdapter

function CharacterAdapter.New(api, revisions, talentFingerprintProvider)
    api = api or {}
    return setmetatable({
        UnitClass = api.UnitClass or UnitClass,
        UnitLevel = api.UnitLevel or UnitLevel,
        GetSpecialization = api.GetSpecialization
            or (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization),
        GetSpecializationInfo = api.GetSpecializationInfo or GetSpecializationInfo,
        revisions = revisions,
        talentFingerprintProvider = talentFingerprintProvider,
    }, CharacterAdapter)
end

function CharacterAdapter:CaptureContext()
    local _, _, classID = self.UnitClass("player")
    local specializationIndex = self.GetSpecialization and self.GetSpecialization() or nil
    local specID = specializationIndex and self.GetSpecializationInfo(specializationIndex) or nil
    local talentFingerprint = self.talentFingerprintProvider and self.talentFingerprintProvider() or nil
    local revision = self.revisions and self.revisions:Capture() or {}
    return {
        classID = classID,
        specID = specID,
        level = self.UnitLevel("player"),
        talentFingerprint = talentFingerprint,
        archetypeID = specID == Constants.ARMS_WARRIOR_SPEC_ID and Constants.TARGET_CAPABILITY_ID or nil,
        profileID = Constants.TARGET_PROFILE_ID,
        enhancementPolicyID = Constants.ENHANCEMENT_POLICY_ID,
        contextRevision = revision.contextRevision or 0,
    }
end
