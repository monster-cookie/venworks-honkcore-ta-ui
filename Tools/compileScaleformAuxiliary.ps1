[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory,

  [string]$FlexSdkPath = (Join-Path $PSScriptRoot '..\.work\tools\flex'),

  [string]$PlayerGlobalPath,

  [string]$BuildManifestPath = (Join-Path $PSScriptRoot '..\Scaleform\venworkscui\build.xml'),

  [string]$WorkDirectory = (Join-Path $PSScriptRoot '..\Scaleform\.work'),

  [switch]$MarkerProbe,

  [switch]$UpdateExpectedHashes,

  [switch]$KeepWork
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'sharedScaleformMovies.ps1')
. (Join-Path $PSScriptRoot 'sharedScaleformProfiles.ps1')

function Resolve-RequiredFile {
  param([string]$Path, [string]$Description)
  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
  if ($null -eq $resolved -or !(Test-Path -LiteralPath $resolved.Path -PathType Leaf)) {
    throw "$Description does not exist: $Path"
  }
  return $resolved.Path
}

function Resolve-RequiredDirectory {
  param([string]$Path, [string]$Description)
  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
  if ($null -eq $resolved -or !(Test-Path -LiteralPath $resolved.Path -PathType Container)) {
    throw "$Description does not exist: $Path"
  }
  return $resolved.Path
}

function Write-Utf8WithoutBom {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text
  )

  $canonicalText = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
  [System.IO.File]::WriteAllText($Path, $canonicalText, [System.Text.UTF8Encoding]::new($false))
}

function Read-Sha256File {
  param([string]$Path)
  $value = [System.IO.File]::ReadAllText($Path).Trim()
  if ($value -notmatch '^[0-9A-Fa-f]{64}$') {
    throw "Invalid SHA-256 file: $Path"
  }
  return $value.ToUpperInvariant()
}

function Write-Sha256File {
  param([string]$Path, [string]$Hash)
  Write-Utf8WithoutBom -Path $Path -Text ($Hash.ToUpperInvariant() + "`n")
}

function Invoke-JavaJar {
  param(
    [Parameter(Mandatory = $true)]
    [string]$JarPath,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  & $script:ResolvedJavaPath -jar $JarPath @Arguments
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "$Description failed with exit code $exitCode."
  }
}

