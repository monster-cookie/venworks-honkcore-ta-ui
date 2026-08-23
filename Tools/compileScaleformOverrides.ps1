[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [string[]]$OutputDirectory = @(
    (Join-Path $PSScriptRoot "..\Staging-VWKS\Interface"),
    (Join-Path $PSScriptRoot "..\Staging-CF\Interface"),
    (Join-Path $PSScriptRoot "..\Staging-FC\Interface"),
    (Join-Path $PSScriptRoot "..\Staging-TA\Interface")
  ),

  [string]$WorkDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work"),

  [string]$ReferenceCacheManifestPath = (Join-Path $PSScriptRoot "..\Scaleform\reference-cache.xml"),

  [string[]]$ManifestPath = @(
    (Join-Path $PSScriptRoot "..\Scaleform\hudmessagesmenu\build.xml"),
    (Join-Path $PSScriptRoot "..\Scaleform\hudmessagesmenu_lrg\build.xml"),
    (Join-Path $PSScriptRoot "..\Scaleform\monoclemenu\build.xml"),
    (Join-Path $PSScriptRoot "..\Scaleform\monoclemenu_lrg\build.xml")
  ),

  [switch]$KeepWork,

  [switch]$UpdateExpectedHashes
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

  [xml]$patch = Get-Content -LiteralPath $PatchPath -Raw
  if (!$patch.actionScriptPatch -or !$patch.actionScriptPatch.script) {
    throw "Invalid ActionScript patch: $PatchPath"
  }

  $source = Get-Content -LiteralPath $SourcePath -Raw
  $insertions = @($patch.SelectNodes('/actionScriptPatch/insertions/insertion'))
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

    if ($position -eq 'before') {
      $replacement = $content + $anchor
    }
    elseif ($position -eq 'after') {
      $replacement = $anchor + $content
    }
    else {
      throw "Unsupported ActionScript insertion position '$position' in $PatchPath."
    }

    $source = $source.Replace($anchor, $replacement)
  }

  [System.IO.File]::WriteAllText(
    $OutputPath,
    $source,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Get-RelativeChildPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [string]$ChildPath
  )

  return $ChildPath.Substring($RootPath.Length).TrimStart(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
}

function Get-MovieSignature {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 3) {
    throw "Scaleform movie is too short to contain a signature: $Path"
  }

  return [System.Text.Encoding]::ASCII.GetString($bytes,0,3)
}

$script:ResolvedJavaPath = Resolve-RequiredFile -Path $JavaPath -Description "Java executable"
$script:ResolvedJpexsJarPath = Resolve-RequiredFile -Path $JpexsJarPath -Description "JPEXS JAR"
$resolvedVanillaInterfacePath = Resolve-RequiredDirectory -Path $VanillaInterfacePath -Description "Vanilla interface directory"
$resolvedOutputDirectories = @($OutputDirectory | ForEach-Object {
  [System.IO.Path]::GetFullPath($_)
} | Select-Object -Unique)
if ($resolvedOutputDirectories.Count -eq 0) {
  throw "At least one output directory is required."
}
foreach ($outputPath in $resolvedOutputDirectories) {
  New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
}

$resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
New-Item -ItemType Directory -Force -Path $resolvedWorkDirectory | Out-Null
$referenceCacheHelperPath = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "sharedScaleformReferenceCache.ps1") `
  -Description "Scaleform reference-cache helper"
. $referenceCacheHelperPath
$resolvedReferenceCacheManifestPath = Resolve-RequiredFile `
  -Path $ReferenceCacheManifestPath `
  -Description "Scaleform reference-cache manifest"
$referenceCacheContext = New-ScaleformReferenceCacheContext `
  -JavaPath $script:ResolvedJavaPath `
  -JpexsJarPath $script:ResolvedJpexsJarPath `
  -VanillaInterfacePath $resolvedVanillaInterfacePath `
  -WorkDirectory $resolvedWorkDirectory `
  -ManifestPath $resolvedReferenceCacheManifestPath

