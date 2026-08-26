<#
.SYNOPSIS
Verifies staged or committed artifacts for release variants.

.PARAMETER VariantKeys
One or more keys from `$Global:ReleaseVariants`. Omit this parameter to process
all release variants. `VariantKey` remains a compatibility alias.
#>
[CmdletBinding()]
param(
  [Alias("VariantKey")]
  [string[]]$VariantKeys,

  [switch]$Committed
)

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
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath) -or
      [System.IO.Path]::IsPathRooted($RelativePath) -or
      $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "$Description must define a safe repository-relative path: $RelativePath"
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

function Assert-NotGitLfsPointer {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $resolvedPath = Resolve-RequiredFile -Path $Path -Description $Description
  $stream = [System.IO.File]::OpenRead($resolvedPath)
  try {
    $buffer = [byte[]]::new([Math]::Min(128, [int]$stream.Length))
    [void]$stream.Read($buffer, 0, $buffer.Length)
  }
  finally {
    $stream.Dispose()
  }
  $prefix = [System.Text.Encoding]::UTF8.GetString($buffer)
  if ($prefix.StartsWith("version https://git-lfs.github.com/spec/v1", [System.StringComparison]::Ordinal)) {
    throw "$Description remains a Git LFS pointer: $resolvedPath"
  }
}

function Assert-MatchingText {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedText,

    [Parameter(Mandatory = $true)]
    [string]$ActualPath,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $actualText = [System.IO.File]::ReadAllText((Resolve-RequiredFile -Path $ActualPath -Description $Description))
  if ($actualText -cne $ExpectedText) {
    throw "$Description differs from its profile-derived expected content."
  }
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
    if ([string]::IsNullOrWhiteSpace($role) -or $value -notmatch '^#[0-9A-Fa-f]{6}$' -or $colors.ContainsKey($role)) {
      throw "Literal palette contains an invalid or duplicate color entry: $PalettePath"
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
  foreach ($referenceMatch in @([regex]::Matches(
    $resolvedText,
    '@palette\.colors\.([A-Za-z][A-Za-z0-9.-]*)'
  ))) {
    $role = [string]$referenceMatch.Groups[1].Value
    if (!$ColorValues.ContainsKey($role)) {
      throw "$Context references unknown palette color '$role'."
    }
    $resolvedText = $resolvedText.Replace([string]$referenceMatch.Value, [string]$ColorValues[$role])
  }
  if ($resolvedText -match '@palette\.') {
    throw "$Context retains an unresolved palette reference."
  }

  return $resolvedText
}

function Get-RelativeFileInventory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath
  )

  $resolvedRoot = Resolve-RequiredDirectory -Path $RootPath -Description "Payload directory"
  return @(
    Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File |
      ForEach-Object {
        $_.FullName.Substring($resolvedRoot.Length + 1).Replace(
          [System.IO.Path]::DirectorySeparatorChar,
          [System.IO.Path]::AltDirectorySeparatorChar
        )
      } |
      Sort-Object
  )
}

function Assert-Inventory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [string[]]$ExpectedPaths,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $actualPaths = @(Get-RelativeFileInventory -RootPath $RootPath)
  $expectedPaths = @($ExpectedPaths | Sort-Object)
  if ($actualPaths.Count -ne $expectedPaths.Count) {
    throw "$Description contains $($actualPaths.Count) files; expected $($expectedPaths.Count)."
  }
  for ($index = 0; $index -lt $expectedPaths.Count; $index++) {
    if ($actualPaths[$index] -cne $expectedPaths[$index]) {
      throw "$Description inventory mismatch. Expected '$($expectedPaths[$index])'; found '$($actualPaths[$index])'."
    }
  }
}

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
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
. (Resolve-RequiredFile `
  -Path (Join-Path $PSScriptRoot "sharedEmbeddedScaleformLayout.ps1") `
  -Description "embedded Scaleform layout helper")

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)
$archiveDefinitions = [ordered]@{
  "Main" = [pscustomobject]@{ FileSuffix = "Main.ba2"; Required = $true }
  "Textures" = [pscustomobject]@{ FileSuffix = "Textures.ba2"; Required = $false }
  "Main_XBox" = [pscustomobject]@{ FileSuffix = "Main_XBox.ba2"; Required = $true }
  "Textures_XBox" = [pscustomobject]@{ FileSuffix = "Textures_XBox.ba2"; Required = $false }
  "Main_PS" = [pscustomobject]@{ FileSuffix = "Main_PS.ba2"; Required = $true }
  "Textures_PS" = [pscustomobject]@{ FileSuffix = "Textures_PS.ba2"; Required = $false }
}

