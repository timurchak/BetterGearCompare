local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Reasons = BGA.Core.ReasonCodes

local StateValidator = {}
BGA.Domain.StateValidator = StateValidator

local plateSlots = {
    [1] = true, [3] = true, [5] = true, [6] = true, [7] = true,
    [8] = true, [9] = true, [10] = true,
}

function StateValidator.Validate(candidateState)
    if not candidateState or not candidateState.state or not candidateState.state.slots then
        return { status = "invalid", reasonCodes = { Reasons.INVALID_EQUIPMENT_STATE } }
    end

    local guidSlots = {}
    local uniqueItemCounts = {}
    local categoryCounts = {}
    local categoryLimits = {}

    for slotID, item in pairs(candidateState.state.slots) do
        if item.isEquippable == false or item.canUse == false then
            return { status = "invalid", reasonCodes = { Reasons.ITEM_NOT_EQUIPPABLE } }
        end
        if plateSlots[slotID] and (item.itemClassID ~= 4 or item.itemSubClassID ~= 4) then
            return { status = "invalid", reasonCodes = { Reasons.WRONG_ARMOR_TYPE } }
        end
        if item.itemGUID then
            if guidSlots[item.itemGUID] then
                return { status = "invalid", reasonCodes = { Reasons.DUPLICATE_INSTANCE } }
            end
            guidSlots[item.itemGUID] = slotID
        end
        if item.isUnique then
            uniqueItemCounts[item.itemID] = (uniqueItemCounts[item.itemID] or 0) + 1
            if uniqueItemCounts[item.itemID] > 1 then
                return { status = "invalid", reasonCodes = { Reasons.UNIQUE_LIMIT_VIOLATION } }
            end
        end
        if item.uniqueCategoryID then
            local category = item.uniqueCategoryID
            categoryCounts[category] = (categoryCounts[category] or 0) + 1
            local declaredLimit = item.uniqueCategoryLimit or 1
            categoryLimits[category] = math.min(categoryLimits[category] or declaredLimit, declaredLimit)
        end
    end

    for category, count in pairs(categoryCounts) do
        if count > categoryLimits[category] then
            return { status = "invalid", reasonCodes = { Reasons.UNIQUE_LIMIT_VIOLATION } }
        end
    end
    return { status = "valid", reasonCodes = {} }
end
