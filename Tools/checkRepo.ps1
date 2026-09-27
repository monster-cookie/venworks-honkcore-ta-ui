<#
.SYNOPSIS
Checks release metadata and verifies selected VWHUD Canvas consumer payloads.
#>
[CmdletBinding()]
param(
  [Alias('VariantKey')][string[]]$VariantKeys,
  [switch]$Committed
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  if ($Committed) {
    . (Join-Path $PSScriptRoot 'sharedConfig.ps1') -SkipEnvironment
  }
  else {
    . (Join-Path $PSScriptRoot 'sharedConfig.ps1')
  }
}
. (Join-Path $PSScriptRoot 'sharedCanvasConsumers.ps1')

$releaseVariants = @($Global:ReleaseVariants)
$expectedKeys = @('CF', 'FC', 'MIN', 'TA', 'VWKS')
$actualKeys = @($releaseVariants.VariantKey | Sort-Object)
if ([string]::Join("`n", $actualKeys) -cne [string]::Join("`n", $expectedKeys)) {
  throw "Release variants must be exactly: $($expectedKeys -join ', ')."
}

foreach ($property in @('VariantKey', 'VariantName', 'ReleaseDisplayName', 'NexusNormalDisplayName', 'NexusLooseDisplayName', 'PackageBaseName', 'StagingFolderPath')) {
  $values = @($releaseVariants | ForEach-Object { [string]$_.$property })
  if (@($values | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -ne 0) {
    throw "Every release variant must define $property."
  }
  if (@($values | Select-Object -Unique).Count -ne $values.Count) {
    throw "Release variant property $property must be unique."
  }
}

foreach ($variant in $releaseVariants) {
  $key = [string]$variant.VariantKey
  if (!(Test-CanvasConsumerVariant -Key $key)) {
    throw "Release variant '$key' is missing its Canvas consumer source."
  }
  if (([string]$variant.NexusNormalDisplayName).Length -gt 50 -or ([string]$variant.NexusLooseDisplayName).Length -gt 50) {
    throw "Variant '$key' exceeds the Nexus display-name limit."
  }
  if ([string]::Join("`n", @($variant.ArchiveTargets)) -cne [string]::Join("`n", @('Main', 'Main_XBox', 'Main_PS'))) {
    throw "Variant '$key' must publish exactly the PC, Xbox, and PS5 Main archives."
  }
  if (@(Get-VariantReleasePackageSuffixes -Variant $variant).Count -ne 5) {
    throw "Variant '$key' must publish exactly five release package shapes."
  }

  $variantSource = Join-Path $repositoryRoot "CanvasConsumer/variants/$key/VWHudVariant.as"
  $variantText = [IO.File]::ReadAllText($variantSource)
  $expectedNamespace = 'venworks.vwhud.' + $key.ToLowerInvariant()
  if (!$variantText.Contains("NAMESPACE:String = `"$expectedNamespace`"")) {
    throw "Variant '$key' does not declare namespace '$expectedNamespace'."
  }
  $spriggitRoot = Join-Path $repositoryRoot "Spriggit/$($variant.PackageBaseName).esm"
  if (!(Test-Path -LiteralPath $spriggitRoot -PathType Container)) {
    throw "Variant '$key' is missing its real plugin source: $spriggitRoot"
  }
}

$variantDirectories = @(
  Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'CanvasConsumer/variants') -Directory |
    Select-Object -ExpandProperty Name |
    Sort-Object
)
if ([string]::Join("`n", $variantDirectories) -cne [string]::Join("`n", $expectedKeys)) {
  throw 'Canvas consumer source directories must match the five release variants exactly.'
}

foreach ($retiredPath in @(
  'Scaleform',
  'Schemas',
  'Staging-PS5DBG',
  'Tools/buildVariantV2.ps1',
  'Tools/verifyVariantV2.ps1',
  'Tools/createPackagesV2.ps1',
  'Tools/createReleasePackagesV2.ps1',
  'Tools/verifyCommittedReleaseV2.ps1',
  'Tools/checkRepoV2.ps1'
)) {
  if (Test-Path -LiteralPath (Join-Path $repositoryRoot $retiredPath)) {
    throw "Retired v1 or PS5 diagnostic path remains: $retiredPath"
  }
}

$selected = @(Get-ModuleVariants -VariantKeys $VariantKeys)
& (Join-Path $PSScriptRoot 'verifyVariant.ps1') -VariantKeys @($selected.VariantKey) -Committed:$Committed

Write-Host -ForegroundColor Cyan 'Selected Variant Build Artifacts Are Valid'
