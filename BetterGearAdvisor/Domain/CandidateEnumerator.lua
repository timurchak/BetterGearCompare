local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Constants = BGA.Core.Constants
local Reasons = BGA.Core.ReasonCodes
local EquipmentState = BGA.Domain.EquipmentState

local CandidateEnumerator = {}
BGA.Domain.CandidateEnumerator = CandidateEnumerator

local singleSlots = {
    INVTYPE_HEAD = 1,
    INVTYPE_NECK = 2,
    INVTYPE_SHOULDER = 3,
    INVTYPE_CHEST = 5,
    INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7,
    INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9,
    INVTYPE_HAND = 10,
    INVTYPE_CLOAK = 15,
}

local function replacement(baseline, candidate, slotID)
    local state, removed, reason = EquipmentState.ReplaceSlot(baseline, slotID, candidate)
    if not state then
        return nil, reason
    end
    return {
        id = state.id,
        state = state,
        replacedSlots = { slotID },
        removedItemKeys = removed and { removed.key } or {},
        retainedRingSlot = slotID == Constants.RING_SLOT_1 and Constants.RING_SLOT_2
            or (slotID == Constants.RING_SLOT_2 and Constants.RING_SLOT_1 or nil),
    }
end

function CandidateEnumerator.Enumerate(baseline, candidate)
    if not baseline or not candidate then
        return { status = "unsupported", states = {}, reasonCodes = { Reasons.INVALID_EQUIPMENT_STATE } }
    end

    local slots = {}
    if candidate.inventoryType == "INVTYPE_FINGER" then
        slots = { Constants.RING_SLOT_1, Constants.RING_SLOT_2 }
    elseif singleSlots[candidate.inventoryType] then
        slots = { singleSlots[candidate.inventoryType] }
    else
        return { status = "unsupported", states = {}, reasonCodes = { Reasons.UNSUPPORTED_INVENTORY_TYPE } }
    end

    local states = {}
    for index = 1, #slots do
        local value, reason = replacement(baseline, candidate, slots[index])
        if not value then
            return { status = "unsupported", states = {}, reasonCodes = { reason } }
        end
        states[#states + 1] = value
    end
    return { status = "ok", states = states, reasonCodes = {} }
end
