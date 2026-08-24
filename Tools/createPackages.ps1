[CmdletBinding()]
param(
  [string[]]$VariantKey,

  [switch]$Committed
)

# Abort on first error
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# If not loaded already pull in the shared config
if (!$Global:SharedConfigurationLoaded) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . "$PSScriptRoot/sharedConfig.ps1"
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

if ([string]::IsNullOrWhiteSpace($ENV:TOOL_PATH_ARCHIVER)) {
  throw "TOOL_PATH_ARCHIVER must name the directory containing Archive2.exe."
}
$archive2Path = Join-Path $ENV:TOOL_PATH_ARCHIVER "Archive2.exe"
if (!(Test-Path -LiteralPath $archive2Path -PathType Leaf)) {
  throw "Archive2.exe was not found at the TOOL_PATH_ARCHIVER location."
}

function Assert-NotGitLfsPointer {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $buffer = [byte[]]::new([Math]::Min(128, [int]$stream.Length))
    [void]$stream.Read($buffer, 0, $buffer.Length)
  }
  finally {
    $stream.Dispose()
  }
  $prefix = [System.Text.Encoding]::UTF8.GetString($buffer)
  if ($prefix.StartsWith("version https://git-lfs.github.com/spec/v1", [System.StringComparison]::Ordinal)) {
    throw "$Description remains a Git LFS pointer: $Path"
  }
}

$archiveDefinitions = [ordered]@{
  "Main" = [pscustomobject]@{
    FileSuffix = "Main.ba2"
    Format = "General"
    Compression = "Default"
    FilterArgument = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2'
    Required = $true
  }
  "Textures" = [pscustomobject]@{
    FileSuffix = "Textures.ba2"
    Format = "DDS"
    Compression = "Default"
    FilterArgument = '-includeFilters=.*\\.*\.dds'
    Required = $false
  }
  "Main_XBox" = [pscustomobject]@{
    FileSuffix = "Main_XBox.ba2"
    Format = "General"
    Compression = "XBox"
    FilterArgument = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2'
    Required = $true
  }
  "Textures_XBox" = [pscustomobject]@{
    FileSuffix = "Textures_XBox.ba2"
    Format = "XBoxDDS"
    Compression = "XBox"
    FilterArgument = '-includeFilters=.*\\.*\.dds'
    Required = $false
  }
  "Main_PS" = [pscustomobject]@{
    FileSuffix = "Main_PS.ba2"
    Format = "General"
    Compression = "Default"
    FilterArgument = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2'
    Required = $true
  }
  "Textures_PS" = [pscustomobject]@{
    FileSuffix = "Textures_PS.ba2"
    Format = "DDS"
    Compression = "Default"
    FilterArgument = '-includeFilters=.*\\.*\.dds'
    Required = $false
  }
}

$variants = @(Get-ModuleVariants -VariantKey $VariantKey)

foreach ($variant in $variants) {
  $stagingFolderPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $variant.StagingFolderPath))
  if (!(Test-Path -LiteralPath $stagingFolderPath -PathType Container)) {
    throw "$($variant.VariantName) staging folder does not exist: $stagingFolderPath"
  }

  $stagingPath = (Resolve-Path -LiteralPath $stagingFolderPath).Path
  if ($Committed) {
    $packageOutputPath = $stagingPath
  }
  else {
    $stagingItem = Get-Item -LiteralPath $stagingFolderPath
    if ($stagingItem.LinkType -ne "Junction") {
      throw "$($variant.VariantName) staging folder must be a Junction: $stagingFolderPath"
    }
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
  }
  $pluginPath = Join-Path $stagingPath "$($variant.PackageBaseName).esm"
  if (!(Test-Path -LiteralPath $pluginPath -PathType Leaf)) {
    throw "$($variant.VariantName) is missing its required root plugin: $pluginPath"
  }
  Assert-NotGitLfsPointer -Path $pluginPath -Description "$($variant.VariantName) root plugin"

  Write-Host -ForegroundColor Green "Creating $($variant.VariantName) archives from $stagingPath"

  $selectedArchiveTargets = @($variant.ArchiveTargets)
  if ($selectedArchiveTargets.Count -eq 0) {
    throw "$($variant.VariantName) does not define any archive targets."
  }
  if (@($selectedArchiveTargets | Select-Object -Unique).Count -ne $selectedArchiveTargets.Count) {
    throw "$($variant.VariantName) defines duplicate archive targets."
  }
  foreach ($archiveTarget in $selectedArchiveTargets) {
    if (!$archiveDefinitions.Contains([string]$archiveTarget)) {
      throw "$($variant.VariantName) defines unknown archive target '$archiveTarget'."
    }
  }

  foreach ($archiveDefinition in $archiveDefinitions.Values) {
    $archiveName = "$($variant.PackageBaseName) - $($archiveDefinition.FileSuffix)"
    $archivePath = Join-Path $packageOutputPath $archiveName
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
      Remove-Item -LiteralPath $archivePath -Force
    }
  }

  foreach ($archiveTarget in $selectedArchiveTargets) {
    $archiveDefinition = $archiveDefinitions[[string]$archiveTarget]
    $archiveName = "$($variant.PackageBaseName) - $($archiveDefinition.FileSuffix)"
    $archivePath = Join-Path $packageOutputPath $archiveName
    $archiveArguments = @(
      "$stagingPath\",
      "-root=$stagingPath\",
      "-create=$archivePath",
      "-format=$($archiveDefinition.Format)",
      "-compression=$($archiveDefinition.Compression)",
      "-maxSizeMB=2048",
      [string]$archiveDefinition.FilterArgument
    )
    & $archive2Path @archiveArguments

    if ($archiveDefinition.Required -and !(Test-Path -LiteralPath $archivePath -PathType Leaf)) {
      throw "Archive2 did not create the expected $($variant.VariantName) archive target '$archiveTarget': $archivePath"
    }
    if ((Test-Path -LiteralPath $archivePath -PathType Leaf) -and
        (Get-Item -LiteralPath $archivePath).Length -le 0) {
      throw "Archive2 created an empty $($variant.VariantName) archive: $archivePath"
    }
  }

  foreach ($archiveTarget in $archiveDefinitions.Keys) {
    if ($selectedArchiveTargets -contains $archiveTarget) {
      continue
    }
    $archiveDefinition = $archiveDefinitions[$archiveTarget]
    $archiveName = "$($variant.PackageBaseName) - $($archiveDefinition.FileSuffix)"
    $archivePath = Join-Path $packageOutputPath $archiveName
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
      throw "$($variant.VariantName) contains an archive outside its configured targets: $archivePath"
    }
  }
}

Write-Host -ForegroundColor Cyan "`n`n"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "** Variant BA2 Archives Created for Selected Targets **"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "`n`n"
