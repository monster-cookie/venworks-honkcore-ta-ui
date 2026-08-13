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

function Assert-CuiIdentifier {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Identifier,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  if ([string]::IsNullOrEmpty($Identifier)) {
    throw "$Context is missing an id."
  }
  if ($Identifier.Length -gt 64) {
    throw "$Context id exceeds the 64-character limit ($($Identifier.Length)): $Identifier"
  }
  if ($Identifier -notmatch '^[A-Za-z][A-Za-z0-9._-]*$') {
    throw "$Context id contains unsupported characters: $Identifier"
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
$resolvedOutputDirectories = @($OutputDirectory | ForEach-Object {
  [System.IO.Path]::GetFullPath($_)
} | Select-Object -Unique)
if ($resolvedOutputDirectories.Count -eq 0) {
  throw "At least one output directory is required."
}
$resolvedProjectOutputDirectory = $resolvedOutputDirectories[0]
$resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
$decompileScript = Resolve-RequiredFile -Path (Join-Path $PSScriptRoot "decompileScaleform.ps1") -Description "Scaleform decompile helper"
$providerProbeLayoutSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\fixtures\chronomark-provider-probe.xml") `
  -Description "Goal 6 environmental provider probe"
$providerProbeComponentDirectory = Resolve-RequiredDirectory `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\fixtures\components") `
  -Description "Goal 6 HUD component directory"
$playerHudDataContextSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\actionscript\venworks\cui\CUIPlayerHudDataContext.as") `
  -Description "Goal 6 player HUD data adapter"
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
  'asset-primitives-gallery.xml',
  'composite-foundations-gallery.xml',
  'chronomark-provider-probe.xml'
)) {
  $positiveFixturePath = Resolve-RequiredFile `
    -Path (Join-Path $fixtureDirectory $positiveFixtureName) `
    -Description "Positive layout fixture"
  $schemaErrors = @(Get-XmlSchemaErrors -XmlPath $positiveFixturePath -SchemaPath $layoutSchemaPath)
  if ($schemaErrors.Count -ne 0) {
    throw "Positive fixture $positiveFixtureName failed schema validation: $($schemaErrors -join '; ')"
  }
}

$providerProbeLayout = [xml](Get-Content -LiteralPath $providerProbeLayoutSource -Raw)
$playerHudDataContextText = Get-Content -LiteralPath $playerHudDataContextSource -Raw
$playerSerialDerivation = [regex]::Match(
  $playerHudDataContextText,
  '(?s)private function derivePlayerSerial\(param1:String\).*?private function formatPlayerSerial')
if (-not $playerSerialDerivation.Success -or
    $playerHudDataContextText -match 'SharedObject|store\.flush\(\)' -or
    $playerSerialDerivation.Value -match 'Math\.random\(\)' -or
    $playerHudDataContextText -notmatch 'PLAYER_SERIAL_ALPHABET:String\s*=\s*"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"' -or
    $playerHudDataContextText -notmatch 'PLAYER_SERIAL_LENGTH:int\s*=\s*18' -or
    $playerHudDataContextText -notmatch 'derivePlayerSerial\(param1:String\)' -or
    $playerHudDataContextText -notmatch 'param1\.charCodeAt\(index\)' -or
    $playerSerialDerivation.Value -notmatch 'uint\(stateA \^ stateB\) % PLAYER_SERIAL_ALPHABET\.length' -or
    $playerHudDataContextText -notmatch 'MODE=DETERMINISTIC' -or
    $playerHudDataContextText -notmatch '\^\[A-Z0-9\]\{18\}\$' -or
    $playerHudDataContextText -notmatch 'substring\(0,8\)' -or
    $playerHudDataContextText -notmatch 'substring\(8,12\)' -or
    $playerHudDataContextText -notmatch 'substring\(12,18\)') {
  throw 'Goal 6 player serial probe must deterministically derive an 18-character uppercase alphanumeric value from the exact character name, use the accepted 8-4-6 display format, and perform no random or persistent-storage operations.'
}
foreach ($meterStyle in @($providerProbeLayout.venworksCUI.definitions.meterStyle)) {
  $renderer = [string]$meterStyle.renderer
  $rejectedAttributes = switch ($renderer) {
    'continuous' { @('segmentCount','gap','partialSegments','trianglePattern','startAngle','sweepAngle','clockwise','thickness') }
    'radial' { @('segmentCount','gap','direction','partialSegments','trianglePattern') }
    'triangles' { @('startAngle','sweepAngle','clockwise','thickness') }
    'segments' { @('trianglePattern','startAngle','sweepAngle','clockwise','thickness') }
    'dots' { @('trianglePattern','startAngle','sweepAngle','clockwise','thickness') }
    default { throw "Unsupported Goal 5 meter renderer: $renderer" }
  }
  foreach ($attributeName in $rejectedAttributes) {
    if ($null -ne $meterStyle.Attributes[$attributeName]) {
      throw "Goal 5 meter attribute '$attributeName' does not apply to renderer $renderer."
    }
  }
}

