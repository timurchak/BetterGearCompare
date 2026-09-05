local _, BGA = ...

BGA.Presentation = BGA.Presentation or {}

local DebugPresenter = {}
BGA.Presentation.DebugPresenter = DebugPresenter

function DebugPresenter.Summary(diagnostics)
    local export = diagnostics:Export()
    local parts = { "Better Gear Advisor diagnostics" }
    for event, count in pairs(export.counters) do
        parts[#parts + 1] = event .. "=" .. count
    end
    table.sort(parts)
    return table.concat(parts, " | ")
end
