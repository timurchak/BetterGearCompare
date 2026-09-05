local addonName, ns = ...

local Probe = {}
ns.Probe = Probe

local CATEGORY_NAMES = {
  armor = true,
  ring = true,
  neck = true,
  socketed = true,
  crafted = true,
  ["old-season"] = true,
  ["upgrade-like-ineligible"] = true,
}

local bonusByID = {}
for _, group in ipairs(ns.Manifest.groups) do
  for _, rank in ipairs(group.ranks) do
    bonusByID[rank.bonusID] = {
      group = group,
      rank = rank,
    }
  end
end

local frame = CreateFrame("Frame")
local requestGeneration = 0
local lastHoveredLink

local function ErrorWithStack(errorMessage)
  local stack = debugstack and debugstack(2, 12, 12) or ""
  return tostring(errorMessage) .. "\n" .. stack
end

local function IsSecret(value)
  return issecretvalue and issecretvalue(value)
end

local function SafeValue(value)
  if IsSecret(value) then
    return "<secret>"
  end
  local valueType = type(value)
  if valueType == "string" or valueType == "number" or valueType == "boolean" or value == nil then
    return value
  end
  return tostring(value)
end

local function PlainCopy(value, seen, depth)
  if IsSecret(value) then
    return "<secret>"
  end
  if type(value) ~= "table" then
    return SafeValue(value)
  end
  if depth > 8 then
    return "<depth-limit>"
  end
  seen = seen or {}
  if seen[value] then
    return "<cycle>"
  end
  seen[value] = true
  local copy = {}
  for key, child in pairs(value) do
    local cleanKey = SafeValue(key)
    copy[cleanKey] = PlainCopy(child, seen, depth + 1)
  end
  seen[value] = nil
  return copy
end

local function JsonEscape(value)
  return value:gsub("[\\\"\b\f\n\r\t]", {
    ["\\"] = "\\\\",
    ["\""] = "\\\"",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
  }):gsub("[%z\1-\31]", function(character)
    return string.format("\\u%04x", string.byte(character))
  end)
end

local function IsArray(value)
  local count = 0
  local maximum = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false, 0
    end
    count = count + 1
    maximum = math.max(maximum, key)
  end
  return count == maximum, maximum
end

