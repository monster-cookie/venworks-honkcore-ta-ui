<#
.SYNOPSIS
Creates the local staging junction for the isolated PS5 debug variant.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . (Join-Path $PSScriptRoot "sharedConfig.ps1")
}

$variant = @(Get-DiagnosticVariants -VariantKeys "PS5DBG")[0]
if ([string]::IsNullOrWhiteSpace([string]$variant.PluginModulePath)) {
  throw "PS5 Debug physical module folder is not configured. Set MODULE_VARIANT_PS5DBG_PATH in .env."
}

$modulePath = [System.IO.Path]::GetFullPath([string]$variant.PluginModulePath)
if (!(Test-Path -LiteralPath $modulePath -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $modulePath | Out-Null
}
$resolvedModulePath = (Resolve-Path -LiteralPath $modulePath).Path
$stagingPath = [System.IO.Path]::GetFullPath([string]$variant.StagingFolderPath)

if (Test-Path -LiteralPath $stagingPath) {
  $stagingItem = Get-Item -LiteralPath $stagingPath
  if ($stagingItem.LinkType -ne "Junction") {
    throw "PS5 Debug staging path exists and is not a Junction: $stagingPath"
  }
  $targets = @($stagingItem.Target)
  if ($targets.Count -ne 1 -or
      ![string]::Equals(
        [System.IO.Path]::GetFullPath([string]$targets[0]),
        $resolvedModulePath,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
    throw "PS5 Debug staging Junction targets a different physical module folder."
  }
  Write-Host -ForegroundColor Green "PS5 Debug staging Junction is already configured."
  return
}

New-Item -ItemType Junction -Path $stagingPath -Value $resolvedModulePath | Out-Null
$createdItem = Get-Item -LiteralPath $stagingPath
if ($createdItem.LinkType -ne "Junction") {
  throw "PS5 Debug staging Junction creation failed."
}
$createdTargets = @($createdItem.Target)
if ($createdTargets.Count -ne 1 -or
    ![string]::Equals(
      [System.IO.Path]::GetFullPath([string]$createdTargets[0]),
      $resolvedModulePath,
      [System.StringComparison]::OrdinalIgnoreCase
    )) {
  throw "PS5 Debug staging Junction does not target its configured physical module folder."
}

Write-Host -ForegroundColor Green "PS5 Debug staging Junction is configured at $stagingPath."
