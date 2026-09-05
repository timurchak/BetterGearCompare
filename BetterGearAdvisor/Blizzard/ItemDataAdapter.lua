local _, BGA = ...

BGA.Blizzard = BGA.Blizzard or {}

local Reasons = BGA.Core.ReasonCodes

local ItemDataAdapter = {}
ItemDataAdapter.__index = ItemDataAdapter
BGA.Blizzard.ItemDataAdapter = ItemDataAdapter

local statMap = {
    ITEM_MOD_STRENGTH_SHORT = "strength",
    ITEM_MOD_CRIT_RATING_SHORT = "crit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste",
    ITEM_MOD_MASTERY_RATING_SHORT = "mastery",
    ITEM_MOD_VERSATILITY = "versatility",
    ITEM_MOD_VERSATILITY_SHORT = "versatility",
}

local recognizedIgnoredStats = {
    ITEM_MOD_AGILITY_SHORT = true,
    ITEM_MOD_INTELLECT_SHORT = true,
    ITEM_MOD_STAMINA_SHORT = true,
    ITEM_MOD_ARMOR_SHORT = true,
    ITEM_MOD_BONUS_ARMOR = true,
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = true,
    ITEM_MOD_LEECH_RATING_SHORT = true,
    ITEM_MOD_AVOIDANCE_RATING_SHORT = true,
    ITEM_MOD_SPEED_RATING_SHORT = true,
    ITEM_MOD_INDESTRUCTIBLE = true,
    EMPTY_SOCKET_PRISMATIC = true,
    RESISTANCE0_NAME = true,
}

local function noOp()
end

local function isSecret(api, value)
    return api.IsSecret and api.IsSecret(value) or false
end

local function mapStats(api, rawStats)
    local stats = { strength = 0, crit = 0, haste = 0, mastery = 0, versatility = 0 }
    local unknown = {}
    for key, value in pairs(rawStats) do
        if isSecret(api, key) or isSecret(api, value) or type(value) ~= "number" then
            return nil, nil, Reasons.ITEM_DATA_PENDING
        end
        local mapped = statMap[key]
        if mapped then
            stats[mapped] = stats[mapped] + value
        elseif not recognizedIgnoredStats[key] then
            unknown[#unknown + 1] = key
        end
    end
    table.sort(unknown)
    return stats, unknown, nil
end

function ItemDataAdapter.New(api, upgradeAdapter)
    api = api or {}
    return setmetatable({
        api = {
            GetItemInfoInstant = api.GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant),
            GetDetailedItemLevelInfo = api.GetDetailedItemLevelInfo or (C_Item and C_Item.GetDetailedItemLevelInfo),
            GetItemStats = api.GetItemStats or (C_Item and C_Item.GetItemStats),
            GetItemInventoryType = api.GetItemInventoryType or (C_Item and C_Item.GetItemInventoryType),
            GetItemInventoryTypeByID = api.GetItemInventoryTypeByID or (C_Item and C_Item.GetItemInventoryTypeByID),
            GetItemInfo = api.GetItemInfo or (C_Item and C_Item.GetItemInfo),
            IsEquippableItem = api.IsEquippableItem or (C_Item and C_Item.IsEquippableItem),
            CanUseItem = api.CanUseItem or (C_PlayerInfo and C_PlayerInfo.CanUseItem),
            GetItemUniquenessByID = api.GetItemUniquenessByID or (C_Item and C_Item.GetItemUniquenessByID),
            GetTooltipData = api.GetTooltipData or (C_TooltipInfo and C_TooltipInfo.GetHyperlink),
            CreateItemFromLink = api.CreateItemFromLink
                or function(fullLink) return Item:CreateFromItemLink(fullLink) end,
            IsSecret = api.IsSecret or issecretvalue,
            effectLineTypes = api.effectLineTypes or { [44] = true, [45] = true, [46] = true },
            craftingQualityLineType = api.craftingQualityLineType
                or (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ProfessionCraftingQuality),
        },
        upgradeAdapter = upgradeAdapter,
    }, ItemDataAdapter)
end

function ItemDataAdapter:Load(itemRef, callback)
    local item = self.api.CreateItemFromLink(itemRef.fullLink)
    if not item or not item.ContinueWithCancelOnItemLoad then
        callback(false, Reasons.ITEM_DATA_FAILED)
        return noOp
    end
    local cancel = item:ContinueWithCancelOnItemLoad(function()
        callback(true)
    end)
    return type(cancel) == "function" and cancel or noOp
