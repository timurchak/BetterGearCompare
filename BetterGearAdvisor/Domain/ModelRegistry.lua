local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Reasons = BGA.Core.ReasonCodes

local ModelRegistry = {}
BGA.Domain.ModelRegistry = ModelRegistry

function ModelRegistry.Select(context, baseline, artifactManifest, capabilityManifest, models)
    if not context or context.specID ~= BGA.Core.Constants.ARMS_WARRIOR_SPEC_ID then
        return nil, Reasons.UNSUPPORTED_SPEC
    end

    local capabilityID = context.archetypeID
    local capability = capabilityManifest
        and capabilityManifest.capabilities
        and capabilityManifest.capabilities[capabilityID]
    if not capability or capability.specID ~= context.specID
        or capability.archetypeID ~= context.archetypeID then
        return nil, Reasons.ARCHETYPE_MISMATCH
    end
    if context.profileID ~= capability.profileID
        or context.talentFingerprint ~= capability.talentFingerprint
        or (capability.enhancementPolicyID
            and context.enhancementPolicyID ~= capability.enhancementPolicyID) then
        return nil, Reasons.ARCHETYPE_MISMATCH
    end
    if not artifactManifest or artifactManifest.numericAdviceEnabled ~= true
        or capability.numericAdviceEnabled ~= true
        or capability.status ~= "validated"
        or not capability.modelID then
        return nil, Reasons.MODEL_NOT_VALIDATED
    end
    if capability.baselineEffectSignature
        and baseline.materialEffectSignature ~= capability.baselineEffectSignature then
        return nil, Reasons.BASELINE_EFFECT_CONTEXT_MISMATCH
    end

    local model = models and models[capability.modelID]
    if not model or model.schema ~= capability.modelSchema then
        return nil, Reasons.MODEL_NOT_VALIDATED
    end
    return model, nil, capability
end
