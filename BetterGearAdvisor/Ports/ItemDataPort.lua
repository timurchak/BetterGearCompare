local _, BGA = ...

BGA.Ports = BGA.Ports or {}

BGA.Ports.ItemDataPort = {
    requiredMethods = { "ReadResolved", "Load" },
}