$releaseVariants = @($Global:ReleaseVariants)
if ($releaseVariants.Count -eq 0) {
  throw "ReleaseVariants must contain at least one canonical plugin stub."
}
$canonicalPluginVariant = $releaseVariants[0]
$canonicalPluginStagingPath = Resolve-RequiredDirectory `
  -Path (Join-Path $repositoryRoot ([string]$canonicalPluginVariant.StagingFolderPath)) `
  -Description "$($canonicalPluginVariant.VariantName) canonical plugin staging folder"
$canonicalPluginPath = Resolve-RequiredFile `
  -Path (Join-Path $canonicalPluginStagingPath "$($canonicalPluginVariant.PackageBaseName).esm") `
  -Description "$($canonicalPluginVariant.VariantName) canonical plugin stub"
Assert-NotGitLfsPointer `
  -Path $canonicalPluginPath `
  -Description "$($canonicalPluginVariant.VariantName) canonical plugin stub"
$canonicalPluginHash = Get-Sha256 -Path $canonicalPluginPath

foreach ($variant in $variants) {
  $profilePath = Resolve-RequiredFile `
    -Path (Join-Path $repositoryRoot "Scaleform\variants\$($variant.VariantKey)\build.psd1") `
    -Description "$($variant.VariantName) build profile"
  $variantBuildProfile = Import-PowerShellDataFile -LiteralPath $profilePath
  $movieProfile = Get-VariantScaleformMovieProfile `
    -RepositoryRoot $repositoryRoot `
    -VariantBuildProfile $variantBuildProfile

  $stagingPath = Resolve-RequiredDirectory `
    -Path (Join-Path $repositoryRoot ([string]$variant.StagingFolderPath)) `
    -Description "$($variant.VariantName) staging folder"
  if (!$Committed) {
    $stagingItem = Get-Item -LiteralPath $variant.StagingFolderPath
    if ($stagingItem.LinkType -ne "Junction") {
      throw "$($variant.VariantName) staging folder must be a Junction."
    }
    $resolvedModulePath = Resolve-RequiredDirectory -Path $variant.PluginModulePath -Description "$($variant.VariantName) physical module folder"
    $stagingTargets = @($stagingItem.Target)
    if ($stagingTargets.Count -ne 1 -or
        ![string]::Equals(
          [System.IO.Path]::GetFullPath([string]$stagingTargets[0]),
          $resolvedModulePath,
          [System.StringComparison]::OrdinalIgnoreCase
        )) {
      throw "$($variant.VariantName) staging Junction targets the wrong physical module folder."
    }
  }

  $interfacePath = Resolve-RequiredDirectory -Path (Join-Path $stagingPath "Interface") -Description "$($variant.VariantName) Interface payload"
  $cuiPath = Join-Path $interfacePath "VenworksCUI"
  if ($movieProfile.ConfigurationMode -ceq "External") {
    $cuiPath = Resolve-RequiredDirectory -Path $cuiPath -Description "$($variant.VariantName) CUI payload"
    $expectedCuiInventory = @("layout.xml")
    $expectedCuiInventory += @($variantBuildProfile.ComponentFileNames | ForEach-Object { "components/$_" })
    $expectedCuiInventory += @($variantBuildProfile.AssetFileNames | ForEach-Object { "Assets/$_" })
    $expectedCuiInventory += @($variantBuildProfile.PaletteFileNames | ForEach-Object { "palettes/$_" })
    Assert-Inventory -RootPath $cuiPath -ExpectedPaths $expectedCuiInventory -Description "$($variant.VariantName) CUI payload"
  }
  else {
    if (Test-Path -LiteralPath $cuiPath) {
      throw "$($variant.VariantName) embedded payload must not contain an Interface/VenworksCUI directory."
    }
    if (@(Get-ChildItem -LiteralPath $interfacePath -Recurse -File -Filter "*.xml").Count -ne 0) {
      throw "$($variant.VariantName) embedded payload must not contain loose XML configuration."
    }
  }

  $verifiedMoviePaths = @{}
  foreach ($movie in @($movieProfile.MovieDefinitions)) {
    $moviePath = Resolve-RequiredFile -Path (Join-Path $interfacePath $movie.FileName) -Description "$($variant.VariantName) $($movie.FileName)"
    $expectedHash = Read-ExpectedSha256 -Path $movie.ExpectedHashPath
    $actualHash = Get-Sha256 -Path $moviePath
    if ($actualHash -cne $expectedHash) {
      throw "$($variant.VariantName) $($movie.FileName) hash mismatch. Expected $expectedHash; found $actualHash."
    }
    $verifiedMoviePaths[[string]$movie.FileName] = $moviePath
  }

  $layoutSourcePath = Resolve-RequiredFile `
    -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.LayoutSource) -Description "$($variant.VariantName) layout source") `
    -Description "$($variant.VariantName) layout source"
  if ($movieProfile.ConfigurationMode -ceq "Embedded") {
    $resolvedEmbeddedLayoutText = Get-VenworksEmbeddedLayoutText `
      -RepositoryRoot $repositoryRoot `
      -Variant $variant `
      -VariantBuildProfile $variantBuildProfile
    [xml]$resolvedEmbeddedLayout = $resolvedEmbeddedLayoutText
    if (@($resolvedEmbeddedLayout.SelectNodes('//include|//includes')).Count -ne 0 -or
        @($resolvedEmbeddedLayout.SelectNodes('/venworksCUI/components/group')).Count -ne 8) {
      throw "$($variant.VariantName) embedded layout did not resolve all six component imports into the two root components."
    }
    foreach ($movie in @($movieProfile.MovieDefinitions | Where-Object {
      [string]$_.FileName -in @('hudmenu.gfx', 'hudmenu_lrg.gfx')
    })) {
      Assert-VenworksEmbeddedLayoutInMovie `
        -MoviePath $verifiedMoviePaths[[string]$movie.FileName] `
        -EmbeddedLayoutText $resolvedEmbeddedLayoutText `
        -Description "$($variant.VariantName) $($movie.FileName)"
    }
    $cuiPath = Split-Path -Parent $layoutSourcePath
  }
  if ($movieProfile.ConfigurationMode -ceq "External") {
  $expectedLayoutText = [System.IO.File]::ReadAllText($layoutSourcePath)
  $literalColors = $null
  $selectedPaletteFileName = [string]$variant.PaletteFileName
  if ([string]$variantBuildProfile.PaletteMode -ceq "External") {
    $paletteMatches = @([regex]::Matches($expectedLayoutText, '\bpalette="[^"]+"'))
    if ($paletteMatches.Count -ne 1 -or
        @($variantBuildProfile.PaletteFileNames | Where-Object { [string]$_ -ceq $selectedPaletteFileName }).Count -ne 1) {
      throw "$($variant.VariantName) external palette profile is invalid."
    }
    $expectedLayoutText = [regex]::Replace(
      $expectedLayoutText,
      '\bpalette="[^"]+"',
      "palette=`"$selectedPaletteFileName`"",
      1
    )
  }
  elseif ([string]$variantBuildProfile.PaletteMode -ceq "Literal") {
    $literalPalettePath = Resolve-RequiredFile `
      -Path (Join-Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PaletteSourceDirectory) -Description "$($variant.VariantName) palette source") $selectedPaletteFileName) `
      -Description "$($variant.VariantName) literal palette"
    $literalColors = Get-LiteralPaletteColors -PalettePath $literalPalettePath
    if ($expectedLayoutText -match '@palette\.|\bpalette="') {
      throw "$($variant.VariantName) literal layout source retains a palette selector or reference."
    }
  }
  else {
    throw "$($variant.VariantName) profile selects unsupported palette mode '$($variantBuildProfile.PaletteMode)'."
  }
  $layoutPath = Join-Path $cuiPath "layout.xml"
  Assert-MatchingText -ExpectedText $expectedLayoutText -ActualPath $layoutPath -Description "$($variant.VariantName) layout"

  $componentSourceDirectory = Resolve-RequiredDirectory `
    -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.ComponentSourceDirectory) -Description "$($variant.VariantName) component source") `
    -Description "$($variant.VariantName) component source directory"
  foreach ($componentFileName in @($variantBuildProfile.ComponentFileNames)) {
    $componentSourcePath = Resolve-RequiredFile -Path (Join-Path $componentSourceDirectory ([string]$componentFileName)) -Description "$($variant.VariantName) component source '$componentFileName'"
    $expectedComponentText = [System.IO.File]::ReadAllText($componentSourcePath)
    if ([string]$variantBuildProfile.PaletteMode -ceq "Literal") {
      $expectedComponentText = Resolve-PaletteColorReferences `
        -Text $expectedComponentText `
        -ColorValues $literalColors `
        -Context "$($variant.VariantName) component '$componentFileName'"
      $expectedComponentText = $expectedComponentText.TrimEnd([char[]]"`r`n") + [Environment]::NewLine
    }
    Assert-MatchingText `
      -ExpectedText $expectedComponentText `
      -ActualPath (Join-Path (Join-Path $cuiPath "components") ([string]$componentFileName)) `
      -Description "$($variant.VariantName) component '$componentFileName'"
  }

  foreach ($assetFileName in @($variantBuildProfile.AssetFileNames)) {
    $sourcePath = Resolve-RequiredFile -Path (Join-Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.AssetSourceDirectory) -Description "$($variant.VariantName) asset source") ([string]$assetFileName)) -Description "$($variant.VariantName) asset source '$assetFileName'"
    $stagedPath = Resolve-RequiredFile -Path (Join-Path (Join-Path $cuiPath "Assets") ([string]$assetFileName)) -Description "$($variant.VariantName) asset '$assetFileName'"
    if ((Get-Sha256 -Path $sourcePath) -cne (Get-Sha256 -Path $stagedPath)) {
      throw "$($variant.VariantName) asset '$assetFileName' differs from its source."
    }
  }
  foreach ($paletteFileName in @($variantBuildProfile.PaletteFileNames)) {
    $sourcePath = Resolve-RequiredFile -Path (Join-Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PaletteSourceDirectory) -Description "$($variant.VariantName) palette source") ([string]$paletteFileName)) -Description "$($variant.VariantName) palette source '$paletteFileName'"
    $stagedPath = Resolve-RequiredFile -Path (Join-Path (Join-Path $cuiPath "palettes") ([string]$paletteFileName)) -Description "$($variant.VariantName) palette '$paletteFileName'"
    if ((Get-Sha256 -Path $sourcePath) -cne (Get-Sha256 -Path $stagedPath)) {
      throw "$($variant.VariantName) palette '$paletteFileName' differs from its source."
    }
  }

  [xml]$layout = Get-Content -LiteralPath $layoutPath -Raw
  $includedFileNames = @($layout.SelectNodes('/venworksCUI/includes/include') | ForEach-Object { [string]$_.src } | Sort-Object)
  $profileFileNames = @($variantBuildProfile.ComponentFileNames | ForEach-Object { [string]$_ } | Sort-Object)
  if ($includedFileNames.Count -ne $profileFileNames.Count) {
    throw "$($variant.VariantName) layout/profile component count differs."
  }
  for ($index = 0; $index -lt $profileFileNames.Count; $index++) {
    if ($includedFileNames[$index] -cne $profileFileNames[$index]) {
      throw "$($variant.VariantName) layout/profile component mismatch."
    }
  }
  }
  else {
    [xml]$layout = Get-Content -LiteralPath $layoutSourcePath -Raw
  }

  if ([string]$variant.VariantKey -ceq "MIN") {
    $radarIncludes = @($layout.SelectNodes('/venworksCUI/includes/include[@id="contact-radar"]'))
    if ($radarIncludes.Count -ne 1 -or
        [string]$radarIncludes[0].x -cne "-64" -or
        [string]$radarIncludes[0].y -cne "-36" -or
        @($layout.SelectNodes('/venworksCUI/includes/include[@id="faction-display"]')).Count -ne 0 -or
        (Test-Path -LiteralPath (Join-Path $cuiPath "components\faction-display.xml"))) {
      throw "Minimalist must omit the faction display and keep the contact radar in its former upper-left position."
    }
    $scannerText = [System.IO.File]::ReadAllText((Join-Path $cuiPath "components\environmental-hazard-scanner.xml"))
    if ($scannerText -notmatch 'id="planet\.solar-transition" x="14" y="52" width="332" height="22"' -or
        $scannerText -notmatch 'source="environment\.solarTransitionCountdown" format="raw"' -or
        $scannerText -match '<panel\b') {
      throw "Minimalist does not preserve the accepted dedicated solar-transition row."
    }
    $configurationText = if ($movieProfile.ConfigurationMode -ceq "Embedded") {
      $resolvedEmbeddedLayoutText
    }
    else {
      @(
        Get-ChildItem -LiteralPath $cuiPath -Recurse -File -Filter "*.xml" |
          ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }
      ) -join "`n"
    }
    if ($configurationText -match '(?i)<(?:svg|path|mask|icon|panel|providerSymbol)\b|\.svg\b|@palette\.|\bpalette="' -or
        $configurationText -match '(?i)equipment-rail' -or
        (Test-Path -LiteralPath (Join-Path $cuiPath "components\equipment-rail.xml")) -or
        @(Get-ChildItem -LiteralPath $interfacePath -Recurse -File -Include "*.svg","*.dds","*.png","*.jpg","*.jpeg").Count -ne 0) {
      throw "Minimalist contains a disabled XML capability, equipment rail, external palette, or image asset."
    }

    $fittedBackingDefinitions = @(
      [pscustomobject]@{ RelativePath = "layout.xml"; Id = "critical-health"; X = "0"; Y = "0"; Width = "320"; Height = "70"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "layout.xml"; Id = "vehicle-exit"; X = "0"; Y = "0"; Width = "184"; Height = "36"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\contact-radar.xml"; Id = "contact-radar"; X = "22"; Y = "21"; Width = "184"; Height = "184"; Shape = "ellipse" }
      [pscustomobject]@{ RelativePath = "components\environmental-hazard-scanner.xml"; Id = "environmental-hazard"; X = "0"; Y = "0"; Width = "360"; Height = "254"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\helmet-awareness.xml"; Id = "helmet.compass"; X = "0"; Y = "-58"; Width = "826"; Height = "48"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\helmet-awareness.xml"; Id = "helmet.threat"; X = "253"; Y = "12"; Width = "320"; Height = "24"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\player-status-scanner.xml"; Id = "player-status"; X = "0"; Y = "0"; Width = "360"; Height = "236"; Shape = "rectangle" }
      [pscustomobject]@{ RelativePath = "components\quest-tracker.xml"; Id = "quest-tracker"; X = "0"; Y = "0"; Width = "447"; Height = "90"; Shape = "rectangle" }
    )
    $fittedBackingDocuments = @{}
    $fittedBackingNodeCount = 0
    foreach ($relativePath in @($fittedBackingDefinitions.RelativePath | Sort-Object -Unique)) {
      [xml]$backingDocument = Get-Content -LiteralPath (Join-Path $cuiPath $relativePath) -Raw
      $fittedBackingDocuments[$relativePath] = $backingDocument
      $fittedBackingNodeCount += @($backingDocument.SelectNodes('//shape[contains(@id,".backing.")]')).Count
    }
    if ($fittedBackingNodeCount -ne ($fittedBackingDefinitions.Count * 2)) {
      throw "Minimalist must contain exactly two fitted backing layers for each approved readout footprint."
    }
    foreach ($backing in $fittedBackingDefinitions) {
      $backingDocument = $fittedBackingDocuments[[string]$backing.RelativePath]
      foreach ($layer in @(
        [pscustomobject]@{ Name = "base"; Z = "-2"; FillColor = "#0D1114"; FillOpacity = "0.28" },
        [pscustomobject]@{ Name = "tint"; Z = "-1"; FillColor = "#70CFE0"; FillOpacity = "0.10" }
      )) {
        $backingId = "$($backing.Id).backing.$($layer.Name)"
        $backingNodes = @($backingDocument.SelectNodes("//shape[@id='$backingId']"))
        if ($backingNodes.Count -ne 1) {
          throw "Minimalist fitted backing '$backingId' must appear exactly once in $($backing.RelativePath)."
        }
        $backingNode = $backingNodes[0]
        $authoredPaletteReference = $movieProfile.ConfigurationMode -ceq "Embedded" -and
          [string]$backing.RelativePath -cne "layout.xml"
        $expectedFillColor = if ($authoredPaletteReference) {
          if ([string]$layer.Name -ceq "base") { "@palette.colors.panel.background" } else { "@palette.colors.meter.oxygen" }
        }
        else {
          [string]$layer.FillColor
        }
        $expectedStrokeColor = if ($authoredPaletteReference) { "@palette.colors.panel.border" } else { "#D9E3E8" }
        $expectedAttributes = @{
          x = [string]$backing.X
          y = [string]$backing.Y
          width = [string]$backing.Width
          height = [string]$backing.Height
          z = [string]$layer.Z
          shape = [string]$backing.Shape
          fillColor = $expectedFillColor
          fillOpacity = [string]$layer.FillOpacity
          strokeColor = $expectedStrokeColor
          strokeOpacity = "0"
          strokeWidth = "0"
        }
        foreach ($attributeName in $expectedAttributes.Keys) {
          if ([string]$backingNode.GetAttribute($attributeName) -cne [string]$expectedAttributes[$attributeName]) {
            throw "Minimalist fitted backing '$backingId' has an unexpected '$attributeName' value."
          }
        }
      }
    }

    $sharedHudHash = Read-ExpectedSha256 -Path (Join-Path $repositoryRoot "Scaleform\hudmenu\validation\expected.sha256")
    $sharedLargeHudHash = Read-ExpectedSha256 -Path (Join-Path $repositoryRoot "Scaleform\hudmenu_lrg\validation\expected.sha256")
    if ((Get-Sha256 -Path (Join-Path $interfacePath "hudmenu.gfx")) -ceq $sharedHudHash -or
        (Get-Sha256 -Path (Join-Path $interfacePath "hudmenu_lrg.gfx")) -ceq $sharedLargeHudHash) {
      throw "Minimalist HUD movies must be profile-specific and differ from the shared themed movies."
    }

    $sourceProfile = Get-ScaleformSourceProfile -ManifestPath $movieProfile.ManifestPaths[0]
    $expectedExcludedClasses = @(
      'venworks/cui/CUIAssetManager.as',
      'venworks/cui/CUICompositeResolver.as',
      'venworks/cui/CUIIconLibrary.as',
      'venworks/cui/CUILayoutImportLoader.as',
      'venworks/cui/CUIPaletteLoader.as',
      'venworks/cui/CUISvgParser.as',
      'venworks/cui/CUISvgPathParser.as',
      'venworks/cui/components/CUIIcon.as',
      'venworks/cui/components/CUIMask.as',
      'venworks/cui/components/CUIPanel.as',
      'venworks/cui/components/CUIProviderSymbol.as',
      'venworks/cui/components/CUISvg.as',
      'venworks/cui/components/CUISvgPath.as'
    ) | ForEach-Object {
      $_.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    }
    $actualExcludedClasses = @($sourceProfile.ExcludedActionScriptPaths | Sort-Object)
    $expectedExcludedClasses = @($expectedExcludedClasses | Sort-Object)
    if ($actualExcludedClasses.Count -ne $expectedExcludedClasses.Count -or
        [string]::Join("`n", $actualExcludedClasses) -cne [string]::Join("`n", $expectedExcludedClasses)) {
      throw "Minimalist ActionScript exclusions do not match the approved external-loader, SVG, panel, icon, mask, composite, and equipment class inventory."
    }
    if ($sourceProfile.ValueProviders.Count -ne 10 -or
        $sourceProfile.ConditionProviders.Count -ne 7 -or
        $sourceProfile.CrossContextProviderCount -ne 3 -or
        @($sourceProfile.ValueProviders | Where-Object { $_ -in $sourceProfile.ConditionProviders }).Count -ne 3) {
      throw "Minimalist provider profile must retain exactly ten value, seven condition, and three cross-context registrations."
    }

    [xml]$minimalistManifest = Get-Content -LiteralPath $movieProfile.ManifestPaths[0] -Raw
    $minimalistManifestDirectory = Split-Path -Parent $movieProfile.ManifestPaths[0]
    $minimalistSourceRoot = Resolve-RequiredDirectory `
      -Path (Join-Path $minimalistManifestDirectory ([string]$minimalistManifest.scaleformBuild.actionScriptSource)) `
      -Description "Minimalist ActionScript source directory"
    $excludedLookup = @($sourceProfile.ExcludedActionScriptPaths)
    $verificationPatchDirectory = Join-Path $repositoryRoot "Scaleform\.work\verification-patches"
    New-Item -ItemType Directory -Force -Path $verificationPatchDirectory | Out-Null
    $verificationPatchId = [guid]::NewGuid().ToString("N")
    $verificationLayoutPath = Join-Path $verificationPatchDirectory "$verificationPatchId-layout.xml"
    $verificationPatchPath = Join-Path $verificationPatchDirectory "$verificationPatchId-patch.xml"
    [System.IO.File]::WriteAllText(
      $verificationLayoutPath,
      $resolvedEmbeddedLayoutText,
      [System.Text.UTF8Encoding]::new($false)
    )
    $verificationPatchPath = New-VenworksEmbeddedScaleformPatch `
      -SourcePatchPath $sourceProfile.ActionScriptPatchPath `
      -EmbeddedLayoutPath $verificationLayoutPath `
      -OutputPath $verificationPatchPath
    try {
    $transformedSource = @(
      Get-ChildItem -LiteralPath $minimalistSourceRoot -Recurse -File -Filter "*.as" |
        ForEach-Object {
          $relativeSourcePath = $_.FullName.Substring($minimalistSourceRoot.Length).TrimStart(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
          )
          if ($relativeSourcePath -notin $excludedLookup) {
            Get-ScaleformPatchedActionScript `
              -SourcePath $_.FullName `
              -RelativePath $relativeSourcePath `
              -PatchPath $verificationPatchPath
          }
        }
    ) -join "`n"
    foreach ($forbiddenToken in @($sourceProfile.ForbiddenBytecodeTokens)) {
      if ($transformedSource.Contains($forbiddenToken)) {
        throw "Minimalist transformed ActionScript retains forbidden token '$forbiddenToken'."
      }
    }
    if ([regex]::Matches($transformedSource, 'this\.subscribeProvider\s*\(\s*"').Count -ne 17) {
      throw "Minimalist transformed ActionScript does not contain the expected seventeen independent provider registrations."
    }
    if ($transformedSource -match 'CUILayoutImportLoader|CUIPaletteLoader|URLLoader|URLRequest|VenworksCUI/layout\.xml|VenworksCUI/components/') {
      throw "Minimalist transformed ActionScript retains an external configuration loader, URL API, or loose configuration path."
    }

    $statusEffectRelativePath = "venworks/cui/components/CUIStatusEffectBar.as"
    $statusEffectSourcePath = Join-Path $minimalistSourceRoot $statusEffectRelativePath
    $statusEffectSource = Get-ScaleformPatchedActionScript `
      -SourcePath $statusEffectSourcePath `
      -RelativePath $statusEffectRelativePath `
      -PatchPath $verificationPatchPath
    $statusBackgroundMethod = [regex]::Match(
      $statusEffectSource,
      '(?s)private function drawSlotBackground.*?(?=\s+private function drawFallbackIcon)'
    )
    if (!$statusBackgroundMethod.Success -or
        !$statusBackgroundMethod.Value.Contains('param1.graphics.beginFill(0x0D1114,0.28);') -or
        !$statusBackgroundMethod.Value.Contains('param1.graphics.beginFill(0x70CFE0,0.10);') -or
        [regex]::Matches($statusBackgroundMethod.Value, 'param1\.graphics\.drawRect\(').Count -ne 2 -or
        $statusBackgroundMethod.Value -match '(?i)drawPath|GraphicsPath|CUISvg|pathData') {
      throw "Minimalist active status-effect tiles must use only the approved two-layer native rectangle backing."
    }

    $scannerRelativePath = "venworks/cui/components/CUIScannerOverlay.as"
    $scannerSourcePath = Join-Path $minimalistSourceRoot $scannerRelativePath
    $scannerSource = Get-ScaleformPatchedActionScript `
      -SourcePath $scannerSourcePath `
      -RelativePath $scannerRelativePath `
      -PatchPath $verificationPatchPath
    $scannerOverlayMethod = [regex]::Match(
      $scannerSource,
      '(?s)private function createOverlay.*?(?=\s+private function drawCorners)'
    )
    $scannerThreatBacking = 'panelShape.graphics.drawRect(componentWidth / 2 - 112,0,224,26);'
    $scannerContactsBacking = 'panelShape.graphics.drawRect(componentWidth - 270,156,260,146);'
    if (!$scannerOverlayMethod.Success -or
        !$scannerOverlayMethod.Value.Contains('panelShape.graphics.beginFill(0x0D1114,0.28);') -or
        !$scannerOverlayMethod.Value.Contains('panelShape.graphics.beginFill(0x70CFE0,0.10);') -or
        $scannerOverlayMethod.Value.Split($scannerThreatBacking).Count -ne 3 -or
        $scannerOverlayMethod.Value.Split($scannerContactsBacking).Count -ne 3 -or
        [regex]::Matches($scannerOverlayMethod.Value, 'panelShape\.graphics\.drawRect\(').Count -ne 4 -or
        $scannerOverlayMethod.Value -match '(?i)drawPath|GraphicsPath|CUISvg|pathData') {
      throw "Minimalist scanner readouts must use only the approved dynamically positioned two-layer native rectangle backings."
    }
    }
    finally {
      Remove-Item -LiteralPath $verificationPatchPath -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $verificationLayoutPath -Force -ErrorAction SilentlyContinue
    }

    $seedPath = Resolve-RequiredFile `
      -Path (Join-Path $minimalistManifestDirectory ([string]$minimalistManifest.scaleformBuild.abcSeedPatch)) `
      -Description "Minimalist ABC seed"
    $seedText = [System.IO.File]::ReadAllText($seedPath)
    foreach ($excludedClass in $expectedExcludedClasses) {
      $excludedClassName = [System.IO.Path]::GetFileNameWithoutExtension($excludedClass)
      if ($seedText.Contains($excludedClassName)) {
        throw "Minimalist ABC seed retains excluded class '$excludedClassName'."
      }
    }
  }

  $pluginPath = Join-Path $stagingPath "$($variant.PackageBaseName).esm"
  Assert-NotGitLfsPointer -Path $pluginPath -Description "$($variant.VariantName) plugin"
  $pluginHash = Get-Sha256 -Path $pluginPath
  if ($pluginHash -cne $canonicalPluginHash) {
    throw "$($variant.VariantName) plugin is not byte-identical to the canonical $($canonicalPluginVariant.VariantName) stub."
  }
  if (![string]::IsNullOrWhiteSpace([string]$variantBuildProfile.PluginSourcePath)) {
    $pluginSourcePath = Resolve-RequiredFile -Path (Resolve-RepositoryPath -RelativePath ([string]$variantBuildProfile.PluginSourcePath) -Description "$($variant.VariantName) plugin source") -Description "$($variant.VariantName) plugin source"
    Assert-NotGitLfsPointer -Path $pluginSourcePath -Description "$($variant.VariantName) plugin source"
    if ((Get-Sha256 -Path $pluginSourcePath) -cne $pluginHash) {
      throw "$($variant.VariantName) plugin is not byte-identical to its configured source stub."
    }
  }

  $archiveFiles = @(Get-ChildItem -LiteralPath $stagingPath -File -Filter "*.ba2")
  $allowedArchiveNames = [System.Collections.Generic.List[string]]::new()
  foreach ($archiveTarget in @($variant.ArchiveTargets)) {
    if (!$archiveDefinitions.Contains([string]$archiveTarget)) {
      throw "$($variant.VariantName) defines unknown archive target '$archiveTarget'."
    }
    $definition = $archiveDefinitions[[string]$archiveTarget]
    $archiveName = "$($variant.PackageBaseName) - $($definition.FileSuffix)"
    $allowedArchiveNames.Add($archiveName)
    $archivePath = Join-Path $stagingPath $archiveName
    if ($definition.Required -and !(Test-Path -LiteralPath $archivePath -PathType Leaf)) {
      throw "$($variant.VariantName) is missing required archive '$archiveName'."
    }
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
      Assert-NotGitLfsPointer -Path $archivePath -Description "$($variant.VariantName) archive '$archiveName'"
    }
  }
  foreach ($archiveFile in $archiveFiles) {
    if (!$allowedArchiveNames.Contains($archiveFile.Name)) {
      throw "$($variant.VariantName) contains archive outside its configured targets: $($archiveFile.FullName)"
    }
  }

  Write-Host -ForegroundColor Green "$($variant.VariantName) profile, payload, movies, plugin, and archives are valid."
}
