<#
.SYNOPSIS
Compiles the shared Scaleform movies and stages independent variant payloads.

.PARAMETER VariantKeys
One or more keys from `$Global:ReleaseVariants`. Omit this parameter to process
all release variants. `VariantKey` remains a compatibility alias.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$VanillaInterfacePath,

  [Alias("VariantKey")]
  [string[]]$VariantKeys,

  [string]$WorkDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work"),

  [switch]$KeepWork,

  [switch]$UpdateExpectedHashes,

  [switch]$Committed,

  [switch]$AuxiliaryMarkerProbe
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

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

function Resolve-RepositoryPath {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath)) {
    throw "$Description must define a repository-relative path."
  }
  if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "$Description must remain repository-relative: $RelativePath"
  }

  $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
  $repositoryPrefix = $repositoryRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  ) + [System.IO.Path]::DirectorySeparatorChar
  if (!$resolvedPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description resolves outside the repository: $resolvedPath"
  }

  return $resolvedPath
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
  [System.IO.File]::WriteAllText(
    $Path,
    $canonicalText,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Copy-ProfilePayloadFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
  )

  $extension = [System.IO.Path]::GetExtension($SourcePath)
  if ($extension -in @(".xml", ".svg")) {
    Write-Utf8WithoutBom `
      -Path $DestinationPath `
      -Text ([System.IO.File]::ReadAllText($SourcePath))
  }
  else {
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
  }
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
    throw "Refusing to remove a directory outside its owned root: $fullPath"
  }

  Remove-Item -LiteralPath $fullPath -Recurse -Force
}

function Get-LiteralPaletteColors {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PalettePath
  )

  [xml]$palette = Get-Content -LiteralPath $PalettePath -Raw
  $colors = @{}
  foreach ($colorNode in @($palette.SelectNodes('/venworksCUIPalette/colors/color'))) {
    $role = [string]$colorNode.role
    $value = [string]$colorNode.value
    if ([string]::IsNullOrWhiteSpace($role) -or $value -notmatch '^#[0-9A-Fa-f]{6}$') {
      throw "Literal palette contains an invalid color entry: $PalettePath"
    }
    if ($colors.ContainsKey($role)) {
      throw "Literal palette repeats color role '$role': $PalettePath"
    }
    $colors[$role] = $value
  }
  if ($colors.Count -eq 0) {
    throw "Literal palette does not define any colors: $PalettePath"
  }

  return $colors
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
      throw "$Context references unknown palette color '$role'."
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

