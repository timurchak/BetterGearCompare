local _, ns = ...

local L = ns.L

ns.BisUI = {}

-- Upgrade tracks: fixed at 6/8 for each difficulty tier
-- Bonus IDs sourced from Wowhead bonusOptions for raid items
-- 6/8 = baseBonus + 5
local UPGRADE_TRACKS = {
  { key = "VETERAN",  bonusID = 12782, contextBonus = 13332 }, -- LFR 6/8
  { key = "CHAMPION", bonusID = 12790, contextBonus = nil },   -- Normal 6/8
  { key = "HERO",     bonusID = 12798, contextBonus = 13334 }, -- Heroic 6/8
  { key = "MYTH",     bonusID = 12806, contextBonus = 13335 }, -- Mythic 6/8
}

local selectedTrackIndex = 4 -- Myth by default

local SLOT_ORDER = {
  "Head", "Neck", "Shoulders", "Back", "Chest", "Wrist",
  "Hands", "Waist", "Legs", "Feet", "Ring", "Trinket",
  "Weapon", "Offhand",
}

local CLASS_FROM_SLUG = {
  ["death-knight"] = "DEATHKNIGHT",
  ["demon-hunter"] = "DEMONHUNTER",
  ["druid"] = "DRUID",
  ["evoker"] = "EVOKER",
  ["hunter"] = "HUNTER",
  ["mage"] = "MAGE",
  ["monk"] = "MONK",
  ["paladin"] = "PALADIN",
  ["priest"] = "PRIEST",
  ["rogue"] = "ROGUE",
  ["shaman"] = "SHAMAN",
  ["warlock"] = "WARLOCK",
  ["warrior"] = "WARRIOR",
}

local SPEC_NAMES = {}

local QUALITY_COLORS = {
  [0] = { 0.62, 0.62, 0.62 },
  [1] = { 1, 1, 1 },
  [2] = { 0.12, 1, 0 },
  [3] = { 0, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 },
  [5] = { 1, 0.50, 0 },
}

local ROW_HEIGHT = 28
local HEADER_HEIGHT = 22
local ICON_SIZE = 24
local FRAME_WIDTH = 420
local FRAME_HEIGHT = 550

-- Helpers

local function ItemString(itemID)
  local track = UPGRADE_TRACKS[selectedTrackIndex]
  if track.contextBonus then
    return "item:" .. itemID .. "::::::::::::2:" .. track.bonusID .. ":" .. track.contextBonus
  else
    return "item:" .. itemID .. "::::::::::::1:" .. track.bonusID
  end
end

local function GetClassColor(classSlug)
  local classToken = CLASS_FROM_SLUG[classSlug]
  if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
    return RAID_CLASS_COLORS[classToken]
  end
  return { r = 1, g = 1, b = 1, colorStr = "ffffffff" }
end

local function GetSpecDisplayName(specID, slug)
  if SPEC_NAMES[specID] then
    return SPEC_NAMES[specID]
  end

  -- Try WoW API for localized names
  if GetSpecializationInfoByID then
    local _, specName, _, icon, role, classFile, className = GetSpecializationInfoByID(specID)
    if specName and className then
      local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
      if classColor then
        local colorStr = classColor.colorStr or string.format("ff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        local display = string.format("|c%s%s — %s|r", colorStr, className, specName)
        SPEC_NAMES[specID] = display
        return display
      end
    end
  end

  -- Fallback: build from slug
  local parts = { strsplit("/", slug) }
  local classSlug = parts[1] or ""
  local specSlug = parts[2] or ""

  local className = classSlug:gsub("-", " "):gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest end)
  local specName = specSlug:gsub("-", " "):gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest end)

  local color = GetClassColor(classSlug)
  local colorStr = color.colorStr or string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
  local display = string.format("|c%s%s — %s|r", colorStr, className, specName)

  SPEC_NAMES[specID] = display
  return display
end

-- Scroll Area (based on Midnight-Routine pattern)

