<#
.SYNOPSIS
Verifies staged or committed artifacts for release variants.

.PARAMETER VariantKeys
One or more keys from `$Global:ReleaseVariants`. Omit this parameter to process
all release variants. `VariantKey` remains a compatibility alias.

.PARAMETER PreArchiveMutation
Verifies each selected profile, complete staged Interface payload, movie, and
plugin without requiring or inspecting generated BA2 archives.
#>
[CmdletBinding()]
param(
  [Alias("VariantKey")]
  [string[]]$VariantKeys,

  [switch]$Committed,

  [switch]$PreArchiveMutation
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

  if ([uint32]$Entry.PackedSize -eq 0) {
    return $storedBytes
  }
  $compressedStream = [System.IO.MemoryStream]::new($storedBytes, $false)
  $uncompressedStream = [System.IO.MemoryStream]::new()
  try {
    $zlibStream = [System.IO.Compression.ZLibStream]::new(
      $compressedStream,
      [System.IO.Compression.CompressionMode]::Decompress,
      $true
    )
    try {
      $zlibStream.CopyTo($uncompressedStream)
    }
    finally {
      $zlibStream.Dispose()
    }
    $uncompressedBytes = $uncompressedStream.ToArray()
  }
  finally {
    $compressedStream.Dispose()
    $uncompressedStream.Dispose()
  }
  if ($uncompressedBytes.Length -ne [uint32]$Entry.UnpackedSize) {
    throw "BA2 entry '$($Entry.Name)' has an unexpected uncompressed length."
  }

  return $uncompressedBytes
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

function Assert-MatchingText {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedText,

    [Parameter(Mandatory = $true)]
    [string]$ActualPath,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $resolvedActualPath = Resolve-RequiredFile -Path $ActualPath -Description $Description
  $actualBytes = [System.IO.File]::ReadAllBytes($resolvedActualPath)
  if ($actualBytes.Length -ge 3 -and
      $actualBytes[0] -eq 0xEF -and
      $actualBytes[1] -eq 0xBB -and
      $actualBytes[2] -eq 0xBF) {
    throw "$Description must use UTF-8 without a byte-order mark."
  }
  $actualText = [System.Text.UTF8Encoding]::new($false, $true).GetString($actualBytes)
  if ($actualText.Contains("`r")) {
    throw "$Description must use canonical LF line endings."
  }
  $canonicalExpectedText = $ExpectedText.Replace("`r`n", "`n").Replace("`r", "`n")
  if ($actualText -cne $canonicalExpectedText) {
    throw "$Description differs from its profile-derived expected content."
  }
}

function Get-LiteralPaletteColors {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PalettePath
  )

  [xml]$palette = Get-Content -LiteralPath $PalettePath -Raw
  $colors = @{}
  foreach ($colorNode in @($palette.SelectNodes('/venworksCUIPalette/colors/color'))) {
    $role = [string]$colorNode.role
    $value = [string]$colorNode.value
    if ([string]::IsNullOrWhiteSpace($role) -or $value -notmatch '^#[0-9A-Fa-f]{6}$' -or $colors.ContainsKey($role)) {
      throw "Literal palette contains an invalid or duplicate color entry: $PalettePath"
    }
    $colors[$role] = $value
  }
  if ($colors.Count -eq 0) {
    throw "Literal palette does not define any colors: $PalettePath"
  }

  return $colors
}

function Resolve-PaletteColorReferences {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text,

    [Parameter(Mandatory = $true)]
    [hashtable]$ColorValues,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $resolvedText = $Text
  foreach ($referenceMatch in @([regex]::Matches(
    $resolvedText,
    '@palette\.colors\.([A-Za-z][A-Za-z0-9.-]*)'
  ))) {
    $role = [string]$referenceMatch.Groups[1].Value
    if (!$ColorValues.ContainsKey($role)) {
      throw "$Context references unknown palette color '$role'."
    }
    $resolvedText = $resolvedText.Replace([string]$referenceMatch.Value, [string]$ColorValues[$role])
  }
  if ($resolvedText -match '@palette\.') {
    throw "$Context retains an unresolved palette reference."
  }

  return $resolvedText
}

function Get-RelativeFileInventory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath
  )

  $resolvedRoot = Resolve-RequiredDirectory -Path $RootPath -Description "Payload directory"
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
  if ($actualPaths.Count -ne $expectedPaths.Count) {
    throw "$Description contains $($actualPaths.Count) files; expected $($expectedPaths.Count)."
  }
  for ($index = 0; $index -lt $expectedPaths.Count; $index++) {
    if ($actualPaths[$index] -cne $expectedPaths[$index]) {
      throw "$Description inventory mismatch. Expected '$($expectedPaths[$index])'; found '$($actualPaths[$index])'."
    }
  }
}

function Get-ScaleformMovieInspection {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $movieBytes = [System.IO.File]::ReadAllBytes($Path)
  $signature = [System.Text.Encoding]::ASCII.GetString($movieBytes, 0, 3)
  if ($signature -ceq "CWS") {
    $compressedStream = [System.IO.MemoryStream]::new(
      $movieBytes,
      8,
      $movieBytes.Length - 8,
      $false
    )
    $decompressedStream = [System.IO.MemoryStream]::new()
    try {
      $zlibStream = [System.IO.Compression.ZLibStream]::new(
        $compressedStream,
        [System.IO.Compression.CompressionMode]::Decompress
      )
      try {
        $zlibStream.CopyTo($decompressedStream)
      }
      finally {
        $zlibStream.Dispose()
      }
      $payloadBytes = $decompressedStream.ToArray()
    }
    finally {
      $decompressedStream.Dispose()
      $compressedStream.Dispose()
    }
    $uncompressedBytes = [byte[]]::new($payloadBytes.Length + 8)
    [System.Array]::Copy($movieBytes, 0, $uncompressedBytes, 0, 8)
    [System.Array]::Copy($payloadBytes, 0, $uncompressedBytes, 8, $payloadBytes.Length)
    $movieBytes = $uncompressedBytes
  }
  elseif ($signature -cne "GFX") {
    throw "$Context has unsupported Scaleform signature '$signature'."
  }

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
    . "$PSScriptRoot\sharedConfig.ps1" -SkipEnvironment
  }
  else {
    . "$PSScriptRoot\sharedConfig.ps1"
  }
}
. (Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "sharedScaleformProfiles.ps1") `
  -Description "Scaleform movie-profile helper")
. (Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "sharedScaleformMovies.ps1") `
  -Description "Scaleform movie-format helper")

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)
$archiveDefinitions = [ordered]@{
  "Main" = [pscustomobject]@{ FileSuffix = "Main.ba2"; Required = $true }
  "Textures" = [pscustomobject]@{ FileSuffix = "Textures.ba2"; Required = $false }
  "Main_XBox" = [pscustomobject]@{ FileSuffix = "Main_XBox.ba2"; Required = $true }
  "Textures_XBox" = [pscustomobject]@{ FileSuffix = "Textures_XBox.ba2"; Required = $false }
  "Main_PS" = [pscustomobject]@{ FileSuffix = "Main_PS.ba2"; Required = $true }
  "Textures_PS" = [pscustomobject]@{ FileSuffix = "Textures_PS.ba2"; Required = $false }
}

$releaseVariants = @($Global:ReleaseVariants)
if ($releaseVariants.Count -eq 0) {
  throw "ReleaseVariants must contain at least one canonical plugin stub."
}
$canonicalPluginVariant = $releaseVariants[0]
$canonicalPluginStagingPath = Resolve-RequiredDirectory `
  -Path (Join-Path $repositoryRoot ([string]$canonicalPluginVariant.StagingFolderPath)) `
  -Description "$($canonicalPluginVariant.VariantName) canonical plugin staging folder"
$canonicalPluginPath = Resolve-RequiredFile `
  -Path (Join-Path $canonicalPluginStagingPath "$($canonicalPluginVariant.PackageBaseName).esm") `
  -Description "$($canonicalPluginVariant.VariantName) canonical plugin stub"
Assert-NotGitLfsPointer `
  -Path $canonicalPluginPath `
  -Description "$($canonicalPluginVariant.VariantName) canonical plugin stub"
$canonicalPluginHash = Get-Sha256 -Path $canonicalPluginPath

