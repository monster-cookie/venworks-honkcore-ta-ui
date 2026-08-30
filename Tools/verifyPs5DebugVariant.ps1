<#
.SYNOPSIS
Verifies the isolated PS5 Debug staging payload and its two uncompressed Main archives.

.PARAMETER Committed
Verifies the tracked staging directory without requiring a local junction target.
#>
[CmdletBinding()]
param(
  [switch]$Committed
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

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

function Resolve-RequiredDirectory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if (!(Test-Path -LiteralPath $Path -PathType Container)) {
    throw "$Description does not exist: $Path"
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-RepositoryPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath) -or
      [System.IO.Path]::IsPathRooted($RelativePath) -or
      $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "$Description must define a safe repository-relative path: $RelativePath"
  }

  $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
  $repositoryPrefix = $repositoryRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  ) + [System.IO.Path]::DirectorySeparatorChar
  if (!$resolvedPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description resolves outside the repository: $resolvedPath"
  }
  return $resolvedPath
}

function Get-Sha256 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Read-ExpectedSha256 {
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

function Get-ByteArraySha256 {
  param(
    [Parameter(Mandatory = $true)]
    [byte[]]$Bytes
  )

  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    return [System.BitConverter]::ToString($sha256.ComputeHash($Bytes)).Replace('-', '')
  }
  finally {
    $sha256.Dispose()
  }
}

function Assert-NotGitLfsPointer {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $resolvedPath = Resolve-RequiredFile -Path $Path -Description $Description
  $stream = [System.IO.File]::OpenRead($resolvedPath)
  try {
    $buffer = [byte[]]::new([Math]::Min(128, [int]$stream.Length))
    [void]$stream.Read($buffer, 0, $buffer.Length)
  }
  finally {
    $stream.Dispose()
  }
  $prefix = [System.Text.Encoding]::UTF8.GetString($buffer)
  if ($prefix.StartsWith("version https://git-lfs.github.com/spec/v1", [System.StringComparison]::Ordinal)) {
    throw "$Description remains a Git LFS pointer: $resolvedPath"
  }
}

function Get-RelativeFileInventory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath
  )

  $resolvedRoot = Resolve-RequiredDirectory -Path $RootPath -Description "PS5 Debug staging directory"
  return @(
    Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File |
      ForEach-Object {
        $_.FullName.Substring($resolvedRoot.Length + 1).Replace(
          [System.IO.Path]::DirectorySeparatorChar,
          [System.IO.Path]::AltDirectorySeparatorChar
        )
      } |
      Sort-Object
  )
}

function Assert-Inventory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [string[]]$ExpectedPaths,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $actualPaths = @(Get-RelativeFileInventory -RootPath $RootPath)
  $expectedPaths = @($ExpectedPaths | Sort-Object)
  if ($actualPaths.Count -ne $expectedPaths.Count -or
      [string]::Join("`n", $actualPaths) -cne [string]::Join("`n", $expectedPaths)) {
    throw "$Description contains an unexpected file inventory. Expected $($expectedPaths.Count) files; found $($actualPaths.Count)."
  }
}