foreach ($componentFixtureName in @(
  'weapon-status.xml',
  'environmental-hazard-scanner.xml',
  'player-status-scanner.xml'
)) {
  $componentFixturePath = Resolve-RequiredFile `
    -Path (Join-Path $providerProbeComponentDirectory $componentFixtureName) `
    -Description "Positive component fragment"
  $componentSchemaErrors = @(Get-XmlSchemaErrors -XmlPath $componentFixturePath -SchemaPath $layoutSchemaPath)
  if ($componentSchemaErrors.Count -ne 0) {
    throw "Component fragment $componentFixtureName failed schema validation: $($componentSchemaErrors -join '; ')"
  }
}

$legacyOverlongResolvedId = 'environmental-hazard-diagnostic-strip.diagnostic.environment.candidates'
try {
  Assert-CuiIdentifier -Identifier $legacyOverlongResolvedId -Context 'Goal 6 composed-id regression'
  throw 'Composed-id validation did not reject the known 71-character Goal 6 regression.'
}
catch {
  if ($_.Exception.Message -notmatch 'exceeds the 64-character limit \(71\)') {
    throw
  }
}

foreach ($includeNode in @($providerProbeLayout.venworksCUI.includes.include)) {
  $includeId = [string]$includeNode.id
  Assert-CuiIdentifier -Identifier $includeId -Context 'CUI include'
  $includedFragmentPath = Resolve-RequiredFile `
    -Path (Join-Path $providerProbeComponentDirectory ([string]$includeNode.src)) `
    -Description "Included component fragment '$([string]$includeNode.src)'"
  [xml]$includedFragment = Get-Content -LiteralPath $includedFragmentPath -Raw
  foreach ($componentNode in @($includedFragment.SelectNodes('//*[@id]'))) {
    $resolvedComponentId = $includeId + '.' + [string]$componentNode.id
    Assert-CuiIdentifier `
      -Identifier $resolvedComponentId `
      -Context "Resolved $($componentNode.Name) component for include '$includeId'"
  }
}

$missingIncludeFixture = Resolve-RequiredFile -Path (Join-Path $fixtureDirectory 'layout-missing-include.xml') -Description "Missing include fixture"
$missingIncludeErrors = @(Get-XmlSchemaErrors -XmlPath $missingIncludeFixture -SchemaPath $layoutSchemaPath)
if ($missingIncludeErrors.Count -ne 0) {
  throw "Missing include fixture should pass structural schema validation: $($missingIncludeErrors -join '; ')"
}

foreach ($invalidImportFixtureName in @(
  'layout-unsafe-include-path.xml',
  'layout-nested-include.xml',
  'layout-duplicate-include-id.xml'
)) {
  $invalidImportFixture = Resolve-RequiredFile -Path (Join-Path $fixtureDirectory $invalidImportFixtureName) -Description "Invalid import fixture"
  $invalidImportErrors = @(Get-XmlSchemaErrors -XmlPath $invalidImportFixture -SchemaPath $layoutSchemaPath)
  if ($invalidImportErrors.Count -eq 0) {
    throw "Invalid import fixture $invalidImportFixtureName unexpectedly passed schema validation."
  }
}

$malformedFragmentPath = Resolve-RequiredFile -Path (Join-Path $fixtureDirectory 'layout-malformed-fragment.xml') -Description "Malformed fragment fixture"
try {
  [xml](Get-Content -LiteralPath $malformedFragmentPath -Raw) | Out-Null
  throw 'Malformed fragment fixture unexpectedly parsed as XML.'
}
catch {
  if ($_.Exception.Message -eq 'Malformed fragment fixture unexpectedly parsed as XML.') { throw }
}

foreach ($structurallyInvalidCompositeFixtureName in @(
  'layout-invalid-button-state.xml',
  'layout-invalid-composite-child.xml',
  'layout-invalid-quick-bar-overflow.xml',
  'layout-invalid-warning-severity.xml'
)) {
  $structurallyInvalidCompositeFixture = Resolve-RequiredFile `
    -Path (Join-Path $fixtureDirectory $structurallyInvalidCompositeFixtureName) `
    -Description "Structurally invalid composite fixture"
  $structuralErrors = @(Get-XmlSchemaErrors -XmlPath $structurallyInvalidCompositeFixture -SchemaPath $layoutSchemaPath)
  if ($structuralErrors.Count -eq 0) {
    throw "Invalid composite fixture $structurallyInvalidCompositeFixtureName unexpectedly passed schema validation."
  }
}

$semanticInformationPanelFixture = Resolve-RequiredFile `
  -Path (Join-Path $fixtureDirectory 'layout-invalid-information-panel.xml') `
  -Description "Semantically invalid information-panel fixture"
