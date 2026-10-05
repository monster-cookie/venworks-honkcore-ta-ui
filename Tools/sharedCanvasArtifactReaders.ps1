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

function Expand-Lz4Block {
  param(
    [Parameter(Mandatory = $true)]
    [byte[]]$Source,

    [Parameter(Mandatory = $true)]
    [int]$UnpackedSize
  )

  if ($UnpackedSize -lt 1) {
    throw 'LZ4 texture chunk is empty.'
  }
  $output = [byte[]]::new($UnpackedSize)
  $sourceOffset = 0
  $outputOffset = 0
  while ($outputOffset -lt $UnpackedSize) {
    if ($sourceOffset -ge $Source.Length) {
      throw 'LZ4 texture chunk ended before the unpacked texture was complete.'
    }
    $token = [int]$Source[$sourceOffset]
    $sourceOffset++
    $literalLength = $token -shr 4
    if ($literalLength -eq 15) {
      do {
        if ($sourceOffset -ge $Source.Length) { throw 'LZ4 texture chunk has a truncated literal length.' }
        $extra = [int]$Source[$sourceOffset]
        $sourceOffset++
        $literalLength += $extra
      } while ($extra -eq 255)
    }
    if ($literalLength -gt 0) {
      if ($sourceOffset + $literalLength -gt $Source.Length -or $outputOffset + $literalLength -gt $UnpackedSize) {
        throw 'LZ4 texture chunk literal extends outside the chunk.'
      }
      [System.Array]::Copy($Source, $sourceOffset, $output, $outputOffset, $literalLength)
      $sourceOffset += $literalLength
      $outputOffset += $literalLength
    }
    if ($outputOffset -ge $UnpackedSize) { break }
    if ($sourceOffset + 2 -gt $Source.Length) { throw 'LZ4 texture chunk has a truncated match offset.' }
    $matchOffset = [int]$Source[$sourceOffset] -bor ([int]$Source[$sourceOffset + 1] -shl 8)
    $sourceOffset += 2
    if ($matchOffset -le 0 -or $matchOffset -gt $outputOffset) {
      throw "LZ4 texture chunk has an invalid match offset $matchOffset."
    }
    $matchLength = ($token -band 15) + 4
    if (($token -band 15) -eq 15) {
      do {
        if ($sourceOffset -ge $Source.Length) { throw 'LZ4 texture chunk has a truncated match length.' }
        $extra = [int]$Source[$sourceOffset]
        $sourceOffset++
        $matchLength += $extra
      } while ($extra -eq 255)
    }
    if ($outputOffset + $matchLength -gt $UnpackedSize) {
      throw 'LZ4 texture chunk match extends outside the unpacked texture.'
    }
    for ($index = 0; $index -lt $matchLength; $index++) {
      $output[$outputOffset] = $output[$outputOffset - $matchOffset]
      $outputOffset++
    }
  }
  if ($sourceOffset -ne $Source.Length) {
    throw 'LZ4 texture chunk contains bytes after the unpacked texture.'
  }
  return $output
}

function Expand-DdsTextureChunk {
  param(
    [Parameter(Mandatory = $true)]
    [byte[]]$Stored,

    [Parameter(Mandatory = $true)]
    [uint32]$PackedSize,

    [Parameter(Mandatory = $true)]
    [uint32]$UnpackedSize
  )

  if ($UnpackedSize -lt 1 -or $UnpackedSize -gt 67108864) {
    throw 'DDS texture chunk has an unsupported unpacked size.'
  }
  if ($PackedSize -eq 0) {
    if ($Stored.Length -ne $UnpackedSize) { throw 'Uncompressed DDS texture chunk has an unexpected length.' }
    return $Stored
  }
  if ($Stored.Length -ne $PackedSize) { throw 'Compressed DDS texture chunk has an unexpected length.' }
  $zlib = $Stored.Length -ge 2 -and $Stored[0] -eq 0x78 -and (([int]$Stored[0] * 256 + [int]$Stored[1]) % 31 -eq 0)
  if ($zlib) {
    $compressedStream = [System.IO.MemoryStream]::new($Stored, $false)
    $uncompressedStream = [System.IO.MemoryStream]::new()
    try {
      $zlibStream = [System.IO.Compression.ZLibStream]::new(
        $compressedStream,
        [System.IO.Compression.CompressionMode]::Decompress,
        $true
      )
      try { $zlibStream.CopyTo($uncompressedStream) }
      finally { $zlibStream.Dispose() }
      $pixels = $uncompressedStream.ToArray()
    }
    finally {
      $compressedStream.Dispose()
      $uncompressedStream.Dispose()
    }
    if ($pixels.Length -ne $UnpackedSize) { throw 'Zlib DDS texture chunk has an unexpected uncompressed length.' }
    return $pixels
  }
  return Expand-Lz4Block -Source $Stored -UnpackedSize ([int]$UnpackedSize)
}

