<#
.SYNOPSIS
Builds the isolated PS5 debug HUD movies and stages their unique plugin payload.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [string]$WorkDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work\ps5-debug"),

  [switch]$KeepWork,

  [switch]$UpdateExpectedHashes
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . (Join-Path $PSScriptRoot "sharedConfig.ps1")
}
. (Join-Path $PSScriptRoot "sharedScaleformMovies.ps1")

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

function Assert-NotGitLfsPointer {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $prefixLength = [Math]::Min(128, $bytes.Length)
  $prefix = [System.Text.Encoding]::UTF8.GetString($bytes, 0, $prefixLength)
  if ($prefix.StartsWith("version https://git-lfs.github.com/spec/v1", [System.StringComparison]::Ordinal)) {
    throw "$Description remains a Git LFS pointer: $Path"
  }
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

  [xml]$patchDocument = Get-Content -LiteralPath $PatchPath -Raw
  $patchRoot = $patchDocument.actionScriptPatch
  if (!$patchRoot -or [string]$patchRoot.script -cne "HUDMenu") {
    throw "PS5 debug patch must target the Bethesda HUDMenu class: $PatchPath"
  }

  $source = Get-Content -LiteralPath $SourcePath -Raw
  $insertions = @($patchDocument.SelectNodes('/actionScriptPatch/insertions/insertion'))
  if ($insertions.Count -eq 0) {
    throw "PS5 debug patch contains no insertions: $PatchPath"
  }
  foreach ($insertion in $insertions) {
    $anchor = [string]$insertion.anchor.InnerText
    $content = [string]$insertion.content.InnerText
    $anchorCount = [regex]::Matches($source, [regex]::Escape($anchor)).Count
    if ($anchorCount -ne 1) {
      throw "Expected one '$anchor' anchor in $SourcePath; found $anchorCount."
    }
    if ([string]$insertion.position -ceq "before") {
      $source = $source.Replace($anchor, $content + $anchor)
    }
    elseif ([string]$insertion.position -ceq "after") {
      $source = $source.Replace($anchor, $anchor + $content)
    }
    else {
      throw "Unsupported ActionScript insertion position '$($insertion.position)' in $PatchPath."
    }
  }

  [System.IO.File]::WriteAllText(
    $OutputPath,
    $source,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Build-Ps5DebugMovie {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$BuildRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$VanillaDirectory
  )

  [xml]$manifest = Get-Content -LiteralPath $ManifestPath -Raw
  $build = $manifest.scaleformBuild
  if (!$build -or
      [string]$build.GetAttribute("mode") -cne "ps5-debug-hudmenu" -or
      !$build.name -or
      !$build.inputFile -or
      !$build.outputFile -or
      !$build.vanillaHashFile -or
      !$build.expectedHashFile -or
      !$build.actionScriptPatch) {
    throw "Invalid PS5 debug movie manifest: $ManifestPath"
  }

  $manifestDirectory = Split-Path -Parent $ManifestPath
  $inputPath = Resolve-RequiredFile `
    -Path (Join-Path $VanillaDirectory ([string]$build.inputFile)) `
    -Description "Vanilla PS5 debug movie input"
  $vanillaHashPath = Resolve-RequiredFile `
    -Path (Join-Path $manifestDirectory ([string]$build.vanillaHashFile)) `
    -Description "Vanilla PS5 debug movie hash"
  $actualVanillaHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToUpperInvariant()
  $expectedVanillaHash = Read-Sha256File -Path $vanillaHashPath
  if ($actualVanillaHash -cne $expectedVanillaHash) {
    throw "Vanilla hash mismatch for $inputPath. Expected $expectedVanillaHash; found $actualVanillaHash."
  }

  $patchPath = Resolve-RequiredFile `
    -Path (Join-Path $manifestDirectory ([string]$build.actionScriptPatch)) `
    -Description "PS5 debug ActionScript patch"
  $expectedHashPath = Resolve-RequiredFile `
    -Path (Join-Path $manifestDirectory ([string]$build.expectedHashFile)) `
    -Description "PS5 debug expected movie hash"
  $movieWorkPath = Join-Path $BuildRoot ([string]$build.name)
  $exportedScriptsPath = Join-Path $movieWorkPath "exported-scripts"
  $importScriptsPath = Join-Path $movieWorkPath "import-scripts"
  $validationScriptsPath = Join-Path $movieWorkPath "validation-scripts"
  $reopenedXmlPath = Join-Path $movieWorkPath "reopened.xml"
  New-Item -ItemType Directory -Force -Path $importScriptsPath | Out-Null

  Invoke-Jpexs `
    -Arguments @('-format', 'script:as', '-export', 'script', $exportedScriptsPath, $inputPath) `
    -Description "exporting $($build.name) ActionScript"
  $hudMenuMatches = @(Get-ChildItem -LiteralPath $exportedScriptsPath -Recurse -File -Filter 'HUDMenu.as')
  if ($hudMenuMatches.Count -ne 1) {
    throw "Expected one exported HUDMenu.as for $($build.name); found $($hudMenuMatches.Count)."
  }
  Apply-ActionScriptPatch `
    -SourcePath $hudMenuMatches[0].FullName `
    -PatchPath $patchPath `
    -OutputPath (Join-Path $importScriptsPath 'HUDMenu.as')

  $generatedPath = Join-Path $movieWorkPath ([string]$build.outputFile)
  Invoke-Jpexs `
    -Arguments @('-onerror', 'abort', '-importScript', $inputPath, $generatedPath, $importScriptsPath) `
    -Description "importing the $($build.name) diagnostic"
  Invoke-Jpexs `
    -Arguments @('-swf2xml', $generatedPath, $reopenedXmlPath) `
    -Description "reopening $($build.name)"
  Invoke-Jpexs `
    -Arguments @('-format', 'script:as', '-export', 'script', $validationScriptsPath, $generatedPath) `
    -Description "validating $($build.name) ActionScript"

  $expectedSignature = if ([System.IO.Path]::GetExtension([string]$build.outputFile) -ceq '.gfx') { 'GFX' } else { 'CWS' }
  $metadata = Get-ScaleformMovieMetadata `
    -Path $generatedPath `
    -Context "Generated $($build.outputFile)" `
    -ExpectedSignature $expectedSignature
  if ($metadata.StageWidth -ne 1920 -or
      $metadata.StageHeight -ne 1080 -or
      $metadata.FrameRate -ne 30 -or
      $metadata.FrameCount -ne 1) {
    throw "Generated $($build.outputFile) must remain 1920x1080 at 30 fps with one frame."
  }

  [xml]$reopened = Get-Content -LiteralPath $reopenedXmlPath -Raw
  $abcTags = @($reopened.SelectNodes('/swf/tags/item[@type="DoABC2Tag" or @type="DoABCTag"]'))
  if ($abcTags.Count -ne 1) {
    throw "Generated $($build.outputFile) must contain exactly one Bethesda ABC; found $($abcTags.Count)."
  }

  $reopenedHudMenuMatches = @(Get-ChildItem -LiteralPath $validationScriptsPath -Recurse -File -Filter 'HUDMenu.as')
  if ($reopenedHudMenuMatches.Count -ne 1) {
    throw "Expected one reopened HUDMenu.as for $($build.name); found $($reopenedHudMenuMatches.Count)."
  }
  $hudMenuSource = Get-Content -LiteralPath $reopenedHudMenuMatches[0].FullName -Raw
  foreach ($requiredToken in @(
    'PS5DBG-01 CONSTRUCTED',
    'PS5DBG-02 ADDED TO STAGE',
    'PS5DBG-OK HUD LOADED',
    'PS5DBG-ERR UNCAUGHT',
    'new TextFormat("$MAIN_Font_Bold",20',
    'loaderInfo.uncaughtErrorEvents.addEventListener',
    'param1.preventDefault()',
    'param1.stopImmediatePropagation()'
  )) {
    if (!$hudMenuSource.Contains($requiredToken)) {
      throw "Generated $($build.outputFile) is missing diagnostic token '$requiredToken'."
    }
  }
  foreach ($forbiddenToken in @(
    'VenworksCUI',
    'venworks.cui',
    'venworkscui.swf',
    'CUILayout',
    'CUISvg',
    'CUIPalette',
    'CUIPlayerHudDataContext'
  )) {
    if ($hudMenuSource.Contains($forbiddenToken)) {
      throw "Generated $($build.outputFile) contains forbidden CUI token '$forbiddenToken'."
    }
  }

  $originalScripts = @(Get-ChildItem -LiteralPath $exportedScriptsPath -Recurse -File -Filter '*.as')
  $reopenedScripts = @(Get-ChildItem -LiteralPath $validationScriptsPath -Recurse -File -Filter '*.as')
  if ($reopenedScripts.Count -ne $originalScripts.Count) {
    throw "PS5 debug import changed the Bethesda class inventory for $($build.name)."
  }
  foreach ($originalScript in $originalScripts) {
    if ($originalScript.Name -ceq 'HUDMenu.as') {
      continue
    }
    $relativePath = $originalScript.FullName.Substring($exportedScriptsPath.Length).TrimStart(
      [System.IO.Path]::DirectorySeparatorChar,
      [System.IO.Path]::AltDirectorySeparatorChar
    )
    $reopenedPath = Join-Path $validationScriptsPath $relativePath
    if (!(Test-Path -LiteralPath $reopenedPath -PathType Leaf) -or
        (Get-FileHash -LiteralPath $originalScript.FullName -Algorithm SHA256).Hash -cne
        (Get-FileHash -LiteralPath $reopenedPath -Algorithm SHA256).Hash) {
      throw "PS5 debug import unexpectedly changed Bethesda class '$relativePath'."
    }
  }

  $actualHash = (Get-FileHash -LiteralPath $generatedPath -Algorithm SHA256).Hash.ToUpperInvariant()
  if ($UpdateExpectedHashes) {
    Write-Sha256File -Path $expectedHashPath -Hash $actualHash -FileName ([string]$build.outputFile)
  }
  $expectedHash = Read-Sha256File -Path $expectedHashPath
  if ($actualHash -cne $expectedHash) {
    throw "Generated hash mismatch for $($build.name). Expected $expectedHash; found $actualHash."
  }

  $destinationPath = Join-Path $OutputDirectory ([string]$build.outputFile)
  Copy-Item -LiteralPath $generatedPath -Destination $destinationPath -Force
  Write-Host -ForegroundColor Green "Built and validated $destinationPath ($actualHash)"
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$script:ResolvedJavaPath = Resolve-RequiredFile -Path $JavaPath -Description "Java executable"
$script:ResolvedJpexsJarPath = Resolve-RequiredFile -Path $JpexsJarPath -Description "JPEXS JAR"
$resolvedVanillaPath = Resolve-RequiredDirectory -Path $VanillaInterfacePath -Description "Vanilla Interface directory"
$variant = @(Get-DiagnosticVariants -VariantKeys "PS5DBG")[0]
$profilePath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Scaleform\variants\PS5DBG\build.psd1") `
  -Description "PS5 Debug build profile"
$profile = Import-PowerShellDataFile -LiteralPath $profilePath
$manifestPaths = @($profile.MovieManifestPaths)
if ($manifestPaths.Count -ne 4 -or @($manifestPaths | Select-Object -Unique).Count -ne 4) {
  throw "PS5 Debug must declare exactly four unique HUD movie manifests."
}

$stagingPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot ([string]$variant.StagingFolderPath)))
if (!(Test-Path -LiteralPath $stagingPath -PathType Container)) {
  throw "PS5 Debug staging folder does not exist. Run setupPs5DebugVariant.ps1 first: $stagingPath"
}
$stagingItem = Get-Item -LiteralPath $stagingPath
if ($stagingItem.LinkType -ne "Junction") {
  throw "PS5 Debug staging folder must be a Junction: $stagingPath"
}
$stagingTargets = @($stagingItem.Target)
if ($stagingTargets.Count -ne 1) {
  throw "PS5 Debug staging Junction must have exactly one target."
}
$resolvedStagingPath = (Resolve-Path -LiteralPath $stagingPath).Path
$resolvedJunctionTarget = Resolve-RequiredDirectory `
  -Path ([string]$stagingTargets[0]) `
  -Description "PS5 Debug staging Junction target"
