local BGA, Assert = ...

local function snapshot()
    return BGA.Domain.ItemSnapshot.New({
        fullLink = "item:100:0", itemID = 100, itemGUID = "owned", locationKey = "bag:0:1",
        inventoryType = "INVTYPE_FINGER", actualItemLevel = 300, itemClassID = 4, itemSubClassID = 4,
        statsComplete = true,
        stats = { strength = 10, crit = 10, haste = 10, mastery = 10, versatility = 10 },
        upgrade = { eligibility = true, rank = 2, maxRank = 4 },
    })
end

local projector = {
    Project = function(_, targetRank)
        return {
            projectedLink = "item:100:rank:" .. targetRank,
            sourceRank = 2,
            targetRank = targetRank,
            expectedItemLevel = 300 + targetRank,
        }
    end,
    Verify = function(projection, resolved)
        if resolved.actualItemLevel ~= projection.expectedItemLevel then
            return nil, BGA.Core.ReasonCodes.PROJECTION_ITEM_LEVEL_MISMATCH
        end
        return { status = "verified", projection = projection, snapshot = resolved }
    end,
}

local function resolvedFor(itemRef)
    local rank = tonumber(string.match(itemRef.fullLink, "rank:(%d+)$"))
    return BGA.Domain.ItemSnapshot.New({
        fullLink = itemRef.fullLink, itemID = 100,
        inventoryType = "INVTYPE_FINGER", actualItemLevel = 300 + rank,
        itemClassID = 4, itemSubClassID = 4, statsComplete = true,
        stats = { strength = 10, crit = rank * 10, haste = 10, mastery = 10, versatility = 10 },
        upgrade = { eligibility = "unknown" },
    })
end

return {
    disabled_projection_does_not_load_synthetic_items = function()
        local loads = 0
        local resolver = BGA.Application.FutureRankResolver.New({
            itemRepository = { Resolve = function() loads = loads + 1 end },
            artifactManifest = { projectionEnabled = false },
            seasonManifest = { validationVerdict = "PASS" },
            clientBuild = "test",
            projector = projector,
        })
        local result
        resolver:Resolve(snapshot(), {}, nil, function(value) result = value end)
        Assert.Equal(loads, 0)
        Assert.Equal(result.status, "unsupported")
    end,

    synchronous_loads_resolve_every_future_rank_once = function()
        local refs = {}
        local resolver = BGA.Application.FutureRankResolver.New({
            itemRepository = { Resolve = function(_, itemRef, _, callback)
                refs[#refs + 1] = itemRef
                callback({ status = "ready", snapshot = resolvedFor(itemRef) })
                return function() end
            end },
            artifactManifest = { projectionEnabled = true },
            seasonManifest = { validationVerdict = "PASS" },
            clientBuild = "test",
            projector = projector,
        })
        local callbackCount = 0
        local result
        resolver:Resolve(snapshot(), {}, nil, function(value)
            callbackCount = callbackCount + 1
            result = value
        end)
        Assert.Equal(callbackCount, 1)
        Assert.Equal(result.status, "available")
        Assert.Equal(#result.candidates, 2)
        Assert.Equal(result.candidates[1].rank, 3)
        Assert.Equal(result.candidates[2].rank, 4)
        Assert.Nil(refs[1].itemGUID)
        Assert.Nil(refs[1].locationKey)
    end,

    verification_failure_is_a_nonnumeric_rank = function()
        local resolver = BGA.Application.FutureRankResolver.New({
            itemRepository = { Resolve = function(_, itemRef, _, callback)
                local resolved = resolvedFor(itemRef)
                resolved.actualItemLevel = 999
                callback({ status = "ready", snapshot = resolved })
                return function() end
            end },
            artifactManifest = { projectionEnabled = true },
            seasonManifest = { validationVerdict = "PASS" },
            clientBuild = "test",
            projector = projector,
        })
        local result
        resolver:Resolve(snapshot(), {}, nil, function(value) result = value end)
        Assert.Equal(result.status, "unverified")
        Assert.Equal(result.candidates[1].status, "unsupported")
        Assert.Equal(result.candidates[1].reasonCodes[1], BGA.Core.ReasonCodes.PROJECTION_ITEM_LEVEL_MISMATCH)
    end,
}
