$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-CanvasResourceBytes([string]$Path) {
  # Match the repository's LF resource contract even before Git normalizes a local edit.
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n","`n").Replace("`r","`n")
  return ,([Text.UTF8Encoding]::new($false).GetBytes($text))
}

function Test-CanvasConsumerVariant([string]$Key) {
  $consumerProfilePath = Join-Path $PSScriptRoot "../Scaleform/variants/$Key/build.psd1"
  if (!(Test-Path -LiteralPath $consumerProfilePath)) { return $false }
  $configuration = Import-PowerShellDataFile -LiteralPath $consumerProfilePath
  return $configuration.ContainsKey('CanvasConsumer') -and [bool]$configuration.CanvasConsumer
}

function Get-CanvasConsumerSources([string]$RepositoryRoot,[string]$Key) {
  $pending = [Collections.Generic.Queue[string]]::new()
  $result = [ordered]@{}
  $pending.Enqueue('index.html')
  while ($pending.Count -gt 0) {
    $relative = $pending.Dequeue()
    if ($result.Contains($relative)) { continue }
    if ($relative -notmatch '^[a-z0-9][a-z0-9./-]*\.(html|css|svg)$' -or $relative -match '(^|/)\.\.?(/|$)') { throw "Invalid Canvas resource path: $relative" }
    $path = if ($relative -eq 'index.html') { Join-Path $RepositoryRoot "Canvas/variants/$Key/index.html" } else { Join-Path $RepositoryRoot "Canvas/resources/$relative" }
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Canvas resource: $relative" }
    $result[$relative] = $path
    if ($relative.EndsWith('.html')) {
      $text = [IO.File]::ReadAllText($path)
      foreach ($match in [regex]::Matches($text,'(?:src|href|data-vw-assets)="([^"]+)"')) {
        foreach ($dependency in $match.Groups[1].Value.Split(' ')) { $pending.Enqueue($dependency) }
      }
    }
  }
  return $result
}

function Get-CanvasConsumerSourceDigest([string]$RepositoryRoot,[string]$Key) {
  $files = @(
    Get-ChildItem (Join-Path $RepositoryRoot 'Canvas/actionscript') -File -Filter *.as
    Get-ChildItem (Join-Path $RepositoryRoot 'Papyrus/Venworks/CustomizableHUD') -File -Filter *.psc
    Get-Item (Join-Path $RepositoryRoot "Canvas/variants/$Key/VWHudVariant.as")
    Get-Item (Join-Path $RepositoryRoot 'Canvas/build/consumer.build.xml')
    Get-ChildItem (Join-Path $RepositoryRoot 'Spriggit') -Recurse -File
  )
  $lines = @($files | Sort-Object FullName | ForEach-Object {
    $canonical = [IO.File]::ReadAllText($_.FullName).Replace("`r`n","`n").Replace("`r","`n")
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($canonical)))
    [IO.Path]::GetRelativePath($RepositoryRoot,$_.FullName).Replace('\','/')+' '+$hash
  })
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))
}