local function CreateScrollArea(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -88)
  scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -18, 10)
  scroll:EnableMouseWheel(true)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetWidth(scroll:GetWidth() or (FRAME_WIDTH - 28))
  content:SetHeight(1)
  scroll:SetScrollChild(content)

  local track = CreateFrame("Frame", nil, parent)
  track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, 0)
  track:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 0)
  track:SetWidth(5)

  local trackBg = track:CreateTexture(nil, "BACKGROUND")
  trackBg:SetAllPoints()
  trackBg:SetColorTexture(0, 0, 0, 0.3)

  local thumb = CreateFrame("Button", nil, track)
  thumb:SetWidth(5)
  thumb:EnableMouse(true)
  thumb:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

  local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
  thumbTex:SetAllPoints()
  thumbTex:SetColorTexture(0.24, 0.72, 0.72, 0.8)

  local function UpdateScrollBar()
    local viewH = scroll:GetHeight()
    local contentH = content:GetHeight()
    local maxScroll = math.max(contentH - viewH, 0)
    local currentScroll = scroll:GetVerticalScroll()

    if currentScroll > maxScroll then
      scroll:SetVerticalScroll(maxScroll)
      currentScroll = maxScroll
    elseif currentScroll < 0 then
      scroll:SetVerticalScroll(0)
      currentScroll = 0
    end

    if contentH <= viewH or viewH <= 0 then
      if currentScroll ~= 0 then
        scroll:SetVerticalScroll(0)
      end
      thumb:Hide()
      return
    end

    thumb:Show()
    local trackH = math.max(track:GetHeight(), 1)
    local thumbH = math.max(trackH * (viewH / contentH), 18)
    local pct = currentScroll / math.max(maxScroll, 1)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -((trackH - thumbH) * pct))
  end

  scroll:SetScript("OnMouseWheel", function(_, delta)
    local viewH = scroll:GetHeight()
    local contentH = content:GetHeight()
    local maxScroll = math.max(contentH - viewH, 0)
    local newScroll = math.max(0, math.min(scroll:GetVerticalScroll() - (delta * 30), maxScroll))
    scroll:SetVerticalScroll(newScroll)
    UpdateScrollBar()
  end)

  -- Thumb dragging
  local dragging = false
  local grabOffset = 0

  local function SetScrollFromCursor(cursorY, offset)
    local viewH = scroll:GetHeight()
    local contentH = content:GetHeight()
    local maxScroll = math.max(contentH - viewH, 0)
    if maxScroll <= 0 then return end

    local trackTop = track:GetTop()
    local trackBottom = track:GetBottom()
    if not trackTop or not trackBottom then return end

    local trackH = math.max(trackTop - trackBottom, 1)
    local thumbH = thumb:GetHeight()
    local movable = math.max(trackH - thumbH, 1)
    local y = math.max(0, math.min((trackTop - cursorY) - offset, movable))
    local pct = y / movable
    scroll:SetVerticalScroll(maxScroll * pct)
    UpdateScrollBar()
  end

  thumb:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      if not dragging then
        dragging = true
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / (thumb:GetEffectiveScale() or 1)
        grabOffset = (thumb:GetTop() or 0) - cursorY
        thumb:SetScript("OnUpdate", function()
          local _, cy = GetCursorPosition()
          cy = cy / (thumb:GetEffectiveScale() or 1)
          SetScrollFromCursor(cy, grabOffset)
        end)
      else
        dragging = false
        thumb:SetScript("OnUpdate", nil)
      end
    end
  end)

  scroll.content = content
  scroll.UpdateScrollBar = UpdateScrollBar
  return scroll
end

-- Copy URL Popup

local WOWHEAD_ICON = "Interface\\AddOns\\BetterGearCompare\\Media\\wowhead"

local copyPopup

local function CreateCopyPopup()
  local f = CreateFrame("Frame", "BGCBisCopyPopup", UIParent, "BackdropTemplate")
  f:SetSize(340, 50)
  f:SetFrameStrata("TOOLTIP")
  f:SetClampedToScreen(true)
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.1, 0.1, 0.15, 0.95)
  f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  f:Hide()

  local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
  label:SetText("Ctrl+C to copy:")
  label:SetTextColor(0.6, 0.6, 0.6)

  local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  editBox:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -20)
  editBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 6)
  editBox:SetAutoFocus(true)
  editBox:SetScript("OnEscapePressed", function() f:Hide() end)
  editBox:SetScript("OnEnterPressed", function() f:Hide() end)
  f.editBox = editBox

  f:SetScript("OnShow", function(self)
    self.editBox:SetFocus()
    self.editBox:HighlightText()
  end)

  -- Click outside to close
  f:EnableMouse(true)
  f:SetScript("OnMouseDown", function() end) -- absorb clicks

  return f
end

local function ShowCopyPopup(anchor, itemID, directUrl)
  if not copyPopup then
    copyPopup = CreateCopyPopup()
  end
  local url = directUrl or ("https://www.wowhead.com/item=" .. itemID)
  copyPopup.editBox:SetText(url)
  copyPopup:ClearAllPoints()
  copyPopup:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
  copyPopup:Show()
  copyPopup.editBox:HighlightText()
end

-- Item Rows

local rowPool = {}

