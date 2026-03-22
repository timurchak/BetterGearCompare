param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$releaseRoot = Join-Path $source "Release"
$stagingRoot = Join-Path $releaseRoot "staging"
$addonName = "BetterGearCompare"
$addonRoot = Join-Path $stagingRoot $addonName

$generatorScript = Join-Path $source "scripts\generate_wowhead_trinket_lua.py"
$generatedLuaPath = Join-Path $source "BetterGearCompare_TrinketData.lua"

function Get-PythonCommand {
    $candidates = @(
        @("python.exe"),
        @("py", "-3"),
        @("python")
    )

    foreach ($candidate in $candidates) {
        $command = $candidate[0]
        if (Get-Command $command -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    throw "Python was not found. Install Python or make python.exe/py available in PATH."
}

$tocPath = Join-Path $source "BetterGearCompare.toc"
if (-not (Test-Path $tocPath)) {
    throw "TOC file not found: $tocPath"
}

if (-not (Test-Path $generatorScript)) {
    throw "Generator script not found: $generatorScript"
}

$pythonCommand = Get-PythonCommand
Write-Host "Generating trinket data Lua file..."
if ($pythonCommand.Length -gt 1) {
    $pythonArgs = @($pythonCommand[1..($pythonCommand.Length - 1)]) + @($generatorScript)
    & $pythonCommand[0] @pythonArgs
} else {
    & $pythonCommand[0] $generatorScript
}

if (-not (Test-Path $generatedLuaPath)) {
    throw "Generated Lua file not found after running generator: $generatedLuaPath"
}

if (-not $Version) {
    $versionLine = Get-Content $tocPath | Where-Object { $_ -match '^## Version:\s*(.+)$' } | Select-Object -First 1
    $Version = if ($versionLine) { ($versionLine -replace '^## Version:\s*', '').Trim() } else { "dev" }
}

if (Test-Path $releaseRoot) {
    Remove-Item -Recurse -Force $releaseRoot
}

New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null

$files = @(
    "BetterGearCompare.toc",
    "BetterGearCompare.lua",
    "BetterGearCompare_Localization.lua",
    "BetterGearCompare_Constants.lua",
    "BetterGearCompare_DB.lua",
    "BetterGearCompare_Stats.lua",
    "BetterGearCompare_SpecRules.lua",
    "BetterGearCompare_TrinketData.lua",
    "BetterGearCompare_Compare.lua",
    "BetterGearCompare_Tooltip.lua",
    "BetterGearCompare_Options.lua",
    "BetterGearCompare_Icons.lua",
    "README.md"
)

foreach ($file in $files) {
    Copy-Item -Path (Join-Path $source $file) -Destination (Join-Path $addonRoot $file) -Force
}

$localeTarget = Join-Path $addonRoot "Locales"
New-Item -ItemType Directory -Path $localeTarget -Force | Out-Null
Copy-Item -Path (Join-Path $source "Locales\*") -Destination $localeTarget -Recurse -Force

$zipName = "{0}-{1}.zip" -f $addonName, $Version
$zipPath = Join-Path $releaseRoot $zipName

Compress-Archive -Path $addonRoot -DestinationPath $zipPath -Force

Write-Host "Created release archive: $zipPath"
