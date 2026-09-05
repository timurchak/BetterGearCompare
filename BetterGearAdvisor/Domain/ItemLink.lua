local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Reasons = BGA.Core.ReasonCodes

local ItemLink = {}
BGA.Domain.ItemLink = ItemLink

local function splitPreservingEmpty(text, delimiter)
    local parts = {}
    local startAt = 1
    while true do
        local delimiterAt = string.find(text, delimiter, startAt, true)
        if not delimiterAt then
            parts[#parts + 1] = string.sub(text, startAt)
            return parts
        end
        parts[#parts + 1] = string.sub(text, startAt, delimiterAt - 1)
        startAt = delimiterAt + #delimiter
    end
end

function ItemLink.Parse(fullLink)
    if type(fullLink) ~= "string" or fullLink == "" then
        return nil, Reasons.INVALID_ITEM_SNAPSHOT
    end

    local payloadStart = string.find(fullLink, "item:", 1, true)
    if not payloadStart then
        return nil, Reasons.INVALID_ITEM_SNAPSHOT
    end
    local suffixStart = string.find(fullLink, "|", payloadStart, true)
    local payloadEnd = suffixStart and suffixStart - 1 or #fullLink
    local payload = string.sub(fullLink, payloadStart, payloadEnd)
    local parts = splitPreservingEmpty(payload, ":")
    if parts[1] ~= "item" or not tonumber(parts[2]) then
        return nil, Reasons.INVALID_ITEM_SNAPSHOT
    end

    local bonusCount = tonumber(parts[14])
    if not bonusCount or bonusCount < 0 or bonusCount > 200 or bonusCount % 1 ~= 0 then
        return nil, Reasons.INVALID_ITEM_SNAPSHOT
    end
    if #parts < 14 + bonusCount then
        return nil, Reasons.INVALID_ITEM_SNAPSHOT
    end

    local bonuses = {}
    for partIndex = 15, 14 + bonusCount do
        local bonusID = tonumber(parts[partIndex])
        if not bonusID then
            return nil, Reasons.INVALID_ITEM_SNAPSHOT
        end
        bonuses[#bonuses + 1] = { id = bonusID, partIndex = partIndex }
    end

    return {
        fullLink = fullLink,
        prefix = string.sub(fullLink, 1, payloadStart - 1),
        suffix = suffixStart and string.sub(fullLink, suffixStart) or "",
        payload = payload,
        parts = parts,
        bonuses = bonuses,
    }
end

function ItemLink.ReplacePart(parsed, partIndex, replacement)
    if not parsed or not parsed.parts or type(partIndex) ~= "number" then
        return nil, Reasons.INVALID_ITEM_SNAPSHOT
    end
    local parts = {}
    for index = 1, #parsed.parts do
        parts[index] = parsed.parts[index]
    end
    parts[partIndex] = tostring(replacement)
    return parsed.prefix .. table.concat(parts, ":") .. parsed.suffix
end