$buildWorkDirectory = Join-Path $resolvedWorkDirectory ("overrides-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $buildWorkDirectory | Out-Null

try {
  foreach ($manifestEntry in $ManifestPath) {
    $resolvedManifestPath = Resolve-RequiredFile -Path $manifestEntry -Description "Scaleform override manifest"
    $manifestDirectory = Split-Path -Parent $resolvedManifestPath
    [xml]$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw
    $build = $manifest.scaleformBuild
    if (!$build -or !$build.name -or !$build.inputFile -or !$build.outputFile -or
        !$build.vanillaHashFile -or !$build.expectedHashFile -or !$build.actionScriptPatch) {
      throw "Invalid Scaleform override manifest: $resolvedManifestPath"
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
    $actionScriptPatchPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.actionScriptPatch)) `
      -Description "ActionScript patch"

    $expectedVanillaHash = Read-Sha256File -Path $vanillaHashPath
    $actualVanillaHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
    if ($actualVanillaHash -ne $expectedVanillaHash) {
      throw "Vanilla hash mismatch for $inputPath. Expected $expectedVanillaHash; found $actualVanillaHash."
    }

    [xml]$actionScriptPatch = Get-Content -LiteralPath $actionScriptPatchPath -Raw
    $scriptName = [string]$actionScriptPatch.actionScriptPatch.script
    $movieWorkDirectory = Join-Path $buildWorkDirectory ([string]$build.name)
    $importScriptsDirectory = Join-Path $movieWorkDirectory "import-scripts"
    $validationScriptsDirectory = Join-Path $movieWorkDirectory "validation-scripts"
    $generatedMoviePath = Join-Path $movieWorkDirectory ([string]$build.outputFile)
    New-Item -ItemType Directory -Path $movieWorkDirectory | Out-Null
    New-Item -ItemType Directory -Path $importScriptsDirectory | Out-Null

    $vanillaReference = Get-ScaleformReferenceMovie `
      -Context $referenceCacheContext `
      -InputFile ([string]$build.inputFile)
    $sourceScriptMatches = @(Get-ChildItem -LiteralPath $vanillaReference.ScriptsPath -Recurse -File -Filter "$scriptName.as")
    if ($sourceScriptMatches.Count -ne 1) {
      throw "Expected one vanilla $scriptName.as in $($build.inputFile); found $($sourceScriptMatches.Count)."
    }

    $patchedScriptPath = Join-Path $importScriptsDirectory "$scriptName.as"
    Apply-ActionScriptPatch `
      -SourcePath $sourceScriptMatches[0].FullName `
      -PatchPath $actionScriptPatchPath `
      -OutputPath $patchedScriptPath

    Invoke-Jpexs `
      -Arguments @('-onerror','abort','-importScript',$inputPath,$generatedMoviePath,$importScriptsDirectory) `
      -Description "importing the $($build.name) owner patch"
    Invoke-Jpexs `
      -Arguments @('-format','script:as','-export','script',$validationScriptsDirectory,$generatedMoviePath) `
      -Description "validating the $($build.name) owner patch"
    $validationScriptsRoot = Resolve-RequiredDirectory `
      -Path (Join-Path $validationScriptsDirectory 'scripts') `
      -Description "Reopened $($build.name) ActionScript directory"

    $sourceSignature = Get-MovieSignature -Path $inputPath
    $generatedSignature = Get-MovieSignature -Path $generatedMoviePath
    if ($generatedSignature -cne $sourceSignature) {
      throw "Generated $($build.outputFile) signature changed from $sourceSignature to $generatedSignature."
    }

    $validationScriptMatches = @(Get-ChildItem -LiteralPath $validationScriptsRoot -Recurse -File -Filter "$scriptName.as")
    if ($validationScriptMatches.Count -ne 1) {
      throw "Expected one reopened $scriptName.as in $($build.outputFile); found $($validationScriptMatches.Count)."
    }
    $reopenedSource = Get-Content -LiteralPath $validationScriptMatches[0].FullName -Raw
    foreach ($requiredPatternNode in @($actionScriptPatch.SelectNodes('/actionScriptPatch/validation/require'))) {
      $requiredPattern = [string]$requiredPatternNode.InnerText
      if ($reopenedSource -notmatch $requiredPattern) {
        throw "Generated $($build.outputFile) is missing a required $scriptName validation pattern."
      }
    }
    foreach ($rejectedPatternNode in @($actionScriptPatch.SelectNodes('/actionScriptPatch/validation/reject'))) {
      $rejectedPattern = [string]$rejectedPatternNode.InnerText
      if ($reopenedSource -match $rejectedPattern) {
        throw "Generated $($build.outputFile) contains a rejected $scriptName validation pattern."
      }
    }

    $originalScripts = @(Get-ChildItem -LiteralPath $vanillaReference.ScriptsPath -Recurse -File -Filter '*.as')
    $validationScripts = @(Get-ChildItem -LiteralPath $validationScriptsRoot -Recurse -File -Filter '*.as')
    if ($validationScripts.Count -ne $originalScripts.Count) {
      throw "Vanilla and reopened class inventories differ for $($build.outputFile): $($originalScripts.Count) before import and $($validationScripts.Count) after import."
    }
    foreach ($originalScript in $originalScripts) {
      $relativeScriptPath = Get-RelativeChildPath `
        -RootPath $vanillaReference.ScriptsPath `
        -ChildPath $originalScript.FullName
      if ($originalScript.Name -eq "$scriptName.as") {
        continue
      }
      $reopenedScriptPath = Join-Path $validationScriptsRoot $relativeScriptPath
      if (!(Test-Path -LiteralPath $reopenedScriptPath -PathType Leaf) -or
          (Get-FileHash -LiteralPath $originalScript.FullName -Algorithm SHA256).Hash -ne
          (Get-FileHash -LiteralPath $reopenedScriptPath -Algorithm SHA256).Hash) {
        throw "Unexpected change to vanilla ActionScript class in $($build.outputFile): $relativeScriptPath"
      }
    }

    $actualOutputHash = (Get-FileHash -LiteralPath $generatedMoviePath -Algorithm SHA256).Hash
    if ($UpdateExpectedHashes) {
      Write-Sha256File `
        -Path $expectedHashPath `
        -Hash $actualOutputHash `
        -FileName ([string]$build.outputFile)
      Write-Host -ForegroundColor Yellow "Updated expected hash for $($build.outputFile): $actualOutputHash"
    }
    else {
      $expectedOutputHash = Read-Sha256File -Path $expectedHashPath
      if ($actualOutputHash -ne $expectedOutputHash) {
        throw "Generated hash mismatch for $($build.outputFile). Expected $expectedOutputHash; found $actualOutputHash."
      }
    }

    foreach ($outputPath in $resolvedOutputDirectories) {
      Copy-Item `
        -LiteralPath $generatedMoviePath `
        -Destination (Join-Path $outputPath ([string]$build.outputFile)) `
        -Force
    }
    Write-Host -ForegroundColor Green "Built and staged $($build.outputFile)"
  }
}
finally {
  if ($KeepWork) {
    Write-Host -ForegroundColor Yellow "Temporary override build files retained at $buildWorkDirectory"
  }
  elseif (Test-Path -LiteralPath $buildWorkDirectory) {
    $resolvedBuildWorkDirectory = (Resolve-Path -LiteralPath $buildWorkDirectory).Path
    $resolvedWorkRoot = (Resolve-Path -LiteralPath $resolvedWorkDirectory).Path
    if (!$resolvedBuildWorkDirectory.StartsWith(
        $resolvedWorkRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to clean an override build directory outside the configured work root: $resolvedBuildWorkDirectory"
    }
    Remove-Item -LiteralPath $resolvedBuildWorkDirectory -Recurse -Force
  }
}
