<#
.SYNOPSIS
Creates local staging junctions for release variants.

.PARAMETER VariantKeys
One or more keys from `$Global:ReleaseVariants`. Omit this parameter to process
all release variants. `VariantKey` remains a compatibility alias.
#>
[CmdletBinding()]
param(
  [Alias("VariantKey")]
  [string[]]$VariantKeys
)

# Abort on first error
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# If not loaded already pull in the shared config
if (!$Global:SharedConfigurationLoaded) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . "$PSScriptRoot\sharedConfig.ps1"
}

If (![System.IO.File]::Exists(".env")) {
  Write-Host -ForegroundColor Red "ERROR: .env file must be created and configured to run this."
  Exit
}

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)

foreach ($variant in $variants) {
  Write-Host -ForegroundColor Cyan "Setting variant $($variant.VariantName) using $($variant.StagingFolderPath) and linked to $($variant.PluginModulePath)"

  if ([string]::IsNullOrWhiteSpace($variant.PluginModulePath)) {
    throw "$($variant.VariantName) physical module folder is not configured."
  }
  if (!(Test-Path -LiteralPath $variant.PluginModulePath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $variant.PluginModulePath | Out-Null
  }
  $resolvedModulePath = (Resolve-Path -LiteralPath $variant.PluginModulePath).Path

  if (Test-Path -LiteralPath $variant.StagingFolderPath) {
    $stagingItem = Get-Item -LiteralPath $variant.StagingFolderPath
    if ($stagingItem.LinkType -eq "Junction") {
      $stagingTargets = @($stagingItem.Target)
      if ($stagingTargets.Count -eq 1 -and
          [string]::Equals(
            [System.IO.Path]::GetFullPath([string]$stagingTargets[0]),
            $resolvedModulePath,
            [System.StringComparison]::OrdinalIgnoreCase
          )) {
        Write-Host -ForegroundColor Green "$($variant.VariantName) staging Junction is already configured."
        Continue
      }
      throw "$($variant.VariantName) staging Junction targets a different physical module folder."
    }
    throw "$($variant.VariantName) staging path exists and is not a Junction: $($variant.StagingFolderPath)"
  }

  New-Item -ItemType Junction -Path $variant.StagingFolderPath -Value $resolvedModulePath | Out-Null

  $createdStagingItem = Get-Item -LiteralPath $variant.StagingFolderPath
  if ($createdStagingItem.LinkType -ne "Junction") {
    throw "$($variant.VariantName) staging Junction creation failed."
  }
  $createdTargets = @($createdStagingItem.Target)
  if ($createdTargets.Count -ne 1 -or
      ![string]::Equals(
        [System.IO.Path]::GetFullPath([string]$createdTargets[0]),
        $resolvedModulePath,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
    throw "$($variant.VariantName) staging Junction does not target its configured physical module folder."
  }
}

Write-Host -ForegroundColor Cyan "`n`n"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "**        Variant Junctions Are Configured       **"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "`n`n"
