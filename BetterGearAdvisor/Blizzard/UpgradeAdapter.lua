local _, BGA = ...

BGA.Blizzard = BGA.Blizzard or {}

local Reasons = BGA.Core.ReasonCodes

local UpgradeAdapter = {}
UpgradeAdapter.__index = UpgradeAdapter
BGA.Blizzard.UpgradeAdapter = UpgradeAdapter

function UpgradeAdapter.New(api)
    api = api or {}
    return setmetatable({
        GetItemUpgradeInfo = api.GetItemUpgradeInfo or (C_Item and C_Item.GetItemUpgradeInfo),
        CanUpgradeItem = api.CanUpgradeItem or (C_ItemUpgrade and C_ItemUpgrade.CanUpgradeItem),
    }, UpgradeAdapter)
end

function UpgradeAdapter:GetMetadata(itemRef)
    if not self.GetItemUpgradeInfo then
        return { status = "failed", reasonCode = Reasons.ITEM_DATA_FAILED }
    end
    local info = self.GetItemUpgradeInfo(itemRef.fullLink)
    if not info then
        return { status = "ready", metadataPresent = false }
    end
    return {
        status = "ready",
        metadataPresent = true,
        currentLevel = info.currentLevel,
        maxLevel = info.maxLevel,
        maxItemLevel = info.maxItemLevel,
        trackStringID = info.trackStringID,
    }
end

function UpgradeAdapter:GetEligibility(itemLocation)
    if not itemLocation then
        return "unknown"
    end
    if itemLocation.IsValid and not itemLocation:IsValid() then
        return "unknown"
    end
    if not self.CanUpgradeItem then
        return "unknown"
    end

    -- Keep the literal boolean. A truthiness idiom would collapse false to nil.
    local eligible = self.CanUpgradeItem(itemLocation)
    if eligible == true then
        return true
    end
    if eligible == false then
        return false
    end
    return "unknown"
end
