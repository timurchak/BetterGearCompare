local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Constants = BGA.Core.Constants
local Keys = BGA.Core.Keys
local TableUtil = BGA.Core.TableUtil
local Reasons = BGA.Core.ReasonCodes

local EquipmentState = {}
BGA.Domain.EquipmentState = EquipmentState

local modeledStats = { "strength", "crit", "haste", "mastery", "versatility" }

local function aggregate(slots)
    local totals = { strength = 0, crit = 0, haste = 0, mastery = 0, versatility = 0 }
    for _, item in pairs(slots) do
        for index = 1, #modeledStats do
            local stat = modeledStats[index]
            totals[stat] = totals[stat] + item.stats[stat]
        end
    end
    return totals
end

function EquipmentState.New(fields)
    if type(fields) ~= "table" or type(fields.slots) ~= "table" then
        return nil, Reasons.INVALID_EQUIPMENT_STATE
    end
    for slotID, item in pairs(fields.slots) do
        if type(slotID) ~= "number" or type(item) ~= "table" or type(item.key) ~= "string" then
            return nil, Reasons.INVALID_EQUIPMENT_STATE
        end
    end

    local state = {
        schema = Constants.EQUIPMENT_STATE_SCHEMA,
        slots = TableUtil.ShallowCopy(fields.slots),
        equipmentRevision = fields.equipmentRevision or 0,
        inventoryRevision = fields.inventoryRevision or 0,
        materialEffectSignature = fields.materialEffectSignature or "unverified",
    }
    state.aggregateStats = aggregate(state.slots)
    state.id = Keys.EquipmentStateKey(state.slots, state.equipmentRevision, state.inventoryRevision)
    return state
end

function EquipmentState.ReplaceSlot(baseline, slotID, candidate)
    local slots = TableUtil.ShallowCopy(baseline.slots)
    local removed = slots[slotID]
    slots[slotID] = candidate

    local state, reason = EquipmentState.New({
        slots = slots,
        equipmentRevision = baseline.equipmentRevision,
        inventoryRevision = baseline.inventoryRevision,
        materialEffectSignature = baseline.materialEffectSignature,
    })
    return state, removed, reason
end
