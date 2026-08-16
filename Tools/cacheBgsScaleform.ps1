[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [string]$WorkDirectory = (Join-Path $PSScriptRoot '..\Scaleform\.work'),

  [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Scaleform\reference-cache.xml'),

  [switch]$ForceRefresh
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$cacheHelperPath = Join-Path $PSScriptRoot 'sharedScaleformReferenceCache.ps1'
if (!(Test-Path -LiteralPath $cacheHelperPath -PathType Leaf)) {
  throw "Scaleform reference-cache helper does not exist: $cacheHelperPath"
}
. $cacheHelperPath

$context = New-ScaleformReferenceCacheContext `
  -JavaPath $JavaPath `
  -JpexsJarPath $JpexsJarPath `
  -VanillaInterfacePath $VanillaInterfacePath `
  -WorkDirectory $WorkDirectory `
  -ManifestPath $ManifestPath

$movieResults = [System.Collections.Generic.List[object]]::new()
foreach ($movie in $context.Manifest.Movies) {
  $movieResults.Add((Get-ScaleformReferenceMovie `
    -Context $context `
    -InputFile $movie.InputFile `
    -ForceRefresh:$ForceRefresh))
}

$fileResults = [System.Collections.Generic.List[object]]::new()
foreach ($file in $context.Manifest.Files) {
  $fileResults.Add((Sync-ScaleformReferenceFile `
    -Context $context `
    -InputFile $file.InputFile `
    -ForceRefresh:$ForceRefresh))
}

$movieHitCount = @($movieResults | Where-Object { $_.CacheHit }).Count
$fileHitCount = @($fileResults | Where-Object { $_.CacheHit }).Count
$summaryFormat = 'BGS Scaleform reference cache ready at {0}: {1} movies ({2} hits, {3} refreshed), ' +
  '{4} files ({5} hits, {6} refreshed).'
Write-Host -ForegroundColor Green ($summaryFormat -f
  $context.CacheRoot,
  $movieResults.Count,
  $movieHitCount,
  ($movieResults.Count - $movieHitCount),
  $fileResults.Count,
  $fileHitCount,
  ($fileResults.Count - $fileHitCount)
)
