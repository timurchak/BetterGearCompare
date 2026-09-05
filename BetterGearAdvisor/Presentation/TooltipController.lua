local _, BGA = ...

BGA.Presentation = BGA.Presentation or {}

local Keys = BGA.Core.Keys
local Result = BGA.Core.Result
local TooltipPresenter = BGA.Presentation.TooltipPresenter

local TooltipController = {}
TooltipController.__index = TooltipController
BGA.Presentation.TooltipController = TooltipController

function TooltipController.New(tooltipPort, coordinator, strings, diagnostics)
    return setmetatable({
        tooltipPort = tooltipPort,
        coordinator = coordinator,
        strings = strings,
        diagnostics = diagnostics,
        states = setmetatable({}, { __mode = "k" }),
    }, TooltipController)
end

function TooltipController:_stateFor(tooltip)
    local state = self.states[tooltip]
    if state then
        return state
    end
    state = { viewRevision = 0, hooked = true }
    self.states[tooltip] = state
    self.tooltipPort:HookHide(tooltip, function(hiddenTooltip)
        local hidden = self.states[hiddenTooltip]
        if not hidden then return end
        hidden.viewRevision = hidden.viewRevision + 1
        if hidden.cancel then hidden.cancel() end
        hidden.key = nil
        hidden.cancel = nil
        hidden.active = false
        hidden.result = nil
        hidden.renderedSignature = nil
        hidden.renderedLineCount = nil
        if self.diagnostics then self.diagnostics:Record("tooltip-hide") end
    end)
    return state
end

function TooltipController:_render(tooltip, state)
    if not state.result then return end
    local signature = TooltipPresenter.Signature(state.key, state.result)
    local currentLines = self.tooltipPort:NumLines(tooltip)
    if state.renderedSignature == signature and state.renderedLineCount
        and currentLines >= state.renderedLineCount then
        if self.diagnostics then self.diagnostics:Record("render-duplicate-suppressed", { key = state.key }) end
        return
    end
    TooltipPresenter.Render(tooltip, state.result, self.strings)
    state.renderedSignature = signature
    state.renderedLineCount = self.tooltipPort:NumLines(tooltip)
    self.tooltipPort:Commit(tooltip)
    if self.diagnostics then self.diagnostics:Record("render", { key = state.key, status = state.result.status }) end
end

function TooltipController:OnItemTooltip(tooltip, tooltipData)
    local itemRef = self.tooltipPort:GetDisplayedItem(tooltip, tooltipData)
    if not itemRef then
        if self.diagnostics then
            self.diagnostics:Record("tooltip-no-item-ref", {
                tooltip = tooltip.GetName and tooltip:GetName() or "unnamed",
            })
        end
        return
    end
    if self.diagnostics then
        self.diagnostics:Record("tooltip-item-ref", {
            source = itemRef.source,
            tooltip = tooltip.GetName and tooltip:GetName() or "unnamed",
        })
    end
    local key = Keys.ItemSnapshotKey(itemRef.fullLink, itemRef.itemGUID, itemRef.locationKey)
    local state = self:_stateFor(tooltip)

    if state.key ~= key then
        if state.cancel then state.cancel() end
        state.viewRevision = state.viewRevision + 1
        state.key = key
        state.cancel = nil
        state.active = false
        state.result = nil
        state.renderedSignature = nil
        state.renderedLineCount = nil
        if self.diagnostics then self.diagnostics:Record("tooltip-item-change", { key = key }) end
    end

    if state.result and Result.IsFinal(state.result) then
        self:_render(tooltip, state)
        return
    end
    if state.active then
        self:_render(tooltip, state)
        return
    end

    state.active = true
    local expectedRevision = state.viewRevision
    local expectedKey = key
    local subscribing = true
    local completedSynchronously = false
    local cancel = self.coordinator:Request(itemRef, function(result)
        local current = self.states[tooltip]
        -- TooltipDataProcessor may invoke its post-call while the frame is still
        -- being assembled and IsShown() is false. Identity + view revision are
        -- the stale guards; OnHide advances that revision and clears the key.
        if not current or current.viewRevision ~= expectedRevision or current.key ~= expectedKey then
            if self.diagnostics then self.diagnostics:Record("stale-result-rejected", { key = expectedKey }) end
            return
        end
        current.result = result
        if Result.IsFinal(result) then
            current.active = false
            current.cancel = nil
            if subscribing then
                completedSynchronously = true
            else
                self.tooltipPort:Refresh(tooltip)
            end
        end
    end)
    subscribing = false
    if state.active then
        state.cancel = cancel
    elseif not completedSynchronously and cancel then
        cancel()
    end
    self:_render(tooltip, state)
end

function TooltipController:Start()
    self.tooltipPort:RegisterItemPostCall(function(tooltip, tooltipData)
        if self.diagnostics then self.diagnostics:Record("tooltip-postcall") end
        local ok, message = pcall(self.OnItemTooltip, self, tooltip, tooltipData)
        if not ok and self.diagnostics then
            self.diagnostics:Record("tooltip-error", { message = tostring(message) })
        end
    end)
    if self.diagnostics then self.diagnostics:Record("tooltip-registered") end
end

function TooltipController:RefreshTracked()
    for tooltip, state in pairs(self.states) do
        if state.key and self.tooltipPort:IsShown(tooltip) then
            if state.cancel then state.cancel() end
            state.viewRevision = state.viewRevision + 1
            state.cancel = nil
            state.active = false
            state.result = nil
            state.renderedSignature = nil
            state.renderedLineCount = nil
            self.tooltipPort:Refresh(tooltip)
        end
    end
end
