local _, BGA = ...

BGA.Application = BGA.Application or {}

local Revisions = {}
Revisions.__index = Revisions
BGA.Application.Revisions = Revisions

function Revisions.New()
    return setmetatable({
        equipment = 0,
        inventory = 0,
        context = 0,
        artifacts = 0,
    }, Revisions)
end

function Revisions:Bump(kind)
    if self[kind] == nil then
        error("unknown revision kind: " .. tostring(kind), 2)
    end
    self[kind] = self[kind] + 1
    return self[kind]
end

function Revisions:Capture()
    return {
        equipmentRevision = self.equipment,
        inventoryRevision = self.inventory,
        contextRevision = self.context,
        artifactRevision = self.artifacts,
    }
end

function Revisions:Matches(token)
    return token
        and token.equipmentRevision == self.equipment
        and token.inventoryRevision == self.inventory
        and token.contextRevision == self.context
        and token.artifactRevision == self.artifacts
end
