local BGA, Assert = ...

local function syntheticModel()
    local coefficients = {}
    for index = 1, 116 do
        coefficients[index] = 0
    end
    coefficients[1] = 10
    coefficients[2] = 0.1
    return {
        schema = 1,
        mean = { 100, 25, 25, 25, 25 },
        scale = { 10, 10, 10, 10, 10 },
        knots = {
            { -1, 0, 1, 2 },
            { -1, 0, 1, 2 },
            { -1, 0, 1, 2 },
            { -1, 0, 1, 2 },
            { -1, 0, 1, 2 },
        },
        coefficients = coefficients,
        primaryMin = 80,
        primaryMax = 120,
        secondaryBudgetMin = 80,
        secondaryBudgetMax = 120,
    }
end

local baselineStats = { strength = 100, crit = 25, haste = 25, mastery = 25, versatility = 25 }

return {
    planned_capability_fails_closed = function()
        local baseline = { materialEffectSignature = "unverified" }
        local context = {
            specID = 71,
            archetypeID = "arms-warrior-mid2-dungeon-aoe-v1",
            profileID = "dungeon_aoe",
            talentFingerprint = nil,
        }
        local model, reason = BGA.Domain.ModelRegistry.Select(
            context,
            baseline,
            BGA.Generated.ArtifactManifest,
            BGA.Generated.CapabilityManifest,
            {}
        )
        Assert.Nil(model)
        Assert.Equal(reason, BGA.Core.ReasonCodes.MODEL_NOT_VALIDATED)
    end,

    evaluator_is_bounded = function()
        local model = syntheticModel()
        local value, reason = BGA.Domain.OrdinaryModel.Evaluate(model, baselineStats)
        Assert.Nil(reason)
        Assert.Equal(value, 10)
        local outside = { strength = 121, crit = 25, haste = 25, mastery = 25, versatility = 25 }
        local rejected, rejectedReason = BGA.Domain.OrdinaryModel.Evaluate(model, outside)
        Assert.Nil(rejected)
        Assert.Equal(rejectedReason, BGA.Core.ReasonCodes.OUT_OF_MODEL_DOMAIN)
    end,

    malformed_payload_fails_closed = function()
        local model = syntheticModel()
        model.coefficients[116] = nil
        local value, reason = BGA.Domain.OrdinaryModel.Evaluate(model, baselineStats)
        Assert.Nil(value)
        Assert.Equal(reason, BGA.Core.ReasonCodes.MODEL_NOT_VALIDATED)
    end,

    log_delta_is_relative_not_raw_score_difference = function()
        local delta = BGA.Domain.OrdinaryModel.DeltaPercent(10, 10 + math.log(1.02))
        Assert.True(math.abs(delta - 2) < 0.0000001)
    end,

    materiality_boundary_abstains = function()
        local result = BGA.Domain.ConfidencePolicy.Decide(1.5, 1.0, 0.5)
        Assert.Equal(result.status, "too_close")
        Assert.Equal(result.reasonCodes[1], BGA.Core.ReasonCodes.UNCERTAINTY_OVERLAPS_MATERIALITY)
    end,

    interval_clear_of_materiality_is_directional = function()
        local upgrade = BGA.Domain.ConfidencePolicy.Decide(1.6, 1.0, 0.5)
        local downgrade = BGA.Domain.ConfidencePolicy.Decide(-1.6, 1.0, 0.5)
        Assert.Equal(upgrade.status, "upgrade")
        Assert.Equal(downgrade.status, "downgrade")
    end,

    wider_uncertainty_cannot_improve_direction = function()
        local narrow = BGA.Domain.ConfidencePolicy.Decide(2.0, 1.0, 0.5)
        local wide = BGA.Domain.ConfidencePolicy.Decide(2.0, 1.6, 0.5)
        Assert.Equal(narrow.status, "upgrade")
        Assert.Equal(wide.status, "too_close")
    end,
}
