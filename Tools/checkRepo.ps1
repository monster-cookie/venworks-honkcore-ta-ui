[CmdletBinding()]
param(
  [string[]]$VariantKey
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . "$PSScriptRoot\sharedConfig.ps1"
}

$expectedVariants = [ordered]@{
  "TA" = [ordered]@{
    VariantName = "Trackers Alliance"
    ReleaseDisplayName = "Venworks - Customizable HUD - Trackers Alliance Theme"
    NexusNormalDisplayName = "Venworks - HUD - TA Theme (Normal)"
    NexusLooseDisplayName = "Venworks - HUD - TA Theme (Loose)"
    PackageBaseName = "Venworks-CustomizableHUD-TrackersAlliance"
    StagingFolderPath = "./Staging-TA"
    PaletteFileName = "trackers-alliance.xml"
    ArchiveTargets = @("Main", "Textures", "Main_XBox", "Textures_XBox", "Main_PS", "Textures_PS")
  }
  "FC" = [ordered]@{
    VariantName = "Freestar Collective"
    ReleaseDisplayName = "Venworks - Customizable HUD - Freestar Collective Theme"
    NexusNormalDisplayName = "Venworks - HUD - FC Theme (Normal)"
    NexusLooseDisplayName = "Venworks - HUD - FC Theme (Loose)"
    PackageBaseName = "Venworks-CustomizableHUD-FreestarCollective"
    StagingFolderPath = "./Staging-FC"
    PaletteFileName = "freestar-collective.xml"
    ArchiveTargets = @("Main", "Textures", "Main_XBox", "Textures_XBox", "Main_PS", "Textures_PS")
  }
  "CF" = [ordered]@{
    VariantName = "Crimson Fleet"
    ReleaseDisplayName = "Venworks - Customizable HUD - Crimson Fleet Theme"
    NexusNormalDisplayName = "Venworks - HUD - CF Theme (Normal)"
    NexusLooseDisplayName = "Venworks - HUD - CF Theme (Loose)"
    PackageBaseName = "Venworks-CustomizableHUD-CrimsonFleet"
    StagingFolderPath = "./Staging-CF"
    PaletteFileName = "crimson-fleet.xml"
    ArchiveTargets = @("Main", "Textures", "Main_XBox", "Textures_XBox", "Main_PS", "Textures_PS")
  }
  "VWKS" = [ordered]@{
    VariantName = "Venworks"
    ReleaseDisplayName = "Venworks - Customizable HUD - Venworks Theme"
    NexusNormalDisplayName = "Venworks - HUD - Venworks Theme (Normal)"
    NexusLooseDisplayName = "Venworks - HUD - Venworks Theme (Loose)"
    PackageBaseName = "Venworks-CustomizableHUD-Venworks"
    StagingFolderPath = "./Staging-VWKS"
    PaletteFileName = "venworks.xml"
    ArchiveTargets = @("Main", "Textures", "Main_XBox", "Textures_XBox", "Main_PS", "Textures_PS")
  }
  "MIN" = [ordered]@{
    VariantName = "Minimalist"
    ReleaseDisplayName = "Venworks - Customizable HUD - Minimalist"
    NexusNormalDisplayName = "Venworks - HUD - Minimalist (Normal)"
    NexusLooseDisplayName = "Venworks - HUD - Minimalist (Loose)"
    PackageBaseName = "Venworks-CustomizableHUD-Minimalist"
    StagingFolderPath = "./Staging-MIN"
    PaletteFileName = ""
    ArchiveTargets = @("Main_PS")
  }
}

$variants = @(Get-ModuleVariants -VariantKey $VariantKey)
foreach ($variant in $variants) {
  if (!$expectedVariants.Contains([string]$variant.VariantKey)) {
    throw "Unexpected variant key '$($variant.VariantKey)'."
  }
  $expectedVariant = $expectedVariants[[string]$variant.VariantKey]
  foreach ($propertyName in @(
    "VariantName",
    "ReleaseDisplayName",
    "NexusNormalDisplayName",
    "NexusLooseDisplayName",
    "PackageBaseName",
    "StagingFolderPath",
    "PaletteFileName"
  )) {
    if ([string]$variant.$propertyName -cne [string]$expectedVariant[$propertyName]) {
      throw "Variant '$($variant.VariantKey)' must use $propertyName '$($expectedVariant[$propertyName])'; found '$($variant.$propertyName)'."
    }
  }
  foreach ($nexusPropertyName in @("NexusNormalDisplayName", "NexusLooseDisplayName")) {
    $displayName = [string]$variant.$nexusPropertyName
    if ([string]::IsNullOrWhiteSpace($displayName) -or $displayName.Length -gt 50) {
      throw "Variant '$($variant.VariantKey)' has an invalid Nexus display name in $nexusPropertyName."
    }
  }

  $actualArchiveTargets = @($variant.ArchiveTargets)
  $expectedArchiveTargets = @($expectedVariant.ArchiveTargets)
  if ($actualArchiveTargets.Count -ne $expectedArchiveTargets.Count) {
    throw "Variant '$($variant.VariantKey)' archive target count differs from its contract."
  }
  for ($index = 0; $index -lt $expectedArchiveTargets.Count; $index++) {
    if ([string]$actualArchiveTargets[$index] -cne [string]$expectedArchiveTargets[$index]) {
      throw "Variant '$($variant.VariantKey)' archive target mismatch. Expected '$($expectedArchiveTargets[$index])'; found '$($actualArchiveTargets[$index])'."
    }
  }
}

& (Join-Path $PSScriptRoot "verifyVariant.ps1") -VariantKey @($variants.VariantKey)

Write-Host -ForegroundColor Cyan "`n`n"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "**  Selected Variant Build Artifacts Are Valid  **"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "`n`n"
