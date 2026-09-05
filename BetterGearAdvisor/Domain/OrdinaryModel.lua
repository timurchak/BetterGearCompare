local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Reasons = BGA.Core.ReasonCodes

local OrdinaryModel = {}
BGA.Domain.OrdinaryModel = OrdinaryModel

local featureNames = { "strength", "crit", "haste", "mastery", "versatility" }

local function validateModel(model)
    return type(model) == "table"
        and type(model.mean) == "table"
        and type(model.scale) == "table"
        and type(model.knots) == "table"
        and type(model.coefficients) == "table"
        and type(model.primaryMin) == "number"
        and type(model.primaryMax) == "number"
        and type(model.secondaryBudgetMin) == "number"
        and type(model.secondaryBudgetMax) == "number"
end

function OrdinaryModel.Evaluate(model, stats)
    if not validateModel(model) or type(stats) ~= "table" then
        return nil, Reasons.MODEL_NOT_VALIDATED
    end

    local input = {}
    for index = 1, #featureNames do
        local value = stats[featureNames[index]]
        if type(value) ~= "number" then
            return nil, Reasons.OUT_OF_MODEL_DOMAIN
        end
        input[index] = value
    end

    local secondaryBudget = input[2] + input[3] + input[4] + input[5]
    if input[1] < model.primaryMin or input[1] > model.primaryMax
        or secondaryBudget < model.secondaryBudgetMin
        or secondaryBudget > model.secondaryBudgetMax
        or input[2] < 0 or input[3] < 0 or input[4] < 0 or input[5] < 0 then
        return nil, Reasons.OUT_OF_MODEL_DOMAIN
    end

    local normalized = {}
    for index = 1, #featureNames do
        if type(model.mean[index]) ~= "number" or type(model.scale[index]) ~= "number"
            or model.scale[index] == 0 or type(model.knots[index]) ~= "table"
            or #model.knots[index] ~= 4 then
            return nil, Reasons.MODEL_NOT_VALIDATED
        end
        normalized[index] = (input[index] - model.mean[index]) / model.scale[index]
    end

    local coefficientIndex = 1
    local value = model.coefficients[coefficientIndex]
    if type(value) ~= "number" then
        return nil, Reasons.MODEL_NOT_VALIDATED
    end
    coefficientIndex = coefficientIndex + 1

    for dimension = 1, #featureNames do
        local x = normalized[dimension]
        local linear = model.coefficients[coefficientIndex]
        if type(linear) ~= "number" then
            return nil, Reasons.MODEL_NOT_VALIDATED
        end
        value = value + linear * x
        coefficientIndex = coefficientIndex + 1
        for knotIndex = 1, 4 do
            local coefficient = model.coefficients[coefficientIndex]
            if type(coefficient) ~= "number" then
                return nil, Reasons.MODEL_NOT_VALIDATED
            end
            value = value + coefficient * math.max(0, x - model.knots[dimension][knotIndex])
            coefficientIndex = coefficientIndex + 1
        end
    end

    local interaction = {}
    for dimension = 1, #featureNames do
        local x = normalized[dimension]
        interaction[dimension] = {
            x,
            math.max(0, x - model.knots[dimension][2]),
            math.max(0, x - model.knots[dimension][4]),
        }
    end
    for left = 1, #featureNames do
        for right = left + 1, #featureNames do
            for leftBasis = 1, 3 do
                for rightBasis = 1, 3 do
                    local coefficient = model.coefficients[coefficientIndex]
                    if type(coefficient) ~= "number" then
                        return nil, Reasons.MODEL_NOT_VALIDATED
                    end
                    value = value + coefficient
                        * interaction[left][leftBasis] * interaction[right][rightBasis]
                    coefficientIndex = coefficientIndex + 1
                end
            end
        end
    end
    if model.coefficients[coefficientIndex] ~= nil then
        return nil, Reasons.MODEL_NOT_VALIDATED
    end
    return value
end

function OrdinaryModel.DeltaPercent(baselineLogScore, candidateLogScore)
    if type(baselineLogScore) ~= "number" or type(candidateLogScore) ~= "number" then
        return nil, Reasons.MODEL_NOT_VALIDATED
    end
    return 100 * (math.exp(candidateLogScore - baselineLogScore) - 1)
end
