[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$InputPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputXmlPath
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-RequiredFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Description does not exist: $Path"
  }

  return (Resolve-Path -LiteralPath $Path).Path
}

$resolvedJavaPath = Resolve-RequiredFile -Path $JavaPath -Description "Java executable"
$resolvedJpexsJarPath = Resolve-RequiredFile -Path $JpexsJarPath -Description "JPEXS JAR"
$resolvedInputPath = Resolve-RequiredFile -Path $InputPath -Description "Scaleform input"
$resolvedOutputXmlPath = [System.IO.Path]::GetFullPath($OutputXmlPath)
$outputDirectory = Split-Path -Parent $resolvedOutputXmlPath

if (!(Test-Path -LiteralPath $outputDirectory -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

Write-Host -ForegroundColor Cyan "Decompiling $resolvedInputPath"
& $resolvedJavaPath -jar $resolvedJpexsJarPath -swf2xml $resolvedInputPath $resolvedOutputXmlPath

if ($LASTEXITCODE -ne 0) {
  throw "JPEXS failed to decompile $resolvedInputPath (exit code $LASTEXITCODE)."
}

if (!(Test-Path -LiteralPath $resolvedOutputXmlPath -PathType Leaf)) {
  throw "JPEXS reported success but did not create $resolvedOutputXmlPath."
}

Write-Host -ForegroundColor Green "Created temporary XML: $resolvedOutputXmlPath"
