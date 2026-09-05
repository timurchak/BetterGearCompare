local addonName = ...

local tooltipStates = setmetatable({}, { __mode = "k" })
local repository = {}
local equipmentRevision = 0
local nextRequestID = 0

local frame = CreateFrame("Frame")

local function IsSecret(value)
  return issecretvalue and issecretvalue(value)
end

local function Plain(value, depth)
  if IsSecret(value) then
    return "<secret>"
  end
  if type(value) ~= "table" then
    local valueType = type(value)
    if valueType == "string" or valueType == "number" or valueType == "boolean" or value == nil then
      return value
    end
    return tostring(value)
  end
  if depth > 5 then
    return "<depth-limit>"
  end
  local result = {}
  for key, child in pairs(value) do
    result[tostring(key)] = Plain(child, depth + 1)
  end
  return result
end

local function Log(event, fields)
  local row = {
    event = event,
    at = GetTimePreciseSec and GetTimePreciseSec() or GetTime(),
    fields = Plain(fields or {}, 0),
  }
  local log = Phase0TooltipProbeDB.log
  log[#log + 1] = row
  if #log > 2000 then
    table.remove(log, 1)
  end
  if Phase0TooltipProbeDB.debug then
    print("|cffcba6f7P0C|r", event, fields and fields.detail or "")
  end
end

local function StateFor(tooltip)
  local state = tooltipStates[tooltip]
  if not state then
    state = {
      revision = 0,
      key = nil,
      waiterID = nil,
      renderedSignature = nil,
      renderedLineCount = nil,
      hooked = false,
    }
    tooltipStates[tooltip] = state
  end
  if not state.hooked and tooltip.HookScript then
    state.hooked = true
    tooltip:HookScript("OnHide", function(hiddenTooltip)
      local hiddenState = tooltipStates[hiddenTooltip]
      if hiddenState then
        hiddenState.revision = hiddenState.revision + 1
        hiddenState.key = nil
        hiddenState.waiterID = nil
        hiddenState.renderedSignature = nil
        hiddenState.renderedLineCount = nil
        Log("tooltip-hide", {
          tooltip = hiddenTooltip:GetName(),
          revision = hiddenState.revision,
        })
      end
    end)
  end
  return state
end

local function CanonicalItemKey(tooltip, tooltipData)
  if tooltipData and tooltipData.guid and not IsSecret(tooltipData.guid) then
    local guidLink = C_Item.GetItemLinkByGUID(tooltipData.guid)
    if guidLink and not IsSecret(guidLink) then
      return guidLink
    end
  end
  if tooltipData and tooltipData.hyperlink and not IsSecret(tooltipData.hyperlink) then
    return tooltipData.hyperlink
  end
  local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
  if itemLink and not IsSecret(itemLink) then
    return itemLink
  end
  return nil
end

local function RemoveWaiter(entry, waiterID)
  if entry and waiterID then
    entry.waiters[waiterID] = nil
  end
end

local function PublishReady(entry)
  for waiterID, waiter in pairs(entry.waiters) do
    entry.waiters[waiterID] = nil
    local tooltip = waiter.tooltip
    local state = tooltipStates[tooltip]
    if state
        and state.revision == waiter.tooltipRevision
        and state.key == waiter.key
        and tooltip:IsShown() then
      Log("load-publish-refresh", {
        detail = waiter.key,
        requestID = entry.requestID,
        waiterID = waiterID,
        tooltipRevision = state.revision,
      })
      if tooltip.RefreshData then
        tooltip:RefreshData()
      else
        Log("refresh-unsupported", {
          detail = waiter.key,
          tooltipRevision = state.revision,
        })
      end
    else
      Log("stale-result-rejected", {
        detail = waiter.key,
        requestID = entry.requestID,
        waiterID = waiterID,
        expectedRevision = waiter.tooltipRevision,
        actualRevision = state and state.revision,
        actualKey = state and state.key,
      })
    end
  end
end

local function StartLoad(key)
  nextRequestID = nextRequestID + 1
  local entry = {
    key = key,
    requestID = nextRequestID,
    status = "pending",
    waiters = {},
  }
  repository[key] = entry
  Log("load-start", { detail = key, requestID = entry.requestID })

  local item = Item:CreateFromItemLink(key)
  entry.cancel = item:ContinueWithCancelOnItemLoad(function()
    if repository[key] ~= entry or entry.status ~= "pending" then
      Log("orphan-load-completion", { detail = key, requestID = entry.requestID })
      return
    end
    local itemID = C_Item.GetItemInfoInstant(key)
    local actualItemLevel = C_Item.GetDetailedItemLevelInfo(key)
    local stats = C_Item.GetItemStats(key)
    if itemID and actualItemLevel and stats then
      entry.status = "ready"
      entry.value = {
        itemID = itemID,
        actualItemLevel = actualItemLevel,
        statKeyCount = 0,
      }
      for _ in pairs(stats) do
        entry.value.statKeyCount = entry.value.statKeyCount + 1
      end
      Log("load-ready", {
        detail = key,
        requestID = entry.requestID,
        itemID = itemID,
        itemLevel = actualItemLevel,
      })
    else
      entry.status = "failed"
      entry.failure = "mandatory structured data missing after item-load callback"
      entry.failedAt = GetTime()
      Log("load-failed", { detail = key, requestID = entry.requestID })
    end
    PublishReady(entry)
  end)
  return entry
end

local function Subscribe(tooltip, state, entry)
  if state.waiterID and entry.waiters[state.waiterID] then
    local existing = entry.waiters[state.waiterID]
    if existing.tooltipRevision == state.revision and existing.key == state.key then
      Log("subscribe-duplicate-suppressed", {
        detail = state.key,
        waiterID = state.waiterID,
        tooltipRevision = state.revision,
      })
      return
    end
  end
  if state.waiterID then
    RemoveWaiter(repository[state.key], state.waiterID)
  end
  nextRequestID = nextRequestID + 1
  local waiterID = nextRequestID
  state.waiterID = waiterID
  entry.waiters[waiterID] = {
    tooltip = tooltip,
    tooltipRevision = state.revision,
    key = state.key,
  }
  Log("load-subscribe", {
    detail = state.key,
    requestID = entry.requestID,
    waiterID = waiterID,
    tooltipRevision = state.revision,
  })
end

local function Render(tooltip, state, entry)
  local signature = table.concat({
    state.key,
    tostring(entry.requestID),
    tostring(equipmentRevision),
  }, "|")
  local currentLines = tooltip:NumLines()
  if state.renderedSignature == signature
      and state.renderedLineCount
      and currentLines >= state.renderedLineCount then
    Log("render-duplicate-suppressed", {
      detail = state.key,
      tooltipRevision = state.revision,
      signature = signature,
    })
    return
  end

  local color = NORMAL_FONT_COLOR
  local value = entry.value
  tooltip:AddDoubleLine(
    "P0 tooltip lifecycle",
    string.format("item=%d ilvl=%d rev=%d", value.itemID, value.actualItemLevel, state.revision),
    color.r,
    color.g,
    color.b,
    0.54,
    0.91,
    0.99
  )
  state.renderedSignature = signature
  state.renderedLineCount = tooltip:NumLines()
  state.waiterID = nil
  Log("render", {
    detail = state.key,
    tooltipRevision = state.revision,
    equipmentRevision = equipmentRevision,
    signature = signature,
    lineCount = state.renderedLineCount,
  })
end

local function OnItemTooltip(tooltip, tooltipData)
  local state = StateFor(tooltip)
  local key = CanonicalItemKey(tooltip, tooltipData)
  if not key then
    Log("postcall-no-key", { tooltip = tooltip:GetName() })
    return
  end

  if state.key ~= key then
    if state.waiterID and state.key then
      RemoveWaiter(repository[state.key], state.waiterID)
    end
    state.revision = state.revision + 1
    state.key = key
    state.waiterID = nil
    state.renderedSignature = nil
    state.renderedLineCount = nil
    Log("tooltip-item-change", {
      detail = key,
      tooltip = tooltip:GetName(),
      tooltipRevision = state.revision,
      dataInstanceID = tooltipData and tooltipData.dataInstanceID,
    })
  end

  local entry = repository[key]
  if entry and entry.status == "failed" and GetTime() - (entry.failedAt or 0) >= 1 then
    repository[key] = nil
    entry = nil
    Log("load-retry-enabled", { detail = key, tooltipRevision = state.revision })
  end
  if not entry then
    entry = StartLoad(key)
  end

  if entry.status == "ready" then
    Render(tooltip, state, entry)
  elseif entry.status == "pending" then
    Subscribe(tooltip, state, entry)
  else
    Log("render-safe-failure", {
      detail = key,
      tooltipRevision = state.revision,
      failure = entry.failure,
    })
  end
end

local copyFrame = CreateFrame("Frame", "Phase0TooltipProbeCopyFrame", UIParent, "BackdropTemplate")
copyFrame:SetSize(760, 180)
copyFrame:SetPoint("CENTER")
copyFrame:SetFrameStrata("DIALOG")
copyFrame:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
copyFrame:SetBackdropColor(0, 0, 0, 0.95)
copyFrame:Hide()

local editBox = CreateFrame("EditBox", nil, copyFrame)
editBox:SetMultiLine(true)
editBox:SetAutoFocus(true)
editBox:SetFontObject(ChatFontNormal)
editBox:SetPoint("TOPLEFT", 12, -12)
editBox:SetPoint("BOTTOMRIGHT", -12, 12)
editBox:SetScript("OnEscapePressed", function()
  copyFrame:Hide()
end)

local function StableSerialize(value)
  if type(value) ~= "table" then
    if type(value) == "string" then
      return string.format("%q", value)
    end
    return tostring(value)
  end
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  local output = { "{" }
  for _, key in ipairs(keys) do
    output[#output + 1] = "[" .. StableSerialize(key) .. "]=" .. StableSerialize(value[key]) .. ","
  end
  output[#output + 1] = "}"
  return table.concat(output)
end

local function ShowExport()
  local version, build, buildDate, tocVersion = GetBuildInfo()
  local export = {
    schema = 1,
    client = {
      version = version,
      build = build,
      buildDate = buildDate,
      tocVersion = tocVersion,
      locale = GetLocale(),
    },
    equipmentRevision = equipmentRevision,
    log = Phase0TooltipProbeDB.log,
    marks = Phase0TooltipProbeDB.marks,
  }
  editBox:SetText("return " .. StableSerialize(export))
  editBox:HighlightText()
  copyFrame:Show()
  editBox:SetFocus()
end

SLASH_PHASE0TOOLTIPPROBE1 = "/p0c"
SlashCmdList.PHASE0TOOLTIPPROBE = function(message)
  local command, rest = message:match("^(%S+)%s*(.-)%s*$")
  command = command and command:lower() or "help"
  if command == "debug" then
    Phase0TooltipProbeDB.debug = rest:lower() ~= "off"
    print("P0C debug", Phase0TooltipProbeDB.debug and "ON" or "OFF")
  elseif command == "mark" then
    Phase0TooltipProbeDB.marks[#Phase0TooltipProbeDB.marks + 1] = {
      label = rest,
      at = GetTimePreciseSec and GetTimePreciseSec() or GetTime(),
      logIndex = #Phase0TooltipProbeDB.log,
    }
    print("P0C marked", rest)
  elseif command == "export" then
    ShowExport()
  elseif command == "clear" then
    Phase0TooltipProbeDB.log = {}
    Phase0TooltipProbeDB.marks = {}
    print("P0C log cleared")
  elseif command == "stats" then
    local count = 0
    for _ in pairs(repository) do
      count = count + 1
    end
    print("P0C log rows", #Phase0TooltipProbeDB.log, "repository entries", count, "equipment revision", equipmentRevision)
  else
    print("|cffcba6f7Phase0TooltipProbe commands:|r")
    print("/p0c debug on|off")
    print("/p0c mark <bags|equipped|character|chat|loot|merchant|journal|comparison>")
    print("/p0c stats | export | clear")
  end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("SOCKET_INFO_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local loadedAddon = ...
    if loadedAddon ~= addonName then
      return
    end
    Phase0TooltipProbeDB = Phase0TooltipProbeDB or {}
    Phase0TooltipProbeDB.schema = 1
    Phase0TooltipProbeDB.debug = Phase0TooltipProbeDB.debug ~= false
    Phase0TooltipProbeDB.log = Phase0TooltipProbeDB.log or {}
    Phase0TooltipProbeDB.marks = Phase0TooltipProbeDB.marks or {}
    Log("addon-loaded", { detail = select(2, GetBuildInfo()) })
  else
    equipmentRevision = equipmentRevision + 1
    Log("equipment-revision", { detail = event, equipmentRevision = equipmentRevision })
    for tooltip, state in pairs(tooltipStates) do
      if state.key and tooltip:IsShown() and tooltip.RefreshData then
        tooltip:RefreshData()
      end
    end
  end
end)
