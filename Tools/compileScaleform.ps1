[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\Staging-CUI\Interface"),

  [string]$WorkDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work"),

  [string[]]$ManifestPath = @(
    (Join-Path $PSScriptRoot "..\Scaleform\hudmenu\build.xml"),
    (Join-Path $PSScriptRoot "..\Scaleform\hudmenu_lrg\build.xml")
  ),

  [switch]$KeepWork
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

function Read-Sha256File {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $hashLine = Get-Content -LiteralPath $Path | Where-Object {
    $_ -match '^\s*[A-Fa-f0-9]{64}(?:\s|$)'
  } | Select-Object -First 1

  if (!$hashLine) {
    throw "No SHA-256 value was found in $Path."
  }

  return ([regex]::Match($hashLine, '[A-Fa-f0-9]{64}').Value).ToUpperInvariant()
}

function Invoke-Jpexs {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  & $script:ResolvedJavaPath -jar $script:ResolvedJpexsJarPath @Arguments

  if ($LASTEXITCODE -ne 0) {
    throw "JPEXS failed while $Description (exit code $LASTEXITCODE)."
  }
}

$script:ResolvedJavaPath = Resolve-RequiredFile -Path $JavaPath -Description "Java executable"
$script:ResolvedJpexsJarPath = Resolve-RequiredFile -Path $JpexsJarPath -Description "JPEXS JAR"
$resolvedVanillaInterfacePath = (Resolve-Path -LiteralPath $VanillaInterfacePath).Path
$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
$decompileScript = Resolve-RequiredFile -Path (Join-Path $PSScriptRoot "decompileScaleform.ps1") -Description "Scaleform decompile helper"

if (!(Test-Path -LiteralPath $resolvedVanillaInterfacePath -PathType Container)) {
  throw "Vanilla interface directory does not exist: $VanillaInterfacePath"
}

New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $resolvedWorkDirectory | Out-Null

$buildWorkDirectory = Join-Path $resolvedWorkDirectory ([guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $buildWorkDirectory | Out-Null

try {
  foreach ($manifestEntry in $ManifestPath) {
    $resolvedManifestPath = Resolve-RequiredFile -Path $manifestEntry -Description "Scaleform build manifest"
    $manifestDirectory = Split-Path -Parent $resolvedManifestPath
    [xml]$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw
    $build = $manifest.scaleformBuild

    if (!$build -or !$build.name -or !$build.inputFile -or !$build.outputFile) {
      throw "Invalid Scaleform build manifest: $resolvedManifestPath"
    }

    $inputPath = Resolve-RequiredFile `
      -Path (Join-Path $resolvedVanillaInterfacePath ([string]$build.inputFile)) `
      -Description "Vanilla Scaleform input"
    $vanillaHashPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.vanillaHashFile)) `
      -Description "Vanilla hash file"
    $expectedHashPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.expectedHashFile)) `
      -Description "Expected output hash file"
    $patchPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.patch)) `
      -Description "Scaleform patch"

    $expectedVanillaHash = Read-Sha256File -Path $vanillaHashPath
    $actualVanillaHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
    if ($actualVanillaHash -ne $expectedVanillaHash) {
      throw "Vanilla hash mismatch for $inputPath. Expected $expectedVanillaHash; found $actualVanillaHash."
    }

    $movieWorkDirectory = Join-Path $buildWorkDirectory ([string]$build.name)
    New-Item -ItemType Directory -Path $movieWorkDirectory | Out-Null
    $decompiledXmlPath = Join-Path $movieWorkDirectory "vanilla.xml"
    $patchedXmlPath = Join-Path $movieWorkDirectory "patched.xml"
    $generatedGfxPath = Join-Path $movieWorkDirectory ([string]$build.outputFile)
    $reopenedXmlPath = Join-Path $movieWorkDirectory "reopened.xml"

    & $decompileScript `
      -JavaPath $script:ResolvedJavaPath `
      -JpexsJarPath $script:ResolvedJpexsJarPath `
      -InputPath $inputPath `
      -OutputXmlPath $decompiledXmlPath

    [xml]$scaleform = Get-Content -LiteralPath $decompiledXmlPath -Raw
    [xml]$patch = Get-Content -LiteralPath $patchPath -Raw
    $preconditions = $patch.scaleformPatch.preconditions
    $displayRect = $scaleform.SelectSingleNode('/swf/displayRect')

    if (!$displayRect) {
      throw "Scaleform display rectangle is missing from $inputPath."
    }

    if ($displayRect.Xmax -ne $preconditions.stageWidthTwips -or
        $displayRect.Ymax -ne $preconditions.stageHeightTwips -or
        $displayRect.Xmin -ne "0" -or $displayRect.Ymin -ne "0") {
      throw "Unexpected Scaleform stage geometry in $inputPath."
    }

    $characterId = [string]$preconditions.characterId
    $rootDepth = [string]$preconditions.rootDepth
    $existingCharacter = $scaleform.SelectNodes("//*[@characterID='$characterId' or @characterId='$characterId' or @textID='$characterId']")
    if ($existingCharacter.Count -ne 0) {
      throw "Character ID $characterId is already in use in $inputPath."
    }

    $existingRootDepth = $scaleform.SelectNodes("/swf/tags/item[@depth='$rootDepth']")
    if ($existingRootDepth.Count -ne 0) {
      throw "Root depth $rootDepth is already in use in $inputPath."
    }

    $rootShowFrames = $scaleform.SelectNodes('/swf/tags/item[@type="ShowFrameTag"]')
    if ($rootShowFrames.Count -ne 1) {
      throw "Expected exactly one root ShowFrameTag in $inputPath; found $($rootShowFrames.Count)."
    }

    $patchTags = $patch.SelectNodes('/scaleformPatch/tags/item')
    if ($patchTags.Count -eq 0) {
      throw "Patch contains no tags: $patchPath"
    }

    foreach ($patchTag in $patchTags) {
      $importedTag = $scaleform.ImportNode($patchTag, $true)
      [void]$rootShowFrames[0].ParentNode.InsertBefore($importedTag, $rootShowFrames[0])
    }

    $xmlSettings = [System.Xml.XmlWriterSettings]::new()
    $xmlSettings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $xmlSettings.Indent = $true
    $xmlWriter = [System.Xml.XmlWriter]::Create($patchedXmlPath, $xmlSettings)
    try {
      $scaleform.Save($xmlWriter)
    }
    finally {
      $xmlWriter.Dispose()
    }

    Invoke-Jpexs -Arguments @('-xml2swf', $patchedXmlPath, $generatedGfxPath) -Description "building $($build.name)"
    Invoke-Jpexs -Arguments @('-swf2xml', $generatedGfxPath, $reopenedXmlPath) -Description "reopening $($build.name)"

    $generatedBytes = [System.IO.File]::ReadAllBytes($generatedGfxPath)
    if ($generatedBytes.Length -lt 3 -or [System.Text.Encoding]::ASCII.GetString($generatedBytes, 0, 3) -ne 'GFX') {
      throw "Generated output does not have a GFX signature: $generatedGfxPath"
    }

    [xml]$reopened = Get-Content -LiteralPath $reopenedXmlPath -Raw
    if ($reopened.SelectNodes("/swf/tags/item[@characterID='$characterId']").Count -ne 1 -or
        $reopened.SelectNodes("/swf/tags/item[@characterId='$characterId' and @depth='$rootDepth']").Count -ne 1) {
      throw "Generated output does not contain the expected probe definition and placement."
    }

    $expectedOutputHash = Read-Sha256File -Path $expectedHashPath
    $actualOutputHash = (Get-FileHash -LiteralPath $generatedGfxPath -Algorithm SHA256).Hash
    if ($actualOutputHash -ne $expectedOutputHash) {
      throw "Generated hash mismatch for $($build.outputFile). Expected $expectedOutputHash; found $actualOutputHash."
    }

    $destinationPath = Join-Path $resolvedOutputDirectory ([string]$build.outputFile)
    Copy-Item -LiteralPath $generatedGfxPath -Destination $destinationPath -Force
    Write-Host -ForegroundColor Green "Built and validated $destinationPath ($actualOutputHash)"
  }
}
finally {
  if ($KeepWork) {
    Write-Host -ForegroundColor Yellow "Temporary build files retained at $buildWorkDirectory"
  }
  elseif (Test-Path -LiteralPath $buildWorkDirectory) {
    $resolvedBuildWorkDirectory = (Resolve-Path -LiteralPath $buildWorkDirectory).Path
    $resolvedWorkRoot = (Resolve-Path -LiteralPath $resolvedWorkDirectory).Path
    if (!$resolvedBuildWorkDirectory.StartsWith(
        $resolvedWorkRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to clean a build directory outside the configured work root: $resolvedBuildWorkDirectory"
    }

    Remove-Item -LiteralPath $resolvedBuildWorkDirectory -Recurse -Force
  }
}
