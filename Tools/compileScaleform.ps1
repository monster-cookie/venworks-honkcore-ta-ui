[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work\compiled-interface"),

  [string]$WorkDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work"),

  [string]$ReferenceCacheManifestPath = (Join-Path $PSScriptRoot "..\Scaleform\reference-cache.xml"),

  [string[]]$ManifestPath = @(
    (Join-Path $PSScriptRoot "..\Scaleform\hudmenu\build.xml"),
    (Join-Path $PSScriptRoot "..\Scaleform\hudmenu_lrg\build.xml")
  ),

  [switch]$KeepWork,

  [switch]$UpdateExpectedHashes,

  [switch]$SkipOverrides,

  [switch]$AuxiliaryMarkerProbe
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "sharedScaleformMovies.ps1")
. (Join-Path $PSScriptRoot "sharedScaleformProfiles.ps1")

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

function Resolve-RequiredDirectory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if (!(Test-Path -LiteralPath $Path -PathType Container)) {
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

function Write-Sha256File {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Hash,

    [Parameter(Mandatory = $true)]
    [string]$FileName
  )

  [System.IO.File]::WriteAllText(
    $Path,
    "$($Hash.ToUpperInvariant())  $FileName`r`n",
    [System.Text.UTF8Encoding]::new($false)
  )
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

function Apply-ActionScriptPatch {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$PatchPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
  )

  [xml]$actionScriptPatch = Get-Content -LiteralPath $PatchPath -Raw
  $patchRoot = $actionScriptPatch.actionScriptPatch
  if (!$patchRoot -or !$patchRoot.script) {
    throw "Invalid ActionScript patch: $PatchPath"
  }

  $source = Get-Content -LiteralPath $SourcePath -Raw
  $insertions = @($actionScriptPatch.SelectNodes('/actionScriptPatch/insertions/insertion'))
  if ($insertions.Count -eq 0) {
    throw "ActionScript patch contains no insertions: $PatchPath"
  }
  foreach ($insertion in $insertions) {
    $anchor = [string]$insertion.anchor.InnerText
    $content = [string]$insertion.content.InnerText
    $position = [string]$insertion.position
    $anchorMatches = [regex]::Matches($source, [regex]::Escape($anchor)).Count
    if ($anchorMatches -ne 1) {
      throw "Expected one '$anchor' anchor in $SourcePath; found $anchorMatches."
    }
    if ($position -ceq 'before') {
      $source = $source.Replace($anchor, $content + $anchor)
    }
    elseif ($position -ceq 'after') {
      $source = $source.Replace($anchor, $anchor + $content)
    }
    else {
      throw "Unsupported ActionScript insertion position '$position' in $PatchPath."
    }
  }

  [System.IO.File]::WriteAllText(
    $OutputPath,
    $source,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Build-HudHostMovie {
  param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$WorkPath,

    [Parameter(Mandatory = $true)]
    [string]$PatchPath,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedHashPath,

    [Parameter(Mandatory = $true)]
    [string]$BuildName,

    [switch]$SkipExpectedHash
  )

  $exportedScriptsDirectory = Join-Path $WorkPath "exported-scripts"
  $importScriptsDirectory = Join-Path $WorkPath "import-scripts"
  $validationScriptsDirectory = Join-Path $WorkPath "validation-scripts"
  $reopenedXmlPath = Join-Path $WorkPath "reopened.xml"
  New-Item -ItemType Directory -Force -Path $importScriptsDirectory | Out-Null

  Invoke-Jpexs `
    -Arguments @('-format', 'script:as', '-export', 'script', $exportedScriptsDirectory, $InputPath) `
    -Description "exporting $BuildName ActionScript"

  $patchDefinition = Get-ScaleformActionScriptPatchDefinition -PatchPath $PatchPath
  $scriptName = [string]$patchDefinition.Script
  $exportedScriptMatches = @(Get-ChildItem -LiteralPath $exportedScriptsDirectory -Recurse -File -Filter "$scriptName.as")
  if ($exportedScriptMatches.Count -ne 1) {
    throw "Expected one exported $scriptName.as; found $($exportedScriptMatches.Count)."
  }
  Apply-ActionScriptPatch `
    -SourcePath $exportedScriptMatches[0].FullName `
    -PatchPath $PatchPath `
    -OutputPath (Join-Path $importScriptsDirectory "$scriptName.as")

  Invoke-Jpexs `
    -Arguments @('-onerror', 'abort', '-importScript', $InputPath, $OutputPath, $importScriptsDirectory) `
    -Description "importing the $BuildName HUD host patch"
  Invoke-Jpexs `
    -Arguments @('-swf2xml', $OutputPath, $reopenedXmlPath) `
    -Description "reopening $BuildName"
  Invoke-Jpexs `
    -Arguments @('-format', 'script:as', '-export', 'script', $validationScriptsDirectory, $OutputPath) `
    -Description "validating $BuildName ActionScript"

  Assert-ScaleformMovieEncoding -Path $OutputPath -Context "Generated $([System.IO.Path]::GetFileName($OutputPath))"
  if ((Get-ScaleformMovieSignature -Path $OutputPath) -cne (Get-ScaleformMovieSignature -Path $InputPath)) {
    throw "Generated $BuildName changed its Bethesda movie encoding."
  }

  [xml]$reopened = Get-Content -LiteralPath $reopenedXmlPath -Raw
  $abcTags = @($reopened.SelectNodes('/swf/tags/item[@type="DoABC2Tag" or @type="DoABCTag"]'))
  if ($abcTags.Count -ne 1) {
    throw "Generated $BuildName must contain exactly one Bethesda ABC; found $($abcTags.Count)."
  }
  if (@($reopened.SelectNodes('/swf/tags/item[@type="DoABC2Tag" and starts-with(@name,"venworks.cui.components.seed.")]')).Count -ne 0) {
    throw "Generated $BuildName retains the obsolete Venworks seed ABC."
  }

  $validationScriptMatches = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter "$scriptName.as")
  if ($validationScriptMatches.Count -ne 1) {
    throw "Expected one reopened $scriptName.as; found $($validationScriptMatches.Count)."
  }
  $reopenedHudMenuSource = Get-Content -LiteralPath $validationScriptMatches[0].FullName -Raw
  foreach ($requiredToken in @($patchDefinition.RequiredSourceTokens)) {
    if (!$reopenedHudMenuSource.Contains($requiredToken)) {
      throw "Generated $BuildName is missing patch contract token '$requiredToken'."
    }
  }
  foreach ($forbiddenToken in @($patchDefinition.ForbiddenSourceTokens)) {
    if ($reopenedHudMenuSource.Contains($forbiddenToken)) {
      throw "Generated $BuildName contains forbidden patch contract token '$forbiddenToken'."
    }
  }
  foreach ($forbiddenPattern in @($patchDefinition.ForbiddenSourcePatterns)) {
    if ($reopenedHudMenuSource -match $forbiddenPattern) {
      throw "Generated $BuildName matches forbidden patch contract pattern '$forbiddenPattern'."
    }
  }

  $originalScripts = @(Get-ChildItem -LiteralPath $exportedScriptsDirectory -Recurse -File -Filter '*.as')
  $validationScripts = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter '*.as')
  if ($validationScripts.Count -ne $originalScripts.Count) {
    throw "Bootstrap import changed the Bethesda class inventory for $BuildName."
  }
  foreach ($originalScript in $originalScripts) {
    if ($originalScript.Name -ceq "$scriptName.as") {
      continue
    }
    $relativePath = $originalScript.FullName.Substring($exportedScriptsDirectory.Length).TrimStart(
      [System.IO.Path]::DirectorySeparatorChar,
      [System.IO.Path]::AltDirectorySeparatorChar
    )
    $validationPath = Join-Path $validationScriptsDirectory $relativePath
    if (!(Test-Path -LiteralPath $validationPath -PathType Leaf) -or
        (Get-FileHash -LiteralPath $originalScript.FullName -Algorithm SHA256).Hash -cne
        (Get-FileHash -LiteralPath $validationPath -Algorithm SHA256).Hash) {
      throw "HUD host patch unexpectedly changed Bethesda class '$relativePath'."
    }
  }

  $actualOutputHash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
  if (!$SkipExpectedHash) {
    if ($UpdateExpectedHashes) {
      Write-Sha256File `
        -Path $ExpectedHashPath `
        -Hash $actualOutputHash `
        -FileName ([System.IO.Path]::GetFileName($OutputPath))
    }
    $expectedOutputHash = Read-Sha256File -Path $ExpectedHashPath
    if ($actualOutputHash -cne $expectedOutputHash) {
      throw "Generated hash mismatch for $BuildName. Expected $expectedOutputHash; found $actualOutputHash."
    }
  }

  return $actualOutputHash
}

