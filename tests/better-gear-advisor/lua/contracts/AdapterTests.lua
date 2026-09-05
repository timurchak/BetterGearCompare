local BGA, Assert = ...

local function location(valid)
    local value = {}
    function value:IsValid()
        return valid
    end
    return value
end

local function baseAPI(calls)
    return {
        GetItemInfoInstant = function()
            return 123, "Armor", "Plate", "INVTYPE_HEAD", 1, 4, 4
        end,
        GetDetailedItemLevelInfo = function()
            return 300, false, 200
        end,
        GetItemStats = function()
            return {
                ITEM_MOD_STRENGTH_SHORT = 100,
                ITEM_MOD_CRIT_RATING_SHORT = 20,
                ITEM_MOD_STAMINA_SHORT = 200,
                RESISTANCE0_NAME = 50,
            }
        end,
        GetItemInventoryType = function(argument)
            calls.locationArgument = argument
            return 1
        end,
        GetItemInventoryTypeByID = function(argument)
            calls.byIDArgument = argument
            return 1
        end,
        GetItemInfo = function()
            return "name", "link", 4, 300, 90, "Armor", "Plate", 1, "INVTYPE_HEAD", 1, 1, 4, 4, 1, 10, nil, false
        end,
        IsEquippableItem = function() return true end,
        CanUseItem = function() return true end,
        GetItemUniquenessByID = function() return false end,
        GetTooltipData = function() return { lines = {} } end,
        CreateItemFromLink = function()
            return { ContinueWithCancelOnItemLoad = function(_, callback) callback(); return function() end end }
        end,
        IsSecret = function() return false end,
    }
end

local function upgrade(eligibility)
    local value = {}
    function value:GetMetadata()
        return { status = "ready", metadataPresent = true, currentLevel = 1, maxLevel = 6 }
    end
    function value:GetEligibility()
        return eligibility
    end
    return value
end

return {
    owned_inventory_type_uses_item_location_overload = function()
        local calls = {}
        local api = baseAPI(calls)
        local adapter = BGA.Blizzard.ItemDataAdapter.New(api, upgrade(true))
        local ownedLocation = location(true)
        local result = adapter:ReadResolved({
            fullLink = "item:123::::::::::::0:",
            itemLocation = ownedLocation,
            itemGUID = "guid",
            locationKey = "equipment:1",
        })
        Assert.Equal(result.status, "ready")
        Assert.Equal(calls.locationArgument, ownedLocation)
        Assert.Nil(calls.byIDArgument)
    end,

    detached_inventory_type_fallback_uses_item_id_not_link = function()
        local calls = {}
        local api = baseAPI(calls)
        local adapter = BGA.Blizzard.ItemDataAdapter.New(api, upgrade("unknown"))
        local result = adapter:ReadResolved({ fullLink = "item:123::::::::::::0:" })
        Assert.Equal(result.status, "ready")
        Assert.Equal(calls.byIDArgument, 123)
        Assert.Nil(calls.locationArgument)
    end,

    false_upgrade_eligibility_is_preserved = function()
        local ownedLocation = location(true)
        local adapter = BGA.Blizzard.UpgradeAdapter.New({
            GetItemUpgradeInfo = function() return nil end,
            CanUpgradeItem = function(argument)
                Assert.Equal(argument, ownedLocation)
                return false
            end,
        })
        Assert.Equal(adapter:GetEligibility(ownedLocation), false)
    end,

    missing_structured_stats_stays_pending = function()
        local calls = {}
        local api = baseAPI(calls)
        api.GetItemStats = function() return nil end
        local adapter = BGA.Blizzard.ItemDataAdapter.New(api, upgrade(true))
        local result = adapter:ReadResolved({ fullLink = "item:123::::::::::::0:" })
        Assert.Equal(result.status, "pending")
        Assert.Equal(result.reasonCode, BGA.Core.ReasonCodes.ITEM_DATA_PENDING)
    end,

    automatic_load_callback_may_be_synchronous = function()
        local calls = {}
        local adapter = BGA.Blizzard.ItemDataAdapter.New(baseAPI(calls), upgrade(true))
        local completions = 0
        adapter:Load({ fullLink = "item:123::::::::::::0:" }, function(success)
            Assert.True(success)
            completions = completions + 1
        end)
        Assert.Equal(completions, 1)
    end,

    unknown_optional_event_does_not_abort_startup = function()
        local frame = {}
        function frame:RegisterEvent(event)
            if event == "TRAIT_NODE_CHANGED" then error("unknown event") end
        end
        function frame:SetScript() end
        local adapter = BGA.Blizzard.EventAdapter.New(function() return frame end, BGA.Application.Revisions.New())
        adapter:Start()
        Assert.True(adapter.unsupportedEvents.TRAIT_NODE_CHANGED)
        Assert.True(adapter.registeredEvents.PLAYER_EQUIPMENT_CHANGED)
    end,

    tooltip_item_link_field_is_a_supported_fallback = function()
        local adapter = BGA.Blizzard.TooltipAdapter.New({
            AddTooltipPostCall = function() end,
            itemDataType = 0,
            GetDisplayedItem = function() return nil, nil end,
            IsSecret = function() return false end,
        })
        local result = adapter:GetDisplayedItem({}, { itemLink = "item:456::::::::::::0:" })
        Assert.Equal(result.fullLink, "item:456::::::::::::0:")
    end,

    tooltip_processing_info_is_a_supported_fallback = function()
        local adapter = BGA.Blizzard.TooltipAdapter.New({
            AddTooltipPostCall = function() end,
            itemDataType = 0,
            GetDisplayedItem = function() return nil, nil end,
            IsSecret = function() return false end,
        })
        local tooltip = { processingInfo = { hyperlink = "item:789::::::::::::0:" } }
        local result = adapter:GetDisplayedItem(tooltip, {})
        Assert.Equal(result.fullLink, "item:789::::::::::::0:")
    end,
}
