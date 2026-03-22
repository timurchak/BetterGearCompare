local _, ns = ...

ns.Tooltip = {
  initialized = false,
}

local L = ns.L

local ALLOWED_TOOLTIP_NAMES = {
  GameTooltip = true,
  ItemRefTooltip = true,
}

local function ShouldAnnotateTooltip(tooltip)
  if not tooltip then
    return false
  end

  local name = tooltip:GetName()
  return name and ALLOWED_TOOLTIP_NAMES[name] or false
end

local function TooltipAlreadyAnnotated(tooltip)
  local name = tooltip:GetName()
  if not name then
    return false
  end

  for lineIndex = 1, tooltip:NumLines() do
    local leftText = _G[name .. "TextLeft" .. lineIndex]
    if leftText and leftText:GetText() == "BetterGearCompare" then
      return true
    end
  end

  return false
end

local function ExtractItemLink(tooltip, data)
  if TooltipUtil and TooltipUtil.GetDisplayedItem then
    local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
    if itemLink then
      return itemLink
    end
  end

  if data then
    if data.hyperlink then
      return data.hyperlink
    end

    if data.itemLink then
      return data.itemLink
    end
  end

  if tooltip.GetItem then
    local _, itemLink = tooltip:GetItem()
    if itemLink then
      return itemLink
    end
  end

  if tooltip.itemLink then
    return tooltip.itemLink
  end

  if tooltip.processingInfo then
    return tooltip.processingInfo.hyperlink or tooltip.processingInfo.itemLink
  end

  return nil
end

local function AddComparisonLines(tooltip, itemLink)
  local comparison = ns.Compare:GetComparison(itemLink)
  if not comparison then
    if ns.DebugLog then
      ns:DebugLog("tooltip skip", "no comparison result")
    end
    return
  end

  local slotLabel = comparison.slotLabelOverride or ns.Compare:GetSlotLabel(comparison.slotID)

  tooltip:AddLine(" ")
  tooltip:AddLine(L.TOOLTIP_HEADER, 0.35, 0.82, 1)

  if comparison.state == "no_compare" then
    tooltip:AddLine(string.format(L.TOOLTIP_NO_COMPARE, comparison.newScore), 0.8, 0.8, 0.8)
    return
  end

  if comparison.state == "better" then
    tooltip:AddLine(string.format(L.TOOLTIP_BETTER, slotLabel, comparison.percent), 0.1, 1, 0.1)
  elseif comparison.state == "worse" then
    tooltip:AddLine(string.format(L.TOOLTIP_WORSE, slotLabel, math.abs(comparison.percent)), 1, 0.15, 0.15)
  else
    tooltip:AddLine(string.format(L.TOOLTIP_EQUAL, slotLabel), 0.85, 0.85, 0.85)
  end

  tooltip:AddLine(string.format(L.TOOLTIP_SCORE, comparison.newScore, comparison.equippedScore), 0.8, 0.8, 0.8)
end

local function HandleTooltipItem(tooltip, data)
  if not ShouldAnnotateTooltip(tooltip) then
    return
  end

  if tooltip.__bgcProcessing then
    return
  end

  local itemLink = ExtractItemLink(tooltip, data)
  if not itemLink or TooltipAlreadyAnnotated(tooltip) then
    return
  end

  if ns.DebugLog then
    ns:DebugLog("tooltip item", itemLink)
  end

  tooltip.__bgcProcessing = true
  AddComparisonLines(tooltip, itemLink)
  tooltip:Show()
  tooltip.__bgcProcessing = false
end

local function HookTooltipMethod(tooltip, methodName, extractor)
  if not tooltip or not tooltip[methodName] or not hooksecurefunc then
    return
  end

  hooksecurefunc(tooltip, methodName, function(self, ...)
    local itemLink = extractor and extractor(self, ...) or nil
    HandleTooltipItem(self, itemLink and { hyperlink = itemLink } or nil)
  end)
end

local function HookBasicTooltip(tooltip)
  if not tooltip then
    return
  end

  if tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
    tooltip:HookScript("OnTooltipSetItem", HandleTooltipItem)
  end
end

local function HookProcessInfoTooltip(tooltip)
  if not tooltip or not tooltip.ProcessInfo or not hooksecurefunc then
    return
  end

  hooksecurefunc(tooltip, "ProcessInfo", function(self)
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
      local _, itemLink = TooltipUtil.GetDisplayedItem(self)
      if itemLink then
        HandleTooltipItem(self, { hyperlink = itemLink })
        return
      end
    end

    HandleTooltipItem(self)
  end)
end

function ns.Tooltip:Init()
  if self.initialized then
    return
  end

  HookBasicTooltip(GameTooltip)
  HookProcessInfoTooltip(GameTooltip)

  for _, methodName in ipairs(ns.Constants.tooltipMethods) do
    if methodName == "SetHyperlink" then
      HookTooltipMethod(GameTooltip, methodName, function(_, itemLink)
        return itemLink
      end)
    else
      HookTooltipMethod(GameTooltip, methodName)
    end
  end

  HookBasicTooltip(ItemRefTooltip)

  if ItemRefTooltip then
    HookTooltipMethod(ItemRefTooltip, "SetHyperlink", function(_, itemLink)
      return itemLink
    end)
  end

  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, HandleTooltipItem)
  end

  self.initialized = true
end
