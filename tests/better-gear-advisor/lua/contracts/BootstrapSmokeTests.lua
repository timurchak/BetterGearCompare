local BGA, Assert = ...

return {
    bootstrap_reaches_tooltip_registration_when_optional_event_is_unknown = function()
        local registeredPostCalls = 0
        local frames = {}

        Enum = {
            TooltipDataType = { Item = 0 },
            TooltipDataLineType = { ProfessionCraftingQuality = 51 },
        }
        TooltipDataProcessor = {
            AddTooltipPostCall = function(_, callback)
                registeredPostCalls = registeredPostCalls + 1
                Assert.True(type(callback) == "function")
            end,
        }
        SlashCmdList = {}
        BetterGearAdvisorDB = nil
        C_Item = nil
        C_ItemUpgrade = nil
        C_Container = nil
        C_PlayerInfo = nil
        C_TooltipInfo = nil
        C_SpecializationInfo = nil
        TooltipUtil = nil
        NUM_BAG_SLOTS = 4

        GetBuildInfo = function() return "12.1.0", "69587" end
        GetLocale = function() return "enUS" end
        GetTime = function() return 0 end
        GetTimePreciseSec = function() return 0 end
        GetInventoryItemLink = function() return nil end
        UnitClass = function() return "Warrior", "WARRIOR", 1 end
        UnitLevel = function() return 90 end
        GetSpecializationInfo = function() return 71 end

        CreateFrame = function()
            local frame = {}
            frames[#frames + 1] = frame
            function frame:RegisterEvent(event)
                if event == "TRAIT_NODE_CHANGED" then
                    error("unknown event")
                end
            end
            function frame:SetScript(script, callback)
                self[script] = callback
            end
            return frame
        end

        local chunk, loadError = loadfile(BGA.__testRoot .. "\\BetterGearAdvisor\\Bootstrap.lua")
        Assert.Nil(loadError)
        chunk("BetterGearAdvisor", BGA)

        Assert.True(BGA.initialized)
        Assert.Equal(registeredPostCalls, 1)
        Assert.True(BGA.runtime.eventAdapter.unsupportedEvents.TRAIT_NODE_CHANGED)
        Assert.Equal(SLASH_BETTERGEARADVISOR1, "/bga")
        Assert.True(type(SlashCmdList.BETTERGEARADVISOR) == "function")
        Assert.True(#frames >= 2)
    end,
}
