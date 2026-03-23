local ADDON_NAME, ns = ...

_G.BetterGearCompare = ns

ns.ADDON_NAME = ADDON_NAME
ns.frame = CreateFrame("Frame")
ns.Debug = {
  enabled = false,
}

function ns:SetDebugEnabled(enabled)
  enabled = enabled and true or false
  self.Debug.enabled = enabled

  BetterGearCompareCharDB = BetterGearCompareCharDB or {}
  BetterGearCompareCharDB.debugEnabled = enabled
end

function ns:IsDebugEnabled()
  return self.Debug and self.Debug.enabled or false
end

function ns:DebugLog(...)
  if not self:IsDebugEnabled() then
    return
  end

  local parts = {}
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    parts[#parts + 1] = tostring(value)
  end

  local message = table.concat(parts, " ")
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffBetterGearCompare|r " .. message)
  end
end

local function OnAddonLoaded(addonName)
  if addonName == ADDON_NAME then
    ns.DB:Init()
    ns.Tooltip:Init()
    ns.Options:Init()
    ns.Icons:Init()
    return
  end

  if addonName == "Baganator" and ns.Icons then
    ns.Icons:InitBaganator()
  end
end

local function TryShowFirstRunWelcome()
  if not ns.DB or not ns.Options then
    return
  end

  if ns.DB:HasSeenWelcome() then
    return
  end

  ns.DB:MarkWelcomeSeen()
  ns.Options:ShowFirstRunWelcome()
end

local function OnSpecializationChanged()
  if not BetterGearCompareDB or not BetterGearCompareCharDB then
    return
  end

  ns.DB:EnsureSpecProfile()

  if ns.Options then
    ns.Options:Refresh()
  end

  if ns.Icons then
    ns.Icons:Refresh()
  end
end

local hasHandledInitialPlayerEnter = false

ns.frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    OnAddonLoaded(...)
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
    OnSpecializationChanged()

    if event == "PLAYER_ENTERING_WORLD" and not hasHandledInitialPlayerEnter then
      hasHandledInitialPlayerEnter = true
      TryShowFirstRunWelcome()
    end
  end
end)

ns.frame:RegisterEvent("ADDON_LOADED")
ns.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
ns.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ns.frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