$bootstrapPatchPath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot 'Scaleform\shared\patches\cui-auxiliary-loader.xml') `
  -Description 'CUI auxiliary loader patch'
$bootstrapPatchSource = [System.IO.File]::ReadAllText($bootstrapPatchPath).Replace("`r`n", "`n")
foreach ($requiredBootstrapSourceToken in @(
  'addEventListener(Event.ADDED_TO_STAGE,this.__setPerspectiveProjection_);',
  'this.startVenworksCUI();',
  'addEventListener(Event.INIT,this.onVenworksCUIInit',
  'addEventListener(Event.COMPLETE,this.onVenworksCUIComplete',
  'this.VenworksCUIBridge["initialize"](this);',
  'addChild(loadedContent);',
  'removeEventListener(Event.INIT,this.onVenworksCUIInit);',
  'removeChild(loadedContent);'
)) {
  if (!$bootstrapPatchSource.Contains($requiredBootstrapSourceToken)) {
    throw "CUI auxiliary loader patch is missing '$requiredBootstrapSourceToken'."
  }
}
if ($bootstrapPatchSource -match '(?s)<anchor><!\[CDATA\[\s*super\.onAddedToStage\(\);\]\]></anchor><content><!\[CDATA\[\s*this\.startVenworksCUI\(\);') {
  throw 'CUI auxiliary loading must start from the HUDMenu constructor rather than onAddedToStage().'
}

$entrypointPath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot 'Scaleform\venworkscui\VenworksCUIEntrypoint.as') `
  -Description 'CUI auxiliary entrypoint'
$entrypointSource = [System.IO.File]::ReadAllText($entrypointPath).Replace("`r`n", "`n")
if (!$entrypointSource.Contains('new CUIRuntime(this.owner,this);')) {
  throw 'CUI auxiliary entrypoint must keep the Bethesda HUD owner separate from its child display owner.'
}