function Get-GeneralBa2Entries {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $stream = [System.IO.File]::OpenRead($Path)
  $reader = [System.IO.BinaryReader]::new($stream, [System.Text.Encoding]::UTF8, $true)
  try {
    if ([System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -cne 'BTDX') {
      throw "Archive is missing the BTDX signature: $Path"
    }
    $version = $reader.ReadUInt32()
    $archiveType = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
    $fileCount = $reader.ReadUInt32()
    $nameTableOffset = $reader.ReadUInt64()
    if ($version -ne 2 -or $archiveType -cne 'GNRL' -or
        $fileCount -gt 10000 -or $nameTableOffset -ge [uint64]$stream.Length) {
      throw "Archive is not a supported version 2 General BA2: $Path"
    }
    [void]$reader.ReadUInt64()

    $records = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $fileCount; $index++) {
      [void]$reader.ReadUInt32()
      [void]$reader.ReadBytes(4)
      [void]$reader.ReadUInt32()
      [void]$reader.ReadUInt32()
      $offset = $reader.ReadUInt64()
      $packedSize = $reader.ReadUInt32()
      $unpackedSize = $reader.ReadUInt32()
      [void]$reader.ReadUInt32()
      $storedSize = if ($packedSize -eq 0) { $unpackedSize } else { $packedSize }
      if ($offset -lt 32 + ($fileCount * 36) -or
          $offset + $storedSize -gt $nameTableOffset) {
        throw "Archive contains an invalid file record at index ${index}: $Path"
      }
      $records.Add([pscustomobject]@{
        Offset = $offset
        PackedSize = $packedSize
        UnpackedSize = $unpackedSize
      })
    }

    $stream.Position = [int64]$nameTableOffset
    for ($index = 0; $index -lt $fileCount; $index++) {
      $nameLength = $reader.ReadUInt16()
      if ($nameLength -eq 0 -or $stream.Position + $nameLength -gt $stream.Length) {
        throw "Archive contains an invalid name record at index ${index}: $Path"
      }
      $name = [System.Text.Encoding]::UTF8.GetString($reader.ReadBytes($nameLength)).Replace('\', '/')
      $records[$index] | Add-Member -NotePropertyName Name -NotePropertyValue $name
      $records[$index] | Add-Member -NotePropertyName ArchivePath -NotePropertyValue $Path
    }
    return @($records)
  }
  finally {
    $reader.Dispose()
    $stream.Dispose()
  }
}

function Read-GeneralBa2EntryBytes {
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$Entry
  )

  $stream = [System.IO.File]::OpenRead([string]$Entry.ArchivePath)
  try {
    $stream.Position = [int64]$Entry.Offset
    $storedSize = if ([uint32]$Entry.PackedSize -eq 0) {
      [uint32]$Entry.UnpackedSize
    }
    else {
      [uint32]$Entry.PackedSize
    }
    $storedBytes = [byte[]]::new([int]$storedSize)
    $readCount = $stream.Read($storedBytes, 0, $storedBytes.Length)
    if ($readCount -ne $storedBytes.Length) {
      throw "Unable to read BA2 entry '$($Entry.Name)' from $($Entry.ArchivePath)."
    }
  }
  finally {
    $stream.Dispose()
  }

  if ([uint32]$Entry.PackedSize -ne 0) {
    throw "PS5 Debug BA2 entry '$($Entry.Name)' must be stored with compression=None."
  }
  return $storedBytes
}

function Get-ScaleformMovieInspection {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $movieBytes = Get-ScaleformMovieUncompressedBytes -Path $Path
  if ($movieBytes.Length -lt 14) {
    throw "$Context is too short to contain a frame header and tags."
  }
  $rectBitCount = 5 + (4 * ([int]$movieBytes[8] -shr 3))
  $rectByteCount = [int][Math]::Ceiling($rectBitCount / 8.0)
  $tagOffset = 8 + $rectByteCount + 4
  if ($tagOffset -ge $movieBytes.Length) {
    throw "$Context contains an invalid frame header."
  }

  $abcCount = 0
  $endTagFound = $false
  while ($tagOffset + 2 -le $movieBytes.Length) {
    $tagHeader = [int]$movieBytes[$tagOffset] -bor ([int]$movieBytes[$tagOffset + 1] -shl 8)
    $tagOffset += 2
    $tagCode = $tagHeader -shr 6
    $tagLength = $tagHeader -band 0x3F
    if ($tagLength -eq 0x3F) {
      if ($tagOffset + 4 -gt $movieBytes.Length) {
        throw "$Context contains a truncated long tag header."
      }
      $tagLength = [System.BitConverter]::ToUInt32($movieBytes, $tagOffset)
      $tagOffset += 4
    }
    if ([uint64]$tagOffset + [uint64]$tagLength -gt [uint64]$movieBytes.Length) {
      throw "$Context contains a tag that extends beyond the movie."
    }
    if ($tagCode -eq 72 -or $tagCode -eq 82) {
      $abcCount++
    }
    $tagOffset += [int]$tagLength
    if ($tagCode -eq 0) {
      $endTagFound = $true
      break
    }
  }
  if (!$endTagFound) {
    throw "$Context does not contain a terminating End tag."
  }

  return [pscustomobject]@{
    AbcCount = $abcCount
    Text = [System.Text.Encoding]::UTF8.GetString($movieBytes)
  }
}

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  if ($Committed) {
    . (Join-Path $PSScriptRoot "sharedConfig.ps1") -SkipEnvironment
  }
  else {
    . (Join-Path $PSScriptRoot "sharedConfig.ps1")
  }
}
. (Join-Path $PSScriptRoot "sharedScaleformMovies.ps1")

