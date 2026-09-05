local BGA, Assert = ...

local function contextPort()
    return {
        CaptureContext = function()
            return {
                specID = 71,
                archetypeID = "arms-warrior-mid2-dungeon-aoe-v1",
                profileID = "dungeon_aoe",
                talentFingerprint = nil,
                enhancementPolicyID = "as_observed_v1",
                contextRevision = 0,
            }
        end,
    }
end

local function candidateSnapshot()
    return BGA.Domain.ItemSnapshot.New({
        fullLink = "item:103::::::::::::0:", itemID = 103, itemGUID = "c", locationKey = "bag:0:1",
        inventoryType = "INVTYPE_FINGER", actualItemLevel = 300, itemClassID = 4, itemSubClassID = 4,
        statsComplete = true, stats = { strength = 0, crit = 10, haste = 10, mastery = 10, versatility = 10 },
        upgrade = { eligibility = false },
    })
end

local function equipmentState()
    local candidate = candidateSnapshot()
    return BGA.Domain.EquipmentState.New({ slots = { [11] = candidate }, materialEffectSignature = "unverified" })
end

return {
    coordinator_publishes_pending_then_final = function()
        local revisions = BGA.Application.Revisions.New()
        local itemRepository = { Resolve = function(_, _, _, callback)
            callback({ status = "ready", snapshot = candidateSnapshot() })
            return function() end
        end }
        local equipmentRepository = { ResolveSnapshot = function(_, _, callback)
            callback({ status = "ready", state = equipmentState() })
            return function() end
        end }
        local coordinator = BGA.Application.EvaluationCoordinator.New({
            revisions = revisions,
            itemRepository = itemRepository,
            equipmentRepository = equipmentRepository,
            characterPort = contextPort(),
            evaluator = BGA.Domain.GearEvaluator,
            evaluationCache = BGA.Application.EvaluationCache.New(),
            artifactManifest = BGA.Generated.ArtifactManifest,
            capabilityManifest = BGA.Generated.CapabilityManifest,
        })
        local statuses = {}
        coordinator:Request({ fullLink = "item:103::::::::::::0:", itemGUID = "c" }, function(result)
            statuses[#statuses + 1] = result.status
        end)
        Assert.Equal(statuses[1], "pending")
        Assert.Equal(statuses[2], "unsupported")
    end,

    stale_revision_prevents_final_publish = function()
        local revisions = BGA.Application.Revisions.New()
        local candidateCallback
        local equipmentCallback
        local coordinator = BGA.Application.EvaluationCoordinator.New({
            revisions = revisions,
            itemRepository = { Resolve = function(_, _, _, callback) candidateCallback = callback; return function() end end },
            equipmentRepository = { ResolveSnapshot = function(_, _, callback) equipmentCallback = callback; return function() end end },
            characterPort = contextPort(),
            evaluator = BGA.Domain.GearEvaluator,
            evaluationCache = BGA.Application.EvaluationCache.New(),
            artifactManifest = BGA.Generated.ArtifactManifest,
            capabilityManifest = BGA.Generated.CapabilityManifest,
        })
        local publishes = 0
        coordinator:Request({ fullLink = "item:103::::::::::::0:", itemGUID = "c" }, function() publishes = publishes + 1 end)
        revisions:Bump("equipment")
        candidateCallback({ status = "ready", snapshot = candidateSnapshot() })
        equipmentCallback({ status = "ready", state = equipmentState() })
        Assert.Equal(publishes, 1)
        Assert.Equal(coordinator.staleDiscardCount, 1)
    end,

    pending_result_is_not_cached = function()
        local cache = BGA.Application.EvaluationCache.New()
        local stored = cache:Put("key", BGA.Core.Result.New("pending", { reasonCodes = { "ITEM_DATA_PENDING" } }))
        Assert.Equal(stored, false)
        Assert.Nil(cache:Get("key"))
    end,

    cached_result_is_returned_as_an_immutable_copy = function()
        local cache = BGA.Application.EvaluationCache.New()
        local original = BGA.Core.Result.New("unsupported", { reasonCodes = { "A" } })
        cache:Put("key", original)
        local first = cache:Get("key")
        first.reasonCodes[1] = "MUTATED"
        Assert.Equal(cache:Get("key").reasonCodes[1], "A")
    end,
}
