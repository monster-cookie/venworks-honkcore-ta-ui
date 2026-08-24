[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [string]$WorkDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work\ps5-minimalist"),

  [switch]$KeepWork
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Utf8WithoutBom {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text
  )

  [System.IO.File]::WriteAllText(
    $Path,
    $Text,
    [System.Text.UTF8Encoding]::new($false)
  )
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

function Remove-OwnedDirectory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$OwnerPath
  )

  if (!(Test-Path -LiteralPath $Path -PathType Container)) {
    return
  }

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $fullOwnerPath = [System.IO.Path]::GetFullPath($OwnerPath).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $ownedPrefix = $fullOwnerPath + [System.IO.Path]::DirectorySeparatorChar
  if (!$fullPath.StartsWith($ownedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a directory outside the Minimalist CUI payload: $fullPath"
  }

  Remove-Item -LiteralPath $fullPath -Recurse -Force
}

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . "$PSScriptRoot\sharedConfig.ps1"
}

$minimalistVariants = @(Get-ModuleVariants -VariantKey "MIN")
if ($minimalistVariants.Count -ne 1) {
  throw "Expected exactly one Minimalist variant."
}
$minimalistVariant = $minimalistVariants[0]

if (!(Test-Path -LiteralPath $minimalistVariant.StagingFolderPath -PathType Container)) {
  throw "Minimalist staging folder does not exist. Run Tools/setupRepo.ps1 -VariantKey MIN first."
}
$stagingItem = Get-Item -LiteralPath $minimalistVariant.StagingFolderPath
if ($stagingItem.LinkType -ne "Junction") {
  throw "Minimalist staging folder must be a Junction: $($minimalistVariant.StagingFolderPath)"
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

$interfaceOutputDirectory = Join-Path $resolvedStagingPath "Interface"
$compileParameters = @{
  JavaPath = $JavaPath
  JpexsJarPath = $JpexsJarPath
  VanillaInterfacePath = $VanillaInterfacePath
  OutputDirectory = $interfaceOutputDirectory
  WorkDirectory = $WorkDirectory
}
if ($KeepWork) {
  $compileParameters.KeepWork = $true
}

Write-Host -ForegroundColor Green "Compiling Minimalist HUD movies through the PS5 spike entry point"
& (Join-Path $PSScriptRoot "compilePs5MinimalistScaleform.ps1") @compileParameters
& (Join-Path $PSScriptRoot "compileScaleformOverrides.ps1") @compileParameters

$cuiOutputDirectory = Join-Path $interfaceOutputDirectory "VenworksCUI"
$layoutPath = Join-Path $cuiOutputDirectory "layout.xml"
$starfieldPalettePath = Join-Path $PSScriptRoot "..\Scaleform\shared\palettes\starfield.xml"
if (!(Test-Path -LiteralPath $layoutPath -PathType Leaf)) {
  throw "Minimalist layout was not staged: $layoutPath"
}
if (!(Test-Path -LiteralPath $starfieldPalettePath -PathType Leaf)) {
  throw "Starfield palette source does not exist: $starfieldPalettePath"
}

[xml]$starfieldPalette = Get-Content -LiteralPath $starfieldPalettePath -Raw
$starfieldColors = @{}
foreach ($colorNode in @($starfieldPalette.SelectNodes('/venworksCUIPalette/colors/color'))) {
  $role = [string]$colorNode.role
  $value = [string]$colorNode.value
  if ([string]::IsNullOrWhiteSpace($role) -or $value -notmatch '^#[0-9A-Fa-f]{6}$') {
    throw "Starfield palette contains an invalid color entry."
  }
  if ($starfieldColors.ContainsKey($role)) {
    throw "Starfield palette repeats color role '$role'."
  }
  $starfieldColors[$role] = $value
}
if ($starfieldColors.Count -eq 0) {
  throw "Starfield palette does not define any colors."
}

$layoutText = [System.IO.File]::ReadAllText($layoutPath)
[xml]$layoutDocument = $layoutText
$factionIncludes = @($layoutDocument.SelectNodes('/venworksCUI/includes/include[@id="faction-display"]'))
$radarIncludes = @($layoutDocument.SelectNodes('/venworksCUI/includes/include[@id="contact-radar"]'))
if ($factionIncludes.Count -ne 1) {
  throw "Expected exactly one faction-display include before creating the Minimalist layout."
}
if ($radarIncludes.Count -ne 1 -or
    [string]$radarIncludes[0].x -ne "155" -or
    [string]$radarIncludes[0].y -ne "-36" -or
    [string]$radarIncludes[0].anchor -ne "top-left") {
  throw "The production contact radar is not at the expected pre-Minimalist position."
}

$paletteAttributeMatches = @([regex]::Matches($layoutText, '\s+palette="[^"]+"'))
if ($paletteAttributeMatches.Count -ne 1) {
  throw "Expected exactly one palette selector in the staged production layout."
}
$layoutText = [regex]::Replace($layoutText, '\s+palette="[^"]+"', '', 1)

$factionIncludePattern = '(?ms)^[ \t]*<include\b(?=[^>]*\bid="faction-display")[^>]*/>\r?\n'
$factionIncludeMatches = @([regex]::Matches($layoutText, $factionIncludePattern))
if ($factionIncludeMatches.Count -ne 1) {
  throw "Expected exactly one removable faction-display include in the staged layout."
}
$layoutText = [regex]::Replace($layoutText, $factionIncludePattern, '', 1)

$radarPositionPattern = '(<include\b(?=[^>]*\bid="contact-radar")[^>]*\bx=")155("[^>]*/>)'
$radarPositionMatches = @([regex]::Matches($layoutText, $radarPositionPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline))
if ($radarPositionMatches.Count -ne 1) {
  throw "Expected exactly one contact-radar x coordinate to move in the staged layout."
}
$layoutText = [regex]::Replace(
  $layoutText,
  $radarPositionPattern,
  { param($match) $match.Groups[1].Value + '-64' + $match.Groups[2].Value },
  [System.Text.RegularExpressions.RegexOptions]::Singleline
)
$layoutText = Resolve-PaletteColorReferences `
  -Text $layoutText `
  -ColorValues $starfieldColors `
  -Context "Minimalist layout"
Write-Utf8WithoutBom -Path $layoutPath -Text $layoutText

$componentOutputDirectory = Join-Path $cuiOutputDirectory "components"
$factionComponentPath = Join-Path $componentOutputDirectory "faction-display.xml"
if (!(Test-Path -LiteralPath $factionComponentPath -PathType Leaf)) {
  throw "Faction display component was not staged before Minimalist cleanup."
}
Remove-Item -LiteralPath $factionComponentPath -Force

$expectedComponentFileNames = @(
  "contact-radar.xml",
  "equipment-rail.xml",
  "environmental-hazard-scanner.xml",
  "helmet-awareness.xml",
  "player-status-scanner.xml",
  "quest-tracker.xml",
  "scanner-overlay.xml"
)
$componentFiles = @(Get-ChildItem -LiteralPath $componentOutputDirectory -File -Filter "*.xml")
if ($componentFiles.Count -ne $expectedComponentFileNames.Count) {
  throw "Minimalist must retain exactly seven production component fragments."
}
foreach ($componentFileName in $expectedComponentFileNames) {
  $componentPath = Join-Path $componentOutputDirectory $componentFileName
  if (!(Test-Path -LiteralPath $componentPath -PathType Leaf)) {
    throw "Minimalist is missing component fragment '$componentFileName'."
  }
  $componentText = [System.IO.File]::ReadAllText($componentPath)
  $componentText = Resolve-PaletteColorReferences `
    -Text $componentText `
    -ColorValues $starfieldColors `
    -Context "Minimalist component '$componentFileName'"
  $componentText = $componentText.TrimEnd("`r", "`n") + [System.Environment]::NewLine
  Write-Utf8WithoutBom -Path $componentPath -Text $componentText
}

