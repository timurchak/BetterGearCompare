local _, BGA = ...

BGA.Core = BGA.Core or {}

local TableUtil = {}
BGA.Core.TableUtil = TableUtil

function TableUtil.CopyArray(source)
    local copy = {}
    for index = 1, #(source or {}) do
        copy[index] = source[index]
    end
    return copy
end

function TableUtil.ShallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

function TableUtil.DeepCopy(source, seen)
    if type(source) ~= "table" then
        return source
    end

    seen = seen or {}
    if seen[source] then
        return seen[source]
    end

    local copy = {}
    seen[source] = copy
    for key, value in pairs(source) do
        copy[TableUtil.DeepCopy(key, seen)] = TableUtil.DeepCopy(value, seen)
    end
    return copy
end

function TableUtil.ArrayContains(values, expected)
    for index = 1, #(values or {}) do
        if values[index] == expected then
            return true
        end
    end
    return false
end
