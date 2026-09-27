[CmdletBinding()]
param(
  [switch]$SkipEnvironment
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'

class ModuleVariant {
  [string]$VariantKey
  [string]$VariantName
  [string]$ReleaseDisplayName
  [string]$NexusNormalDisplayName
  [string]$NexusLooseDisplayName
  [string]$PackageBaseName
  [string]$StagingFolderPath
  [string]$PluginModulePath
  [string[]]$ArchiveTargets

  ModuleVariant(
    [string]$variantKey,
    [string]$variantName,
    [string]$releaseDisplayName,
    [string]$nexusNormalDisplayName,
    [string]$nexusLooseDisplayName,
    [string]$packageBaseName,
    [string]$stagingFolderPath,
    [string]$pluginModulePath,
    [string[]]$archiveTargets
  ) {
    $this.VariantKey = $variantKey
    $this.VariantName = $variantName
    $this.ReleaseDisplayName = $releaseDisplayName
    $this.NexusNormalDisplayName = $nexusNormalDisplayName
    $this.NexusLooseDisplayName = $nexusLooseDisplayName
    $this.PackageBaseName = $packageBaseName
    $this.StagingFolderPath = $stagingFolderPath
    $this.PluginModulePath = $pluginModulePath
    $this.ArchiveTargets = $archiveTargets
  }
}

if (!$SkipEnvironment) {
  if (![System.IO.File]::Exists('.env')) {
    throw 'A configured .env file is required for local staging operations.'
  }

  foreach ($line in Get-Content -LiteralPath '.env') {
    if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
      continue
    }
    $name = $Matches[1]
    $value = $Matches[2].Trim().Trim('"')
    Set-Item -Path "env:$name" -Value $value
  }
}

$archiveTargets = @('Main', 'Main_XBox', 'Main_PS')
$Global:ReleaseVariants = @(
  [ModuleVariant]::new('TA', 'Trackers Alliance', 'Venworks - Customizable HUD - Trackers Alliance Theme', 'Venworks - HUD - TA Theme (Normal)', 'Venworks - HUD - TA Theme (Loose)', 'Venworks-CustomizableHUD-TrackersAlliance', './Staging-TA', "$ENV:MODULE_VARIANT_TA_PATH", $archiveTargets)
  [ModuleVariant]::new('FC', 'Freestar Collective', 'Venworks - Customizable HUD - Freestar Collective Theme', 'Venworks - HUD - FC Theme (Normal)', 'Venworks - HUD - FC Theme (Loose)', 'Venworks-CustomizableHUD-FreestarCollective', './Staging-FC', "$ENV:MODULE_VARIANT_FC_PATH", $archiveTargets)
  [ModuleVariant]::new('CF', 'Crimson Fleet', 'Venworks - Customizable HUD - Crimson Fleet Theme', 'Venworks - HUD - CF Theme (Normal)', 'Venworks - HUD - CF Theme (Loose)', 'Venworks-CustomizableHUD-CrimsonFleet', './Staging-CF', "$ENV:MODULE_VARIANT_CF_PATH", $archiveTargets)
  [ModuleVariant]::new('VWKS', 'Venworks', 'Venworks - Customizable HUD - Venworks Theme', 'Venworks - HUD - Venworks Theme (Normal)', 'Venworks - HUD - Venworks Theme (Loose)', 'Venworks-CustomizableHUD-Venworks', './Staging-VWKS', "$ENV:MODULE_VARIANT_VWKS_PATH", $archiveTargets)
  [ModuleVariant]::new('MIN', 'Minimalist', 'Venworks - Customizable HUD - Minimalist', 'Venworks - HUD - Minimalist (Normal)', 'Venworks - HUD - Minimalist (Loose)', 'Venworks-CustomizableHUD-Minimalist', './Staging-MIN', "$ENV:MODULE_VARIANT_MIN_PATH", $archiveTargets)
)

function Global:Get-ModuleVariants {
  [CmdletBinding()]
  param(
    [Alias('VariantKey')]
    [string[]]$VariantKeys
  )

  if ($null -eq $VariantKeys -or $VariantKeys.Count -eq 0) {
    return @($Global:ReleaseVariants)
  }

  $normalizedKeys = @($VariantKeys | ForEach-Object {
    if ([string]::IsNullOrWhiteSpace($_)) {
      throw 'Variant keys cannot be empty.'
    }
    $_.Trim().ToUpperInvariant()
  })
  if (@($normalizedKeys | Select-Object -Unique).Count -ne $normalizedKeys.Count) {
    throw 'Variant keys cannot be repeated.'
  }

  $selected = foreach ($key in $normalizedKeys) {
    $matches = @($Global:ReleaseVariants | Where-Object { $_.VariantKey -ceq $key })
    if ($matches.Count -ne 1) {
      throw "Unknown module variant key '$key'."
    }
    $matches[0]
  }
  return @($selected)
}

function Global:Get-VariantReleasePackageSuffixes {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ModuleVariant]$Variant
  )

  if ('Main' -in $Variant.ArchiveTargets) {
    'Nexus PC - Normal'
    'Nexus PC - Fully Loose Files'
    'Bethesda PC'
  }
  if ('Main_XBox' -in $Variant.ArchiveTargets) {
    'Bethesda Xbox'
  }
  if ('Main_PS' -in $Variant.ArchiveTargets) {
    'Bethesda PS5'
  }
}

$Global:SharedConfigurationLoaded = $true
