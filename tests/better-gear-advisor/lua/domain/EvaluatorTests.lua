local BGA, Assert = ...

local function model()
    local coefficients = {}
    for index = 1, 116 do coefficients[index] = 0 end
    coefficients[1] = 10
    coefficients[7] = 0.1 -- crit linear term after the primary hinge block
    return {
        schema = 1,
        mean = { 100, 100, 100, 100, 100 },
        scale = { 100, 100, 100, 100, 100 },
        knots = {
            { -1, 0, 1, 2 }, { -1, 0, 1, 2 }, { -1, 0, 1, 2 },
            { -1, 0, 1, 2 }, { -1, 0, 1, 2 },
        },
        coefficients = coefficients,
        primaryMin = 0,
        primaryMax = 1000,
        secondaryBudgetMin = 0,
        secondaryBudgetMax = 2000,
        uncertaintyPP = 0.1,
        materialityPP = 0.5,
        payloadHash = "model-hash",
    }
end

local function item(id, guid, crit, inventoryType)
    return BGA.Domain.ItemSnapshot.New({
        fullLink = "item:" .. id .. "::::::::::::0:",
        itemID = id,
        itemGUID = guid,
        locationKey = "fixture:" .. guid,
        inventoryType = inventoryType or "INVTYPE_FINGER",
        actualItemLevel = 300,
        itemClassID = 4,
        itemSubClassID = 4,
        statsComplete = true,
        stats = { strength = 50, crit = crit, haste = 50, mastery = 50, versatility = 50 },
        upgrade = { eligibility = false },
    })
end

local function input(candidate)
    local first = item(101, "a", 40)
    local second = item(102, "b", 10)
    local baseline = BGA.Domain.EquipmentState.New({
        slots = { [11] = first, [12] = second },
        materialEffectSignature = "supported-baseline",
    })
    local capability = {
        schema = 1,
        capabilities = {
            arms = {
                status = "validated",
                numericAdviceEnabled = true,
                specID = 71,
                archetypeID = "arms",
                profileID = "dungeon_aoe",
                talentFingerprint = "talents",
                modelID = "model",
                modelSchema = 1,
                baselineEffectSignature = "supported-baseline",
            },
        },
    }
    return {
        baseline = baseline,
        candidate = candidate,
        context = {
            specID = 71,
            archetypeID = "arms",
            profileID = "dungeon_aoe",
            talentFingerprint = "talents",
            enhancementPolicyID = "as_observed_v1",
        },
        artifactManifest = { numericAdviceEnabled = true, addonVersion = "test", artifactSetHash = "artifacts" },
        capabilityManifest = capability,
        models = { model = model() },
        clientBuild = "test",
    }
end

return {
    packaged_planned_capability_is_unsupported = function()
        local candidate = item(103, "c", 80)
        local value = input(candidate)
        value.context.archetypeID = "arms-warrior-mid2-dungeon-aoe-v1"
        value.context.talentFingerprint = nil
        value.artifactManifest = BGA.Generated.ArtifactManifest
        value.capabilityManifest = BGA.Generated.CapabilityManifest
        value.models = {}
        local result = BGA.Domain.GearEvaluator.Evaluate(value)
        Assert.Equal(result.status, "unsupported")
        Assert.Equal(result.reasonCodes[1], BGA.Core.ReasonCodes.MODEL_NOT_VALIDATED)
        Assert.Nil(result.deltaPercent)
    end,

    ring_evaluator_selects_better_complete_replacement = function()
        local result = BGA.Domain.GearEvaluator.Evaluate(input(item(103, "c", 80)))
        Assert.Equal(result.status, "upgrade")
        Assert.Equal(result.replacement.replacedSlots[1], 12)
        Assert.Equal(#result.alternatives, 2)
        Assert.True(result.deltaPercent > 0)
    end,

    small_supported_delta_abstains = function()
        local value = input(item(103, "c", 11))
        local result = BGA.Domain.GearEvaluator.Evaluate(value)
        Assert.Equal(result.status, "too_close")
    end,

    future_ranks_are_scored_independently_and_choose_ring_slot = function()
        local value = input(item(103, "c", 11))
        value.futureStatus = "available"
        value.futureCandidates = {
            { rank = 2, itemLevel = 303, status = "verified", snapshot = item(103, "future-2", 11) },
            { rank = 3, itemLevel = 306, status = "verified", snapshot = item(103, "future-3", 80) },
        }
        local result = BGA.Domain.GearEvaluator.Evaluate(value)
        Assert.Equal(result.status, "too_close")
        Assert.Equal(result.future.status, "available")
        Assert.Equal(result.future.ranks[1].status, "too_close")
        Assert.Equal(result.future.ranks[2].status, "upgrade")
        Assert.Equal(result.future.firstConfirmedUpgradeRank, 3)
        Assert.Equal(result.future.ranks[2].replacement.replacedSlots[1], 12)
    end,

    special_candidate_never_reaches_numeric_model = function()
        local candidate = item(103, "c", 500, "INVTYPE_TRINKET")
        local result = BGA.Domain.GearEvaluator.Evaluate(input(candidate))
        Assert.Equal(result.status, "special")
        Assert.Nil(result.deltaPercent)
    end,

    baseline_effect_mismatch_fails_closed = function()
        local value = input(item(103, "c", 80))
        value.baseline.materialEffectSignature = "different"
        local result = BGA.Domain.GearEvaluator.Evaluate(value)
        Assert.Equal(result.status, "unsupported")
        Assert.Equal(result.reasonCodes[1], BGA.Core.ReasonCodes.BASELINE_EFFECT_CONTEXT_MISMATCH)
    end,
}