local function EncodeJson(value)
  if value == nil then
    return "null"
  end
  local valueType = type(value)
  if valueType == "boolean" then
    return value and "true" or "false"
  elseif valueType == "number" then
    return tostring(value)
  elseif valueType == "string" then
    return "\"" .. JsonEscape(value) .. "\""
  elseif valueType ~= "table" then
    return "\"" .. JsonEscape(tostring(value)) .. "\""
  end

  local array, size = IsArray(value)
  local output = {}
  if array then
    for index = 1, size do
      output[index] = EncodeJson(value[index])
    end
    return "[" .. table.concat(output, ",") .. "]"
  end

  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = tostring(key)
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    output[#output + 1] = EncodeJson(key) .. ":" .. EncodeJson(value[key])
  end
  return "{" .. table.concat(output, ",") .. "}"
end

local function Debug(event, fields)
  local entry = {
    event = event,
    at = GetTimePreciseSec and GetTimePreciseSec() or GetTime(),
    fields = PlainCopy(fields or {}, {}, 0),
  }
  local log = Phase0UpgradeProbeDB.log
  log[#log + 1] = entry
  if #log > 500 then
    table.remove(log, 1)
  end
  print("|cff8be9fdP0A|r", event, fields and fields.detail or "")
end

local function SplitPreservingEmpty(text, delimiter)
  local parts = {}
  local startAt = 1
  while true do
    local delimiterAt = string.find(text, delimiter, startAt, true)
    if not delimiterAt then
      parts[#parts + 1] = string.sub(text, startAt)
      return parts
    end
    parts[#parts + 1] = string.sub(text, startAt, delimiterAt - 1)
    startAt = delimiterAt + #delimiter
  end
end

local function ParseItemPayload(itemLink)
  local payload = itemLink and itemLink:match("(item:[%-?%d:]+)")
  if not payload then
    return nil, "missing numeric item payload"
  end
  local parts = SplitPreservingEmpty(payload, ":")
  local count = tonumber(parts[14])
  if not count or count < 0 or count > 200 then
    return nil, "invalid numBonusIDs field"
  end
  local bonuses = {}
  for index = 15, 14 + count do
    local bonusID = tonumber(parts[index])
    if not bonusID then
      return nil, "nonnumeric bonus ID"
    end
    bonuses[#bonuses + 1] = { id = bonusID, partIndex = index }
  end
  return {
    payload = payload,
    parts = parts,
    bonuses = bonuses,
  }
end

local function FindUpgradeBonus(parsed)
  local found
  for _, bonus in ipairs(parsed.bonuses) do
    local known = bonusByID[bonus.id]
    if known then
      if found then
        return nil, "multiple current-season rank bonuses"
      end
      found = {
        bonusID = bonus.id,
        partIndex = bonus.partIndex,
        group = known.group,
        rank = known.rank,
      }
    end
  end
  return found
end

local function ReplaceBonus(parsed, partIndex, bonusID)
  local parts = {}
  for index, value in ipairs(parsed.parts) do
    parts[index] = value
  end
  parts[partIndex] = tostring(bonusID)
  return table.concat(parts, ":")
end

local function FindOwnedLocation(itemLink)
  for slotID = 1, 19 do
    if GetInventoryItemLink("player", slotID) == itemLink then
      return ItemLocation:CreateFromEquipmentSlot(slotID)
    end
  end
  for bagID = 0, NUM_BAG_SLOTS or 4 do
    local slots = C_Container.GetContainerNumSlots(bagID)
    for slotID = 1, slots do
      if C_Container.GetContainerItemLink(bagID, slotID) == itemLink then
        return ItemLocation:CreateFromBagAndSlot(bagID, slotID)
      end
    end
  end
  return nil
end

local function CaptureSockets(itemLink)
  local sockets = {
    total = C_Item.GetItemNumSockets(itemLink),
    added = C_Item.GetItemNumAddedSockets(itemLink),
    gems = {},
  }
  local maximum = math.max(sockets.total or 0, 4)
  for index = 1, maximum do
    local gemID = C_Item.GetItemGemID(itemLink, index)
    if gemID then
      sockets.gems[#sockets.gems + 1] = { index = index, gemID = gemID }
    end
  end
  return sockets
end

local function CaptureSnapshot(itemLink, location)
  local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = C_Item.GetItemInfoInstant(itemLink)
  local actualItemLevel, previewLevel, sparseItemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
  local effectiveItemLevel
  local itemGUID
  local inventoryType
  local currentlyUpgradeable
  if location and location:IsValid() then
    effectiveItemLevel = C_Item.GetCurrentItemLevel(location)
    itemGUID = C_Item.GetItemGUID(location)
    inventoryType = C_Item.GetItemInventoryType(location)
    currentlyUpgradeable = C_ItemUpgrade.CanUpgradeItem(location) and true or false
  end
  inventoryType = inventoryType or C_Item.GetItemInventoryTypeByID(itemLink)
  local upgradeInfo = C_Item.GetItemUpgradeInfo(itemLink)
  return {
    itemID = itemID,
    fullItemLink = itemLink,
    itemGUID = itemGUID,
    currentItemLevel = actualItemLevel,
    effectiveItemLevel = effectiveItemLevel,
    previewLevel = previewLevel,
    sparseItemLevel = sparseItemLevel,
    itemType = itemType,
    itemSubType = itemSubType,
    itemEquipLoc = itemEquipLoc,
    inventoryType = inventoryType,
    icon = icon,
    classID = classID,
    subclassID = subclassID,
    stats = PlainCopy(C_Item.GetItemStats(itemLink) or {}, {}, 0),
    sockets = CaptureSockets(itemLink),
    upgradeInfo = PlainCopy(upgradeInfo or {}, {}, 0),
    currentlyUpgradeable = currentlyUpgradeable,
  }
end

local function MatchVendorValues(projectedStats, vendorLevelStats)
  if not vendorLevelStats then
    return nil, nil
  end
  local available = {}
  for key, value in pairs(projectedStats or {}) do
    if type(value) == "number" and value ~= 0 then
      available[#available + 1] = { key = key, value = value, used = false }
    end
  end
  local mismatches = {}
  for _, vendorStat in ipairs(vendorLevelStats) do
    if vendorStat.active and type(vendorStat.statValue) == "number" then
      local match
      for _, candidate in ipairs(available) do
        if not candidate.used and candidate.value == vendorStat.statValue then
          match = candidate
          break
        end
      end
      if match then
        match.used = true
      else
        mismatches[#mismatches + 1] = {
          statValue = vendorStat.statValue,
          displayString = vendorStat.displayString,
        }
      end
    end
  end
  return #mismatches == 0, mismatches
end

local function CaptureVendorExpectedStats(vendorLevelStats)
  local expected = {}
  for _, vendorStat in ipairs(vendorLevelStats or {}) do
    if vendorStat.active and type(vendorStat.statValue) == "number" then
      expected[#expected + 1] = {
        statValue = vendorStat.statValue,
        statID = vendorStat.statID,
        statType = vendorStat.statType,
        displayString = vendorStat.displayString,
      }
    end
  end
  return expected
end

local function FindVendorLevel(vendorInfo, rank)
  if not vendorInfo or not vendorInfo.upgradeLevelInfos then
    return nil
  end
  for _, level in ipairs(vendorInfo.upgradeLevelInfos) do
    if level.upgradeLevel == rank then
      return level
    end
  end
  return nil
end

local function CompleteCapture(capture)
  if capture.generation ~= requestGeneration then
    Debug("capture-stale", { detail = tostring(capture.generation) })
    return
  end
  if capture.complete then
    Debug("capture-duplicate-completion-suppressed", { detail = capture.fixtureID })
    return
  end
  capture.completedAt = date("!%Y-%m-%dT%H:%M:%SZ")
  capture.complete = true
  local fixture = {
    fixtureID = capture.fixtureID,
    category = capture.category,
    capture = capture,
  }
  Phase0UpgradeProbeDB.captures[#Phase0UpgradeProbeDB.captures + 1] = fixture
  Phase0UpgradeProbeDB.lastExport = EncodeJson(fixture)
  Debug("capture-complete", {
    detail = capture.fixtureID,
    projections = #capture.projections,
  })
end

local function Capture(itemLink, location, category, vendorInfo)
  if not itemLink then
    print("|cffff5555P0A: no item link|r")
    return
  end
  if not CATEGORY_NAMES[category] then
    print("|cffff5555P0A: category required; see /p0a help|r")
    return
  end

  requestGeneration = requestGeneration + 1
  local generation = requestGeneration
  local item = Item:CreateFromItemLink(itemLink)
  local sourceLoadFinished = false
  Debug("load-start", { detail = itemLink, generation = generation })
  item:ContinueOnItemLoad(function()
    sourceLoadFinished = true
    local ok, errorMessage = xpcall(function()
      if generation ~= requestGeneration then
        Debug("source-load-stale", { detail = itemLink, generation = generation })
        return
      end
      Debug("source-load-ready", { detail = itemLink, generation = generation })
      location = location or FindOwnedLocation(itemLink)
      local parsed, parseError = ParseItemPayload(itemLink)
      local upgradeBonus, bonusError = parsed and FindUpgradeBonus(parsed) or nil
      local version, build, buildDate, tocVersion = GetBuildInfo()
      local capture = {
      schema = 1,
      fixtureID = string.format("%s-%s-%d", category, tostring(C_Item.GetItemInfoInstant(itemLink) or "unknown"), time()),
      category = category,
      generation = generation,
      capturedAt = date("!%Y-%m-%dT%H:%M:%SZ"),
      client = {
        version = version,
        build = build,
        buildDate = buildDate,
        tocVersion = tocVersion,
        locale = GetLocale(),
      },
      manifest = PlainCopy(ns.Manifest, {}, 0),
      tooltipParsingUsed = false,
      parseError = parseError or bonusError,
      allBonusIDs = {},
      projections = {},
      vendorObservation = PlainCopy(vendorInfo, {}, 0),
      source = CaptureSnapshot(itemLink, location),
    }
      capture.fixtureID = capture.fixtureID
      if parsed then
        for _, bonus in ipairs(parsed.bonuses) do
          capture.allBonusIDs[#capture.allBonusIDs + 1] = bonus.id
        end
      end
      if upgradeBonus then
        capture.source.upgradeBonusID = upgradeBonus.bonusID
        capture.source.upgradeGroupID = upgradeBonus.group.groupID
        capture.source.manifestTrack = upgradeBonus.group.track
        capture.source.manifestRank = upgradeBonus.rank.rank
        capture.source.manifestMaxRank = #upgradeBonus.group.ranks
      end

      local shouldProject = upgradeBonus
        and category ~= "old-season"
        and category ~= "upgrade-like-ineligible"
        and capture.source.currentlyUpgradeable ~= false

      if not shouldProject then
        CompleteCapture(capture)
        return
      end

      local targets = {}
      for _, target in ipairs(upgradeBonus.group.ranks) do
        if target.rank > upgradeBonus.rank.rank then
          targets[#targets + 1] = target
        end
      end

      -- Determine the complete fan-out before subscribing. Item callbacks may run
      -- synchronously when their records are already cached.
      local pending = #targets
      for _, target in ipairs(targets) do
          local projectedKey = ReplaceBonus(parsed, upgradeBonus.partIndex, target.bonusID)
          local projection = {
          targetRank = target.rank,
          targetBonusID = target.bonusID,
          expectedItemLevel = target.itemLevel,
          projectedItemKey = projectedKey,
          sourceBonusPartIndex = upgradeBonus.partIndex,
          sourceOtherBonusIDs = PlainCopy(capture.allBonusIDs, {}, 0),
        }
          capture.projections[#capture.projections + 1] = projection
          local projectedItem = Item:CreateFromItemLink(projectedKey)
          projectedItem:ContinueOnItemLoad(function()
          if generation ~= requestGeneration then
            Debug("projection-load-stale", { detail = projectedKey, generation = generation })
            return
          end
          local projectedSnapshot = CaptureSnapshot(projectedKey, nil)
          projection.projectedFullItemLink = select(2, C_Item.GetItemInfo(projectedKey)) or projectedKey
          projection.projectedItemLevel = projectedSnapshot.currentItemLevel
          projection.projectedStats = projectedSnapshot.stats
          projection.projectedSockets = projectedSnapshot.sockets
          projection.itemLevelMatched = projection.projectedItemLevel == projection.expectedItemLevel

          local vendorLevel = FindVendorLevel(vendorInfo, target.rank)
          if vendorLevel then
            projection.authoritativeExpectedSource = "upgrade-vendor"
            projection.vendorLevel = PlainCopy(vendorLevel, {}, 0)
            projection.expectedStats = CaptureVendorExpectedStats(vendorLevel.levelStats)
            projection.vendorStatValuesMatched, projection.vendorStatMismatches = MatchVendorValues(
              projection.projectedStats,
              vendorLevel.levelStats
            )
            projection.statMismatches = PlainCopy(projection.vendorStatMismatches or {}, {}, 0)
          end
          projection.statsVerified = projection.vendorStatValuesMatched == true
          projection.verified = projection.itemLevelMatched and projection.statsVerified
          pending = pending - 1
          Debug("projection-load-end", {
            detail = string.format("rank=%d ilvl=%s verified=%s", target.rank, tostring(projection.projectedItemLevel), tostring(projection.verified)),
            generation = generation,
          })
          if pending == 0 then
            CompleteCapture(capture)
          end
          end)
      end
      if pending == 0 then
        CompleteCapture(capture)
      end
    end, ErrorWithStack)
    if not ok then
      Debug("source-callback-error", {
        detail = errorMessage,
        generation = generation,
      })
      print("|cffff5555P0A callback error:|r", errorMessage)
    end
  end)
  C_Timer.After(8, function()
    if generation == requestGeneration and not sourceLoadFinished then
      Debug("source-load-timeout", { detail = itemLink, generation = generation })
      print("|cffff5555P0A load timeout:|r item data callback did not fire within 8 seconds")
    end
  end)
end

local copyFrame = CreateFrame("Frame", "Phase0UpgradeProbeCopyFrame", UIParent, "BackdropTemplate")
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

local function ShowExport(index)
  local capture = index and Phase0UpgradeProbeDB.captures[index] or nil
  local payload = capture and EncodeJson(capture) or Phase0UpgradeProbeDB.lastExport
  editBox:SetText(payload or "No completed capture yet")
  editBox:HighlightText()
  copyFrame:Show()
  editBox:SetFocus()
end

local function ListCaptures()
  if #Phase0UpgradeProbeDB.captures == 0 then
    print("P0A: no completed captures")
    return
  end
  for index, fixture in ipairs(Phase0UpgradeProbeDB.captures) do
    print(string.format(
      "P0A capture %d: %s %s",
      index,
      tostring(fixture.category),
      tostring(fixture.fixtureID)
    ))
  end
end

local function CaptureVendor(category)
  local itemLink = C_ItemUpgrade.GetItemHyperlink()
  local vendorInfo = C_ItemUpgrade.GetItemUpgradeItemInfo()
  if not itemLink or not vendorInfo then
    print("|cffff5555P0A: select an item in Blizzard's upgrade frame first|r")
    return
  end
  Capture(itemLink, FindOwnedLocation(itemLink), category, vendorInfo)
end

local function Help()
  print("|cff8be9fdPhase0UpgradeProbe commands:|r")
  print("/p0a hover <category>")
  print("/p0a link <category> <item link>")
  print("/p0a equipped <category> <slotID>")
  print("/p0a bag <category> <bagID> <slotID>")
  print("/p0a vendor <category>  -- selected Blizzard upgrade-frame item")
  print("/p0a list | export [captureNumber] | clear | help")
end

SLASH_PHASE0UPGRADEPROBE1 = "/p0a"
SlashCmdList.PHASE0UPGRADEPROBE = function(message)
  local command, rest = message:match("^(%S+)%s*(.-)%s*$")
  command = command and command:lower() or "help"
  if command == "hover" then
    Capture(lastHoveredLink, nil, rest)
  elseif command == "link" then
    local category, link = rest:match("^(%S+)%s+(.+)$")
    Capture(link, nil, category)
  elseif command == "equipped" then
    local category, slotText = rest:match("^(%S+)%s+(%d+)$")
    local slotID = tonumber(slotText)
    local link = slotID and GetInventoryItemLink("player", slotID)
    local location = slotID and ItemLocation:CreateFromEquipmentSlot(slotID)
    Capture(link, location, category)
  elseif command == "bag" then
    local category, bagText, slotText = rest:match("^(%S+)%s+([%-]?%d+)%s+(%d+)$")
    local bagID = tonumber(bagText)
    local slotID = tonumber(slotText)
    local link = bagID and slotID and C_Container.GetContainerItemLink(bagID, slotID)
    local location = bagID and slotID and ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    Capture(link, location, category)
  elseif command == "vendor" then
    CaptureVendor(rest)
  elseif command == "export" then
    ShowExport(tonumber(rest))
  elseif command == "list" then
    ListCaptures()
  elseif command == "clear" then
    Phase0UpgradeProbeDB.captures = {}
    Phase0UpgradeProbeDB.log = {}
    Phase0UpgradeProbeDB.lastExport = nil
    print("P0A: fixtures cleared")
  else
    Help()
  end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
  -- ShoppingTooltip1/2 are rendered automatically after the primary tooltip and
  -- must not replace the item the user actually hovered.
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
    return
  end
  local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
  if itemLink then
    lastHoveredLink = itemLink
  end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
  if event == "ADDON_LOADED" and loadedAddon == addonName then
    Phase0UpgradeProbeDB = Phase0UpgradeProbeDB or {}
    Phase0UpgradeProbeDB.schema = 1
    Phase0UpgradeProbeDB.captures = Phase0UpgradeProbeDB.captures or {}
    Phase0UpgradeProbeDB.log = Phase0UpgradeProbeDB.log or {}
    Debug("addon-loaded", { detail = ns.Manifest.wowBuild })
    Help()
  end
end)
