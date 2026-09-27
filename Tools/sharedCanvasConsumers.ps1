$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-CanvasResourceBytes([string]$Path) {
  # Match the repository's LF resource contract even before Git normalizes a local edit.
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n","`n").Replace("`r","`n")
  return ,([Text.UTF8Encoding]::new($false).GetBytes($text))
}

function Test-CanvasConsumerVariant([string]$Key) {
  $normalizedKey = $Key.ToUpperInvariant()
  if ($normalizedKey -notin @('VWKS', 'TA', 'FC', 'CF', 'MIN')) { return $false }
  return Test-Path -LiteralPath (Join-Path $PSScriptRoot "../CanvasConsumer/variants/$normalizedKey") -PathType Container
}

function Get-CanvasConsumerSources([string]$RepositoryRoot,[string]$Key) {
  $pending = [Collections.Generic.Queue[string]]::new()
  $result = [ordered]@{}
  $pending.Enqueue('index.html')
  while ($pending.Count -gt 0) {
    $relative = $pending.Dequeue()
    if ($result.Contains($relative)) { continue }
    if ($relative -notmatch '^[a-z0-9][a-z0-9./-]*\.(html|css|svg)$' -or $relative -match '(^|/)\.\.?(/|$)') { throw "Invalid Canvas resource path: $relative" }
    $path = if ($relative -eq 'index.html') { Join-Path $RepositoryRoot "CanvasConsumer/variants/$Key/index.html" } else { Join-Path $RepositoryRoot "CanvasConsumer/resources/$relative" }
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
    Get-ChildItem (Join-Path $RepositoryRoot 'CanvasConsumer/actionscript') -File -Filter *.as
    Get-ChildItem (Join-Path $RepositoryRoot 'Papyrus/Venworks/CustomizableHUD') -File -Filter *.psc
    Get-Item (Join-Path $RepositoryRoot "CanvasConsumer/variants/$Key/VWHudVariant.as")
    Get-Item (Join-Path $RepositoryRoot 'CanvasConsumer/build/consumer.build.xml')
    Get-ChildItem (Join-Path $RepositoryRoot 'Spriggit') -Recurse -File
  )
  $lines = @($files | Sort-Object FullName | ForEach-Object {
    $canonical = [IO.File]::ReadAllText($_.FullName).Replace("`r`n","`n").Replace("`r","`n")
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($canonical)))
    [IO.Path]::GetRelativePath($RepositoryRoot,$_.FullName).Replace('\','/')+' '+$hash
  })
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))
}

function Get-CanvasConsumerBuildRecord([string]$RepositoryRoot,[string]$Key,[string]$Evidence) {
  if (!(Test-Path -LiteralPath $Evidence -PathType Leaf)) { throw "Missing Canvas build evidence: $Key" }
  $record = Get-Content -LiteralPath $Evidence -Raw | ConvertFrom-Json -AsHashtable
  if ($record.Schema -cne 'VWHUD_CANVAS_BUILD/1' -or $record.Variant -cne $Key -or $record.SourceDigest -cne (Get-CanvasConsumerSourceDigest $RepositoryRoot $Key)) {
    throw "Canvas build evidence does not match current sources: $Key"
  }
  return $record
}

function Get-CanvasConsumerBuildInventory([string]$RepositoryRoot,[string]$Key,[hashtable]$Record) {
  $namespace = 'venworks.vwhud.'+$Key.ToLowerInvariant()
  $prefix = "Interface/VenworksCanvas/Consumers/$namespace/"
  $resources = Get-CanvasConsumerSources $RepositoryRoot $Key
  $plugins = @($Record.Files.Keys | Where-Object { $_ -match '^[^/]+\.esm$' })
  if ($plugins.Count -ne 1) { throw "Invalid plugin evidence: $Key" }
  $expected = @($resources.Keys | ForEach-Object { $prefix+$_ }) + @(($prefix+'normal.swf'),($prefix+'large.swf'),'Scripts/Venworks/CustomizableHUD/HudRegistrar.pex','Scripts/Venworks/CustomizableHUD/HudEffectsPublisher.pex') + $plugins
  if ((($Record.Files.Keys | Sort-Object) -join "`n") -cne (($expected | Sort-Object) -join "`n")) { throw "Unexpected consumer build inventory: $Key" }
  foreach ($relative in $resources.Keys) {
    $sourceHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData((Get-CanvasResourceBytes $resources[$relative])))
    if ($sourceHash -cne $Record.Files[$prefix+$relative]) { throw "Stale consumer resource: $Key/$relative" }
  }
  return [pscustomobject]@{
    Namespace = $namespace
    Prefix = $prefix
    Resources = $resources
    Plugin = [string]$plugins[0]
    Expected = @($expected)
    ArchivePayload = @($expected | Where-Object { $_ -notlike '*.esm' })
  }
}

