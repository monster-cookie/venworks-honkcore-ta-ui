[CmdletBinding()]
param()

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

function Get-Sha256 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Read-ExpectedSha256 {
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

function Resolve-PaletteColorReferences {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text,

    [Parameter(Mandatory = $true)]
    [hashtable]$ColorValues,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $resolvedText = $Text
  $referenceMatches = @([regex]::Matches(
    $resolvedText,
    '@palette\.colors\.([A-Za-z][A-Za-z0-9.-]*)'
  ))
  foreach ($referenceMatch in $referenceMatches) {
    $role = [string]$referenceMatch.Groups[1].Value
    if (!$ColorValues.ContainsKey($role)) {
      throw "$Context references unknown Starfield palette color '$role'."
    }
    $resolvedText = $resolvedText.Replace(
      [string]$referenceMatch.Value,
      [string]$ColorValues[$role]
    )
  }

  if ($resolvedText -match '@palette\.') {
    throw "$Context retains an unresolved palette reference."
  }

  return $resolvedText
}

function Get-ExpectedMinimalistLayout {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [hashtable]$ColorValues
  )

  $expectedText = [System.IO.File]::ReadAllText($SourcePath)
  $paletteAttributeMatches = @([regex]::Matches($expectedText, '\s+palette="[^"]+"'))
  if ($paletteAttributeMatches.Count -ne 1) {
    throw "Production layout must contain exactly one palette selector."
  }
  $expectedText = [regex]::Replace($expectedText, '\s+palette="[^"]+"', '', 1)

  $factionIncludePattern = '(?ms)^[ \t]*<include\b(?=[^>]*\bid="faction-display")[^>]*/>\r?\n'
  $factionIncludeMatches = @([regex]::Matches($expectedText, $factionIncludePattern))
  if ($factionIncludeMatches.Count -ne 1) {
    throw "Production layout must contain exactly one faction-display include."
  }
  $expectedText = [regex]::Replace($expectedText, $factionIncludePattern, '', 1)

  $radarPositionPattern = '(<include\b(?=[^>]*\bid="contact-radar")[^>]*\bx=")155("[^>]*/>)'
  $radarPositionMatches = @([regex]::Matches($expectedText, $radarPositionPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline))
  if ($radarPositionMatches.Count -ne 1) {
    throw "Production layout must contain the expected contact-radar position."
  }
  $expectedText = [regex]::Replace(
    $expectedText,
    $radarPositionPattern,
    { param($match) $match.Groups[1].Value + '-64' + $match.Groups[2].Value },
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  return Resolve-PaletteColorReferences `
    -Text $expectedText `
    -ColorValues $ColorValues `
    -Context "Expected Minimalist layout"
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

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  . "$PSScriptRoot\sharedConfig.ps1"
}

$minimalistVariants = @(Get-ModuleVariants -VariantKey "MIN")
if ($minimalistVariants.Count -ne 1) {
  throw "Expected exactly one Minimalist variant."
}
$minimalistVariant = $minimalistVariants[0]
if (![string]::IsNullOrEmpty($minimalistVariant.PaletteFileName)) {
  throw "Minimalist must not define a palette file."
}
if (@($minimalistVariant.ArchiveTargets).Count -ne 1 -or
    [string]$minimalistVariant.ArchiveTargets[0] -ne "Main_PS") {
  throw "Minimalist must target only the PS Main archive."
}

if (!(Test-Path -LiteralPath $minimalistVariant.StagingFolderPath -PathType Container)) {
  throw "Minimalist staging folder does not exist: $($minimalistVariant.StagingFolderPath)"
}
$stagingItem = Get-Item -LiteralPath $minimalistVariant.StagingFolderPath
if ($stagingItem.LinkType -ne "Junction") {
  throw "Minimalist staging folder must be a Junction."
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

& (Join-Path $PSScriptRoot "verifyPs5MinimalistScaleform.ps1") `
  -InterfacePath (Join-Path $resolvedStagingPath "Interface")

$componentFileNames = @(
  "contact-radar.xml",
  "equipment-rail.xml",
  "environmental-hazard-scanner.xml",
  "helmet-awareness.xml",
  "player-status-scanner.xml",
  "quest-tracker.xml",
  "scanner-overlay.xml"
)
$movieDefinitions = @(
  [pscustomobject]@{ FileName = "hudmenu.gfx"; ExpectedHashPath = "Scaleform\ps5-minimalist\validation\hudmenu.sha256" },
  [pscustomobject]@{ FileName = "hudmenu_lrg.gfx"; ExpectedHashPath = "Scaleform\ps5-minimalist\validation\hudmenu_lrg.sha256" },
  [pscustomobject]@{ FileName = "hudmessagesmenu.gfx"; ExpectedHashPath = "Scaleform\hudmessagesmenu\validation\expected.sha256" },
  [pscustomobject]@{ FileName = "hudmessagesmenu_lrg.gfx"; ExpectedHashPath = "Scaleform\hudmessagesmenu_lrg\validation\expected.sha256" }
)

$expectedRelativeFiles = @(
  "$($minimalistVariant.PackageBaseName).esm",
  "$($minimalistVariant.PackageBaseName) - Main_PS.ba2",
  "Interface\VenworksCUI\layout.xml"
)
$expectedRelativeFiles += @($movieDefinitions | ForEach-Object { "Interface\$($_.FileName)" })
$expectedRelativeFiles += @($componentFileNames | ForEach-Object {
  "Interface\VenworksCUI\components\$_"
})
$actualRelativeFiles = @(
  Get-ChildItem -LiteralPath $resolvedStagingPath -Recurse -File |
    ForEach-Object { $_.FullName.Substring($resolvedStagingPath.Length + 1) } |
    Sort-Object
)
$sortedExpectedRelativeFiles = @($expectedRelativeFiles | Sort-Object)
if ($actualRelativeFiles.Count -ne $sortedExpectedRelativeFiles.Count) {
  throw "Minimalist staging contains $($actualRelativeFiles.Count) files; expected $($sortedExpectedRelativeFiles.Count)."
}
for ($index = 0; $index -lt $sortedExpectedRelativeFiles.Count; $index++) {
  if ($actualRelativeFiles[$index] -cne $sortedExpectedRelativeFiles[$index]) {
    throw "Minimalist staging inventory mismatch. Expected '$($sortedExpectedRelativeFiles[$index])'; found '$($actualRelativeFiles[$index])'."
  }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
foreach ($movieDefinition in $movieDefinitions) {
  $moviePath = Resolve-RequiredFile `
    -Path (Join-Path $resolvedStagingPath "Interface\$($movieDefinition.FileName)") `
    -Description "Minimalist movie $($movieDefinition.FileName)"
  $expectedHash = Read-ExpectedSha256 `
    -Path (Join-Path $repositoryRoot $movieDefinition.ExpectedHashPath)
  $actualHash = Get-Sha256 -Path $moviePath
  if ($actualHash -cne $expectedHash) {
    throw "Minimalist movie $($movieDefinition.FileName) hash mismatch. Expected $expectedHash; found $actualHash."
  }
}

$sourcePluginPath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Staging-TA\Venworks-CustomizableHUD-TrackersAlliance.esm") `
  -Description "Release stub ESM"
$minimalistPluginPath = Resolve-RequiredFile `
  -Path (Join-Path $resolvedStagingPath "$($minimalistVariant.PackageBaseName).esm") `
  -Description "Minimalist stub ESM"
if ((Get-Sha256 -Path $minimalistPluginPath) -cne (Get-Sha256 -Path $sourcePluginPath)) {
  throw "Minimalist stub ESM is not byte-identical to the release stub."
}

$minimalistArchivePath = Resolve-RequiredFile `
  -Path (Join-Path $resolvedStagingPath "$($minimalistVariant.PackageBaseName) - Main_PS.ba2") `
  -Description "Minimalist PS Main archive"
if ((Get-Item -LiteralPath $minimalistArchivePath).Length -le 0) {
  throw "Minimalist PS Main archive is empty."
}
$archiveFiles = @(Get-ChildItem -LiteralPath $resolvedStagingPath -Recurse -File -Filter "*.ba2")
if ($archiveFiles.Count -ne 1 -or $archiveFiles[0].FullName -cne $minimalistArchivePath) {
  throw "Minimalist must contain only its root PS Main archive."
}

$starfieldPalettePath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Scaleform\shared\palettes\starfield.xml") `
  -Description "Starfield palette source"
[xml]$starfieldPalette = Get-Content -LiteralPath $starfieldPalettePath -Raw
$starfieldColors = @{}
foreach ($colorNode in @($starfieldPalette.SelectNodes('/venworksCUIPalette/colors/color'))) {
  $starfieldColors[[string]$colorNode.role] = [string]$colorNode.value
}

$layoutSourcePath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Scaleform\shared\fixtures\chronomark-provider-probe.xml") `
  -Description "Production layout source"
$layoutPath = Resolve-RequiredFile `
  -Path (Join-Path $resolvedStagingPath "Interface\VenworksCUI\layout.xml") `
  -Description "Minimalist layout"
$expectedLayoutText = Get-ExpectedMinimalistLayout `
  -SourcePath $layoutSourcePath `
  -ColorValues $starfieldColors
$actualLayoutText = [System.IO.File]::ReadAllText($layoutPath)
if ($actualLayoutText -cne $expectedLayoutText) {
  throw "Minimalist layout differs from the production layout beyond the approved transformation."
}

[xml]$layoutDocument = $actualLayoutText
if ($layoutDocument.venworksCUI.HasAttribute("palette")) {
  throw "Minimalist layout must not select an external palette."
}
$factionIncludes = @($layoutDocument.SelectNodes('/venworksCUI/includes/include[@id="faction-display"]'))
$radarIncludes = @($layoutDocument.SelectNodes('/venworksCUI/includes/include[@id="contact-radar"]'))
if ($factionIncludes.Count -ne 0) {
  throw "Minimalist layout retains the faction display include."
}
if ($radarIncludes.Count -ne 1 -or
    [string]$radarIncludes[0].x -ne "-64" -or
    [string]$radarIncludes[0].y -ne "-36" -or
    [string]$radarIncludes[0].anchor -ne "top-left") {
  throw "Minimalist contact radar is not in the former faction-display position."
}

$layoutSchemaPath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Schemas\VenworksCUI\layout-v1.xsd") `
  -Description "CUI layout schema"
$configurationPaths = @($layoutPath)
foreach ($componentFileName in $componentFileNames) {
  $sourceComponentPath = Resolve-RequiredFile `
    -Path (Join-Path $repositoryRoot "Scaleform\shared\fixtures\components\$componentFileName") `
    -Description "Production component $componentFileName"
  $stagedComponentPath = Resolve-RequiredFile `
    -Path (Join-Path $resolvedStagingPath "Interface\VenworksCUI\components\$componentFileName") `
    -Description "Minimalist component $componentFileName"
  $expectedComponentText = Resolve-PaletteColorReferences `
    -Text ([System.IO.File]::ReadAllText($sourceComponentPath)) `
    -ColorValues $starfieldColors `
    -Context "Expected Minimalist component '$componentFileName'"
  $expectedComponentText = $expectedComponentText.TrimEnd("`r", "`n") + [System.Environment]::NewLine
  $actualComponentText = [System.IO.File]::ReadAllText($stagedComponentPath)
  if ($actualComponentText -cne $expectedComponentText) {
    throw "Minimalist component '$componentFileName' differs beyond Starfield color literalization."
  }
  $configurationPaths += $stagedComponentPath
}

foreach ($configurationPath in $configurationPaths) {
  $schemaErrors = @(Get-XmlSchemaErrors -XmlPath $configurationPath -SchemaPath $layoutSchemaPath)
  if ($schemaErrors.Count -ne 0) {
    throw "Minimalist configuration failed schema validation at $configurationPath`: $($schemaErrors -join '; ')"
  }
  $configurationText = [System.IO.File]::ReadAllText($configurationPath)
  if ($configurationText -match '(?i)<svg\b|\.svg\b|@palette\.|\bpalette="') {
    throw "Minimalist configuration retains SVG or palette content: $configurationPath"
  }
}

$cuiDirectory = Join-Path $resolvedStagingPath "Interface\VenworksCUI"
if (Test-Path -LiteralPath (Join-Path $cuiDirectory "Assets")) {
  throw "Minimalist must not contain an Assets directory."
}
if (Test-Path -LiteralPath (Join-Path $cuiDirectory "palettes")) {
  throw "Minimalist must not contain a palettes directory."
}
if (@(Get-ChildItem -LiteralPath $resolvedStagingPath -Recurse -File -Filter "*.svg").Count -ne 0) {
  throw "Minimalist contains external SVG files."
}
if (@(Get-ChildItem -LiteralPath $resolvedStagingPath -Recurse -File -Filter "*.dds").Count -ne 0) {
  throw "Minimalist contains DDS files."
}

Write-Host -ForegroundColor Green "Minimalist PS5 spike staging and archive validation passed."
