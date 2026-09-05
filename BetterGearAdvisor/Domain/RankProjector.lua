local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local ItemLink = BGA.Domain.ItemLink
local Reasons = BGA.Core.ReasonCodes

local RankProjector = {}
BGA.Domain.RankProjector = RankProjector

local function findManifestMatch(parsed, manifest)
    local byBonusID = {}
    for groupIndex = 1, #(manifest.groups or {}) do
        local group = manifest.groups[groupIndex]
        for rankIndex = 1, #(group.ranks or {}) do
            local rank = group.ranks[rankIndex]
            byBonusID[rank.bonusID] = { group = group, rank = rank }
        end
    end

    local found
    for index = 1, #parsed.bonuses do
        local bonus = parsed.bonuses[index]
        local match = byBonusID[bonus.id]
        if match then
            if found then
                return nil, Reasons.AMBIGUOUS_RANK_BONUS
            end
            found = {
                group = match.group,
                rank = match.rank,
                partIndex = bonus.partIndex,
            }
        end
    end
    if not found then
        return nil, Reasons.LEGACY_OR_INELIGIBLE_TRACK
    end
    return found
end

local function findTargetRank(group, targetRank)
    for index = 1, #(group.ranks or {}) do
        if group.ranks[index].rank == targetRank then
            return group.ranks[index]
        end
    end
end

function RankProjector.Project(snapshot, targetRank, context, manifest)
    if not context or context.projectionEnabled ~= true
        or not manifest or manifest.validationVerdict ~= "PASS"
        or context.clientBuild ~= manifest.wowBuild then
        return nil, Reasons.UNVERIFIED_SEASON_DATA
    end
    if not snapshot or type(snapshot.upgrade) ~= "table" then
        return nil, Reasons.LEGACY_OR_INELIGIBLE_TRACK
    end
    if snapshot.isCrafted then
        return nil, Reasons.CRAFTED_PROJECTION_UNSUPPORTED
    end
    if not snapshot.itemGUID or not snapshot.locationKey or snapshot.upgrade.eligibility == "unknown" then
        return nil, Reasons.ELIGIBILITY_UNVERIFIED
    end
    if snapshot.upgrade.eligibility ~= true then
        return nil, Reasons.LEGACY_OR_INELIGIBLE_TRACK
    end

    local parsed, parseReason = ItemLink.Parse(snapshot.fullLink)
    if not parsed then
        return nil, parseReason
    end
    local current, matchReason = findManifestMatch(parsed, manifest)
    if not current then
        return nil, matchReason
    end
    if type(targetRank) ~= "number" or targetRank % 1 ~= 0 or targetRank <= current.rank.rank then
        return nil, Reasons.LEGACY_OR_INELIGIBLE_TRACK
    end
    local target = findTargetRank(current.group, targetRank)
    if not target then
        return nil, Reasons.LEGACY_OR_INELIGIBLE_TRACK
    end

    local projectedLink, replaceReason = ItemLink.ReplacePart(parsed, current.partIndex, target.bonusID)
    if not projectedLink then
        return nil, replaceReason
    end
    return {
        status = "projected_link",
        sourceKey = snapshot.key,
        projectedLink = projectedLink,
        groupID = current.group.groupID,
        track = current.group.track,
        sourceRank = current.rank.rank,
        targetRank = target.rank,
        targetBonusID = target.bonusID,
        expectedItemLevel = target.itemLevel,
    }
end

function RankProjector.Verify(projection, resolvedSnapshot)
    if not projection or not resolvedSnapshot then
        return nil, Reasons.ITEM_DATA_PENDING
    end
    if resolvedSnapshot.actualItemLevel ~= projection.expectedItemLevel then
        return nil, Reasons.PROJECTION_ITEM_LEVEL_MISMATCH
    end
    return {
        status = "verified",
        projection = projection,
        snapshot = resolvedSnapshot,
    }
end
