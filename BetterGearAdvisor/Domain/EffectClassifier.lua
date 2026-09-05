local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Reasons = BGA.Core.ReasonCodes

local EffectClassifier = {}
BGA.Domain.EffectClassifier = EffectClassifier

local weaponTypes = {
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_SHIELD = true,
    INVTYPE_HOLDABLE = true,
}

local supportedOrdinaryTypes = {
    INVTYPE_HEAD = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_CLOAK = true,
    INVTYPE_NECK = true,
    INVTYPE_FINGER = true,
}

function EffectClassifier.Classify(snapshot)
    if not snapshot then
        return { status = "pending", reasonCodes = { Reasons.ITEM_DATA_PENDING } }
    end
    if snapshot.resolutionStatus and snapshot.resolutionStatus ~= "ready" then
        return { status = "pending", reasonCodes = { Reasons.ITEM_DATA_PENDING } }
    end
    if weaponTypes[snapshot.inventoryType] then
        return { status = "unsupported", reasonCodes = { Reasons.WEAPON_UNSUPPORTED } }
    end
    if snapshot.inventoryType == "INVTYPE_TRINKET" then
        return { status = "special", reasonCodes = { Reasons.TRINKET_UNSUPPORTED } }
    end
    if snapshot.setID then
        return { status = "special", reasonCodes = { Reasons.TIER_UNSUPPORTED } }
    end
    if snapshot.isCrafted then
        return { status = "special", reasonCodes = { Reasons.CRAFTED_ITEM_UNSUPPORTED } }
    end
    if #(snapshot.unknownStatKeys or {}) > 0 then
        return { status = "unsupported", reasonCodes = { Reasons.UNKNOWN_STAT_KEY } }
    end

    local evidence = snapshot.effectEvidence or {}
    if evidence.itemSpellID or evidence.triggeredSpellID or evidence.knownSpecialKey
        or #(evidence.tooltipLineTypes or {}) > 0 then
        return { status = "special", reasonCodes = { Reasons.SPECIAL_EFFECT_DETECTED } }
    end
    if not supportedOrdinaryTypes[snapshot.inventoryType] then
        return { status = "unsupported", reasonCodes = { Reasons.UNSUPPORTED_INVENTORY_TYPE } }
    end
    return { status = "ordinary", reasonCodes = {} }
end
