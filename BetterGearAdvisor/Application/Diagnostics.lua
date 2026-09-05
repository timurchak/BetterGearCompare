local _, BGA = ...

BGA.Application = BGA.Application or {}

local Diagnostics = {}
Diagnostics.__index = Diagnostics
BGA.Application.Diagnostics = Diagnostics

function Diagnostics.New(maxRows)
    return setmetatable({ maxRows = maxRows or 200, rows = {}, counters = {} }, Diagnostics)
end

function Diagnostics:Record(event, fields)
    self.counters[event] = (self.counters[event] or 0) + 1
    self.rows[#self.rows + 1] = { event = event, fields = BGA.Core.TableUtil.DeepCopy(fields or {}) }
    if #self.rows > self.maxRows then
        table.remove(self.rows, 1)
    end
end

function Diagnostics:Export()
    return {
        schema = 1,
        counters = BGA.Core.TableUtil.DeepCopy(self.counters),
        rows = BGA.Core.TableUtil.DeepCopy(self.rows),
    }
end