$semanticInformationPanelErrors = @(Get-XmlSchemaErrors -XmlPath $semanticInformationPanelFixture -SchemaPath $layoutSchemaPath)
if ($semanticInformationPanelErrors.Count -ne 0) {
  throw "Information-panel row-limit fixture should pass structural schema validation: $($semanticInformationPanelErrors -join '; ')"
}

$invalidAssetPathFixture = Resolve-RequiredFile `
  -Path (Join-Path $fixtureDirectory 'layout-invalid-asset-path.xml') `
  -Description "Invalid asset-path fixture"
$invalidAssetPathErrors = @(Get-XmlSchemaErrors -XmlPath $invalidAssetPathFixture -SchemaPath $layoutSchemaPath)
if ($invalidAssetPathErrors.Count -eq 0) {
  throw "Invalid asset-path fixture unexpectedly passed schema validation."
}

$unknownIconFixture = Resolve-RequiredFile `
  -Path (Join-Path $fixtureDirectory 'layout-unknown-icon.xml') `
  -Description "Unknown built-in icon fixture"
$unknownIconSchemaErrors = @(Get-XmlSchemaErrors -XmlPath $unknownIconFixture -SchemaPath $layoutSchemaPath)
if ($unknownIconSchemaErrors.Count -ne 0) {
  throw "Unknown built-in icon fixture should pass structural schema validation: $($unknownIconSchemaErrors -join '; ')"
}

foreach ($semanticValueFixtureName in @(
  'layout-unknown-value-source.xml',
  'layout-incompatible-value-binding.xml',
  'layout-invalid-value-format.xml',
  'layout-invalid-text-value-template.xml',
  'layout-unknown-template-value-source.xml',
  'layout-incompatible-template-value-format.xml'
)) {
  $semanticValueFixture = Resolve-RequiredFile `
    -Path (Join-Path $fixtureDirectory $semanticValueFixtureName) `
    -Description "Semantically invalid value-binding fixture"
  $semanticValueErrors = @(Get-XmlSchemaErrors -XmlPath $semanticValueFixture -SchemaPath $layoutSchemaPath)
  if ($semanticValueErrors.Count -ne 0) {
    throw "Value-binding fixture $semanticValueFixtureName should pass structural schema validation: $($semanticValueErrors -join '; ')"
  }
}

if (!(Test-Path -LiteralPath $resolvedVanillaInterfacePath -PathType Container)) {
  throw "Vanilla interface directory does not exist: $VanillaInterfacePath"
}