function Normalize-AuxiliaryMovie {
  param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$WorkPath
  )

  $rawXmlPath = Join-Path $WorkPath 'compiled.xml'
  $normalizedXmlPath = Join-Path $WorkPath 'normalized.xml'
  Invoke-JavaJar `
    -JarPath $script:ResolvedJpexsJarPath `
    -Arguments @('-swf2xml', $InputPath, $rawXmlPath) `
    -Description 'JPEXS auxiliary movie XML export'

  [xml]$movie = Get-Content -LiteralPath $rawXmlPath -Raw
  $tagsNode = $movie.SelectSingleNode('/swf/tags')
  if ($null -eq $tagsNode) {
    throw 'Generated auxiliary movie does not contain a root tag collection.'
  }
  foreach ($tag in @($movie.SelectNodes('/swf/tags/item[@type="MetadataTag" or @type="ProductInfoTag"]'))) {
    [void]$tagsNode.RemoveChild($tag)
  }
  $fileAttributes = $movie.SelectSingleNode('/swf/tags/item[@type="FileAttributesTag"]')
  if ($null -ne $fileAttributes) {
    $fileAttributes.SetAttribute('hasMetadata', 'false')
  }

  $settings = [System.Xml.XmlWriterSettings]::new()
  $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
  $settings.Indent = $true
  $settings.NewLineChars = "`n"
  $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
  $writer = [System.Xml.XmlWriter]::Create($normalizedXmlPath, $settings)
  try {
    $movie.Save($writer)
  }
  finally {
    $writer.Dispose()
  }

  Invoke-JavaJar `
    -JarPath $script:ResolvedJpexsJarPath `
    -Arguments @('-xml2swf', $normalizedXmlPath, $OutputPath) `
    -Description 'JPEXS normalized auxiliary movie rebuild'
}

function Copy-ProfiledActionScript {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,

    [Parameter(Mandatory = $true)]
    [pscustomobject]$SourceProfile
  )

  $sourceFiles = @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Filter '*.as')
  foreach ($sourceFile in $sourceFiles) {
    $relativePath = $sourceFile.FullName.Substring($SourceRoot.Length + 1)
    $normalizedRelativePath = $relativePath.Replace(
      [System.IO.Path]::AltDirectorySeparatorChar,
      [System.IO.Path]::DirectorySeparatorChar
    )
    if ($normalizedRelativePath -in $SourceProfile.ExcludedActionScriptPaths) {
      continue
    }

    $profileSourcePath = Get-ScaleformProfileActionScriptPath `
      -SourceProfile $SourceProfile `
      -SourcePath $sourceFile.FullName `
      -RelativePath $normalizedRelativePath
    $sourceText = if ($null -ne $SourceProfile.ActionScriptPatchPath) {
      Get-ScaleformPatchedActionScript `
        -SourcePath $profileSourcePath `
        -RelativePath $normalizedRelativePath `
        -PatchPath $SourceProfile.ActionScriptPatchPath
    }
    else {
      [System.IO.File]::ReadAllText($profileSourcePath)
    }

    $destinationPath = Join-Path $DestinationRoot $normalizedRelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationPath) | Out-Null
    Write-Utf8WithoutBom -Path $destinationPath -Text $sourceText
  }
}

function Assert-ProviderInventory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [pscustomobject]$SourceProfile
  )

  $valueSource = [System.IO.File]::ReadAllText((Join-Path $SourceRoot 'venworks\cui\CUIPlayerHudDataContext.as'))
  $conditionSource = [System.IO.File]::ReadAllText((Join-Path $SourceRoot 'venworks\cui\CUIConditionContext.as'))
  $valueProviders = @([regex]::Matches($valueSource, 'subscribeProvider\("([^"]+)"') | ForEach-Object {
    [string]$_.Groups[1].Value
  })
  $conditionProviders = @([regex]::Matches($conditionSource, 'subscribeProvider\("([^"]+)"') | ForEach-Object {
    [string]$_.Groups[1].Value
  })
  $expectedValueProviders = @($SourceProfile.ValueProviders | ForEach-Object { [string]$_ })
  $expectedConditionProviders = @($SourceProfile.ConditionProviders | ForEach-Object { [string]$_ })
  if ([string]::Join("`n", $valueProviders) -cne [string]::Join("`n", $expectedValueProviders)) {
    throw "Auxiliary profile '$($SourceProfile.Name)' value-provider inventory does not match its manifest contract."
  }
  if ([string]::Join("`n", $conditionProviders) -cne [string]::Join("`n", $expectedConditionProviders)) {
    throw "Auxiliary profile '$($SourceProfile.Name)' condition-provider inventory does not match its manifest contract."
  }
  $crossContextCount = @($valueProviders | Where-Object { $_ -in $conditionProviders } | Select-Object -Unique).Count
  if ($crossContextCount -ne $SourceProfile.CrossContextProviderCount) {
    throw "Auxiliary profile '$($SourceProfile.Name)' has $crossContextCount cross-context providers; expected $($SourceProfile.CrossContextProviderCount)."
  }
}

function Get-AuxiliaryClassInventory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptsDirectory
  )

  $definitions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  foreach ($scriptFile in @(Get-ChildItem -LiteralPath $ScriptsDirectory -Recurse -File -Filter '*.as')) {
    $source = [System.IO.File]::ReadAllText($scriptFile.FullName)
    $packageMatch = [regex]::Match(
      $source,
      '(?m)^\s*package(?:\s+([A-Za-z_][A-Za-z0-9_.]*))?\s*$'
    )
    $packageName = if ($packageMatch.Success) { [string]$packageMatch.Groups[1].Value } else { '' }
    foreach ($definitionMatch in [regex]::Matches(
      $source,
      '(?m)^\s*(?:(?:public|internal|final|dynamic)\s+)*(?:class|interface)\s+([A-Za-z_][A-Za-z0-9_]*)\b'
    )) {
      $definitionName = [string]$definitionMatch.Groups[1].Value
      $qualifiedName = if ([string]::IsNullOrEmpty($packageName)) {
        $definitionName
      }
      else {
        "$packageName.$definitionName"
      }
      if (!$definitions.Add($qualifiedName)) {
        throw "Auxiliary movie exports duplicate definition '$qualifiedName'."
      }
    }
  }

  [string[]]$inventory = @($definitions)
  [System.Array]::Sort($inventory, [System.StringComparer]::Ordinal)
  if ($inventory.Count -eq 0) {
    throw 'Auxiliary movie did not export any ActionScript definitions.'
  }
  return $inventory
}

function Invoke-AuxiliaryCompilation {
  param(
    [Parameter(Mandatory = $true)]
    [string]$EntrypointPath,

    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [int]$StageWidth,

    [Parameter(Mandatory = $true)]
    [int]$StageHeight,

    [Parameter(Mandatory = $true)]
    [int]$FrameRate,

    [string]$ExternSwcPath
  )

  $compilerArguments = @(
    "-load-config=$flexConfigPath",
    '-compiler.library-path=',
    "-compiler.external-library-path=$resolvedPlayerGlobalPath",
    '-compiler.source-path', $SourceRoot,
    '-compiler.debug=false',
    '-compiler.optimize=true',
    '-compiler.compress=true',
    '-compiler.omit-trace-statements=true',
    '-use-network=false',
    '-target-player=11.1.0',
    '-swf-version=12',
    '-default-size', $StageWidth, $StageHeight,
    "-default-frame-rate=$FrameRate",
    '-output', $OutputPath,
    $EntrypointPath
  )
  if (![string]::IsNullOrWhiteSpace($ExternSwcPath)) {
    $compilerArguments = @($compilerArguments[0..2]) +
      @("-compiler.external-library-path+=$ExternSwcPath") +
      @($compilerArguments[3..($compilerArguments.Count - 1)])
  }

  Push-Location (Join-Path $resolvedFlexSdkPath 'frameworks')
  try {
    Invoke-JavaJar -JarPath $mxmlcJarPath -Arguments $compilerArguments -Description 'Apache Flex CUI compilation'
  }
  finally {
    Pop-Location
  }
}

function Assert-AuxiliaryMovie {
  param(
    [Parameter(Mandatory = $true)]
    [string]$MoviePath,

    [Parameter(Mandatory = $true)]
    [string]$WorkPath,

    [pscustomobject]$SourceProfile,

    [Parameter(Mandatory = $true)]
    [ValidateSet('runtime-bridge', 'diagnostic-bridge')]
    [string]$Contract,

    [Parameter(Mandatory = $true)]
    [string]$PassName,

    [Parameter(Mandatory = $true)]
    [int]$ExpectedStageWidth,

    [Parameter(Mandatory = $true)]
    [int]$ExpectedStageHeight,

    [Parameter(Mandatory = $true)]
    [int]$ExpectedFrameRate,

    [string]$ExpectedSourceFingerprint,

    [string]$ExpectedClassFingerprint,

    [switch]$Marker
  )

  $movieMetadata = Get-ScaleformMovieMetadata `
    -Path $MoviePath `
    -Context 'Generated auxiliary movie' `
    -ExpectedSignature CWS
  if ($movieMetadata.StageWidth -ne $ExpectedStageWidth -or
      $movieMetadata.StageHeight -ne $ExpectedStageHeight -or
      $movieMetadata.FrameRate -ne $ExpectedFrameRate -or
      $movieMetadata.FrameCount -ne 1) {
    throw "Auxiliary movie must be $($ExpectedStageWidth)x$($ExpectedStageHeight) at $($ExpectedFrameRate) fps with one frame; found $($movieMetadata.StageWidth)x$($movieMetadata.StageHeight) at $($movieMetadata.FrameRate) fps with $($movieMetadata.FrameCount) frames."
  }
  $reopenedXmlPath = Join-Path $WorkPath "$PassName-reopened.xml"
  $validationScriptsDirectory = Join-Path $WorkPath "$PassName-validation-scripts"
  Invoke-JavaJar `
    -JarPath $script:ResolvedJpexsJarPath `
    -Arguments @('-swf2xml', $MoviePath, $reopenedXmlPath) `
    -Description 'JPEXS auxiliary movie reopen' |
      Out-Host
  Invoke-JavaJar `
    -JarPath $script:ResolvedJpexsJarPath `
    -Arguments @('-format', 'script:as', '-export', 'script', $validationScriptsDirectory, $MoviePath) `
    -Description 'JPEXS auxiliary ActionScript export' |
      Out-Host

  [xml]$reopened = Get-Content -LiteralPath $reopenedXmlPath -Raw
  $abcTags = @($reopened.SelectNodes('/swf/tags/item[@type="DoABC2Tag" or @type="DoABCTag"]'))
  if ($abcTags.Count -ne 1) {
    throw "Auxiliary movie must contain exactly one ABC; found $($abcTags.Count)."
  }
  $validationSource = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter '*.as' | ForEach-Object {
    [System.IO.File]::ReadAllText($_.FullName)
  }) -join "`n"
  $classInventory = @(Get-AuxiliaryClassInventory -ScriptsDirectory $validationScriptsDirectory)
  foreach ($className in $classInventory) {
    if ($className.StartsWith('Shared.', [System.StringComparison]::Ordinal) -or
        $className -ceq 'scaleform.gfx.Extensions') {
      throw "Auxiliary movie embeds compile-only host class '$className'."
    }
  }
  $classFingerprint = Get-ScaleformAuxiliaryTextSha256 -Text ([string]::Join("`n", $classInventory) + "`n")
  foreach ($requiredToken in @(
    'public function initialize',
    'public function reapplyVanillaPlacements',
    'public function updateVanillaHudModeVisibility',
    'public function dispose'
  )) {
    if (!$validationSource.Contains($requiredToken)) {
      throw "Auxiliary movie is missing '$requiredToken'."
    }
  }
  if ($validationSource -match '(?m)^\s*(?:public\s+)?(?:final\s+)?class\s+(?:BSUIDataManager|FromClientDataEvent|CustomEvent|ButtonKeyHelper|SymbolLoaderClip|MapMarkerUtils|Extensions)\b') {
    throw 'Auxiliary movie embeds a compile-only host class.'
  }

  if ($Marker) {
    if (!$validationSource.Contains('VENWORKS AUX LOADED')) {
      throw 'Marker auxiliary movie is missing its acceptance text.'
    }
    return [pscustomobject]@{
      ClassFingerprint = $classFingerprint
      ClassInventory = $classInventory
      ValidationSource = $validationSource
    }
  }
  if ($Contract -ceq 'diagnostic-bridge') {
    if ([string]::Join("`n", $classInventory) -cne 'VenworksCUIDiagnosticEntrypoint') {
      throw "Diagnostic auxiliary movie has an unexpected class inventory: $([string]::Join(', ', $classInventory))."
    }
    foreach ($requiredToken in @(
      'VenworksCUIDiagnosticEntrypoint',
      'venworkscui.swf loaded',
      'Shared.AS3.Data.BSUIDataManager',
      'getDefinitionByName',
      'PlayerData',
      'GetDataFromClient',
      'Subscribe',
      'Unsubscribe',
      'sName',
      'PS5DBG-05 PLAYERDATA NEXT FRAME',
      'PS5DBG-06 PLAYERDATA REQUEST',
      'PS5DBG-07 PLAYERDATA WAITING',
      'PS5DBG-08 XML LOAD NEXT FRAME',
      'PS5DBG-09 XML LOAD RETURNED',
      'PS5DBG-10 XML RECEIVED',
      'PS5DBG-11 XML PARSE NEXT FRAME',
      'PS5DBG-OK PLAYERDATA',
      'PS5DBG-ERR PLAYERDATA',
      'PS5DBG-OK XML',
      'PS5DBG-ERR XML REQUEST',
      'PS5DBG-ERR XML IO',
      'PS5DBG-ERR XML SECURITY',
      'PS5DBG-ERR XML PARSE',
      'PS5DBG-ERR XML VALUE',
      'PLAYERDATA:',
      'XML:',
      'URLRequest',
      'URLLoader',
      'VenworksCUI/layout.xml',
      'diagnosticText',
      '$MAIN_Font_Bold',
      'embedFonts',
      'defaultTextFormat',
      'setTextFormat'
    )) {
      if (!$validationSource.Contains($requiredToken)) {
        throw "Diagnostic auxiliary movie is missing '$requiredToken'."
      }
    }
    foreach ($forbiddenToken in @(
      'CUIRuntime',
      'CUILayoutImportLoader',
      'CUIPlayerHudDataContext',
      'CUIConditionContext',
      'XMLList',
      'elements'
    )) {
      if ($validationSource.Contains($forbiddenToken)) {
        throw "Diagnostic auxiliary movie contains forbidden runtime token '$forbiddenToken'."
      }
    }
    if (![string]::IsNullOrWhiteSpace($ExpectedClassFingerprint) -and
        !$validationSource.Contains("VENWORKS_CUI_CLASSES_SHA256:$ExpectedClassFingerprint")) {
      throw 'Diagnostic auxiliary movie does not embed its compiled class fingerprint.'
    }
    return [pscustomobject]@{
      ClassFingerprint = $classFingerprint
      ClassInventory = $classInventory
      ValidationSource = $validationSource
    }
  }
  if ($null -eq $SourceProfile) {
    throw 'Runtime auxiliary validation requires a source profile.'
  }
  if ($validationSource.Contains('VENWORKS AUX LOADED')) {
    throw 'Production auxiliary movie retains the marker-probe payload.'
  }
  $requiredSwfComponentTokens = @(
    'CUISwfComponentLibrary',
    'CUISwfPlayerDataPanelDefinition',
    'CUISwfPlanetDataPanelDefinition',
    'CUISwfEquipmentRailDefinition',
    'CUISwfFactionIconDefinition',
    'CUISwfCompassDefinition',
    'CUISwfQuestTrackerDefinition',
    'CUISwfThreatMeterDefinition',
    'CUISwfRadarDefinition',
    'CUISwfStatusEffectScreenDefinition',
    'CUISwfScannerHashPanelDefinition',
    'CUISwfScannerDataPanelDefinition'
  )
  foreach ($requiredToken in @('CUIRuntime', 'CUILayoutImportLoader', 'CUIPlayerHudDataContext', 'CUIConditionContext') +
      $requiredSwfComponentTokens + @($SourceProfile.RequiredBytecodeTokens)) {
    if (!$validationSource.Contains([string]$requiredToken)) {
      throw "Auxiliary profile '$($SourceProfile.Name)' is missing required bytecode token '$requiredToken'."
    }
  }
  foreach ($forbiddenToken in @($SourceProfile.ForbiddenBytecodeTokens)) {
    if ($validationSource.Contains([string]$forbiddenToken)) {
      throw "Auxiliary profile '$($SourceProfile.Name)' contains forbidden bytecode token '$forbiddenToken'."
    }
  }
  foreach ($providerName in @($SourceProfile.ValueProviders) + @($SourceProfile.ConditionProviders)) {
    if (!$validationSource.Contains([string]$providerName)) {
      throw "Auxiliary profile '$($SourceProfile.Name)' is missing provider '$providerName'."
    }
  }
  if (![string]::IsNullOrWhiteSpace($ExpectedSourceFingerprint) -and
      !$validationSource.Contains("VENWORKS_CUI_SOURCE_SHA256:$ExpectedSourceFingerprint")) {
    throw "Auxiliary profile '$($SourceProfile.Name)' does not embed its current source fingerprint."
  }
  if (![string]::IsNullOrWhiteSpace($ExpectedClassFingerprint) -and
      !$validationSource.Contains("VENWORKS_CUI_CLASSES_SHA256:$ExpectedClassFingerprint")) {
    throw "Auxiliary profile '$($SourceProfile.Name)' does not embed its compiled class fingerprint."
  }

  return [pscustomobject]@{
    ClassFingerprint = $classFingerprint
    ClassInventory = $classInventory
    ValidationSource = $validationSource
  }
}