$script:ResolvedJavaPath = Resolve-RequiredFile -Path $JavaPath -Description "Java executable"
$script:ResolvedJpexsJarPath = Resolve-RequiredFile -Path $JpexsJarPath -Description "JPEXS JAR"
$resolvedVanillaInterfacePath = Resolve-RequiredDirectory `
  -Path $VanillaInterfacePath `
  -Description "Vanilla interface directory"
$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory, $resolvedWorkDirectory | Out-Null
$buildWorkDirectory = Join-Path $resolvedWorkDirectory ([guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $buildWorkDirectory | Out-Null

try {
  $usedBuildNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  $usedOutputNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  foreach ($manifestEntry in $ManifestPath) {
    $resolvedManifestPath = Resolve-RequiredFile -Path $manifestEntry -Description "Scaleform build manifest"
    $manifestDirectory = Split-Path -Parent $resolvedManifestPath
    [xml]$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw
    $build = $manifest.scaleformBuild
    if (!$build -or !$build.name -or !$build.inputFile -or !$build.outputFile -or
        !$build.vanillaHashFile -or !$build.expectedHashFile -or !$build.actionScriptPatch) {
      throw "Invalid Scaleform bootstrap build manifest: $resolvedManifestPath"
    }
    $buildMode = [string]$build.GetAttribute('mode')
    if ($buildMode -notin @('auxiliary-bootstrap', 'bgs-hudmenu-only')) {
      throw "Scaleform HUD manifests must select a supported host mode: $resolvedManifestPath"
    }
    if ($build.HasAttribute('abcSeedPatch') -or
        $build.HasAttribute('actionScriptSource') -or
        $build.HasAttribute('actionScriptProfile')) {
      throw "Scaleform HUD host manifest retains an embedded-CUI attribute: $resolvedManifestPath"
    }
    if (!$usedBuildNames.Add([string]$build.name) -or
        !$usedOutputNames.Add([string]$build.outputFile)) {
      throw "Scaleform HUD bootstrap manifests contain a duplicate build or output name."
    }

    $inputPath = Resolve-RequiredFile `
      -Path (Join-Path $resolvedVanillaInterfacePath ([string]$build.inputFile)) `
      -Description "Vanilla Scaleform input"
    Assert-ScaleformMovieEncoding -Path $inputPath -Context "Vanilla $($build.inputFile)"
    $vanillaHashPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.vanillaHashFile)) `
      -Description "Vanilla hash file"
    $expectedVanillaHash = Read-Sha256File -Path $vanillaHashPath
    $actualVanillaHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
    if ($actualVanillaHash -cne $expectedVanillaHash) {
      throw "Vanilla hash mismatch for $inputPath. Expected $expectedVanillaHash; found $actualVanillaHash."
    }
    $expectedHashPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.expectedHashFile)) `
      -Description "Expected output hash file"
    $actionScriptPatchPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.actionScriptPatch)) `
      -Description "ActionScript bootstrap patch"

    $movieWorkDirectory = Join-Path $buildWorkDirectory ([string]$build.name)
    New-Item -ItemType Directory -Path $movieWorkDirectory | Out-Null
    $generatedMoviePath = Join-Path $movieWorkDirectory ([string]$build.outputFile)
    Build-HudHostMovie `
      -InputPath $inputPath `
      -OutputPath $generatedMoviePath `
      -WorkPath $movieWorkDirectory `
      -PatchPath $actionScriptPatchPath `
      -ExpectedHashPath $expectedHashPath `
      -BuildName ([string]$build.name) `
      -SkipExpectedHash:$AuxiliaryMarkerProbe | Out-Host

    $destinationPath = Join-Path $resolvedOutputDirectory ([string]$build.outputFile)
    Copy-Item -LiteralPath $generatedMoviePath -Destination $destinationPath -Force
    $actualOutputHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
    Write-Host -ForegroundColor Green "Built and validated $destinationPath ($actualOutputHash)"
  }
}
finally {
  if ($KeepWork) {
    Write-Host -ForegroundColor Yellow "Temporary build files retained at $buildWorkDirectory"
  }
  elseif (Test-Path -LiteralPath $buildWorkDirectory -PathType Container) {
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

if (!$SkipOverrides) {
  $overrideCompilerPath = Resolve-RequiredFile `
    -Path (Join-Path $PSScriptRoot 'compileScaleformOverrides.ps1') `
    -Description 'Bethesda owner-movie override compiler'
  $overrideCompilerArguments = @{
    JavaPath = $script:ResolvedJavaPath
    JpexsJarPath = $script:ResolvedJpexsJarPath
    VanillaInterfacePath = $resolvedVanillaInterfacePath
    OutputDirectory = @($resolvedOutputDirectory)
    WorkDirectory = $resolvedWorkDirectory
    ReferenceCacheManifestPath = $ReferenceCacheManifestPath
  }
  if ($KeepWork) {
    $overrideCompilerArguments.KeepWork = $true
  }
  if ($UpdateExpectedHashes) {
    $overrideCompilerArguments.UpdateExpectedHashes = $true
  }
  & $overrideCompilerPath @overrideCompilerArguments
}
