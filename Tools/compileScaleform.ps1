[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\Staging-CUI\Interface"),

  [string]$TextureOutputDirectory = (Join-Path $PSScriptRoot "..\Staging-CUI\Textures"),

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

function Get-XmlSchemaErrors {
  param(
    [Parameter(Mandatory = $true)]
    [string]$XmlPath,

    [Parameter(Mandatory = $true)]
    [string]$SchemaPath
  )

  [xml]$document = Get-Content -LiteralPath $XmlPath -Raw
  $schemas = [System.Xml.Schema.XmlSchemaSet]::new()
  [void]$schemas.Add($null, $SchemaPath)
  $document.Schemas = $schemas
  $errors = [System.Collections.Generic.List[string]]::new()
  $handler = [System.Xml.Schema.ValidationEventHandler]{
    param($sender, $eventArgs)
    $errors.Add($eventArgs.Message)
  }
  $document.Validate($handler)
  return @($errors)
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
  $insertions = $actionScriptPatch.SelectNodes('/actionScriptPatch/insertions/insertion')
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

$script:ResolvedJavaPath = Resolve-RequiredFile -Path $JavaPath -Description "Java executable"
$script:ResolvedJpexsJarPath = Resolve-RequiredFile -Path $JpexsJarPath -Description "JPEXS JAR"
$resolvedVanillaInterfacePath = (Resolve-Path -LiteralPath $VanillaInterfacePath).Path
$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$resolvedTextureOutputDirectory = [System.IO.Path]::GetFullPath($TextureOutputDirectory)
$resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
$decompileScript = Resolve-RequiredFile -Path (Join-Path $PSScriptRoot "decompileScaleform.ps1") -Description "Scaleform decompile helper"
$galleryLayoutSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\fixtures\asset-primitives-gallery.xml") `
  -Description "Goal 4E asset gallery"
$galleryDdsSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\assets\venworks-logo.dds") `
  -Description "Owned Venworks DDS gallery asset"
$gallerySvgSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\assets\gallery-vector.svg") `
  -Description "Owned SVG gallery asset"
$venworksLogoSvgSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\assets\venworks-logo.svg") `
  -Description "Owned Venworks logo SVG asset"
$invalidSvgSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\assets\gallery-invalid.svg") `
  -Description "Goal 4E invalid SVG fixture"
$layoutSchemaPath = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Schemas\VenworksCUI\layout-v1.xsd") `
  -Description "Venworks CUI layout schema"
$fixtureDirectory = Resolve-RequiredDirectory `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\fixtures") `
  -Description "Scaleform fixture directory"

foreach ($positiveFixtureName in @(
  'component-gallery.xml',
  'layout-anchor-gallery.xml',
  'composition-gallery.xml',
  'condition-gallery.xml',
  'vanilla-visibility-gallery.xml',
  'meter-renderer-gallery.xml',
  'asset-primitives-gallery.xml'
)) {
  $positiveFixturePath = Resolve-RequiredFile `
    -Path (Join-Path $fixtureDirectory $positiveFixtureName) `
    -Description "Positive layout fixture"
  $schemaErrors = @(Get-XmlSchemaErrors -XmlPath $positiveFixturePath -SchemaPath $layoutSchemaPath)
  if ($schemaErrors.Count -ne 0) {
    throw "Positive fixture $positiveFixtureName failed schema validation: $($schemaErrors -join '; ')"
  }
}

$invalidAssetPathFixture = Resolve-RequiredFile `
  -Path (Join-Path $fixtureDirectory 'layout-invalid-asset-path.xml') `
  -Description "Invalid asset-path fixture"
$invalidAssetPathErrors = @(Get-XmlSchemaErrors -XmlPath $invalidAssetPathFixture -SchemaPath $layoutSchemaPath)
if ($invalidAssetPathErrors.Count -eq 0) {
  throw "Invalid asset-path fixture unexpectedly passed schema validation."
}

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
    $abcSeedPatchPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.abcSeedPatch)) `
      -Description "Scaleform ABC seed patch"
    $actionScriptSourcePath = Resolve-RequiredDirectory `
      -Path (Join-Path $manifestDirectory ([string]$build.actionScriptSource)) `
      -Description "Authored ActionScript source directory"
    $actionScriptPatchPath = Resolve-RequiredFile `
      -Path (Join-Path $manifestDirectory ([string]$build.actionScriptPatch)) `
      -Description "ActionScript patch"

    $expectedVanillaHash = Read-Sha256File -Path $vanillaHashPath
    $actualVanillaHash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
    if ($actualVanillaHash -ne $expectedVanillaHash) {
      throw "Vanilla hash mismatch for $inputPath. Expected $expectedVanillaHash; found $actualVanillaHash."
    }

    $movieWorkDirectory = Join-Path $buildWorkDirectory ([string]$build.name)
    New-Item -ItemType Directory -Path $movieWorkDirectory | Out-Null
    $decompiledXmlPath = Join-Path $movieWorkDirectory "vanilla.xml"
    $patchedXmlPath = Join-Path $movieWorkDirectory "patched.xml"
    $timelineGfxPath = Join-Path $movieWorkDirectory "timeline.gfx"
    $generatedGfxPath = Join-Path $movieWorkDirectory ([string]$build.outputFile)
    $reopenedXmlPath = Join-Path $movieWorkDirectory "reopened.xml"
    $exportedScriptsDirectory = Join-Path $movieWorkDirectory "exported-scripts"
    $importScriptsDirectory = Join-Path $movieWorkDirectory "import-scripts"
    $validationScriptsDirectory = Join-Path $movieWorkDirectory "validation-scripts"

    & $decompileScript `
      -JavaPath $script:ResolvedJavaPath `
      -JpexsJarPath $script:ResolvedJpexsJarPath `
      -InputPath $inputPath `
      -OutputXmlPath $decompiledXmlPath

    [xml]$scaleform = Get-Content -LiteralPath $decompiledXmlPath -Raw
    [xml]$abcSeedPatch = Get-Content -LiteralPath $abcSeedPatchPath -Raw
    $displayRect = $scaleform.SelectSingleNode('/swf/displayRect')

    if (!$displayRect) {
      throw "Scaleform display rectangle is missing from $inputPath."
    }

    if ($displayRect.Xmax -ne "38400" -or
        $displayRect.Ymax -ne "21600" -or
        $displayRect.Xmin -ne "0" -or $displayRect.Ymin -ne "0") {
      throw "Unexpected Scaleform stage geometry in $inputPath."
    }

    $rootShowFrames = $scaleform.SelectNodes('/swf/tags/item[@type="ShowFrameTag"]')
    if ($rootShowFrames.Count -ne 1) {
      throw "Expected exactly one root ShowFrameTag in $inputPath; found $($rootShowFrames.Count)."
    }

    $promptSymbolIds = @()
    foreach ($symbolClassTag in $scaleform.SelectNodes('/swf/tags/item[@type="SymbolClassTag"]')) {
      $symbolIds = @($symbolClassTag.tags.item)
      $symbolNames = @($symbolClassTag.names.item)
      if ($symbolIds.Count -ne $symbolNames.Count) {
        throw "SymbolClass ID/name count mismatch in $inputPath."
      }
      for ($symbolIndex = 0; $symbolIndex -lt $symbolNames.Count; $symbolIndex++) {
        if ([string]$symbolNames[$symbolIndex] -eq 'PromptMessageWidget') {
          $promptSymbolIds += [string]$symbolIds[$symbolIndex]
        }
      }
    }
    if ($promptSymbolIds.Count -ne 1) {
      throw "Expected exactly one PromptMessageWidget SymbolClass in $inputPath; found $($promptSymbolIds.Count)."
    }

    $promptSprite = $scaleform.SelectSingleNode(
      "/swf/tags/item[@type='DefineSpriteTag' and @spriteId='$($promptSymbolIds[0])']"
    )
    if (!$promptSprite) {
      throw "PromptMessageWidget sprite $($promptSymbolIds[0]) is missing from $inputPath."
    }
    $promptTextPlacements = @($promptSprite.SelectNodes(
      "./subTags/item[@name='textField' and @placeFlagHasCharacter='true']"
    ))
    if ($promptTextPlacements.Count -ne 1) {
      throw "Expected one PromptMessageWidget textField placement in $inputPath; found $($promptTextPlacements.Count)."
    }

    $promptTextId = [string]$promptTextPlacements[0].characterId
    $promptTextDefinition = $scaleform.SelectSingleNode(
      "/swf/tags/item[@type='DefineEditTextTag' and @characterID='$promptTextId']"
    )
    if (!$promptTextDefinition -or
        $promptTextDefinition.fontClass -ne '$MAIN_Font_Bold' -or
        $promptTextDefinition.hasFontClass -ne 'true' -or
        $promptTextDefinition.useOutlines -ne 'true') {
      throw "PromptMessageWidget textField does not have the expected linked `$MAIN_Font_Bold outline font in $inputPath."
    }

    if ($scaleform.SelectNodes('/swf/tags/item[@type="DoABC2Tag" and @name="venworks.cui.components.seed"]').Count -ne 0) {
      throw "Vanilla input unexpectedly contains the Venworks CUI ABC seed."
    }

    $abcSeedTags = $abcSeedPatch.SelectNodes('/scaleformAbcPatch/tags/item')
    if ($abcSeedTags.Count -ne 1 -or
        $abcSeedTags[0].type -ne 'DoABC2Tag' -or
        $abcSeedTags[0].name -ne 'venworks.cui.components.seed') {
      throw "ABC seed patch must contain exactly one named Venworks DoABC2Tag: $abcSeedPatchPath"
    }

    foreach ($abcSeedTag in $abcSeedTags) {
      $importedTag = $scaleform.ImportNode($abcSeedTag, $true)
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

    Invoke-Jpexs -Arguments @('-xml2swf', $patchedXmlPath, $timelineGfxPath) -Description "building the $($build.name) timeline"
    Invoke-Jpexs `
      -Arguments @('-format', 'script:as', '-export', 'script', $exportedScriptsDirectory, $timelineGfxPath) `
      -Description "exporting $($build.name) ActionScript"

    [xml]$actionScriptPatch = Get-Content -LiteralPath $actionScriptPatchPath -Raw
    $scriptName = [string]$actionScriptPatch.actionScriptPatch.script
    $exportedScriptMatches = @(Get-ChildItem -LiteralPath $exportedScriptsDirectory -Recurse -File -Filter "$scriptName.as")
    if ($exportedScriptMatches.Count -ne 1) {
      throw "Expected one exported $scriptName.as; found $($exportedScriptMatches.Count)."
    }

    New-Item -ItemType Directory -Path $importScriptsDirectory | Out-Null
    $patchedScriptPath = Join-Path $importScriptsDirectory "$scriptName.as"
    Apply-ActionScriptPatch `
      -SourcePath $exportedScriptMatches[0].FullName `
      -PatchPath $actionScriptPatchPath `
      -OutputPath $patchedScriptPath

    $authoredScripts = @(Get-ChildItem -LiteralPath $actionScriptSourcePath -Recurse -File -Filter "*.as")
    if ($authoredScripts.Count -ne 31) {
      throw "Expected 31 authored CUI classes; found $($authoredScripts.Count) in $actionScriptSourcePath."
    }

    foreach ($authoredScript in $authoredScripts) {
      $relativeScriptPath = $authoredScript.FullName.Substring($actionScriptSourcePath.Length).TrimStart(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
      )
      $importScriptPath = Join-Path $importScriptsDirectory $relativeScriptPath
      $importScriptParent = Split-Path -Parent $importScriptPath
      New-Item -ItemType Directory -Force -Path $importScriptParent | Out-Null
      Copy-Item -LiteralPath $authoredScript.FullName -Destination $importScriptPath
    }

    Invoke-Jpexs `
      -Arguments @('-onerror', 'abort', '-importScript', $timelineGfxPath, $generatedGfxPath, $importScriptsDirectory) `
      -Description "importing the $($build.name) ActionScript probe"
    Invoke-Jpexs -Arguments @('-swf2xml', $generatedGfxPath, $reopenedXmlPath) -Description "reopening $($build.name)"
    Invoke-Jpexs `
      -Arguments @('-format', 'script:as', '-export', 'script', $validationScriptsDirectory, $generatedGfxPath) `
      -Description "validating $($build.name) ActionScript"

    $generatedBytes = [System.IO.File]::ReadAllBytes($generatedGfxPath)
    if ($generatedBytes.Length -lt 3 -or [System.Text.Encoding]::ASCII.GetString($generatedBytes, 0, 3) -ne 'GFX') {
      throw "Generated output does not have a GFX signature: $generatedGfxPath"
    }

    [xml]$reopened = Get-Content -LiteralPath $reopenedXmlPath -Raw
    if ($reopened.SelectNodes('/swf/tags/item[@type="DoABC2Tag" and @name="venworks.cui.components.seed"]').Count -ne 1) {
      throw "Generated output does not contain exactly one Venworks CUI ABC seed tag."
    }

    $validationScriptMatches = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter "$scriptName.as")
    if ($validationScriptMatches.Count -ne 1) {
      throw "Expected one reopened $scriptName.as; found $($validationScriptMatches.Count)."
    }

    $originalScripts = @(Get-ChildItem -LiteralPath $exportedScriptsDirectory -Recurse -File -Filter "*.as")
    $validationScripts = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter "*.as")
    if ($originalScripts.Count -ne 198 -or $validationScripts.Count -ne $originalScripts.Count) {
      throw "Expected 198 seeded and reopened classes; found $($originalScripts.Count) before import and $($validationScripts.Count) after import."
    }

    foreach ($originalScript in $originalScripts) {
      $relativeOriginalPath = $originalScript.FullName.Substring($exportedScriptsDirectory.Length).TrimStart(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
      )
      if ($originalScript.Name -eq "$scriptName.as" -or
          $relativeOriginalPath -match '(^|[\\/])venworks[\\/]cui[\\/]') {
        continue
      }
      $reopenedScriptPath = Join-Path $validationScriptsDirectory $relativeOriginalPath
      if (!(Test-Path -LiteralPath $reopenedScriptPath -PathType Leaf) -or
          (Get-FileHash -LiteralPath $originalScript.FullName -Algorithm SHA256).Hash -ne
          (Get-FileHash -LiteralPath $reopenedScriptPath -Algorithm SHA256).Hash) {
        throw "Unexpected change to vanilla ActionScript class: $relativeOriginalPath"
      }
    }

    foreach ($authoredScript in $authoredScripts) {
      $relativeAuthoredPath = $authoredScript.FullName.Substring($actionScriptSourcePath.Length).TrimStart(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
      )
      $reopenedAuthoredPath = Join-Path (Join-Path $validationScriptsDirectory "scripts") $relativeAuthoredPath
      if (!(Test-Path -LiteralPath $reopenedAuthoredPath -PathType Leaf)) {
        throw "Generated output is missing authored class: $relativeAuthoredPath"
      }
    }

    $validationSource = ($validationScripts | ForEach-Object {
      Get-Content -LiteralPath $_.FullName -Raw
    }) -join "`n"
    foreach ($requiredValue in @(
      'VenworksCUI/layout.xml',
      'getDefinitionByName',
      'PromptMessageWidget',
      'CUITextFieldHost',
      'textField',
      'CUI LAYOUT MISSING',
      'CUI LAYOUT MALFORMED',
      'CUI LAYOUT UNSUPPORTED',
      'CUI LAYOUT INVALID',
      'VenworksCUIComponentLayer',
      'VenworksCUIDiagnosticsPanel',
      'CUICompositionResolver',
      'CUIConditionParser',
      'CUIConditionExpression',
      'CUIConditionContext',
      'CUIVisibilityBinding',
      'CUIVanillaVisibilityAdapter',
      'CUIAssetManager',
      'CUISvgParser',
      'CUISvgPathParser',
      'CUIImage',
      'CUISvg',
      'CUISvgPath',
      'CUIMask',
      'CUISymbol',
      'VenworksCUI/Assets/',
      'img://textures/interface/VenworksCUI/Assets/',
      'Image assets must use .dds',
      'CUI ASSET LOAD ERROR',
      'Asset path traversal is prohibited',
      'Unsupported SVG element',
      'SVG arc path commands are not supported',
      'Embedded symbol is not allowlisted',
      'environment-alert',
      'HUDMenu_fla.envAlertIcon_174',
      'HUDMenu_LRG_fla.envAlertIcon_174',
      'quest-door-marker',
      'QuestDoorMarker',
      'boost-fill',
      'HUDMenu_fla.BoostBarFill_mc_139',
      'HUDMenu_LRG_fla.BoostBarFill_mc_139',
      'CUISegmentedBar',
      'CUIDotBar',
      'CUIRadialMeter',
      'CUILayoutEngine',
      'Extensions.visibleRect',
      'top-left',
      'bottom-right',
      'Unsupported component anchor',
      'Unsupported repeater flow',
      'Unknown template reference',
      'content exceeds its configured bounds',
      'selects unknown option',
      'Condition exceeds the 8-level nesting limit',
      'Condition provider unavailable in hudmenu.gfx',
      'Vanilla visibility target is not allowlisted',
      'Meter direction must be right, left, down, or up',
      'Meter segmentCount must be between 1 and 64',
      'Radial thickness exceeds meter bounds',
      'alternating',
      'clockwise',
      'HudCrosshairData',
      'HUDStealthData',
      'HudCompassData',
      'HUDVehicleData'
    )) {
      if (!$validationSource.Contains($requiredValue)) {
        throw "Generated ActionScript is missing required value '$requiredValue'."
      }
    }

    if ($validationSource.Contains('VENWORKS XML LOADED') -or
        $validationSource.Contains('VenworksCuiTest_txt')) {
      throw "Generated ActionScript still contains the Goal 2 success probe."
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

  $cuiOutputDirectory = Join-Path $resolvedOutputDirectory "VenworksCUI"
  $assetOutputDirectory = Join-Path $cuiOutputDirectory "Assets"
  $textureAssetOutputDirectory = Join-Path $resolvedTextureOutputDirectory "Interface\VenworksCUI\Assets"
  New-Item -ItemType Directory -Force -Path $assetOutputDirectory | Out-Null
  New-Item -ItemType Directory -Force -Path $textureAssetOutputDirectory | Out-Null
  Copy-Item -LiteralPath $galleryLayoutSource -Destination (Join-Path $cuiOutputDirectory "layout.xml") -Force
  Copy-Item -LiteralPath $gallerySvgSource -Destination (Join-Path $assetOutputDirectory "gallery-vector.svg") -Force
  Copy-Item -LiteralPath $venworksLogoSvgSource -Destination (Join-Path $assetOutputDirectory "venworks-logo.svg") -Force
  Copy-Item -LiteralPath $invalidSvgSource -Destination (Join-Path $assetOutputDirectory "gallery-invalid.svg") -Force
  Copy-Item -LiteralPath $galleryDdsSource -Destination (Join-Path $textureAssetOutputDirectory "venworks-logo.dds") -Force
  Write-Host -ForegroundColor Green "Staged Goal 4E interface assets in $cuiOutputDirectory"
  Write-Host -ForegroundColor Green "Staged Goal 4E DDS assets in $textureAssetOutputDirectory"
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
