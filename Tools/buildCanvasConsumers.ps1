<#
.SYNOPSIS
Builds independent VWHUD Canvas consumers, scripts, and plugins into an isolated payload directory.
.DESCRIPTION
Uses the existing Flex, Starfield Papyrus, and Spriggit toolchains. The output contains no vanilla HUD movies or Canvas Example assets. Publishing or archiving is handled by the consumer pipeline after validation.
#>
[CmdletBinding()]
param(
  [ValidateSet('VWKS','TA','FC','CF','MIN')][string[]]$VariantKeys = @('VWKS','TA','FC','CF','MIN'),
  [Parameter(Mandatory)][string]$JavaPath,
  [Parameter(Mandatory)][string]$FlexSdkPath,
  [Parameter(Mandatory)][string]$CanvasProjectPath,
  [Parameter(Mandatory)][string]$EnvironmentPath,
  [Parameter(Mandatory)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'sharedCanvasConsumers.ps1')
. (Join-Path $PSScriptRoot 'sharedCanvasCompatibility.ps1')
if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'sharedConfig.ps1') -SkipEnvironment
}
$workRoot = Join-Path $repositoryRoot '.work'
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if (!$outputRoot.StartsWith($workRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
  throw 'Consumer build output must be beneath the repository .work directory.'
}
if (Test-Path -LiteralPath $outputRoot) { throw 'Choose a fresh output directory; existing candidates are never overwritten.' }

function RequiredFile([string]$Path) {
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required tool or input is missing: $Path" }
  (Resolve-Path -LiteralPath $Path).Path
}
function Tool([string]$Path,[string]$FileName) {
  if (Test-Path -LiteralPath $Path -PathType Container) { $Path = Join-Path $Path $FileName }
  RequiredFile $Path
}

# Read only the compiler settings needed for this operation. Do not import credentials.
$settings = @{}
$allowed = @('TOOL_PATH_PAPYRUS_COMPILER','PAPYRUS_COMPILER_FLAGS','PAPYRUS_SCRIPTS_SOURCE_PATH','TOOL_PATH_SPRIGGIT','STEAM_DATA_FOLDER')
foreach ($line in [IO.File]::ReadAllLines((RequiredFile $EnvironmentPath))) {
  if ($line -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)$' -and $matches[1] -in $allowed) {
    $settings[$matches[1]] = $matches[2].Trim().Trim('"')
  }
}
foreach ($name in $allowed) { if (!$settings.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($settings[$name])) { throw "Missing toolchain setting: $name" } }
$java = RequiredFile $JavaPath
$flex = [IO.Path]::GetFullPath($FlexSdkPath)
$mxmlc = RequiredFile (Join-Path $flex 'lib/mxmlc.jar')
$playerglobal = RequiredFile (Join-Path $flex 'frameworks/libs/player/11.1/playerglobal.swc')
$compiler = Tool $settings.TOOL_PATH_PAPYRUS_COMPILER 'PapyrusCompiler.exe'
$flags = Tool $settings.PAPYRUS_COMPILER_FLAGS 'Starfield_Papyrus_Flags.flg'
$spriggit = Tool $settings.TOOL_PATH_SPRIGGIT 'Spriggit.CLI.exe'
$canvasRoot = [IO.Path]::GetFullPath($CanvasProjectPath)
$canvasSources = Join-Path $canvasRoot 'Papyrus'
Assert-VWHudCanvasCompatibility -CanvasProjectPath $canvasRoot
foreach ($directory in @($settings.PAPYRUS_SCRIPTS_SOURCE_PATH,$settings.STEAM_DATA_FOLDER)) {
  if (!(Test-Path -LiteralPath $directory -PathType Container)) { throw 'Configured game source/data directory does not exist.' }
}

New-Item -ItemType Directory -Path $outputRoot | Out-Null
$scriptCandidate = Join-Path $outputRoot 'compiled-scripts'
New-Item -ItemType Directory -Path $scriptCandidate | Out-Null
foreach ($source in Get-ChildItem (Join-Path $repositoryRoot 'Papyrus/Venworks/CustomizableHUD') -Filter *.psc) {
  & $compiler $source.FullName '-f' '-optimize' "-flags=$flags" "-output=$scriptCandidate" "-import=$repositoryRoot/Papyrus;$canvasSources;$($settings.PAPYRUS_SCRIPTS_SOURCE_PATH)" '-ignorecwd'
  if ($LASTEXITCODE -ne 0) { throw "Papyrus compilation failed: $($source.Name)" }
}

