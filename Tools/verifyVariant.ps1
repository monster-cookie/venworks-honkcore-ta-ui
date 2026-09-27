<#
.SYNOPSIS
Verifies staged or committed VWHUD Canvas consumer payloads.
#>
[CmdletBinding()]
param(
  [Alias('VariantKey')][string[]]$VariantKeys,
  [switch]$Committed,
  [switch]$PreArchiveMutation
)

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

foreach ($variant in @(Get-ModuleVariants -VariantKeys $VariantKeys)) {
  $key = [string]$variant.VariantKey
  if (!(Test-CanvasConsumerVariant -Key $key)) {
    throw "Variant '$key' is not a configured Canvas consumer."
  }

  $payload = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $variant.StagingFolderPath))
  if (!$Committed) {
    if (!(Test-Path -LiteralPath $payload -PathType Container)) {
      throw "$($variant.VariantName) staging junction is missing: $payload"
    }
    $junction = Get-Item -LiteralPath $payload
    $physical = [IO.Path]::GetFullPath($variant.PluginModulePath)
    if ($junction.LinkType -ne 'Junction' -or @($junction.Target).Count -ne 1 -or [IO.Path]::GetFullPath([string]$junction.Target[0]) -ine $physical) {
      throw "$($variant.VariantName) staging junction does not match its configured module directory."
    }
    $payload = $physical
  }

  Assert-CanvasConsumerPayload `
    -RepositoryRoot $repositoryRoot `
    -Key $key `
    -Payload $payload `
    -Evidence (Join-Path $repositoryRoot "CanvasConsumer/build/expected/$key.json") `
    -Archives:(!$PreArchiveMutation)
}

Write-Host -ForegroundColor Cyan 'Selected Canvas consumer payloads are valid.'
