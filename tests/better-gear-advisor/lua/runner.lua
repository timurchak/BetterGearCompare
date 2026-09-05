local root = arg[1] or "."
local addonRoot = root .. "\\BetterGearAdvisor\\"
local BGA = {}
BGA.__testRoot = root

local files = {
    "Core\\Constants.lua",
    "Core\\TableUtil.lua",
    "Core\\ReasonCodes.lua",
    "Core\\Keys.lua",
    "Core\\Result.lua",
    "Generated\\ArtifactManifest.lua",
    "Generated\\SeasonManifest.lua",
    "Generated\\CapabilityManifest.lua",
    "Domain\\ItemLink.lua",
    "Domain\\ItemSnapshot.lua",
    "Domain\\EffectClassifier.lua",
    "Domain\\EquipmentState.lua",
    "Domain\\CandidateEnumerator.lua",
    "Domain\\StateValidator.lua",
    "Domain\\ModelRegistry.lua",
    "Domain\\OrdinaryModel.lua",
    "Domain\\ConfidencePolicy.lua",
    "Domain\\RankProjector.lua",
    "Domain\\GearEvaluator.lua",
    "Ports\\ItemDataPort.lua",
    "Ports\\InventoryPort.lua",
    "Ports\\CharacterPort.lua",
    "Ports\\UpgradePort.lua",
    "Ports\\TooltipPort.lua",
    "Ports\\ClockPort.lua",
    "Blizzard\\ClockAdapter.lua",
    "Blizzard\\UpgradeAdapter.lua",
    "Blizzard\\InventoryAdapter.lua",
    "Blizzard\\CharacterAdapter.lua",
    "Blizzard\\ItemDataAdapter.lua",
    "Blizzard\\EventAdapter.lua",
    "Blizzard\\TooltipAdapter.lua",
    "Application\\Revisions.lua",
    "Application\\ItemRepository.lua",
    "Application\\EquipmentRepository.lua",
    "Application\\EvaluationCache.lua",
    "Application\\FutureRankResolver.lua",
    "Application\\EvaluationCoordinator.lua",
    "Application\\Diagnostics.lua",
    "Application\\Settings.lua",
    "Locale\\enUS.lua",
    "Locale\\ruRU.lua",
    "Presentation\\TooltipPresenter.lua",
    "Presentation\\TooltipController.lua",
    "Presentation\\DebugPresenter.lua",
}

for index = 1, #files do
    local chunk, loadError = loadfile(addonRoot .. files[index])
    if not chunk then
        error(loadError)
    end
    chunk("BetterGearAdvisor", BGA)
end

local passed = 0
local failed = 0

local function fail(message)
    error(message, 2)
end

local Assert = {}

function Assert.Equal(actual, expected, message)
    if actual ~= expected then
        fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

function Assert.True(value, message)
    if value ~= true then
        fail(message or ("expected true, got " .. tostring(value)))
    end
end

function Assert.Nil(value, message)
    if value ~= nil then
        fail(message or ("expected nil, got " .. tostring(value)))
    end
end

local function runTestFile(relativePath)
    local chunk, loadError = loadfile(root .. "\\tests\\better-gear-advisor\\lua\\" .. relativePath)
    if not chunk then
        error(loadError)
    end
    local tests = chunk(BGA, Assert)
    for name, test in pairs(tests) do
        local ok, testError = pcall(test)
        if ok then
            passed = passed + 1
            print("PASS " .. name)
        else
            failed = failed + 1
            print("FAIL " .. name .. ": " .. tostring(testError))
        end
    end
end

runTestFile("core\\CoreTests.lua")
runTestFile("domain\\DomainTests.lua")
runTestFile("domain\\ModelTests.lua")
runTestFile("domain\\ProjectionTests.lua")
runTestFile("application\\RepositoryTests.lua")
runTestFile("application\\FutureRankResolverTests.lua")
runTestFile("contracts\\AdapterTests.lua")
runTestFile("domain\\EvaluatorTests.lua")
runTestFile("application\\CoordinatorTests.lua")
runTestFile("presentation\\TooltipTests.lua")
runTestFile("contracts\\BootstrapSmokeTests.lua")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
