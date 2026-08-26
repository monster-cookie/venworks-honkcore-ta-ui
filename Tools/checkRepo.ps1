<#
.SYNOPSIS
Checks shared release metadata and verifies selected variant artifacts.

.PARAMETER VariantKeys
One or more keys from `$Global:ReleaseVariants`. Omit this parameter to process
all release variants. `VariantKey` remains a compatibility alias.

.PARAMETER Committed
Verifies the tracked staging directories instead of requiring local junctions.
#>
[CmdletBinding()]
param(
  [Alias("VariantKey")]
  [string[]]$VariantKeys,

  [switch]$Committed
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  if ($Committed) {
    . "$PSScriptRoot\sharedConfig.ps1" -SkipEnvironment
  }
  else {
    . "$PSScriptRoot\sharedConfig.ps1"
  }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseVariants = @($Global:ReleaseVariants)
if ($releaseVariants.Count -ne 5) {
  throw "ReleaseVariants must contain all five release variants; found $($releaseVariants.Count)."
}

$requiredStringProperties = @(
  "VariantKey",
  "VariantName",
  "ReleaseDisplayName",
  "NexusNormalDisplayName",
  "NexusLooseDisplayName",
  "PackageBaseName",
  "StagingFolderPath",
  "PaletteFileName"
)
foreach ($propertyName in $requiredStringProperties) {
  $values = @($releaseVariants | ForEach-Object { [string]$_.$propertyName })
  if (@($values | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -ne 0) {
    throw "Every release variant must define $propertyName."
  }
  if ($propertyName -in @("VariantKey", "VariantName", "ReleaseDisplayName", "PackageBaseName", "StagingFolderPath") -and
      @($values | Select-Object -Unique).Count -ne $values.Count) {
    throw "Release variant property $propertyName must be unique."
  }
}

$allowedArchiveTargets = @("Main", "Textures", "Main_XBox", "Textures_XBox", "Main_PS", "Textures_PS")
$requiredMainTargets = @("Main", "Main_XBox", "Main_PS")
$forbiddenProfileProperties = @(
  "VariantKey",
  "VariantName",
  "ReleaseDisplayName",
  "NexusNormalDisplayName",
  "NexusLooseDisplayName",
  "PackageBaseName",
  "StagingFolderPath",
  "PluginModulePath",
  "PaletteFileName",
  "ArchiveTargets"
)
foreach ($variant in $releaseVariants) {
  foreach ($nexusPropertyName in @("NexusNormalDisplayName", "NexusLooseDisplayName")) {
    if (([string]$variant.$nexusPropertyName).Length -gt 50) {
      throw "Variant '$($variant.VariantKey)' exceeds the Nexus display-name limit in $nexusPropertyName."
    }
  }

  $archiveTargets = @($variant.ArchiveTargets)
  if ($archiveTargets.Count -eq 0 -or
      @($archiveTargets | Select-Object -Unique).Count -ne $archiveTargets.Count -or
      @($archiveTargets | Where-Object { $_ -notin $allowedArchiveTargets }).Count -ne 0) {
    throw "Variant '$($variant.VariantKey)' has invalid or repeated archive targets."
  }
  foreach ($requiredMainTarget in $requiredMainTargets) {
    if ($requiredMainTarget -notin $archiveTargets) {
      throw "Variant '$($variant.VariantKey)' must publish the $requiredMainTarget archive."
    }
  }

  $profilePath = Join-Path $repositoryRoot "Scaleform\variants\$($variant.VariantKey)\build.psd1"
  if (!(Test-Path -LiteralPath $profilePath -PathType Leaf)) {
    throw "Variant '$($variant.VariantKey)' is missing its build profile: $profilePath"
  }
  $variantBuildProfile = Import-PowerShellDataFile -LiteralPath $profilePath
  foreach ($forbiddenProperty in $forbiddenProfileProperties) {
    if ($variantBuildProfile.ContainsKey($forbiddenProperty)) {
      throw "Variant '$($variant.VariantKey)' build profile duplicates shared property '$forbiddenProperty'."
    }
  }
}

$profileKeys = @(
  Get-ChildItem -LiteralPath (Join-Path $repositoryRoot "Scaleform\variants") -Directory |
    Select-Object -ExpandProperty Name |
    Sort-Object
)
$releaseKeys = @($releaseVariants.VariantKey | Sort-Object)
if ([string]::Join("`n", $profileKeys) -cne [string]::Join("`n", $releaseKeys)) {
  throw "Scaleform profile directories must match ReleaseVariants exactly."
}

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)

& (Join-Path $PSScriptRoot "verifyVariant.ps1") `
  -VariantKeys @($variants.VariantKey) `
  -Committed:$Committed

Write-Host -ForegroundColor Cyan "`n`n"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "**  Selected Variant Build Artifacts Are Valid  **"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "`n`n"