foreach ($variant in $variants) {
  $profilePath = Resolve-RequiredFile `
    -Path (Join-Path $repositoryRoot "Scaleform\variants\$($variant.VariantKey)\build.psd1") `
    -Description "$($variant.VariantName) build profile"
  $variantBuildProfile = Import-PowerShellDataFile -LiteralPath $profilePath
  $movieProfile = Get-VariantScaleformMovieProfile `
    -RepositoryRoot $repositoryRoot `
    -VariantBuildProfile $variantBuildProfile
  $sourceProfile = $movieProfile.SourceProfile
  $hasAuxiliaryMovie = $null -ne $movieProfile.AuxiliaryManifestPath

  $stagingPath = Resolve-RequiredDirectory `
    -Path (Join-Path $repositoryRoot ([string]$variant.StagingFolderPath)) `
    -Description "$($variant.VariantName) staging folder"
  if (!$Committed) {
    $stagingItem = Get-Item -LiteralPath $variant.StagingFolderPath
    if ($stagingItem.LinkType -ne "Junction") {
      throw "$($variant.VariantName) staging folder must be a Junction."
    }
    $resolvedModulePath = Resolve-RequiredDirectory -Path $variant.PluginModulePath -Description "$($variant.VariantName) physical module folder"
    $stagingTargets = @($stagingItem.Target)
    if ($stagingTargets.Count -ne 1 -or
        ![string]::Equals(
          [System.IO.Path]::GetFullPath([string]$stagingTargets[0]),
          $resolvedModulePath,
          [System.StringComparison]::OrdinalIgnoreCase
        )) {
      throw "$($variant.VariantName) staging Junction targets the wrong physical module folder."
    }
  }

  $interfacePath = Resolve-RequiredDirectory -Path (Join-Path $stagingPath "Interface") -Description "$($variant.VariantName) Interface payload"
  $hasCuiPayload = $variantBuildProfile.ContainsKey('LayoutSource') -and
    ![string]::IsNullOrWhiteSpace([string]$variantBuildProfile.LayoutSource)
  $hasDiagnosticXmlPayload = $variantBuildProfile.ContainsKey('DiagnosticXmlSource') -and
    ![string]::IsNullOrWhiteSpace([string]$variantBuildProfile.DiagnosticXmlSource)
  if ($hasCuiPayload -and $hasDiagnosticXmlPayload) {
    throw "$($variant.VariantName) profile must not combine production CUI configuration with a diagnostic XML payload."
  }
  $cuiPath = $null
  $expectedCuiInventory = @()
  $diagnosticXmlValue = $null
  if ($hasCuiPayload) {
    $cuiPath = Resolve-RequiredDirectory -Path (Join-Path $interfacePath "VenworksCUI") -Description "$($variant.VariantName) CUI payload"
    $expectedCuiInventory = @("layout.xml")
    $expectedCuiInventory += @($variantBuildProfile.ComponentFileNames | ForEach-Object { "components/$_" })
    $expectedCuiInventory += @($variantBuildProfile.AssetFileNames | ForEach-Object { "Assets/$_" })
    $expectedCuiInventory += @($variantBuildProfile.PaletteFileNames | ForEach-Object { "palettes/$_" })
    Assert-Inventory -RootPath $cuiPath -ExpectedPaths $expectedCuiInventory -Description "$($variant.VariantName) CUI payload"
  }
  elseif ($hasDiagnosticXmlPayload) {
    if ($movieProfile.AuxiliaryContract -cne 'diagnostic-bridge' -or $null -ne $sourceProfile) {
      throw "$($variant.VariantName) diagnostic XML payload requires an isolated diagnostic-bridge auxiliary profile."
    }
    $cuiPath = Resolve-RequiredDirectory -Path (Join-Path $interfacePath "VenworksCUI") -Description "$($variant.VariantName) diagnostic XML payload"
    $expectedCuiInventory = @("layout.xml")
    Assert-Inventory -RootPath $cuiPath -ExpectedPaths $expectedCuiInventory -Description "$($variant.VariantName) diagnostic XML payload"
    $diagnosticXmlSourcePath = Resolve-RequiredFile `
      -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.DiagnosticXmlSource) -Description "$($variant.VariantName) diagnostic XML source") `
      -Description "$($variant.VariantName) diagnostic XML source"
    $diagnosticXmlSourceText = [System.IO.File]::ReadAllText($diagnosticXmlSourcePath)
    $diagnosticXmlPath = Join-Path $cuiPath "layout.xml"
    Assert-MatchingText `
      -ExpectedText $diagnosticXmlSourceText `
      -ActualPath $diagnosticXmlPath `
      -Description "$($variant.VariantName) staged diagnostic XML"
    if ($diagnosticXmlSourceText.Length -eq 0 -or $diagnosticXmlSourceText.Length -gt 4096) {
      throw "$($variant.VariantName) diagnostic XML source must contain between 1 and 4096 characters."
    }
    try {
      [xml]$diagnosticXml = $diagnosticXmlSourceText
    }
    catch {
      throw "$($variant.VariantName) diagnostic XML source is not well-formed XML."
    }
    $diagnosticRoot = $diagnosticXml.DocumentElement
    $diagnosticRootElements = @($diagnosticRoot.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
    $diagnosticHeadNodes = @($diagnosticRoot.SelectNodes('head'))
    $diagnosticTitleNodes = @($diagnosticRoot.SelectNodes('head/title'))
    $diagnosticBodyNodes = @($diagnosticRoot.SelectNodes('body'))
    $diagnosticSectionNodes = @($diagnosticRoot.SelectNodes('body/section'))
    $diagnosticHeadingNodes = @($diagnosticRoot.SelectNodes('body/section/h1'))
    $diagnosticParagraphNodes = @($diagnosticRoot.SelectNodes('body/section/p'))
    $diagnosticHeadElements = @()
    if ($diagnosticHeadNodes.Count -eq 1) {
      $diagnosticHeadElements = @($diagnosticHeadNodes[0].ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
    }
    $diagnosticBodyElements = @()
    if ($diagnosticBodyNodes.Count -eq 1) {
      $diagnosticBodyElements = @($diagnosticBodyNodes[0].ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
    }
    $diagnosticSectionElements = @()
    if ($diagnosticSectionNodes.Count -eq 1) {
      $diagnosticSectionElements = @($diagnosticSectionNodes[0].ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
    }
    if ($null -eq $diagnosticRoot -or
        $diagnosticRoot.Name -cne 'html' -or
        ![string]::IsNullOrEmpty([string]$diagnosticRoot.NamespaceURI) -or
        $diagnosticRoot.Attributes.Count -ne 0 -or
        $diagnosticRootElements.Count -ne 2 -or
        $diagnosticRootElements[0].Name -cne 'head' -or
        $diagnosticRootElements[1].Name -cne 'body' -or
        $diagnosticHeadNodes.Count -ne 1 -or
        $diagnosticHeadNodes[0].Attributes.Count -ne 0 -or
        $diagnosticHeadElements.Count -ne 1 -or
        $diagnosticHeadElements[0].Name -cne 'title' -or
        $diagnosticTitleNodes.Count -ne 1 -or
        $diagnosticTitleNodes[0].Attributes.Count -ne 0 -or
        $diagnosticTitleNodes[0].SelectNodes('*').Count -ne 0 -or
        $diagnosticBodyNodes.Count -ne 1 -or
        $diagnosticBodyNodes[0].Attributes.Count -ne 0 -or
        $diagnosticBodyElements.Count -ne 1 -or
        $diagnosticBodyElements[0].Name -cne 'section' -or
        $diagnosticSectionNodes.Count -ne 1 -or
        $diagnosticSectionNodes[0].Attributes.Count -ne 0 -or
        $diagnosticSectionElements.Count -ne 2 -or
        $diagnosticSectionElements[0].Name -cne 'h1' -or
        $diagnosticSectionElements[1].Name -cne 'p' -or
        $diagnosticHeadingNodes.Count -ne 1 -or
        $diagnosticHeadingNodes[0].Attributes.Count -ne 0 -or
        $diagnosticHeadingNodes[0].SelectNodes('*').Count -ne 0 -or
        $diagnosticParagraphNodes.Count -ne 1 -or
        $diagnosticParagraphNodes[0].Attributes.Count -ne 0 -or
        $diagnosticParagraphNodes[0].SelectNodes('*').Count -ne 0) {
      throw "$($variant.VariantName) diagnostic XML must be an exact unnamespaced html/head/title/body/section/h1/p document with text-only title, h1, and p elements."
    }
    $diagnosticHtmlValues = @(
      [string]$diagnosticTitleNodes[0].InnerText
      [string]$diagnosticHeadingNodes[0].InnerText
      [string]$diagnosticParagraphNodes[0].InnerText
    )
    foreach ($diagnosticHtmlValue in $diagnosticHtmlValues) {
      if ([string]::IsNullOrWhiteSpace($diagnosticHtmlValue) -or
          $diagnosticHtmlValue.Length -gt 80 -or
          $diagnosticHtmlValue -cne $diagnosticHtmlValue.Trim() -or
          $diagnosticHtmlValue -match '[\r\n\t]') {
        throw "$($variant.VariantName) diagnostic title, h1, and p values must be non-empty, trimmed, single-line text no longer than 80 characters."
      }
    }
    $diagnosticEntrypointPath = Resolve-RequiredFile `
      -Path (Join-Path $repositoryRoot 'Scaleform\variants\PS5DBG\venworkscui\VenworksCUIDiagnosticEntrypoint.as') `
      -Description "$($variant.VariantName) diagnostic ActionScript entrypoint"
    $diagnosticEntrypointSource = [System.IO.File]::ReadAllText($diagnosticEntrypointPath)
    foreach ($diagnosticHtmlValue in $diagnosticHtmlValues) {
      if ($diagnosticEntrypointSource.Contains($diagnosticHtmlValue)) {
        throw "$($variant.VariantName) diagnostic ActionScript must not embed XML-derived HTML text."
      }
    }
    foreach ($forbiddenDiagnosticSourceToken in @(
      'XMLList',
      '.elements(',
      '.children(',
      '.descendants(',
      '.child(',
      'htmlText',
      'StyleSheet',
      'ExternalInterface',
      'navigateToURL'
    )) {
      if ($diagnosticEntrypointSource.Contains($forbiddenDiagnosticSourceToken)) {
        throw "$($variant.VariantName) diagnostic ActionScript contains forbidden basic-HTML token '$forbiddenDiagnosticSourceToken'."
      }
    }
    foreach ($requiredDiagnosticSourceToken in @(
      'String(parsedXml.name()) != "html"',
      'String(parsedXml.head.title)',
      'String(parsedXml.body.section.h1)',
      'String(parsedXml.body.section.p)',
      'this.htmlPane.text =',
      'this.htmlPane.setTextFormat'
    )) {
      if (!$diagnosticEntrypointSource.Contains($requiredDiagnosticSourceToken)) {
        throw "$($variant.VariantName) diagnostic ActionScript is missing required bounded basic-HTML token '$requiredDiagnosticSourceToken'."
      }
    }
  }
  elseif (Test-Path -LiteralPath (Join-Path $interfacePath "VenworksCUI")) {
    throw "$($variant.VariantName) profile without CUI configuration must not stage a VenworksCUI payload."
  }
  if ($hasCuiPayload -and
      ($movieProfile.AuxiliaryContract -cne 'runtime-bridge' -or $null -eq $sourceProfile)) {
    throw "$($variant.VariantName) CUI configuration requires a runtime-bridge auxiliary profile."
  }
  if (!$hasCuiPayload -and $movieProfile.AuxiliaryContract -ceq 'runtime-bridge') {
    throw "$($variant.VariantName) runtime-bridge auxiliary profile requires staged CUI configuration."
  }
  if ($movieProfile.AuxiliaryContract -ceq 'diagnostic-bridge' -and $null -ne $sourceProfile) {
    throw "$($variant.VariantName) diagnostic auxiliary profile must not resolve a CUI source profile."
  }
  if ($movieProfile.AuxiliaryContract -ceq 'diagnostic-bridge' -and !$hasDiagnosticXmlPayload) {
    throw "$($variant.VariantName) diagnostic auxiliary profile requires its isolated diagnostic XML payload."
  }
  $expectedInterfaceInventory = @($movieProfile.DeploymentMovieDefinitions | ForEach-Object { [string]$_.FileName })
  if ($hasCuiPayload -or $hasDiagnosticXmlPayload) {
    $expectedInterfaceInventory += @($expectedCuiInventory | ForEach-Object { "VenworksCUI/$_" })
  }
  Assert-Inventory `
    -RootPath $interfacePath `
    -ExpectedPaths $expectedInterfaceInventory `
    -Description "$($variant.VariantName) complete Interface payload"

  $verifiedMoviePaths = @{}
  $movieInspections = @{}
  foreach ($movie in @($movieProfile.DeploymentMovieDefinitions)) {
    $moviePath = Resolve-RequiredFile -Path (Join-Path $interfacePath $movie.FileName) -Description "$($variant.VariantName) $($movie.FileName)"
    $expectedHash = Read-ExpectedSha256 -Path $movie.ExpectedHashPath
    $actualHash = Get-Sha256 -Path $moviePath
    if ($actualHash -cne $expectedHash) {
      throw "$($variant.VariantName) $($movie.FileName) hash mismatch. Expected $expectedHash; found $actualHash."
    }
    $movieMetadata = Get-ScaleformMovieMetadata `
      -Path $moviePath `
      -Context "$($variant.VariantName) $($movie.FileName)" `
      -ExpectedSignature ([string]$movie.ExpectedSignature)
    $expectedStageWidth = if ([string]$movie.FileName -ceq 'venworkscui.swf') { $movieProfile.AuxiliaryStageWidth } else { 1920 }
    $expectedStageHeight = if ([string]$movie.FileName -ceq 'venworkscui.swf') { $movieProfile.AuxiliaryStageHeight } else { 1080 }
    $expectedFrameRate = if ([string]$movie.FileName -ceq 'venworkscui.swf') { $movieProfile.AuxiliaryFrameRate } else { 30 }
    if ($movieMetadata.StageWidth -ne $expectedStageWidth -or
        $movieMetadata.StageHeight -ne $expectedStageHeight -or
        $movieMetadata.FrameRate -ne $expectedFrameRate -or
        $movieMetadata.FrameCount -ne 1) {
      throw "$($variant.VariantName) $($movie.FileName) must be $($expectedStageWidth)x$($expectedStageHeight) at $($expectedFrameRate) fps with one frame; found $($movieMetadata.StageWidth)x$($movieMetadata.StageHeight) at $($movieMetadata.FrameRate) fps with $($movieMetadata.FrameCount) frames."
    }
    $verifiedMoviePaths[[string]$movie.FileName] = $moviePath
    $movieInspections[[string]$movie.FileName] = Get-ScaleformMovieInspection `
      -Path $moviePath `
      -Context "$($variant.VariantName) $($movie.FileName)"
  }

  foreach ($baseHudMovieName in @('hudmenu.gfx', 'hudmenu.swf', 'hudmenu_lrg.gfx', 'hudmenu_lrg.swf')) {
    $inspection = $movieInspections[$baseHudMovieName]
    $movieDefinition = @($movieProfile.DeploymentMovieDefinitions | Where-Object {
      [string]$_.FileName -ceq $baseHudMovieName
    })[0]
    if ($inspection.AbcCount -ne 1) {
      throw "$($variant.VariantName) $baseHudMovieName must contain exactly one Bethesda ABC; found $($inspection.AbcCount)."
    }
    foreach ($requiredInspectionToken in @($movieDefinition.RequiredInspectionTokens)) {
      if (!$inspection.Text.Contains($requiredInspectionToken)) {
        throw "$($variant.VariantName) $baseHudMovieName is missing patch contract token '$requiredInspectionToken'."
      }
    }
    foreach ($forbiddenInspectionToken in @($movieDefinition.ForbiddenInspectionTokens)) {
      if ($inspection.Text.Contains($forbiddenInspectionToken)) {
        throw "$($variant.VariantName) $baseHudMovieName contains forbidden patch contract token '$forbiddenInspectionToken'."
      }
    }
    if ([string]$movieProfile.HostMode -notin @('auxiliary-bootstrap', 'bgs-hudmenu-only')) {
      throw "$($variant.VariantName) selects unsupported HUD host mode '$($movieProfile.HostMode)'."
    }
    foreach ($forbiddenRuntimeToken in @(
      'CUIRuntime',
      'CUILayoutImportLoader',
      'CUIPlayerHudDataContext',
      'CUIConditionContext',
      'CUISvgParser',
      'cui-component-abc-seed'
    )) {
      if ($inspection.Text.Contains($forbiddenRuntimeToken)) {
        throw "$($variant.VariantName) $baseHudMovieName embeds CUI runtime token '$forbiddenRuntimeToken'."
      }
    }
  }

  if ($hasCuiPayload) {
  $auxiliaryInspection = $movieInspections['venworkscui.swf']
  if ($auxiliaryInspection.AbcCount -ne 1) {
    throw "$($variant.VariantName) venworkscui.swf must contain exactly one CUI ABC; found $($auxiliaryInspection.AbcCount)."
  }
  foreach ($requiredAuxiliaryToken in @(
    'VenworksCUIEntrypoint',
    'CUIRuntime',
    'CUILayoutImportLoader',
    'CUIPlayerHudDataContext',
    'CUIConditionContext',
    'GetDataFromClient',
    'initialize',
    'reapplyVanillaPlacements',
    'updateVanillaHudModeVisibility',
    'dispose'
  ) + @($sourceProfile.RequiredBytecodeTokens) + @($sourceProfile.ValueProviders) + @($sourceProfile.ConditionProviders)) {
    if (!$auxiliaryInspection.Text.Contains([string]$requiredAuxiliaryToken)) {
      throw "$($variant.VariantName) venworkscui.swf is missing '$requiredAuxiliaryToken'."
    }
  }
  if ($auxiliaryInspection.Text.Contains('VENWORKS AUX LOADED')) {
    throw "$($variant.VariantName) venworkscui.swf retains the marker-probe payload."
  }
  foreach ($forbiddenAuxiliaryToken in @($sourceProfile.ForbiddenBytecodeTokens)) {
    if ($auxiliaryInspection.Text.Contains([string]$forbiddenAuxiliaryToken)) {
      throw "$($variant.VariantName) venworkscui.swf contains forbidden token '$forbiddenAuxiliaryToken'."
    }
  }
  $sourceFingerprint = Get-ScaleformAuxiliarySourceFingerprint `
    -ManifestPath $movieProfile.AuxiliaryManifestPath
  $expectedClassFingerprint = Read-ExpectedSha256 `
    -Path $movieProfile.AuxiliaryExpectedClassHashPath
  foreach ($fingerprintToken in @(
    "VENWORKS_CUI_SOURCE_SHA256:$sourceFingerprint",
    "VENWORKS_CUI_CLASSES_SHA256:$expectedClassFingerprint"
  )) {
    if (!$auxiliaryInspection.Text.Contains($fingerprintToken)) {
      throw "$($variant.VariantName) venworkscui.swf is not bound to '$fingerprintToken'."
    }
  }

  $actionScriptSourceRoot = Resolve-RequiredDirectory `
    -Path (Join-Path $repositoryRoot 'Scaleform\shared\actionscript') `
    -Description "$($variant.VariantName) ActionScript source directory"
  $profiledActionScript = @{}
  foreach ($sourceFile in @(Get-ChildItem -LiteralPath $actionScriptSourceRoot -Recurse -File -Filter '*.as')) {
    $relativeSourcePath = $sourceFile.FullName.Substring($actionScriptSourceRoot.Length + 1).Replace(
      [System.IO.Path]::AltDirectorySeparatorChar,
      [System.IO.Path]::DirectorySeparatorChar
    )
    if ($relativeSourcePath -in $sourceProfile.ExcludedActionScriptPaths) {
      continue
    }
    $effectiveSourcePath = Get-ScaleformProfileActionScriptPath `
      -SourceProfile $sourceProfile `
      -SourcePath $sourceFile.FullName `
      -RelativePath $relativeSourcePath
    $profiledActionScript[$relativeSourcePath] = if ($null -ne $sourceProfile.ActionScriptPatchPath) {
      Get-ScaleformPatchedActionScript `
        -SourcePath $effectiveSourcePath `
        -RelativePath $relativeSourcePath `
        -PatchPath $sourceProfile.ActionScriptPatchPath
    }
    else {
      [System.IO.File]::ReadAllText($effectiveSourcePath).Replace("`r`n", "`n")
    }
  }
  $transformedSource = @($profiledActionScript.Values) -join "`n"
  foreach ($requiredRuntimeToken in @($sourceProfile.RequiredBytecodeTokens)) {
    if (!$transformedSource.Contains([string]$requiredRuntimeToken)) {
      throw "$($variant.VariantName) transformed ActionScript is missing required runtime token '$requiredRuntimeToken'."
    }
  }
  foreach ($forbiddenRuntimeToken in @($sourceProfile.ForbiddenBytecodeTokens)) {
    if ($transformedSource.Contains([string]$forbiddenRuntimeToken)) {
      throw "$($variant.VariantName) transformed ActionScript retains forbidden token '$forbiddenRuntimeToken'."
    }
  }
  $playerContextRelativePath = [System.IO.Path]::Combine(
    'venworks',
    'cui',
    'CUIPlayerHudDataContext.as'
  )
  $conditionContextRelativePath = [System.IO.Path]::Combine(
    'venworks',
    'cui',
    'CUIConditionContext.as'
  )
  if (!$profiledActionScript.ContainsKey($playerContextRelativePath) -or
      !$profiledActionScript.ContainsKey($conditionContextRelativePath)) {
    throw "$($variant.VariantName) profile excludes a required provider context."
  }
  $actualValueProviders = @(
    [regex]::Matches([string]$profiledActionScript[$playerContextRelativePath], 'subscribeProvider\("([^"]+)"') |
      ForEach-Object { $_.Groups[1].Value }
  )
  $actualConditionProviders = @(
    [regex]::Matches([string]$profiledActionScript[$conditionContextRelativePath], 'subscribeProvider\("([^"]+)"') |
      ForEach-Object { $_.Groups[1].Value }
  )
  if ([string]::Join("`n", $actualValueProviders) -cne [string]::Join("`n", @($sourceProfile.ValueProviders)) -or
      [string]::Join("`n", $actualConditionProviders) -cne [string]::Join("`n", @($sourceProfile.ConditionProviders))) {
    throw "$($variant.VariantName) transformed ActionScript does not preserve the declared provider inventories."
  }
  $actualCrossContextProviderCount = @(
    $actualValueProviders | Where-Object { $_ -in $actualConditionProviders } | Select-Object -Unique
  ).Count
  if ($actualCrossContextProviderCount -ne $sourceProfile.CrossContextProviderCount) {
    throw "$($variant.VariantName) transformed ActionScript has $actualCrossContextProviderCount cross-context providers; expected $($sourceProfile.CrossContextProviderCount)."
  }
  $tacticalAwarenessRelativePath = [System.IO.Path]::Combine(
    'venworks',
    'cui',
    'CUITacticalAwarenessModel.as'
  )
  if (!$profiledActionScript.ContainsKey($tacticalAwarenessRelativePath)) {
    throw "$($variant.VariantName) profile excludes the tactical-awareness model."
  }
  $tacticalAwarenessSource = [string]$profiledActionScript[$tacticalAwarenessRelativePath]
  $statusCollectionMethod = [regex]::Match(
    $tacticalAwarenessSource,
    '(?s)private function collectStatusEffects\(\) : Array.*?(?=\s+private function appendStatusEffects)'
  )
  $statusAppendMethod = [regex]::Match(
    $tacticalAwarenessSource,
    '(?s)private function appendStatusEffects\(.*?(?=\s+private function classifyStatus)'
  )
  $statusEffectBarRelativePath = [System.IO.Path]::Combine(
    'venworks',
    'cui',
    'components',
    'CUIStatusEffectBar.as'
  )
  if (!$profiledActionScript.ContainsKey($statusEffectBarRelativePath)) {
    throw "$($variant.VariantName) profile excludes the status-effect bar."
  }
  $statusEffectBarSource = [string]$profiledActionScript[$statusEffectBarRelativePath]
  if (!$statusCollectionMethod.Success -or
      !$statusCollectionMethod.Value.Contains('personalEffectsData.aPersonalEffects as Array;') -or
      !$statusCollectionMethod.Value.Contains('environmentData.aEnvironmentEffects as Array;') -or
      !$statusCollectionMethod.Value.Contains('this.appendStatusEffects(result,seen,personalEffects,false,0);') -or
      !$statusCollectionMethod.Value.Contains('this.appendStatusEffects(result,seen,environmentEffects,true,1);') -or
      !$statusAppendMethod.Success -or
      !$statusAppendMethod.Value.Contains('param2[key] !== true') -or
      !$statusAppendMethod.Value.Contains('kind = param4 ? "debuff" : this.classifyStatus(key);') -or
      !$statusAppendMethod.Value.Contains('key.indexOf("SUSTENANCE_FOOD_NEGATIVE_") == 0') -or
      !$statusAppendMethod.Value.Contains('key.indexOf("SUSTENANCE_DRINK_NEGATIVE_") == 0') -or
      !$statusAppendMethod.Value.Contains('"debuff" : kind,') -or
      !$statusEffectBarSource.Contains('var colorKind:String = param2.colorKind == null ? String(param2.kind) : String(param2.colorKind);') -or
      !$statusEffectBarSource.Contains('var color:uint = colorKind == "debuff" ? debuffColor :') -or
      !$statusEffectBarSource.Contains('colorKind == "sustenance" ? sustenanceColor : neutralColor;')) {
    throw "$($variant.VariantName) tactical-awareness statuses must aggregate both sources, deduplicate icons, and render negative sustenance with the debuff color."
  }
  $runtimeRelativePath = [System.IO.Path]::Combine('venworks', 'cui', 'CUIRuntime.as')
  if (!$profiledActionScript.ContainsKey($runtimeRelativePath)) {
    throw "$($variant.VariantName) profile excludes the CUI runtime."
  }
  $runtimeSource = [string]$profiledActionScript[$runtimeRelativePath]
  foreach ($requiredRuntimeOwnershipToken in @(
    'private var hudOwner:DisplayObjectContainer;',
    'private var displayOwner:DisplayObjectContainer;',
    'public function CUIRuntime(param1:DisplayObjectContainer, param2:DisplayObjectContainer)',
    'displayOwner.addChild(componentLayer);',
    'displayOwner.addChild(diagnostics);',
    'hudOwner.addEventListener(Event.REMOVED_FROM_STAGE,this.onOwnerRemovedFromStage);',
    'new CUIVanillaVisibilityAdapter(',
    'hudOwner,',
    'componentLayer.parent === displayOwner',
    'diagnostics.parent === displayOwner'
  )) {
    if (!$runtimeSource.Contains($requiredRuntimeOwnershipToken)) {
      throw "$($variant.VariantName) runtime does not preserve the separate HUD and auxiliary display ownership contract: missing '$requiredRuntimeOwnershipToken'."
    }
  }
  $runtimeLoadMethod = [regex]::Match(
    $runtimeSource,
    '(?s)public function load\(\) : void.*?(?=\s+private function startProviderContexts)'
  )
  $providerStartupMethod = [regex]::Match(
    $runtimeSource,
    '(?s)private function startProviderContexts\(\) : void.*?(?=\s+public function reapplyVanillaPlacements)'
  )
  if (!$runtimeLoadMethod.Success -or
      !$runtimeLoadMethod.Value.Contains('this.startProviderContexts();') -or
      !$runtimeLoadMethod.Value.Contains('if(this.failed)') -or
      $runtimeLoadMethod.Value.IndexOf('this.startProviderContexts();') -gt $runtimeLoadMethod.Value.IndexOf('loader.load();') -or
      !$providerStartupMethod.Success -or
      !$providerStartupMethod.Value.Contains('valueContext.start();') -or
      !$providerStartupMethod.Value.Contains('if(this.failed)') -or
      !$providerStartupMethod.Value.Contains('conditionContext.start();')) {
    throw "$($variant.VariantName) runtime must start both provider contexts before loading external configuration."
  }
  $providerErrorMethod = [regex]::Match(
    $runtimeSource,
    '(?s)private function onProviderError\(.*?(?=\s+private function showLiveEventError)'
  )
  $terminalFailureMethod = [regex]::Match(
    $runtimeSource,
    '(?s)private function enterTerminalFailure\(\) : void.*?(?=\s+private function showRuntimeError)'
  )
  if (!$providerErrorMethod.Success -or
      !$providerErrorMethod.Value.Contains('this.enterTerminalFailure();') -or
      !$providerErrorMethod.Value.Contains('this.deferComponentTeardown();') -or
      $providerErrorMethod.Value.IndexOf('this.enterTerminalFailure();') -gt
        $providerErrorMethod.Value.IndexOf('this.deferComponentTeardown();') -or
      !$terminalFailureMethod.Success -or
      !$terminalFailureMethod.Value.Contains('this.failed = true;') -or
      !$terminalFailureMethod.Value.Contains('loader.cancel();') -or
      !$terminalFailureMethod.Value.Contains('paletteLoader.cancel();') -or
      !$terminalFailureMethod.Value.Contains('assetManager.cancel();') -or
      [regex]::Matches($runtimeSource, 'if\(this\.disposed \|\| this\.failed\)').Count -lt 5) {
    throw "$($variant.VariantName) runtime does not terminally contain provider faults across its asynchronous load pipeline."
  }
  foreach ($cancellableLoaderRelativePath in @(
    [System.IO.Path]::Combine('venworks', 'cui', 'CUILayoutImportLoader.as'),
    [System.IO.Path]::Combine('venworks', 'cui', 'CUIPaletteLoader.as'),
    [System.IO.Path]::Combine('venworks', 'cui', 'CUIAssetManager.as')
  )) {
    if (!$profiledActionScript.ContainsKey($cancellableLoaderRelativePath)) {
      throw "$($variant.VariantName) profile excludes cancellable loader '$cancellableLoaderRelativePath'."
    }
    $cancellableLoaderSource = [string]$profiledActionScript[$cancellableLoaderRelativePath]
    if (!$cancellableLoaderSource.Contains('public function cancel() : void') -or
        !$cancellableLoaderSource.Contains('.close();')) {
      throw "$($variant.VariantName) loader '$cancellableLoaderRelativePath' does not cancel its active URLLoader requests."
    }
  }
  foreach ($contextRelativePath in @($playerContextRelativePath, $conditionContextRelativePath)) {
    $contextSource = [string]$profiledActionScript[$contextRelativePath]
    $subscribeMethod = [regex]::Match(
      $contextSource,
      '(?s)private function subscribeProvider\(.*?(?=\s+private function handleProviderEvent)'
    )
    if (!$subscribeMethod.Success -or
        !$subscribeMethod.Value.Contains('BSUIDataManager.GetDataFromClient(param1,true);') -or
        $subscribeMethod.Value.IndexOf('BSUIDataManager.GetDataFromClient(param1,true);') -gt
          $subscribeMethod.Value.IndexOf('BSUIDataManager.Subscribe(param1,callback);')) {
      throw "$($variant.VariantName) provider subscriptions must prime each provider snapshot before attaching callbacks."
    }
  }

  $layoutSourcePath = Resolve-RequiredFile `
    -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.LayoutSource) -Description "$($variant.VariantName) layout source") `
    -Description "$($variant.VariantName) layout source"
  $expectedLayoutText = [System.IO.File]::ReadAllText($layoutSourcePath)
  $literalColors = $null
  $selectedPaletteFileName = [string]$variant.PaletteFileName
  if ([string]$variantBuildProfile.PaletteMode -ceq "External") {
    $paletteMatches = @([regex]::Matches($expectedLayoutText, '\bpalette="[^"]+"'))
    if ($paletteMatches.Count -ne 1 -or
        @($variantBuildProfile.PaletteFileNames | Where-Object { [string]$_ -ceq $selectedPaletteFileName }).Count -ne 1) {
      throw "$($variant.VariantName) external palette profile is invalid."
    }
    $expectedLayoutText = [regex]::Replace(
      $expectedLayoutText,
      '\bpalette="[^"]+"',
      "palette=`"$selectedPaletteFileName`"",
      1
    )
  }
  elseif ([string]$variantBuildProfile.PaletteMode -ceq "Literal") {
    $literalPalettePath = Resolve-RequiredFile `
      -Path (Join-Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PaletteSourceDirectory) -Description "$($variant.VariantName) palette source") $selectedPaletteFileName) `
      -Description "$($variant.VariantName) literal palette"
    $literalColors = Get-LiteralPaletteColors -PalettePath $literalPalettePath
    if ($expectedLayoutText -match '@palette\.|\bpalette="') {
      throw "$($variant.VariantName) literal layout source retains a palette selector or reference."
    }
  }
  else {
    throw "$($variant.VariantName) profile selects unsupported palette mode '$($variantBuildProfile.PaletteMode)'."
  }
  $layoutPath = Join-Path $cuiPath "layout.xml"
  Assert-MatchingText -ExpectedText $expectedLayoutText -ActualPath $layoutPath -Description "$($variant.VariantName) layout"

  $componentSourceDirectory = Resolve-RequiredDirectory `
    -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.ComponentSourceDirectory) -Description "$($variant.VariantName) component source") `
    -Description "$($variant.VariantName) component source directory"
  foreach ($componentFileName in @($variantBuildProfile.ComponentFileNames)) {
    $componentSourcePath = Resolve-RequiredFile -Path (Join-Path $componentSourceDirectory ([string]$componentFileName)) -Description "$($variant.VariantName) component source '$componentFileName'"
    $expectedComponentText = [System.IO.File]::ReadAllText($componentSourcePath)
    if ([string]$variantBuildProfile.PaletteMode -ceq "Literal") {
      $expectedComponentText = Resolve-PaletteColorReferences `
        -Text $expectedComponentText `
        -ColorValues $literalColors `
        -Context "$($variant.VariantName) component '$componentFileName'"
      $expectedComponentText = $expectedComponentText.TrimEnd([char[]]"`r`n") + [Environment]::NewLine
    }
    Assert-MatchingText `
      -ExpectedText $expectedComponentText `
      -ActualPath (Join-Path (Join-Path $cuiPath "components") ([string]$componentFileName)) `
      -Description "$($variant.VariantName) component '$componentFileName'"
  }

  foreach ($assetFileName in @($variantBuildProfile.AssetFileNames)) {
    $sourcePath = Resolve-RequiredFile -Path (Join-Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.AssetSourceDirectory) -Description "$($variant.VariantName) asset source") ([string]$assetFileName)) -Description "$($variant.VariantName) asset source '$assetFileName'"
    $stagedPath = Resolve-RequiredFile -Path (Join-Path (Join-Path $cuiPath "Assets") ([string]$assetFileName)) -Description "$($variant.VariantName) asset '$assetFileName'"
    Assert-MatchingText `
      -ExpectedText ([System.IO.File]::ReadAllText($sourcePath)) `
      -ActualPath $stagedPath `
      -Description "$($variant.VariantName) asset '$assetFileName'"
  }
  foreach ($paletteFileName in @($variantBuildProfile.PaletteFileNames)) {
    $sourcePath = Resolve-RequiredFile -Path (Join-Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PaletteSourceDirectory) -Description "$($variant.VariantName) palette source") ([string]$paletteFileName)) -Description "$($variant.VariantName) palette source '$paletteFileName'"
    $stagedPath = Resolve-RequiredFile -Path (Join-Path (Join-Path $cuiPath "palettes") ([string]$paletteFileName)) -Description "$($variant.VariantName) palette '$paletteFileName'"
    Assert-MatchingText `
      -ExpectedText ([System.IO.File]::ReadAllText($sourcePath)) `
      -ActualPath $stagedPath `
      -Description "$($variant.VariantName) palette '$paletteFileName'"
  }

  [xml]$layout = Get-Content -LiteralPath $layoutPath -Raw
  $includedFileNames = @($layout.SelectNodes('/venworksCUI/includes/include') | ForEach-Object { [string]$_.src } | Sort-Object)
  $profileFileNames = @($variantBuildProfile.ComponentFileNames | ForEach-Object { [string]$_ } | Sort-Object)
  if ($includedFileNames.Count -ne $profileFileNames.Count) {
    throw "$($variant.VariantName) layout/profile component count differs."
  }
  for ($index = 0; $index -lt $profileFileNames.Count; $index++) {
    if ($includedFileNames[$index] -cne $profileFileNames[$index]) {
      throw "$($variant.VariantName) layout/profile component mismatch."
    }
  }

  if ([string]$variant.VariantKey -ceq "MIN") {
    $radarIncludes = @($layout.SelectNodes('/venworksCUI/includes/include[@id="contact-radar"]'))
    if ($radarIncludes.Count -ne 1 -or
        [string]$radarIncludes[0].x -cne "-64" -or
        [string]$radarIncludes[0].y -cne "-36" -or
        @($layout.SelectNodes('/venworksCUI/includes/include[@id="faction-display"]')).Count -ne 0 -or
        (Test-Path -LiteralPath (Join-Path $cuiPath "components\faction-display.xml"))) {
      throw "Minimalist must omit the faction display and keep the contact radar in its former upper-left position."
    }
    $scannerText = [System.IO.File]::ReadAllText((Join-Path $cuiPath "components\environmental-hazard-scanner.xml"))
    if ($scannerText -notmatch 'id="planet\.solar-transition" x="14" y="52" width="332" height="22"' -or
        $scannerText -notmatch 'source="environment\.solarTransitionCountdown" format="raw"' -or
        $scannerText -match '<panel\b') {
      throw "Minimalist does not preserve the accepted dedicated solar-transition row."
    }
    $configurationText = @(
      Get-ChildItem -LiteralPath $cuiPath -Recurse -File -Filter "*.xml" |
        ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }
    ) -join "`n"
    if ($configurationText -match '(?i)<(?:svg|path|mask|icon|panel|providerSymbol)\b|\.svg\b|@palette\.|\bpalette="' -or
        $configurationText -match '(?i)equipment-rail' -or
        (Test-Path -LiteralPath (Join-Path $cuiPath "components\equipment-rail.xml")) -or
        @(Get-ChildItem -LiteralPath $interfacePath -Recurse -File -Include "*.svg","*.dds","*.png","*.jpg","*.jpeg").Count -ne 0) {
      throw "Minimalist contains a disabled XML capability, equipment rail, external palette, or image asset."
    }

    $fittedBackingDefinitions = @(
      [pscustomobject]@{ RelativePath = "layout.xml"; Id = "critical-health"; X = "0"; Y = "0"; Width = "320"; Height = "70"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "layout.xml"; Id = "vehicle-exit"; X = "0"; Y = "0"; Width = "184"; Height = "36"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\contact-radar.xml"; Id = "contact-radar"; X = "22"; Y = "21"; Width = "184"; Height = "184"; Shape = "ellipse" }
      [pscustomobject]@{ RelativePath = "components\environmental-hazard-scanner.xml"; Id = "environmental-hazard"; X = "0"; Y = "0"; Width = "360"; Height = "254"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\helmet-awareness.xml"; Id = "helmet.compass"; X = "0"; Y = "-58"; Width = "826"; Height = "48"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\helmet-awareness.xml"; Id = "helmet.threat"; X = "253"; Y = "12"; Width = "320"; Height = "24"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\player-status-scanner.xml"; Id = "player-status"; X = "0"; Y = "0"; Width = "360"; Height = "236"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\quest-tracker.xml"; Id = "quest-tracker"; X = "0"; Y = "0"; Width = "447"; Height = "90"; Shape = "rectangle" }
    )
    $fittedBackingDocuments = @{}
    $fittedBackingNodeCount = 0
    foreach ($relativePath in @($fittedBackingDefinitions.RelativePath | Sort-Object -Unique)) {
      [xml]$backingDocument = Get-Content -LiteralPath (Join-Path $cuiPath $relativePath) -Raw
      $fittedBackingDocuments[$relativePath] = $backingDocument
      $fittedBackingNodeCount += @($backingDocument.SelectNodes('//shape[contains(@id,".backing.")]')).Count
    }
    if ($fittedBackingNodeCount -ne ($fittedBackingDefinitions.Count * 2)) {
      throw "Minimalist must contain exactly two fitted backing layers for each approved readout footprint."
    }
    foreach ($backing in $fittedBackingDefinitions) {
      $backingDocument = $fittedBackingDocuments[[string]$backing.RelativePath]
      foreach ($layer in @(
        [pscustomobject]@{ Name = "base"; Z = "-2"; FillColor = "#0D1114"; FillOpacity = "0.28" },
        [pscustomobject]@{ Name = "tint"; Z = "-1"; FillColor = "#70CFE0"; FillOpacity = "0.10" }
      )) {
        $backingId = "$($backing.Id).backing.$($layer.Name)"
        $backingNodes = @($backingDocument.SelectNodes("//shape[@id='$backingId']"))
        if ($backingNodes.Count -ne 1) {
          throw "Minimalist fitted backing '$backingId' must appear exactly once in $($backing.RelativePath)."
        }
        $backingNode = $backingNodes[0]
        $expectedAttributes = @{
          x = [string]$backing.X
          y = [string]$backing.Y
          width = [string]$backing.Width
          height = [string]$backing.Height
          z = [string]$layer.Z
          shape = [string]$backing.Shape
          fillColor = [string]$layer.FillColor
          fillOpacity = [string]$layer.FillOpacity
          strokeColor = "#D9E3E8"
          strokeOpacity = "0"
          strokeWidth = "0"
        }
        foreach ($attributeName in $expectedAttributes.Keys) {
          if ([string]$backingNode.GetAttribute($attributeName) -cne [string]$expectedAttributes[$attributeName]) {
            throw "Minimalist fitted backing '$backingId' has an unexpected '$attributeName' value."
          }
        }
      }
    }

    if ($sourceProfile.Name -cne "minimalist-live" -or
        $sourceProfile.ExcludedActionScriptPaths.Count -ne 0) {
      throw "Minimalist must use the full shared ActionScript inventory through the minimalist-live profile."
    }
    if ($sourceProfile.ActionScriptReplacementPaths.Count -ne 0) {
      throw "Minimalist live provider profile must not replace either shared data context."
    }
    $expectedValueProviders = @(
      'LocalEnvironmentData',
      'LocalEnvData_Frequent',
      'PlayerData',
      'PlayerFrequentData',
      'PlayerInventoryData',
      'HudJetpackData',
      'EnvironmentEffectsData',
      'PersonalEffectsData',
      'StarmapSystemBodyInfoProvider',
      'HudCompassData'
    )
    $expectedConditionProviders = @(
      'HudCrosshairData',
      'HUDStealthData',
      'HudCompassData',
      'HUDVehicleData',
      'HUDOpacityData',
      'HudJetpackData',
      'PlayerInventoryData'
    )
    if ([string]::Join("`n", @($sourceProfile.ValueProviders)) -cne [string]::Join("`n", $expectedValueProviders) -or
        [string]::Join("`n", @($sourceProfile.ConditionProviders)) -cne [string]::Join("`n", $expectedConditionProviders) -or
        $sourceProfile.CrossContextProviderCount -ne 3) {
      throw "Minimalist live provider profile must contain exactly 10 value, 7 condition, and 3 cross-context registrations."
    }
    $requiredRuntimeTokens = @(
      'CUILayoutImportLoader',
      'CUIPaletteLoader',
      'CUIAssetManager',
      'CUICompositeResolver',
      'CUIIconLibrary',
      'CUISvgParser',
      'CUISvgPathParser',
      'CUIIcon',
      'CUIMask',
      'CUIPanel',
      'CUIProviderSymbol',
      'CUISvg',
      'CUISvgPath'
    )
    if (@($requiredRuntimeTokens | Where-Object { $_ -notin $sourceProfile.RequiredBytecodeTokens }).Count -ne 0) {
      throw "Minimalist does not require the complete external XML, palette, SVG, path, mask, icon, panel, provider-symbol, and composite runtime."
    }
    if ([string]::Join("`n", $actualValueProviders) -cne [string]::Join("`n", $expectedValueProviders) -or
        [string]::Join("`n", $actualConditionProviders) -cne [string]::Join("`n", $expectedConditionProviders)) {
      throw "Minimalist transformed ActionScript does not preserve the exact live provider inventory."
    }
    foreach ($railOnlyProvider in @('WeaponData', 'HUDStarbornPowersData', 'FavoritesData', 'ControlMapData')) {
      if ($railOnlyProvider -in $actualValueProviders -or $railOnlyProvider -in $actualConditionProviders) {
        throw "Minimalist transformed ActionScript restores removed equipment provider '$railOnlyProvider'."
      }
    }
    foreach ($requiredEventToken in @(
      'CUIPlayerHudDataContext.PROVIDER_ERROR',
      'CUIPlayerHudDataContext.VALUE_CHANGE',
      'CUIPlayerHudDataContext.COMPASS_CHANGE',
      'CUIPlayerHudDataContext.TACTICAL_AWARENESS_CHANGE',
      'CUIConditionContext.PROVIDER_ERROR',
      'CUIConditionContext.CONDITION_CHANGE'
    )) {
      if (!$transformedSource.Contains($requiredEventToken)) {
        throw "Minimalist transformed ActionScript is missing required event wiring '$requiredEventToken'."
      }
    }

    $statusEffectRelativePath = [System.IO.Path]::Combine(
      'venworks',
      'cui',
      'components',
      'CUIStatusEffectBar.as'
    )
    $statusEffectSource = [string]$profiledActionScript[$statusEffectRelativePath]
    $statusBackgroundMethod = [regex]::Match(
      $statusEffectSource,
      '(?s)private function drawSlotBackground.*?(?=\s+private function drawFallbackIcon)'
    )
    if (!$statusBackgroundMethod.Success -or
        !$statusBackgroundMethod.Value.Contains('param1.graphics.beginFill(0x0D1114,0.28);') -or
        !$statusBackgroundMethod.Value.Contains('param1.graphics.beginFill(0x70CFE0,0.10);') -or
        [regex]::Matches($statusBackgroundMethod.Value, 'param1\.graphics\.drawRect\(').Count -ne 2 -or
        $statusBackgroundMethod.Value -match '(?i)drawPath|GraphicsPath|CUISvg|pathData') {
      throw "Minimalist active status-effect tiles must use only the approved two-layer native rectangle backing."
    }

    $scannerRelativePath = [System.IO.Path]::Combine(
      'venworks',
      'cui',
      'components',
      'CUIScannerOverlay.as'
    )
    $scannerSource = [string]$profiledActionScript[$scannerRelativePath]
    $scannerOverlayMethod = [regex]::Match(
      $scannerSource,
      '(?s)private function createOverlay.*?(?=\s+private function drawCorners)'
    )
    $scannerThreatBacking = 'panelShape.graphics.drawRect(componentWidth / 2 - 112,0,224,26);'
    $scannerContactsBacking = 'panelShape.graphics.drawRect(componentWidth - 270,156,260,146);'
    if (!$scannerOverlayMethod.Success -or
        !$scannerOverlayMethod.Value.Contains('panelShape.graphics.beginFill(0x0D1114,0.28);') -or
        !$scannerOverlayMethod.Value.Contains('panelShape.graphics.beginFill(0x70CFE0,0.10);') -or
        $scannerOverlayMethod.Value.Split($scannerThreatBacking).Count -ne 3 -or
        $scannerOverlayMethod.Value.Split($scannerContactsBacking).Count -ne 3 -or
        [regex]::Matches($scannerOverlayMethod.Value, 'panelShape\.graphics\.drawRect\(').Count -ne 4 -or
        $scannerOverlayMethod.Value -match '(?i)drawPath|GraphicsPath|CUISvg|pathData') {
      throw "Minimalist scanner readouts must use only the approved dynamically positioned two-layer native rectangle backings."
    }

  }
  }
  elseif ($movieProfile.AuxiliaryContract -ceq 'diagnostic-bridge') {
    $auxiliaryInspection = $movieInspections['venworkscui.swf']
    if ($null -eq $auxiliaryInspection -or $auxiliaryInspection.AbcCount -ne 1) {
      $actualAbcCount = if ($null -eq $auxiliaryInspection) { 0 } else { $auxiliaryInspection.AbcCount }
      throw "$($variant.VariantName) diagnostic venworkscui.swf must contain exactly one ABC; found $actualAbcCount."
    }
    foreach ($requiredDiagnosticToken in @(
      'VenworksCUIDiagnosticEntrypoint',
      'venworkscui.swf loaded',
      'Shared.AS3.Data.BSUIDataManager',
      'getDefinitionByName',
      'PlayerData',
      'GetDataFromClient',
      'Subscribe',
      'Unsubscribe',
      'sName',
      'PS5DBG-05 PLAYERDATA NEXT FRAME',
      'PS5DBG-06 PLAYERDATA REQUEST',
      'PS5DBG-07 PLAYERDATA WAITING',
      'PS5DBG-08 XML LOAD NEXT FRAME',
      'PS5DBG-09 XML LOAD RETURNED',
      'PS5DBG-10 XML RECEIVED',
      'PS5DBG-11 XML PARSE NEXT FRAME',
      'PS5DBG-12 BASIC HTML RENDER',
      'PS5DBG-OK PLAYERDATA',
      'PS5DBG-ERR PLAYERDATA',
      'PS5DBG-OK HTML',
      'PS5DBG-ERR XML REQUEST',
      'PS5DBG-ERR XML IO',
      'PS5DBG-ERR XML SECURITY',
      'PS5DBG-ERR XML PARSE',
      'PS5DBG-ERR XML VALUE',
      'PS5DBG-ERR HTML VALUE',
      'PS5DBG-ERR HTML RENDER',
      'PLAYERDATA:',
      'XML:',
      'URLRequest',
      'URLLoader',
      'VenworksCUI/layout.xml',
      'html/head/title/body/section/h1/p',
      'VenworksCUIBasicHtmlPane',
      'renderBasicHtml',
      'initialize',
      'reapplyVanillaPlacements',
      'updateVanillaHudModeVisibility',
      'dispose',
      '$MAIN_Font_Bold',
      'embedFonts',
      'defaultTextFormat',
      'setTextFormat'
    )) {
      if (!$auxiliaryInspection.Text.Contains($requiredDiagnosticToken)) {
        throw "$($variant.VariantName) diagnostic venworkscui.swf is missing '$requiredDiagnosticToken'."
      }
    }
    foreach ($forbiddenDiagnosticToken in @(
      'CUIRuntime',
      'CUILayoutImportLoader',
      'CUIPlayerHudDataContext',
      'CUIConditionContext',
      'XMLList',
      'elements',
      'children',
      'descendants',
      'htmlText',
      'StyleSheet',
      'ExternalInterface',
      'navigateToURL',
      'VENWORKS AUX LOADED'
    )) {
      if ($auxiliaryInspection.Text.Contains($forbiddenDiagnosticToken)) {
        throw "$($variant.VariantName) diagnostic venworkscui.swf contains forbidden runtime token '$forbiddenDiagnosticToken'."
      }
    }
    foreach ($diagnosticHtmlValue in $diagnosticHtmlValues) {
      if ([string]::IsNullOrWhiteSpace($diagnosticHtmlValue) -or $auxiliaryInspection.Text.Contains($diagnosticHtmlValue)) {
        throw "$($variant.VariantName) diagnostic venworkscui.swf must not embed XML-derived HTML text."
      }
    }
    $expectedDiagnosticClassFingerprint = Read-ExpectedSha256 `
      -Path $movieProfile.AuxiliaryExpectedClassHashPath
    $canonicalDiagnosticClassFingerprint = Get-ScaleformAuxiliaryTextSha256 `
      -Text "VenworksCUIDiagnosticEntrypoint`n"
    if ($expectedDiagnosticClassFingerprint -cne $canonicalDiagnosticClassFingerprint) {
      throw "$($variant.VariantName) diagnostic auxiliary expected class hash does not match its one-class contract."
    }
    $embeddedDiagnosticClassFingerprint = "VENWORKS_CUI_CLASSES_SHA256:$expectedDiagnosticClassFingerprint"
    if (!$auxiliaryInspection.Text.Contains($embeddedDiagnosticClassFingerprint)) {
      throw "$($variant.VariantName) staged diagnostic venworkscui.swf does not embed its expected class fingerprint."
    }
  }
  elseif ($hasAuxiliaryMovie) {
    throw "$($variant.VariantName) selects unsupported auxiliary contract '$($movieProfile.AuxiliaryContract)'."
  }

  $pluginPath = Join-Path $stagingPath "$($variant.PackageBaseName).esm"
  Assert-NotGitLfsPointer -Path $pluginPath -Description "$($variant.VariantName) plugin"
  $pluginHash = Get-Sha256 -Path $pluginPath
  if ($pluginHash -cne $canonicalPluginHash) {
    throw "$($variant.VariantName) plugin is not byte-identical to the canonical $($canonicalPluginVariant.VariantName) stub."
  }
  if (![string]::IsNullOrWhiteSpace([string]$variantBuildProfile.PluginSourcePath)) {
    $pluginSourcePath = Resolve-RequiredFile -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PluginSourcePath) -Description "$($variant.VariantName) plugin source") -Description "$($variant.VariantName) plugin source"
    Assert-NotGitLfsPointer -Path $pluginSourcePath -Description "$($variant.VariantName) plugin source"
    if ((Get-Sha256 -Path $pluginSourcePath) -cne $pluginHash) {
      throw "$($variant.VariantName) plugin is not byte-identical to its configured source stub."
    }
  }

  if ($PreArchiveMutation) {
    Write-Host -ForegroundColor Green "$($variant.VariantName) profile, complete Interface payload, movies, and plugin are valid before archive mutation."
    continue
  }

  $archiveFiles = @(Get-ChildItem -LiteralPath $stagingPath -File -Filter "*.ba2")
  $allowedArchiveNames = [System.Collections.Generic.List[string]]::new()
  foreach ($archiveTarget in @($variant.ArchiveTargets)) {
    if (!$archiveDefinitions.Contains([string]$archiveTarget)) {
      throw "$($variant.VariantName) defines unknown archive target '$archiveTarget'."
    }
    $definition = $archiveDefinitions[[string]$archiveTarget]
    $archiveName = "$($variant.PackageBaseName) - $($definition.FileSuffix)"
    $allowedArchiveNames.Add($archiveName)
    $archivePath = Join-Path $stagingPath $archiveName
    if ($definition.Required -and !(Test-Path -LiteralPath $archivePath -PathType Leaf)) {
      throw "$($variant.VariantName) is missing required archive '$archiveName'."
    }
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
      Assert-NotGitLfsPointer -Path $archivePath -Description "$($variant.VariantName) archive '$archiveName'"
    }
  }
  foreach ($archiveFile in $archiveFiles) {
    if (!$allowedArchiveNames.Contains($archiveFile.Name)) {
      throw "$($variant.VariantName) contains archive outside its configured targets: $($archiveFile.FullName)"
    }
  }

  $hasTexturePayload = @(
    Get-ChildItem -LiteralPath $stagingPath -Recurse -File |
      Where-Object { $_.Extension -ieq '.dds' }
  ).Count -ne 0
  $expectedArchiveNames = @(
    foreach ($archiveTarget in @($variant.ArchiveTargets)) {
      $archiveDefinition = $archiveDefinitions[[string]$archiveTarget]
      if ($archiveDefinition.Required -or
          ($hasTexturePayload -and [string]$archiveTarget -like 'Textures*')) {
        "$($variant.PackageBaseName) - $($archiveDefinition.FileSuffix)"
      }
    }
  )
  $expectedStagingInventory = @("$($variant.PackageBaseName).esm")
  $expectedStagingInventory += @($expectedInterfaceInventory | ForEach-Object { "Interface/$_" })
  $expectedStagingInventory += $expectedArchiveNames
  Assert-Inventory `
    -RootPath $stagingPath `
    -ExpectedPaths $expectedStagingInventory `
    -Description "$($variant.VariantName) complete staging payload"

  $stagedMainEntryPaths = [System.Collections.Generic.Dictionary[string,string]]::new(
    [System.StringComparer]::Ordinal
  )
  $expectedMainEntries = @(
    Get-ChildItem -LiteralPath $interfacePath -Recurse -File |
      ForEach-Object {
        $relativePath = $_.FullName.Substring($interfacePath.Length + 1).Replace(
          [System.IO.Path]::DirectorySeparatorChar,
          [System.IO.Path]::AltDirectorySeparatorChar
        )
        $entryName = "interface/$($relativePath.ToLowerInvariant())"
        if ($stagedMainEntryPaths.ContainsKey($entryName)) {
          throw "$($variant.VariantName) staging contains a case-insensitive archive path collision: $entryName"
        }
        $stagedMainEntryPaths.Add($entryName, $_.FullName)
        $entryName
      } |
      Sort-Object
  )
  foreach ($archiveTarget in @($variant.ArchiveTargets | Where-Object { [string]$_ -match '^Main(?:_|$)' })) {
    $archiveDefinition = $archiveDefinitions[[string]$archiveTarget]
    $archivePath = Join-Path $stagingPath "$($variant.PackageBaseName) - $($archiveDefinition.FileSuffix)"
    $entries = @(Get-GeneralBa2Entries -Path $archivePath)
    $actualEntryNames = @($entries.Name | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object)
    if ($actualEntryNames.Count -ne $expectedMainEntries.Count -or
        [string]::Join("`n", $actualEntryNames) -cne [string]::Join("`n", $expectedMainEntries)) {
      throw "$($variant.VariantName) $archiveTarget archive inventory does not match its staged Interface payload."
    }
    if ([string]$archiveTarget -match '^Main(?:_|$)') {
      $compressedEntries = @($entries | Where-Object { [uint32]$_.PackedSize -ne 0 })
      if ($compressedEntries.Count -ne 0) {
        throw "$($variant.VariantName) $archiveTarget must store every entry without BA2 compression; compressed entries: $($compressedEntries.Name -join ', ')"
      }
    }

    foreach ($entry in $entries) {
      $entryName = $entry.Name.ToLowerInvariant()
      if (!$entryName.StartsWith("interface/", [System.StringComparison]::Ordinal)) {
        throw "$($variant.VariantName) $archiveTarget contains an unexpected non-Interface entry '$($entry.Name)'."
      }
      if (!$stagedMainEntryPaths.ContainsKey($entryName)) {
        throw "$($variant.VariantName) $archiveTarget contains an archive entry not present in staging: '$entryName'."
      }
      $stagedEntryPath = $stagedMainEntryPaths[$entryName]
      $archiveHash = Get-ByteArraySha256 -Bytes (Read-GeneralBa2EntryBytes -Entry $entry)
      $stagedHash = Get-Sha256 -Path $stagedEntryPath
      if ($archiveHash -cne $stagedHash) {
        throw "$($variant.VariantName) $archiveTarget '$entryName' is not byte-identical to staging."
      }
    }
  }

  Write-Host -ForegroundColor Green "$($variant.VariantName) profile, payload, movies, plugin, and archives are valid."
}
