local _, BGA = ...

BGA.Blizzard = BGA.Blizzard or {}

local EventAdapter = {}
EventAdapter.__index = EventAdapter
BGA.Blizzard.EventAdapter = EventAdapter

local revisionByEvent = {
    PLAYER_EQUIPMENT_CHANGED = "equipment",
    UNIT_INVENTORY_CHANGED = "equipment",
    BAG_UPDATE_DELAYED = "inventory",
    PLAYER_SPECIALIZATION_CHANGED = "context",
    ACTIVE_TALENT_GROUP_CHANGED = "context",
    TRAIT_CONFIG_UPDATED = "context",
    TRAIT_NODE_CHANGED = "context",
    PLAYER_TALENT_UPDATE = "context",
    PLAYER_LEVEL_UP = "context",
    SOCKET_INFO_UPDATE = "equipment",
}

function EventAdapter.New(frameFactory, revisions, onRevision)
    return setmetatable({
        frameFactory = frameFactory or CreateFrame,
        revisions = revisions,
        onRevision = onRevision,
        frame = nil,
        registeredEvents = {},
        unsupportedEvents = {},
    }, EventAdapter)
end

function EventAdapter:Start()
    if self.frame then
        return
    end
    local frame = self.frameFactory("Frame")
    self.frame = frame
    for event in pairs(revisionByEvent) do
        local registered = pcall(frame.RegisterEvent, frame, event)
        if registered then
            self.registeredEvents[event] = true
        else
            self.unsupportedEvents[event] = true
        end
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_INVENTORY_CHANGED" and (...) ~= "player" then
            return
        end
        local kind = revisionByEvent[event]
        local value = self.revisions:Bump(kind)
        if self.onRevision then
            self.onRevision(kind, value, event)
        end
    end)
end
