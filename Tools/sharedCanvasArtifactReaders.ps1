# Artifact readers shared with the legacy v2 verifier.
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