function Assert-CanvasConsumerMovie([string]$RepositoryRoot,[string]$Key,[string]$Namespace,[string]$Movie,[string]$Path) {
  Assert-ScaleformMovieEncoding -Path $Path -Context "$Key/$Movie" -ExpectedSignature CWS
  $metadata = Get-ScaleformMovieMetadata -Path $Path -Context "$Key/$Movie"
  if ($metadata.StageWidth -ne 1920 -or $metadata.StageHeight -ne 1080 -or $metadata.FrameRate -ne 30) { throw "Unexpected consumer movie dimensions: $Key/$Movie" }
  $inspection = Get-ScaleformMovieInspection -Path $Path -Context "$Key/$Movie"
  if ($inspection.AbcCount -ne 1) { throw "Unexpected consumer bytecode inventory: $Key/$Movie" }
  [xml]$manifest = Get-Content (Join-Path $RepositoryRoot 'CanvasConsumer/build/consumer.build.xml') -Raw
  foreach ($token in $manifest.movieBuild.requiredTokens.token) { if (!$inspection.Text.Contains([string]$token)) { throw "Missing consumer bytecode token: $token" } }
  foreach ($token in $manifest.movieBuild.forbiddenTokens.token) { if ($inspection.Text.Contains([string]$token)) { throw "Forbidden consumer bytecode token: $token" } }
  if (!$inspection.Text.Contains($Namespace)) { throw "Consumer namespace mismatch: $Key" }
}

