-- Convert explicitly selected Phase0UpgradeProbe SavedVariables captures to JSON.
-- Usage: lua import_savedvariables.lua INPUT OUTPUT_DIR INDEX=FILE.json [...]

local inputPath = assert(arg[1], "missing SavedVariables input path")
local outputDirectory = assert(arg[2], "missing output directory")
assert(dofile(inputPath) == nil)
assert(type(Phase0UpgradeProbeDB) == "table", "Phase0UpgradeProbeDB is missing")
assert(type(Phase0UpgradeProbeDB.captures) == "table", "captures table is missing")

local function escape(value)
  return value:gsub('[\\"\b\f\n\r\t]', {
    ['\\'] = '\\\\',
    ['"'] = '\\"',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
  }):gsub('[%z\1-\31]', function(character)
    return string.format('\\u%04x', string.byte(character))
  end)
end

local function arraySize(value)
  local count, maximum = 0, 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return nil
    end
    count = count + 1
    maximum = math.max(maximum, key)
  end
  return count == maximum and maximum or nil
end

local function encode(value)
  local valueType = type(value)
  if value == nil then return "null" end
  if valueType == "boolean" then return value and "true" or "false" end
  if valueType == "number" then return string.format("%.17g", value) end
  if valueType == "string" then return '"' .. escape(value) .. '"' end
  if valueType ~= "table" then return '"' .. escape(tostring(value)) .. '"' end

  local size = arraySize(value)
  if size then
    local output = {}
    for index = 1, size do output[index] = encode(value[index]) end
    return "[" .. table.concat(output, ",") .. "]"
  end

  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
  local output = {}
  for _, key in ipairs(keys) do
    output[#output + 1] = encode(tostring(key)) .. ":" .. encode(value[key])
  end
  return "{" .. table.concat(output, ",") .. "}"
end

for argumentIndex = 3, #arg do
  local captureIndexText, fileName = arg[argumentIndex]:match("^(%d+)=(.+%.json)$")
  assert(captureIndexText and fileName, "invalid selection: " .. tostring(arg[argumentIndex]))
  assert(not fileName:find("[\\/]"), "output filename must not contain a path")
  local captureIndex = tonumber(captureIndexText)
  local capture = assert(Phase0UpgradeProbeDB.captures[captureIndex], "missing capture " .. captureIndex)
  local outputPath = outputDirectory .. "/" .. fileName
  local handle = assert(io.open(outputPath, "wb"))
  handle:write(encode(capture), "\n")
  handle:close()
  print(string.format("exported capture %d (%s) -> %s", captureIndex, tostring(capture.category), outputPath))
end