if ($MarkerProbe -and $UpdateExpectedHashes) {
  throw 'The marker probe cannot update production expected hashes.'
}

$script:ResolvedJavaPath = Resolve-RequiredFile -Path $JavaPath -Description 'Java executable'
$script:ResolvedJpexsJarPath = Resolve-RequiredFile -Path $JpexsJarPath -Description 'JPEXS JAR'
$resolvedFlexSdkPath = Resolve-RequiredDirectory -Path $FlexSdkPath -Description 'Apache Flex SDK directory'
$resolvedBuildManifestPath = Resolve-RequiredFile -Path $BuildManifestPath -Description 'Auxiliary build manifest'
$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
$mxmlcJarPath = Resolve-RequiredFile -Path (Join-Path $resolvedFlexSdkPath 'lib\mxmlc.jar') -Description 'Apache Flex mxmlc compiler'
$compcJarPath = Resolve-RequiredFile -Path (Join-Path $resolvedFlexSdkPath 'lib\compc.jar') -Description 'Apache Flex compc compiler'
$flexConfigPath = Resolve-RequiredFile -Path (Join-Path $resolvedFlexSdkPath 'frameworks\flex-config.xml') -Description 'Apache Flex compiler configuration'

if ([string]::IsNullOrWhiteSpace($PlayerGlobalPath)) {
  $playerGlobalMatches = @(Get-ChildItem -LiteralPath (Join-Path $resolvedFlexSdkPath 'frameworks') -Recurse -File -Filter 'playerglobal.swc')
  if ($playerGlobalMatches.Count -ne 1) {
    throw "Expected exactly one playerglobal.swc in the Apache Flex SDK; found $($playerGlobalMatches.Count)."
  }
  $PlayerGlobalPath = $playerGlobalMatches[0].FullName
}
$resolvedPlayerGlobalPath = Resolve-RequiredFile -Path $PlayerGlobalPath -Description 'playerglobal.swc'

