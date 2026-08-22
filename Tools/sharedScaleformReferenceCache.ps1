function Resolve-ScaleformReferenceRequiredFile {
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

function Resolve-ScaleformReferenceRequiredDirectory {
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

function Resolve-ScaleformReferenceChildPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [Parameter(Mandatory = $true)]
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) {
    throw "$Description must be a non-empty relative path: $RelativePath"
  }

  $normalizedRelativePath = $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
  $segments = @($normalizedRelativePath.Split([System.IO.Path]::DirectorySeparatorChar))
  $unsafeSegments = @($segments | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' })
  if ($segments.Count -eq 0 -or $unsafeSegments.Count -ne 0) {
    throw "$Description contains an unsafe path segment: $RelativePath"
  }

  $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $normalizedRelativePath))
  if (!$resolvedPath.StartsWith(
      $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar,
      [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description resolves outside its allowed root: $RelativePath"
  }

  return $resolvedPath
}

function Assert-ScaleformReferenceCachePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CacheRoot,

    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $resolvedRoot = [System.IO.Path]::GetFullPath($CacheRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $resolvedPath = [System.IO.Path]::GetFullPath($Path)
  if (!$resolvedPath.StartsWith(
      $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar,
      [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description is outside the configured cache root: $resolvedPath"
  }

  return $resolvedPath
}

function Read-ScaleformReferenceManifest {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
  )

  $resolvedManifestPath = Resolve-ScaleformReferenceRequiredFile `
    -Path $ManifestPath `
    -Description 'Scaleform reference-cache manifest'
  [xml]$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw
  if (!$manifest.scaleformReferenceCache -or [string]$manifest.scaleformReferenceCache.version -ne '1') {
    throw "Unsupported Scaleform reference-cache manifest version: $resolvedManifestPath"
  }

  $movies = [System.Collections.Generic.List[object]]::new()
  $files = [System.Collections.Generic.List[object]]::new()
  $inputFiles = @{}
  foreach ($entryType in @('movie', 'file')) {
    $nodes = @($manifest.SelectNodes("/scaleformReferenceCache/$($entryType)s/$entryType"))
    foreach ($node in $nodes) {
      $group = [string]$node.group
      $inputFile = ([string]$node.inputFile).Replace('\', '/')
      if ($group -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        throw "Invalid reference-cache group '$group' in $resolvedManifestPath."
      }
      if ([string]::IsNullOrWhiteSpace($inputFile)) {
        throw "Reference-cache $entryType is missing inputFile in $resolvedManifestPath."
      }
      [void](Resolve-ScaleformReferenceChildPath `
        -Root (Split-Path -Parent $resolvedManifestPath) `
        -RelativePath $inputFile `
        -Description "Reference-cache $entryType inputFile")
      if ($inputFiles.ContainsKey($inputFile)) {
        throw "Duplicate reference-cache inputFile '$inputFile' in $resolvedManifestPath."
      }
      $inputFiles[$inputFile] = $true
      $entry = [PSCustomObject]@{
        Group = $group
        InputFile = $inputFile
      }
      if ($entryType -eq 'movie') {
        $movies.Add($entry)
      }
      else {
        $files.Add($entry)
      }
    }
  }

  if ($movies.Count -eq 0) {
    throw "Scaleform reference-cache manifest contains no movies: $resolvedManifestPath"
  }

  return [PSCustomObject]@{
    Path = $resolvedManifestPath
    Movies = @($movies)
    Files = @($files)
  }
}

function New-ScaleformReferenceCacheContext {
  param(
    [Parameter(Mandatory = $true)]
    [string]$JavaPath,

    [Parameter(Mandatory = $true)]
    [string]$JpexsJarPath,

    [Parameter(Mandatory = $true)]
    [string]$VanillaInterfacePath,

    [Parameter(Mandatory = $true)]
    [string]$WorkDirectory,

    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
  )

  $resolvedJavaPath = Resolve-ScaleformReferenceRequiredFile -Path $JavaPath -Description 'Java executable'
  $resolvedJpexsJarPath = Resolve-ScaleformReferenceRequiredFile -Path $JpexsJarPath -Description 'JPEXS JAR'
  $resolvedVanillaInterfacePath = Resolve-ScaleformReferenceRequiredDirectory `
    -Path $VanillaInterfacePath `
    -Description 'Vanilla Interface directory'
  $manifest = Read-ScaleformReferenceManifest -ManifestPath $ManifestPath
  $resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
  New-Item -ItemType Directory -Force -Path $resolvedWorkDirectory | Out-Null
  $cacheRoot = Join-Path $resolvedWorkDirectory 'bgs-decompiled'
  New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

  return [PSCustomObject]@{
    JavaPath = $resolvedJavaPath
    JpexsJarPath = $resolvedJpexsJarPath
    JpexsSha256 = (Get-FileHash -LiteralPath $resolvedJpexsJarPath -Algorithm SHA256).Hash
    VanillaInterfacePath = $resolvedVanillaInterfacePath
    WorkDirectory = $resolvedWorkDirectory
    CacheRoot = $cacheRoot
    Manifest = $manifest
  }
}

function Write-ScaleformReferenceMetadata {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [object]$Metadata
  )

  $json = $Metadata | ConvertTo-Json -Depth 4
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Assert-ScaleformReferenceMovieXml {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Cached Scaleform XML is missing: $Path"
  }
  [xml]$movie = Get-Content -LiteralPath $Path -Raw
  if (!$movie.swf) {
    throw "Cached Scaleform XML does not contain an swf root: $Path"
  }
}

function Test-ScaleformReferenceMovieCache {
  param(
    [Parameter(Mandatory = $true)]
    [string]$EntryPath,

    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$SourceSha256,

    [Parameter(Mandatory = $true)]
    [string]$JpexsSha256
  )

  $metadataPath = Join-Path $EntryPath 'cache.json'
  $movieXmlPath = Join-Path $EntryPath 'movie.xml'
  $scriptsPath = Join-Path $EntryPath 'scripts'
  if (!(Test-Path -LiteralPath $metadataPath -PathType Leaf) -or
      !(Test-Path -LiteralPath $scriptsPath -PathType Container)) {
    return $false
  }

  try {
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ([int]$metadata.schemaVersion -ne 1 -or
        [string]$metadata.kind -ne 'movie' -or
        [string]$metadata.inputFile -ne $InputFile -or
        [string]$metadata.sourceSha256 -ne $SourceSha256 -or
        [string]$metadata.jpexsSha256 -ne $JpexsSha256) {
      return $false
    }
    Assert-ScaleformReferenceMovieXml -Path $movieXmlPath
  }
  catch {
    return $false
  }

  return $true
}

function Invoke-ScaleformReferenceJpexs {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Context,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  & $Context.JavaPath -jar $Context.JpexsJarPath @Arguments | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "JPEXS failed while $Description (exit code $LASTEXITCODE)."
  }
}

function Get-ScaleformReferenceMovie {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Context,

    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [switch]$ForceRefresh
  )

  $normalizedInputFile = $InputFile.Replace('\', '/')
  $manifestEntries = @($Context.Manifest.Movies | Where-Object {
    $_.InputFile -eq $normalizedInputFile
  })
  if ($manifestEntries.Count -ne 1) {
    throw "Scaleform movie '$normalizedInputFile' must appear exactly once in $($Context.Manifest.Path)."
  }

  $sourcePath = Resolve-ScaleformReferenceChildPath `
    -Root $Context.VanillaInterfacePath `
    -RelativePath $normalizedInputFile `
    -Description 'Vanilla Scaleform movie'
  $sourcePath = Resolve-ScaleformReferenceRequiredFile -Path $sourcePath -Description 'Vanilla Scaleform movie'
  $sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
  $entryPath = Resolve-ScaleformReferenceChildPath `
    -Root (Join-Path $Context.CacheRoot 'movies') `
    -RelativePath $normalizedInputFile `
    -Description 'Scaleform movie cache entry'

  if (!$ForceRefresh -and (Test-ScaleformReferenceMovieCache `
      -EntryPath $entryPath `
      -InputFile $normalizedInputFile `
      -SourceSha256 $sourceSha256 `
      -JpexsSha256 $Context.JpexsSha256)) {
    Write-Host -ForegroundColor Green "BGS reference cache hit: $normalizedInputFile"
    return [PSCustomObject]@{
      InputFile = $normalizedInputFile
      Group = $manifestEntries[0].Group
      SourceSha256 = $sourceSha256
      EntryPath = $entryPath
      MovieXmlPath = (Join-Path $entryPath 'movie.xml')
      ScriptsPath = (Join-Path $entryPath 'scripts')
      CacheHit = $true
    }
  }

  $stagingRoot = Join-Path $Context.CacheRoot '.staging'
  New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
  $stagingEntry = Join-Path $stagingRoot ([guid]::NewGuid().ToString('N'))
  $stagingEntry = Assert-ScaleformReferenceCachePath `
    -CacheRoot $Context.CacheRoot `
    -Path $stagingEntry `
    -Description 'Scaleform movie staging entry'
  New-Item -ItemType Directory -Path $stagingEntry | Out-Null

  try {
    $movieXmlPath = Join-Path $stagingEntry 'movie.xml'
    $scriptsPath = Join-Path $stagingEntry 'scripts'
    Write-Host -ForegroundColor Cyan "Refreshing BGS reference cache: $normalizedInputFile"
    Invoke-ScaleformReferenceJpexs `
      -Context $Context `
      -Arguments @('-swf2xml', $sourcePath, $movieXmlPath) `
      -Description "decompiling $normalizedInputFile"
    Invoke-ScaleformReferenceJpexs `
      -Context $Context `
      -Arguments @('-format', 'script:as', '-export', 'script', $stagingEntry, $sourcePath) `
      -Description "exporting $normalizedInputFile ActionScript"
    if (!(Test-Path -LiteralPath $scriptsPath -PathType Container)) {
      throw "JPEXS did not create the expected script directory for $normalizedInputFile."
    }
    Assert-ScaleformReferenceMovieXml -Path $movieXmlPath

    $scriptCount = @(Get-ChildItem -LiteralPath $scriptsPath -Recurse -File -Filter '*.as').Count
    Write-ScaleformReferenceMetadata `
      -Path (Join-Path $stagingEntry 'cache.json') `
      -Metadata ([ordered]@{
        schemaVersion = 1
        kind = 'movie'
        group = [string]$manifestEntries[0].Group
        inputFile = $normalizedInputFile
        sourceSha256 = $sourceSha256
        jpexsSha256 = $Context.JpexsSha256
        scriptCount = $scriptCount
      })

    $entryParent = Split-Path -Parent $entryPath
    New-Item -ItemType Directory -Force -Path $entryParent | Out-Null
    if (Test-Path -LiteralPath $entryPath) {
      $resolvedEntryPath = Assert-ScaleformReferenceCachePath `
        -CacheRoot $Context.CacheRoot `
        -Path $entryPath `
        -Description 'Stale Scaleform movie cache entry'
      Remove-Item -LiteralPath $resolvedEntryPath -Recurse -Force
    }
    Move-Item -LiteralPath $stagingEntry -Destination $entryPath
  }
  finally {
    if (Test-Path -LiteralPath $stagingEntry) {
      Remove-Item -LiteralPath $stagingEntry -Recurse -Force
    }
  }

  Write-Host -ForegroundColor Green "Cached BGS Scaleform reference: $normalizedInputFile"
  return [PSCustomObject]@{
    InputFile = $normalizedInputFile
    Group = $manifestEntries[0].Group
    SourceSha256 = $sourceSha256
    EntryPath = $entryPath
    MovieXmlPath = (Join-Path $entryPath 'movie.xml')
    ScriptsPath = (Join-Path $entryPath 'scripts')
    CacheHit = $false
  }
}

function Sync-ScaleformReferenceFile {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Context,

    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [switch]$ForceRefresh
  )

  $normalizedInputFile = $InputFile.Replace('\', '/')
  $manifestEntries = @($Context.Manifest.Files | Where-Object {
    $_.InputFile -eq $normalizedInputFile
  })
  if ($manifestEntries.Count -ne 1) {
    throw "Reference file '$normalizedInputFile' must appear exactly once in $($Context.Manifest.Path)."
  }

  $sourcePath = Resolve-ScaleformReferenceChildPath `
    -Root $Context.VanillaInterfacePath `
    -RelativePath $normalizedInputFile `
    -Description 'Vanilla reference file'
  $sourcePath = Resolve-ScaleformReferenceRequiredFile -Path $sourcePath -Description 'Vanilla reference file'
  $sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
  $targetPath = Resolve-ScaleformReferenceChildPath `
    -Root (Join-Path $Context.CacheRoot 'files') `
    -RelativePath $normalizedInputFile `
    -Description 'Reference-file cache entry'
  $metadataPath = $targetPath + '.cache.json'
  $cacheHit = $false
  if (!$ForceRefresh -and
      (Test-Path -LiteralPath $targetPath -PathType Leaf) -and
      (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    try {
      $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
      $cachedSha256 = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
      $cacheHit = [int]$metadata.schemaVersion -eq 1 -and
        [string]$metadata.kind -eq 'file' -and
        [string]$metadata.inputFile -eq $normalizedInputFile -and
        [string]$metadata.sourceSha256 -eq $sourceSha256 -and
        $cachedSha256 -eq $sourceSha256
    }
    catch {
      $cacheHit = $false
    }
  }

  if ($cacheHit) {
    Write-Host -ForegroundColor Green "BGS reference file cache hit: $normalizedInputFile"
  }
  else {
    $targetParent = Split-Path -Parent $targetPath
    New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
    $stagingPath = $targetPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    $stagingPath = Assert-ScaleformReferenceCachePath `
      -CacheRoot $Context.CacheRoot `
      -Path $stagingPath `
      -Description 'Reference-file staging path'
    try {
      Copy-Item -LiteralPath $sourcePath -Destination $stagingPath
      if ((Get-FileHash -LiteralPath $stagingPath -Algorithm SHA256).Hash -ne $sourceSha256) {
        throw "Reference-file cache copy hash mismatch: $normalizedInputFile"
      }
      Move-Item -LiteralPath $stagingPath -Destination $targetPath -Force
    }
    finally {
      if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Force
      }
    }
    Write-ScaleformReferenceMetadata `
      -Path $metadataPath `
      -Metadata ([ordered]@{
        schemaVersion = 1
        kind = 'file'
        group = [string]$manifestEntries[0].Group
        inputFile = $normalizedInputFile
        sourceSha256 = $sourceSha256
      })
    Write-Host -ForegroundColor Green "Cached BGS reference file: $normalizedInputFile"
  }

  return [PSCustomObject]@{
    InputFile = $normalizedInputFile
    Group = $manifestEntries[0].Group
    SourceSha256 = $sourceSha256
    Path = $targetPath
    CacheHit = $cacheHit
  }
}