$configuredModulePath = Resolve-RequiredDirectory `
  -Path ([string]$variant.PluginModulePath) `
  -Description "PS5 Debug physical module folder"
if (![string]::Equals($resolvedJunctionTarget, $configuredModulePath, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "PS5 Debug staging Junction does not target the configured physical module folder."
}

foreach ($existingItem in @(Get-ChildItem -LiteralPath $resolvedStagingPath -Force)) {
  $resolvedItemPath = [System.IO.Path]::GetFullPath($existingItem.FullName)
  if (!$resolvedItemPath.StartsWith(
      $resolvedStagingPath + [System.IO.Path]::DirectorySeparatorChar,
      [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean an item outside the PS5 Debug staging folder: $resolvedItemPath"
  }
  Remove-Item -LiteralPath $resolvedItemPath -Recurse -Force
}

$interfacePath = Join-Path $resolvedStagingPath "Interface"
New-Item -ItemType Directory -Force -Path $interfacePath | Out-Null
$resolvedWorkRoot = [System.IO.Path]::GetFullPath($WorkDirectory)
New-Item -ItemType Directory -Force -Path $resolvedWorkRoot | Out-Null
$buildRoot = Join-Path $resolvedWorkRoot ([guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $buildRoot | Out-Null

try {
  foreach ($manifestRelativePath in $manifestPaths) {
    $manifestPath = Resolve-RequiredFile `
      -Path (Join-Path $repositoryRoot ([string]$manifestRelativePath)) `
      -Description "PS5 Debug movie manifest"
    Build-Ps5DebugMovie `
      -ManifestPath $manifestPath `
      -BuildRoot $buildRoot `
      -OutputDirectory $interfacePath `
      -VanillaDirectory $resolvedVanillaPath
  }

  $pluginSourcePath = Resolve-RequiredFile `
    -Path (Join-Path $repositoryRoot ([string]$profile.PluginSourcePath)) `
    -Description "Canonical plugin stub"
  Assert-NotGitLfsPointer -Path $pluginSourcePath -Description "Canonical plugin stub"
  $pluginOutputPath = Join-Path $resolvedStagingPath "$($variant.PackageBaseName).esm"
  Copy-Item -LiteralPath $pluginSourcePath -Destination $pluginOutputPath -Force
  if ((Get-FileHash -LiteralPath $pluginSourcePath -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $pluginOutputPath -Algorithm SHA256).Hash) {
    throw "PS5 Debug plugin is not byte-identical to the canonical stub."
  }
}
finally {
  if ($KeepWork) {
    Write-Host -ForegroundColor Yellow "Temporary PS5 Debug build files retained at $buildRoot"
  }
  elseif (Test-Path -LiteralPath $buildRoot -PathType Container) {
    $resolvedBuildRoot = (Resolve-Path -LiteralPath $buildRoot).Path
    if (!$resolvedBuildRoot.StartsWith(
        $resolvedWorkRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to clean a PS5 Debug build directory outside the configured work root: $resolvedBuildRoot"
    }
    Remove-Item -LiteralPath $resolvedBuildRoot -Recurse -Force
  }
}

Write-Host -ForegroundColor Cyan "PS5 Debug HUD movies and unique plugin are staged."
