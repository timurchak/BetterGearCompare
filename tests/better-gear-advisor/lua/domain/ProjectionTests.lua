local BGA, Assert = ...

local manifest = {
    schema = 1,
    validationVerdict = "PASS",
    wowBuild = "12.1.0.69587",
    groups = {
        {
            groupID = 616,
            track = "Champion",
            ranks = {
                { rank = 1, bonusID = 12833, itemLevel = 292 },
                { rank = 2, bonusID = 12834, itemLevel = 295 },
                { rank = 3, bonusID = 12835, itemLevel = 298 },
                { rank = 4, bonusID = 12836, itemLevel = 302 },
                { rank = 5, bonusID = 12837, itemLevel = 305 },
                { rank = 6, bonusID = 12838, itemLevel = 308 },
            },
        },
        {
            groupID = 617,
            track = "Hero",
            ranks = {
                { rank = 1, bonusID = 12841, itemLevel = 305 },
                { rank = 2, bonusID = 12842, itemLevel = 308 },
                { rank = 3, bonusID = 12843, itemLevel = 311 },
                { rank = 4, bonusID = 12844, itemLevel = 315 },
                { rank = 5, bonusID = 12845, itemLevel = 318 },
                { rank = 6, bonusID = 12846, itemLevel = 321 },
            },
        },
    },
}

local sourceLink = "|cnIQ4:|Hitem:271484::::::::90:264::16:6:6652:12843:13440:13691:13697:1564:1:64:251165:::::|h[Проклятые захваты]|h|r"
local targetLink = "|cnIQ4:|Hitem:271484::::::::90:264::16:6:6652:12844:13440:13691:13697:1564:1:64:251165:::::|h[Проклятые захваты]|h|r"

local function source(overrides)
    local fields = {
        fullLink = sourceLink,
        itemID = 271484,
        itemGUID = "Item-test-271484",
        locationKey = "equipment:10",
        inventoryType = "INVTYPE_HAND",
        actualItemLevel = 311,
        itemClassID = 4,
        itemSubClassID = 3,
        statsComplete = true,
        stats = { strength = 100, crit = 80, haste = 0, mastery = 0, versatility = 50 },
        upgrade = { eligibility = true },
    }
    for key, value in pairs(overrides or {}) do
        fields[key] = value
    end
    return BGA.Domain.ItemSnapshot.New(fields)
end

local context = { projectionEnabled = true, clientBuild = "12.1.0.69587" }

return {
    phase0_link_replaces_only_rank_bonus = function()
        local projection, reason = BGA.Domain.RankProjector.Project(source(), 4, context, manifest)
        Assert.Nil(reason)
        Assert.Equal(projection.projectedLink, targetLink)
        Assert.Equal(projection.expectedItemLevel, 315)
        Assert.Equal(projection.groupID, 617)
    end,

    projected_item_level_must_match_manifest = function()
        local projection = BGA.Domain.RankProjector.Project(source(), 4, context, manifest)
        local resolved = source({ fullLink = targetLink, actualItemLevel = 314 })
        local verified, reason = BGA.Domain.RankProjector.Verify(projection, resolved)
        Assert.Nil(verified)
        Assert.Equal(reason, BGA.Core.ReasonCodes.PROJECTION_ITEM_LEVEL_MISMATCH)
    end,

    projection_is_disabled_for_packaged_placeholder_artifact = function()
        local projection, reason = BGA.Domain.RankProjector.Project(
            source(), 4,
            { projectionEnabled = BGA.Generated.ArtifactManifest.projectionEnabled, clientBuild = "12.1.0.69587" },
            BGA.Generated.SeasonManifest
        )
        Assert.Nil(projection)
        Assert.Equal(reason, BGA.Core.ReasonCodes.UNVERIFIED_SEASON_DATA)
    end,

    detached_link_has_unverified_eligibility = function()
        local detached = source({ itemGUID = false, locationKey = false, upgrade = { eligibility = "unknown" } })
        detached.itemGUID = nil
        detached.locationKey = nil
        local projection, reason = BGA.Domain.RankProjector.Project(detached, 4, context, manifest)
        Assert.Nil(projection)
        Assert.Equal(reason, BGA.Core.ReasonCodes.ELIGIBILITY_UNVERIFIED)
    end,

    explicit_false_eligibility_fails_closed = function()
        local projection, reason = BGA.Domain.RankProjector.Project(
            source({ upgrade = { eligibility = false } }), 4, context, manifest
        )
        Assert.Nil(projection)
        Assert.Equal(reason, BGA.Core.ReasonCodes.LEGACY_OR_INELIGIBLE_TRACK)
    end,

    crafted_projection_is_never_invented = function()
        local projection, reason = BGA.Domain.RankProjector.Project(source({ isCrafted = true }), 4, context, manifest)
        Assert.Nil(projection)
        Assert.Equal(reason, BGA.Core.ReasonCodes.CRAFTED_PROJECTION_UNSUPPORTED)
    end,

    ambiguous_manifest_bonus_fails_closed = function()
        local ambiguousLink = string.gsub(sourceLink, ":6:6652:12843:", ":7:6652:12843:12844:", 1)
        local projection, reason = BGA.Domain.RankProjector.Project(source({ fullLink = ambiguousLink }), 5, context, manifest)
        Assert.Nil(projection)
        Assert.Equal(reason, BGA.Core.ReasonCodes.AMBIGUOUS_RANK_BONUS)
    end,

    build_mismatch_disables_projection = function()
        local projection, reason = BGA.Domain.RankProjector.Project(
            source(), 4, { projectionEnabled = true, clientBuild = "12.1.0.99999" }, manifest
        )
        Assert.Nil(projection)
        Assert.Equal(reason, BGA.Core.ReasonCodes.UNVERIFIED_SEASON_DATA)
    end,

    lower_and_post_track_ranks_are_rejected = function()
        local lower = BGA.Domain.RankProjector.Project(source(), 2, context, manifest)
        local postTrack = BGA.Domain.RankProjector.Project(source(), 7, context, manifest)
        Assert.Nil(lower)
        Assert.Nil(postTrack)
    end,
}
