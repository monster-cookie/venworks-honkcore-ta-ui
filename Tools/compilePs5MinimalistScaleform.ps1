[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\Staging-MIN\Interface"),

  [string]$WorkDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work\ps5-minimalist"),

  [switch]$KeepWork,

  [switch]$UpdateExpectedHashes
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  . "$PSScriptRoot\sharedConfig.ps1"
}

$minimalistVariants = @(Get-ModuleVariants -VariantKey "MIN")
if ($minimalistVariants.Count -ne 1) {
  throw "Expected exactly one Minimalist variant."
}
$minimalistVariant = $minimalistVariants[0]
if (!(Test-Path -LiteralPath $minimalistVariant.StagingFolderPath -PathType Container)) {
  throw "Minimalist staging folder does not exist. Run Tools/setupRepo.ps1 -VariantKey MIN first."
}
$stagingItem = Get-Item -LiteralPath $minimalistVariant.StagingFolderPath
if ($stagingItem.LinkType -ne "Junction") {
  throw "Minimalist staging folder must be a Junction: $($minimalistVariant.StagingFolderPath)"
}

$resolvedStagingPath = (Resolve-Path -LiteralPath $minimalistVariant.StagingFolderPath).Path
$resolvedModulePath = (Resolve-Path -LiteralPath $minimalistVariant.PluginModulePath).Path
$stagingTargets = @($stagingItem.Target)
if ($stagingTargets.Count -ne 1 -or
    ![string]::Equals(
      [System.IO.Path]::GetFullPath([string]$stagingTargets[0]),
      $resolvedModulePath,
      [System.StringComparison]::OrdinalIgnoreCase
    )) {
  throw "Minimalist staging Junction does not target its configured physical module folder."
}
$expectedOutputPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedStagingPath "Interface"))
$requestedOutputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
if (![string]::Equals(
    $requestedOutputPath,
    $expectedOutputPath,
    [System.StringComparison]::OrdinalIgnoreCase
  )) {
  throw "The PS5 Minimalist compiler may write only to '$expectedOutputPath'; requested '$requestedOutputPath'."
}

& (Join-Path $PSScriptRoot "verifyPs5MinimalistScaleform.ps1")

$compileParameters = @{
  JavaPath = $JavaPath
  JpexsJarPath = $JpexsJarPath
  VanillaInterfacePath = $VanillaInterfacePath
  OutputDirectory = @($expectedOutputPath)
  WorkDirectory = $WorkDirectory
  ManifestPath = @(
    (Join-Path $PSScriptRoot "..\Scaleform\hudmenu\build.xml"),
    (Join-Path $PSScriptRoot "..\Scaleform\hudmenu_lrg\build.xml")
  )
  ExpectedHashPathByOutputFile = @{
    "hudmenu.gfx" = (Join-Path $PSScriptRoot "..\Scaleform\ps5-minimalist\validation\hudmenu.sha256")
    "hudmenu_lrg.gfx" = (Join-Path $PSScriptRoot "..\Scaleform\ps5-minimalist\validation\hudmenu_lrg.sha256")
  }
}
if ($KeepWork) {
  $compileParameters.KeepWork = $true
}
if ($UpdateExpectedHashes) {
  $compileParameters.UpdateExpectedHashes = $true
}

Write-Host -ForegroundColor Green "Compiling guarded PS5 Minimalist HUD movies"
& (Join-Path $PSScriptRoot "compileScaleform.ps1") @compileParameters
& (Join-Path $PSScriptRoot "verifyPs5MinimalistScaleform.ps1") `
  -InterfacePath $expectedOutputPath

Write-Host -ForegroundColor Green "PS5 Minimalist Scaleform compile and validation completed."
