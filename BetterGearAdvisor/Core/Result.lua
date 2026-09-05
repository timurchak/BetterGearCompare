local _, BGA = ...

BGA.Core = BGA.Core or {}

local TableUtil = BGA.Core.TableUtil
local Constants = BGA.Core.Constants

local Result = {}
BGA.Core.Result = Result

local validStatuses = {
    upgrade = true,
    downgrade = true,
    too_close = true,
    special = true,
    unsupported = true,
    pending = true,
}

function Result.New(status, fields)
    if not validStatuses[status] then
        error("invalid evaluation status: " .. tostring(status), 2)
    end

    fields = fields or {}
    local result = TableUtil.DeepCopy(fields)
    result.schema = Constants.RESULT_SCHEMA
    result.status = status
    result.reasonCodes = TableUtil.CopyArray(fields.reasonCodes)
    result.provenance = TableUtil.DeepCopy(fields.provenance or {})

    local directional = status == "upgrade" or status == "downgrade" or status == "too_close"
    if directional then
        if type(result.deltaPercent) ~= "number" or type(result.uncertaintyPercent) ~= "number" then
            error("numeric result requires deltaPercent and uncertaintyPercent", 2)
        end
    elseif result.deltaPercent ~= nil or result.uncertaintyPercent ~= nil then
        error(status .. " result must not contain a numeric recommendation", 2)
    end

    return result
end

function Result.IsFinal(result)
    return result ~= nil and result.status ~= "pending"
end
