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

function Assert-AuxiliaryMovie {
  param(
    [Parameter(Mandatory = $true)]
    [string]$MoviePath,

    [Parameter(Mandatory = $true)]
    [string]$WorkPath,

    [Parameter(Mandatory = $true)]
    [pscustomobject]$SourceProfile,

    [switch]$Marker
  )

  Assert-ScaleformMovieEncoding -Path $MoviePath -Context 'Generated auxiliary movie'
  $reopenedXmlPath = Join-Path $WorkPath 'reopened.xml'
  $validationScriptsDirectory = Join-Path $WorkPath 'validation-scripts'
  Invoke-JavaJar `
    -JarPath $script:ResolvedJpexsJarPath `
    -Arguments @('-swf2xml', $MoviePath, $reopenedXmlPath) `
    -Description 'JPEXS auxiliary movie reopen'
  Invoke-JavaJar `
    -JarPath $script:ResolvedJpexsJarPath `
    -Arguments @('-format', 'script:as', '-export', 'script', $validationScriptsDirectory, $MoviePath) `
    -Description 'JPEXS auxiliary ActionScript export'

  [xml]$reopened = Get-Content -LiteralPath $reopenedXmlPath -Raw
  $abcTags = @($reopened.SelectNodes('/swf/tags/item[@type="DoABC2Tag" or @type="DoABCTag"]'))
  if ($abcTags.Count -ne 1) {
    throw "Auxiliary movie must contain exactly one ABC; found $($abcTags.Count)."
  }
  $validationSource = @(Get-ChildItem -LiteralPath $validationScriptsDirectory -Recurse -File -Filter '*.as' | ForEach-Object {
    [System.IO.File]::ReadAllText($_.FullName)
  }) -join "`n"
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
    return
  }
  if ($validationSource.Contains('VENWORKS AUX LOADED')) {
    throw 'Production auxiliary movie retains the marker-probe payload.'
  }
  foreach ($requiredToken in @('CUIRuntime', 'CUILayoutImportLoader', 'CUIPlayerHudDataContext', 'CUIConditionContext') + @($SourceProfile.RequiredBytecodeTokens)) {
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
if (!$build -or !$build.outputFile -or !$build.documentClass -or !$build.expectedHashFile) {
  throw "Invalid auxiliary build manifest: $resolvedBuildManifestPath"
}
$manifestDirectory = Split-Path -Parent $resolvedBuildManifestPath
$entrypointPath = Resolve-RequiredFile `
  -Path (Join-Path $manifestDirectory ([string]$build.documentClass)) `
  -Description 'Auxiliary entrypoint'
$expectedHashPath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory ([string]$build.expectedHashFile)))
$sourceProfile = Get-ScaleformSourceProfileFromAuxiliaryManifest -ManifestPath $resolvedBuildManifestPath

New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory, $resolvedWorkDirectory | Out-Null
$buildWorkDirectory = Join-Path $resolvedWorkDirectory ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $buildWorkDirectory | Out-Null
$sourceRoot = Join-Path $buildWorkDirectory 'source'
$externRoot = Join-Path $buildWorkDirectory 'externs'
$compiledSwfPath = Join-Path $buildWorkDirectory 'compiled.swf'
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

   public final class VenworksCUIEntrypoint extends MovieClip
   {
      private var owner:DisplayObjectContainer;
      private var marker:TextField;

      public function initialize(param1:DisplayObjectContainer) : void
      {
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
         this.marker.text = "VENWORKS AUX LOADED";
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
    Write-Utf8WithoutBom -Path $scaleformExternPath -Text @'
package scaleform.gfx
{
   import flash.geom.Rectangle;

   public final class Extensions
   {
      public static function get visibleRect() : Rectangle
      {
         return null;
      }
   }
}
'@

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

  $compilerArguments = @(
    "-load-config=$flexConfigPath",
    '-compiler.library-path=',
    "-compiler.external-library-path=$resolvedPlayerGlobalPath",
    '-compiler.source-path', $sourceRoot,
    '-compiler.debug=false',
    '-compiler.optimize=true',
    '-compiler.compress=true',
    '-compiler.omit-trace-statements=true',
    '-use-network=false',
    '-target-player=11.1.0',
    '-swf-version=12',
    '-output', $compiledSwfPath,
    $compilerEntrypointPath
  )
  if (!$MarkerProbe) {
    $compilerArguments = @($compilerArguments[0..2]) +
      @("-compiler.external-library-path+=$externSwcPath") +
      @($compilerArguments[3..($compilerArguments.Count - 1)])
  }
  Push-Location (Join-Path $resolvedFlexSdkPath 'frameworks')
  try {
    Invoke-JavaJar -JarPath $mxmlcJarPath -Arguments $compilerArguments -Description 'Apache Flex CUI compilation'
  }
  finally {
    Pop-Location
  }

  Normalize-AuxiliaryMovie -InputPath $compiledSwfPath -OutputPath $normalizedSwfPath -WorkPath $buildWorkDirectory
  Assert-AuxiliaryMovie `
    -MoviePath $normalizedSwfPath `
    -WorkPath $buildWorkDirectory `
    -SourceProfile $sourceProfile `
    -Marker:$MarkerProbe

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
  Write-Host -ForegroundColor Green "Built and validated $($sourceProfile.Name) auxiliary movie $destinationPath ($actualHash)"
}
finally {
  if ($KeepWork) {
    Write-Host -ForegroundColor Yellow "Auxiliary build files retained at $buildWorkDirectory"
  }
  elseif (Test-Path -LiteralPath $buildWorkDirectory -PathType Container) {
    Remove-Item -LiteralPath $buildWorkDirectory -Recurse -Force
  }
}