function Assert-CanvasConsumerArchivePayload([string]$RepositoryRoot,[string]$Key,[string]$Payload,[string]$Evidence,[switch]$AllowUnmanagedFiles) {
  . (Join-Path $PSScriptRoot 'sharedScaleformMovies.ps1')
  . (Join-Path $PSScriptRoot 'sharedCanvasArtifactReaders.ps1')
  $record = Get-CanvasConsumerBuildRecord $RepositoryRoot $Key $Evidence
  $inventory = Get-CanvasConsumerBuildInventory $RepositoryRoot $Key $record
  $pluginPath = Join-Path $Payload $inventory.Plugin
  if (!(Test-Path -LiteralPath $pluginPath -PathType Leaf) -or (Get-FileHash -LiteralPath $pluginPath -Algorithm SHA256).Hash -cne $record.Files[$inventory.Plugin]) {
    throw "Consumer plugin differs from build evidence: $Key"
  }
  $recordPaths = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($relative in $inventory.ArchivePayload) { $recordPaths.Add($relative.Replace('\','/'),$relative) }
  $archiveNames = [Collections.Generic.List[string]]::new()
  $movieFiles = @{}
  foreach ($suffix in @('Main','Main_XBox','Main_PS')) {
    $archiveName = [IO.Path]::GetFileNameWithoutExtension($inventory.Plugin)+" - $suffix.ba2"
    $archiveNames.Add($archiveName)
    $archivePath = Join-Path $Payload $archiveName
    $entries = @(Get-GeneralBa2Entries -Path $archivePath)
    $wanted = @($inventory.ArchivePayload | ForEach-Object {$_.ToLowerInvariant()} | Sort-Object)
    $actual = @($entries.Name | ForEach-Object {$_.Replace('\','/').ToLowerInvariant()} | Sort-Object)
    if (($wanted -join "`n") -cne ($actual -join "`n")) { throw "Consumer archive inventory mismatch: $Key/$suffix" }
    foreach ($entry in $entries) {
      if ($entry.PackedSize -ne 0) { throw "Consumer archives require uncompressed General entries: $Key/$suffix" }
      $archiveRelative = $entry.Name.Replace('\','/')
      if (!$recordPaths.ContainsKey($archiveRelative)) { throw "Consumer archive contains an undeclared entry: $Key/$suffix/$archiveRelative" }
      $declaredRelative = $recordPaths[$archiveRelative]
      $bytes = [byte[]](Read-GeneralBa2EntryBytes -Entry $entry)
      if ((Get-ByteArraySha256 -Bytes $bytes) -cne $record.Files[$declaredRelative]) { throw "Consumer archive bytes differ: $Key/$suffix/$archiveRelative" }
      if ($suffix -ceq 'Main' -and ($archiveRelative.EndsWith('/normal.swf',[StringComparison]::OrdinalIgnoreCase) -or $archiveRelative.EndsWith('/large.swf',[StringComparison]::OrdinalIgnoreCase))) {
        $movieFiles[[IO.Path]::GetFileName($archiveRelative)] = $bytes
      }
    }
  }
  $actualFiles = @(Get-ChildItem -LiteralPath $Payload -Recurse -File | ForEach-Object {[IO.Path]::GetRelativePath($Payload,$_.FullName).Replace('\','/')})
  $allowed = @($inventory.Plugin) + @($archiveNames)
  if (!$AllowUnmanagedFiles -and (($actualFiles | Sort-Object) -join "`n") -cne (($allowed | Sort-Object) -join "`n")) { throw "Archive-only consumer payload contains missing or competing files: $Key" }
  $inspectionRoot = Join-Path $RepositoryRoot ('.work/archive-verification/'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $inspectionRoot | Out-Null
  try {
    foreach ($movie in @('normal.swf','large.swf')) {
      if (!$movieFiles.ContainsKey($movie)) { throw "Consumer archive is missing $movie for inspection: $Key" }
      $moviePath = Join-Path $inspectionRoot $movie
      [IO.File]::WriteAllBytes($moviePath,[byte[]]$movieFiles[$movie])
      Assert-CanvasConsumerMovie $RepositoryRoot $Key $inventory.Namespace $movie $moviePath
    }
  }
  finally {
    $resolvedInspectionRoot = [IO.Path]::GetFullPath($inspectionRoot)
    $workRoot = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot '.work'))
    if ($resolvedInspectionRoot.StartsWith($workRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedInspectionRoot -PathType Container)) {
      Remove-Item -LiteralPath $resolvedInspectionRoot -Recurse -Force
    }
  }
  Write-Host "Verified $Key archive-only consumer artifacts, resources, bytecode tokens, and payload inventory."
}

function Get-CanvasConsumerLoosePackageFiles([string]$RepositoryRoot,[string]$Key,[string]$Payload,[string]$Evidence) {
  . (Join-Path $PSScriptRoot 'sharedCanvasArtifactReaders.ps1')
  Assert-CanvasConsumerArchivePayload $RepositoryRoot $Key $Payload $Evidence
  $record = Get-CanvasConsumerBuildRecord $RepositoryRoot $Key $Evidence
  $inventory = Get-CanvasConsumerBuildInventory $RepositoryRoot $Key $record
  $archivePath = Join-Path $Payload ([IO.Path]::GetFileNameWithoutExtension($inventory.Plugin)+' - Main.ba2')
  foreach ($entry in @(Get-GeneralBa2Entries -Path $archivePath)) {
    [pscustomobject]@{ EntryName=$entry.Name.Replace('\','/'); Bytes=[byte[]](Read-GeneralBa2EntryBytes -Entry $entry) }
  }
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

function Assert-CanvasConsumerPayload([string]$RepositoryRoot,[string]$Key,[string]$Payload,[string]$Evidence) {
  . (Join-Path $PSScriptRoot 'sharedScaleformMovies.ps1')
  . (Join-Path $PSScriptRoot 'sharedCanvasArtifactReaders.ps1')
  $record = Get-CanvasConsumerBuildRecord $RepositoryRoot $Key $Evidence
  $inventory = Get-CanvasConsumerBuildInventory $RepositoryRoot $Key $record
  $namespace = $inventory.Namespace
  $prefix = $inventory.Prefix
  $expected = $inventory.Expected
  foreach ($relative in $expected) {
    $path = Join-Path $Payload $relative
    if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $record.Files[$relative]) { throw "Consumer artifact differs from build evidence: $Key/$relative" }
  }
  foreach ($movie in @('normal.swf','large.swf')) {
    $path = Join-Path $Payload ($prefix+$movie)
    Assert-CanvasConsumerMovie $RepositoryRoot $Key $namespace $movie $path
  }
  $actualFiles = @(Get-ChildItem -LiteralPath $Payload -Recurse -File | ForEach-Object {[IO.Path]::GetRelativePath($Payload,$_.FullName).Replace('\','/')})
  if ((($actualFiles | Sort-Object) -join "`n") -cne (($expected | Sort-Object) -join "`n")) { throw "Consumer payload contains missing or competing files: $Key" }
  Write-Host "Verified $Key consumer artifact identities, resources, bytecode tokens, and payload inventory."
}