local function GetOrCreateRow(parent, index)
  if rowPool[index] then
    return rowPool[index]
  end

  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(ROW_HEIGHT)

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("LEFT", row, "LEFT", 4, 0)
  row.icon = icon

  local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  nameText:SetPoint("RIGHT", row, "CENTER", 40, 0)
  nameText:SetJustifyH("LEFT")
  nameText:SetWordWrap(false)
  row.nameText = nameText

  local sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  sourceText:SetPoint("RIGHT", row, "RIGHT", -24, 0)
  sourceText:SetJustifyH("RIGHT")
  sourceText:SetWordWrap(false)
  sourceText:SetTextColor(0.5, 0.5, 0.5)
  row.sourceText = sourceText

  local whBtn = CreateFrame("Button", nil, row)
  whBtn:SetSize(16, 16)
  whBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
  local whIcon = whBtn:CreateTexture(nil, "ARTWORK")
  whIcon:SetAllPoints()
  whIcon:SetTexture(WOWHEAD_ICON)
  whBtn:SetScript("OnClick", function()
    if row.itemID then
      ShowCopyPopup(whBtn, row.itemID)
    end
  end)
  whBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Open on Wowhead")
    GameTooltip:Show()
  end)
  whBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  row.whBtn = whBtn

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.08)

  row:SetScript("OnEnter", function(self)
    if self.itemID then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(ItemString(self.itemID))
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  rowPool[index] = row
  return row
end

local function GetOrCreateHeader(parent, index)
  local key = "header_" .. index
  if rowPool[key] then
    return rowPool[key]
  end

  local header = CreateFrame("Frame", nil, parent)
  header:SetHeight(HEADER_HEIGHT)

  local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("LEFT", header, "LEFT", 4, 0)
  text:SetTextColor(0.6, 0.6, 0.6)
  header.text = text

  local line = header:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("LEFT", text, "RIGHT", 6, 0)
  line:SetPoint("RIGHT", header, "RIGHT", -4, 0)
  line:SetColorTexture(0.3, 0.3, 0.3, 0.5)

  rowPool[key] = header
  return header
end

-- Main Frame

local mainFrame
local scrollArea
local specDropdown
local selectedSpecID
local pendingItems = {}

local function PopulateItems()
  if not mainFrame or not mainFrame:IsShown() then return end

  local bisData = ns.BisData
  if not bisData or not bisData.specs then return end

  local slug = bisData.specIDs[selectedSpecID]
  if not slug then return end

  local specData = bisData.specs[slug]
  if not specData or not specData.itemsBySlot then return end

  local content = scrollArea.content
  local contentWidth = scrollArea:GetWidth()

  -- Hide all existing rows
  for _, row in pairs(rowPool) do
    row:Hide()
  end

  local yOffset = 0
  local rowIndex = 0
  local headerIndex = 0
  local hasPendingItems = false

  for _, slotName in ipairs(SLOT_ORDER) do
    local items = specData.itemsBySlot[slotName]
    if items and #items > 0 then
      headerIndex = headerIndex + 1
      local header = GetOrCreateHeader(content, headerIndex)
      header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
      header:SetPoint("RIGHT", content, "RIGHT", 0, 0)
      header.text:SetText(slotName)
      header:Show()
      yOffset = yOffset + HEADER_HEIGHT

      for _, entry in ipairs(items) do
        local itemID = entry.itemID
        local source = entry.source or ""
        rowIndex = rowIndex + 1
        local row = GetOrCreateRow(content, rowIndex)
        row.itemID = itemID
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

        local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(ItemString(itemID))

        if itemName then
          row.icon:SetTexture(itemTexture)
          local qc = QUALITY_COLORS[itemQuality] or QUALITY_COLORS[1]
          row.nameText:SetText(itemName)
          row.nameText:SetTextColor(qc[1], qc[2], qc[3])
        else
          row.icon:SetTexture(134400) -- Question mark icon
          row.nameText:SetText("Loading... (ID: " .. itemID .. ")")
          row.nameText:SetTextColor(0.5, 0.5, 0.5)
          pendingItems[itemID] = true
          hasPendingItems = true
        end

        row.sourceText:SetText(source)

        row:Show()
        yOffset = yOffset + ROW_HEIGHT
      end
    end
  end

  content:SetHeight(math.max(yOffset, 1))
  content:SetWidth(contentWidth)

  C_Timer.After(0, function()
    scrollArea.UpdateScrollBar()
  end)

  return hasPendingItems
end

local function OnItemDataLoaded(_, _, itemID)
  if not mainFrame or not mainFrame:IsShown() then return end
  if pendingItems[itemID] then
    pendingItems[itemID] = nil
    PopulateItems()
  end
end

local function BuildSpecEntries()
  local bisData = ns.BisData
  if not bisData or not bisData.specIDs then return {} end

  local entries = {}
  for specID, slug in pairs(bisData.specIDs) do
    table.insert(entries, {
      specID = specID,
      slug = slug,
      display = GetSpecDisplayName(specID, slug),
    })
  end

  table.sort(entries, function(a, b)
    return a.slug < b.slug
  end)

  return entries
end

local function CreateMainFrame()
  local f = CreateFrame("Frame", "BetterGearCompareBisFrame", UIParent, "BackdropTemplate")
  f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)

  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
  f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
  title:SetText("BetterGearCompare — Best in Slot")
  title:SetTextColor(0.35, 0.82, 1)

  -- Close button
  local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

  -- Spec dropdown (left half)
  local halfWidth = math.floor((FRAME_WIDTH - 50) / 2)
  specDropdown = CreateFrame("Frame", "BGCBisSpecDropdown", f, "UIDropDownMenuTemplate")
  specDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -4, -34)

  UIDropDownMenu_SetWidth(specDropdown, halfWidth)
  UIDropDownMenu_Initialize(specDropdown, function(_, level)
    local entries = BuildSpecEntries()
    for _, entry in ipairs(entries) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.display
      info.value = entry.specID
      info.checked = (entry.specID == selectedSpecID)
      info.func = function(self)
        selectedSpecID = self.value
        UIDropDownMenu_SetText(specDropdown, GetSpecDisplayName(selectedSpecID, ns.BisData.specIDs[selectedSpecID]))
        pendingItems = {}
        PopulateItems()
        UpdateGuideLink()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  -- Tier dropdown (right half)
  local tierDropdown = CreateFrame("Frame", "BGCBisTierDropdown", f, "UIDropDownMenuTemplate")
  tierDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", halfWidth + 12, -34)

  UIDropDownMenu_SetWidth(tierDropdown, halfWidth)
  UIDropDownMenu_Initialize(tierDropdown, function(_, level)
    for trackIdx, track in ipairs(UPGRADE_TRACKS) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = L["BIS_TRACK_" .. track.key]
      info.value = trackIdx
      info.checked = (trackIdx == selectedTrackIndex)
      info.func = function(self)
        selectedTrackIndex = self.value
        UIDropDownMenu_SetText(tierDropdown, L["BIS_TRACK_" .. UPGRADE_TRACKS[selectedTrackIndex].key])
        pendingItems = {}
        PopulateItems()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_SetText(tierDropdown, L["BIS_TRACK_" .. UPGRADE_TRACKS[selectedTrackIndex].key])

  -- Guide link row
  local guideLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  guideLabel:SetPoint("LEFT", f, "TOPLEFT", 14, -72)
  guideLabel:SetTextColor(0.6, 0.6, 0.6)

  local guideWhBtn = CreateFrame("Button", nil, f)
  guideWhBtn:SetSize(16, 16)
  guideWhBtn:SetPoint("LEFT", guideLabel, "RIGHT", 4, 0)
  local guideWhIcon = guideWhBtn:CreateTexture(nil, "ARTWORK")
  guideWhIcon:SetAllPoints()
  guideWhIcon:SetTexture(WOWHEAD_ICON)
  guideWhBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["BIS_GUIDE_LINK"])
    GameTooltip:Show()
  end)
  guideWhBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  function UpdateGuideLink()
    local slug = ns.BisData and ns.BisData.specIDs and ns.BisData.specIDs[selectedSpecID]
    local specData = slug and ns.BisData.specs and ns.BisData.specs[slug]
    local url = specData and specData.sourceUrl
    guideLabel:SetText(L["BIS_GUIDE_LINK"])
    if url then
      guideWhBtn:SetScript("OnClick", function()
        ShowCopyPopup(guideWhBtn, nil, url)
      end)
      guideWhBtn:Show()
    else
      guideWhBtn:Hide()
    end
  end

  -- Separator line
  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -82)
  sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -82)
  sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)

  -- Scroll area
  scrollArea = CreateScrollArea(f)

  -- Escape closes
  table.insert(UISpecialFrames, "BetterGearCompareBisFrame")

  -- Event frame for item data loading
  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  eventFrame:SetScript("OnEvent", OnItemDataLoaded)

  f:SetScript("OnShow", function()
    pendingItems = {}
    PopulateItems()
  end)

  f:Hide() -- Start hidden so first Toggle() will Show()

  return f
end

function ns.BisUI:Toggle()
  if not ns.BisData then
    print("BetterGearCompare: No BIS data available.")
    return
  end

  if not mainFrame then
    -- Default to current spec
    local specIndex = GetSpecialization and GetSpecialization() or nil
    if specIndex then
      selectedSpecID = GetSpecializationInfo(specIndex)
    end
    if not selectedSpecID or not ns.BisData.specIDs[selectedSpecID] then
      -- Fallback to first available spec
      for id, _ in pairs(ns.BisData.specIDs) do
        selectedSpecID = id
        break
      end
    end

    mainFrame = CreateMainFrame()
    UIDropDownMenu_SetText(specDropdown, GetSpecDisplayName(selectedSpecID, ns.BisData.specIDs[selectedSpecID]))
    UpdateGuideLink()
  end

  if mainFrame:IsShown() then
    mainFrame:Hide()
  else
    mainFrame:Show()
  end
end
