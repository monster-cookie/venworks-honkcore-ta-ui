<#
.SYNOPSIS
Creates the uncompressed Windows and PS5 Main archives for the isolated PS5 debug variant.

.PARAMETER Committed
Uses the tracked staging directory without requiring a local junction target.
#>
[CmdletBinding()]
param(
  [switch]$Committed
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  if ($Committed) {
    . (Join-Path $PSScriptRoot "sharedConfig.ps1") -SkipEnvironment
  }
  else {
    . (Join-Path $PSScriptRoot "sharedConfig.ps1")
  }
}
. (Join-Path $PSScriptRoot "sharedScaleformMovies.ps1")

function Resolve-RequiredFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Description does not exist: $Path"
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function Read-Sha256File {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $hashLine = Get-Content -LiteralPath $Path | Where-Object {
    $_ -match '^\s*[A-Fa-f0-9]{64}(?:\s|$)'
  } | Select-Object -First 1
  if (!$hashLine) {
    throw "No SHA-256 value was found in $Path."
  }
  return ([regex]::Match($hashLine, '[A-Fa-f0-9]{64}').Value).ToUpperInvariant()
}

function Assert-NotGitLfsPointer {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $prefix = [System.Text.Encoding]::UTF8.GetString($bytes, 0, [Math]::Min(128, $bytes.Length))
  if ($prefix.StartsWith("version https://git-lfs.github.com/spec/v1", [System.StringComparison]::Ordinal)) {
    throw "$Description remains a Git LFS pointer: $Path"
  }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$variant = @(Get-DiagnosticVariants -VariantKeys "PS5DBG")[0]
$profilePath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Scaleform\variants\PS5DBG\build.psd1") `
  -Description "PS5 Debug build profile"
$buildProfile = Import-PowerShellDataFile -LiteralPath $profilePath

if ([string]::IsNullOrWhiteSpace($ENV:TOOL_PATH_ARCHIVER)) {
  throw "TOOL_PATH_ARCHIVER must name the directory containing Archive2.exe."
}
$archive2Path = Resolve-RequiredFile `
  -Path (Join-Path $ENV:TOOL_PATH_ARCHIVER "Archive2.exe") `
  -Description "Archive2 executable"

$stagingFolderPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot ([string]$variant.StagingFolderPath)))
if (!(Test-Path -LiteralPath $stagingFolderPath -PathType Container)) {
  throw "PS5 Debug staging folder does not exist: $stagingFolderPath"
}
$stagingPath = (Resolve-Path -LiteralPath $stagingFolderPath).Path
if ($Committed) {
  $packageOutputPath = $stagingPath
}
else {
  $stagingItem = Get-Item -LiteralPath $stagingFolderPath
  if ($stagingItem.LinkType -ne "Junction") {
    throw "PS5 Debug staging folder must be a Junction: $stagingFolderPath"
  }
  $stagingTargets = @($stagingItem.Target)
  if ($stagingTargets.Count -ne 1) {
    throw "PS5 Debug staging Junction must have exactly one target."
  }
  if (!(Test-Path -LiteralPath $variant.PluginModulePath -PathType Container)) {
    throw "PS5 Debug physical module folder does not exist: $($variant.PluginModulePath)"
  }
  $junctionTargetPath = (Resolve-Path -LiteralPath ([string]$stagingTargets[0])).Path
  $packageOutputPath = (Resolve-Path -LiteralPath $variant.PluginModulePath).Path
  if (![string]::Equals($junctionTargetPath, $packageOutputPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PS5 Debug staging Junction does not target its configured physical module folder."
  }
}

$interfacePath = Join-Path $stagingPath "Interface"
if (!(Test-Path -LiteralPath $interfacePath -PathType Container)) {
  throw "PS5 Debug staged Interface directory does not exist: $interfacePath"
}
$expectedMovieNames = @('hudmenu.gfx', 'hudmenu.swf', 'hudmenu_lrg.gfx', 'hudmenu_lrg.swf') | Sort-Object
$actualMovieNames = @(
  Get-ChildItem -LiteralPath $interfacePath -Recurse -File |
    ForEach-Object { $_.FullName.Substring($interfacePath.Length + 1).Replace('\', '/') } |
    Sort-Object
)
if ([string]::Join("`n", $actualMovieNames) -cne [string]::Join("`n", $expectedMovieNames)) {
  throw "PS5 Debug staging must contain exactly the four declared HUD movies before archive mutation."
}

$manifestDefinitions = foreach ($manifestRelativePath in @($buildProfile.MovieManifestPaths)) {
  $manifestPath = Resolve-RequiredFile `
    -Path (Join-Path $repositoryRoot ([string]$manifestRelativePath)) `
    -Description "PS5 Debug movie manifest"
  [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
  $build = $manifest.scaleformBuild
  [pscustomobject]@{
    FileName = [string]$build.outputFile
    ExpectedHashPath = Resolve-RequiredFile `
      -Path (Join-Path (Split-Path -Parent $manifestPath) ([string]$build.expectedHashFile)) `
      -Description "PS5 Debug expected movie hash"
  }
}
if (@($manifestDefinitions).Count -ne 4) {
  throw "PS5 Debug build profile must resolve exactly four movie definitions."
}
foreach ($movie in $manifestDefinitions) {
  $moviePath = Resolve-RequiredFile `
    -Path (Join-Path $interfacePath ([string]$movie.FileName)) `
    -Description "PS5 Debug staged $($movie.FileName)"
  $expectedHash = Read-Sha256File -Path ([string]$movie.ExpectedHashPath)
  $actualHash = (Get-FileHash -LiteralPath $moviePath -Algorithm SHA256).Hash.ToUpperInvariant()
  if ($actualHash -cne $expectedHash) {
    throw "PS5 Debug staged $($movie.FileName) is not the declared diagnostic movie. Refusing to mutate archives."
  }
  $signature = if ([System.IO.Path]::GetExtension([string]$movie.FileName) -ceq '.gfx') { 'GFX' } else { 'CWS' }
  Assert-ScaleformMovieEncoding `
    -Path $moviePath `
    -Context "PS5 Debug staged $($movie.FileName)" `
    -ExpectedSignature $signature
}
Write-Host -ForegroundColor Green "Verified the PS5 Debug movie payload before archive mutation."

$pluginPath = Resolve-RequiredFile `
  -Path (Join-Path $stagingPath "$($variant.PackageBaseName).esm") `
  -Description "PS5 Debug root plugin"
Assert-NotGitLfsPointer -Path $pluginPath -Description "PS5 Debug root plugin"
$rootPluginNames = @(Get-ChildItem -LiteralPath $stagingPath -File -Filter '*.esm' | Select-Object -ExpandProperty Name)
if ($rootPluginNames.Count -ne 1 -or $rootPluginNames[0] -cne "$($variant.PackageBaseName).esm") {
  throw "PS5 Debug staging must contain only its unique root plugin identity."
}

$archiveDefinitions = @(
  [pscustomobject]@{ Target = 'Main'; Suffix = 'Main.ba2' },
  [pscustomobject]@{ Target = 'Main_PS'; Suffix = 'Main_PS.ba2' }
)
$allKnownSuffixes = @('Main.ba2', 'Textures.ba2', 'Main_XBox.ba2', 'Textures_XBox.ba2', 'Main_PS.ba2', 'Textures_PS.ba2')
foreach ($suffix in $allKnownSuffixes) {
  $archivePath = Join-Path $packageOutputPath "$($variant.PackageBaseName) - $suffix"
  if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
    Remove-Item -LiteralPath $archivePath -Force
  }
}

foreach ($archiveDefinition in $archiveDefinitions) {
  if ($archiveDefinition.Target -notin @($variant.ArchiveTargets)) {
    throw "PS5 Debug configuration does not declare archive target '$($archiveDefinition.Target)'."
  }
  $archivePath = Join-Path $packageOutputPath "$($variant.PackageBaseName) - $($archiveDefinition.Suffix)"
  $archiveArguments = @(
    $stagingPath,
    "-root=$stagingPath",
    "-create=$archivePath",
    '-format=General',
    '-compression=None',
    '-maxSizeMB=2048',
    '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2'
  )
  & $archive2Path @archiveArguments
  if (!(Test-Path -LiteralPath $archivePath -PathType Leaf) -or
      (Get-Item -LiteralPath $archivePath).Length -le 0) {
    throw "Archive2 did not create the PS5 Debug $($archiveDefinition.Target) archive: $archivePath"
  }
}

Write-Host -ForegroundColor Cyan "Created the isolated PS5 Debug Windows and PS5 Main archives."