foreach ($outputPath in $resolvedOutputDirectories) {
  New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
}
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
    if ($authoredScripts.Count -ne 38) {
      throw "Expected 38 authored CUI classes; found $($authoredScripts.Count) in $actionScriptSourcePath."
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
    $reopenedHudMenuSource = Get-Content -LiteralPath $validationScriptMatches[0].FullName -Raw
    if ($reopenedHudMenuSource -notmatch 'CENTER_GROUP_POINT\.y\s*=\s*this\.CenterGroup_mc\.y;\s*if\s*\(this\.VenworksCUIRuntimeInstance\s*!=\s*null\)\s*\{\s*this\.VenworksCUIRuntimeInstance\.reapplyVanillaPlacements\(\);' -or
        $reopenedHudMenuSource -notmatch 'GlobalFunc\.LockToSafeRect\(this\.BottomLeftGroup_mc,"BL",SafeX,SafeY,true\)') {
      throw 'Generated HUDMenu does not reapply configured vanilla placement after Bethesda safe-rect locking.'
    }

    $originalScripts = @(Get-ChildItem -LiteralPath $exportedScriptsDirectory -Recurse -File -Filter "*.as")
    $validationScripts = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter "*.as")
    if ($originalScripts.Count -ne 205 -or $validationScripts.Count -ne $originalScripts.Count) {
      throw "Expected 205 seeded and reopened classes; found $($originalScripts.Count) before import and $($validationScripts.Count) after import."
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

    $reopenedCompositionResolverPath = Join-Path `
      (Join-Path $validationScriptsDirectory "scripts") `
      "venworks\cui\CUICompositionResolver.as"
    $reopenedCompositionResolverSource = Get-Content -LiteralPath $reopenedCompositionResolverPath -Raw
    if (!$reopenedCompositionResolverSource.Contains('type == "providerSymbol"')) {
      throw "Generated output composition resolver does not accept providerSymbol components."
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
      'CUICompositeResolver',
      'CUIConditionParser',
      'CUIConditionExpression',
      'CUIConditionContext',
      'CUIVisibilityBinding',
      'CUIVanillaVisibilityAdapter',
      'CUIPlayerHudDataContext',
      'CUIValueBinding',
      'Meter renderer must implement redraw.',
      'CUIMeter(target).setValue',
      'rightmeters',
      'RightMeters_mc',
      'weapon.explosivecount',
      'weapon.explosivetype',
      'boost.charge',
      'weaponhasexplosive',
      'weaponexplosiveismine',
      'boostactive',
      'HudJetpackData',
      'uExplosiveCount',
      'CUIAssetManager',
      'CUILayoutImportLoader',
      'VenworksCUI/components/',
      'The layout exceeds the 16-include limit',
      'Include paths must name one XML file',
      'cannot contain imports',
      'CUI COMPONENT MISSING',
      'CUI COMPONENT MALFORMED',
      'CUISvgParser',
      'CUISvgPathParser',
      'CUIImage',
      'CUISvg',
      'CUISvgPath',
      'CUIMask',
      'CUIIcon',
      'CUIIconLibrary',
      'CUISymbol',
      'VenworksCUI/Assets/',
      'dimension inspection',
      'display-list attachment',
      'tint application',
      'fit and alignment',
      'clipping setup',
      'CUI ASSET LOAD ERROR',
      'PHASE:',
      'COMPONENT:',
      'SYMBOL:',
      'EXCEPTION:',
      'ERROR ID:',
      'Asset path traversal is prohibited',
      'Unsupported SVG element',
      'SVG arc path commands are not supported',
      'Built-in icon is not allowlisted',
      'jolly-roger',
      'electrocution',
      'disease',
      'Embedded symbol is not allowlisted',
      'environment-alert',
      'HUDMenu_fla.envAlertIcon_174',
      'HUDMenu_LRG_fla.envAlertIcon_174',
      'quest-door-marker',
      'QuestDoorMarker',
      'boost-fill',
      'HUDMenu_fla.BoostBarFill_mc_139',
      'HUDMenu_LRG_fla.BoostBarFill_mc_139',
      'vehicle-exit-prompt',
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
      'exceeds the 16-button limit',
      'exceeds the 12-row limit',
      'Unsupported warning severity',
      'selects unknown option',
      'Condition exceeds the 8-level nesting limit',
      'Condition provider unavailable in hudmenu.gfx',
      'Vanilla visibility target is not allowlisted',
      'Value source is not allowlisted in hudmenu.gfx',
      'Text source and valueTemplate are mutually exclusive',
      'Text valueTemplate exceeds the 8-variable limit',
      'diagnostic.powernameprovider',
      'ArtifactPower_AlienReanim',
      'ArtifactPower_VoidForm',
      'HUD POWER KEY UNKNOWN',
      'fEncumbrance',
      'fMaxEncumbrance',
      'uCoin',
      'LocalEnvironmentData',
      'LocalEnvData_Frequent',
      'EnvironmentEffectsData',
      'fSoakDamagePct',
      'bShouldPlayAlertAtFullSoak',
      'environment.protectionlevel',
      'environment.protectionpercentage',
      'environment.protectionstatus',
      'PROTECTION DEPLETED',
      'AIR / WATER DETECTED',
      'EXPOSURE_UPDATE_MS',
      'EXPOSURE_LERP',
      'ACTIVITY_DRAIN_EPSILON',
      'ACTIVITY_ATTACK_STEP',
      'ACTIVITY_RELEASE_STEP',
      'this.oxygenActivity = Math.min(1,this.oxygenActivity + ACTIVITY_ATTACK_STEP)',
      'this.oxygenActivity = Math.max(0,this.oxygenActivity - ACTIVITY_RELEASE_STEP)',
      'this.currentFullSoak = fullSoak',
      'this.environmentalCritical = nextCritical',
      'this.exposureCurrent[index] = 1',
      '0.05 + 0.1 * randomValue + 0.25 * activity + 0.7 * depletion',
      'environment.hazard.airwaterexposurelevel',
      'environment.hazard.thermalexposurelevel',
      'environment.hazard.corrosiveexposurelevel',
      'environment.hazard.radiationexposurelevel',
      'diagnostic.activityoxygen',
      'diagnostic.activityenvelope',
      'diagnostic.activityprotection',
      'diagnostic.activityloads',
      'valueContext.dispose()',
      'PlayerFrequentData',
      'PlayerInventoryData',
      'player.serial',
      'player.universaltime',
      'player.xppercentage',
      'player.carbondioxidepercentage',
      'player.digipicks',
      'carry.percentage',
      'boost.percentage',
      'digipicksavailable',
      'WeaponData',
      'HUDStarbornPowersData',
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

    $reopenedAssetManagerPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIAssetManager.as'
    $reopenedLayoutParserPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUILayoutParser.as'
    $reopenedLayoutEnginePath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUILayoutEngine.as'
    $reopenedCompositionResolverPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUICompositionResolver.as'
    $reopenedCompositeResolverPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUICompositeResolver.as'
    $reopenedIconLibraryPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIIconLibrary.as'
    $reopenedIconPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\components\CUIIcon.as'
    $reopenedImagePath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\components\CUIImage.as'
    $reopenedSymbolPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\components\CUISymbol.as'
    $reopenedValueBindingPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIValueBinding.as'
    $reopenedVanillaVisibilityPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIVanillaVisibilityAdapter.as'
    $reopenedRuntimePath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIRuntime.as'
    $reopenedAssetManagerSource = Get-Content -LiteralPath $reopenedAssetManagerPath -Raw
    $reopenedLayoutParserSource = Get-Content -LiteralPath $reopenedLayoutParserPath -Raw
    $reopenedLayoutEngineSource = Get-Content -LiteralPath $reopenedLayoutEnginePath -Raw
    $reopenedCompositionResolverSource = Get-Content -LiteralPath $reopenedCompositionResolverPath -Raw
    $reopenedCompositeResolverSource = Get-Content -LiteralPath $reopenedCompositeResolverPath -Raw
    $reopenedIconLibrarySource = Get-Content -LiteralPath $reopenedIconLibraryPath -Raw
    $reopenedIconSource = Get-Content -LiteralPath $reopenedIconPath -Raw
    $reopenedImageSource = Get-Content -LiteralPath $reopenedImagePath -Raw
    $reopenedSymbolSource = Get-Content -LiteralPath $reopenedSymbolPath -Raw
    $reopenedValueBindingSource = Get-Content -LiteralPath $reopenedValueBindingPath -Raw
    $reopenedVanillaVisibilitySource = Get-Content -LiteralPath $reopenedVanillaVisibilityPath -Raw
    $reopenedRuntimeSource = Get-Content -LiteralPath $reopenedRuntimePath -Raw
    foreach ($identifierValidatorSource in @(
      $reopenedLayoutParserSource,
      $reopenedCompositionResolverSource,
      $reopenedCompositeResolverSource
    )) {
      foreach ($requiredIdentifierError in @(
        'Missing id on ',
        'exceeds the 64-character limit (',
        'contains unsupported characters: '
      )) {
        if (!$identifierValidatorSource.Contains($requiredIdentifierError)) {
          throw "Generated ID validator is missing actionable error text '$requiredIdentifierError'."
        }
      }
    }
    if ($reopenedValueBindingSource -notmatch 'CUIMeter\(target\)\.setValue' -or
        $reopenedValueBindingSource -match 'meterMask|ValueMask|flash\.geom\.Matrix') {
      throw 'Generated value binding does not use direct meter redraws or retains the retired external meter mask.'
    }
    foreach ($meterRenderer in @('CUIContinuousBar','CUISegmentedBar','CUITriangleBar','CUIDotBar','CUIRadialMeter')) {
      $meterRendererPath = Join-Path $validationScriptsDirectory "scripts\venworks\cui\components\$meterRenderer.as"
      $meterRendererSource = Get-Content -LiteralPath $meterRendererPath -Raw
      if ($meterRendererSource -notmatch 'override\s+protected\s+function\s+redraw') {
        throw "Generated $meterRenderer does not implement dynamic redraw."
      }
    }
    if ($reopenedVanillaVisibilitySource -notmatch 'targetName\s*==\s*"rightmeters"' -or
        $reopenedVanillaVisibilitySource -notmatch 'return\s+"RightMeters_mc"' -or
        $reopenedVanillaVisibilitySource -match 'PowerBarEmpty_mc|EquippedGrenadeIcon_mc|EquippedGrenadeCount_mc|JetpackMeterWrapper_mc|HUDVehicle_mc') {
      throw 'Generated rightMeters visibility adapter does not remain a whole-group alpha-only presentation gate.'
    }
    if ($reopenedVanillaVisibilitySource -notmatch 'function\s+reapplyPlacement' -or
        $reopenedVanillaVisibilitySource -notmatch 'layoutEngine\.positionVanilla\(DisplayObject\(targets\[index\]\),targetConfig\)' -or
        $reopenedRuntimeSource -notmatch 'function\s+reapplyVanillaPlacements' -or
        $reopenedRuntimeSource -notmatch 'adapter\.reapplyPlacement\(\)' -or
        $reopenedRuntimeSource -notmatch 'VANILLA SAFE-RECT PLACEMENT' -or
        $reopenedVanillaVisibilitySource -notmatch 'function\s+dispose' -or
        $reopenedLayoutEngineSource -notmatch 'function\s+positionVanilla' -or
        $reopenedLayoutEngineSource -notmatch 'param1\.getBounds\(parent\)' -or
        $reopenedLayoutEngineSource -notmatch 'createRootSafeRect\(rootConfig,parent\)' -or
        $reopenedLayoutParserSource -notmatch 'Vanilla target placement requires x, y, and anchor together') {
      throw 'Generated vanilla visibility adapter does not retain bounded safe-area placement for allowlisted whole targets.'
    }
    if ($reopenedSymbolSource -notmatch '"vehicle-exit-prompt"' -or
        $reopenedSymbolSource -notmatch '"classes":\["HUDVehicle"\]' -or
        $reopenedSymbolSource -notmatch '"child":"GetUpButton_mc"' -or
        $reopenedSymbolSource -notmatch '"glyphChildren":\["PCButton_mc","ConsoleButton_mc"\]' -or
        $reopenedSymbolSource -notmatch 'createBoundedChildViewport' -or
        $reopenedSymbolSource -notmatch 'bounds\.union\(childBounds\)' -or
        $reopenedSymbolSource -notmatch 'Object\(result\)\[String\(definition\.child\)\]' -or
        $reopenedSymbolSource -notmatch 'mouseEnabled\s*=\s*false' -or
        $reopenedSymbolSource -notmatch 'mouseChildren\s*=\s*false' -or
        $reopenedSymbolSource -match 'Subscribe|ProcessUserEvent|HandleUserEvent|UserEventData|callback') {
      throw 'Generated vehicle-exit-prompt symbol is not a bounded noninteractive presentation mapping.'
    }
    if ($reopenedAssetManagerSource -match 'flash\.display\.Loader' -or
        $reopenedAssetManagerSource -match 'LoaderContext' -or
        $reopenedAssetManagerSource -match 'ApplicationDomain' -or
        $reopenedAssetManagerSource -match 'createLibrarySymbol' -or
        $reopenedAssetManagerSource -match 'VenworksCUI/Libraries/') {
      throw 'Generated CUIAssetManager still contains retired supplemental SWF loading support.'
    }
    if ($reopenedIconLibrarySource -notmatch 'public\s+static\s+function\s+create' -or
        $reopenedIconLibrarySource -notmatch 'CUISvgPathParser\.draw' -or
        $reopenedIconLibrarySource -notmatch '"health"' -or
        $reopenedIconLibrarySource -notmatch '"disease"' -or
        $reopenedIconSource -notmatch 'CUIIconLibrary\.create') {
      throw 'Generated ActionScript is missing the same-domain built-in icon framework.'
    }
    foreach ($imagePhase in @(
      'dimension inspection',
      'display-list attachment',
      'tint application',
      'fit and alignment',
      'clipping setup'
    )) {
      if ($reopenedImageSource -notmatch [regex]::Escape($imagePhase)) {
        throw "Generated CUIImage is missing the '$imagePhase' diagnostic phase."
      }
    }
    if ($reopenedImageSource -notmatch 'readColor\s*\(\s*param1\s*,\s*"color"\s*,\s*16777215\s*\)') {
      throw 'Generated CUIImage does not use the shared XML color parser for asset tinting.'
    }
    if ($reopenedSymbolSource -match 'libraryLinkageName' -or $reopenedSymbolSource -match '@library') {
      throw 'Generated CUISymbol still contains retired supplemental-library support.'
    }
    if ($reopenedCompositionResolverSource -notmatch 'type\s*==\s*"icon"') {
      throw 'Generated CUICompositionResolver does not accept icon leaf components.'
    }
    if ($reopenedCompositionResolverSource -notmatch 'compositeResolver\.isComposite' -or
        $reopenedCompositeResolverSource -notmatch 'param1\s*==\s*"button"' -or
        $reopenedCompositeResolverSource -notmatch 'param1\s*==\s*"quickBar"' -or
        $reopenedCompositeResolverSource -notmatch 'param1\s*==\s*"informationPanel"' -or
        $reopenedCompositeResolverSource -notmatch 'param1\s*==\s*"warning"') {
      throw 'Generated ActionScript is missing the approved composite lowering framework.'
    }

    if ($validationSource.Contains('VENWORKS XML LOADED') -or
        $validationSource.Contains('VenworksCuiTest_txt')) {
      throw "Generated ActionScript still contains the Goal 2 success probe."
    }

    if ($validationSource.Contains('img://textures/interface/VenworksCUI/Assets/') -or
        $validationSource.Contains('Image assets must use .dds')) {
      throw "Generated ActionScript still contains retired direct DDS loading support."
    }

    $expectedOutputHash = Read-Sha256File -Path $expectedHashPath
    $actualOutputHash = (Get-FileHash -LiteralPath $generatedGfxPath -Algorithm SHA256).Hash
    if ($actualOutputHash -ne $expectedOutputHash) {
      throw "Generated hash mismatch for $($build.outputFile). Expected $expectedOutputHash; found $actualOutputHash."
    }

    foreach ($outputPath in $resolvedOutputDirectories) {
      $destinationPath = Join-Path $outputPath ([string]$build.outputFile)
      Copy-Item -LiteralPath $generatedGfxPath -Destination $destinationPath -Force
      Write-Host -ForegroundColor Green "Built and validated $destinationPath ($actualOutputHash)"
    }
  }

  $cuiOutputDirectory = Join-Path $resolvedProjectOutputDirectory "VenworksCUI"
  $assetOutputDirectory = Join-Path $cuiOutputDirectory "Assets"
  $componentOutputDirectory = Join-Path $cuiOutputDirectory "components"
  New-Item -ItemType Directory -Force -Path $assetOutputDirectory | Out-Null
  New-Item -ItemType Directory -Force -Path $componentOutputDirectory | Out-Null
  Copy-Item -LiteralPath $providerProbeLayoutSource -Destination (Join-Path $cuiOutputDirectory "layout.xml") -Force
  $retiredComponentNames = @(
    'environmental-hazard-diagnostic-strip.xml',
    'environment-status.xml',
    'player-meters.xml',
    'mobility-status.xml',
    'player-data-diagnostic-strip.xml'
  )
  foreach ($retiredComponentName in $retiredComponentNames) {
    $retiredComponentPath = Join-Path $componentOutputDirectory $retiredComponentName
    if (Test-Path -LiteralPath $retiredComponentPath) {
      Remove-Item -LiteralPath $retiredComponentPath -Force
    }
  }
  foreach ($componentFixtureName in @('weapon-status.xml','environmental-hazard-scanner.xml','player-status-scanner.xml')) {
    Copy-Item -LiteralPath (Join-Path $providerProbeComponentDirectory $componentFixtureName) -Destination (Join-Path $componentOutputDirectory $componentFixtureName) -Force
  }
  $stagedPlayerScannerText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'player-status-scanner.xml') -Raw
  $stagedPlayerScanner = [xml]$stagedPlayerScannerText
  if (@($stagedPlayerScanner.venworksCUIFragment.group.meter).Count -ne 6) {
    throw 'Staged player-status-scanner.xml must contain five normalized tracks and the shared CO2 overlay.'
  }
  $stagedWeaponStatusText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'weapon-status.xml') -Raw
  $stagedEnvironmentalScannerText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'environmental-hazard-scanner.xml') -Raw
  $stagedEnvironmentalScanner = [xml]$stagedEnvironmentalScannerText
  if ($stagedWeaponStatusText -notmatch 'name="vehicle-exit-prompt"' -or
      $stagedWeaponStatusText -notmatch 'value="\$EXIT HOLD"' -or
      $stagedWeaponStatusText -notmatch 'fontSize="21"' -or
      $stagedWeaponStatusText -notmatch 'id="vehicle\.exit\.label" x="8" y="88" width="165"' -or
      $stagedWeaponStatusText -notmatch 'id="vehicle\.exit\.glyph" x="183" y="80" width="52" height="52"' -or
      $stagedWeaponStatusText -notmatch 'source="power\.name"' -or
      ([regex]::Matches($stagedWeaponStatusText, 'visibleWhen="inVehicle"')).Count -lt 2 -or
      $stagedWeaponStatusText -match '<button|action=|event=|callback=|userEvent=|key=') {
    throw 'Staged weapon-status.xml must own the bounded vehicle-exit presentation and temporary active-power readout.'
  }
  $environmentalDiagnosticIncludes = @($providerProbeLayout.venworksCUI.includes.include | Where-Object {
    [string]$_.id -eq 'environmental-hazard-diagnostic'
  })
  $environmentalScannerIncludes = @($providerProbeLayout.venworksCUI.includes.include | Where-Object {
    [string]$_.id -eq 'environmental-hazard-scanner'
  })
  $playerScannerIncludes = @($providerProbeLayout.venworksCUI.includes.include | Where-Object {
    [string]$_.id -eq 'player-status-scanner'
  })
  $weaponStatusIncludes = @($providerProbeLayout.venworksCUI.includes.include | Where-Object {
    [string]$_.id -eq 'chronomark.weapon-status'
  })
  $bottomLeftTargets = @($providerProbeLayout.venworksCUI.vanillaVisibility.target | Where-Object {
    [string]$_.id -eq 'bottomLeft'
  })
  $environmentalProtectionStyles = @($providerProbeLayout.venworksCUI.definitions.meterStyle | Where-Object {
    [string]$_.id -eq 'environment.protection'
  })
  $stagedEnvironmentalScannerGroup = $stagedEnvironmentalScanner.venworksCUIFragment.group
  $retiredStagedComponents = @($retiredComponentNames | Where-Object {
    Test-Path -LiteralPath (Join-Path $componentOutputDirectory $_)
  })
  $stagedPlayerScannerGroup = $stagedPlayerScanner.venworksCUIFragment.group
  if ($environmentalDiagnosticIncludes.Count -ne 0 -or
      $retiredStagedComponents.Count -ne 0 -or
      $environmentalScannerIncludes.Count -ne 1 -or
      [string]$environmentalScannerIncludes[0].src -ne 'environmental-hazard-scanner.xml' -or
      [string]$environmentalScannerIncludes[0].anchor -ne 'bottom-right' -or
      [string]$environmentalScannerIncludes[0].visibleWhen -ne 'always' -or
      [int]$environmentalScannerIncludes[0].x -ne 39 -or
      [int]$environmentalScannerIncludes[0].y -ne 11 -or
      $playerScannerIncludes.Count -ne 1 -or
      [string]$playerScannerIncludes[0].src -ne 'player-status-scanner.xml' -or
      [string]$playerScannerIncludes[0].anchor -ne 'bottom-left' -or
      [string]$playerScannerIncludes[0].visibleWhen -ne 'always' -or
      [int]$playerScannerIncludes[0].x -ne -39 -or
      [int]$playerScannerIncludes[0].y -ne 11 -or
      $weaponStatusIncludes.Count -ne 1 -or
      [string]$weaponStatusIncludes[0].anchor -ne 'top-right' -or
      [int]$weaponStatusIncludes[0].x -ne 39 -or
      [int]$weaponStatusIncludes[0].y -ne -11 -or
      $bottomLeftTargets.Count -ne 1 -or
      [string]$bottomLeftTargets[0].visibleWhen -ne 'always' -or
      [string]$bottomLeftTargets[0].anchor -ne 'top-left' -or
      [int]$bottomLeftTargets[0].x -ne 25 -or
      [int]$bottomLeftTargets[0].y -ne 25 -or
      [int]$stagedPlayerScannerGroup.width -ne 360 -or
      [int]$stagedPlayerScannerGroup.height -ne 296 -or
      $stagedPlayerScannerText -notmatch 'value="PLAYER DATA"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.serial"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.universalTime"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.xpPercentage"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.healthPercentage"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.oxygenPercentage"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.carbonDioxidePercentage"' -or
      $stagedPlayerScannerText -notmatch 'source="boost\.percentage"' -or
      $stagedPlayerScannerText -notmatch 'source="carry\.percentage"' -or
      $stagedPlayerScannerText -notmatch 'id="level" x="174" y="92"' -or
      $stagedPlayerScannerText -notmatch 'id="mass" x="126" y="256"' -or
      $stagedPlayerScannerText -notmatch 'id="oxygen\.value" x="132" y="174"' -or
      $stagedPlayerScannerText -notmatch 'id="carbondioxide\.value" x="226" y="174"' -or
      $stagedPlayerScannerText -notmatch 'visibleWhen="digipicksAvailable"' -or
      $stagedPlayerScannerText -notmatch 'player\.digipicks:integer' -or
      ([regex]::Matches($stagedPlayerScannerText, 'max="100"')).Count -ne 6 -or
      $environmentalProtectionStyles.Count -ne 1 -or
      [string]$environmentalProtectionStyles[0].renderer -ne 'segments' -or
      [string]$environmentalProtectionStyles[0].direction -ne 'right' -or
      [int]$environmentalProtectionStyles[0].segmentCount -ne 16 -or
      [int]$stagedEnvironmentalScannerGroup.width -ne 360 -or
      [int]$stagedEnvironmentalScannerGroup.height -ne 312 -or
      $stagedEnvironmentalScannerText -notmatch 'value="PLANET DATA"' -or
      $stagedEnvironmentalScannerText -notmatch 'value="ENVIRONMENTAL HAZARDS"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="location\.name"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.localTime"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="planet\.time\.label" x="214" y="8"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="planet\.time" x="288" y="6"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.oxygenPercentage"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.temperature"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.gravity"' -or
      $stagedEnvironmentalScannerText -match 'RELATIVE LOAD' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.protectionLevel"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.protectionPercentage"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.protectionStatus"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.hazard\.airWaterExposureLevel"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.hazard\.thermalExposureLevel"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.hazard\.corrosiveExposureLevel"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.hazard\.radiationExposureLevel"' -or
      $stagedEnvironmentalScannerText -match 'value="[^\"]*(ppm|μSv/h|mmpy|SAMPLE RATE|THREAT INDEX|VACUUM)') {
    throw 'Goal 6 must stage the accepted environmental control, production player scanner, and temporary upper-right weapon/power presentation with no retired diagnostics or invented data.'
  }
  Copy-Item -LiteralPath $gallerySvgSource -Destination (Join-Path $assetOutputDirectory "gallery-vector.svg") -Force
  Copy-Item -LiteralPath $venworksLogoSvgSource -Destination (Join-Path $assetOutputDirectory "venworks-logo.svg") -Force
  Copy-Item -LiteralPath $invalidSvgSource -Destination (Join-Path $assetOutputDirectory "gallery-invalid.svg") -Force
  Write-Host -ForegroundColor Green "Staged the accepted Goal 6 environmental control and production player scanner in $cuiOutputDirectory"
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
