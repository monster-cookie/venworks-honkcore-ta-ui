$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Read-CwsExpectedHash {
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

function Write-CwsExpectedHash {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Hash,

    [Parameter(Mandatory = $true)]
    [string]$FileName
  )

  $parentPath = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $parentPath | Out-Null
  [System.IO.File]::WriteAllText(
    $Path,
    "$($Hash.ToUpperInvariant())  $FileName$([Environment]::NewLine)",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Get-Ps5CwsMovieDefinitions {
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.IDictionary]$VariantBuildProfile,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot
  )

  if (!$VariantBuildProfile.Contains('Ps5CwsMovies')) {
    return @()
  }

  $resolvedRepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $repositoryPrefix = $resolvedRepositoryRoot + [System.IO.Path]::DirectorySeparatorChar
  $definitions = @($VariantBuildProfile.Ps5CwsMovies)
  if ($definitions.Count -eq 0) {
    throw "PS5 CWS movie configuration must declare at least one movie."
  }

  $result = [System.Collections.Generic.List[object]]::new()
  $inputFileNames = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
  )
  foreach ($definition in $definitions) {
    $inputFileName = [string]$definition.InputFileName
    $sourceRelativePath = [string]$definition.SourcePath
    $expectedHashRelativePath = [string]$definition.ExpectedHashPath
    if ([string]::IsNullOrWhiteSpace($inputFileName) -or
        $inputFileName -cne [System.IO.Path]::GetFileName($inputFileName) -or
        [System.IO.Path]::GetExtension($inputFileName) -cne '.gfx' -or
        !$inputFileNames.Add($inputFileName)) {
      throw "PS5 CWS movie configuration contains an unsafe or duplicate GFX input: $inputFileName"
    }
    foreach ($relativePath in @($sourceRelativePath, $expectedHashRelativePath)) {
      if ([string]::IsNullOrWhiteSpace($relativePath) -or
          [System.IO.Path]::IsPathRooted($relativePath) -or
          $relativePath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "PS5 CWS movie configuration contains an unsafe repository path: $relativePath"
      }
    }

    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRepositoryRoot $sourceRelativePath))
    $expectedHashPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRepositoryRoot $expectedHashRelativePath))
    if (!$sourcePath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        !$expectedHashPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        [System.IO.Path]::GetExtension($sourcePath) -cne '.swf' -or
        [System.IO.Path]::GetFileNameWithoutExtension($sourcePath) -cne
          [System.IO.Path]::GetFileNameWithoutExtension($inputFileName)) {
      throw "PS5 CWS movie configuration must map '$inputFileName' to a same-named repository SWF."
    }

    $result.Add([pscustomobject]@{
      InputFileName = $inputFileName
      SwfFileName = [System.IO.Path]::GetFileName($sourcePath)
      SourcePath = $sourcePath
      ExpectedHashPath = $expectedHashPath
    })
  }

  return @($result)
}

function Assert-CwsMovieEquivalent {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GfxPath,

    [Parameter(Mandatory = $true)]
    [string]$CwsPath,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $gfxBytes = [System.IO.File]::ReadAllBytes($GfxPath)
  $cwsBytes = [System.IO.File]::ReadAllBytes($CwsPath)
  if ($gfxBytes.Length -lt 8 -or
      [System.Text.Encoding]::ASCII.GetString($gfxBytes, 0, 3) -cne "GFX") {
    throw "$Context source is not an uncompressed Scaleform GFX movie: $GfxPath"
  }
  if ($cwsBytes.Length -lt 9 -or
      [System.Text.Encoding]::ASCII.GetString($cwsBytes, 0, 3) -cne "CWS") {
    throw "$Context output is not a ZLIB-compressed SWF movie: $CwsPath"
  }
  if ($gfxBytes[3] -ne $cwsBytes[3] -or
      [System.BitConverter]::ToUInt32($cwsBytes, 4) -ne [uint32]$gfxBytes.Length) {
    throw "$Context CWS header does not preserve the source version and uncompressed length."
  }

  $compressedPayload = [System.IO.MemoryStream]::new(
    $cwsBytes,
    8,
    $cwsBytes.Length - 8,
    $false
  )
  $decompressedPayload = [System.IO.MemoryStream]::new()
  try {
    $zlibStream = [System.IO.Compression.ZLibStream]::new(
      $compressedPayload,
      [System.IO.Compression.CompressionMode]::Decompress,
      $true
    )
    try {
      $zlibStream.CopyTo($decompressedPayload)
    }
    finally {
      $zlibStream.Dispose()
    }
  }
  finally {
    $compressedPayload.Dispose()
  }

  try {
    $payloadBytes = $decompressedPayload.ToArray()
  }
  finally {
    $decompressedPayload.Dispose()
  }
  if ($payloadBytes.Length -ne $gfxBytes.Length - 8) {
    throw "$Context decompressed payload length does not match the source movie."
  }
  for ($index = 0; $index -lt $payloadBytes.Length; $index++) {
    if ($payloadBytes[$index] -ne $gfxBytes[$index + 8]) {
      throw "$Context changes movie data at uncompressed byte offset $($index + 8)."
    }
  }
}

