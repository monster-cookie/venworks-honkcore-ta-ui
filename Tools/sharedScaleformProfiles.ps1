$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-ScaleformProfileRepositoryPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $true)]
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$Description,

    [switch]$Directory
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath) -or
      [System.IO.Path]::IsPathRooted($RelativePath) -or
      $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "$Description must define a safe repository-relative path: $RelativePath"
  }

  $resolvedRoot = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $RelativePath))
  $repositoryPrefix = $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar
  if (!$resolvedPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description resolves outside the repository: $resolvedPath"
  }

  $pathType = if ($Directory) { "Container" } else { "Leaf" }
  if (!(Test-Path -LiteralPath $resolvedPath -PathType $pathType)) {
    throw "$Description does not exist: $resolvedPath"
  }

  return (Resolve-Path -LiteralPath $resolvedPath).Path
}

function Get-ScaleformManifestDefinition {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
  )

  $resolvedManifestPath = (Resolve-Path -LiteralPath $ManifestPath -ErrorAction Stop).Path
  [xml]$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw
  $build = $manifest.scaleformBuild
  if (!$build -or !$build.name -or !$build.outputFile -or !$build.expectedHashFile) {
    throw "Invalid Scaleform build manifest: $resolvedManifestPath"
  }

  $manifestDirectory = Split-Path -Parent $resolvedManifestPath
  $sourceProfilePath = $null
  $sourceProfileName = [string]$build.GetAttribute("actionScriptProfile")
  if (![string]::IsNullOrWhiteSpace($sourceProfileName)) {
    $sourceProfilePath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory $sourceProfileName))
    if (!(Test-Path -LiteralPath $sourceProfilePath -PathType Leaf)) {
      throw "Scaleform ActionScript profile does not exist: $sourceProfilePath"
    }
  }

  return [pscustomobject]@{
    Name = [string]$build.name
    Mode = [string]$build.GetAttribute("mode")
    FileName = [string]$build.outputFile
    ManifestPath = $resolvedManifestPath
    ExpectedHashPath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory ([string]$build.expectedHashFile)))
    SourceProfilePath = $sourceProfilePath
  }
}

function Get-ScaleformAuxiliaryManifestDefinition {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
  )

  $resolvedManifestPath = (Resolve-Path -LiteralPath $ManifestPath -ErrorAction Stop).Path
  [xml]$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw
  $build = $manifest.scaleformAuxiliaryBuild
  if (!$build -or !$build.name -or !$build.outputFile -or !$build.documentClass -or
      !$build.actionScriptSource -or !$build.externSource -or !$build.expectedHashFile -or
      !$build.expectedClassHashFile -or !$build.stageWidth -or !$build.stageHeight -or
      !$build.frameRate) {
    throw "Invalid Scaleform auxiliary build manifest: $resolvedManifestPath"
  }

  $stageWidth = 0
  $stageHeight = 0
  $frameRate = 0
  if (![int]::TryParse([string]$build.stageWidth, [ref]$stageWidth) -or
      ![int]::TryParse([string]$build.stageHeight, [ref]$stageHeight) -or
      ![int]::TryParse([string]$build.frameRate, [ref]$frameRate) -or
      $stageWidth -ne 1920 -or $stageHeight -ne 1080 -or $frameRate -ne 30) {
    throw "Scaleform auxiliary build manifest must declare a 1920x1080 stage at 30 fps: $resolvedManifestPath"
  }

  $manifestDirectory = Split-Path -Parent $resolvedManifestPath
  $sourceProfilePath = $null
  $sourceProfileName = [string]$build.GetAttribute("actionScriptProfile")
  if (![string]::IsNullOrWhiteSpace($sourceProfileName)) {
    $sourceProfilePath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory $sourceProfileName))
    if (!(Test-Path -LiteralPath $sourceProfilePath -PathType Leaf)) {
      throw "Scaleform ActionScript profile does not exist: $sourceProfilePath"
    }
  }

  return [pscustomobject]@{
    Name = [string]$build.name
    FileName = [string]$build.outputFile
    ManifestPath = $resolvedManifestPath
    ExpectedHashPath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory ([string]$build.expectedHashFile)))
    ExpectedClassHashPath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory ([string]$build.expectedClassHashFile)))
    StageWidth = $stageWidth
    StageHeight = $stageHeight
    FrameRate = $frameRate
    SourceProfilePath = $sourceProfilePath
  }
}