$diagnosticVariants = @($Global:DiagnosticVariants)
if ($diagnosticVariants.Count -ne 1 -or [string]$diagnosticVariants[0].VariantKey -cne 'PS5DBG') {
  throw "DiagnosticVariants must contain only the isolated PS5DBG variant."
}
$variant = @(Get-DiagnosticVariants -VariantKeys 'PS5DBG')[0]
if ([string]$variant.VariantName -cne 'PS5 Debug' -or
    [string]$variant.ReleaseDisplayName -cne 'Venworks - Customizable HUD - PS5 Debug' -or
    [string]$variant.PackageBaseName -cne 'Venworks-CustomizableHUD-PS5Debug' -or
    [string]$variant.StagingFolderPath -cne './Staging-PS5DBG' -or
    ![string]::IsNullOrEmpty([string]$variant.NexusNormalDisplayName) -or
    ![string]::IsNullOrEmpty([string]$variant.NexusLooseDisplayName) -or
    ![string]::IsNullOrEmpty([string]$variant.PaletteFileName) -or
    [string]::Join("`n", @($variant.ArchiveTargets)) -cne "Main`nMain_PS") {
  throw "The PS5 Debug diagnostic variant metadata has drifted from its isolated PC-and-PS5 contract."
}

$profilePath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot 'Scaleform/variants/PS5DBG/build.psd1') `
  -Description 'PS5 Debug build profile'
$buildProfile = Import-PowerShellDataFile -LiteralPath $profilePath
if (@($buildProfile.Keys | Sort-Object).Count -ne 2 -or
    @($buildProfile.MovieManifestPaths).Count -ne 4 -or
    @($buildProfile.MovieManifestPaths | Select-Object -Unique).Count -ne 4 -or
    [string]$buildProfile.PluginSourcePath -cne 'Staging-TA/Venworks-CustomizableHUD-TrackersAlliance.esm') {
  throw "The PS5 Debug build profile must contain only four movie manifests and the canonical plugin source."
}

$expectedManifestDefinitions = [ordered]@{
  'hudmenu.gfx' = [pscustomobject]@{ Signature = 'GFX'; InputFile = 'hudmenu.gfx'; VanillaHashFile = '../../../hudmenu/vanilla.sha256'; ExpectedHashFile = 'hudmenu.expected.sha256' }
  'hudmenu.swf' = [pscustomobject]@{ Signature = 'CWS'; InputFile = 'hudmenu.swf'; VanillaHashFile = '../../../hudmenu/vanilla-swf.sha256'; ExpectedHashFile = 'hudmenu-swf.expected.sha256' }
  'hudmenu_lrg.gfx' = [pscustomobject]@{ Signature = 'GFX'; InputFile = 'hudmenu_lrg.gfx'; VanillaHashFile = '../../../hudmenu_lrg/vanilla.sha256'; ExpectedHashFile = 'hudmenu-lrg.expected.sha256' }
  'hudmenu_lrg.swf' = [pscustomobject]@{ Signature = 'CWS'; InputFile = 'hudmenu_lrg.swf'; VanillaHashFile = '../../../hudmenu_lrg/vanilla-swf.sha256'; ExpectedHashFile = 'hudmenu-lrg-swf.expected.sha256' }
}

$movieDefinitions = @{}
foreach ($manifestRelativePath in @($buildProfile.MovieManifestPaths)) {
  $manifestPath = Resolve-RequiredFile `
    -Path (Resolve-RepositoryPath -RelativePath ([string]$manifestRelativePath) -Description 'PS5 Debug movie manifest') `
    -Description 'PS5 Debug movie manifest'
  [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
  $build = $manifest.scaleformBuild
  $outputFile = [string]$build.outputFile
  if (!$expectedManifestDefinitions.Contains($outputFile)) {
    throw "PS5 Debug manifest declares unexpected output '$outputFile'."
  }
  $expectedDefinition = $expectedManifestDefinitions[$outputFile]
  if ([string]$build.GetAttribute('mode') -cne 'ps5-debug-hudmenu' -or
      [string]$build.inputFile -cne [string]$expectedDefinition.InputFile -or
      [string]$build.vanillaHashFile -cne [string]$expectedDefinition.VanillaHashFile -or
      [string]$build.expectedHashFile -cne [string]$expectedDefinition.ExpectedHashFile -or
      [string]$build.actionScriptPatch -cne '../patches/ps5-debug-pane.xml') {
    throw "PS5 Debug manifest for '$outputFile' has drifted from the direct Bethesda HUDMenu patch contract."
  }
  $expectedHashPath = Resolve-RequiredFile `
    -Path (Join-Path (Split-Path -Parent $manifestPath) ([string]$build.expectedHashFile)) `
    -Description "PS5 Debug $outputFile expected hash"
  $movieDefinitions[$outputFile] = [pscustomobject]@{
    Signature = [string]$expectedDefinition.Signature
    ExpectedHashPath = $expectedHashPath
  }
}
if ($movieDefinitions.Count -ne 4) {
  throw "PS5 Debug manifests must resolve exactly four unique HUD movies."
}

$stagingFolderPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot ([string]$variant.StagingFolderPath)))
$stagingFolder = Resolve-RequiredDirectory -Path $stagingFolderPath -Description 'PS5 Debug staging folder'
$stagingPath = $stagingFolder
if (!$Committed) {
  $stagingItem = Get-Item -LiteralPath $stagingFolderPath
  if ($stagingItem.LinkType -ne 'Junction') {
    throw "PS5 Debug staging folder must be a Junction: $stagingFolderPath"
  }
  $stagingTargets = @($stagingItem.Target)
  if ($stagingTargets.Count -ne 1) {
    throw "PS5 Debug staging Junction must have exactly one target."
  }
  $junctionTargetPath = Resolve-RequiredDirectory -Path ([string]$stagingTargets[0]) -Description 'PS5 Debug staging Junction target'
  $modulePath = Resolve-RequiredDirectory -Path ([string]$variant.PluginModulePath) -Description 'PS5 Debug physical module folder'
  if (![string]::Equals($junctionTargetPath, $modulePath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PS5 Debug staging Junction does not target its configured physical module folder."
  }
}

$pluginName = "$($variant.PackageBaseName).esm"
$archiveNames = @(
  "$($variant.PackageBaseName) - Main.ba2",
  "$($variant.PackageBaseName) - Main_PS.ba2"
)
$movieNames = @($expectedManifestDefinitions.Keys)
$expectedStagingInventory = @($pluginName) + $archiveNames + @($movieNames | ForEach-Object { "Interface/$_" })
Assert-Inventory `
  -RootPath $stagingPath `
  -ExpectedPaths $expectedStagingInventory `
  -Description 'PS5 Debug staging payload'

