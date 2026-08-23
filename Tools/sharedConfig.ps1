[CmdletBinding()]
param(
  [switch]$SkipEnvironment
)

# Abort on first error
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

class ModuleVariant {
    [string]$VariantKey
    [string]$VariantName
    [string]$ReleaseDisplayName
    [string]$NexusNormalDisplayName
    [string]$NexusLooseDisplayName
    [string]$PackageBaseName
    [string]$StagingFolderPath
    [string]$PluginModulePath
    [string]$PaletteFileName
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
        [string]$paletteFileName,
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
        $this.PaletteFileName = $paletteFileName
        $this.ArchiveTargets = $archiveTargets
    }
}

if ([System.IO.Directory]::Exists("./Staging")) {
  if ((Get-Item -Path "./Staging").LinkType -ne "Junction") {
    Write-Host -ForegroundColor Red "Staging is no longer a Junction. Please delete it and rerun the setupRepo script."
    Exit
  }
}

if (!$SkipEnvironment) {
  If (![System.IO.File]::Exists(".env")) {
    Write-Host -ForegroundColor Red "ERROR: .env file must be created and configured to run this."
    Exit
  }

  Write-Host -ForegroundColor Green "Importing ENV Settings from .env file"
  Get-Content .env | ForEach-Object {
    $name, $value = $_.split('=')
    $name.trim() | Out-Null
    if (!$name.StartsWith('#') || ![string]::IsNullOrWhitespace($name) || ![string]::IsNullOrWhitespace($value)) {
      $value.trim() | Out-Null
      Set-Item -Path "env:$name" -Value "$value"
    }
  }

  Write-Host -ForegroundColor Yellow "`nSteam Settings:"
  Write-Host -ForegroundColor Yellow "Starfield game folder is set to $ENV:STEAM_GAME_FOLDER."
  Write-Host -ForegroundColor Yellow "Starfield data folder is set to $ENV:STEAM_DATA_FOLDER."

  Write-Host -ForegroundColor Yellow "`nModule Settings:"
  Write-Host -ForegroundColor Yellow "Trackers Alliance Variant Folder is $ENV:MODULE_VARIANT_TA_PATH"
  Write-Host -ForegroundColor Yellow "Freestar Collective Variant Folder is $ENV:MODULE_VARIANT_FC_PATH"
  Write-Host -ForegroundColor Yellow "Crimson Fleet Variant Folder is $ENV:MODULE_VARIANT_CF_PATH"
  Write-Host -ForegroundColor Yellow "Venworks Variant Folder is $ENV:MODULE_VARIANT_VWKS_PATH"
  Write-Host -ForegroundColor Yellow "Minimalist Variant Folder is $ENV:MODULE_VARIANT_MIN_PATH"
}

$releaseArchiveTargets = @(
    "Main",
    "Textures",
    "Main_XBox",
    "Textures_XBox",
    "Main_PS",
    "Textures_PS"
)

$Global:ReleaseVariants = @(
    [ModuleVariant]::new(
        "TA",
        "Trackers Alliance",
        "Venworks - Customizable HUD - Trackers Alliance Theme",
        "Venworks - HUD - TA Theme (Normal)",
        "Venworks - HUD - TA Theme (Loose)",
        "Venworks-CustomizableHUD-TrackersAlliance",
        "./Staging-TA",
        "$ENV:MODULE_VARIANT_TA_PATH",
        "trackers-alliance.xml",
        $releaseArchiveTargets
    )

    [ModuleVariant]::new(
        "FC",
        "Freestar Collective",
        "Venworks - Customizable HUD - Freestar Collective Theme",
        "Venworks - HUD - FC Theme (Normal)",
        "Venworks - HUD - FC Theme (Loose)",
        "Venworks-CustomizableHUD-FreestarCollective",
        "./Staging-FC",
        "$ENV:MODULE_VARIANT_FC_PATH",
        "freestar-collective.xml",
        $releaseArchiveTargets
    )

    [ModuleVariant]::new(
        "CF",
        "Crimson Fleet",
        "Venworks - Customizable HUD - Crimson Fleet Theme",
        "Venworks - HUD - CF Theme (Normal)",
        "Venworks - HUD - CF Theme (Loose)",
        "Venworks-CustomizableHUD-CrimsonFleet",
        "./Staging-CF",
        "$ENV:MODULE_VARIANT_CF_PATH",
        "crimson-fleet.xml",
        $releaseArchiveTargets
    )

    [ModuleVariant]::new(
        "VWKS",
        "Venworks",
        "Venworks - Customizable HUD - Venworks Theme",
        "Venworks - HUD - Venworks Theme (Normal)",
        "Venworks - HUD - Venworks Theme (Loose)",
        "Venworks-CustomizableHUD-Venworks",
        "./Staging-VWKS",
        "$ENV:MODULE_VARIANT_VWKS_PATH",
        "venworks.xml",
        $releaseArchiveTargets
    )
)

$Global:SpikeVariants = @(
    [ModuleVariant]::new(
        "MIN",
        "Minimalist",
        "Venworks - Customizable HUD - Minimalist",
        "Venworks - HUD - Minimalist (Normal)",
        "Venworks - HUD - Minimalist (Loose)",
        "Venworks-CustomizableHUD-Minimalist",
        "./Staging-MIN",
        "$ENV:MODULE_VARIANT_MIN_PATH",
        "",
        @("Main_PS")
    )
)

$Global:Variants = @($Global:ReleaseVariants)
$Global:AllVariants = @($Global:ReleaseVariants + $Global:SpikeVariants)

function Global:Get-ModuleVariants {
  [CmdletBinding()]
  param(
    [string[]]$VariantKey
  )

  if ($null -eq $VariantKey -or $VariantKey.Count -eq 0) {
    return @($Global:ReleaseVariants)
  }

  $normalizedKeys = @($VariantKey | ForEach-Object {
    if ([string]::IsNullOrWhiteSpace($_)) {
      throw "Variant keys cannot be empty."
    }
    $_.Trim().ToUpperInvariant()
  })
  if (@($normalizedKeys | Select-Object -Unique).Count -ne $normalizedKeys.Count) {
    throw "Variant keys cannot be repeated."
  }

  $selectedVariants = foreach ($normalizedKey in $normalizedKeys) {
    $matches = @($Global:AllVariants | Where-Object {
      [string]$_.VariantKey -eq $normalizedKey
    })
    if ($matches.Count -ne 1) {
      throw "Unknown module variant key '$normalizedKey'."
    }
    $matches[0]
  }

  return @($selectedVariants)
}

$Global:SharedConfigurationLoaded=$true
