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
    [string]$Context
  )

  $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
  if ($bytes.Length -lt 8) {
    throw "$Context is too short to contain a complete Scaleform header: $resolvedPath"
  }

  $signature = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 3)
  $extension = [System.IO.Path]::GetExtension($resolvedPath)
  $expectedSignature = if ($extension -ceq ".gfx") { "GFX" } elseif ($extension -ceq ".swf") { "CWS" } else { "" }
  if ([string]::IsNullOrEmpty($expectedSignature)) {
    throw "$Context has an unsupported Scaleform extension '$extension': $resolvedPath"
  }
  if ($signature -cne $expectedSignature) {
    throw "$Context must use the Bethesda $expectedSignature encoding for '$extension'; found $signature."
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