[xml]$manifest = Get-Content -LiteralPath $resolvedBuildManifestPath -Raw
$build = $manifest.scaleformAuxiliaryBuild
if (!$build -or !$build.outputFile -or !$build.documentClass -or !$build.expectedHashFile -or
    !$build.expectedClassHashFile -or !$build.stageWidth -or !$build.stageHeight -or
    !$build.frameRate) {
  throw "Invalid auxiliary build manifest: $resolvedBuildManifestPath"
}
$auxiliaryDefinition = Get-ScaleformAuxiliaryManifestDefinition -ManifestPath $resolvedBuildManifestPath
$contract = [string]$auxiliaryDefinition.Contract
if ($MarkerProbe -and $contract -cne 'runtime-bridge') {
  throw 'The marker probe requires a runtime-bridge auxiliary manifest.'
}
$stageWidth = [int]$auxiliaryDefinition.StageWidth
$stageHeight = [int]$auxiliaryDefinition.StageHeight
$frameRate = [int]$auxiliaryDefinition.FrameRate
$manifestDirectory = Split-Path -Parent $resolvedBuildManifestPath
$entrypointPath = Resolve-RequiredFile `
  -Path (Join-Path $manifestDirectory ([string]$build.documentClass)) `
  -Description 'Auxiliary entrypoint'
