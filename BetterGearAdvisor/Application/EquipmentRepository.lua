local _, BGA = ...

BGA.Application = BGA.Application or {}

local EquipmentState = BGA.Domain.EquipmentState
local Reasons = BGA.Core.ReasonCodes

local EquipmentRepository = {}
EquipmentRepository.__index = EquipmentRepository
BGA.Application.EquipmentRepository = EquipmentRepository

function EquipmentRepository.New(inventoryPort, itemRepository)
    return setmetatable({ inventoryPort = inventoryPort, itemRepository = itemRepository }, EquipmentRepository)
end

function EquipmentRepository:ResolveSnapshot(context, callback)
    local capture = self.inventoryPort:CaptureEquippedRefs()
    if not capture or type(capture.refsBySlot) ~= "table" then
        callback({ status = "failed", reasonCode = Reasons.INVALID_EQUIPMENT_STATE })
        return function() end
    end

    local slotIDs = {}
    for slotID in pairs(capture.refsBySlot) do
        slotIDs[#slotIDs + 1] = slotID
    end
    table.sort(slotIDs)
    if #slotIDs == 0 then
        callback({ status = "failed", reasonCode = Reasons.INVALID_EQUIPMENT_STATE })
        return function() end
    end

    -- The full fan-out is known before subscribing because Resolve callbacks
    -- may run synchronously for cached item data.
    local pending = #slotIDs
    local finished = {}
    local snapshots = {}
    local cancellations = {}
    local published = false

    local function publish(result)
        if published then
            return
        end
        published = true
        callback(result)
    end

    for index = 1, #slotIDs do
        local slotID = slotIDs[index]
        local itemRef = capture.refsBySlot[slotID]
        cancellations[index] = self.itemRepository:Resolve(itemRef, context, function(result)
            if published or finished[index] then
                return
            end
            finished[index] = true
            if result.status ~= "ready" then
                publish({ status = "failed", reasonCode = result.reasonCode })
                return
            end
            snapshots[slotID] = result.snapshot
            pending = pending - 1
            if pending == 0 then
                local state, reason = EquipmentState.New({
                    slots = snapshots,
                    equipmentRevision = capture.equipmentRevision,
                    inventoryRevision = capture.inventoryRevision,
                    materialEffectSignature = capture.materialEffectSignature,
                })
                if not state then
                    publish({ status = "failed", reasonCode = reason })
                else
                    publish({ status = "ready", state = state })
                end
            end
        end)
        if published then
            break
        end
    end

    return function()
        if published then
            return
        end
        published = true
        for index = 1, #cancellations do
            if cancellations[index] then
                cancellations[index]()
            end
        end
    end
end