function CopyResources([string]$Entry,[string]$InterfaceDestination,[string]$TextureDestination) {
  $pending = [Collections.Generic.Queue[string]]::new()
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $pending.Enqueue('index.html')
  $sourceRoot = Join-Path $repositoryRoot 'CanvasConsumer/resources'
  while ($pending.Count -gt 0) {
    $relative = $pending.Dequeue()
    if (!$seen.Add($relative)) { continue }
    if ($relative -notmatch '^[a-z0-9][a-z0-9./-]*\.(html|css|svg|dds)$' -or $relative -match '(^|/)\.\.?(/|$)') { throw "Invalid resource path: $relative" }
    $source = if ($relative -eq 'index.html') { $Entry } else { Join-Path $sourceRoot $relative }
    [void](RequiredFile $source)
    $root = if ($relative.EndsWith('.dds',[StringComparison]::OrdinalIgnoreCase)) { $TextureDestination } else { $InterfaceDestination }
    $target = Join-Path $root $relative
    New-Item -ItemType Directory -Force ([IO.Path]::GetDirectoryName($target)) | Out-Null
    [IO.File]::WriteAllBytes($target,(Get-CanvasResourceBytes $source))
    if ($relative.EndsWith('.html')) {
      $text = [IO.File]::ReadAllText($source)
      foreach ($match in [regex]::Matches($text,'(?:src|href|data-vw-assets)="([^"]+)"')) {
        foreach ($path in $match.Groups[1].Value.Split(' ')) { $pending.Enqueue($path) }
      }
    }
  }
  if ($seen.Count -gt 64) { throw 'Consumer exceeds Canvas resource limit.' }
}

foreach ($key in $VariantKeys | Select-Object -Unique) {
  $variantDirectory = Join-Path $repositoryRoot "CanvasConsumer/variants/$key"
  $source = RequiredFile (Join-Path $repositoryRoot 'CanvasConsumer/actionscript/VWHudConsumer.as')
  $variantText = [IO.File]::ReadAllText((RequiredFile (Join-Path $variantDirectory 'VWHudVariant.as')))
  $namespace = [regex]::Match($variantText,'NAMESPACE:String = "([a-z0-9.]+)"').Groups[1].Value
  if ($namespace -cne "venworks.vwhud.$($key.ToLowerInvariant())") { throw "Namespace mismatch: $key" }
  $payload = Join-Path $outputRoot $key
  $consumer = Join-Path $payload "Interface/VenworksCanvas/Consumers/$namespace"
  New-Item -ItemType Directory -Force $consumer | Out-Null
  $arguments = @('-jar',$mxmlc,"-load-config=$flex/frameworks/flex-config.xml",'-compiler.library-path=',"-compiler.external-library-path=$playerglobal",'-compiler.source-path',"$repositoryRoot/CanvasConsumer/actionscript",$variantDirectory,'-compiler.debug=false','-compiler.optimize=true','-use-network=false','-target-player=11.1.0','-swf-version=12','-default-size=1920,1080','-default-frame-rate=30',"-output=$consumer/normal.swf",$source)
  Push-Location (Join-Path $flex 'frameworks')
  try { & $java @arguments; if ($LASTEXITCODE -ne 0) { throw "Consumer compilation failed: $key" } }
  finally { Pop-Location }
  Copy-Item "$consumer/normal.swf" "$consumer/large.swf"
  $textureRoot = Join-Path $payload "Textures/Interface/VenworksCanvas/Consumers/$namespace"
  CopyResources (Join-Path $variantDirectory 'index.html') $consumer $textureRoot
  New-Item -ItemType Directory (Join-Path $payload 'Scripts') | Out-Null
  Copy-Item (Join-Path $scriptCandidate '*') (Join-Path $payload 'Scripts') -Recurse
  $variant = @(Get-ModuleVariants -VariantKeys $key)[0]
  $pluginName = "$($variant.PackageBaseName).esm"
  if (!(Test-Path -LiteralPath (Join-Path $repositoryRoot "Spriggit/$pluginName") -PathType Container)) { throw "Missing Spriggit source for $pluginName" }
  & $spriggit deserialize --InputPath (Join-Path $repositoryRoot "Spriggit/$pluginName") --OutputPath (Join-Path $payload $pluginName) --DataFolder $settings.STEAM_DATA_FOLDER
  if ($LASTEXITCODE -ne 0) { throw "Plugin assembly failed: $key" }
  $evidence = Join-Path $outputRoot "$key.build.json"
  Write-CanvasConsumerEvidence $repositoryRoot $key $payload $evidence
  Assert-CanvasConsumerPayload $repositoryRoot $key $payload $evidence
  Write-Host "Built Canvas consumer payload: $key"
}