function Assert-UniqueSafeFileNames {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [object[]]$FileNames,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $names = @($FileNames | ForEach-Object { [string]$_ })
  if (@($names | Select-Object -Unique).Count -ne $names.Count) {
    throw "$Context contains duplicate file names."
  }
  foreach ($fileName in $names) {
    if ([string]::IsNullOrWhiteSpace($fileName) -or
        $fileName -ne [System.IO.Path]::GetFileName($fileName)) {
      throw "$Context contains an unsafe file name: $fileName"
    }
  }
}

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  if ($Committed) {
    . "$PSScriptRoot\sharedConfig.ps1" -SkipEnvironment
  }
  else {
    . "$PSScriptRoot\sharedConfig.ps1"
  }
}
. (Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "sharedScaleformProfiles.ps1") `
  -Description "Scaleform movie-profile helper")

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)
if ($variants.Count -eq 0) {
  throw "At least one variant must be selected."
}
if ($AuxiliaryMarkerProbe) {
  if ($Committed) {
    throw 'The auxiliary marker probe cannot run in committed-artifact mode.'
  }
  if ($UpdateExpectedHashes) {
    throw 'The auxiliary marker probe cannot update production expected hashes.'
  }
  if ($variants.Count -ne 1 -or [string]$variants[0].VariantKey -cne 'MIN') {
    throw 'The auxiliary marker probe is restricted to -VariantKeys MIN.'
  }
}

$resolvedWorkDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
New-Item -ItemType Directory -Force -Path $resolvedWorkDirectory | Out-Null
$buildDirectory = Join-Path $resolvedWorkDirectory ([guid]::NewGuid().ToString("N"))
$variantBuildProfiles = @{}
$variantMovieProfiles = @{}
$variantBootstrapProfileKeys = @{}
$bootstrapProfiles = @{}
$auxiliaryProfiles = @{}
$sharedMovieNames = @()
foreach ($variant in $variants) {
  $profilePath = Resolve-RequiredFile `
    -Path (Join-Path $repositoryRoot "Scaleform\variants\$($variant.VariantKey)\build.psd1") `
    -Description "$($variant.VariantName) build profile"
  $variantBuildProfile = Import-PowerShellDataFile -LiteralPath $profilePath
  $movieProfile = Get-VariantScaleformMovieProfile `
    -RepositoryRoot $repositoryRoot `
    -VariantBuildProfile $variantBuildProfile
  $variantBuildProfiles[[string]$variant.VariantKey] = $variantBuildProfile
  $variantMovieProfiles[[string]$variant.VariantKey] = $movieProfile
  $bootstrapProfileKey = @($movieProfile.ManifestPaths) -join '|'
  $variantBootstrapProfileKeys[[string]$variant.VariantKey] = $bootstrapProfileKey
  if (!$bootstrapProfiles.ContainsKey($bootstrapProfileKey)) {
    $bootstrapProfiles[$bootstrapProfileKey] = [pscustomobject]@{
      Name = [string]$movieProfile.HostMode
      ManifestPaths = @($movieProfile.ManifestPaths)
      MovieNames = @($movieProfile.BuildMovieDefinitions |
        Where-Object { [string]$_.SourceGroup -ceq 'Bootstrap' } |
        ForEach-Object { [string]$_.FileName })
    }
  }
  if (@($bootstrapProfiles[$bootstrapProfileKey].MovieNames).Count -ne 4) {
    throw "Scaleform movie profile '$($movieProfile.Name)' must declare four HUD host build outputs."
  }
  $profileHudMessageNames = @($movieProfile.BuildMovieDefinitions |
    Where-Object { [string]$_.SourceGroup -ceq 'HudMessages' } |
    ForEach-Object { [string]$_.FileName })
  if ($profileHudMessageNames.Count -ne 0) {
    if ($sharedMovieNames.Count -eq 0) {
      $sharedMovieNames = @($profileHudMessageNames)
    }
    elseif (($sharedMovieNames -join '|') -cne ($profileHudMessageNames -join '|')) {
      throw 'Selected movie profiles declare conflicting HUD-message output inventories.'
    }
  }
  if ($null -ne $movieProfile.AuxiliaryManifestPath -and $auxiliaryProfiles.ContainsKey($movieProfile.Name)) {
    if ([string]$auxiliaryProfiles[$movieProfile.Name].AuxiliaryManifestPath -cne
        [string]$movieProfile.AuxiliaryManifestPath) {
      throw "Scaleform auxiliary profile '$($movieProfile.Name)' resolves to conflicting build manifests."
    }
  }
  elseif ($null -ne $movieProfile.AuxiliaryManifestPath) {
    $auxiliaryProfiles[$movieProfile.Name] = $movieProfile
  }
}

try {
  $bootstrapProfileDirectories = @{}
  $auxiliaryProfileDirectories = @{}
  $bootstrapIndex = 0
  foreach ($bootstrapProfileKey in @($bootstrapProfiles.Keys | Sort-Object)) {
    $bootstrapProfile = $bootstrapProfiles[$bootstrapProfileKey]
    $bootstrapIndex++
    $bootstrapMovieDirectory = Join-Path (Join-Path $buildDirectory 'movies') "bootstrap-$bootstrapIndex"
    New-Item -ItemType Directory -Force -Path $bootstrapMovieDirectory | Out-Null
    $bootstrapProfileDirectories[$bootstrapProfileKey] = $bootstrapMovieDirectory
    $compileArguments = @{
      JavaPath = $JavaPath
      JpexsJarPath = $JpexsJarPath
      VanillaInterfacePath = $VanillaInterfacePath
      OutputDirectory = $bootstrapMovieDirectory
      WorkDirectory = $resolvedWorkDirectory
      ManifestPath = @($bootstrapProfile.ManifestPaths)
      SkipOverrides = $true
    }
    if ($KeepWork) {
      $compileArguments.KeepWork = $true
    }
    if ($UpdateExpectedHashes) {
      $compileArguments.UpdateExpectedHashes = $true
    }
    if ($AuxiliaryMarkerProbe) {
      $compileArguments.AuxiliaryMarkerProbe = $true
    }
    Write-Host -ForegroundColor Green "Compiling the '$($bootstrapProfile.Name)' validated HUD host movies"
    & (Join-Path $PSScriptRoot 'compileScaleform.ps1') @compileArguments
    foreach ($movieName in @($bootstrapProfile.MovieNames)) {
      [void](Resolve-RequiredFile `
        -Path (Join-Path $bootstrapMovieDirectory $movieName) `
        -Description "$($bootstrapProfile.Name) compiled movie '$movieName'")
    }
  }

  foreach ($movieProfileName in @($auxiliaryProfiles.Keys | Sort-Object)) {
    $movieProfile = $auxiliaryProfiles[$movieProfileName]
    $auxiliaryProfileDirectory = Join-Path (Join-Path $buildDirectory 'movies') "auxiliary-$movieProfileName"
    New-Item -ItemType Directory -Force -Path $auxiliaryProfileDirectory | Out-Null
    $auxiliaryProfileDirectories[$movieProfileName] = $auxiliaryProfileDirectory
    $auxiliaryCompileArguments = @{
      JavaPath = $JavaPath
      JpexsJarPath = $JpexsJarPath
      OutputDirectory = $auxiliaryProfileDirectory
      WorkDirectory = $resolvedWorkDirectory
      BuildManifestPath = $movieProfile.AuxiliaryManifestPath
    }
    if ($KeepWork) {
      $auxiliaryCompileArguments.KeepWork = $true
    }
    if ($UpdateExpectedHashes) {
      $auxiliaryCompileArguments.UpdateExpectedHashes = $true
    }
    if ($AuxiliaryMarkerProbe) {
      $auxiliaryCompileArguments.MarkerProbe = $true
    }
    Write-Host -ForegroundColor Green "Compiling the '$movieProfileName' validated auxiliary movie"
    & (Join-Path $PSScriptRoot 'compileScaleformAuxiliaryV2.ps1') @auxiliaryCompileArguments
    [void](Resolve-RequiredFile `
      -Path (Join-Path $auxiliaryProfileDirectory 'venworkscui.swf') `
      -Description "$movieProfileName auxiliary movie")
  }

  $sharedMovieDirectory = $null
  if ($sharedMovieNames.Count -ne 0) {
    if ($sharedMovieNames.Count -ne 4) {
      throw 'HUD-message movie profiles must declare exactly four build outputs.'
    }
    $sharedMovieDirectory = Join-Path (Join-Path $buildDirectory "movies") "shared-overrides"
    New-Item -ItemType Directory -Force -Path $sharedMovieDirectory | Out-Null
    $overrideCompileArguments = @{
      JavaPath = $JavaPath
      JpexsJarPath = $JpexsJarPath
      VanillaInterfacePath = $VanillaInterfacePath
      OutputDirectory = @($sharedMovieDirectory)
      WorkDirectory = $resolvedWorkDirectory
    }
    if ($KeepWork) {
      $overrideCompileArguments.KeepWork = $true
    }
    if ($UpdateExpectedHashes) {
      $overrideCompileArguments.UpdateExpectedHashes = $true
    }
    Write-Host -ForegroundColor Green "Compiling the shared validated HUD-message GFX/SWF movies"
    & (Join-Path $PSScriptRoot "compileScaleformOverrides.ps1") @overrideCompileArguments
    foreach ($movieName in $sharedMovieNames) {
      [void](Resolve-RequiredFile `
        -Path (Join-Path $sharedMovieDirectory $movieName) `
        -Description "shared compiled movie '$movieName'")
    }
  }

  foreach ($variant in $variants) {
    $variantBuildProfile = $variantBuildProfiles[[string]$variant.VariantKey]
    $movieProfile = $variantMovieProfiles[[string]$variant.VariantKey]
    $bootstrapMovieDirectory = $bootstrapProfileDirectories[$variantBootstrapProfileKeys[[string]$variant.VariantKey]]
    $auxiliaryProfileDirectory = if ($null -eq $movieProfile.AuxiliaryManifestPath) {
      $null
    }
    else {
      $auxiliaryProfileDirectories[[string]$movieProfile.Name]
    }

    $stagingFolderPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $variant.StagingFolderPath))
    if (!(Test-Path -LiteralPath $stagingFolderPath -PathType Container)) {
      throw "$($variant.VariantName) staging folder does not exist. Run Tools/setupRepo.ps1 for the selected variant first."
    }
    $resolvedStagingPath = (Resolve-Path -LiteralPath $stagingFolderPath).Path
    if (!$Committed) {
      $stagingItem = Get-Item -LiteralPath $stagingFolderPath
      if ($stagingItem.LinkType -ne "Junction") {
        throw "$($variant.VariantName) staging folder must be a Junction: $stagingFolderPath"
      }
      $resolvedModulePath = Resolve-RequiredDirectory `
        -Path $variant.PluginModulePath `
        -Description "$($variant.VariantName) physical module folder"
      $stagingTargets = @($stagingItem.Target)
      if ($stagingTargets.Count -ne 1 -or
          ![string]::Equals(
            [System.IO.Path]::GetFullPath([string]$stagingTargets[0]),
            $resolvedModulePath,
            [System.StringComparison]::OrdinalIgnoreCase
          )) {
        throw "$($variant.VariantName) staging Junction does not target its configured physical module folder."
      }
    }

    $interfaceOutputDirectory = Join-Path $resolvedStagingPath "Interface"
    Remove-OwnedDirectory -Path $interfaceOutputDirectory -OwnerPath $resolvedStagingPath
    New-Item -ItemType Directory -Force -Path $interfaceOutputDirectory | Out-Null
    foreach ($deploymentMovie in @($movieProfile.DeploymentMovieDefinitions)) {
      $sourceDirectory = switch ([string]$deploymentMovie.SourceGroup) {
        'Bootstrap' { $bootstrapMovieDirectory; break }
        'HudMessages' { $sharedMovieDirectory; break }
        'Auxiliary' { $auxiliaryProfileDirectory; break }
        default { throw "$($variant.VariantName) movie deployment '$($deploymentMovie.FileName)' has unknown source group '$($deploymentMovie.SourceGroup)'." }
      }
      $sourceMoviePath = Resolve-RequiredFile `
        -Path (Join-Path $sourceDirectory ([string]$deploymentMovie.SourceFileName)) `
        -Description "$($variant.VariantName) deployment source '$($deploymentMovie.SourceFileName)'"
      Copy-Item `
        -LiteralPath $sourceMoviePath `
        -Destination (Join-Path $interfaceOutputDirectory ([string]$deploymentMovie.FileName)) `
        -Force
    }

    $hasCuiPayload = $variantBuildProfile.ContainsKey('LayoutSource') -and
      ![string]::IsNullOrWhiteSpace([string]$variantBuildProfile.LayoutSource)
    $hasDiagnosticXmlPayload = $variantBuildProfile.ContainsKey('DiagnosticXmlSource') -and
      ![string]::IsNullOrWhiteSpace([string]$variantBuildProfile.DiagnosticXmlSource)
    if ($hasCuiPayload -and $hasDiagnosticXmlPayload) {
      throw "$($variant.VariantName) profile must not combine production CUI configuration with a diagnostic XML payload."
    }
    if ($hasDiagnosticXmlPayload) {
      if ($movieProfile.AuxiliaryContract -cne 'diagnostic-bridge') {
        throw "$($variant.VariantName) diagnostic XML payload requires a diagnostic-bridge auxiliary profile."
      }
      $diagnosticXmlSourcePath = Resolve-RequiredFile `
        -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.DiagnosticXmlSource) -Description "$($variant.VariantName) diagnostic XML source") `
        -Description "$($variant.VariantName) diagnostic XML source"
      $diagnosticCuiOutputDirectory = Join-Path $interfaceOutputDirectory "VenworksCUI"
      New-Item -ItemType Directory -Force -Path $diagnosticCuiOutputDirectory | Out-Null
      Copy-ProfilePayloadFile `
        -SourcePath $diagnosticXmlSourcePath `
        -DestinationPath (Join-Path $diagnosticCuiOutputDirectory "layout.xml")
    }
    if ($hasCuiPayload) {
      Assert-UniqueSafeFileNames -FileNames @($variantBuildProfile.ComponentFileNames) -Context "$($variant.VariantName) component profile"
      Assert-UniqueSafeFileNames -FileNames @($variantBuildProfile.AssetFileNames) -Context "$($variant.VariantName) asset profile"
      Assert-UniqueSafeFileNames -FileNames @($variantBuildProfile.PaletteFileNames) -Context "$($variant.VariantName) palette profile"
      Assert-UniqueSafeFileNames -FileNames @([string]$variant.PaletteFileName) -Context "$($variant.VariantName) selected palette"

      $layoutSourcePath = Resolve-RequiredFile `
        -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.LayoutSource) -Description "$($variant.VariantName) layout source") `
        -Description "$($variant.VariantName) layout source"
      $componentSourceDirectory = Resolve-RequiredDirectory `
        -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.ComponentSourceDirectory) -Description "$($variant.VariantName) component source") `
        -Description "$($variant.VariantName) component source directory"

      $cuiOutputDirectory = Join-Path $interfaceOutputDirectory "VenworksCUI"
      $componentOutputDirectory = Join-Path $cuiOutputDirectory "components"
      New-Item -ItemType Directory -Force -Path $componentOutputDirectory | Out-Null

      $paletteMode = [string]$variantBuildProfile.PaletteMode
      $selectedPaletteFileName = [string]$variant.PaletteFileName
      $layoutText = [System.IO.File]::ReadAllText($layoutSourcePath)
      $literalColors = $null
      if ($paletteMode -ceq "External") {
        if (@($variantBuildProfile.PaletteFileNames | Where-Object { [string]$_ -ceq $selectedPaletteFileName }).Count -ne 1) {
          throw "$($variant.VariantName) selected palette '$selectedPaletteFileName' is not present exactly once in its payload profile."
        }
        $paletteMatches = @([regex]::Matches($layoutText, '\bpalette="[^"]+"'))
        if ($paletteMatches.Count -ne 1) {
          throw "$($variant.VariantName) external-palette layout must contain exactly one palette selector."
        }
        $layoutText = [regex]::Replace(
          $layoutText,
          '\bpalette="[^"]+"',
          "palette=`"$selectedPaletteFileName`"",
          1
        )
      }
      elseif ($paletteMode -ceq "Literal") {
        if ($layoutText -match '@palette\.|\bpalette="') {
          throw "$($variant.VariantName) literal-palette layout must already contain literal values and no palette selector."
        }
        $literalPalettePath = Resolve-RequiredFile `
          -Path (Join-Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PaletteSourceDirectory) -Description "$($variant.VariantName) palette source") $selectedPaletteFileName) `
          -Description "$($variant.VariantName) literal palette"
        $literalColors = Get-LiteralPaletteColors -PalettePath $literalPalettePath
      }
      else {
        throw "$($variant.VariantName) profile selects unsupported palette mode '$paletteMode'."
      }
      Write-Utf8WithoutBom -Path (Join-Path $cuiOutputDirectory "layout.xml") -Text $layoutText

      foreach ($componentFileName in @($variantBuildProfile.ComponentFileNames)) {
        $componentSourcePath = Resolve-RequiredFile `
          -Path (Join-Path $componentSourceDirectory ([string]$componentFileName)) `
          -Description "$($variant.VariantName) component '$componentFileName'"
        $componentOutputPath = Join-Path $componentOutputDirectory ([string]$componentFileName)
        if ($paletteMode -ceq "Literal") {
          $componentText = Resolve-PaletteColorReferences `
            -Text ([System.IO.File]::ReadAllText($componentSourcePath)) `
            -ColorValues $literalColors `
            -Context "$($variant.VariantName) component '$componentFileName'"
          $componentText = $componentText.TrimEnd([char[]]"`r`n") + [Environment]::NewLine
          Write-Utf8WithoutBom -Path $componentOutputPath -Text $componentText
        }
        else {
          Copy-ProfilePayloadFile `
            -SourcePath $componentSourcePath `
            -DestinationPath $componentOutputPath
        }
      }

      if (@($variantBuildProfile.AssetFileNames).Count -ne 0) {
        $assetSourceDirectory = Resolve-RequiredDirectory `
          -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.AssetSourceDirectory) -Description "$($variant.VariantName) asset source") `
          -Description "$($variant.VariantName) asset source directory"
        $assetOutputDirectory = Join-Path $cuiOutputDirectory "Assets"
        New-Item -ItemType Directory -Force -Path $assetOutputDirectory | Out-Null
        foreach ($assetFileName in @($variantBuildProfile.AssetFileNames)) {
          Copy-ProfilePayloadFile `
            -SourcePath (Resolve-RequiredFile -Path (Join-Path $assetSourceDirectory ([string]$assetFileName)) -Description "$($variant.VariantName) asset '$assetFileName'") `
            -DestinationPath (Join-Path $assetOutputDirectory ([string]$assetFileName))
        }
      }

      if (@($variantBuildProfile.PaletteFileNames).Count -ne 0) {
        $paletteSourceDirectory = Resolve-RequiredDirectory `
          -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PaletteSourceDirectory) -Description "$($variant.VariantName) palette source") `
          -Description "$($variant.VariantName) palette source directory"
        $paletteOutputDirectory = Join-Path $cuiOutputDirectory "palettes"
        New-Item -ItemType Directory -Force -Path $paletteOutputDirectory | Out-Null
        foreach ($paletteFileName in @($variantBuildProfile.PaletteFileNames)) {
          Copy-ProfilePayloadFile `
            -SourcePath (Resolve-RequiredFile -Path (Join-Path $paletteSourceDirectory ([string]$paletteFileName)) -Description "$($variant.VariantName) palette '$paletteFileName'") `
            -DestinationPath (Join-Path $paletteOutputDirectory ([string]$paletteFileName))
        }
      }

      [xml]$stagedLayout = Get-Content -LiteralPath (Join-Path $cuiOutputDirectory "layout.xml") -Raw
      $includedComponentFileNames = @($stagedLayout.SelectNodes('/venworksCUI/includes/include') | ForEach-Object {
        [string]$_.src
      } | Sort-Object)
      $profileComponentFileNames = @($variantBuildProfile.ComponentFileNames | ForEach-Object { [string]$_ } | Sort-Object)
      if ($includedComponentFileNames.Count -ne $profileComponentFileNames.Count) {
        throw "$($variant.VariantName) layout includes $($includedComponentFileNames.Count) component files; its profile declares $($profileComponentFileNames.Count)."
      }
      for ($index = 0; $index -lt $profileComponentFileNames.Count; $index++) {
        if ($includedComponentFileNames[$index] -cne $profileComponentFileNames[$index]) {
          throw "$($variant.VariantName) layout/profile component mismatch. Expected '$($profileComponentFileNames[$index])'; found '$($includedComponentFileNames[$index])'."
        }
      }

      if ($paletteMode -ceq "Literal") {
        $configurationText = @(
          Get-ChildItem -LiteralPath $cuiOutputDirectory -Recurse -File -Filter "*.xml" |
            ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }
        ) -join "`n"
        if ($configurationText -match '(?i)<svg\b|\.svg\b|@palette\.|\bpalette="' -or
            (Test-Path -LiteralPath (Join-Path $cuiOutputDirectory "Assets")) -or
            (Test-Path -LiteralPath (Join-Path $cuiOutputDirectory "palettes")) -or
            @(Get-ChildItem -LiteralPath $interfaceOutputDirectory -Recurse -File -Include "*.svg","*.dds").Count -ne 0) {
          throw "$($variant.VariantName) literal payload retains external SVG, palette, or DDS content."
        }
      }
    }

    if (![string]::IsNullOrWhiteSpace([string]$variantBuildProfile.PluginSourcePath)) {
      $pluginSourcePath = Resolve-RequiredFile `
        -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PluginSourcePath) -Description "$($variant.VariantName) plugin source") `
        -Description "$($variant.VariantName) plugin source"
      $pluginOutputPath = Join-Path $resolvedStagingPath "$($variant.PackageBaseName).esm"
      Copy-Item -LiteralPath $pluginSourcePath -Destination $pluginOutputPath -Force
      if ((Get-FileHash -LiteralPath $pluginSourcePath -Algorithm SHA256).Hash -cne
          (Get-FileHash -LiteralPath $pluginOutputPath -Algorithm SHA256).Hash) {
        throw "$($variant.VariantName) plugin copy is not byte-identical to its source stub."
      }
    }

    Write-Host -ForegroundColor Green "Built independent $($variant.VariantName) payload in $interfaceOutputDirectory"
  }
}
finally {
  if ($KeepWork) {
    Write-Host -ForegroundColor Yellow "Variant build files retained at $buildDirectory"
  }
  elseif (Test-Path -LiteralPath $buildDirectory -PathType Container) {
    Remove-OwnedDirectory -Path $buildDirectory -OwnerPath $resolvedWorkDirectory
  }
}
