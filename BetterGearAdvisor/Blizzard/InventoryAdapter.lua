local _, BGA = ...

BGA.Blizzard = BGA.Blizzard or {}

local InventoryAdapter = {}
InventoryAdapter.__index = InventoryAdapter
BGA.Blizzard.InventoryAdapter = InventoryAdapter

local observedSlots = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

function InventoryAdapter.New(api, revisions)
    api = api or {}
    return setmetatable({
        GetInventoryItemLink = api.GetInventoryItemLink or GetInventoryItemLink,
        CreateEquipmentLocation = api.CreateEquipmentLocation
            or function(slotID) return ItemLocation:CreateFromEquipmentSlot(slotID) end,
        GetItemGUID = api.GetItemGUID or (C_Item and C_Item.GetItemGUID),
        GetContainerNumSlots = api.GetContainerNumSlots or (C_Container and C_Container.GetContainerNumSlots),
        GetContainerItemLink = api.GetContainerItemLink or (C_Container and C_Container.GetContainerItemLink),
        CreateBagLocation = api.CreateBagLocation
            or function(bagID, slotID) return ItemLocation:CreateFromBagAndSlot(bagID, slotID) end,
        numBagSlots = api.numBagSlots or NUM_BAG_SLOTS or 4,
        revisions = revisions,
    }, InventoryAdapter)
end

function InventoryAdapter:FindOwnedRef(fullLink, itemGUID)
    for index = 1, #observedSlots do
        local slotID = observedSlots[index]
        local equippedLink = self.GetInventoryItemLink("player", slotID)
        if equippedLink then
            local location = self.CreateEquipmentLocation(slotID)
            local guid = self.GetItemGUID and self.GetItemGUID(location) or nil
            if (itemGUID and guid == itemGUID) or (not itemGUID and equippedLink == fullLink) then
                return {
                    fullLink = equippedLink,
                    itemLocation = location,
                    itemGUID = guid,
                    locationKey = "equipment:" .. slotID,
                    source = "equipped",
                }
            end
        end
    end

    if self.GetContainerNumSlots and self.GetContainerItemLink then
        for bagID = 0, self.numBagSlots do
            for slotID = 1, self.GetContainerNumSlots(bagID) do
                local bagLink = self.GetContainerItemLink(bagID, slotID)
                if bagLink then
                    local location = self.CreateBagLocation(bagID, slotID)
                    local guid = self.GetItemGUID and self.GetItemGUID(location) or nil
                    if (itemGUID and guid == itemGUID) or (not itemGUID and bagLink == fullLink) then
                        return {
                            fullLink = bagLink,
                            itemLocation = location,
                            itemGUID = guid,
                            locationKey = "bag:" .. bagID .. ":" .. slotID,
                            source = "bag",
                        }
                    end
                end
            end
        end
    end
    return nil
end

function InventoryAdapter:CaptureEquippedRefs()
    local refsBySlot = {}
    for index = 1, #observedSlots do
        local slotID = observedSlots[index]
        local fullLink = self.GetInventoryItemLink("player", slotID)
        if fullLink then
            local location = self.CreateEquipmentLocation(slotID)
            refsBySlot[slotID] = {
                fullLink = fullLink,
                itemLocation = location,
                itemGUID = self.GetItemGUID and self.GetItemGUID(location) or nil,
                locationKey = "equipment:" .. slotID,
                source = "equipped",
            }
        end
    end
    local revision = self.revisions and self.revisions:Capture() or {}
    return {
        refsBySlot = refsBySlot,
        equipmentRevision = revision.equipmentRevision or 0,
        inventoryRevision = revision.inventoryRevision or 0,
        materialEffectSignature = "unverified",
    }
end
