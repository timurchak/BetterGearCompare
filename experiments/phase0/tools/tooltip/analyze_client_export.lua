-- Analyze a `return {...}` export produced by Phase0TooltipProbe.
-- Usage: lua analyze_client_export.lua EXPORT.lua TAINT.log REPORT.json

local exportPath = assert(arg[1], "missing export path")
local taintPath = assert(arg[2], "missing taint log path")
local reportPath = assert(arg[3], "missing report path")
local data = assert(dofile(exportPath))

local function escape(value)
  return value:gsub('[\\"\b\f\n\r\t]', {
    ['\\'] = '\\\\', ['"'] = '\\"', ['\b'] = '\\b', ['\f'] = '\\f',
    ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
  }):gsub('[%z\1-\31]', function(character)
    return string.format('\\u%04x', string.byte(character))
  end)
end

local function arraySize(value)
  local count, maximum = 0, 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return nil end
    count, maximum = count + 1, math.max(maximum, key)
  end
  return count == maximum and maximum or nil
end

local function encode(value)
  if value == nil then return "null" end
  local kind = type(value)
  if kind == "boolean" then return value and "true" or "false" end
  if kind == "number" then return string.format("%.17g", value) end
  if kind == "string" then return '"' .. escape(value) .. '"' end
  assert(kind == "table", "unsupported JSON value: " .. kind)
  local size = arraySize(value)
  if size then
    local rows = {}
    for index = 1, size do rows[index] = encode(value[index]) end
    return "[" .. table.concat(rows, ",") .. "]"
  end
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
  local rows = {}
  for _, key in ipairs(keys) do
    rows[#rows + 1] = encode(tostring(key)) .. ":" .. encode(value[key])
  end
  return "{" .. table.concat(rows, ",") .. "}"
end

local function increment(target, key)
  target[key] = (target[key] or 0) + 1
end

local eventCounts, tooltipCounts = {}, {}
for _, row in ipairs(data.log or {}) do
  increment(eventCounts, row.event)
  if row.fields and row.fields.tooltip then increment(tooltipCounts, row.fields.tooltip) end
end

local segments, labels = {}, {}
for index, mark in ipairs(data.marks or {}) do
  labels[mark.label] = true
  local last = data.marks[index + 1] and data.marks[index + 1].logIndex or #(data.log or {})
  local events, tooltips = {}, {}
  for rowIndex = mark.logIndex + 1, last do
    local row = data.log[rowIndex]
    if row then
      increment(events, row.event)
      if row.fields and row.fields.tooltip then increment(tooltips, row.fields.tooltip) end
    end
  end
  segments[#segments + 1] = {
    label = mark.label,
    rows = last - mark.logIndex,
    events = events,
    tooltips = tooltips,
  }
end

local taintHandle = io.open(taintPath, "rb")
local taint = taintHandle and taintHandle:read("*a") or nil
if taintHandle then taintHandle:close() end
local taintMentionsProbe = taint and (
  taint:find("Phase0TooltipProbe", 1, true) ~= nil
  or taint:find("Phase0UpgradeProbe", 1, true) ~= nil
) or nil
local taintLower = taint and taint:lower() or nil
local blockedProtectedAction = taintLower and (
  taintLower:find("blocked", 1, true) ~= nil
  or taintLower:find("forbidden", 1, true) ~= nil
) or nil
local slashRegistrationMention = taint and taint:find("SLASH_PHASE0", 1, true) ~= nil or nil

local requiredLabels = { "bags", "character", "chat", "comparison" }
local markedRequiredSources = true
for _, label in ipairs(requiredLabels) do
  if not labels[label] then markedRequiredSources = false end
end

local failures = (eventCounts["load-failed"] or 0)
  + (eventCounts["refresh-unsupported"] or 0)
  + (eventCounts["orphan-load-completion"] or 0)
local checks = {
  targetBuild = data.client and data.client.build == "69587",
  markedRequiredSources = markedRequiredSources,
  itemRefTooltipObserved = (tooltipCounts.ItemRefTooltip or 0) > 0,
  shoppingTooltipsObserved = (tooltipCounts.ShoppingTooltip1 or 0) > 0
    and (tooltipCounts.ShoppingTooltip2 or 0) > 0,
  equipmentRefreshObserved = (eventCounts["equipment-revision"] or 0) > 0,
  balancedLoads = (eventCounts["load-start"] or 0) == (eventCounts["load-ready"] or 0),
  noFailureEvents = failures == 0,
  duplicateSuppressionObserved = (eventCounts["render-duplicate-suppressed"] or 0) > 0,
  staleRejectionObserved = (eventCounts["stale-result-rejected"] or 0) > 0,
  asynchronousRefreshObserved = (eventCounts["load-publish-refresh"] or 0) > 0,
  taintLogPresent = taint ~= nil,
  probeTaintMentioned = taintMentionsProbe == true,
  slashRegistrationTaintObserved = slashRegistrationMention == true,
  noBlockedProtectedAction = taint ~= nil and not blockedProtectedAction,
}

local report = {
  schema = 1,
  verdict = checks.staleRejectionObserved and checks.asynchronousRefreshObserved
    and checks.noBlockedProtectedAction and "PASS" or "PARTIAL",
  client = data.client,
  logRows = #(data.log or {}),
  equipmentRevision = data.equipmentRevision,
  eventCounts = eventCounts,
  tooltipCounts = tooltipCounts,
  segments = segments,
  checks = checks,
  taintLogBytes = taint and #taint or nil,
  missingEvidence = {
    not checks.staleRejectionObserved and "live stale callback rejection" or nil,
    not checks.asynchronousRefreshObserved and "live uncached item refresh" or nil,
    not labels.loot and "loot source mark" or nil,
    not labels.merchant and "merchant source mark" or nil,
    not labels.journal and "encounter journal source mark" or nil,
  },
}

-- Remove nil holes from the human-readable missing-evidence list.
local compact = {}
for index = 1, 5 do
  if report.missingEvidence[index] then compact[#compact + 1] = report.missingEvidence[index] end
end
report.missingEvidence = compact

local output = assert(io.open(reportPath, "wb"))
output:write(encode(report), "\n")
output:close()
print(encode(report))
