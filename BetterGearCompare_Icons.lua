local _, ns = ...

ns.Icons = {
  baganatorRegistered = false,
}

local L = ns.L

local function PostBaganatorRefresh()
  if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
    Baganator.API.RequestItemButtonsRefresh()
  end
end

function ns.Icons:Refresh()
  PostBaganatorRefresh()
end

function ns.Icons:InitBaganator()
  if self.baganatorRegistered or not (Baganator and Baganator.API and Syndicator) then
    return
  end

  self.baganatorRegistered = true

  local refreshFrame = CreateFrame("Frame")
  refreshFrame:RegisterEvent("PLAYER_LEVEL_UP")
  refreshFrame:RegisterEvent("BAG_UPDATE_DELAYED")
  refreshFrame:SetScript("OnEvent", PostBaganatorRefresh)

  Syndicator.CallbackRegistry:RegisterCallback("EquippedCacheUpdate", PostBaganatorRefresh)

  Baganator.API.RegisterCornerWidget(L.ADDON_NAME, "bettergearcompare", function(_, details)
    return details.itemLink and ns.Compare:ShouldShowUpgradeIcon(details.itemLink)
  end, function(itemButton)
    local arrow = itemButton:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas("bags-greenarrow", true)
    arrow:SetScale(0.8)
    return arrow
  end, { corner = "top_left", priority = 2 }, true)

  PostBaganatorRefresh()
end

function ns.Icons:Init()
  if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Baganator") then
    self:InitBaganator()
  end
end
