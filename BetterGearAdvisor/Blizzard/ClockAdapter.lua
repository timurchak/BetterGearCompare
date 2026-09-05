local _, BGA = ...

BGA.Blizzard = BGA.Blizzard or {}

local ClockAdapter = {}
ClockAdapter.__index = ClockAdapter
BGA.Blizzard.ClockAdapter = ClockAdapter

function ClockAdapter.New(api)
    return setmetatable({ api = api or {} }, ClockAdapter)
end

function ClockAdapter:Now()
    local now = self.api.GetTimePreciseSec or GetTimePreciseSec or self.api.GetTime or GetTime
    return now()
end
