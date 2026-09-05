local _, BGA = ...

BGA.Ports = BGA.Ports or {}

BGA.Ports.CharacterPort = {
    requiredMethods = { "CaptureContext" },
}
