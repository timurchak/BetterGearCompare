local addonName, BGA = ...

BGA.name = addonName
BGA.version = "0.1.0-dev"

BetterGearAdvisorDB = BetterGearAdvisorDB or {}

local revisions = BGA.Application.Revisions.New()
local diagnostics = BGA.Application.Diagnostics.New()
diagnostics:Record("bootstrap-start")
local settings = BGA.Application.Settings.New(BetterGearAdvisorDB)
local clock = BGA.Blizzard.ClockAdapter.New()
local upgradeAdapter = BGA.Blizzard.UpgradeAdapter.New()
local inventoryAdapter = BGA.Blizzard.InventoryAdapter.New(nil, revisions)
local characterAdapter = BGA.Blizzard.CharacterAdapter.New(nil, revisions, nil)
local itemDataAdapter = BGA.Blizzard.ItemDataAdapter.New(nil, upgradeAdapter)
local itemRepository = BGA.Application.ItemRepository.New(itemDataAdapter, clock)
local equipmentRepository = BGA.Application.EquipmentRepository.New(inventoryAdapter, itemRepository)
local evaluationCache = BGA.Application.EvaluationCache.New(128)

local version, build = GetBuildInfo()
local clientBuild = tostring(version) .. "." .. tostring(build)
local futureRankResolver = BGA.Application.FutureRankResolver.New({
    itemRepository = itemRepository,
    artifactManifest = BGA.Generated.ArtifactManifest,
    seasonManifest = BGA.Generated.SeasonManifest,
    clientBuild = clientBuild,
})
local coordinator = BGA.Application.EvaluationCoordinator.New({
    revisions = revisions,
    itemRepository = itemRepository,
    equipmentRepository = equipmentRepository,
    characterPort = characterAdapter,
    evaluator = BGA.Domain.GearEvaluator,
    evaluationCache = evaluationCache,
    artifactManifest = BGA.Generated.ArtifactManifest,
    capabilityManifest = BGA.Generated.CapabilityManifest,
    models = {},
    clientBuild = clientBuild,
    futureRankResolver = futureRankResolver,
})

local tooltipAdapter = BGA.Blizzard.TooltipAdapter.New(nil, inventoryAdapter)
local locale = GetLocale()
local strings = BGA.Locale[locale] or BGA.Locale.enUS
local tooltipController = BGA.Presentation.TooltipController.New(
    tooltipAdapter,
    coordinator,
    strings,
    diagnostics
)

local eventAdapter = BGA.Blizzard.EventAdapter.New(nil, revisions, function()
    evaluationCache:Clear()
    tooltipController:RefreshTracked()
end)
tooltipController:Start()
eventAdapter:Start()

local ticker = CreateFrame("Frame")
local elapsedSinceTick = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceTick = elapsedSinceTick + elapsed
    if elapsedSinceTick >= 0.25 then
        elapsedSinceTick = 0
        itemRepository:Tick()
    end
end)

SLASH_BETTERGEARADVISOR1 = "/bga"
SlashCmdList.BETTERGEARADVISOR = function(message)
    local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
    if command == "debug" then
        settings:SetDebugEnabled(not settings:IsDebugEnabled())
        print("Better Gear Advisor debug: " .. (settings:IsDebugEnabled() and "on" or "off"))
    elseif command == "export" then
        print(BGA.Presentation.DebugPresenter.Summary(diagnostics))
    elseif command == "status" then
        print("Better Gear Advisor " .. BGA.version
            .. ": initialized=" .. tostring(BGA.initialized == true)
            .. ", tooltipRegistered=" .. tostring(tooltipAdapter.registrationSucceeded == true))
        print(BGA.Presentation.DebugPresenter.Summary(diagnostics))
    else
        print("Better Gear Advisor " .. BGA.version .. ": " .. BGA.Generated.ArtifactManifest.reason)
        print("Commands: /bga status | /bga export | /bga debug")
    end
end

BGA.runtime = {
    revisions = revisions,
    diagnostics = diagnostics,
    settings = settings,
    itemRepository = itemRepository,
    futureRankResolver = futureRankResolver,
    coordinator = coordinator,
    tooltipController = tooltipController,
    eventAdapter = eventAdapter,
}
BGA.initialized = true
diagnostics:Record("bootstrap-complete")

print("Better Gear Advisor " .. BGA.version .. " loaded; Arms/AoE model is not validated yet.")
