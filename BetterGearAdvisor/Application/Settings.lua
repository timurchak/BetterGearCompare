local _, BGA = ...

BGA.Application = BGA.Application or {}

local Settings = {}
Settings.__index = Settings
BGA.Application.Settings = Settings

function Settings.New(savedVariables)
    savedVariables.schema = 1
    if savedVariables.debug == nil then
        savedVariables.debug = false
    end
    return setmetatable({ values = savedVariables }, Settings)
end

function Settings:IsDebugEnabled()
    return self.values.debug == true
end

function Settings:SetDebugEnabled(enabled)
    self.values.debug = enabled == true
end