function Get-ScaleformSourceProfile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [switch]$Auxiliary
  )

  $definition = if ($Auxiliary) {
    Get-ScaleformAuxiliaryManifestDefinition -ManifestPath $ManifestPath
  }
  else {
    Get-ScaleformManifestDefinition -ManifestPath $ManifestPath
  }
  if ($null -eq $definition.SourceProfilePath) {
    return [pscustomobject]@{
      Name = "shared"
      ExcludedActionScriptPaths = @()
      ActionScriptReplacementPaths = @{}
      ActionScriptPatchPath = $null
      ForbiddenBytecodeTokens = @()
      RequiredBytecodeTokens = @()
      ValueProviders = @(
        'LocalEnvironmentData'
        'LocalEnvData_Frequent'
        'PlayerData'
        'PlayerFrequentData'
        'PlayerInventoryData'
        'WeaponData'
        'HudJetpackData'
        'HUDStarbornPowersData'
        'FavoritesData'
        'ControlMapData'
        'EnvironmentEffectsData'
        'PersonalEffectsData'
        'StarmapSystemBodyInfoProvider'
        'HudCompassData'
      )
      ConditionProviders = @(
        'HudCrosshairData'
        'HUDStealthData'
        'HudCompassData'
        'HUDVehicleData'
        'HUDOpacityData'
        'WeaponData'
        'HUDStarbornPowersData'
        'FavoritesData'
        'HudJetpackData'
        'PlayerInventoryData'
      )
      CrossContextProviderCount = 6
    }
  }

  $scaleformProfile = Import-PowerShellDataFile -LiteralPath $definition.SourceProfilePath
  if ([string]::IsNullOrWhiteSpace([string]$scaleformProfile.Name)) {
    throw "Scaleform ActionScript profile is missing Name: $($definition.SourceProfilePath)"
  }

  $profileDirectory = Split-Path -Parent $definition.SourceProfilePath
  $excludedPaths = @($scaleformProfile.ExcludedActionScriptPaths | ForEach-Object {
    $path = [string]$_
    if ([string]::IsNullOrWhiteSpace($path) -or
        [System.IO.Path]::IsPathRooted($path) -or
        $path -match '(^|[\\/])\.\.([\\/]|$)' -or
        $path -notmatch '\.as$') {
      throw "Scaleform profile '$($scaleformProfile.Name)' contains an unsafe ActionScript exclusion: $path"
    }
    $path.Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar)
  })
  if (@($excludedPaths | Select-Object -Unique).Count -ne $excludedPaths.Count) {
    throw "Scaleform profile '$($scaleformProfile.Name)' contains duplicate ActionScript exclusions."
  }

  $replacementPaths = @{}
  if ($scaleformProfile.ContainsKey("ActionScriptReplacementPaths")) {
    foreach ($replacementEntry in $scaleformProfile.ActionScriptReplacementPaths.GetEnumerator()) {
      $sourcePath = [string]$replacementEntry.Key
      if ([string]::IsNullOrWhiteSpace($sourcePath) -or
          [System.IO.Path]::IsPathRooted($sourcePath) -or
          $sourcePath -match '(^|[\\/])\.\.([\\/]|$)' -or
          $sourcePath -notmatch '\.as$') {
        throw "Scaleform profile '$($scaleformProfile.Name)' contains an unsafe ActionScript replacement target: $sourcePath"
      }
      $normalizedSourcePath = $sourcePath.Replace(
        [System.IO.Path]::AltDirectorySeparatorChar,
        [System.IO.Path]::DirectorySeparatorChar
      )
      if ($replacementPaths.ContainsKey($normalizedSourcePath)) {
        throw "Scaleform profile '$($scaleformProfile.Name)' repeats ActionScript replacement target '$sourcePath'."
      }
      if ($normalizedSourcePath -in $excludedPaths) {
        throw "Scaleform profile '$($scaleformProfile.Name)' cannot replace and exclude '$sourcePath'."
      }

      $replacementPath = [System.IO.Path]::GetFullPath((Join-Path $profileDirectory ([string]$replacementEntry.Value)))
      if (!(Test-Path -LiteralPath $replacementPath -PathType Leaf) -or
          [System.IO.Path]::GetExtension($replacementPath) -cne ".as") {
        throw "Scaleform profile '$($scaleformProfile.Name)' replacement does not exist or is not ActionScript: $replacementPath"
      }
      $replacementPaths[$normalizedSourcePath] = $replacementPath
    }
  }

  $patchPath = $null
  if (![string]::IsNullOrWhiteSpace([string]$scaleformProfile.ActionScriptPatchPath)) {
    $patchPath = [System.IO.Path]::GetFullPath((Join-Path $profileDirectory ([string]$scaleformProfile.ActionScriptPatchPath)))
    if (!(Test-Path -LiteralPath $patchPath -PathType Leaf)) {
      throw "Scaleform profile '$($scaleformProfile.Name)' patch does not exist: $patchPath"
    }
  }

  return [pscustomobject]@{
    Name = [string]$scaleformProfile.Name
    ExcludedActionScriptPaths = $excludedPaths
    ActionScriptReplacementPaths = $replacementPaths
    ActionScriptPatchPath = $patchPath
    ForbiddenBytecodeTokens = @($scaleformProfile.ForbiddenBytecodeTokens | ForEach-Object { [string]$_ })
    RequiredBytecodeTokens = @($scaleformProfile.RequiredBytecodeTokens | ForEach-Object { [string]$_ })
    ValueProviders = @($scaleformProfile.ValueProviders | ForEach-Object { [string]$_ })
    ConditionProviders = @($scaleformProfile.ConditionProviders | ForEach-Object { [string]$_ })
    CrossContextProviderCount = [int]$scaleformProfile.CrossContextProviderCount
  }
}

