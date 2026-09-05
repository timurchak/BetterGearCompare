local _, BGA = ...

BGA.Ports = BGA.Ports or {}

BGA.Ports.TooltipPort = {
    requiredMethods = { "RegisterItemPostCall", "GetDisplayedItem", "Refresh", "Commit", "HookHide", "IsShown", "NumLines" },
}