function ConvertTo-CwsMovie {
  param(
    [Parameter(Mandatory = $true)]
    [string]$GfxPath,

    [Parameter(Mandatory = $true)]
    [string]$CwsPath,

    [Parameter(Mandatory = $true)]
    [string]$JavaPath,

    [Parameter(Mandatory = $true)]
    [string]$JpexsJarPath,

    [Parameter(Mandatory = $true)]
    [string]$WorkDirectory,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $resolvedGfxPath = (Resolve-Path -LiteralPath $GfxPath -ErrorAction Stop).Path
  $resolvedJavaPath = (Resolve-Path -LiteralPath $JavaPath -ErrorAction Stop).Path
  $resolvedJpexsJarPath = (Resolve-Path -LiteralPath $JpexsJarPath -ErrorAction Stop).Path
  $resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
  New-Item -ItemType Directory -Force -Path $resolvedWorkDirectory | Out-Null
  $temporaryDirectory = Join-Path $resolvedWorkDirectory ([guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
  try {
    $uncompressedSwfPath = Join-Path $temporaryDirectory "movie.swf"
    $compressedSwfPath = Join-Path $temporaryDirectory "movie.cws.swf"
    & $resolvedJavaPath @(
      '-jar',
      $resolvedJpexsJarPath,
      '-header',
      '-set',
      'gfx',
      'false',
      $resolvedGfxPath,
      $uncompressedSwfPath
    )
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $uncompressedSwfPath -PathType Leaf)) {
      throw "JPEXS failed to convert $Context from GFX to uncompressed SWF."
    }

    $gfxBytes = [System.IO.File]::ReadAllBytes($resolvedGfxPath)
    $swfBytes = [System.IO.File]::ReadAllBytes($uncompressedSwfPath)
    if ($gfxBytes.Length -ne $swfBytes.Length -or
        [System.Text.Encoding]::ASCII.GetString($swfBytes, 0, 3) -cne 'FWS') {
      throw "JPEXS did not preserve $Context while changing its GFX signature."
    }
    for ($index = 3; $index -lt $gfxBytes.Length; $index++) {
      if ($gfxBytes[$index] -ne $swfBytes[$index]) {
        throw "JPEXS changed $Context at uncompressed byte offset $index."
      }
    }

    & $resolvedJavaPath @(
      '-jar',
      $resolvedJpexsJarPath,
      '-compress',
      'zlib',
      $uncompressedSwfPath,
      $compressedSwfPath
    )
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $compressedSwfPath -PathType Leaf)) {
      throw "JPEXS failed to ZLIB-compress $Context."
    }
    Assert-CwsMovieEquivalent -GfxPath $resolvedGfxPath -CwsPath $compressedSwfPath -Context $Context

    $outputDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($CwsPath))
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    Copy-Item -LiteralPath $compressedSwfPath -Destination $CwsPath -Force
  }
  finally {
    $resolvedTemporaryDirectory = [System.IO.Path]::GetFullPath($temporaryDirectory)
    $workPrefix = $resolvedWorkDirectory.TrimEnd(
      [System.IO.Path]::DirectorySeparatorChar,
      [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    if (!$resolvedTemporaryDirectory.StartsWith($workPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to remove a CWS work directory outside its owned root: $resolvedTemporaryDirectory"
    }
    if (Test-Path -LiteralPath $resolvedTemporaryDirectory -PathType Container) {
      Remove-Item -LiteralPath $resolvedTemporaryDirectory -Recurse -Force
    }
  }
}
