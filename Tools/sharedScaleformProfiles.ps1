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
    FileName = [string]$build.outputFile
    ManifestPath = $resolvedManifestPath
    ExpectedHashPath = [System.IO.Path]::GetFullPath((Join-Path $manifestDirectory ([string]$build.expectedHashFile)))
    SourceProfilePath = $sourceProfilePath
  }
}

function Get-ScaleformSourceProfile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
  )

  $definition = Get-ScaleformManifestDefinition -ManifestPath $ManifestPath
  if ($null -eq $definition.SourceProfilePath) {
    return [pscustomobject]@{
      Name = "shared"
      ExcludedActionScriptPaths = @()
      ActionScriptPatchPath = $null
      ForbiddenBytecodeTokens = @()
      ValueProviders = @()
      ConditionProviders = @()
      CrossContextProviderCount = 6
    }
  }

  $profile = Import-PowerShellDataFile -LiteralPath $definition.SourceProfilePath
  if ([string]::IsNullOrWhiteSpace([string]$profile.Name)) {
    throw "Scaleform ActionScript profile is missing Name: $($definition.SourceProfilePath)"
  }

  $profileDirectory = Split-Path -Parent $definition.SourceProfilePath
  $excludedPaths = @($profile.ExcludedActionScriptPaths | ForEach-Object {
    $path = [string]$_
    if ([string]::IsNullOrWhiteSpace($path) -or
        [System.IO.Path]::IsPathRooted($path) -or
        $path -match '(^|[\\/])\.\.([\\/]|$)' -or
        $path -notmatch '\.as$') {
      throw "Scaleform profile '$($profile.Name)' contains an unsafe ActionScript exclusion: $path"
    }
    $path.Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar)
  })
  if (@($excludedPaths | Select-Object -Unique).Count -ne $excludedPaths.Count) {
    throw "Scaleform profile '$($profile.Name)' contains duplicate ActionScript exclusions."
  }

  $patchPath = $null
  if (![string]::IsNullOrWhiteSpace([string]$profile.ActionScriptPatchPath)) {
    $patchPath = [System.IO.Path]::GetFullPath((Join-Path $profileDirectory ([string]$profile.ActionScriptPatchPath)))
    if (!(Test-Path -LiteralPath $patchPath -PathType Leaf)) {
      throw "Scaleform profile '$($profile.Name)' patch does not exist: $patchPath"
    }
  }

  return [pscustomobject]@{
    Name = [string]$profile.Name
    ExcludedActionScriptPaths = $excludedPaths
    ActionScriptPatchPath = $patchPath
    ForbiddenBytecodeTokens = @($profile.ForbiddenBytecodeTokens | ForEach-Object { [string]$_ })
    ValueProviders = @($profile.ValueProviders | ForEach-Object { [string]$_ })
    ConditionProviders = @($profile.ConditionProviders | ForEach-Object { [string]$_ })
    CrossContextProviderCount = [int]$profile.CrossContextProviderCount
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

  $manifestRelativePaths = if ($VariantBuildProfile.ContainsKey("MovieManifestPaths")) {
    @($VariantBuildProfile.MovieManifestPaths | ForEach-Object { [string]$_ })
  }
  else {
    @("Scaleform/hudmenu/build.xml", "Scaleform/hudmenu_lrg/build.xml")
  }
  if ($manifestRelativePaths.Count -ne 2 -or
      @($manifestRelativePaths | Select-Object -Unique).Count -ne 2) {
    throw "Scaleform movie profile '$name' must declare exactly two unique HUD build manifests."
  }

  $manifestDefinitions = @($manifestRelativePaths | ForEach-Object {
    $manifestPath = Resolve-ScaleformProfileRepositoryPath `
      -RepositoryRoot $RepositoryRoot `
      -RelativePath $_ `
      -Description "Scaleform movie profile '$name' manifest"
    Get-ScaleformManifestDefinition -ManifestPath $manifestPath
  })
  $movieNames = @($manifestDefinitions | ForEach-Object { $_.FileName })
  $requiredMovieNames = @("hudmenu.gfx", "hudmenu_lrg.gfx")
  if ($movieNames.Count -ne $requiredMovieNames.Count -or
      @($requiredMovieNames | Where-Object { $_ -notin $movieNames }).Count -ne 0) {
    throw "Scaleform movie profile '$name' must build hudmenu.gfx and hudmenu_lrg.gfx exactly once."
  }

  $sourceProfileNames = @($manifestDefinitions | ForEach-Object {
    (Get-ScaleformSourceProfile -ManifestPath $_.ManifestPath).Name
  } | Select-Object -Unique)
  if ($sourceProfileNames.Count -ne 1 -or $sourceProfileNames[0] -cne $name) {
    throw "Scaleform movie profile '$name' does not match its manifest ActionScript profile."
  }

  $movieDefinitions = @($manifestDefinitions | ForEach-Object {
    [pscustomobject]@{
      FileName = $_.FileName
      ExpectedHashPath = $_.ExpectedHashPath
    }
  })
  $movieDefinitions += @(
    [pscustomobject]@{
      FileName = "hudmessagesmenu.gfx"
      ExpectedHashPath = (Join-Path $RepositoryRoot "Scaleform\hudmessagesmenu\validation\expected.sha256")
    },
    [pscustomobject]@{
      FileName = "hudmessagesmenu_lrg.gfx"
      ExpectedHashPath = (Join-Path $RepositoryRoot "Scaleform\hudmessagesmenu_lrg\validation\expected.sha256")
    }
  )

  return [pscustomobject]@{
    Name = $name
    ManifestPaths = @($manifestDefinitions | ForEach-Object { $_.ManifestPath })
    MovieDefinitions = $movieDefinitions
  }
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
