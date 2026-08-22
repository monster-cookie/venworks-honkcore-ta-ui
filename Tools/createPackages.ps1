# Abort on first error
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# If not loaded already pull in the shared config
if (!$Global:SharedConfigurationLoaded) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . "$PSScriptRoot/sharedConfig.ps1"
}

if ([string]::IsNullOrWhiteSpace($ENV:TOOL_PATH_ARCHIVER)) {
  throw "TOOL_PATH_ARCHIVER must name the directory containing Archive2.exe."
}
$archive2Path = Join-Path $ENV:TOOL_PATH_ARCHIVER "Archive2.exe"
if (!(Test-Path -LiteralPath $archive2Path -PathType Leaf)) {
  throw "Archive2.exe was not found at the TOOL_PATH_ARCHIVER location."
}

foreach ($variant in $Global:Variants) {
  if (!(Test-Path -LiteralPath $variant.StagingFolderPath -PathType Container)) {
    throw "$($variant.VariantName) staging folder does not exist: $($variant.StagingFolderPath)"
  }

  $stagingItem = Get-Item -LiteralPath $variant.StagingFolderPath
  if ($stagingItem.LinkType -ne "Junction") {
    throw "$($variant.VariantName) staging folder must be a Junction: $($variant.StagingFolderPath)"
  }
  $stagingPath = (Resolve-Path -LiteralPath $variant.StagingFolderPath).Path
  if (!(Test-Path -LiteralPath $variant.PluginModulePath -PathType Container)) {
    throw "$($variant.VariantName) physical module folder does not exist: $($variant.PluginModulePath)"
  }
  $packageOutputPath = (Resolve-Path -LiteralPath $variant.PluginModulePath).Path
  $stagingTargets = @($stagingItem.Target)
  if ($stagingTargets.Count -ne 1 -or
      ![string]::Equals(
        [System.IO.Path]::GetFullPath([string]$stagingTargets[0]),
        $packageOutputPath,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
    throw "$($variant.VariantName) staging Junction does not target its configured physical module folder."
  }
  $pluginPath = Join-Path $stagingPath "$($variant.PackageBaseName).esm"
  if (!(Test-Path -LiteralPath $pluginPath -PathType Leaf)) {
    throw "$($variant.VariantName) is missing its required root plugin: $pluginPath"
  }

  Write-Host -ForegroundColor Green "Creating $($variant.VariantName) archives from $stagingPath"

  $mainArchiveNames = @(
    "$($variant.PackageBaseName) - Main.ba2",
    "$($variant.PackageBaseName) - Main_XBox.ba2",
    "$($variant.PackageBaseName) - Main_PS.ba2"
  )
  $textureArchiveNames = @(
    "$($variant.PackageBaseName) - Textures.ba2",
    "$($variant.PackageBaseName) - Textures_XBox.ba2",
    "$($variant.PackageBaseName) - Textures_PS.ba2"
  )
  foreach ($archiveName in @($mainArchiveNames + $textureArchiveNames)) {
    $archivePath = Join-Path $packageOutputPath $archiveName
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
      Remove-Item -LiteralPath $archivePath -Force
    }
  }

  # Creating the Windows Archives and placing them in the variant Staging folder
  & $archive2Path "$stagingPath\" -root="$stagingPath\" -create="$packageOutputPath\$($variant.PackageBaseName) - Main.ba2" -format="General" -compression="Default" -maxSizeMB=2048 -excludeFilters=".*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2"
  & $archive2Path "$stagingPath\" -root="$stagingPath\" -create="$packageOutputPath\$($variant.PackageBaseName) - Textures.ba2" -format="DDS" -compression="Default" -maxSizeMB=2048 -includeFilters=".*\\.*\.dds"

  # Creating the XBox Archives and placing them in the variant Staging folder
  & $archive2Path "$stagingPath\" -root="$stagingPath\" -create="$packageOutputPath\$($variant.PackageBaseName) - Main_XBox.ba2" -format="General" -compression="XBox" -maxSizeMB=2048 -excludeFilters=".*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2"
  & $archive2Path "$stagingPath\" -root="$stagingPath\" -create="$packageOutputPath\$($variant.PackageBaseName) - Textures_XBox.ba2" -format="XBoxDDS" -compression="XBox" -maxSizeMB=2048 -includeFilters=".*\\.*\.dds"

  # Creating the PS Archives and placing them in the variant Staging folder (Currently Archiver2 has not been updated for PS support)
  & $archive2Path "$stagingPath\" -root="$stagingPath\" -create="$packageOutputPath\$($variant.PackageBaseName) - Main_PS.ba2" -format="General" -compression="Default" -maxSizeMB=2048 -excludeFilters=".*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2"
  & $archive2Path "$stagingPath\" -root="$stagingPath\" -create="$packageOutputPath\$($variant.PackageBaseName) - Textures_PS.ba2" -format="DDS" -compression="Default" -maxSizeMB=2048 -includeFilters=".*\\.*\.dds"

  foreach ($archiveName in $mainArchiveNames) {
    $archivePath = Join-Path $packageOutputPath $archiveName
    if (!(Test-Path -LiteralPath $archivePath -PathType Leaf)) {
      throw "Archive2 did not create the expected $($variant.VariantName) archive: $archivePath"
    }
    if ((Get-Item -LiteralPath $archivePath).Length -le 0) {
      throw "Archive2 created an empty $($variant.VariantName) archive: $archivePath"
    }
  }
  foreach ($archiveName in $textureArchiveNames) {
    $archivePath = Join-Path $packageOutputPath $archiveName
    if ((Test-Path -LiteralPath $archivePath -PathType Leaf) -and
        (Get-Item -LiteralPath $archivePath).Length -le 0) {
      throw "Archive2 created an empty $($variant.VariantName) archive: $archivePath"
    }
  }
}

Write-Host -ForegroundColor Cyan "`n`n"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "**  Variant BA2 Archives Created for All Targets **"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "`n`n"
