param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$releaseRoot = Join-Path $source "Release"
$stagingRoot = Join-Path $releaseRoot "staging"
$addonName = "BetterGearCompare"
$addonRoot = Join-Path $stagingRoot $addonName

$tocPath = Join-Path $source "BetterGearCompare.toc"
if (-not (Test-Path $tocPath)) {
    throw "TOC file not found: $tocPath"
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