function Get-VariantScaleformMovieProfile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $true)]
    [hashtable]$VariantBuildProfile
  )

  $name = [string]$VariantBuildProfile.MovieProfile
  if ([string]::IsNullOrWhiteSpace($name)) {
    throw "Variant build profile is missing MovieProfile."
  }

  if ($VariantBuildProfile.ContainsKey("SwfMovieManifestPaths")) {
    throw "Variant build profiles must declare one complete MovieManifestPaths collection instead of a parallel SWF manifest list."
  }

  $usesCustomHudManifests = $VariantBuildProfile.ContainsKey("MovieManifestPaths")
  $manifestRelativePaths = if ($usesCustomHudManifests) {
    @($VariantBuildProfile.MovieManifestPaths | ForEach-Object { [string]$_ })
  }
  else {
    @(
      "Scaleform/hudmenu/build.xml"
      "Scaleform/hudmenu_lrg/build.xml"
      "Scaleform/hudmenu/build-swf.xml"
      "Scaleform/hudmenu_lrg/build-swf.xml"
    )
  }
  if ($manifestRelativePaths.Count -ne 4 -or
      @($manifestRelativePaths | Select-Object -Unique).Count -ne 4) {
    throw "Scaleform movie profile '$name' must declare exactly two unique GFX and two unique SWF HUD build manifests."
  }

  $manifestDefinitions = @($manifestRelativePaths | ForEach-Object {
    $manifestPath = Resolve-ScaleformProfileRepositoryPath `
      -RepositoryRoot $RepositoryRoot `
      -RelativePath $_ `
      -Description "Scaleform movie profile '$name' manifest"
    Get-ScaleformManifestDefinition -ManifestPath $manifestPath
  })
  $movieNames = @($manifestDefinitions | ForEach-Object { $_.FileName })
  $requiredMovieNames = @("hudmenu.gfx", "hudmenu.swf", "hudmenu_lrg.gfx", "hudmenu_lrg.swf")
  if ($movieNames.Count -ne $requiredMovieNames.Count -or
      @($requiredMovieNames | Where-Object { $_ -notin $movieNames }).Count -ne 0) {
    throw "Scaleform movie profile '$name' must build the normal and large HUD GFX/SWF movies exactly once."
  }

  foreach ($manifestDefinition in $manifestDefinitions) {
    if ([string]::IsNullOrWhiteSpace([string]$manifestDefinition.Mode) -or
        [string]$manifestDefinition.Mode -notin @('auxiliary-bootstrap', 'ps5-debug-hudmenu') -or
        $null -ne $manifestDefinition.SourceProfilePath) {
      throw "HUD manifest must select a supported profile-independent host mode: $($manifestDefinition.ManifestPath)"
    }
  }
  $manifestModes = @($manifestDefinitions.Mode | Select-Object -Unique)
  if ($manifestModes.Count -ne 1) {
    throw "Scaleform movie profile '$name' cannot mix HUD host build modes."
  }
  if (!$usesCustomHudManifests -and [string]$manifestModes[0] -cne 'auxiliary-bootstrap') {
    throw "The shared HUD manifests must select auxiliary-bootstrap mode."
  }

  $auxiliaryDefinition = $null
  $auxiliarySourceProfile = $null
  $includeSharedRuntimeMovies = !$usesCustomHudManifests
  if ($includeSharedRuntimeMovies) {
    $auxiliaryManifestRelativePath = if ($VariantBuildProfile.ContainsKey("AuxiliaryMovieManifestPath")) {
      [string]$VariantBuildProfile.AuxiliaryMovieManifestPath
    }
    else {
      'Scaleform/venworkscui/build.xml'
    }
    $auxiliaryManifestPath = Resolve-ScaleformProfileRepositoryPath `
      -RepositoryRoot $RepositoryRoot `
      -RelativePath $auxiliaryManifestRelativePath `
      -Description "Scaleform movie profile '$name' auxiliary manifest"
    $auxiliaryDefinition = Get-ScaleformAuxiliaryManifestDefinition -ManifestPath $auxiliaryManifestPath
    $auxiliarySourceProfile = Get-ScaleformSourceProfileFromAuxiliaryManifest -ManifestPath $auxiliaryManifestPath
    if ($auxiliarySourceProfile.Name -cne $name) {
      throw "Scaleform movie profile '$name' does not match its auxiliary ActionScript profile '$($auxiliarySourceProfile.Name)'."
    }
    if ($auxiliaryDefinition.FileName -cne 'venworkscui.swf') {
      throw "Scaleform movie profile '$name' must build venworkscui.swf."
    }
  }

  $buildMovieDefinitions = @($manifestDefinitions | ForEach-Object {
    [pscustomobject]@{
      FileName = $_.FileName
      ExpectedHashPath = $_.ExpectedHashPath
      ManifestPath = $_.ManifestPath
      Mode = $_.Mode
      SourceGroup = 'Bootstrap'
    }
  })
  if ($includeSharedRuntimeMovies) {
    $buildMovieDefinitions += @(
      [pscustomobject]@{
        FileName = "hudmessagesmenu.gfx"
        ExpectedHashPath = (Join-Path $RepositoryRoot "Scaleform\hudmessagesmenu\validation\expected.sha256")
        SourceGroup = 'HudMessages'
      },
      [pscustomobject]@{
        FileName = "hudmessagesmenu.swf"
        ExpectedHashPath = (Join-Path $RepositoryRoot "Scaleform\hudmessagesmenu\validation\expected-swf.sha256")
        SourceGroup = 'HudMessages'
      },
      [pscustomobject]@{
        FileName = "hudmessagesmenu_lrg.gfx"
        ExpectedHashPath = (Join-Path $RepositoryRoot "Scaleform\hudmessagesmenu_lrg\validation\expected.sha256")
        SourceGroup = 'HudMessages'
      },
      [pscustomobject]@{
        FileName = "hudmessagesmenu_lrg.swf"
        ExpectedHashPath = (Join-Path $RepositoryRoot "Scaleform\hudmessagesmenu_lrg\validation\expected-swf.sha256")
        SourceGroup = 'HudMessages'
      },
      [pscustomobject]@{
        FileName = $auxiliaryDefinition.FileName
        ExpectedHashPath = $auxiliaryDefinition.ExpectedHashPath
        ExpectedClassHashPath = $auxiliaryDefinition.ExpectedClassHashPath
        SourceGroup = 'Auxiliary'
      }
    )
  }

  $buildMoviesByName = @{}
  foreach ($buildMovie in $buildMovieDefinitions) {
    if ($buildMoviesByName.ContainsKey([string]$buildMovie.FileName)) {
      throw "Scaleform movie profile '$name' contains duplicate build output '$($buildMovie.FileName)'."
    }
    $buildMoviesByName[[string]$buildMovie.FileName] = $buildMovie
  }

  $deploymentMappings = @($buildMovieDefinitions | ForEach-Object {
    $extension = [System.IO.Path]::GetExtension([string]$_.FileName)
    $expectedSignature = switch ($extension) {
      '.gfx' { 'GFX'; break }
      '.swf' { 'CWS'; break }
      default { throw "Scaleform movie profile '$name' has unsupported movie extension '$extension'." }
    }
    [pscustomobject]@{
      FileName = [string]$_.FileName
      SourceFileName = [string]$_.FileName
      ExpectedSignature = $expectedSignature
    }
  })
  $deploymentMovieDefinitions = @($deploymentMappings | ForEach-Object {
    $sourceFileName = [string]$_.SourceFileName
    if (!$buildMoviesByName.ContainsKey($sourceFileName)) {
      throw "Scaleform movie profile '$name' deploys missing build output '$sourceFileName'."
    }
    $sourceDefinition = $buildMoviesByName[$sourceFileName]
    [pscustomobject]@{
      FileName = [string]$_.FileName
      SourceFileName = $sourceFileName
      ExpectedHashPath = [string]$sourceDefinition.ExpectedHashPath
      ExpectedSignature = [string]$_.ExpectedSignature
      SourceGroup = [string]$sourceDefinition.SourceGroup
    }
  })
  $requiredDeploymentNames = @($buildMovieDefinitions | ForEach-Object { [string]$_.FileName })
  $deploymentNames = @($deploymentMovieDefinitions | ForEach-Object { [string]$_.FileName })
  if ($deploymentNames.Count -ne $requiredDeploymentNames.Count -or
      @($deploymentNames | Select-Object -Unique).Count -ne $deploymentNames.Count -or
      @($requiredDeploymentNames | Where-Object { $_ -notin $deploymentNames }).Count -ne 0) {
    throw "Scaleform movie profile '$name' must deploy every declared build output exactly once."
  }

  return [pscustomobject]@{
    Name = $name
    HostMode = [string]$manifestModes[0]
    ManifestPaths = @($manifestDefinitions | ForEach-Object { $_.ManifestPath })
    AuxiliaryManifestPath = if ($null -eq $auxiliaryDefinition) { $null } else { $auxiliaryDefinition.ManifestPath }
    AuxiliaryExpectedClassHashPath = if ($null -eq $auxiliaryDefinition) { $null } else { $auxiliaryDefinition.ExpectedClassHashPath }
    AuxiliaryStageWidth = if ($null -eq $auxiliaryDefinition) { 0 } else { $auxiliaryDefinition.StageWidth }
    AuxiliaryStageHeight = if ($null -eq $auxiliaryDefinition) { 0 } else { $auxiliaryDefinition.StageHeight }
    AuxiliaryFrameRate = if ($null -eq $auxiliaryDefinition) { 0 } else { $auxiliaryDefinition.FrameRate }
    SourceProfile = $auxiliarySourceProfile
    BuildMovieDefinitions = $buildMovieDefinitions
    DeploymentMovieDefinitions = $deploymentMovieDefinitions
  }
}

