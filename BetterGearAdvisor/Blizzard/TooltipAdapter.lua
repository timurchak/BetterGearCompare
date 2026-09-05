local _, BGA = ...

BGA.Blizzard = BGA.Blizzard or {}

local TooltipAdapter = {}
TooltipAdapter.__index = TooltipAdapter
BGA.Blizzard.TooltipAdapter = TooltipAdapter

local function isSecret(api, value)
    return api.IsSecret and api.IsSecret(value) or false
end

function TooltipAdapter.New(api, inventoryAdapter)
    api = api or {}
    return setmetatable({
        api = {
            AddTooltipPostCall = api.AddTooltipPostCall
                or function(dataType, callback) TooltipDataProcessor.AddTooltipPostCall(dataType, callback) end,
            itemDataType = api.itemDataType
                or (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item),
            GetItemLinkByGUID = api.GetItemLinkByGUID or (C_Item and C_Item.GetItemLinkByGUID),
            GetDisplayedItem = api.GetDisplayedItem or (TooltipUtil and TooltipUtil.GetDisplayedItem),
            IsSecret = api.IsSecret or issecretvalue,
        },
        inventoryAdapter = inventoryAdapter,
    }, TooltipAdapter)
end

function TooltipAdapter:RegisterItemPostCall(callback)
    self.api.AddTooltipPostCall(self.api.itemDataType, callback)
    self.registrationSucceeded = true
end

function TooltipAdapter:GetDisplayedItem(tooltip, tooltipData)
    local guid = tooltipData and tooltipData.guid
    if isSecret(self.api, guid) then
        guid = nil
    end

    local fullLink
    if self.api.GetDisplayedItem then
        local _, displayedLink = self.api.GetDisplayedItem(tooltip)
        if not isSecret(self.api, displayedLink) then
            fullLink = displayedLink
        end
    end
    if not fullLink and tooltipData and not isSecret(self.api, tooltipData.hyperlink) then
        fullLink = tooltipData.hyperlink
    end
    if not fullLink and tooltipData and not isSecret(self.api, tooltipData.itemLink) then
        fullLink = tooltipData.itemLink
    end
    if not fullLink and guid and self.api.GetItemLinkByGUID then
        local guidLink = self.api.GetItemLinkByGUID(guid)
        if not isSecret(self.api, guidLink) then
            fullLink = guidLink
        end
    end
    if not fullLink and tooltip.GetItem then
        local _, displayedLink = tooltip:GetItem()
        if not isSecret(self.api, displayedLink) then
            fullLink = displayedLink
        end
    end
    if not fullLink and not isSecret(self.api, tooltip.itemLink) then
        fullLink = tooltip.itemLink
    end
    if not fullLink and tooltip.processingInfo then
        local processingLink = tooltip.processingInfo.hyperlink or tooltip.processingInfo.itemLink
        if not isSecret(self.api, processingLink) then
            fullLink = processingLink
        end
    end
    if type(fullLink) ~= "string" or fullLink == "" then
        return nil
    end

    local owned = self.inventoryAdapter and self.inventoryAdapter:FindOwnedRef(fullLink, guid)
    if owned then
        return owned
    end

    local name = tooltip.GetName and tooltip:GetName() or ""
    local source = string.find(name, "ShoppingTooltip", 1, true) and "comparison"
        or (string.find(name, "ItemRef", 1, true) and "chat" or "detached")
    return { fullLink = fullLink, itemGUID = guid, source = source }
end

function TooltipAdapter:Refresh(tooltip)
    if self:IsShown(tooltip) and tooltip.RefreshData then
        tooltip:RefreshData()
        return true
    end
    return false
end

function TooltipAdapter:Commit(tooltip)
    if tooltip.Show then
        tooltip:Show()
        return true
    end
    return false
end

function TooltipAdapter:HookHide(tooltip, callback)
    if tooltip.HookScript then
        tooltip:HookScript("OnHide", callback)
    end
end

function TooltipAdapter:IsShown(tooltip)
    return not tooltip.IsShown or tooltip:IsShown()
end

function TooltipAdapter:NumLines(tooltip)
    return tooltip.NumLines and tooltip:NumLines() or 0
end
