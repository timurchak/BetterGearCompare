local _, ns = ...

ns.Stats = {}

local Constants = ns.Constants
local GetItemStatsAPI = (C_Item and C_Item.GetItemStats) or GetItemStats

function ns.Stats:GetItemStats(itemLink)
  if not itemLink or not GetItemStatsAPI then
    return nil
  end

  return GetItemStatsAPI(itemLink)
end

function ns.Stats:SanitizeWeight(value)
  local numericValue = tonumber((tostring(value or "0"):gsub(",", ".")))
  if not numericValue then
    return 0
  end

  if numericValue < 0 then
    return 0
  end

  return math.floor(numericValue * 100 + 0.5) / 100
end

function ns.Stats:CalculateScore(itemLink, weights)
  local stats = self:GetItemStats(itemLink)
  if not stats then
    return 0, nil
  end

  local score = 0
  for _, stat in ipairs(Constants.statDefinitions) do
    score = score + (stats[stat.key] or 0) * (weights[stat.key] or 0)
  end

  return score, stats
end

function ns.Stats:GetDisplayLabel(statKey)
  for _, stat in ipairs(Constants.statDefinitions) do
    if stat.key == statKey then
      return stat.label
    end
  end

  return statKey
end
