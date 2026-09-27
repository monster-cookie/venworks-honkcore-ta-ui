<#
.SYNOPSIS
Builds one or more VWHUD Canvas consumer variants into isolated package inputs.
.PARAMETER Committed
Retained for command compatibility. Builds never mutate installed or committed staging.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$JavaPath,
  [Parameter(Mandatory)][string]$FlexSdkPath,
  [Parameter(Mandatory)][string]$CanvasProjectPath,
  [string]$CanvasEnvironmentPath,
  [string]$PayloadRoot,
  [Alias('VariantKey')][string[]]$VariantKeys,
  [switch]$UpdateExpectedHashes,
  [switch]$Committed
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'sharedConfig.ps1') -SkipEnvironment }
. (Join-Path $PSScriptRoot 'sharedCanvasConsumers.ps1')

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)
if ([string]::IsNullOrWhiteSpace($CanvasEnvironmentPath)) {
  $CanvasEnvironmentPath = Join-Path $CanvasProjectPath '.env'
}
$candidateRoot = Join-Path $repositoryRoot ('.work/canvas-consumers/' + [guid]::NewGuid().ToString('N'))
if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $PayloadRoot = Join-Path $repositoryRoot '.work/canvas-payloads' }
$payloadRootPath = [IO.Path]::GetFullPath($PayloadRoot)
$workRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.work')).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
if (!$payloadRootPath.StartsWith($workRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Consumer payload output must be beneath the repository .work directory.' }
& (Join-Path $PSScriptRoot 'buildCanvasConsumers.ps1') `
  -VariantKeys @($variants.VariantKey) `
  -JavaPath $JavaPath `
  -FlexSdkPath $FlexSdkPath `
  -CanvasProjectPath $CanvasProjectPath `
  -EnvironmentPath $CanvasEnvironmentPath `
  -OutputDirectory $candidateRoot

foreach ($variant in $variants) {
  $key = [string]$variant.VariantKey
  $candidatePayload = Join-Path $candidateRoot $key
  $candidateEvidence = Join-Path $candidateRoot "$key.build.json"
  $expectedEvidence = Join-Path $repositoryRoot "CanvasConsumer/build/expected/$key.json"
  Assert-CanvasConsumerPayload $repositoryRoot $key $candidatePayload $candidateEvidence
  if ($UpdateExpectedHashes) {
    Copy-Item -LiteralPath $candidateEvidence -Destination $expectedEvidence -Force
  }
  elseif (!(Test-Path -LiteralPath $expectedEvidence -PathType Leaf) -or [IO.File]::ReadAllText($expectedEvidence) -cne [IO.File]::ReadAllText($candidateEvidence)) {
    throw "Consumer build differs from approved expected hashes; use -UpdateExpectedHashes to record the new local build: $key"
  }
  $destination = Join-Path $payloadRootPath $key
  if (Test-Path -LiteralPath $destination) {
    $resolvedDestination = [IO.Path]::GetFullPath($destination)
    if (!$resolvedDestination.StartsWith($payloadRootPath.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Consumer payload cleanup escaped its work root.' }
    Remove-Item -LiteralPath $resolvedDestination -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  foreach ($item in Get-ChildItem -LiteralPath $candidatePayload -Force) { Copy-Item -LiteralPath $item.FullName -Destination $destination -Recurse -Force }
  Assert-CanvasConsumerPayload $repositoryRoot $key $destination $expectedEvidence
  Write-Host "Prepared validated package input: $destination"
}

Write-Host -ForegroundColor Cyan 'Built the selected Canvas consumer variants into isolated package inputs.'
