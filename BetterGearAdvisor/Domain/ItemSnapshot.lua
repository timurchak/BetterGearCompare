local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Constants = BGA.Core.Constants
local Keys = BGA.Core.Keys
local TableUtil = BGA.Core.TableUtil
local Reasons = BGA.Core.ReasonCodes

local ItemSnapshot = {}
BGA.Domain.ItemSnapshot = ItemSnapshot

local modeledStats = { "strength", "crit", "haste", "mastery", "versatility" }

function ItemSnapshot.New(fields)
    if type(fields) ~= "table"
        or type(fields.fullLink) ~= "string"
        or type(fields.itemID) ~= "number"
        or type(fields.inventoryType) ~= "string"
        or type(fields.actualItemLevel) ~= "number"
        or fields.statsComplete ~= true
        or type(fields.stats) ~= "table" then
        return nil, Reasons.INVALID_ITEM_SNAPSHOT
    end

    local snapshot = TableUtil.DeepCopy(fields)
    snapshot.schema = Constants.ITEM_SNAPSHOT_SCHEMA
    snapshot.key = fields.key or Keys.ItemSnapshotKey(fields.fullLink, fields.itemGUID, fields.locationKey)
    snapshot.stats = {}
    for index = 1, #modeledStats do
        local stat = modeledStats[index]
        local value = fields.stats[stat]
        if value == nil then
            value = 0
        end
        if type(value) ~= "number" then
            return nil, Reasons.INVALID_ITEM_SNAPSHOT
        end
        snapshot.stats[stat] = value
    end

    snapshot.unknownStatKeys = TableUtil.CopyArray(fields.unknownStatKeys)
    snapshot.effectEvidence = TableUtil.DeepCopy(fields.effectEvidence or {})
    snapshot.sockets = TableUtil.DeepCopy(fields.sockets or {})
    snapshot.tertiary = TableUtil.DeepCopy(fields.tertiary or {})
    snapshot.upgrade = TableUtil.DeepCopy(fields.upgrade or {})
    return snapshot
end
