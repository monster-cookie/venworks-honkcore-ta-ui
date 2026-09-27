<#
.SYNOPSIS
Builds and stages one or more VWHUD Canvas consumer variants.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$JavaPath,
  [Parameter(Mandatory)][string]$FlexSdkPath,
  [Parameter(Mandatory)][string]$CanvasProjectPath,
  [string]$CanvasEnvironmentPath,
  [Alias('VariantKey')][string[]]$VariantKeys,
  [switch]$UpdateExpectedHashes,
  [switch]$Committed
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  if ($Committed) {
    . (Join-Path $PSScriptRoot 'sharedConfig.ps1') -SkipEnvironment
  }
  else {
    . (Join-Path $PSScriptRoot 'sharedConfig.ps1')
  }
}
. (Join-Path $PSScriptRoot 'sharedCanvasConsumers.ps1')

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)
if ([string]::IsNullOrWhiteSpace($CanvasEnvironmentPath)) {
  $CanvasEnvironmentPath = Join-Path $CanvasProjectPath '.env'
}
$candidateRoot = Join-Path $repositoryRoot ('.work/canvas-consumers/' + [guid]::NewGuid().ToString('N'))
& (Join-Path $PSScriptRoot 'buildCanvasConsumers.ps1') `
  -VariantKeys @($variants.VariantKey) `
  -JavaPath $JavaPath `
  -FlexSdkPath $FlexSdkPath `
  -CanvasProjectPath $CanvasProjectPath `
  -EnvironmentPath $CanvasEnvironmentPath `
  -OutputDirectory $candidateRoot

foreach ($variant in $variants) {
  $destination = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $variant.StagingFolderPath))
  if (!$Committed) {
    if (!(Test-Path -LiteralPath $destination -PathType Container)) {
      throw "$($variant.VariantName) staging junction is missing: $destination"
    }
    $junction = Get-Item -LiteralPath $destination
    $physical = [IO.Path]::GetFullPath($variant.PluginModulePath)
    if ($junction.LinkType -ne 'Junction' -or @($junction.Target).Count -ne 1 -or [IO.Path]::GetFullPath([string]$junction.Target[0]) -ine $physical) {
      throw "$($variant.VariantName) staging junction does not match its configured module directory."
    }
    $destination = $physical
  }

  $key = [string]$variant.VariantKey
  Publish-CanvasConsumerPayload `
    -RepositoryRoot $repositoryRoot `
    -Key $key `
    -Payload (Join-Path $candidateRoot $key) `
    -Destination $destination `
    -Evidence (Join-Path $candidateRoot "$key.build.json") `
    -ExpectedEvidence (Join-Path $repositoryRoot "CanvasConsumer/build/expected/$key.json") `
    -UpdateExpectedHashes:$UpdateExpectedHashes
}

Write-Host -ForegroundColor Cyan 'Built and staged the selected Canvas consumer variants.'
