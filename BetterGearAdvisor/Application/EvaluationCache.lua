local _, BGA = ...

BGA.Application = BGA.Application or {}

local Result = BGA.Core.Result
local TableUtil = BGA.Core.TableUtil

local EvaluationCache = {}
EvaluationCache.__index = EvaluationCache
BGA.Application.EvaluationCache = EvaluationCache

function EvaluationCache.New(maxEntries)
    return setmetatable({
        maxEntries = maxEntries or 128,
        values = {},
        order = {},
    }, EvaluationCache)
end

function EvaluationCache.Key(candidate, baseline, context, artifactManifest)
    return table.concat({
        candidate.key,
        baseline.id,
        context.archetypeID or "no-archetype",
        context.talentFingerprint or "no-talents",
        context.profileID or "no-profile",
        context.enhancementPolicyID or "no-enhancement-policy",
        tostring(context.contextRevision or 0),
        artifactManifest.artifactSetHash or artifactManifest.status or "no-artifact",
    }, "|")
end

function EvaluationCache:Get(key)
    return TableUtil.DeepCopy(self.values[key])
end

function EvaluationCache:Put(key, result)
    if not Result.IsFinal(result) then
        return false
    end
    if not self.values[key] then
        self.order[#self.order + 1] = key
    end
    self.values[key] = TableUtil.DeepCopy(result)
    while #self.order > self.maxEntries do
        local oldest = table.remove(self.order, 1)
        self.values[oldest] = nil
    end
    return true
end

function EvaluationCache:Clear()
    self.values = {}
    self.order = {}
end
