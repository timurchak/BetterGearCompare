local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Result = BGA.Core.Result
local Reasons = BGA.Core.ReasonCodes
local TableUtil = BGA.Core.TableUtil

local ConfidencePolicy = {}
BGA.Domain.ConfidencePolicy = ConfidencePolicy

local function appendReason(reasons, reason)
    local result = TableUtil.CopyArray(reasons)
    if not TableUtil.ArrayContains(result, reason) then
        result[#result + 1] = reason
    end
    return result
end

function ConfidencePolicy.Decide(deltaPercent, uncertaintyPercent, materialityPercent, fields)
    if type(deltaPercent) ~= "number" or type(uncertaintyPercent) ~= "number"
        or type(materialityPercent) ~= "number" or uncertaintyPercent < 0 or materialityPercent < 0 then
        return Result.New("unsupported", {
            reasonCodes = { Reasons.MODEL_NOT_VALIDATED },
            provenance = fields and fields.provenance or {},
        })
    end

    fields = TableUtil.DeepCopy(fields or {})
    fields.deltaPercent = deltaPercent
    fields.uncertaintyPercent = uncertaintyPercent
    fields.materialityPercent = materialityPercent
    fields.interval = {
        low = deltaPercent - uncertaintyPercent,
        high = deltaPercent + uncertaintyPercent,
    }

    if fields.interval.low > materialityPercent then
        return Result.New("upgrade", fields)
    end
    if fields.interval.high < -materialityPercent then
        return Result.New("downgrade", fields)
    end

    fields.reasonCodes = appendReason(fields.reasonCodes, Reasons.UNCERTAINTY_OVERLAPS_MATERIALITY)
    return Result.New("too_close", fields)
end
