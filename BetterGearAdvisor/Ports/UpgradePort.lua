local _, BGA = ...

BGA.Ports = BGA.Ports or {}

BGA.Ports.UpgradePort = {
    requiredMethods = { "GetMetadata", "GetEligibility" },
}
