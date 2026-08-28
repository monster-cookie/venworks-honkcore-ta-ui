$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-ScaleformMovieSignature {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $stream = [System.IO.File]::OpenRead($Path)
  try {
    if ($stream.Length -lt 8) {
      throw "Scaleform movie is too short to contain a complete header: $Path"
    }
    $header = [byte[]]::new(8)
    [void]$stream.Read($header, 0, $header.Length)
  }
  finally {
    $stream.Dispose()
  }

  return [System.Text.Encoding]::ASCII.GetString($header, 0, 3)
}

function Assert-ScaleformMovieEncoding {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Context,

    [ValidateSet("CWS", "GFX")]
    [string]$ExpectedSignature
  )

  $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
  if ($bytes.Length -lt 8) {
    throw "$Context is too short to contain a complete Scaleform header: $resolvedPath"
  }

  $signature = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 3)
  $extension = [System.IO.Path]::GetExtension($resolvedPath)
  $requiredSignature = $ExpectedSignature
  if ([string]::IsNullOrEmpty($requiredSignature)) {
    $requiredSignature = if ($extension -ceq ".gfx") { "GFX" } elseif ($extension -ceq ".swf") { "CWS" } else { "" }
  }
  if ([string]::IsNullOrEmpty($requiredSignature)) {
    throw "$Context has an unsupported Scaleform extension '$extension': $resolvedPath"
  }
  if ($signature -cne $requiredSignature) {
    throw "$Context must use the declared $requiredSignature encoding for '$extension'; found $signature."
  }
  if ($bytes[3] -ne 12) {
    throw "$Context must use Scaleform/SWF version 12; found $($bytes[3])."
  }

  if ($signature -ceq "CWS") {
    $declaredLength = [System.BitConverter]::ToUInt32($bytes, 4)
    if ($declaredLength -le $bytes.Length) {
      throw "$Context CWS header does not declare a larger uncompressed length."
    }

    $compressedStream = [System.IO.MemoryStream]::new(
      $bytes,
      8,
      $bytes.Length - 8,
      $false
    )
    $decompressedStream = [System.IO.MemoryStream]::new()
    $decodedPayloadLength = 0L
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
      $decodedPayloadLength = $decompressedStream.Length
    }
    catch {
      throw "$Context does not contain a valid CWS ZLIB payload: $($_.Exception.Message)"
    }
    finally {
      $decompressedStream.Dispose()
      $compressedStream.Dispose()
    }

    $actualUncompressedLength = [uint64]$decodedPayloadLength + 8
    if ($actualUncompressedLength -ne [uint64]$declaredLength) {
      throw "$Context CWS header declares $declaredLength uncompressed bytes; decoded $actualUncompressedLength."
    }
  }
}

function Get-ScaleformMovieUncompressedBytes {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $movieBytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path)
  $signature = [System.Text.Encoding]::ASCII.GetString($movieBytes, 0, 3)
  if ($signature -cne "CWS") {
    return $movieBytes
  }

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
  return $uncompressedBytes
}

function Read-ScaleformMovieBits {
  param(
    [Parameter(Mandatory = $true)]
    [byte[]]$Bytes,

    [Parameter(Mandatory = $true)]
    [ref]$BitOffset,

    [Parameter(Mandatory = $true)]
    [int]$BitCount,

    [switch]$Signed
  )

  if ($BitCount -lt 1 -or $BitCount -gt 31) {
    throw "Scaleform bit field width is outside the supported range: $BitCount"
  }

  $value = [int64]0
  for ($index = 0; $index -lt $BitCount; $index++) {
    $byteIndex = [int][Math]::Floor($BitOffset.Value / 8.0)
    if ($byteIndex -ge $Bytes.Length) {
      throw "Scaleform movie contains a truncated bit field."
    }
    $bitIndex = 7 - ($BitOffset.Value % 8)
    $value = ($value -shl 1) -bor (($Bytes[$byteIndex] -shr $bitIndex) -band 1)
    $BitOffset.Value++
  }

  if ($Signed -and ($value -band ([int64]1 -shl ($BitCount - 1))) -ne 0) {
    $value -= ([int64]1 -shl $BitCount)
  }
  return $value
}

function Get-ScaleformMovieMetadata {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Context,

    [ValidateSet("CWS", "GFX")]
    [string]$ExpectedSignature
  )

  if ([string]::IsNullOrEmpty($ExpectedSignature)) {
    Assert-ScaleformMovieEncoding -Path $Path -Context $Context
  }
  else {
    Assert-ScaleformMovieEncoding `
      -Path $Path `
      -Context $Context `
      -ExpectedSignature $ExpectedSignature
  }
  $movieBytes = Get-ScaleformMovieUncompressedBytes -Path $Path
  $signature = [System.Text.Encoding]::ASCII.GetString($movieBytes, 0, 3)

  $bitPosition = 64
  $fieldWidth = [int](Read-ScaleformMovieBits -Bytes $movieBytes -BitOffset ([ref]$bitPosition) -BitCount 5)
  $xMin = Read-ScaleformMovieBits -Bytes $movieBytes -BitOffset ([ref]$bitPosition) -BitCount $fieldWidth -Signed
  $xMax = Read-ScaleformMovieBits -Bytes $movieBytes -BitOffset ([ref]$bitPosition) -BitCount $fieldWidth -Signed
  $yMin = Read-ScaleformMovieBits -Bytes $movieBytes -BitOffset ([ref]$bitPosition) -BitCount $fieldWidth -Signed
  $yMax = Read-ScaleformMovieBits -Bytes $movieBytes -BitOffset ([ref]$bitPosition) -BitCount $fieldWidth -Signed
  $frameHeaderOffset = [int][Math]::Ceiling($bitPosition / 8.0)
  if ($frameHeaderOffset + 4 -gt $movieBytes.Length) {
    throw "$Context contains a truncated frame header."
  }

  $rawFrameRate = [System.BitConverter]::ToUInt16($movieBytes, $frameHeaderOffset)
  $frameCount = [System.BitConverter]::ToUInt16($movieBytes, $frameHeaderOffset + 2)
  return [pscustomobject]@{
    Signature = $signature
    Version = [int]$movieBytes[3]
    StageWidth = ([double]($xMax - $xMin)) / 20.0
    StageHeight = ([double]($yMax - $yMin)) / 20.0
    FrameRate = ([double]$rawFrameRate) / 256.0
    FrameCount = [int]$frameCount
  }
}
