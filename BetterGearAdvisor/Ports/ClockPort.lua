local _, BGA = ...

BGA.Ports = BGA.Ports or {}

BGA.Ports.ClockPort = {
    requiredMethods = { "Now" },
}
