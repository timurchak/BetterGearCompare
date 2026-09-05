local BGA, Assert = ...

return {
    item_key_ignores_localized_link_wrapper = function()
        local a = BGA.Core.Keys.ItemSnapshotKey("|cffa335ee|Hitem:123:0:1|h[English]|h|r")
        local b = BGA.Core.Keys.ItemSnapshotKey("|cffa335ee|Hitem:123:0:1|h[Русский]|h|r")
        Assert.Equal(a, b)
    end,

    item_key_distinguishes_instance_identity = function()
        local link = "|Hitem:123:0:1|h[item]|h"
        Assert.True(BGA.Core.Keys.ItemSnapshotKey(link, "guid-a") ~= BGA.Core.Keys.ItemSnapshotKey(link, "guid-b"))
    end,

    item_key_distinguishes_full_bonus_payload = function()
        local a = BGA.Core.Keys.ItemSnapshotKey("|Hitem:123:0:1:12841|h[item]|h")
        local b = BGA.Core.Keys.ItemSnapshotKey("|Hitem:123:0:1:12842|h[item]|h")
        Assert.True(a ~= b)
    end,

    planned_arms_capability_cannot_emit_numeric_advice = function()
        local capability = BGA.Generated.CapabilityManifest.capabilities["arms-warrior-mid2-dungeon-aoe-v1"]
        Assert.Equal(capability.specID, 71)
        Assert.Equal(capability.profileID, "dungeon_aoe")
        Assert.Equal(capability.numericAdviceEnabled, false)
        Assert.Equal(BGA.Generated.ArtifactManifest.numericAdviceEnabled, false)
    end,

    nonnumeric_result_rejects_delta = function()
        local ok = pcall(BGA.Core.Result.New, "unsupported", { deltaPercent = 1, uncertaintyPercent = 1 })
        Assert.Equal(ok, false)
    end,

    pending_is_not_final = function()
        local result = BGA.Core.Result.New("pending", { reasonCodes = { "ITEM_DATA_PENDING" } })
        Assert.Equal(BGA.Core.Result.IsFinal(result), false)
    end,

    directional_result_requires_both_numeric_fields = function()
        local ok = pcall(BGA.Core.Result.New, "upgrade", { deltaPercent = 2.1 })
        Assert.Equal(ok, false)
    end,
}