end

function ItemDataAdapter:ReadResolved(itemRef)
    local api = self.api
    local itemID, _, _, itemEquipLoc, _, itemClassID, itemSubClassID = api.GetItemInfoInstant(itemRef.fullLink)
    local actualItemLevel, previewItemLevel = api.GetDetailedItemLevelInfo(itemRef.fullLink)
    local rawStats = api.GetItemStats(itemRef.fullLink)
    if not itemID or not itemEquipLoc or not actualItemLevel or not rawStats
        or isSecret(api, itemID) or isSecret(api, actualItemLevel) or isSecret(api, rawStats) then
        return { status = "pending", reasonCode = Reasons.ITEM_DATA_PENDING }
    end

    local validLocation = itemRef.itemLocation
        and (not itemRef.itemLocation.IsValid or itemRef.itemLocation:IsValid())
    local inventoryType
    if validLocation and api.GetItemInventoryType then
        inventoryType = api.GetItemInventoryType(itemRef.itemLocation)
    end
    if not inventoryType and api.GetItemInventoryTypeByID then
        inventoryType = api.GetItemInventoryTypeByID(itemID)
    end
    if not inventoryType then
        return { status = "pending", reasonCode = Reasons.ITEM_DATA_PENDING }
    end

    local stats, unknownStatKeys, statReason = mapStats(api, rawStats)
    if not stats then
        return { status = "pending", reasonCode = statReason }
    end
    local setID
    if api.GetItemInfo then
        setID = select(16, api.GetItemInfo(itemRef.fullLink))
    end
    local isUnique, _, uniqueCategoryLimit, uniqueCategoryID
    if api.GetItemUniquenessByID then
        isUnique, _, uniqueCategoryLimit, uniqueCategoryID = api.GetItemUniquenessByID(itemID)
    end

    local effectLineTypes = {}
    local isCrafted = false
    if not api.GetTooltipData then
        return { status = "pending", reasonCode = Reasons.ITEM_DATA_PENDING }
    end
    local tooltipData = api.GetTooltipData(itemRef.fullLink)
    if not tooltipData or type(tooltipData.lines) ~= "table" then
        return { status = "pending", reasonCode = Reasons.ITEM_DATA_PENDING }
    end
    for _, line in ipairs(tooltipData.lines) do
        if api.effectLineTypes[line.type] then
            effectLineTypes[#effectLineTypes + 1] = line.type
        end
        if api.craftingQualityLineType and line.type == api.craftingQualityLineType then
            isCrafted = true
        end
    end

    local metadata = self.upgradeAdapter and self.upgradeAdapter:GetMetadata(itemRef)
        or { status = "ready", metadataPresent = false }
    local eligibility = self.upgradeAdapter and self.upgradeAdapter:GetEligibility(itemRef.itemLocation) or "unknown"
    if metadata.status ~= "ready" then
        return { status = "pending", reasonCode = metadata.reasonCode or Reasons.ITEM_DATA_PENDING }
    end

    local isEquippable = api.IsEquippableItem and api.IsEquippableItem(itemRef.fullLink)
    local canUse = api.CanUseItem and api.CanUseItem(itemID)
    return {
        status = "ready",
        rawFields = {
            resolutionStatus = "ready",
            fullLink = itemRef.fullLink,
            itemID = itemID,
            itemGUID = itemRef.itemGUID,
            locationKey = itemRef.locationKey,
            inventoryType = itemEquipLoc,
            inventoryTypeID = inventoryType,
            itemClassID = itemClassID,
            itemSubClassID = itemSubClassID,
            actualItemLevel = actualItemLevel,
            previewItemLevel = previewItemLevel,
            statsComplete = true,
            stats = stats,
            unknownStatKeys = unknownStatKeys,
            setID = setID,
            isCrafted = isCrafted,
            isEquippable = isEquippable,
            canUse = canUse,
            isUnique = isUnique == true,
            uniqueCategoryID = isUnique and uniqueCategoryID or nil,
            uniqueCategoryLimit = isUnique and uniqueCategoryLimit or nil,
            effectEvidence = { tooltipLineTypes = effectLineTypes },
            upgrade = {
                metadataPresent = metadata.metadataPresent,
                rank = metadata.currentLevel,
                maxRank = metadata.maxLevel,
                eligibility = eligibility,
                manifestStatus = "unverified",
            },
        },
    }
end