function Get-ScaleformSourceProfileFromAuxiliaryManifest {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
  )

  return Get-ScaleformSourceProfile -ManifestPath $ManifestPath -Auxiliary
}

function Get-ScaleformProfileActionScriptPath {
  param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$SourceProfile,

    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  $normalizedRelativePath = $RelativePath.Replace(
    [System.IO.Path]::AltDirectorySeparatorChar,
    [System.IO.Path]::DirectorySeparatorChar
  )
  if ($SourceProfile.ActionScriptReplacementPaths.ContainsKey($normalizedRelativePath)) {
    return [string]$SourceProfile.ActionScriptReplacementPaths[$normalizedRelativePath]
  }
  return $SourcePath
}

function Get-ScaleformPatchedActionScript {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$PatchPath
  )

  [xml]$patchDocument = Get-Content -LiteralPath $PatchPath -Raw
  $normalizedRelativePath = $RelativePath.Replace(
    [System.IO.Path]::AltDirectorySeparatorChar,
    [System.IO.Path]::DirectorySeparatorChar
  )
  $sourceNodes = @($patchDocument.SelectNodes('/actionScriptProfilePatch/source'))
  $sourceNode = @($sourceNodes | Where-Object {
    ([string]$_.path).Replace(
      [System.IO.Path]::AltDirectorySeparatorChar,
      [System.IO.Path]::DirectorySeparatorChar
    ) -ceq $normalizedRelativePath
  })
  if ($sourceNode.Count -gt 1) {
    throw "ActionScript profile patch repeats source '$RelativePath': $PatchPath"
  }

  $sourceText = [System.IO.File]::ReadAllText($SourcePath).Replace("`r`n", "`n")
  if ($sourceNode.Count -eq 0) {
    return $sourceText
  }

  foreach ($operation in @($sourceNode[0].ChildNodes | Where-Object { $_.NodeType -eq 'Element' })) {
    $findNodes = @($operation.SelectNodes('find'))
    $replacementNodes = @($operation.SelectNodes('with'))
    if ($operation.Name -ne "replace" -or
        $findNodes.Count -ne 1 -or
        $replacementNodes.Count -ne 1) {
      throw "ActionScript profile patch contains an unsupported operation for '$RelativePath': $PatchPath"
    }
    $findText = ([string]$findNodes[0].InnerText).Replace("`r`n", "`n")
    $replacementText = ([string]$replacementNodes[0].InnerText).Replace("`r`n", "`n")
    $matchCount = [regex]::Matches($sourceText, [regex]::Escape($findText)).Count
    if ($matchCount -ne 1) {
      throw "ActionScript profile patch expected one exact match in '$RelativePath'; found $matchCount."
    }
    $sourceText = $sourceText.Replace($findText, $replacementText)
  }

  return $sourceText
}