$expectedHashPath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory ([string]$build.expectedHashFile)))
$expectedClassHashPath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory ([string]$build.expectedClassHashFile)))
$sourceProfile = if ($contract -ceq 'runtime-bridge') {
  Get-ScaleformSourceProfileFromAuxiliaryManifest -ManifestPath $resolvedBuildManifestPath
}
else {
  $null
}

New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory, $resolvedWorkDirectory | Out-Null
$buildWorkDirectory = Join-Path $resolvedWorkDirectory ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $buildWorkDirectory | Out-Null
$sourceRoot = Join-Path $buildWorkDirectory 'source'
$externRoot = Join-Path $buildWorkDirectory 'externs'
$firstCompiledSwfPath = Join-Path $buildWorkDirectory 'first-compiled.swf'
$firstNormalizedSwfPath = Join-Path $buildWorkDirectory 'first-pass.swf'
$compiledSwfPath = Join-Path $buildWorkDirectory 'final-compiled.swf'
$normalizedSwfPath = Join-Path $buildWorkDirectory ([string]$build.outputFile)
$externSwcPath = Join-Path $buildWorkDirectory 'host-externs.swc'

try {
  New-Item -ItemType Directory -Force -Path $sourceRoot | Out-Null
  if ($MarkerProbe) {
    $markerSource = @'
package
{
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.text.TextField;
   import flash.text.TextFormat;

   public final class VenworksCUIEntrypoint extends MovieClip
   {
      private var owner:DisplayObjectContainer;
      private var marker:TextField;

      public function initialize(param1:DisplayObjectContainer) : void
      {
         var format:TextFormat = new TextFormat("$MAIN_Font_Bold",18,0xFFFFFF,true);
         this.dispose();
         this.owner = param1;
         if(this.owner == null)
         {
            return;
         }
         this.marker = new TextField();
         this.marker.x = 760;
         this.marker.y = 180;
         this.marker.width = 400;
         this.marker.height = 48;
         this.marker.background = true;
         this.marker.backgroundColor = 0x282828;
         this.marker.border = true;
         this.marker.borderColor = 0x00FFFF;
         this.marker.textColor = 0xFFFFFF;
         this.marker.embedFonts = true;
         this.marker.defaultTextFormat = format;
         this.marker.text = "VENWORKS AUX LOADED";
         this.marker.setTextFormat(format);
         this.owner.addChild(this.marker);
      }

      public function reapplyVanillaPlacements() : void
      {
      }

      public function updateVanillaHudModeVisibility(param1:Array) : void
      {
      }

      public function dispose() : void
      {
         if(this.marker != null && this.marker.parent != null)
         {
            this.marker.parent.removeChild(this.marker);
         }
         this.marker = null;
         this.owner = null;
      }
   }
}
'@
    $compilerEntrypointPath = Join-Path $sourceRoot 'VenworksCUIEntrypoint.as'
    Write-Utf8WithoutBom -Path $compilerEntrypointPath -Text $markerSource
  }
  elseif ($contract -ceq 'diagnostic-bridge') {
    $compilerEntrypointPath = Join-Path $sourceRoot ([System.IO.Path]::GetFileName($entrypointPath))
    Copy-Item -LiteralPath $entrypointPath -Destination $compilerEntrypointPath
  }
  else {
    $actionScriptSourcePath = Resolve-RequiredDirectory `
      -Path (Join-Path $manifestDirectory ([string]$build.actionScriptSource)) `
      -Description 'Authored CUI ActionScript source directory'
    Copy-ProfiledActionScript `
      -SourceRoot $actionScriptSourcePath `
      -DestinationRoot $sourceRoot `
      -SourceProfile $sourceProfile
    Assert-ProviderInventory -SourceRoot $sourceRoot -SourceProfile $sourceProfile
    $compilerEntrypointPath = Join-Path $sourceRoot 'VenworksCUIEntrypoint.as'
    Copy-Item -LiteralPath $entrypointPath -Destination $compilerEntrypointPath

    $externSourcePath = Resolve-RequiredDirectory `
      -Path (Join-Path $manifestDirectory ([string]$build.externSource)) `
      -Description 'Compile-only host extern source directory'
    Copy-Item -LiteralPath $externSourcePath -Destination $externRoot -Recurse
    $scaleformExternPath = Join-Path $externRoot 'scaleform\gfx\Extensions.as'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $scaleformExternPath) | Out-Null
    Write-Utf8WithoutBom -Path $scaleformExternPath -Text (Get-ScaleformAuxiliaryExtensionsExternSource)

    $compcArguments = @(
      "-load-config=$flexConfigPath",
      '-compiler.library-path=',
      '-compiler.external-library-path', $resolvedPlayerGlobalPath,
      '-compiler.source-path', $externRoot,
      '-include-sources', $externRoot,
      '-compiler.debug=false',
      '-output', $externSwcPath
    )
    Push-Location (Join-Path $resolvedFlexSdkPath 'frameworks')
    try {
      Invoke-JavaJar -JarPath $compcJarPath -Arguments $compcArguments -Description 'Apache Flex host extern compilation'
    }
    finally {
      Pop-Location
    }
  }

  if ($MarkerProbe) {
    Invoke-AuxiliaryCompilation `
      -EntrypointPath $compilerEntrypointPath `
      -SourceRoot $sourceRoot `
      -OutputPath $compiledSwfPath `
      -StageWidth $stageWidth `
      -StageHeight $stageHeight `
      -FrameRate $frameRate
    Normalize-AuxiliaryMovie `
      -InputPath $compiledSwfPath `
      -OutputPath $normalizedSwfPath `
      -WorkPath $buildWorkDirectory
    $markerInspection = Assert-AuxiliaryMovie `
      -MoviePath $normalizedSwfPath `
      -WorkPath $buildWorkDirectory `
      -SourceProfile $sourceProfile `
      -Contract $contract `
      -PassName 'marker' `
      -ExpectedStageWidth $stageWidth `
      -ExpectedStageHeight $stageHeight `
      -ExpectedFrameRate $frameRate `
      -Marker
    if (!$markerInspection.ValidationSource.Contains('$MAIN_Font_Bold') -or
        !$markerInspection.ValidationSource.Contains('embedFonts') -or
        !$markerInspection.ValidationSource.Contains('defaultTextFormat') -or
        !$markerInspection.ValidationSource.Contains('setTextFormat')) {
      throw 'Marker auxiliary movie does not apply the required Starfield font format.'
    }
  }
  elseif ($contract -ceq 'diagnostic-bridge') {
    Invoke-AuxiliaryCompilation `
      -EntrypointPath $compilerEntrypointPath `
      -SourceRoot $sourceRoot `
      -OutputPath $firstCompiledSwfPath `
      -StageWidth $stageWidth `
      -StageHeight $stageHeight `
      -FrameRate $frameRate
    Normalize-AuxiliaryMovie `
      -InputPath $firstCompiledSwfPath `
      -OutputPath $firstNormalizedSwfPath `
      -WorkPath $buildWorkDirectory
    $firstDiagnosticInspection = Assert-AuxiliaryMovie `
      -MoviePath $firstNormalizedSwfPath `
      -WorkPath $buildWorkDirectory `
      -Contract $contract `
      -PassName 'diagnostic-first' `
      -ExpectedStageWidth $stageWidth `
      -ExpectedStageHeight $stageHeight `
      -ExpectedFrameRate $frameRate
    $classFingerprint = [string]$firstDiagnosticInspection.ClassFingerprint
    if ($UpdateExpectedHashes) {
      Write-Sha256File -Path $expectedClassHashPath -Hash $classFingerprint
    }
    else {
      $resolvedExpectedClassHashPath = Resolve-RequiredFile `
        -Path $expectedClassHashPath `
        -Description 'Diagnostic auxiliary expected class hash file'
      $expectedClassHash = Read-Sha256File -Path $resolvedExpectedClassHashPath
      if ($classFingerprint -cne $expectedClassHash) {
        throw "Diagnostic auxiliary class inventory hash mismatch. Expected $expectedClassHash; found $classFingerprint."
      }
    }

    $entrypointSource = [System.IO.File]::ReadAllText($compilerEntrypointPath)
    $classPlaceholder = Get-ScaleformAuxiliaryFingerprintPlaceholder -Kind Classes
    if (!$entrypointSource.Contains($classPlaceholder)) {
      throw 'Diagnostic auxiliary entrypoint does not contain its class fingerprint placeholder.'
    }
    $entrypointSource = $entrypointSource.Replace(
      $classPlaceholder,
      "VENWORKS_CUI_CLASSES_SHA256:$classFingerprint"
    )
    Write-Utf8WithoutBom -Path $compilerEntrypointPath -Text $entrypointSource

    Invoke-AuxiliaryCompilation `
      -EntrypointPath $compilerEntrypointPath `
      -SourceRoot $sourceRoot `
      -OutputPath $compiledSwfPath `
      -StageWidth $stageWidth `
      -StageHeight $stageHeight `
      -FrameRate $frameRate
    Normalize-AuxiliaryMovie `
      -InputPath $compiledSwfPath `
      -OutputPath $normalizedSwfPath `
      -WorkPath $buildWorkDirectory
    $finalDiagnosticInspection = Assert-AuxiliaryMovie `
      -MoviePath $normalizedSwfPath `
      -WorkPath $buildWorkDirectory `
      -Contract $contract `
      -PassName 'diagnostic-final' `
      -ExpectedStageWidth $stageWidth `
      -ExpectedStageHeight $stageHeight `
      -ExpectedFrameRate $frameRate `
      -ExpectedClassFingerprint $classFingerprint
    if ([string]$finalDiagnosticInspection.ClassFingerprint -cne $classFingerprint) {
      throw 'Embedding the diagnostic class fingerprint changed the compiled class inventory.'
    }
  }
  else {
    $sourceFingerprint = Get-ScaleformAuxiliarySourceFingerprint -ManifestPath $resolvedBuildManifestPath
    Invoke-AuxiliaryCompilation `
      -EntrypointPath $compilerEntrypointPath `
      -SourceRoot $sourceRoot `
      -OutputPath $firstCompiledSwfPath `
      -StageWidth $stageWidth `
      -StageHeight $stageHeight `
      -FrameRate $frameRate `
      -ExternSwcPath $externSwcPath
    Normalize-AuxiliaryMovie `
      -InputPath $firstCompiledSwfPath `
      -OutputPath $firstNormalizedSwfPath `
      -WorkPath $buildWorkDirectory
    $firstInspection = Assert-AuxiliaryMovie `
      -MoviePath $firstNormalizedSwfPath `
      -WorkPath $buildWorkDirectory `
      -SourceProfile $sourceProfile `
      -Contract $contract `
      -PassName 'first' `
      -ExpectedStageWidth $stageWidth `
      -ExpectedStageHeight $stageHeight `
      -ExpectedFrameRate $frameRate
    $classFingerprint = [string]$firstInspection.ClassFingerprint
    if ($UpdateExpectedHashes) {
      Write-Sha256File -Path $expectedClassHashPath -Hash $classFingerprint
    }
    else {
      $resolvedExpectedClassHashPath = Resolve-RequiredFile `
        -Path $expectedClassHashPath `
        -Description 'Auxiliary expected class hash file'
      $expectedClassHash = Read-Sha256File -Path $resolvedExpectedClassHashPath
      if ($classFingerprint -cne $expectedClassHash) {
        throw "Auxiliary class inventory hash mismatch. Expected $expectedClassHash; found $classFingerprint."
      }
    }

    $entrypointSource = [System.IO.File]::ReadAllText($compilerEntrypointPath)
    $sourcePlaceholder = Get-ScaleformAuxiliaryFingerprintPlaceholder -Kind Source
    $classPlaceholder = Get-ScaleformAuxiliaryFingerprintPlaceholder -Kind Classes
    if (!$entrypointSource.Contains($sourcePlaceholder) -or !$entrypointSource.Contains($classPlaceholder)) {
      throw 'Auxiliary entrypoint does not contain both build fingerprint placeholders.'
    }
    $entrypointSource = $entrypointSource.Replace(
      $sourcePlaceholder,
      "VENWORKS_CUI_SOURCE_SHA256:$sourceFingerprint"
    ).Replace(
      $classPlaceholder,
      "VENWORKS_CUI_CLASSES_SHA256:$classFingerprint"
    )
    Write-Utf8WithoutBom -Path $compilerEntrypointPath -Text $entrypointSource

    Invoke-AuxiliaryCompilation `
      -EntrypointPath $compilerEntrypointPath `
      -SourceRoot $sourceRoot `
      -OutputPath $compiledSwfPath `
      -StageWidth $stageWidth `
      -StageHeight $stageHeight `
      -FrameRate $frameRate `
      -ExternSwcPath $externSwcPath
    Normalize-AuxiliaryMovie `
      -InputPath $compiledSwfPath `
      -OutputPath $normalizedSwfPath `
      -WorkPath $buildWorkDirectory
    $finalInspection = Assert-AuxiliaryMovie `
      -MoviePath $normalizedSwfPath `
      -WorkPath $buildWorkDirectory `
      -SourceProfile $sourceProfile `
      -Contract $contract `
      -PassName 'final' `
      -ExpectedStageWidth $stageWidth `
      -ExpectedStageHeight $stageHeight `
      -ExpectedFrameRate $frameRate `
      -ExpectedSourceFingerprint $sourceFingerprint `
      -ExpectedClassFingerprint $classFingerprint
    if ([string]$finalInspection.ClassFingerprint -cne $classFingerprint) {
      throw 'Embedding the auxiliary build fingerprints changed the compiled class inventory.'
    }
  }

  $actualHash = (Get-FileHash -LiteralPath $normalizedSwfPath -Algorithm SHA256).Hash
  if (!$MarkerProbe) {
    if ($UpdateExpectedHashes) {
      Write-Sha256File -Path $expectedHashPath -Hash $actualHash
    }
    else {
      $resolvedExpectedHashPath = Resolve-RequiredFile -Path $expectedHashPath -Description 'Auxiliary expected hash file'
      $expectedHash = Read-Sha256File -Path $resolvedExpectedHashPath
      if ($actualHash -cne $expectedHash) {
        throw "Auxiliary movie hash mismatch. Expected $expectedHash; found $actualHash."
      }
    }
  }

  $destinationPath = Join-Path $resolvedOutputDirectory ([string]$build.outputFile)
  Copy-Item -LiteralPath $normalizedSwfPath -Destination $destinationPath -Force
  Write-Host -ForegroundColor Green "Built and validated $([string]$build.name) auxiliary movie $destinationPath ($actualHash)"
}
finally {
  if ($KeepWork) {
    Write-Host -ForegroundColor Yellow "Auxiliary build files retained at $buildWorkDirectory"
  }
  elseif (Test-Path -LiteralPath $buildWorkDirectory -PathType Container) {
    Remove-Item -LiteralPath $buildWorkDirectory -Recurse -Force
  }
}
