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
    [string]$PackageBaseName
    [string]$StagingFolderPath
    [string]$PluginModulePath
    [string]$PaletteFileName

    ModuleVariant(
        [string]$variantKey,
        [string]$variantName,
        [string]$releaseDisplayName,
        [string]$packageBaseName,
        [string]$stagingFolderPath,
        [string]$pluginModulePath,
        [string]$paletteFileName
    ) {
        $this.VariantKey = $variantKey
        $this.VariantName = $variantName
        $this.ReleaseDisplayName = $releaseDisplayName
        $this.PackageBaseName = $packageBaseName
        $this.StagingFolderPath = $stagingFolderPath
        $this.PluginModulePath = $pluginModulePath
        $this.PaletteFileName = $paletteFileName
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
}

$Global:Variants = @(
    [ModuleVariant]::new(
        "TA",
        "Trackers Alliance",
        "Venworks - Customizable HUD - Trackers Alliance Theme",
        "Venworks-CustomizableHUD-TrackersAlliance",
        "./Staging-TA",
        "$ENV:MODULE_VARIANT_TA_PATH",
        "trackers-alliance.xml"
    )

    [ModuleVariant]::new(
        "FC",
        "Freestar Collective",
        "Venworks - Customizable HUD - Freestar Collective Theme",
        "Venworks-CustomizableHUD-FreestarCollective",
        "./Staging-FC",
        "$ENV:MODULE_VARIANT_FC_PATH",
        "freestar-collective.xml"
    )

    [ModuleVariant]::new(
        "CF",
        "Crimson Fleet",
        "Venworks - Customizable HUD - Crimson Fleet Theme",
        "Venworks-CustomizableHUD-CrimsonFleet",
        "./Staging-CF",
        "$ENV:MODULE_VARIANT_CF_PATH",
        "crimson-fleet.xml"
    )

    [ModuleVariant]::new(
        "VWKS",
        "Venworks",
        "Venworks - Customizable HUD - Venworks Theme",
        "Venworks-CustomizableHUD-Venworks",
        "./Staging-VWKS",
        "$ENV:MODULE_VARIANT_VWKS_PATH",
        "venworks.xml"
    )
)

$Global:SharedConfigurationLoaded=$true