function Get-ScaleformAuxiliaryFingerprintPlaceholder {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Source', 'Classes')]
    [string]$Kind
  )

  $prefix = if ($Kind -ceq 'Source') {
    'VENWORKS_CUI_SOURCE_SHA256:'
  }
  else {
    'VENWORKS_CUI_CLASSES_SHA256:'
  }
  return $prefix + ('_' * 64)
}

function Get-ScaleformAuxiliaryExtensionsExternSource {
  return @'
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
}

function Get-ScaleformAuxiliaryTextSha256 {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text
  )

  $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    return [System.BitConverter]::ToString($algorithm.ComputeHash($bytes)).Replace('-', '')
  }
  finally {
    $algorithm.Dispose()
  }
}

function Get-ScaleformCanonicalAuxiliaryEntrypoint {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source
  )

  $canonical = $Source.Replace("`r`n", "`n").Replace("`r", "`n")
  foreach ($kind in @('Source', 'Classes')) {
    $placeholder = Get-ScaleformAuxiliaryFingerprintPlaceholder -Kind $kind
    $prefix = $placeholder.Substring(0, $placeholder.Length - 64)
    $pattern = [regex]::Escape($prefix) + '[0-9A-Fa-f_]{64}'
    $fingerprintMatches = [regex]::Matches($canonical, $pattern)
    if ($fingerprintMatches.Count -ne 1) {
      throw "Auxiliary entrypoint must contain exactly one $kind fingerprint token; found $($fingerprintMatches.Count)."
    }
    $canonical = [regex]::Replace($canonical, $pattern, $placeholder)
  }
  return $canonical
}