function Get-DdsBa2Entries {
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
    if (($version -ne 2 -and $version -ne 3) -or $archiveType -cne 'DX10' -or
        $fileCount -lt 1 -or $fileCount -gt 10000 -or $nameTableOffset -ge [uint64]$stream.Length) {
      throw "Archive is not a supported DDS texture BA2: $Path"
    }
    [void]$reader.ReadBytes($(if ($version -eq 3) { 12 } else { 8 }))

    $records = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $fileCount; $index++) {
      [void]$reader.ReadUInt32()
      [void]$reader.ReadBytes(4)
      [void]$reader.ReadUInt32()
      [void]$reader.ReadByte()
      $chunkCount = [int]$reader.ReadByte()
      $chunkHeaderSize = [int]$reader.ReadUInt16()
      $height = [int]$reader.ReadUInt16()
      $width = [int]$reader.ReadUInt16()
      $mipCount = [int]$reader.ReadByte()
      [void]$reader.ReadByte()
      [void]$reader.ReadByte()
      [void]$reader.ReadByte()
      if ($chunkCount -lt 1 -or $chunkHeaderSize -ne 24 -or $width -lt 1 -or $height -lt 1) {
        throw "Archive contains an invalid DDS file record at index ${index}: $Path"
      }
      $chunks = [System.Collections.Generic.List[object]]::new()
      for ($chunkIndex = 0; $chunkIndex -lt $chunkCount; $chunkIndex++) {
        $offset = $reader.ReadUInt64()
        $packedSize = $reader.ReadUInt32()
        $unpackedSize = $reader.ReadUInt32()
        [void]$reader.ReadUInt16()
        [void]$reader.ReadUInt16()
        $sentinel = $reader.ReadUInt32()
        $storedSize = if ($packedSize -eq 0) { [uint64]$unpackedSize } else { [uint64]$packedSize }
        if ($sentinel -ne 3131961357 -or $unpackedSize -lt 1 -or
            $offset -lt 24 -or $offset + $storedSize -gt $nameTableOffset) {
          throw "Archive contains an invalid DDS chunk at index ${index}: $Path"
        }
        $chunks.Add([pscustomobject]@{
          Offset = $offset
          PackedSize = $packedSize
          UnpackedSize = $unpackedSize
        })
      }
      $records.Add([pscustomobject]@{
        Width = $width
        Height = $height
        MipCount = $mipCount
        Chunks = @($chunks)
        ArchivePath = $Path
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
    }
    return @($records)
  }
  finally {
    $reader.Dispose()
    $stream.Dispose()
  }
}

function Read-DdsBa2EntryBytes {
  param(
    [Parameter(Mandatory = $true)]
    [psobject]$Entry
  )

  $chunks = @($Entry.Chunks)
  $stream = [System.IO.File]::OpenRead([string]$Entry.ArchivePath)
  try {
    $parts = [System.Collections.Generic.List[byte[]]]::new()
    $total = 0
    foreach ($chunk in $chunks) {
      $storedSize = if ([uint32]$chunk.PackedSize -eq 0) { [int]$chunk.UnpackedSize } else { [int]$chunk.PackedSize }
      $stream.Position = [int64]$chunk.Offset
      $stored = [byte[]]::new($storedSize)
      $readCount = $stream.Read($stored, 0, $stored.Length)
      if ($readCount -ne $stored.Length) {
        throw "Unable to read DDS BA2 entry '$($Entry.Name)' from $($Entry.ArchivePath)."
      }
      $pixels = [byte[]](Expand-DdsTextureChunk -Stored $stored -PackedSize ([uint32]$chunk.PackedSize) -UnpackedSize ([uint32]$chunk.UnpackedSize))
      $total += $pixels.Length
      $parts.Add($pixels)
    }
  }
  finally {
    $stream.Dispose()
  }

  $result = [byte[]]::new($total)
  $offset = 0
  foreach ($part in $parts) {
    [System.Array]::Copy($part, 0, $result, $offset, $part.Length)
    $offset += $part.Length
  }
  return $result
}

function Get-DdsFilePixels {
  param(
    [Parameter(Mandatory = $true)]
    [byte[]]$Bytes
  )

  if ($Bytes.Length -lt 128 -or [System.Text.Encoding]::ASCII.GetString($Bytes, 0, 4) -cne 'DDS ' -or
      [System.BitConverter]::ToUInt32($Bytes, 4) -ne 124) {
    throw 'DDS file does not contain a 124-byte header.'
  }
  $height = [int][System.BitConverter]::ToUInt32($Bytes, 12)
  $width = [int][System.BitConverter]::ToUInt32($Bytes, 16)
  $fourCc = [System.Text.Encoding]::ASCII.GetString($Bytes, 84, 4)
  $pixelOffset = if ($fourCc -ceq 'DX10') { 148 } else { 128 }
  if ($width -lt 1 -or $height -lt 1 -or $Bytes.Length -le $pixelOffset) {
    throw 'DDS file does not contain a pixel payload.'
  }
  $pixels = [byte[]]::new($Bytes.Length - $pixelOffset)
  [System.Array]::Copy($Bytes, $pixelOffset, $pixels, 0, $pixels.Length)
  return [pscustomobject]@{
    Width = $width
    Height = $height
    Pixels = $pixels
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
