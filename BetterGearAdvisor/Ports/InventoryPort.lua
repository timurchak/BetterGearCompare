local _, BGA = ...

BGA.Ports = BGA.Ports or {}

BGA.Ports.InventoryPort = {
    requiredMethods = { "CaptureEquippedRefs" },
}