function Write-CanvasConsumerEvidence([string]$RepositoryRoot,[string]$Key,[string]$Payload,[string]$Destination) {
  $hashes = [ordered]@{}
  foreach ($file in Get-ChildItem -LiteralPath $Payload -Recurse -File | Sort-Object FullName) {
    $relative = [IO.Path]::GetRelativePath($Payload,$file.FullName).Replace('\','/')
    $hashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  }
  $record = [ordered]@{Schema='VWHUD_CANVAS_BUILD/1';Variant=$Key;SourceDigest=(Get-CanvasConsumerSourceDigest $RepositoryRoot $Key);Files=$hashes}
  [IO.File]::WriteAllText($Destination,($record | ConvertTo-Json -Depth 5)+"`n")
}

function Publish-CanvasConsumerPayload([string]$RepositoryRoot,[string]$Key,[string]$Payload,[string]$Destination,[string]$Evidence,[string]$ExpectedEvidence,[switch]$UpdateExpectedHashes) {
  Assert-CanvasConsumerPayload $RepositoryRoot $Key $Payload $Evidence
  if (!$UpdateExpectedHashes) {
    if (!(Test-Path -LiteralPath $ExpectedEvidence) -or [IO.File]::ReadAllText($ExpectedEvidence) -cne [IO.File]::ReadAllText($Evidence)) { throw "Consumer build differs from approved expected hashes; use -UpdateExpectedHashes to record the new local build: $Key" }
  }
  $destinationRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\','/')
  if (!(Test-Path -LiteralPath $destinationRoot -PathType Container)) { throw "Staging destination does not exist: $Key" }
  $staging = Get-Item -LiteralPath $destinationRoot
  if ($staging.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Pass the verified physical module directory rather than a staging junction.' }
  if (@(Get-ChildItem -LiteralPath $destinationRoot -Recurse -Force | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count -ne 0) { throw "Nested reparse points prevent safe staging: $Key" }
  $backup = Join-Path $RepositoryRoot ('.work/canvas-rollback/'+[guid]::NewGuid().ToString('N')+'/'+$Key)
  New-Item -ItemType Directory -Force $backup | Out-Null
  $previous = @(Get-ChildItem -LiteralPath $destinationRoot -Force)
  foreach ($item in $previous) { Copy-Item -LiteralPath $item.FullName -Destination $backup -Recurse -Force }
  try {
    foreach ($item in $previous) {
      $resolved = [IO.Path]::GetFullPath($item.FullName)
      if (!$resolved.StartsWith($destinationRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Staging removal escaped its verified destination.' }
      Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    foreach ($item in Get-ChildItem -LiteralPath $Payload -Force) { Copy-Item -LiteralPath $item.FullName -Destination $destinationRoot -Recurse -Force }
    Assert-CanvasConsumerPayload $RepositoryRoot $Key $destinationRoot $Evidence
    if ($UpdateExpectedHashes) {
      New-Item -ItemType Directory -Force ([IO.Path]::GetDirectoryName($ExpectedEvidence)) | Out-Null
      Copy-Item -LiteralPath $Evidence -Destination $ExpectedEvidence -Force
    }
  }
  catch {
    foreach ($item in Get-ChildItem -LiteralPath $destinationRoot -Force) {
      $resolved = [IO.Path]::GetFullPath($item.FullName)
      if (!$resolved.StartsWith($destinationRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Rollback removal escaped its verified destination.' }
      Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    foreach ($item in Get-ChildItem -LiteralPath $backup -Force) { Copy-Item -LiteralPath $item.FullName -Destination $destinationRoot -Recurse -Force }
    throw
  }
  Write-Host "Staged $Key Canvas consumer; previous complete package retained at $backup"
}

function Assert-CanvasConsumerPayload([string]$RepositoryRoot,[string]$Key,[string]$Payload,[string]$Evidence,[switch]$Archives) {
  . (Join-Path $PSScriptRoot 'sharedScaleformMovies.ps1')
  . (Join-Path $PSScriptRoot 'sharedCanvasArtifactReaders.ps1')
  $record = Get-Content -LiteralPath $Evidence -Raw | ConvertFrom-Json -AsHashtable
  if ($record.Schema -cne 'VWHUD_CANVAS_BUILD/1' -or $record.Variant -cne $Key -or $record.SourceDigest -cne (Get-CanvasConsumerSourceDigest $RepositoryRoot $Key)) { throw "Canvas build evidence does not match current sources: $Key" }
  $namespace = 'venworks.vwhud.'+$Key.ToLowerInvariant()
  $prefix = "Interface/VenworksCanvas/Consumers/$namespace/"
  $resources = Get-CanvasConsumerSources $RepositoryRoot $Key
  $expected = @($resources.Keys | ForEach-Object { $prefix+$_ }) + @(($prefix+'normal.swf'),($prefix+'large.swf'),'Scripts/Venworks/CustomizableHUD/HudRegistrar.pex','Scripts/Venworks/CustomizableHUD/HudEffectsPublisher.pex')
  $plugins = @($record.Files.Keys | Where-Object { $_ -match '^[^/]+\.esm$' })
  if ($plugins.Count -ne 1) { throw "Invalid plugin evidence: $Key" }
  $expected += $plugins
  if ((($record.Files.Keys | Sort-Object) -join "`n") -cne (($expected | Sort-Object) -join "`n")) { throw "Unexpected consumer build inventory: $Key" }
  foreach ($relative in $expected) {
    $path = Join-Path $Payload $relative
    if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $record.Files[$relative]) { throw "Consumer artifact differs from build evidence: $Key/$relative" }
  }
  foreach ($relative in $resources.Keys) {
    $sourceHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData((Get-CanvasResourceBytes $resources[$relative])))
    if ($sourceHash -cne $record.Files[$prefix+$relative]) { throw "Stale consumer resource: $Key/$relative" }
  }
  foreach ($movie in @('normal.swf','large.swf')) {
    $path = Join-Path $Payload ($prefix+$movie)
    Assert-ScaleformMovieEncoding -Path $path -Context "$Key/$movie" -ExpectedSignature CWS
    $metadata = Get-ScaleformMovieMetadata -Path $path -Context "$Key/$movie"
    if ($metadata.StageWidth -ne 1920 -or $metadata.StageHeight -ne 1080 -or $metadata.FrameRate -ne 30) { throw "Unexpected consumer movie dimensions: $Key/$movie" }
    $inspection = Get-ScaleformMovieInspection -Path $path -Context "$Key/$movie"
    if ($inspection.AbcCount -ne 1) { throw "Unexpected consumer bytecode inventory: $Key/$movie" }
    [xml]$manifest = Get-Content (Join-Path $RepositoryRoot 'Canvas/build/consumer.build.xml') -Raw
    foreach ($token in $manifest.movieBuild.requiredTokens.token) { if (!$inspection.Text.Contains([string]$token)) { throw "Missing consumer bytecode token: $token" } }
    foreach ($token in $manifest.movieBuild.forbiddenTokens.token) { if ($inspection.Text.Contains([string]$token)) { throw "Forbidden consumer bytecode token: $token" } }
    if (!$inspection.Text.Contains($namespace)) { throw "Consumer namespace mismatch: $Key" }
  }
  $archiveNames = @()
  if ($Archives) {
    $archivePayload = @($expected | Where-Object { $_ -notlike '*.esm' })
    $archiveSources = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($relative in $archivePayload) { $archiveSources.Add($relative,(Join-Path $Payload $relative)) }
    foreach ($suffix in @('Main','Main_XBox','Main_PS')) {
      $archiveName = [IO.Path]::GetFileNameWithoutExtension($plugins[0])+" - $suffix.ba2"
      $archiveNames += $archiveName
      $entries = @(Get-GeneralBa2Entries -Path (Join-Path $Payload $archiveName))
      $wanted = @($archivePayload | ForEach-Object {$_.ToLowerInvariant()} | Sort-Object)
      $actual = @($entries.Name | ForEach-Object {$_.Replace('\','/').ToLowerInvariant()} | Sort-Object)
      if (($wanted -join "`n") -cne ($actual -join "`n")) { throw "Consumer archive inventory mismatch: $Key/$suffix" }
      foreach ($entry in $entries) {
        if ($entry.PackedSize -ne 0) { throw "Consumer archives require uncompressed General entries: $Key/$suffix" }
        # Archive2 lowercases names; use the declared path on case-sensitive checkouts.
        $staged = $archiveSources[$entry.Name.Replace('\','/')]
        if ((Get-ByteArraySha256 -Bytes (Read-GeneralBa2EntryBytes -Entry $entry)) -cne (Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash) { throw "Consumer archive bytes differ: $Key/$suffix/$($entry.Name)" }
      }
    }
  }
  $actualFiles = @(Get-ChildItem -LiteralPath $Payload -Recurse -File | ForEach-Object {[IO.Path]::GetRelativePath($Payload,$_.FullName).Replace('\','/')})
  $allowed = @($expected) + $archiveNames
  if (!$Archives) { $actualFiles = @($actualFiles | Where-Object {$_ -notmatch '^[^/]+\.ba2$'}) }
  if ((($actualFiles | Sort-Object) -join "`n") -cne (($allowed | Sort-Object) -join "`n")) { throw "Consumer payload contains missing or competing files: $Key" }
  Write-Host "Verified $Key consumer artifact identities, resources, bytecode tokens, and payload inventory."
}
