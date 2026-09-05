local _, BGA = ...

BGA.Application = BGA.Application or {}

local Reasons = BGA.Core.ReasonCodes
local RankProjector = BGA.Domain.RankProjector

local FutureRankResolver = {}
FutureRankResolver.__index = FutureRankResolver
BGA.Application.FutureRankResolver = FutureRankResolver

local function noOp()
end

local function isInteger(value)
    return type(value) == "number" and value % 1 == 0
end

function FutureRankResolver.New(dependencies)
    return setmetatable({
        itemRepository = dependencies.itemRepository,
        artifactManifest = dependencies.artifactManifest,
        seasonManifest = dependencies.seasonManifest,
        clientBuild = dependencies.clientBuild,
        projector = dependencies.projector or RankProjector,
    }, FutureRankResolver)
end

function FutureRankResolver:Resolve(snapshot, revisionToken, isCurrent, callback)
    local artifact = self.artifactManifest or {}
    if artifact.projectionEnabled ~= true
        or not self.seasonManifest
        or self.seasonManifest.validationVerdict ~= "PASS" then
        callback({ status = "unsupported", candidates = {}, reasonCode = Reasons.UNVERIFIED_SEASON_DATA })
        return noOp
    end

    local upgrade = snapshot and snapshot.upgrade or {}
    local currentRank = upgrade.rank
    local maxRank = upgrade.maxRank
    if not isInteger(currentRank) or not isInteger(maxRank) or maxRank <= currentRank then
        callback({ status = "unsupported", candidates = {}, reasonCode = Reasons.LEGACY_OR_INELIGIBLE_TRACK })
        return noOp
    end

    local active = true
    local rows = {}
    local projected = {}
    local context = {
        projectionEnabled = artifact.projectionEnabled,
        clientBuild = self.clientBuild,
    }

    -- Build the entire work list first. Resolve callbacks are allowed to run
    -- synchronously, so pending must be final before subscribing to any item.
    for targetRank = currentRank + 1, maxRank do
        local projection, reason = self.projector.Project(snapshot, targetRank, context, self.seasonManifest)
        if projection and projection.sourceRank == currentRank then
            projected[#projected + 1] = projection
        else
            rows[#rows + 1] = {
                rank = targetRank,
                status = "unsupported",
                reasonCodes = { reason or Reasons.UNVERIFIED_SEASON_DATA },
            }
        end
    end

    local pending = #projected
    local verifiedCount = 0
    local cancellations = {}
    local published = false

    local function current()
        return active and (not isCurrent or isCurrent(revisionToken))
    end

    local function publishIfComplete()
        if published or pending ~= 0 or not current() then
            return
        end
        published = true
        table.sort(rows, function(left, right) return left.rank < right.rank end)
        callback({
            status = verifiedCount > 0 and "available" or "unverified",
            candidates = rows,
        })
    end

    if pending == 0 then
        publishIfComplete()
        return noOp
    end

    for index = 1, #projected do
        if not current() then
            break
        end
        local projection = projected[index]
        local itemRef = {
            fullLink = projection.projectedLink,
            source = "projection",
        }
        cancellations[index] = self.itemRepository:Resolve(itemRef, revisionToken, function(result)
            if not current() then
                return
            end
            if result.status == "ready" then
                local verified, reason = self.projector.Verify(projection, result.snapshot)
                if verified then
                    verifiedCount = verifiedCount + 1
                    rows[#rows + 1] = {
                        rank = projection.targetRank,
                        itemLevel = projection.expectedItemLevel,
                        status = "verified",
                        snapshot = verified.snapshot,
                        projection = projection,
                    }
                else
                    rows[#rows + 1] = {
                        rank = projection.targetRank,
                        itemLevel = projection.expectedItemLevel,
                        status = "unsupported",
                        reasonCodes = { reason },
                    }
                end
            else
                rows[#rows + 1] = {
                    rank = projection.targetRank,
                    itemLevel = projection.expectedItemLevel,
                    status = "unsupported",
                    reasonCodes = { result.reasonCode or Reasons.ITEM_DATA_FAILED },
                }
            end
            pending = pending - 1
            publishIfComplete()
        end)
    end

    return function()
        if not active then
            return
        end
        active = false
        for index = 1, #cancellations do
            if cancellations[index] then
                cancellations[index]()
            end
        end
    end
end