$pluginPath = Resolve-RequiredFile -Path (Join-Path $stagingPath $pluginName) -Description 'PS5 Debug plugin'
$canonicalPluginPath = Resolve-RequiredFile `
  -Path (Resolve-RepositoryPath -RelativePath ([string]$buildProfile.PluginSourcePath) -Description 'Canonical plugin source') `
  -Description 'Canonical plugin source'
Assert-NotGitLfsPointer -Path $canonicalPluginPath -Description 'Canonical plugin source'
Assert-NotGitLfsPointer -Path $pluginPath -Description 'PS5 Debug plugin'
if ((Get-Sha256 -Path $pluginPath) -cne (Get-Sha256 -Path $canonicalPluginPath)) {
  throw "PS5 Debug plugin must remain byte-identical to the canonical stub while using its unique filename."
}

$requiredTokens = @(
  'PS5DBG-01 CONSTRUCTED',
  'PS5DBG-02 ADDED TO STAGE',
  'PS5DBG-OK HUD LOADED',
  'PS5DBG-ERR UNCAUGHT',
  '$MAIN_Font_Bold',
  'uncaughtErrorEvents'
)
$forbiddenTokens = @(
  'VenworksCUI',
  'venworks.cui',
  'venworkscui.swf',
  'CUILayout',
  'CUISvg',
  'CUIPalette',
  'CUIPlayerHudDataContext'
)
foreach ($movieName in $movieNames) {
  $moviePath = Resolve-RequiredFile -Path (Join-Path (Join-Path $stagingPath 'Interface') $movieName) -Description "PS5 Debug $movieName"
  $movieDefinition = $movieDefinitions[$movieName]
  $expectedHash = Read-ExpectedSha256 -Path ([string]$movieDefinition.ExpectedHashPath)
  $actualHash = Get-Sha256 -Path $moviePath
  if ($actualHash -cne $expectedHash) {
    throw "PS5 Debug $movieName hash mismatch. Expected $expectedHash; found $actualHash."
  }
  $metadata = Get-ScaleformMovieMetadata `
    -Path $moviePath `
    -Context "PS5 Debug $movieName" `
    -ExpectedSignature ([string]$movieDefinition.Signature)
  if ($metadata.StageWidth -ne 1920 -or
      $metadata.StageHeight -ne 1080 -or
      $metadata.FrameRate -ne 30 -or
      $metadata.FrameCount -ne 1) {
    throw "PS5 Debug $movieName must be 1920x1080 at 30 fps with one frame."
  }
  $inspection = Get-ScaleformMovieInspection -Path $moviePath -Context "PS5 Debug $movieName"
  if ($inspection.AbcCount -ne 1) {
    throw "PS5 Debug $movieName must contain exactly one Bethesda ABC; found $($inspection.AbcCount)."
  }
  foreach ($requiredToken in $requiredTokens) {
    if (!$inspection.Text.Contains($requiredToken)) {
      throw "PS5 Debug $movieName is missing diagnostic bytecode token '$requiredToken'."
    }
  }
  foreach ($forbiddenToken in $forbiddenTokens) {
    if ($inspection.Text.Contains($forbiddenToken)) {
      throw "PS5 Debug $movieName contains forbidden CUI bytecode token '$forbiddenToken'."
    }
  }
}

$expectedArchiveEntries = @($movieNames | ForEach-Object { "interface/$($_.ToLowerInvariant())" } | Sort-Object)
foreach ($archiveName in $archiveNames) {
  $archivePath = Resolve-RequiredFile -Path (Join-Path $stagingPath $archiveName) -Description "PS5 Debug archive $archiveName"
  Assert-NotGitLfsPointer -Path $archivePath -Description "PS5 Debug archive $archiveName"
  $entries = @(Get-GeneralBa2Entries -Path $archivePath)
  $actualArchiveEntries = @($entries | ForEach-Object { ([string]$_.Name).ToLowerInvariant() } | Sort-Object)
  if ($actualArchiveEntries.Count -ne $expectedArchiveEntries.Count -or
      [string]::Join("`n", $actualArchiveEntries) -cne [string]::Join("`n", $expectedArchiveEntries)) {
    throw "PS5 Debug archive $archiveName does not contain the exact four-movie Interface payload."
  }
  foreach ($entry in $entries) {
    if ([uint32]$entry.PackedSize -ne 0) {
      throw "PS5 Debug archive $archiveName contains compressed entry '$($entry.Name)'."
    }
    $movieName = [System.IO.Path]::GetFileName(([string]$entry.Name).Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    $stagedMoviePath = Resolve-RequiredFile `
      -Path (Join-Path (Join-Path $stagingPath 'Interface') $movieName) `
      -Description "PS5 Debug staged movie $movieName"
    $archiveEntryHash = Get-ByteArraySha256 -Bytes (Read-GeneralBa2EntryBytes -Entry $entry)
    if ($archiveEntryHash -cne (Get-Sha256 -Path $stagedMoviePath)) {
      throw "PS5 Debug archive $archiveName entry '$($entry.Name)' is not byte-identical to the staged movie."
    }
  }
}

Write-Host -ForegroundColor Cyan "Verified the isolated PS5 Debug plugin, four one-ABC HUD movies, and two uncompressed Main archives."
