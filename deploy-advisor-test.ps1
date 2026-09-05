$ErrorActionPreference = "Stop"

$source = "C:\projects\BetterGearCompare\BetterGearAdvisor"
$targetRoot = "F:\G\World of Warcraft\_retail_\Interface\AddOns"
$target = Join-Path $targetRoot "BetterGearAdvisor"
$staging = Join-Path $targetRoot "BetterGearAdvisor.__codex_staging"

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "BetterGearAdvisor source folder not found: $source"
}
if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
    throw "WoW Retail AddOns folder not found: $targetRoot"
}

$resolvedRoot = [System.IO.Path]::GetFullPath($targetRoot).TrimEnd('\') + '\'
$resolvedTarget = [System.IO.Path]::GetFullPath($target)
$resolvedStaging = [System.IO.Path]::GetFullPath($staging)
if (-not $resolvedTarget.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing deployment outside the Retail AddOns folder: $resolvedTarget"
}
if (-not $resolvedStaging.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing staging outside the Retail AddOns folder: $resolvedStaging"
}

if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
}

Copy-Item -LiteralPath $source -Destination $staging -Recurse -Force
if (-not (Test-Path -LiteralPath (Join-Path $staging "BetterGearAdvisor.toc") -PathType Leaf)) {
    throw "Staged addon is missing BetterGearAdvisor.toc"
}

if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
}
Move-Item -LiteralPath $staging -Destination $target

$fileCount = (Get-ChildItem -LiteralPath $target -Recurse -File).Count
Write-Host "Deployed BetterGearAdvisor ($fileCount files) to $target"
