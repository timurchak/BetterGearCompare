local _, ns = ...

ns.Options = {
  selectedSpecID = nil,
}

local Constants = ns.Constants
local L = ns.L

local function CreateLabel(parent, text, fontObject)
  local label = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormal")
  label:SetText(text)
  label:SetJustifyH("LEFT")
  return label
end

local function CreateEditBox(parent, width)
  local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  editBox:SetSize(width, 24)
  editBox:SetAutoFocus(false)
  return editBox
end

local function FormatWeight(value)
  local formatted = string.format("%.2f", value)
  formatted = formatted:gsub("%.?0+$", "")
  if formatted == "" then
    return "0"
  end
  return formatted
end

local function GetSelectedSpecID()
  ns.Options.selectedSpecID = ns.Options.selectedSpecID or ns.DB:GetCurrentSpecID()
  return ns.Options.selectedSpecID
end

local function RefreshDropdown(dropdown, values, selectedValue, onSelect)
  UIDropDownMenu_Initialize(dropdown, function(_, level)
    for _, entry in ipairs(values) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.text
      info.checked = entry.value == selectedValue
      info.func = function()
        UIDropDownMenu_SetSelectedValue(dropdown, entry.value)
        UIDropDownMenu_SetSelectedName(dropdown, entry.text)
        onSelect(entry.value)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  UIDropDownMenu_SetWidth(dropdown, 180)

  for _, entry in ipairs(values) do
    if entry.value == selectedValue then
      UIDropDownMenu_SetSelectedValue(dropdown, entry.value)
      UIDropDownMenu_SetSelectedName(dropdown, entry.text)
      break
    end
  end
end

local function BuildPanel(panel)
  if panel.bgcBuilt then
    return
  end

  panel.name = Constants.settingsCategoryName

  local title = CreateLabel(panel, L.ADDON_NAME, "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 18, -18)

  local subtitle = CreateLabel(panel, L.ADDON_DESCRIPTION, "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetWidth(760)

  local specLabel = CreateLabel(panel, L.SETTINGS_SPEC)
  specLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -22)

  local specDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
  specDropdown:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", -16, -2)
  panel.specDropdown = specDropdown

  local profileLabel = CreateLabel(panel, L.SETTINGS_PROFILE)
  profileLabel:SetPoint("TOPLEFT", specDropdown, "BOTTOMLEFT", 16, -18)

  local profileDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
  profileDropdown:SetPoint("TOPLEFT", profileLabel, "BOTTOMLEFT", -16, -2)
  panel.profileDropdown = profileDropdown

  local profileNameLabel = CreateLabel(panel, L.SETTINGS_PROFILE_NAME)
  profileNameLabel:SetPoint("TOPLEFT", profileDropdown, "BOTTOMLEFT", 16, -18)

  local profileNameBox = CreateEditBox(panel, 220)
  profileNameBox:SetPoint("TOPLEFT", profileNameLabel, "BOTTOMLEFT", 0, -6)
  panel.profileNameBox = profileNameBox

  local saveButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  saveButton:SetSize(100, 24)
  saveButton:SetPoint("LEFT", profileNameBox, "RIGHT", 10, 0)
  saveButton:SetText(L.SETTINGS_SAVE)
  panel.saveButton = saveButton

  local deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  deleteButton:SetSize(100, 24)
  deleteButton:SetPoint("LEFT", saveButton, "RIGHT", 8, 0)
  deleteButton:SetText(L.SETTINGS_DELETE)
  panel.deleteButton = deleteButton

  local rows = {}
  local anchor = profileNameBox
  for _, stat in ipairs(Constants.statDefinitions) do
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(420, 24)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, anchor == profileNameBox and -18 or -10)
    anchor = row

    local label = CreateLabel(row, stat.label)
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(150)

    local input = CreateEditBox(row, 80)
    input:SetPoint("LEFT", label, "RIGHT", 18, 0)
    input:SetNumeric(false)

    rows[#rows + 1] = {
      statKey = stat.key,
      input = input,
    }
  end
  panel.statRows = rows

  local note = CreateLabel(panel, L.SETTINGS_NOTE, "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
  note:SetWidth(760)

  saveButton:SetScript("OnClick", function()
    local specID = GetSelectedSpecID()
    local name = strtrim(profileNameBox:GetText() or "")
    if name == "" then
      UIErrorsFrame:AddMessage(L.ERROR_ENTER_PROFILE_NAME, 1, 0.15, 0.15)
      return
    end

    local weights = {}
    for _, row in ipairs(panel.statRows) do
      weights[row.statKey] = ns.Stats:SanitizeWeight(row.input:GetText())
    end

    ns.DB:SaveProfile(name, weights)
    ns.DB:SetProfileForSpec(specID, name)
    ns.Options:Refresh()
    ns.Icons:Refresh()
  end)

  deleteButton:SetScript("OnClick", function()
    local profileName = ns.DB:GetProfileNameForSpec(GetSelectedSpecID())
    if not ns.DB:DeleteProfile(profileName) then
      UIErrorsFrame:AddMessage(L.ERROR_DEFAULT_PROFILE_DELETE, 1, 0.15, 0.15)
      return
    end

    ns.Options:Refresh()
    ns.Icons:Refresh()
  end)

  for _, row in ipairs(panel.statRows) do
    local function SaveInput()
      local specID = GetSelectedSpecID()
      local profileName = ns.DB:GetProfileNameForSpec(specID)
      local profile = ns.DB:GetProfile(profileName)
      local value = ns.Stats:SanitizeWeight(row.input:GetText())
      profile.weights[row.statKey] = value
      row.input:SetText(FormatWeight(value))
      ns.Icons:Refresh()
    end

    row.input:SetScript("OnEnterPressed", function(self)
      SaveInput()
      self:ClearFocus()
    end)
    row.input:SetScript("OnEditFocusLost", SaveInput)
  end

  panel.bgcBuilt = true
end

function ns.Options:Refresh()
  local panel = self.panel
  if not panel or not panel.bgcBuilt then
    return
  end

  local specs = {}
  for _, spec in ipairs(ns.DB:GetSpecializations()) do
    specs[#specs + 1] = {
      text = spec.name,
      value = spec.id,
    }
  end

  local selectedSpecID = GetSelectedSpecID()
  RefreshDropdown(panel.specDropdown, specs, selectedSpecID, function(specID)
    self.selectedSpecID = specID
    self:Refresh()
  end)

  local profiles = {}
  for _, profileName in ipairs(ns.DB:GetProfileNames()) do
    profiles[#profiles + 1] = {
      text = profileName,
      value = profileName,
    }
  end

  local currentProfileName = ns.DB:GetProfileNameForSpec(selectedSpecID)
  RefreshDropdown(panel.profileDropdown, profiles, currentProfileName, function(profileName)
    ns.DB:SetProfileForSpec(selectedSpecID, profileName)
    self:Refresh()
    ns.Icons:Refresh()
  end)

  panel.profileNameBox:SetText(currentProfileName)

  local weights = ns.DB:GetWeightsForSpec(selectedSpecID)
  for _, row in ipairs(panel.statRows) do
    local value = weights[row.statKey] or 0
    row.input:SetText(FormatWeight(value))
  end
end

function ns.Options:Open()
  if Settings and Settings.OpenToCategory and self.categoryID then
    Settings.OpenToCategory(self.categoryID)
  end
end

function ns.Options:Init()
  local panel = CreateFrame("Frame")
  panel.name = Constants.settingsCategoryName
  panel:SetScript("OnShow", function(selfFrame)
    BuildPanel(selfFrame)
    ns.Options:Refresh()
  end)

  self.panel = panel

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, Constants.settingsCategoryName)
    Settings.RegisterAddOnCategory(category)
    self.categoryID = category:GetID()
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end

  SLASH_BETTERGEARCOMPARE1 = "/bgc"
  SlashCmdList.BETTERGEARCOMPARE = function()
    ns.Options:Open()
  end

  SLASH_BETTERGEARCOMPAREDEBUG1 = "/bgcdebug"
  SlashCmdList.BETTERGEARCOMPAREDEBUG = function(message)
    local command = strlower(strtrim(message or ""))
    local enabled

    if command == "on" or command == "1" then
      enabled = true
    elseif command == "off" or command == "0" then
      enabled = false
    else
      enabled = not ns:IsDebugEnabled()
    end

    ns:SetDebugEnabled(enabled)

    if enabled then
      print(L.DEBUG_ENABLED)
    else
      print(L.DEBUG_DISABLED)
    end
  end
end