function Get-ScaleformAuxiliarySourceFingerprint {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
  )

  $definition = Get-ScaleformAuxiliaryManifestDefinition -ManifestPath $ManifestPath
  $sourceProfile = Get-ScaleformSourceProfileFromAuxiliaryManifest -ManifestPath $definition.ManifestPath
  [xml]$manifest = Get-Content -LiteralPath $definition.ManifestPath -Raw
  $build = $manifest.scaleformAuxiliaryBuild
  $manifestDirectory = Split-Path -Parent $definition.ManifestPath
  $sourceRoot = (Resolve-Path -LiteralPath (Join-Path $manifestDirectory ([string]$build.actionScriptSource)) -ErrorAction Stop).Path
  $externRoot = (Resolve-Path -LiteralPath (Join-Path $manifestDirectory ([string]$build.externSource)) -ErrorAction Stop).Path
  $entrypointPath = (Resolve-Path -LiteralPath (Join-Path $manifestDirectory ([string]$build.documentClass)) -ErrorAction Stop).Path
  $records = [System.Collections.Generic.List[string]]::new()

  $records.Add('CONTRACT|venworks-cui-auxiliary-source-v1')
  foreach ($contractValue in @(
    "name=$([string]$build.name)",
    "outputFile=$([string]$build.outputFile)",
    "documentClass=$([string]$build.documentClass)",
    "actionScriptSource=$([string]$build.actionScriptSource)",
    "externSource=$([string]$build.externSource)",
    "expectedHashFile=$([string]$build.expectedHashFile)",
    "expectedClassHashFile=$([string]$build.expectedClassHashFile)",
    "actionScriptProfile=$([string]$build.GetAttribute('actionScriptProfile'))",
    'compiler.debug=false',
    'compiler.optimize=true',
    'compiler.compress=true',
    'compiler.omit-trace-statements=true',
    'use-network=false',
    'target-player=11.1.0',
    'swf-version=12'
  )) {
    $records.Add("BUILD|$contractValue")
  }
  $records.Add("PROFILE|name=$($sourceProfile.Name)")
  foreach ($path in @($sourceProfile.ExcludedActionScriptPaths | Sort-Object)) {
    $records.Add("PROFILE|exclude=$($path.Replace('\', '/'))")
  }
  foreach ($path in @($sourceProfile.ActionScriptReplacementPaths.Keys | Sort-Object)) {
    $records.Add("PROFILE|replace=$($path.Replace('\', '/'))")
  }
  foreach ($token in @($sourceProfile.RequiredBytecodeTokens)) {
    $records.Add("PROFILE|required=$token")
  }
  foreach ($token in @($sourceProfile.ForbiddenBytecodeTokens)) {
    $records.Add("PROFILE|forbidden=$token")
  }
  foreach ($provider in @($sourceProfile.ValueProviders)) {
    $records.Add("PROFILE|value=$provider")
  }
  foreach ($provider in @($sourceProfile.ConditionProviders)) {
    $records.Add("PROFILE|condition=$provider")
  }
  $records.Add("PROFILE|overlaps=$($sourceProfile.CrossContextProviderCount)")

  foreach ($sourceFile in @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.as' | Sort-Object FullName)) {
    $relativePath = $sourceFile.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/')
    $profilePath = $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if ($profilePath -in $sourceProfile.ExcludedActionScriptPaths) {
      continue
    }
    $effectiveSourcePath = Get-ScaleformProfileActionScriptPath `
      -SourceProfile $sourceProfile `
      -SourcePath $sourceFile.FullName `
      -RelativePath $profilePath
    $sourceText = if ($null -ne $sourceProfile.ActionScriptPatchPath) {
      Get-ScaleformPatchedActionScript `
        -SourcePath $effectiveSourcePath `
        -RelativePath $profilePath `
        -PatchPath $sourceProfile.ActionScriptPatchPath
    }
    else {
      [System.IO.File]::ReadAllText($effectiveSourcePath).Replace("`r`n", "`n").Replace("`r", "`n")
    }
    $records.Add("SOURCE|$relativePath|$($sourceText.Length)`n$sourceText")
  }

  $entrypointSource = Get-ScaleformCanonicalAuxiliaryEntrypoint `
    -Source ([System.IO.File]::ReadAllText($entrypointPath))
  $records.Add("ENTRYPOINT|$([string]$build.documentClass)|$($entrypointSource.Length)`n$entrypointSource")

  foreach ($externFile in @(Get-ChildItem -LiteralPath $externRoot -Recurse -File -Filter '*.as' | Sort-Object FullName)) {
    $relativePath = $externFile.FullName.Substring($externRoot.Length + 1).Replace('\', '/')
    $externText = [System.IO.File]::ReadAllText($externFile.FullName).Replace("`r`n", "`n").Replace("`r", "`n")
    $records.Add("EXTERN|$relativePath|$($externText.Length)`n$externText")
  }
  $extensionsExtern = (Get-ScaleformAuxiliaryExtensionsExternSource).Replace("`r`n", "`n").Replace("`r", "`n")
  $records.Add("EXTERN|scaleform/gfx/Extensions.as|$($extensionsExtern.Length)`n$extensionsExtern")

  return Get-ScaleformAuxiliaryTextSha256 -Text ([string]::Join("`n--`n", $records))
}
