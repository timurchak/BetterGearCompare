local _, BGA = ...

BGA.Core = BGA.Core or {}

local Keys = {}
BGA.Core.Keys = Keys

local function requireString(value, label)
    if type(value) ~= "string" or value == "" then
        error((label or "value") .. " must be a non-empty string", 3)
    end
end

function Keys.ItemPayload(fullLink)
    requireString(fullLink, "fullLink")

    local payload = string.match(fullLink, "|H(item:[^|]+)|h")
    if payload then
        return payload
    end
    if string.sub(fullLink, 1, 5) == "item:" then
        return fullLink
    end
    error("fullLink does not contain an item payload", 2)
end

function Keys.ItemSnapshotKey(fullLink, itemGUID, locationKey)
    local identity = itemGUID or locationKey or "detached"
    return Keys.ItemPayload(fullLink) .. "|instance=" .. identity
end

function Keys.EquipmentStateKey(slots, equipmentRevision, inventoryRevision)
    local slotIDs = {}
    for slotID in pairs(slots or {}) do
        slotIDs[#slotIDs + 1] = slotID
    end
    table.sort(slotIDs)

    local parts = {
        "equipment=" .. tostring(equipmentRevision or 0),
        "inventory=" .. tostring(inventoryRevision or 0),
    }
    for index = 1, #slotIDs do
        local slotID = slotIDs[index]
        local item = slots[slotID]
        parts[#parts + 1] = tostring(slotID) .. "=" .. (item and item.key or "empty")
    end
    return table.concat(parts, "|")
end
