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
$referenceCacheHelperPath = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "sharedScaleformReferenceCache.ps1") `
  -Description "Scaleform reference-cache helper"
. $referenceCacheHelperPath
$resolvedReferenceCacheManifestPath = Resolve-RequiredFile `
  -Path $ReferenceCacheManifestPath `
  -Description "Scaleform reference-cache manifest"
$providerProbeLayoutSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\fixtures\chronomark-provider-probe.xml") `
  -Description "Goal 6 production HUD with Goal 7 equipment rail"
$providerProbeComponentDirectory = Resolve-RequiredDirectory `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\fixtures\components") `
  -Description "Goal 6 HUD component directory"
$playerHudDataContextSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\actionscript\venworks\cui\CUIPlayerHudDataContext.as") `
  -Description "Goal 6 player HUD data adapter"
$tacticalAwarenessModelSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\actionscript\venworks\cui\CUITacticalAwarenessModel.as") `
  -Description "Goal 9 tactical-awareness model"
$conditionContextSource = Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "..\Scaleform\shared\actionscript\venworks\cui\CUIConditionContext.as") `
  -Description "Goal 7 condition context"
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
$tacticalAwarenessModelText = Get-Content -LiteralPath $tacticalAwarenessModelSource -Raw
$conditionContextText = Get-Content -LiteralPath $conditionContextSource -Raw
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
if ($playerHudDataContextText -match 'diagnostic\.favorites|uStartingSelection|uQuickkeyIndex|iconImage') {
  throw 'Goal 7 production data bindings must not retain the temporary FavoritesData diagnostic or infer active state from menu-owned selection/image fields.'
}
if ($playerHudDataContextText -notmatch 'case "ArtifactPower_ElementalBlast":\s+name = "Elemental Pull"' -or
    $conditionContextText -notmatch 'case "ArtifactPower_ElementalBlast": return "elemental pull"') {
  throw 'Goal 7 must map Bethesda ArtifactPower_ElementalBlast to the user-facing Elemental Pull name in both data and condition contexts.'
}
if ($playerHudDataContextText -notmatch 'weapon\.explosivelabel' -or
    $playerHudDataContextText -notmatch 'explosiveType != 0 \? "MINE" : "GRENADE"' -or
    $playerHudDataContextText -notmatch '"NO THROWABLE"') {
  throw 'Goal 7 must derive a deterministic generic throwable label from the live explosive count and type.'
}
if ($playerHudDataContextText -notmatch 'ButtonKeyHelper' -or
    $playerHudDataContextText -notmatch 'Subscribe\("ControlMapData",this\.onControlMapData\)' -or
    $playerHudDataContextText -notmatch 'GetButtonNameForEvent\("Quickkey" \+ index\.toString\(\)\)' -or
    $playerHudDataContextText -notmatch 'favorite\." \+ this\.formatFavoriteSlot\(index\) \+ "\.hotkey"') {
  throw 'Goal 7 favorite labels must resolve Quickkey1 through Quickkey12 from Bethesda ControlMapData with ButtonKeyHelper.'
}
if ($playerHudDataContextText -notmatch 'refreshFavoriteSlotText\(\)' -or
    $conditionContextText -notmatch 'weaponMatch = populated.*activeWeaponName\.length != 0.*name == activeWeaponName' -or
    $conditionContextText -notmatch 'effectiveWeapon = Boolean\(favoriteWeapons\[index\]\) \|\| weaponMatch') {
  throw 'Goal 7 must classify and highlight an ammo-less melee favorite only when its normalized name exactly matches the live weapon name.'
}
if ($playerHudDataContextText -notmatch 'Subscribe\("PersonalEffectsData",this\.onPersonalEffectsData\)' -or
    $playerHudDataContextText -match 'Subscribe\("PersonalAlertsData"|Subscribe\("PlayerStatusData"' -or
    $playerHudDataContextText -notmatch 'TACTICAL_AWARENESS_CHANGE:String\s*=\s*"cuiTacticalAwarenessChange"' -or
    $playerHudDataContextText -notmatch 'tacticalAwareness\.updatePersonalEffects\(data\)' -or
    $playerHudDataContextText -notmatch 'tacticalAwareness\.updateEnvironment\(' -or
    $playerHudDataContextText -notmatch 'tacticalAwareness\.updateCompass\(compassData\)' -or
    $tacticalAwarenessModelText -notmatch 'HOSTILE_MAX:Number\s*=\s*35' -or
    $tacticalAwarenessModelText -notmatch 'PHYSICAL_HAZARD_MAX:Number\s*=\s*15' -or
    $tacticalAwarenessModelText -notmatch 'DEBUFF_MAX:Number\s*=\s*35' -or
    $tacticalAwarenessModelText -notmatch 'ENVIRONMENT_MAX:Number\s*=\s*15' -or
    $tacticalAwarenessModelText -notmatch 'AWARENESS_DISTANCE:Number\s*=\s*300' -or
    $tacticalAwarenessModelText -notmatch 'SUSTENANCE_' -or
    $tacticalAwarenessModelText -notmatch 'PERSONALEFFECT_') {
  throw 'Goal 9 must use live compass, environment, and persistent personal-effect data with the approved 35/15/35/15 threat model and no menu-scoped or transient status subscriptions.'
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
  'equipment-rail.xml',
  'environmental-hazard-scanner.xml',
  'helmet-awareness.xml',
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

$equipmentRailFixturePath = Resolve-RequiredFile `
  -Path (Join-Path $providerProbeComponentDirectory 'equipment-rail.xml') `
  -Description 'Goal 7 equipment rail component'
[xml]$equipmentRailFixture = Get-Content -LiteralPath $equipmentRailFixturePath -Raw
$dynamicEmptyFavoriteDetails = @($equipmentRailFixture.SelectNodes(
  '//text[string-length(@value) = 0 and @source and starts-with(@id, "contact.") and contains(@id, ".detail")]'
))
if ($dynamicEmptyFavoriteDetails.Count -ne 12) {
  throw "Goal 7 equipment rail must retain exactly 12 source-bound empty detail fallbacks; found $($dynamicEmptyFavoriteDetails.Count)."
}
if ($equipmentRailFixture.SelectNodes('//text[string-length(@value) = 0 and not(@source) and not(@valueTemplate)]').Count -ne 0) {
  throw 'Goal 7 equipment rail contains an empty static text value.'
}

$emptyStaticTextFixturePath = Resolve-RequiredFile `
  -Path (Join-Path $fixtureDirectory 'layout-invalid-empty-static-text.xml') `
  -Description 'Semantically invalid empty static-text fixture'
$emptyStaticTextSchemaErrors = @(Get-XmlSchemaErrors -XmlPath $emptyStaticTextFixturePath -SchemaPath $layoutSchemaPath)
if ($emptyStaticTextSchemaErrors.Count -ne 0) {
  throw "Empty static-text fixture should pass structural schema validation: $($emptyStaticTextSchemaErrors -join '; ')"
}
[xml]$emptyStaticTextFixture = Get-Content -LiteralPath $emptyStaticTextFixturePath -Raw
$invalidEmptyStaticTextNodes = @($emptyStaticTextFixture.SelectNodes(
  '//text[string-length(@value) = 0 and not(@source) and not(@valueTemplate)]'
))
if ($invalidEmptyStaticTextNodes.Count -ne 1 -or [string]$invalidEmptyStaticTextNodes[0].id -ne 'empty.static.text') {
  throw 'Empty static-text fixture must contain exactly one unbound empty text value.'
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
$referenceCacheContext = New-ScaleformReferenceCacheContext `
  -JavaPath $script:ResolvedJavaPath `
  -JpexsJarPath $script:ResolvedJpexsJarPath `
  -VanillaInterfacePath $resolvedVanillaInterfacePath `
  -WorkDirectory $resolvedWorkDirectory `
  -ManifestPath $resolvedReferenceCacheManifestPath

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

    $vanillaReference = Get-ScaleformReferenceMovie `
      -Context $referenceCacheContext `
      -InputFile ([string]$build.inputFile)
    Copy-Item -LiteralPath $vanillaReference.MovieXmlPath -Destination $decompiledXmlPath
    Write-Host -ForegroundColor Green "Copied cached vanilla XML: $decompiledXmlPath"

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

    if ($scaleform.SelectNodes('/swf/tags/item[@type="DoABC2Tag" and starts-with(@name,"venworks.cui.components.seed.")]').Count -ne 0) {
      throw "Vanilla input unexpectedly contains the Venworks CUI ABC seed."
    }

    $abcSeedTags = $abcSeedPatch.SelectNodes('/scaleformAbcPatch/tags/item')
    $invalidAbcSeedTags = @($abcSeedTags | Where-Object {
      $_.type -ne 'DoABC2Tag' -or $_.name -notmatch '^venworks\.cui\.components\.seed\.\d{3}$'
    })
    if ($abcSeedTags.Count -ne 1 -or $invalidAbcSeedTags.Count -ne 0 -or
        $abcSeedTags[0].name -ne 'venworks.cui.components.seed.000') {
      throw "ABC seed patch must contain exactly one numbered Venworks DoABCTag linkage domain: $abcSeedPatchPath"
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
    if ($authoredScripts.Count -eq 0) {
      throw "No authored CUI classes were found in $actionScriptSourcePath."
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
    $reopenedSeedTags = @($reopened.SelectNodes('/swf/tags/item[@type="DoABC2Tag" and starts-with(@name,"venworks.cui.components.seed.")]'))
    if ($reopenedSeedTags.Count -ne 1 -or
        $reopenedSeedTags[0].name -ne 'venworks.cui.components.seed.000') {
      throw 'Generated output does not retain exactly one Venworks CUI ABC linkage domain.'
    }

    $validationScriptMatches = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter "$scriptName.as")
    if ($validationScriptMatches.Count -ne 1) {
      throw "Expected one reopened $scriptName.as; found $($validationScriptMatches.Count)."
    }
    $reopenedHudMenuSource = Get-Content -LiteralPath $validationScriptMatches[0].FullName -Raw
    if ($reopenedHudMenuSource -notmatch 'CENTER_GROUP_POINT\.y\s*=\s*this\.CenterGroup_mc\.y;\s*if\s*\(this\.VenworksCUIRuntimeInstance\s*!=\s*null\)\s*\{\s*this\.VenworksCUIRuntimeInstance\.reapplyVanillaPlacements\(\);' -or
        $reopenedHudMenuSource -notmatch 'GlobalFunc\.LockToSafeRect\(this\.BottomLeftGroup_mc,"BL",SafeX,SafeY,true\)' -or
        $reopenedHudMenuSource -notmatch 'SocialCommandIcons_mc\.visible\s*=\s*param1\.data\.ModeVisibilityA\[HUDUtils\.SOCIAL_COMMAND_ICONS\]\.bVisible;\s*if\s*\(this\.VenworksCUIRuntimeInstance\s*!=\s*null\)\s*\{\s*this\.VenworksCUIRuntimeInstance\.updateVanillaHudModeVisibility\(param1\.data\.ModeVisibilityA\);') {
      throw 'Generated HUDMenu does not reapply configured vanilla placement and visibility after Bethesda updates.'
    }

    $originalScripts = @(Get-ChildItem -LiteralPath $exportedScriptsDirectory -Recurse -File -Filter "*.as")
    $validationScripts = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter "*.as")
    if ($validationScripts.Count -ne $originalScripts.Count) {
      throw "Seeded and reopened class inventories differ: $($originalScripts.Count) before import and $($validationScripts.Count) after import."
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

    foreach ($unchangedWatchClass in @('WatchIconsWidget.as','CompassMarkerWidget.as')) {
      $originalWatchClassMatches = @(Get-ChildItem -LiteralPath $exportedScriptsDirectory -Recurse -File -Filter $unchangedWatchClass)
      $reopenedWatchClassMatches = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter $unchangedWatchClass)
      if ($originalWatchClassMatches.Count -ne 1 -or
          $reopenedWatchClassMatches.Count -ne 1 -or
          (Get-FileHash -LiteralPath $originalWatchClassMatches[0].FullName -Algorithm SHA256).Hash -ne
          (Get-FileHash -LiteralPath $reopenedWatchClassMatches[0].FullName -Algorithm SHA256).Hash) {
        throw "Generated output unexpectedly changes Bethesda's $unchangedWatchClass."
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
      'weapon.explosivelabel',
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
      'param1.data.fGalacticStandardTime / 24',
      'player.xppercentage',
      'player.carbondioxidepercentage',
      'player.digipicks',
      'carry.percentage',
      'boost.percentage',
      'digipicksavailable',
      'WeaponData',
      'HUDStarbornPowersData',
      'FavoritesData',
      'MAX_FAVORITE_SLOTS',
      'resetFavoriteSlots',
      'cleanFavoriteText',
      'FAVORITE_SLOT_COUNT',
      'updateFavoriteActiveConditions',
      'Meter direction must be right, left, down, or up',
      'Meter segmentCount must be between 1 and 64',
      'Radial thickness exceeds meter bounds',
      'alternating',
      'clockwise',
      'HudCrosshairData',
      'HUDStealthData',
      'HudCompassData',
      'CUIContactRadar',
      'CUITacticalAwarenessModel',
      'CUICompassTape',
      'CUIThreatAlert',
      'CUIStatusEffectBar',
      'TACTICAL_AWARENESS_CHANGE',
      'currentCompassData',
      'currentTacticalAwarenessData',
      'MIT_MARKER_ENEMY',
      'MIT_MARKER_COMPANION',
      'MIT_MARKER_SHIP_PARKED',
      'MIT_MARKER_POSITION',
      'MIT_MARKER_VEHICLE',
      'updateVanillaHudModeVisibility',
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
    $reopenedContactRadarPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\components\CUIContactRadar.as'
    $reopenedCompassTapePath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\components\CUICompassTape.as'
    $reopenedThreatAlertPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\components\CUIThreatAlert.as'
    $reopenedStatusEffectBarPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\components\CUIStatusEffectBar.as'
    $reopenedTacticalAwarenessModelPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUITacticalAwarenessModel.as'
    $reopenedTextPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\components\CUIText.as'
    $reopenedConditionContextPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIConditionContext.as'
    $reopenedConditionExpressionPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIConditionExpression.as'
    $reopenedPlayerHudDataContextPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIPlayerHudDataContext.as'
    $reopenedValueBindingPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIValueBinding.as'
    $reopenedVisibilityBindingPath = Join-Path $validationScriptsDirectory 'scripts\venworks\cui\CUIVisibilityBinding.as'
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
    $reopenedContactRadarSource = Get-Content -LiteralPath $reopenedContactRadarPath -Raw
    $reopenedCompassTapeSource = Get-Content -LiteralPath $reopenedCompassTapePath -Raw
    $reopenedThreatAlertSource = Get-Content -LiteralPath $reopenedThreatAlertPath -Raw
    $reopenedStatusEffectBarSource = Get-Content -LiteralPath $reopenedStatusEffectBarPath -Raw
    $reopenedTacticalAwarenessModelSource = Get-Content -LiteralPath $reopenedTacticalAwarenessModelPath -Raw
    $reopenedTextSource = Get-Content -LiteralPath $reopenedTextPath -Raw
    $reopenedConditionContextSource = Get-Content -LiteralPath $reopenedConditionContextPath -Raw
    $reopenedConditionExpressionSource = Get-Content -LiteralPath $reopenedConditionExpressionPath -Raw
    $reopenedPlayerHudDataContextSource = Get-Content -LiteralPath $reopenedPlayerHudDataContextPath -Raw
    $reopenedValueBindingSource = Get-Content -LiteralPath $reopenedValueBindingPath -Raw
    $reopenedVisibilityBindingSource = Get-Content -LiteralPath $reopenedVisibilityBindingPath -Raw
    $reopenedVanillaVisibilitySource = Get-Content -LiteralPath $reopenedVanillaVisibilityPath -Raw
    $reopenedRuntimeSource = Get-Content -LiteralPath $reopenedRuntimePath -Raw
    $reopenedConditionChangeHandler = [regex]::Match(
      $reopenedRuntimeSource,
      '(?s)private function onConditionChanged\b.*?(?=\s+private function onValueChanged\b)'
    ).Value
    $reopenedValueChangeHandler = [regex]::Match(
      $reopenedRuntimeSource,
      '(?s)private function onValueChanged\b.*?(?=\s+private function onCompassChanged\b)'
    ).Value
    $reopenedCompassChangeHandler = [regex]::Match(
      $reopenedRuntimeSource,
      '(?s)private function onCompassChanged\b.*?(?=\s+private function onTacticalAwarenessChanged\b)'
    ).Value
    $reopenedTacticalAwarenessChangeHandler = [regex]::Match(
      $reopenedRuntimeSource,
      '(?s)private function onTacticalAwarenessChanged\b.*?(?=\s+private function applyValues\b)'
    ).Value
    $reopenedHudModeHandler = [regex]::Match(
      $reopenedRuntimeSource,
      '(?s)public function updateVanillaHudModeVisibility\b.*?(?=\s+private function onLoaded\b)'
    ).Value
    $reopenedContactRenderHandler = [regex]::Match(
      $reopenedContactRadarSource,
      '(?s)private function renderContact\b.*?(?=\s+private function selectContactStyle\b)'
    ).Value
    if ($reopenedLayoutParserSource -notmatch 'String\(param1\.@value\)\.length\s*==\s*0\s*&&\s*param1\.@source\.length\(\)\s*==\s*0\s*&&\s*param1\.@valueTemplate\.length\(\)\s*==\s*0' -or
        !$reopenedLayoutParserSource.Contains('Text value cannot be empty: ')) {
      throw 'Generated layout parser does not allow empty dynamic text fallbacks while rejecting empty static text.'
    }
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
    if ($reopenedPlayerHudDataContextSource -notmatch 'VALUE_CHANGE\s*:\s*String\s*=\s*"cuiValueChange"' -or
        $reopenedPlayerHudDataContextSource -notmatch 'COMPASS_CHANGE\s*:\s*String\s*=\s*"cuiCompassChange"' -or
        $reopenedPlayerHudDataContextSource -notmatch 'TACTICAL_AWARENESS_CHANGE\s*:\s*String\s*=\s*"cuiTacticalAwarenessChange"' -or
        $reopenedPlayerHudDataContextSource -notmatch 'dispatchEvent\s*\(\s*new CustomEvent\s*\(\s*VALUE_CHANGE\s*,\s*sources\s*\)\s*\)' -or
        $reopenedPlayerHudDataContextSource -notmatch 'dispatchEvent\s*\(\s*new Event\s*\(\s*COMPASS_CHANGE\s*\)\s*\)' -or
        $reopenedPlayerHudDataContextSource -notmatch 'dispatchEvent\s*\(\s*new Event\s*\(\s*TACTICAL_AWARENESS_CHANGE\s*\)\s*\)' -or
        $reopenedPlayerHudDataContextSource -notmatch 'valueMatches\s*\(\s*source\s*,\s*value\s*\)' -or
        $reopenedPlayerHudDataContextSource -notmatch 'changedSources\[param1\]\s*===\s*true' -or
        $reopenedPlayerHudDataContextSource -match 'dispatchEvent\s*\(\s*new Event\s*\(\s*Event\.CHANGE') {
      throw 'Generated player HUD data context does not retain changed-source value events and dedicated compass/tactical delivery.'
    }
    if ($reopenedConditionContextSource -notmatch 'CONDITION_CHANGE\s*:\s*String\s*=\s*"cuiConditionChange"' -or
        $reopenedConditionContextSource -notmatch 'dispatchEvent\s*\(\s*new CustomEvent\s*\(\s*CONDITION_CHANGE\s*,\s*conditions\s*\)\s*\)' -or
        $reopenedConditionContextSource -notmatch 'current\.value\s*===\s*param2' -or
        $reopenedConditionContextSource -notmatch 'changedConditions\[name\]\s*!==\s*true' -or
        $reopenedConditionContextSource -match 'dispatchEvent\s*\(\s*new Event\s*\(\s*Event\.CHANGE') {
      throw 'Generated condition context does not retain changed-condition events and no-op suppression.'
    }
    if ($reopenedValueBindingSource -notmatch 'function\s+isAffectedBy' -or
        $reopenedValueBindingSource -notmatch 'param1\[source\]\s*===\s*true' -or
        $reopenedValueBindingSource -notmatch 'param1\[maxSource\]\s*===\s*true' -or
        $reopenedValueBindingSource -notmatch 'for each\s*\(\s*variable\s+in\s+templateVariables\s*\)' -or
        $reopenedConditionExpressionSource -notmatch 'function\s+isAffectedBy' -or
        $reopenedConditionExpressionSource -notmatch 'function\s+nodeIsAffected' -or
        $reopenedConditionExpressionSource -notmatch 'CUIConditionContext\.normalizeName' -or
        $reopenedVisibilityBindingSource -notmatch 'expression\.isAffectedBy\s*\(\s*param1\s*\)' -or
        $reopenedVanillaVisibilitySource -notmatch 'param1\["hudopacitypercentage"\]\s*===\s*true' -or
        $reopenedVanillaVisibilitySource -notmatch 'expression\.isAffectedBy\s*\(\s*param1\s*\)') {
      throw 'Generated bindings do not retain source-specific value and visibility dependency matching.'
    }
    if ($reopenedRuntimeSource -notmatch 'addEventListener\s*\(\s*CUIConditionContext\.CONDITION_CHANGE\s*,\s*this\.onConditionChanged\s*\)' -or
        $reopenedRuntimeSource -notmatch 'addEventListener\s*\(\s*CUIPlayerHudDataContext\.VALUE_CHANGE\s*,\s*this\.onValueChanged\s*\)' -or
        $reopenedRuntimeSource -notmatch 'addEventListener\s*\(\s*CUIPlayerHudDataContext\.COMPASS_CHANGE\s*,\s*this\.onCompassChanged\s*\)' -or
        $reopenedRuntimeSource -notmatch 'addEventListener\s*\(\s*CUIPlayerHudDataContext\.TACTICAL_AWARENESS_CHANGE\s*,\s*this\.onTacticalAwarenessChanged\s*\)' -or
        $reopenedRuntimeSource -notmatch 'removeEventListener\s*\(\s*CUIConditionContext\.CONDITION_CHANGE\s*,\s*this\.onConditionChanged\s*\)' -or
        $reopenedRuntimeSource -notmatch 'removeEventListener\s*\(\s*CUIPlayerHudDataContext\.VALUE_CHANGE\s*,\s*this\.onValueChanged\s*\)' -or
        $reopenedRuntimeSource -notmatch 'removeEventListener\s*\(\s*CUIPlayerHudDataContext\.COMPASS_CHANGE\s*,\s*this\.onCompassChanged\s*\)' -or
        $reopenedRuntimeSource -notmatch 'removeEventListener\s*\(\s*CUIPlayerHudDataContext\.TACTICAL_AWARENESS_CHANGE\s*,\s*this\.onTacticalAwarenessChanged\s*\)' -or
        $reopenedRuntimeSource -notmatch 'binding\.isAffectedBy\s*\(\s*param1\s*\)' -or
        $reopenedRuntimeSource -notmatch 'adapter\.isAffectedBy\s*\(\s*param1\s*\)' -or
        $reopenedConditionChangeHandler.Length -eq 0 -or
        $reopenedConditionChangeHandler -notmatch 'applyConditions\s*\(\s*param1\.params\s*\)' -or
        $reopenedConditionChangeHandler -match 'applyValues|applyContactRadars' -or
        $reopenedValueChangeHandler.Length -eq 0 -or
        $reopenedValueChangeHandler -notmatch 'applyValues\s*\(\s*param1\.params\s*\)' -or
        $reopenedValueChangeHandler -match 'applyContactRadars|applyConditions' -or
        $reopenedCompassChangeHandler.Length -eq 0 -or
        $reopenedCompassChangeHandler -notmatch 'applyContactRadars\s*\(\s*\)' -or
        $reopenedCompassChangeHandler -match 'applyValues|applyConditions' -or
        $reopenedTacticalAwarenessChangeHandler.Length -eq 0 -or
        $reopenedTacticalAwarenessChangeHandler -notmatch 'applyTacticalAwareness\s*\(\s*\)' -or
        $reopenedTacticalAwarenessChangeHandler -match 'applyValues|applyConditions|applyContactRadars' -or
        $reopenedHudModeHandler.Length -eq 0 -or
        $reopenedHudModeHandler -notmatch 'adapter\.updateHudMode\s*\(\s*hudModeVisibility\s*\)' -or
        $reopenedHudModeHandler -notmatch 'adapter\.apply\s*\(\s*conditionContext\s*\)' -or
        $reopenedHudModeHandler -match 'applyValues|applyContactRadars|applyConditions' -or
        $reopenedRuntimeSource -match 'Event\.ENTER_FRAME|pendingValueSources|pendingConditionNames|pendingCompassUpdate|pendingHudModeUpdate|frameUpdateScheduled|scheduleFrameUpdate|onFrameUpdate|applyPending') {
      throw 'Generated runtime does not retain direct provider-local value, condition, compass, tactical-awareness, and HUD-mode routing boundaries, or still contains the rejected frame queue.'
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
        $reopenedVanillaVisibilitySource -notmatch 'function\s+updateHudMode' -or
        $reopenedVanillaVisibilitySource -notmatch 'HUDUtils\.BOTTOM_LEFT_GROUP' -or
        $reopenedVanillaVisibilitySource -notmatch 'HUDUtils\.RIGHT_METERS' -or
        $reopenedVanillaVisibilitySource -notmatch 'effectiveVisible\s*=\s*Boolean\(gameVisibilities\[index\]\)\s*&&\s*conditionVisible' -or
        $reopenedVanillaVisibilitySource -notmatch 'target\.visible\s*=\s*effectiveVisible' -or
        $reopenedRuntimeSource -notmatch 'function\s+updateVanillaHudModeVisibility' -or
        $reopenedRuntimeSource -notmatch 'hudModeVisibility\s*=\s*param1\s*==\s*null\s*\?\s*null\s*:\s*param1\.concat\(\)' -or
        $reopenedRuntimeSource -notmatch 'adapter\.updateHudMode\(hudModeVisibility\)' -or
        $reopenedVanillaVisibilitySource -match 'PowerBarEmpty_mc|EquippedGrenadeIcon_mc|EquippedGrenadeCount_mc|JetpackMeterWrapper_mc|HUDVehicle_mc') {
      throw 'Generated vanilla visibility adapter does not combine Bethesda HUD modes with configured whole-group rendering visibility.'
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
    if ($reopenedCompositionResolverSource -notmatch 'type\s*==\s*"contactRadar"' -or
        $reopenedLayoutParserSource -notmatch 'type\s*==\s*"contactRadar"' -or
        $reopenedRuntimeSource -notmatch 'type\s*==\s*"contactRadar"') {
      throw 'Generated ActionScript does not register contactRadar across composition, parsing, and runtime construction.'
    }
    foreach ($tacticalComponentType in @('compassTape','threatAlert','statusEffectBar')) {
      if ($reopenedCompositionResolverSource -notmatch "type\s*==\s*`"$tacticalComponentType`"" -or
          $reopenedLayoutParserSource -notmatch "type\s*==\s*`"$tacticalComponentType`"" -or
          $reopenedRuntimeSource -notmatch "type\s*==\s*`"$tacticalComponentType`"") {
        throw "Generated ActionScript does not register $tacticalComponentType across composition, parsing, and runtime construction."
      }
    }
    if ($reopenedTacticalAwarenessModelSource -notmatch 'AWARENESS_DISTANCE\s*:\s*Number\s*=\s*300' -or
        $reopenedTacticalAwarenessModelSource -notmatch 'HOSTILE_MAX\s*:\s*Number\s*=\s*35' -or
        $reopenedTacticalAwarenessModelSource -notmatch 'PHYSICAL_HAZARD_MAX\s*:\s*Number\s*=\s*15' -or
        $reopenedTacticalAwarenessModelSource -notmatch 'DEBUFF_MAX\s*:\s*Number\s*=\s*35' -or
        $reopenedTacticalAwarenessModelSource -notmatch 'ENVIRONMENT_MAX\s*:\s*Number\s*=\s*15' -or
        $reopenedTacticalAwarenessModelSource -notmatch 'param1\.indexOf\("PERSONALEFFECT_"\)\s*==\s*0' -or
        $reopenedTacticalAwarenessModelSource -notmatch 'param1\.indexOf\("SUSTENANCE_"\)\s*==\s*0' -or
        $reopenedTacticalAwarenessModelSource -notmatch 'SUSTENANCE_FOOD_POSITIVE_1' -or
        $reopenedTacticalAwarenessModelSource -notmatch 'SUSTENANCE_DRINK_POSITIVE_1') {
      throw 'Generated Goal 9 model does not retain the approved bounded live-data classification and 35/15/35/15 threat weights.'
    }
    if ($reopenedCompassTapeSource -notmatch 'getDefinitionByName\("CompassMarkerWidget"\)' -or
        $reopenedCompassTapeSource -notmatch 'MAX_MARKERS\s*:\s*int\s*=\s*48' -or
        $reopenedCompassTapeSource -notmatch 'MapMarkerUtils\.GetMajorFrameFromMitMarkerType' -or
        $reopenedCompassTapeSource -notmatch 'HEADING_LABELS\s*:\s*Array\s*=\s*\["N","NE","E","SE","S","SW","W","NW"\]' -or
        $reopenedStatusEffectBarSource -notmatch 'getDefinitionByName\("PersonalEffectsWidget"\)' -or
        $reopenedStatusEffectBarSource -notmatch 'HARD_MAX_ITEMS\s*:\s*int\s*=\s*COLUMN_COUNT\s*\*\s*ROW_COUNT' -or
        $reopenedThreatAlertSource -notmatch '"THREAT "\s*\+\s*int\(score\)\.toString\(\)\s*\+\s*"%') {
      throw 'Generated Goal 9 renderers do not retain the Watch icon reuse, eight-way heading tape, two-row bounded status display, and percentage threat presentation.'
    }
    if ($reopenedPlayerHudDataContextSource -match 'Subscribe\("PersonalAlertsData"|Subscribe\("PlayerStatusData"' -or
        $reopenedPlayerHudDataContextSource -notmatch 'Subscribe\("PersonalEffectsData",this\.onPersonalEffectsData\)') {
      throw 'Generated Goal 9 HUD context still uses menu-scoped/transient status providers or lost the persistent PersonalEffectsData subscription.'
    }
    if ($reopenedContactRadarSource -notmatch 'param1\.scaleX\s*=\s*1' -or
        $reopenedContactRadarSource -notmatch 'param1\.scaleY\s*=\s*1' -or
        $reopenedContactRadarSource -notmatch 'param1\.visible\s*=\s*false' -or
        $reopenedContactRadarSource -notmatch 'MAX_DISTANCE\s*:\s*Number\s*=\s*200' -or
        $reopenedContactRadarSource -notmatch 'fDistanceToPlayer' -or
        $reopenedContactRadarSource -notmatch 'distance\s*/\s*MAX_DISTANCE' -or
        $reopenedContactRadarSource -notmatch 'isFiniteNumber\s*\(\s*distance\s*\)' -or
        $reopenedContactRadarSource -notmatch 'isFiniteNumber\s*\(\s*param3\s*\)' -or
        $reopenedContactRadarSource -notmatch 'isFiniteNumber\s*\(\s*heading\s*\)' -or
        $reopenedContactRadarSource -notmatch 'isFiniteNumber\s*\(\s*contactX\s*\)' -or
        $reopenedContactRadarSource -notmatch 'isFiniteNumber\s*\(\s*contactY\s*\)' -or
        $reopenedContactRadarSource -notmatch 'isFiniteNumber\s*\(\s*markerAlpha\s*\)' -or
        $reopenedContactRadarSource -notmatch 'param1\.x\s*=\s*contactX' -or
        $reopenedContactRadarSource -notmatch 'param1\.y\s*=\s*contactY' -or
        $reopenedContactRadarSource -notmatch 'MIT_MARKER_SHIP_PARKED\s*:\s*uint\s*=\s*10' -or
        $reopenedContactRadarSource -notmatch 'MIT_MARKER_POSITION\s*:\s*uint\s*=\s*13' -or
        $reopenedContactRadarSource -notmatch 'MIT_MARKER_VEHICLE\s*:\s*uint\s*=\s*14' -or
        [regex]::Matches($reopenedContactRadarSource,'MIT_MARKER_SHIP_PARKED').Count -lt 3 -or
        [regex]::Matches($reopenedContactRadarSource,'MIT_MARKER_POSITION').Count -lt 3 -or
        [regex]::Matches($reopenedContactRadarSource,'MIT_MARKER_VEHICLE').Count -lt 3 -or
        $reopenedContactRadarSource -match 'MIT_MARKER_SHIP_PARKED\s*:\s*uint\s*=\s*11' -or
        $reopenedContactRadarSource -match 'MIT_MARKER_VEHICLE\s*:\s*uint\s*=\s*15' -or
        $reopenedContactRadarSource -match 'CUITextFieldHost|diagnosticField|"G:"|" TYPES:"' -or
        $reopenedContactRadarSource -match 'bIsNear' -or
        $reopenedContactRadarSource -match 'fDistanceScale' -or
        $reopenedContactRadarSource -match 'graphics\.clear\s*\(' -or
        $reopenedContactRadarSource -notmatch 'createContactShape\s*\(\s*enemyColor\s*,\s*false\s*\)' -or
        [regex]::Matches($reopenedContactRadarSource,'createContactShape\s*\(\s*allyColor').Count -lt 2 -or
        $reopenedContactRadarSource -notmatch 'createContactShape\s*\(\s*allyColor\s*,\s*true\s*\)' -or
        $reopenedContactRenderHandler.Length -eq 0 -or
        $reopenedContactRenderHandler -notmatch 'selectContactStyle\s*\(' -or
        $reopenedContactRenderHandler -match '\.graphics\.|new\s+(Shape|Sprite)') {
      throw 'Generated contact radar does not retain persistent marker geometry, finite transform validation, fixed 200-unit distance placement, fixed scaling, and the Bethesda 10/13/14 ship-position-vehicle mapping, or still contains retired near/far, distance-scale, live-redraw, or diagnostic behavior.'
    }
    if ($reopenedContactRadarSource -match 'BottomLeftGroup_mc|WatchIconsWidget|CompassMarkerWidget' -or
        $reopenedRuntimeSource -notmatch 'componentLayer\.name\s*=\s*"VenworksCUIComponentLayer"' -or
        $reopenedRuntimeSource -notmatch 'renderChildren\(parser\.components,componentLayer,parser\.components\)') {
      throw 'Generated contact radar is not independent from Bethesda Watch ownership and rendering.'
    }
    if ($reopenedPlayerHudDataContextSource -match 'diagnostic\.compassmarkers|updateCompassMarkerDiagnostic|"G:"|" TYPES:"' -or
        !$reopenedPlayerHudDataContextSource.Contains('BSUIDataManager.Subscribe("HudCompassData",this.onRadarCompassData)') -or
        !$reopenedPlayerHudDataContextSource.Contains('currentCompassData') -or
        $reopenedPlayerHudDataContextSource -notmatch 'compassData\s*=\s*param1\s*==\s*null\s*\?\s*null\s*:\s*param1\.data') {
      throw 'Generated player HUD data context does not retain radar compass delivery or still contains the retired marker-count diagnostic.'
    }
    if (!$reopenedTextSource.Contains('this.readBoolean(param1,"multiline",false)') -or
        !$reopenedTextSource.Contains('this.readBoolean(param1,"wordWrap",false)') -or
        !$reopenedLayoutParserSource.Contains('this.requireOptionalBoolean(param1,"multiline")') -or
        !$reopenedLayoutParserSource.Contains('this.requireOptionalBoolean(param1,"wordWrap")')) {
      throw 'Generated text component and layout parser do not retain opt-in multiline wrapping support.'
    }
    foreach ($diagnosticValue in @(
      'LAYOUT VALIDATION',
      'PARSER INITIALIZATION',
      'COMPONENT VALIDATION',
      'ASSET MANAGER INITIALIZATION',
      'ASSET COLLECTION',
      'COLLECTION AND REQUEST START',
      'lastDiagnosticNode',
      'lastDiagnosticCheckpoint',
      'getStackTrace'
    )) {
      if (!$reopenedLayoutParserSource.Contains($diagnosticValue) -and
          !$reopenedRuntimeSource.Contains($diagnosticValue)) {
        throw "Generated ActionScript is missing Goal 8 diagnostic checkpoint '$diagnosticValue'."
      }
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
    'player-data-diagnostic-strip.xml',
    'favorites-provider-diagnostic.xml',
    'weapon-status.xml',
    'contact-radar-diagnostic.xml',
    'personal-effects-diagnostic.xml'
  )
  foreach ($retiredComponentName in $retiredComponentNames) {
    $retiredComponentPath = Join-Path $componentOutputDirectory $retiredComponentName
    if (Test-Path -LiteralPath $retiredComponentPath) {
      Remove-Item -LiteralPath $retiredComponentPath -Force
    }
  }
  foreach ($componentFixtureName in @('contact-radar.xml','faction-display.xml','equipment-rail.xml','environmental-hazard-scanner.xml','helmet-awareness.xml','player-status-scanner.xml')) {
    Copy-Item -LiteralPath (Join-Path $providerProbeComponentDirectory $componentFixtureName) -Destination (Join-Path $componentOutputDirectory $componentFixtureName) -Force
  }
  $stagedHelmetAwarenessText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'helmet-awareness.xml') -Raw
  $stagedHelmetAwareness = [xml]$stagedHelmetAwarenessText
  $helmetAwarenessIncludes = @($providerProbeLayout.venworksCUI.includes.include | Where-Object {
    [string]$_.id -eq 'helmet-awareness'
  })
  $helmetCompassNodes = @($stagedHelmetAwareness.SelectNodes('//compassTape'))
  $helmetThreatNodes = @($stagedHelmetAwareness.SelectNodes('//threatAlert'))
  $helmetStatusNodes = @($stagedHelmetAwareness.SelectNodes('//statusEffectBar'))
  $helmetAwarenessInteractiveNodes = @($stagedHelmetAwareness.SelectNodes('//*[@action or @event or @onClick or @mouseEnabled]'))
  if ($helmetAwarenessIncludes.Count -ne 1 -or
      [string]$helmetAwarenessIncludes[0].src -ne 'helmet-awareness.xml' -or
      [string]$helmetAwarenessIncludes[0].anchor -ne 'top-center' -or
      [string]$helmetAwarenessIncludes[0].visibleWhen -ne 'always' -or
      [int]$helmetAwarenessIncludes[0].x -ne 0 -or
      [int]$helmetAwarenessIncludes[0].y -ne 22 -or
      [int]$helmetAwarenessIncludes[0].z -ne 110 -or
      $helmetCompassNodes.Count -ne 1 -or
      [int]$helmetCompassNodes[0].width -ne 320 -or
      [int]$helmetCompassNodes[0].height -ne 48 -or
      [int]$helmetCompassNodes[0].fieldOfView -ne 120 -or
      $helmetThreatNodes.Count -ne 1 -or
      [int]$helmetThreatNodes[0].width -ne 320 -or
      [int]$helmetThreatNodes[0].height -ne 24 -or
      $helmetStatusNodes.Count -ne 1 -or
      [int]$helmetStatusNodes[0].width -ne 720 -or
      [int]$helmetStatusNodes[0].height -ne 56 -or
      [int]$helmetStatusNodes[0].maxItems -ne 16 -or
      $helmetAwarenessInteractiveNodes.Count -ne 0 -or
      $stagedHelmetAwarenessText -match 'diagnostic\.|PlayerStatusData|PersonalAlertsData') {
    throw 'Goal 9 must stage one passive top-center compass tape, percentage threat alert, and bounded two-row persistent status display with no diagnostic or menu-scoped bindings.'
  }
  $stagedPlayerScannerText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'player-status-scanner.xml') -Raw
  $stagedPlayerScanner = [xml]$stagedPlayerScannerText
  if (@($stagedPlayerScanner.venworksCUIFragment.group.meter).Count -ne 6) {
    throw 'Staged player-status-scanner.xml must contain five normalized tracks and the shared CO2 overlay.'
  }
  $stagedEquipmentRailText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'equipment-rail.xml') -Raw
  $stagedEquipmentRail = [xml]$stagedEquipmentRailText
  $stagedEnvironmentalScannerText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'environmental-hazard-scanner.xml') -Raw
  $stagedEnvironmentalScanner = [xml]$stagedEnvironmentalScannerText
  $stagedContactRadarText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'contact-radar.xml') -Raw
  $stagedContactRadar = [xml]$stagedContactRadarText
  $stagedFactionDisplayText = Get-Content -LiteralPath (Join-Path $componentOutputDirectory 'faction-display.xml') -Raw
  $stagedFactionDisplay = [xml]$stagedFactionDisplayText
  $contactRadarIncludes = @($providerProbeLayout.venworksCUI.includes.include | Where-Object {
    [string]$_.id -eq 'contact-radar'
  })
  $factionDisplayIncludes = @($providerProbeLayout.venworksCUI.includes.include | Where-Object {
    [string]$_.id -eq 'faction-display'
  })
  $contactRadarNodes = @($stagedContactRadar.SelectNodes('//contactRadar'))
  $contactRadarRingNodes = @($stagedContactRadar.SelectNodes('//shape[starts-with(@id,"contact-radar.ring.")]'))
  $contactRadarRing50Nodes = @($stagedContactRadar.SelectNodes('//shape[@id="contact-radar.ring.50"]'))
  $contactRadarRing100Nodes = @($stagedContactRadar.SelectNodes('//shape[@id="contact-radar.ring.100"]'))
  $contactRadarRing150Nodes = @($stagedContactRadar.SelectNodes('//shape[@id="contact-radar.ring.150"]'))
  $contactRadarRing200Nodes = @($stagedContactRadar.SelectNodes('//shape[@id="contact-radar.ring.200"]'))
  $contactRadarRing300Nodes = @($stagedContactRadar.SelectNodes('//shape[@id="contact-radar.ring.300"]'))
  $contactRadarInteractiveNodes = @($stagedContactRadar.SelectNodes('//*[@action or @event or @onClick or @mouseEnabled]'))
  $factionDisplaySvgNodes = @($stagedFactionDisplay.SelectNodes('//svg[@src="venworks-logo.svg"]'))
  $factionDisplayTextNodes = @($stagedFactionDisplay.SelectNodes('//text'))
  if ($contactRadarIncludes.Count -ne 1 -or
      [string]$contactRadarIncludes[0].src -ne 'contact-radar.xml' -or
      [string]$contactRadarIncludes[0].visibleWhen -ne 'always' -or
      [string]$contactRadarIncludes[0].y -ne '-36' -or
      $factionDisplayIncludes.Count -ne 1 -or
      [string]$factionDisplayIncludes[0].src -ne 'faction-display.xml' -or
      [string]$factionDisplayIncludes[0].visibleWhen -ne 'always' -or
      [string]$factionDisplayIncludes[0].x -ne '-64' -or
      [string]$factionDisplayIncludes[0].y -ne '-36' -or
      $contactRadarNodes.Count -ne 1 -or
      $contactRadarRingNodes.Count -ne 4 -or
      $contactRadarRing50Nodes.Count -ne 1 -or
      [string]$contactRadarRing50Nodes[0].x -ne '91' -or
      [string]$contactRadarRing50Nodes[0].y -ne '90' -or
      [string]$contactRadarRing50Nodes[0].width -ne '46' -or
      [string]$contactRadarRing50Nodes[0].height -ne '46' -or
      $contactRadarRing100Nodes.Count -ne 1 -or
      [string]$contactRadarRing100Nodes[0].x -ne '68' -or
      [string]$contactRadarRing100Nodes[0].y -ne '67' -or
      [string]$contactRadarRing100Nodes[0].width -ne '92' -or
      [string]$contactRadarRing100Nodes[0].height -ne '92' -or
      $contactRadarRing150Nodes.Count -ne 1 -or
      [string]$contactRadarRing150Nodes[0].x -ne '45' -or
      [string]$contactRadarRing150Nodes[0].y -ne '44' -or
      [string]$contactRadarRing150Nodes[0].width -ne '138' -or
      [string]$contactRadarRing150Nodes[0].height -ne '138' -or
      $contactRadarRing200Nodes.Count -ne 1 -or
      [string]$contactRadarRing200Nodes[0].x -ne '22' -or
      [string]$contactRadarRing200Nodes[0].y -ne '21' -or
      [string]$contactRadarRing200Nodes[0].width -ne '184' -or
      [string]$contactRadarRing200Nodes[0].height -ne '184' -or
      $contactRadarRing300Nodes.Count -ne 0 -or
      $contactRadarInteractiveNodes.Count -ne 0 -or
      $stagedContactRadarText -match 'venworks-logo.svg' -or
      $stagedContactRadarText -match 'value="VENWORKS"' -or
      $factionDisplaySvgNodes.Count -ne 1 -or
      $factionDisplayTextNodes.Count -ne 0 -or
      $stagedContactRadarText -match 'diagnostic\.radar\.') {
    throw 'Goal 8B must stage independent top-edge faction and passive contact-radar displays, exact 50/100/150/200-unit range circles, one owned SVG crest, no duplicate label, and no diagnostic bindings.'
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
  $equipmentRailIncludes = @($providerProbeLayout.venworksCUI.includes.include | Where-Object {
    [string]$_.id -eq 'equipment-rail'
  })
  $helmetLowerFrameFillPaths = @($providerProbeLayout.venworksCUI.components.SelectNodes("path[@id='helmet.lower-frame.fill']"))
  $helmetUpperFrameFillPaths = @($providerProbeLayout.venworksCUI.components.SelectNodes("path[@id='helmet.upper-frame.fill']"))
  $helmetThreatRecessFillPaths = @($providerProbeLayout.venworksCUI.components.SelectNodes("path[@id='helmet.threat-recess.fill']"))
  $helmetVehicleExitGroups = @($providerProbeLayout.venworksCUI.components.SelectNodes("group[@id='helmet.vehicle-exit']"))
  $helmetVehicleExitLabels = @($providerProbeLayout.venworksCUI.components.SelectNodes("group[@id='helmet.vehicle-exit']/text[@id='vehicle.exit.label']"))
  $helmetVehicleExitGlyphs = @($providerProbeLayout.venworksCUI.components.SelectNodes("group[@id='helmet.vehicle-exit']/symbol[@id='vehicle.exit.glyph']"))
  $compassDiagnosticGroups = @($providerProbeLayout.venworksCUI.components.SelectNodes("group[@id='diagnostic.compass-markers']"))
  $compassDiagnosticPanels = @($providerProbeLayout.venworksCUI.components.SelectNodes("group[@id='diagnostic.compass-markers']/panel[@id='diagnostic.compass-markers.panel']"))
  $compassDiagnosticTexts = @($providerProbeLayout.venworksCUI.components.SelectNodes("group[@id='diagnostic.compass-markers']/text[@id='diagnostic.compass-markers.value']"))
  $compassDiagnosticBindings = @($providerProbeLayout.SelectNodes("//text[@source='diagnostic.compassmarkers']"))
  $bottomLeftTargets = @($providerProbeLayout.venworksCUI.vanillaVisibility.target | Where-Object {
    [string]$_.id -eq 'bottomLeft'
  })
  if ($compassDiagnosticGroups.Count -ne 0 -or
      $compassDiagnosticPanels.Count -ne 0 -or
      $compassDiagnosticTexts.Count -ne 0 -or
      $compassDiagnosticBindings.Count -ne 0) {
    throw 'The retired Goal 8 compass-marker diagnostic must not remain in the production layout.'
  }
  $environmentalProtectionStyles = @($providerProbeLayout.venworksCUI.definitions.meterStyle | Where-Object {
    [string]$_.id -eq 'environment.protection'
  })
  $environmentalExposureStyles = @($providerProbeLayout.venworksCUI.definitions.meterStyle | Where-Object {
    [string]$_.id -in @('environment.air','environment.thermal','environment.corrosive','environment.radiation')
  })
  $stagedEnvironmentalScannerGroup = $stagedEnvironmentalScanner.venworksCUIFragment.group
  $stagedEnvironmentalStructuralPaths = @($stagedEnvironmentalScannerGroup.SelectNodes('path'))
  $retiredStagedComponents = @($retiredComponentNames | Where-Object {
    Test-Path -LiteralPath (Join-Path $componentOutputDirectory $_)
  })
  $stagedPlayerScannerGroup = $stagedPlayerScanner.venworksCUIFragment.group
  $stagedPlayerStructuralPaths = @($stagedPlayerScannerGroup.SelectNodes('path'))
  $stagedEquipmentRailGroup = $stagedEquipmentRail.venworksCUIFragment.group
  $favoriteNameBindings = @($stagedEquipmentRailGroup.text | Where-Object {
    $_.HasAttribute('source') -and $_.GetAttribute('source') -match '^favorite\.(0[1-9]|1[0-2])\.name$'
  })
  $favoriteDetailBindings = @($stagedEquipmentRailGroup.text | Where-Object {
    $_.HasAttribute('source') -and $_.GetAttribute('source') -match '^favorite\.(0[1-9]|1[0-2])\.detail$'
  })
  $favoriteHotkeyBindings = @($stagedEquipmentRailGroup.text | Where-Object {
    $_.HasAttribute('source') -and $_.GetAttribute('source') -match '^favorite\.(0[1-9]|1[0-2])\.hotkey$'
  })
  $favoriteActiveMarkers = @($stagedEquipmentRailGroup.text | Where-Object {
    $_.HasAttribute('id') -and $_.GetAttribute('id') -match '^contact\.(0[1-9]|1[0-2])\.active$'
  })
  $favoriteActiveMarkerFailures = @($favoriteActiveMarkers | Where-Object {
    [string]$_.value -ne '>' -or
    [string]$_.color -ne '#FF4FE1' -or
    [int]$_.width -ne 12 -or
    [int]$_.height -ne 22 -or
    [int]$_.fontSize -ne 12 -or
    [string]$_.bold -ne 'true' -or
    [string]$_.visibleWhen -notmatch '^favorite(0[1-9]|1[0-2])Active$'
  })
  $equipmentRibbonPaths = @($stagedEquipmentRailGroup.path | Where-Object {
    $_.HasAttribute('id') -and $_.GetAttribute('id') -match '^rail\.ribbon\.'
  })
  $equipmentRibbonBody = @($stagedEquipmentRailGroup.path | Where-Object {
    $_.HasAttribute('id') -and $_.GetAttribute('id') -eq 'rail.ribbon.body'
  })
  $retiredEquipmentRibbonPaths = @($stagedEquipmentRailGroup.path | Where-Object {
    $_.HasAttribute('id') -and $_.GetAttribute('id') -in @('rail.ribbon.edge','rail.ribbon.guide')
  })
  $liveContactPanels = @($stagedEquipmentRailGroup.panel | Where-Object {
    $_.HasAttribute('id') -and $_.GetAttribute('id') -match '^contact\.(13|14|15)\.panel$'
  })
  $liveContactOutlineFailures = @($liveContactPanels | Where-Object {
    [string]$_.strokeColor -ne '#FFB51B' -or
    [double]$_.strokeOpacity -lt 0.8 -or
    [double]$_.strokeWidth -lt 2
  })
  $equipmentOutOfBoundsNodes = @($stagedEquipmentRailGroup.ChildNodes | Where-Object {
    $_.HasAttribute('id') -and
    $_.GetAttribute('id') -match '^(contact\.|vehicle\.)' -and
    $_.HasAttribute('x') -and
    $_.HasAttribute('y') -and
    $_.HasAttribute('width') -and
    $_.HasAttribute('height')
  } | Where-Object {
    [double]$_.x -lt 0 -or
    [double]$_.y -lt 0 -or
    ([double]$_.x + [double]$_.width) -gt [double]$stagedEquipmentRailGroup.width -or
    ([double]$_.y + [double]$_.height) -gt [double]$stagedEquipmentRailGroup.height
  })
  $favoriteTwoLineFailures = @(1..12 | ForEach-Object {
    $contactId = $_.ToString('00')
    $nameNode = $stagedEquipmentRailGroup.SelectSingleNode("text[@id='contact.$contactId.name']")
    $detailNode = $stagedEquipmentRailGroup.SelectSingleNode("text[@id='contact.$contactId.detail']")
    $dividerNode = $stagedEquipmentRailGroup.SelectSingleNode("divider[@id='contact.$contactId.divider']")
    if ($null -eq $nameNode -or
        $null -eq $detailNode -or
        $null -eq $dividerNode -or
        [double]$detailNode.y -lt ([double]$nameNode.y + [double]$nameNode.height) -or
        [double]$detailNode.x -ne [double]$nameNode.x -or
        [double]$detailNode.width -ne [double]$nameNode.width -or
        [double]$nameNode.height -lt 20 -or
        [double]$detailNode.height -lt 20 -or
        [double]$dividerNode.y -lt ([double]$detailNode.y + [double]$detailNode.height)) {
      $contactId
    }
  })
  $expectedFavoriteGeometry = @(
    [pscustomobject]@{ ContactId = '01'; MarkerX = 332; MarkerY = 34;  HotkeyX = 348; HotkeyY = 36;  IconX = 390; IconY = 37;  TextX = 416; NameY = 36;  DetailY = 56;  DividerY = 76;  TextWidth = 284 },
    [pscustomobject]@{ ContactId = '02'; MarkerX = 355; MarkerY = 76;  HotkeyX = 371; HotkeyY = 78;  IconX = 413; IconY = 79;  TextX = 439; NameY = 78;  DetailY = 98;  DividerY = 118; TextWidth = 261 },
    [pscustomobject]@{ ContactId = '03'; MarkerX = 378; MarkerY = 118; HotkeyX = 394; HotkeyY = 120; IconX = 436; IconY = 121; TextX = 462; NameY = 120; DetailY = 140; DividerY = 160; TextWidth = 238 },
    [pscustomobject]@{ ContactId = '04'; MarkerX = 401; MarkerY = 160; HotkeyX = 417; HotkeyY = 162; IconX = 459; IconY = 163; TextX = 485; NameY = 162; DetailY = 182; DividerY = 202; TextWidth = 215 },
    [pscustomobject]@{ ContactId = '05'; MarkerX = 424; MarkerY = 202; HotkeyX = 440; HotkeyY = 204; IconX = 482; IconY = 205; TextX = 508; NameY = 204; DetailY = 224; DividerY = 244; TextWidth = 192 },
    [pscustomobject]@{ ContactId = '06'; MarkerX = 424; MarkerY = 453; HotkeyX = 440; HotkeyY = 455; IconX = 482; IconY = 456; TextX = 508; NameY = 455; DetailY = 475; DividerY = 495; TextWidth = 192 },
    [pscustomobject]@{ ContactId = '07'; MarkerX = 409; MarkerY = 495; HotkeyX = 425; HotkeyY = 497; IconX = 467; IconY = 498; TextX = 493; NameY = 497; DetailY = 517; DividerY = 537; TextWidth = 207 },
    [pscustomobject]@{ ContactId = '08'; MarkerX = 393; MarkerY = 537; HotkeyX = 409; HotkeyY = 539; IconX = 451; IconY = 540; TextX = 477; NameY = 539; DetailY = 559; DividerY = 579; TextWidth = 223 },
    [pscustomobject]@{ ContactId = '09'; MarkerX = 378; MarkerY = 579; HotkeyX = 394; HotkeyY = 581; IconX = 436; IconY = 582; TextX = 462; NameY = 581; DetailY = 601; DividerY = 621; TextWidth = 238 },
    [pscustomobject]@{ ContactId = '10'; MarkerX = 363; MarkerY = 621; HotkeyX = 379; HotkeyY = 623; IconX = 421; IconY = 624; TextX = 447; NameY = 623; DetailY = 643; DividerY = 663; TextWidth = 253 },
    [pscustomobject]@{ ContactId = '11'; MarkerX = 347; MarkerY = 663; HotkeyX = 363; HotkeyY = 665; IconX = 405; IconY = 666; TextX = 431; NameY = 665; DetailY = 685; DividerY = 705; TextWidth = 269 },
    [pscustomobject]@{ ContactId = '12'; MarkerX = 332; MarkerY = 705; HotkeyX = 348; HotkeyY = 707; IconX = 390; IconY = 708; TextX = 416; NameY = 707; DetailY = 727; DividerY = 747; TextWidth = 284 }
  )
  $favoriteGeometryFailures = @($expectedFavoriteGeometry | ForEach-Object {
    $geometry = $_
    $markerNode = $stagedEquipmentRailGroup.SelectSingleNode("text[@id='contact.$($geometry.ContactId).active']")
    $hotkeyNode = $stagedEquipmentRailGroup.SelectSingleNode("text[@id='contact.$($geometry.ContactId).hotkey']")
    $iconNodes = @($stagedEquipmentRailGroup.SelectNodes("icon[starts-with(@id,'contact.$($geometry.ContactId).') and (@id='contact.$($geometry.ContactId).weapon' or @id='contact.$($geometry.ContactId).power' or @id='contact.$($geometry.ContactId).item')]") )
    $nameNode = $stagedEquipmentRailGroup.SelectSingleNode("text[@id='contact.$($geometry.ContactId).name']")
    $detailNode = $stagedEquipmentRailGroup.SelectSingleNode("text[@id='contact.$($geometry.ContactId).detail']")
    $dividerNode = $stagedEquipmentRailGroup.SelectSingleNode("divider[@id='contact.$($geometry.ContactId).divider']")
    if ($null -eq $markerNode -or
        $null -eq $hotkeyNode -or
        $iconNodes.Count -ne 3 -or
        $null -eq $nameNode -or
        $null -eq $detailNode -or
        $null -eq $dividerNode -or
        [int]$markerNode.x -ne $geometry.MarkerX -or
        [int]$markerNode.y -ne $geometry.MarkerY -or
        [int]$hotkeyNode.x -ne $geometry.HotkeyX -or
        [int]$hotkeyNode.y -ne $geometry.HotkeyY -or
        @($iconNodes | Where-Object { [int]$_.x -ne $geometry.IconX }).Count -ne 0 -or
        @($iconNodes | Where-Object { [int]$_.y -ne $geometry.IconY }).Count -ne 0 -or
        [int]$nameNode.x -ne $geometry.TextX -or
        [int]$nameNode.y -ne $geometry.NameY -or
        [int]$detailNode.x -ne $geometry.TextX -or
        [int]$detailNode.y -ne $geometry.DetailY -or
        [int]$dividerNode.x -ne $geometry.TextX -or
        [int]$dividerNode.y -ne $geometry.DividerY -or
        [int]$nameNode.width -ne $geometry.TextWidth -or
        [int]$nameNode.height -ne 20 -or
        [int]$detailNode.width -ne $geometry.TextWidth -or
        [int]$detailNode.height -ne 20 -or
        [int]$dividerNode.width -ne $geometry.TextWidth) {
      $geometry.ContactId
    }
  })
  $contactNumbers = @($stagedEquipmentRailGroup.text | Where-Object {
    $_.HasAttribute('id') -and $_.GetAttribute('id') -match '^contact\.(0[1-9]|1[0-5])\.number$'
  })
  $contactVisualOrder = @($stagedEquipmentRailGroup.ChildNodes | Where-Object {
      $_.HasAttribute('id') -and $_.GetAttribute('id') -match '^contact\.(0[1-9]|1[0-5])\.(active|panel)$'
    } |
    Sort-Object { [int]$_.GetAttribute('y') } |
    ForEach-Object { [regex]::Match($_.GetAttribute('id'), '^contact\.(\d{2})\.').Groups[1].Value })
  $expectedContactVisualOrder = @('01','02','03','04','05','13','14','15','06','07','08','09','10','11','12')
  $contactVisualOrderDifferences = @(Compare-Object -ReferenceObject $expectedContactVisualOrder -DifferenceObject $contactVisualOrder -SyncWindow 0)
  $expectedEquipmentRibbonBodyPath = 'M 304 0 C 324 44 352 96 382 142 C 400 176 400 216 398 252 C 396 318 398 382 400 430 C 392 486 368 552 340 620 C 326 654 318 688 320 712 C 322 728 340 740 360 747 L 720 747 L 720 0 Z'
  $equipmentRailScreenBottom = [double]$providerProbeLayout.venworksCUI.safeTop + [double]$equipmentRailIncludes[0].y + [double]$stagedEquipmentRailGroup.height
  $environmentalScannerScreenTop = [double]$providerProbeLayout.venworksCUI.designHeight - [double]$providerProbeLayout.venworksCUI.safeBottom + [double]$environmentalScannerIncludes[0].y - [double]$stagedEnvironmentalScannerGroup.height
  if ($equipmentRailIncludes.Count -ne 1 -or
      [string]$equipmentRailIncludes[0].src -ne 'equipment-rail.xml' -or
      [string]$equipmentRailIncludes[0].anchor -ne 'top-right' -or
      [string]$equipmentRailIncludes[0].visibleWhen -ne 'always' -or
      [int]$equipmentRailIncludes[0].x -ne 64 -or
      [int]$equipmentRailIncludes[0].y -ne 36 -or
      [int]$stagedEquipmentRailGroup.width -ne 720 -or
      [int]$stagedEquipmentRailGroup.height -ne 747 -or
      $equipmentRailScreenBottom -ne $environmentalScannerScreenTop -or
      $equipmentRibbonPaths.Count -ne 1 -or
      $equipmentRibbonBody.Count -ne 1 -or
      [string]$equipmentRibbonBody[0].data -ne $expectedEquipmentRibbonBodyPath -or
      [double]$equipmentRibbonBody[0].fillOpacity -gt 0.24 -or
      $retiredEquipmentRibbonPaths.Count -ne 0 -or
      $liveContactPanels.Count -ne 3 -or
      $liveContactOutlineFailures.Count -ne 0 -or
      $equipmentOutOfBoundsNodes.Count -ne 0 -or
      $favoriteTwoLineFailures.Count -ne 0 -or
      $favoriteGeometryFailures.Count -ne 0 -or
      $favoriteNameBindings.Count -ne 12 -or
      $favoriteDetailBindings.Count -ne 12 -or
      $favoriteHotkeyBindings.Count -ne 12 -or
      $favoriteActiveMarkers.Count -ne 12 -or
      $favoriteActiveMarkerFailures.Count -ne 0 -or
      $contactNumbers.Count -ne 0 -or
      $contactVisualOrderDifferences.Count -ne 0 -or
      $stagedEquipmentRailText -notmatch 'id="contact\.13\.icon"' -or
      $stagedEquipmentRailText -notmatch 'source="weapon\.icon"' -or
      $stagedEquipmentRailText -notmatch 'source="weapon\.ammoType"' -or
      $stagedEquipmentRailText -notmatch 'id="contact\.14\.name"' -or
      $stagedEquipmentRailText -notmatch 'source="weapon\.explosiveLabel"' -or
      $stagedEquipmentRailText -notmatch 'source="weapon\.explosiveCount"' -or
      $stagedEquipmentRailText -notmatch 'id="contact\.15\.name"' -or
      $stagedEquipmentRailText -notmatch 'source="power\.name"' -or
      $stagedEquipmentRailText -match 'vehicle\.exit|vehicle-exit-prompt|\$EXIT HOLD' -or
      $stagedEquipmentRailText -match '<button|action=|event=|callback=|userEvent=|key=' -or
      $stagedEquipmentRailText -match 'uStartingSelection|diagnostic\.' -or
      $stagedEquipmentRailText -match 'value="(ITEM|POWER|COUNT\s*)"' -or
      $stagedEquipmentRailText -match 'id="rail\.panel"|id="contact\.14\.(none|grenade|mine)"') {
    throw 'Goal 7 must stage one compact transparent passive ribbon at the physical right edge, use a bottom-only return aligned to Planet Data, contain the live contacts over its middle fill, remain ordered 1-5, weapon, throwable, power, 6-12 with mirrored uniformly stepped 20-unit two-line remapping-aware favorites, magenta chevron active markers, gold live-contact outlines, compact authoritative counts, and contain no vehicle prompt, cyan guide, opaque rail panel, diagnostic, or input behavior.'
  }
  $expectedHelmetLowerFrameFillPath = 'M 0 0 L 33 32 L 157 32 Q 169 32 169 44 L 169 52 Q 169 62 181 62 L 219 62 Q 231 62 231 52 L 231 44 Q 231 32 243 32 L 377 32 Q 385 32 385 40 L 385 237 C 399 237 407 243 417 253 Q 425 261 439 261 L 1481 261 Q 1495 261 1503 253 C 1513 243 1521 237 1535 237 L 1535 40 Q 1535 32 1543 32 L 1643 32 Q 1655 32 1655 44 L 1655 52 Q 1655 62 1667 62 L 1771 62 Q 1783 62 1783 52 L 1783 44 Q 1783 32 1795 32 L 1887 32 L 1920 0 L 1920 293 L 0 293 Z'
  $expectedHelmetUpperFrameFillPath = 'M 0 0 L 1920 0 L 1920 70 Q 1680 76 1450 92 L 1260 106 Q 1228 108 1204 118 Q 1190 126 1170 126 L 750 126 Q 730 126 716 118 Q 692 108 660 106 L 470 92 Q 240 76 0 70 Z'
  $expectedHelmetThreatRecessFillPath = 'M 16 0 L 304 0 Q 320 0 320 16 L 320 32 Q 320 48 304 48 L 16 48 Q 0 48 0 32 L 0 16 Q 0 0 16 0 Z'
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
      $helmetLowerFrameFillPaths.Count -ne 1 -or
      [string]$helmetLowerFrameFillPaths[0].anchor -ne 'bottom-left' -or
      [int]$helmetLowerFrameFillPaths[0].x -ne -64 -or
      [int]$helmetLowerFrameFillPaths[0].y -ne 36 -or
      [int]$helmetLowerFrameFillPaths[0].width -ne 1920 -or
      [int]$helmetLowerFrameFillPaths[0].height -ne 293 -or
      [int]$helmetLowerFrameFillPaths[0].z -ne 80 -or
      [string]$helmetLowerFrameFillPaths[0].data -ne $expectedHelmetLowerFrameFillPath -or
      [string]$helmetLowerFrameFillPaths[0].fillColor -ne '#03141D' -or
      [double]$helmetLowerFrameFillPaths[0].fillOpacity -ne 0.88 -or
      [double]$helmetLowerFrameFillPaths[0].strokeOpacity -ne 0 -or
      [int]$helmetLowerFrameFillPaths[0].viewBoxWidth -ne 1920 -or
      [int]$helmetLowerFrameFillPaths[0].viewBoxHeight -ne 293 -or
      $helmetUpperFrameFillPaths.Count -ne 1 -or
      [string]$helmetUpperFrameFillPaths[0].anchor -ne 'top-left' -or
      [int]$helmetUpperFrameFillPaths[0].x -ne -64 -or
      [int]$helmetUpperFrameFillPaths[0].y -ne -36 -or
      [int]$helmetUpperFrameFillPaths[0].width -ne 1920 -or
      [int]$helmetUpperFrameFillPaths[0].height -ne 126 -or
      [int]$helmetUpperFrameFillPaths[0].z -ne 80 -or
      [string]$helmetUpperFrameFillPaths[0].data -ne $expectedHelmetUpperFrameFillPath -or
      [string]$helmetUpperFrameFillPaths[0].fillColor -ne '#03141D' -or
      [double]$helmetUpperFrameFillPaths[0].fillOpacity -ne 0.84 -or
      [double]$helmetUpperFrameFillPaths[0].strokeOpacity -ne 0 -or
      [int]$helmetUpperFrameFillPaths[0].viewBoxWidth -ne 1920 -or
      [int]$helmetUpperFrameFillPaths[0].viewBoxHeight -ne 126 -or
      $helmetThreatRecessFillPaths.Count -ne 1 -or
      [string]$helmetThreatRecessFillPaths[0].anchor -ne 'top-center' -or
      [int]$helmetThreatRecessFillPaths[0].x -ne 0 -or
      [int]$helmetThreatRecessFillPaths[0].y -ne 22 -or
      [int]$helmetThreatRecessFillPaths[0].width -ne 320 -or
      [int]$helmetThreatRecessFillPaths[0].height -ne 48 -or
      [int]$helmetThreatRecessFillPaths[0].z -ne 81 -or
      [string]$helmetThreatRecessFillPaths[0].data -ne $expectedHelmetThreatRecessFillPath -or
      [string]$helmetThreatRecessFillPaths[0].fillColor -ne '#020B10' -or
      [double]$helmetThreatRecessFillPaths[0].fillOpacity -ne 0.72 -or
      [double]$helmetThreatRecessFillPaths[0].strokeOpacity -ne 0 -or
      [int]$helmetThreatRecessFillPaths[0].viewBoxWidth -ne 320 -or
      [int]$helmetThreatRecessFillPaths[0].viewBoxHeight -ne 48 -or
      $helmetVehicleExitGroups.Count -ne 1 -or
      [string]$helmetVehicleExitGroups[0].anchor -ne 'bottom-center' -or
      [string]$helmetVehicleExitGroups[0].visibleWhen -ne 'inVehicle' -or
      [int]$helmetVehicleExitGroups[0].x -ne 0 -or
      [int]$helmetVehicleExitGroups[0].y -ne 36 -or
      [int]$helmetVehicleExitGroups[0].width -ne 184 -or
      [int]$helmetVehicleExitGroups[0].height -ne 36 -or
      $helmetVehicleExitLabels.Count -ne 1 -or
      [string]$helmetVehicleExitLabels[0].value -ne '$EXIT HOLD' -or
      $helmetVehicleExitGlyphs.Count -ne 1 -or
      [string]$helmetVehicleExitGlyphs[0].name -ne 'vehicle-exit-prompt' -or
      $bottomLeftTargets.Count -ne 1 -or
      [string]$bottomLeftTargets[0].visibleWhen -ne 'never' -or
      $bottomLeftTargets[0].HasAttribute('anchor') -or
      $bottomLeftTargets[0].HasAttribute('x') -or
      $bottomLeftTargets[0].HasAttribute('y') -or
      [int]$stagedPlayerScannerGroup.width -ne 360 -or
      [int]$stagedPlayerScannerGroup.height -ne 236 -or
      $stagedPlayerStructuralPaths.Count -ne 0 -or
      $stagedPlayerScannerText -match 'id="header\.line"' -or
      $stagedPlayerScannerText -notmatch 'value="PLAYER DATA"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.serial"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.universalTime"' -or
      $stagedPlayerScannerText -notmatch 'id="time\.label" x="218" y="8" width="60" height="22"' -or
      $stagedPlayerScannerText -notmatch 'id="time" x="282" y="6" width="72" height="22"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.xpPercentage"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.healthPercentage"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.oxygenPercentage"' -or
      $stagedPlayerScannerText -notmatch 'source="player\.carbonDioxidePercentage"' -or
      $stagedPlayerScannerText -notmatch 'source="boost\.percentage"' -or
      $stagedPlayerScannerText -notmatch 'source="carry\.percentage"' -or
      $stagedPlayerScannerText -notmatch 'id="serial" x="58" y="34" width="288" height="20"' -or
      $stagedPlayerScannerText -notmatch 'id="level" x="174" y="78" width="90" height="22"' -or
      $stagedPlayerScannerText -notmatch 'id="mass" x="126" y="202" width="146" height="22"' -or
      $stagedPlayerScannerText -notmatch 'id="oxygen\.value" x="132" y="140" width="92" height="22"' -or
      $stagedPlayerScannerText -notmatch 'id="carbondioxide\.value" x="226" y="140" width="122" height="22"' -or
      $stagedPlayerScannerText -notmatch 'visibleWhen="digipicksAvailable"' -or
      $stagedPlayerScannerText -notmatch 'player\.digipicks:integer' -or
      ([regex]::Matches($stagedPlayerScannerText, 'max="100"')).Count -ne 6 -or
      $environmentalProtectionStyles.Count -ne 1 -or
      [string]$environmentalProtectionStyles[0].renderer -ne 'segments' -or
      [string]$environmentalProtectionStyles[0].direction -ne 'right' -or
      [int]$environmentalProtectionStyles[0].segmentCount -ne 16 -or
      $environmentalExposureStyles.Count -ne 4 -or
      @($environmentalExposureStyles | Where-Object {
        [string]$_.renderer -ne 'segments' -or
        [string]$_.direction -ne 'up' -or
        [int]$_.segmentCount -ne 8
      }).Count -ne 0 -or
      [int]$stagedEnvironmentalScannerGroup.width -ne 360 -or
      [int]$stagedEnvironmentalScannerGroup.height -ne 236 -or
      $stagedEnvironmentalStructuralPaths.Count -ne 0 -or
      $stagedEnvironmentalScannerText -match 'id="planet\.line"' -or
      $stagedEnvironmentalScannerText -notmatch 'value="PLANET DATA"' -or
      $stagedEnvironmentalScannerText -notmatch 'value="ENVIRONMENTAL HAZARDS"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="location\.name"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.localTime"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="planet\.time\.label" x="214" y="8" width="68" height="22"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="planet\.time" x="288" y="6" width="58" height="22"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="planet\.name" x="14" y="34" width="332" height="22"' -or
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
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.hazard\.airWaterShortStatus"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.hazard\.thermalShortStatus"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.hazard\.corrosiveShortStatus"' -or
      $stagedEnvironmentalScannerText -notmatch 'source="environment\.hazard\.radiationShortStatus"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="protection\.status" x="122" y="108" width="166" height="22"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="airwater\.label" x="12" y="151" width="80" height="18"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="airwater\.status" x="12" y="168" width="80" height="20"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="thermal\.status" x="96" y="168" width="80" height="20"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="corrosive\.status" x="180" y="168" width="80" height="20"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="radiation\.status" x="264" y="168" width="80" height="20"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="airwater\.exposure" x="30" y="190" width="44" height="34"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="thermal\.exposure" x="114" y="190" width="44" height="34"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="corrosive\.exposure" x="198" y="190" width="44" height="34"' -or
      $stagedEnvironmentalScannerText -notmatch 'id="radiation\.exposure" x="282" y="190" width="44" height="34"' -or
      $stagedEnvironmentalScannerText -match 'value="[^\"]*(ppm|μSv/h|mmpy|SAMPLE RATE|THREAT INDEX|VACUUM)') {
    throw 'The accepted HUD must stage the unified helmet architecture, content-only player and environmental scanners, vertical elemental channels, reserved threat recess, and passive upper-right equipment rail with no retired diagnostics or invented data.'
  }
  Copy-Item -LiteralPath $gallerySvgSource -Destination (Join-Path $assetOutputDirectory "gallery-vector.svg") -Force
  Copy-Item -LiteralPath $venworksLogoSvgSource -Destination (Join-Path $assetOutputDirectory "venworks-logo.svg") -Force
  Copy-Item -LiteralPath $invalidSvgSource -Destination (Join-Path $assetOutputDirectory "gallery-invalid.svg") -Force
  foreach ($outputPath in $resolvedOutputDirectories) {
    $variantCuiOutputDirectory = Join-Path $outputPath "VenworksCUI"
    $variantAssetOutputDirectory = Join-Path $variantCuiOutputDirectory "Assets"
    $variantComponentOutputDirectory = Join-Path $variantCuiOutputDirectory "components"
    if ($variantCuiOutputDirectory -ne $cuiOutputDirectory) {
      New-Item -ItemType Directory -Force -Path $variantAssetOutputDirectory | Out-Null
      New-Item -ItemType Directory -Force -Path $variantComponentOutputDirectory | Out-Null
      Copy-Item -LiteralPath (Join-Path $cuiOutputDirectory "layout.xml") -Destination (Join-Path $variantCuiOutputDirectory "layout.xml") -Force
      foreach ($componentFixtureName in @('contact-radar.xml','faction-display.xml','equipment-rail.xml','environmental-hazard-scanner.xml','helmet-awareness.xml','player-status-scanner.xml')) {
        Copy-Item -LiteralPath (Join-Path $componentOutputDirectory $componentFixtureName) -Destination (Join-Path $variantComponentOutputDirectory $componentFixtureName) -Force
      }
      foreach ($assetFileName in @('gallery-vector.svg','venworks-logo.svg','gallery-invalid.svg')) {
        Copy-Item -LiteralPath (Join-Path $assetOutputDirectory $assetFileName) -Destination (Join-Path $variantAssetOutputDirectory $assetFileName) -Force
      }
      foreach ($retiredComponentName in $retiredComponentNames) {
        $retiredComponentPath = Join-Path $variantComponentOutputDirectory $retiredComponentName
        if (Test-Path -LiteralPath $retiredComponentPath) {
          Remove-Item -LiteralPath $retiredComponentPath -Force
        }
      }
    }
    foreach ($relativeCuiPath in @(
      'layout.xml',
      'components\contact-radar.xml',
      'components\faction-display.xml',
      'components\equipment-rail.xml',
      'components\environmental-hazard-scanner.xml',
      'components\helmet-awareness.xml',
      'components\player-status-scanner.xml',
      'Assets\gallery-vector.svg',
      'Assets\venworks-logo.svg',
      'Assets\gallery-invalid.svg'
    )) {
      $primaryHash = (Get-FileHash -LiteralPath (Join-Path $cuiOutputDirectory $relativeCuiPath) -Algorithm SHA256).Hash
      $variantHash = (Get-FileHash -LiteralPath (Join-Path $variantCuiOutputDirectory $relativeCuiPath) -Algorithm SHA256).Hash
      if ($variantHash -ne $primaryHash) {
        throw "Staged CUI payload mismatch for $relativeCuiPath in $variantCuiOutputDirectory."
      }
    }
    Write-Host -ForegroundColor Green "Staged the Goal 9 compass, threat alert, and persistent status display with the accepted Goal 8 radar and production helmet HUD in $variantCuiOutputDirectory"
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
