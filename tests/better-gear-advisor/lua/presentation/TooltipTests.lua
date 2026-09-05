local BGA, Assert = ...

local function tooltip(name)
    local value = { name = name, shown = true, lines = {}, hideCallbacks = {}, refreshes = 0, shows = 0 }
    function value:GetName() return self.name end
    function value:IsShown() return self.shown end
    function value:NumLines() return #self.lines end
    function value:AddLine(text) self.lines[#self.lines + 1] = text end
    function value:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. " " .. right end
    function value:HookScript(event, callback) self.hideCallbacks[event] = callback end
    function value:RefreshData() self.refreshes = self.refreshes + 1 end
    function value:Show() self.shows = self.shows + 1; self.shown = true end
    function value:Hide()
        self.shown = false
        if self.hideCallbacks.OnHide then self.hideCallbacks.OnHide(self) end
    end
    return value
end

local function tooltipPort()
    local value = { callback = nil, refs = {} }
    function value:RegisterItemPostCall(callback) self.callback = callback end
    function value:GetDisplayedItem(frame, data) return { fullLink = data.hyperlink, source = frame:GetName() } end
    function value:Refresh(frame) return frame:RefreshData() or true end
    function value:Commit(frame) return frame:Show() or true end
    function value:HookHide(frame, callback) frame:HookScript("OnHide", callback) end
    function value:IsShown(frame) return frame:IsShown() end
    function value:NumLines(frame) return frame:NumLines() end
    return value
end

local function manualCoordinator()
    local value = { requests = {}, cancels = 0 }
    function value:Request(itemRef, callback)
        local request = { itemRef = itemRef, callback = callback, canceled = false }
        self.requests[#self.requests + 1] = request
        callback(BGA.Core.Result.New("pending", { reasonCodes = { "ITEM_DATA_PENDING" } }))
        return function()
            if not request.canceled then
                request.canceled = true
                self.cancels = self.cancels + 1
            end
        end
    end
    return value
end

local function unsupported()
    return BGA.Core.Result.New("unsupported", { reasonCodes = { "MODEL_NOT_VALIDATED" } })
end

return {
    one_modern_callback_is_registered = function()
        local port = tooltipPort()
        local controller = BGA.Presentation.TooltipController.New(port, manualCoordinator(), BGA.Locale.enUS)
        controller:Start()
        Assert.True(type(port.callback) == "function")
    end,

    postcall_boundary_records_hidden_runtime_errors = function()
        local port = tooltipPort()
        function port:GetDisplayedItem() error("fixture failure") end
        local diagnostics = BGA.Application.Diagnostics.New()
        local controller = BGA.Presentation.TooltipController.New(port, manualCoordinator(), BGA.Locale.enUS, diagnostics)
        controller:Start()
        port.callback(tooltip("GameTooltip"), { itemLink = "item:101::::::::::::0:" })
        Assert.Equal(diagnostics.counters["tooltip-postcall"], 1)
        Assert.Equal(diagnostics.counters["tooltip-error"], 1)
    end,

    repeated_pending_postcalls_share_one_request_and_one_block = function()
        local port = tooltipPort()
        local coordinator = manualCoordinator()
        local controller = BGA.Presentation.TooltipController.New(port, coordinator, BGA.Locale.enUS)
        local frame = tooltip("GameTooltip")
        local data = { hyperlink = "item:101::::::::::::0:" }
        controller:OnItemTooltip(frame, data)
        controller:OnItemTooltip(frame, data)
        Assert.Equal(#coordinator.requests, 1)
        Assert.Equal(#frame.lines, 1)
    end,

    stale_item_completion_never_refreshes_new_item = function()
        local port = tooltipPort()
        local coordinator = manualCoordinator()
        local diagnostics = BGA.Application.Diagnostics.New()
        local controller = BGA.Presentation.TooltipController.New(port, coordinator, BGA.Locale.enUS, diagnostics)
        local frame = tooltip("GameTooltip")
        controller:OnItemTooltip(frame, { hyperlink = "item:101::::::::::::0:" })
        controller:OnItemTooltip(frame, { hyperlink = "item:102::::::::::::0:" })
        coordinator.requests[1].callback(unsupported())
        Assert.Equal(frame.refreshes, 0)
        coordinator.requests[2].callback(unsupported())
        Assert.Equal(frame.refreshes, 1)
        Assert.Equal(diagnostics.counters["stale-result-rejected"], 1)
    end,

    shopping_tooltips_have_independent_view_state = function()
        local port = tooltipPort()
        local coordinator = manualCoordinator()
        local controller = BGA.Presentation.TooltipController.New(port, coordinator, BGA.Locale.enUS)
        local primary = tooltip("GameTooltip")
        local shopping = tooltip("ShoppingTooltip1")
        controller:OnItemTooltip(primary, { hyperlink = "item:101::::::::::::0:" })
        controller:OnItemTooltip(shopping, { hyperlink = "item:202::::::::::::0:" })
        Assert.Equal(#coordinator.requests, 2)
        Assert.Equal(coordinator.requests[1].itemRef.fullLink, "item:101::::::::::::0:")
        Assert.Equal(coordinator.requests[2].itemRef.fullLink, "item:202::::::::::::0:")
    end,

    hide_cancels_view_and_rejects_late_completion = function()
        local port = tooltipPort()
        local coordinator = manualCoordinator()
        local controller = BGA.Presentation.TooltipController.New(port, coordinator, BGA.Locale.enUS)
        local frame = tooltip("ItemRefTooltip")
        controller:OnItemTooltip(frame, { hyperlink = "item:101::::::::::::0:" })
        frame:Hide()
        coordinator.requests[1].callback(unsupported())
        Assert.Equal(coordinator.cancels, 1)
        Assert.Equal(frame.refreshes, 0)
    end,

    synchronous_final_result_renders_without_refresh_loop = function()
        local port = tooltipPort()
        local coordinator = {}
        function coordinator:Request(_, callback)
            callback(BGA.Core.Result.New("pending", { reasonCodes = { "ITEM_DATA_PENDING" } }))
            callback(unsupported())
            return function() end
        end
        local controller = BGA.Presentation.TooltipController.New(port, coordinator, BGA.Locale.enUS)
        local frame = tooltip("GameTooltip")
        controller:OnItemTooltip(frame, { hyperlink = "item:101::::::::::::0:" })
        Assert.Equal(frame.refreshes, 0)
        Assert.True(#frame.lines >= 2)
        Assert.True(frame.shows >= 1)
    end,

    synchronous_result_is_kept_while_blizzard_is_assembling_hidden_frame = function()
        local port = tooltipPort()
        local coordinator = {}
        function coordinator:Request(_, callback)
            callback(BGA.Core.Result.New("pending", { reasonCodes = { "ITEM_DATA_PENDING" } }))
            callback(unsupported())
            return function() end
        end
        local controller = BGA.Presentation.TooltipController.New(port, coordinator, BGA.Locale.enUS)
        local frame = tooltip("GameTooltip")
        frame.shown = false
        controller:OnItemTooltip(frame, { hyperlink = "item:101::::::::::::0:" })
        Assert.True(#frame.lines >= 2)
        Assert.True(frame.shown)
    end,

    special_presentation_contains_no_percentage = function()
        local frame = tooltip("GameTooltip")
        BGA.Presentation.TooltipPresenter.Render(
            frame,
            BGA.Core.Result.New("special", { reasonCodes = { "TRINKET_UNSUPPORTED" } }),
            BGA.Locale.enUS
        )
        local joined = table.concat(frame.lines, " ")
        Assert.Nil(string.find(joined, "%%"))
    end,
}