Remove-OwnedDirectory -Path (Join-Path $cuiOutputDirectory "Assets") -OwnerPath $cuiOutputDirectory
Remove-OwnedDirectory -Path (Join-Path $cuiOutputDirectory "palettes") -OwnerPath $cuiOutputDirectory

$minimalistConfigurationFiles = @(
  Get-ChildItem -LiteralPath $cuiOutputDirectory -Recurse -File -Filter "*.xml"
)
foreach ($configurationFile in $minimalistConfigurationFiles) {
  $configurationText = [System.IO.File]::ReadAllText($configurationFile.FullName)
  if ($configurationText -match '(?i)<svg\b|\.svg\b|@palette\.|\bpalette="') {
    throw "Minimalist configuration retains SVG or palette content: $($configurationFile.FullName)"
  }
}
if (@(Get-ChildItem -LiteralPath $interfaceOutputDirectory -Recurse -File -Filter "*.svg").Count -ne 0) {
  throw "Minimalist staging retains external SVG files."
}
if (@(Get-ChildItem -LiteralPath $interfaceOutputDirectory -Recurse -File -Filter "*.dds").Count -ne 0) {
  throw "Minimalist staging unexpectedly contains DDS files."
}

$sourcePluginPath = Join-Path $PSScriptRoot "..\Staging-TA\Venworks-CustomizableHUD-TrackersAlliance.esm"
$minimalistPluginPath = Join-Path $resolvedStagingPath "$($minimalistVariant.PackageBaseName).esm"
if (!(Test-Path -LiteralPath $sourcePluginPath -PathType Leaf)) {
  throw "Trackers Alliance stub ESM source does not exist: $sourcePluginPath"
}
Copy-Item -LiteralPath $sourcePluginPath -Destination $minimalistPluginPath -Force
$sourcePluginHash = (Get-FileHash -LiteralPath $sourcePluginPath -Algorithm SHA256).Hash
$minimalistPluginHash = (Get-FileHash -LiteralPath $minimalistPluginPath -Algorithm SHA256).Hash
if ($minimalistPluginHash -ne $sourcePluginHash) {
  throw "Minimalist stub ESM is not byte-identical to the release stub."
}

Write-Host -ForegroundColor Green "Minimalist PS5 staging configuration created without external SVG or palette files."
