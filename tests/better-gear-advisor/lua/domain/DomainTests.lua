local BGA, Assert = ...

local function item(fields)
    fields.statsComplete = true
    fields.actualItemLevel = fields.actualItemLevel or 300
    fields.itemClassID = fields.itemClassID or 4
    fields.itemSubClassID = fields.itemSubClassID or 4
    fields.stats = fields.stats or { strength = 10, crit = 2, haste = 3, mastery = 4, versatility = 5 }
    local snapshot, reason = BGA.Domain.ItemSnapshot.New(fields)
    Assert.Nil(reason)
    return snapshot
end

local function ring(id, guid, stats)
    return item({
        fullLink = "|Hitem:" .. id .. ":0|h[ring]|h",
        itemID = id,
        itemGUID = guid,
        inventoryType = "INVTYPE_FINGER",
        stats = stats,
    })
end

return {
    missing_stats_are_never_a_zero_snapshot = function()
        local snapshot, reason = BGA.Domain.ItemSnapshot.New({
            fullLink = "item:1:0",
            itemID = 1,
            inventoryType = "INVTYPE_HEAD",
            actualItemLevel = 300,
            stats = {},
            statsComplete = false,
        })
        Assert.Nil(snapshot)
        Assert.Equal(reason, BGA.Core.ReasonCodes.INVALID_ITEM_SNAPSHOT)
    end,

    ring_enumerates_both_physical_slots = function()
        local first = ring(101, "ring-a", { strength = 0, crit = 10, haste = 0, mastery = 0, versatility = 0 })
        local second = ring(102, "ring-b", { strength = 0, crit = 0, haste = 10, mastery = 0, versatility = 0 })
        local candidate = ring(103, "ring-c", { strength = 0, crit = 5, haste = 5, mastery = 0, versatility = 0 })
        local baseline = BGA.Domain.EquipmentState.New({ slots = { [11] = first, [12] = second } })
        local result = BGA.Domain.CandidateEnumerator.Enumerate(baseline, candidate)
        Assert.Equal(result.status, "ok")
        Assert.Equal(#result.states, 2)
        Assert.Equal(result.states[1].replacedSlots[1], 11)
        Assert.Equal(result.states[2].replacedSlots[1], 12)
        Assert.Equal(result.states[1].state.slots[12].key, second.key)
        Assert.Equal(result.states[2].state.slots[11].key, first.key)
    end,

    duplicate_ring_instance_is_rejected = function()
        local first = ring(101, "ring-a")
        local second = ring(102, "ring-b")
        local duplicate = ring(101, "ring-a")
        local baseline = BGA.Domain.EquipmentState.New({ slots = { [11] = first, [12] = second } })
        local states = BGA.Domain.CandidateEnumerator.Enumerate(baseline, duplicate).states
        local replacesSecond = BGA.Domain.StateValidator.Validate(states[2])
        Assert.Equal(replacesSecond.status, "invalid")
        Assert.Equal(replacesSecond.reasonCodes[1], BGA.Core.ReasonCodes.DUPLICATE_INSTANCE)
    end,

    unique_category_limit_is_rejected = function()
        local first = ring(101, "ring-a")
        local second = ring(102, "ring-b")
        first.uniqueCategoryID = 55
        first.uniqueCategoryLimit = 1
        local candidate = ring(103, "ring-c")
        candidate.uniqueCategoryID = 55
        candidate.uniqueCategoryLimit = 1
        local baseline = BGA.Domain.EquipmentState.New({ slots = { [11] = first, [12] = second } })
        local states = BGA.Domain.CandidateEnumerator.Enumerate(baseline, candidate).states
        local retainsFirst = BGA.Domain.StateValidator.Validate(states[2])
        Assert.Equal(retainsFirst.status, "invalid")
        Assert.Equal(retainsFirst.reasonCodes[1], BGA.Core.ReasonCodes.UNIQUE_LIMIT_VIOLATION)
    end,

    exact_unique_item_id_cannot_be_equipped_twice = function()
        local first = ring(101, "ring-a")
        local secondCopy = ring(101, "ring-b")
        first.isUnique = true
        secondCopy.isUnique = true
        local state = BGA.Domain.EquipmentState.New({ slots = { [11] = first, [12] = secondCopy } })
        local validation = BGA.Domain.StateValidator.Validate({ state = state })
        Assert.Equal(validation.status, "invalid")
        Assert.Equal(validation.reasonCodes[1], BGA.Core.ReasonCodes.UNIQUE_LIMIT_VIOLATION)
    end,

    replacing_unique_ring_can_leave_one_legal_alternative = function()
        local first = ring(101, "ring-a")
        local second = ring(102, "ring-b")
        first.uniqueCategoryID = 55
        first.uniqueCategoryLimit = 1
        local candidate = ring(103, "ring-c")
        candidate.uniqueCategoryID = 55
        candidate.uniqueCategoryLimit = 1
        local baseline = BGA.Domain.EquipmentState.New({ slots = { [11] = first, [12] = second } })
        local states = BGA.Domain.CandidateEnumerator.Enumerate(baseline, candidate).states
        Assert.Equal(BGA.Domain.StateValidator.Validate(states[1]).status, "valid")
        Assert.Equal(BGA.Domain.StateValidator.Validate(states[2]).status, "invalid")
    end,

    equipped_ring_noop_does_not_duplicate_instance = function()
        local first = ring(101, "ring-a")
        local second = ring(102, "ring-b")
        local baseline = BGA.Domain.EquipmentState.New({ slots = { [11] = first, [12] = second } })
        local states = BGA.Domain.CandidateEnumerator.Enumerate(baseline, first).states
        Assert.Equal(BGA.Domain.StateValidator.Validate(states[1]).status, "valid")
        Assert.Equal(BGA.Domain.StateValidator.Validate(states[2]).status, "invalid")
    end,

    weapons_fail_closed_before_scoring = function()
        local weapon = item({ fullLink = "item:200:0", itemID = 200, itemGUID = "weapon-a", inventoryType = "INVTYPE_2HWEAPON" })
        local classification = BGA.Domain.EffectClassifier.Classify(weapon)
        Assert.Equal(classification.status, "unsupported")
        Assert.Equal(classification.reasonCodes[1], BGA.Core.ReasonCodes.WEAPON_UNSUPPORTED)
    end,

    tier_and_trinket_items_are_special = function()
        local tier = item({ fullLink = "item:300:0", itemID = 300, inventoryType = "INVTYPE_HEAD", setID = 9 })
        local trinket = item({ fullLink = "item:301:0", itemID = 301, inventoryType = "INVTYPE_TRINKET" })
        Assert.Equal(BGA.Domain.EffectClassifier.Classify(tier).status, "special")
        Assert.Equal(BGA.Domain.EffectClassifier.Classify(trinket).status, "special")
    end,

    non_plate_armor_fails_closed_for_arms = function()
        local cloth = item({
            fullLink = "item:401:0",
            itemID = 401,
            itemGUID = "cloth-head",
            inventoryType = "INVTYPE_HEAD",
            itemSubClassID = 1,
        })
        local oldHead = item({ fullLink = "item:402:0", itemID = 402, itemGUID = "plate-head", inventoryType = "INVTYPE_HEAD" })
        local baseline = BGA.Domain.EquipmentState.New({ slots = { [1] = oldHead } })
        local candidateState = BGA.Domain.CandidateEnumerator.Enumerate(baseline, cloth).states[1]
        local validation = BGA.Domain.StateValidator.Validate(candidateState)
        Assert.Equal(validation.status, "invalid")
        Assert.Equal(validation.reasonCodes[1], BGA.Core.ReasonCodes.WRONG_ARMOR_TYPE)
    end,

    state_aggregation_does_not_mutate_baseline = function()
        local first = ring(101, "ring-a", { strength = 0, crit = 10, haste = 0, mastery = 0, versatility = 0 })
        local second = ring(102, "ring-b", { strength = 0, crit = 0, haste = 10, mastery = 0, versatility = 0 })
        local candidate = ring(103, "ring-c", { strength = 0, crit = 20, haste = 20, mastery = 0, versatility = 0 })
        local baseline = BGA.Domain.EquipmentState.New({ slots = { [11] = first, [12] = second } })
        local originalCrit = baseline.aggregateStats.crit
        BGA.Domain.CandidateEnumerator.Enumerate(baseline, candidate)
        Assert.Equal(baseline.aggregateStats.crit, originalCrit)
        Assert.Equal(baseline.slots[11].key, first.key)
        Assert.Equal(baseline.slots[12].key, second.key)
    end,
}
