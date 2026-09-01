[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
. (Join-Path $PSScriptRoot "sharedScaleformMovies.ps1")
. (Join-Path $PSScriptRoot "sharedScaleformProfiles.ps1")

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

function Assert-MatchingFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedPath,

    [Parameter(Mandatory = $true)]
    [string]$ActualPath,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $resolvedExpectedPath = Resolve-RequiredFile -Path $ExpectedPath -Description "$Description source"
  $resolvedActualPath = Resolve-RequiredFile -Path $ActualPath -Description "$Description staged file"
  $expectedText = [System.IO.File]::ReadAllText($resolvedExpectedPath).Replace("`r`n", "`n").Replace("`r", "`n")
  $actualBytes = [System.IO.File]::ReadAllBytes($resolvedActualPath)
  if ($actualBytes.Length -ge 3 -and
      $actualBytes[0] -eq 0xEF -and
      $actualBytes[1] -eq 0xBB -and
      $actualBytes[2] -eq 0xBF) {
    throw "$Description must use UTF-8 without a byte-order mark."
  }
  $actualText = [System.Text.UTF8Encoding]::new($false, $true).GetString($actualBytes)
  if ($actualText.Contains("`r")) {
    throw "$Description must use canonical LF line endings."
  }
  if ($actualText -cne $expectedText) {
    throw "$Description differs from its source after canonical text normalization."
  }
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
  $sortedExpectedPaths = @($ExpectedPaths | Sort-Object)
  if ($actualPaths.Count -ne $sortedExpectedPaths.Count) {
    throw "$Description contains $($actualPaths.Count) files; expected $($sortedExpectedPaths.Count)."
  }

  for ($index = 0; $index -lt $sortedExpectedPaths.Count; $index++) {
    if ($actualPaths[$index] -cne $sortedExpectedPaths[$index]) {
      throw "$Description contains an unexpected file inventory. Expected '$($sortedExpectedPaths[$index])'; found '$($actualPaths[$index])'."
    }
  }
}

function Assert-ExpectedLayout {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$StagedPath,

    [Parameter(Mandatory = $true)]
    [string]$PaletteFileName,

    [Parameter(Mandatory = $true)]
    [string]$VariantName
  )

  $resolvedSourcePath = Resolve-RequiredFile -Path $SourcePath -Description "Production layout source"
  $resolvedStagedPath = Resolve-RequiredFile -Path $StagedPath -Description "$VariantName staged layout"
  $sourceText = [System.IO.File]::ReadAllText($resolvedSourcePath).Replace("`r`n", "`n").Replace("`r", "`n")
  $paletteMatches = [regex]::Matches($sourceText, '\bpalette="[^"]+"')
  if ($paletteMatches.Count -ne 1) {
    throw "Expected exactly one palette selector in $resolvedSourcePath; found $($paletteMatches.Count)."
  }

  $expectedText = [regex]::Replace(
    $sourceText,
    '\bpalette="[^"]+"',
    "palette=`"$PaletteFileName`""
  )
  $expectedBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($expectedText)
  $actualBytes = [System.IO.File]::ReadAllBytes($resolvedStagedPath)
  if ($actualBytes.Length -ne $expectedBytes.Length) {
    throw "$VariantName layout length mismatch. Expected $($expectedBytes.Length) bytes; found $($actualBytes.Length)."
  }

  for ($index = 0; $index -lt $expectedBytes.Length; $index++) {
    if ($actualBytes[$index] -ne $expectedBytes[$index]) {
      throw "$VariantName layout differs from the production source beyond its expected '$PaletteFileName' palette selector."
    }
  }
}

$trackedPowerShellScripts = @(
  & git -C $repositoryRoot ls-files -- '*.ps1' |
    Where-Object { Test-Path -LiteralPath (Join-Path $repositoryRoot $_) -PathType Leaf }
)
if ($LASTEXITCODE -ne 0) {
  throw "Unable to inventory tracked PowerShell scripts."
}
if ($trackedPowerShellScripts.Count -eq 0) {
  throw "No tracked PowerShell scripts were found."
}

foreach ($relativeScriptPath in $trackedPowerShellScripts) {
  $scriptPath = Join-Path $repositoryRoot $relativeScriptPath
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$parseErrors
  )
  if ($parseErrors.Count -ne 0) {
    $messages = @($parseErrors | ForEach-Object { $_.Message }) -join '; '
    throw "PowerShell syntax validation failed for ${relativeScriptPath}: $messages"
  }
}
Write-Host "Validated PowerShell syntax for $($trackedPowerShellScripts.Count) tracked scripts."

$components = @(
  'contact-radar.xml',
  'faction-display.xml',
  'equipment-rail.xml',
  'environmental-hazard-scanner.xml',
  'helmet-awareness.xml',
  'player-status-scanner.xml',
  'quest-tracker.xml',
  'scanner-overlay.xml'
)
$palettes = @(
  'venworks.xml',
  'crimson-fleet.xml',
  'freestar-collective.xml',
  'trackers-alliance.xml',
  'starfield.xml'
)
$assets = @(
  'gallery-vector.svg',
  'venworks-logo.svg',
  'freestar-collective-logo.svg',
  'crimson-fleet-logo.svg',
  'trackers-alliance-logo.svg',
  'gallery-invalid.svg'
)
$variants = @(
  [pscustomobject]@{ Name = 'Venworks'; Directory = 'Staging-VWKS'; Palette = 'venworks.xml' },
  [pscustomobject]@{ Name = 'Crimson Fleet'; Directory = 'Staging-CF'; Palette = 'crimson-fleet.xml' },
  [pscustomobject]@{ Name = 'Freestar Collective'; Directory = 'Staging-FC'; Palette = 'freestar-collective.xml' },
  [pscustomobject]@{ Name = 'Trackers Alliance'; Directory = 'Staging-TA'; Palette = 'trackers-alliance.xml' }
)
$referenceBuildProfile = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'Scaleform/variants/VWKS/build.psd1')
$referenceMovieProfile = Get-VariantScaleformMovieProfile `
  -RepositoryRoot $repositoryRoot `
  -VariantBuildProfile $referenceBuildProfile
$movies = @($referenceMovieProfile.DeploymentMovieDefinitions)
if ($movies.Count -ne 9) {
  throw "The shared deployment profile must contain exactly nine Interface movies; found $($movies.Count)."
}

$explicitSharedBuildProfile = @{
  MovieProfile = 'shared'
  MovieManifestPaths = @(
    'Scaleform/hudmenu/build.xml'
    'Scaleform/hudmenu_lrg/build.xml'
    'Scaleform/hudmenu/build-swf.xml'
    'Scaleform/hudmenu_lrg/build-swf.xml'
  )
  AuxiliaryMovieManifestPath = 'Scaleform/venworkscui/build.xml'
}
$explicitSharedMovieProfile = Get-VariantScaleformMovieProfile `
  -RepositoryRoot $repositoryRoot `
  -VariantBuildProfile $explicitSharedBuildProfile
if ($explicitSharedMovieProfile.HostMode -cne 'auxiliary-bootstrap' -or
    $null -eq $explicitSharedMovieProfile.AuxiliaryManifestPath -or
    $null -eq $explicitSharedMovieProfile.SourceProfile -or
    @($explicitSharedMovieProfile.DeploymentMovieDefinitions).Count -ne 9) {
  throw 'Explicit auxiliary-bootstrap manifests must retain all nine shared runtime movies and their auxiliary source profile.'
}

$diagnosticBuildProfile = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'Scaleform/variants/PS5DBG/build.psd1')
$diagnosticMovieProfile = Get-VariantScaleformMovieProfile `
  -RepositoryRoot $repositoryRoot `
  -VariantBuildProfile $diagnosticBuildProfile
$diagnosticMovieNames = @($diagnosticMovieProfile.DeploymentMovieDefinitions | ForEach-Object { [string]$_.FileName })
$expectedDiagnosticMovieNames = @('hudmenu.gfx', 'hudmenu.swf', 'hudmenu_lrg.gfx', 'hudmenu_lrg.swf', 'venworkscui.swf')
if (!$diagnosticBuildProfile.ContainsKey('DiagnosticXmlSource') -or
    [string]$diagnosticBuildProfile.DiagnosticXmlSource -cne 'Scaleform/variants/PS5DBG/layout.xml' -or
    ($diagnosticBuildProfile.ContainsKey('LayoutSource') -and ![string]::IsNullOrWhiteSpace([string]$diagnosticBuildProfile.LayoutSource))) {
  throw 'The PS5 Debug profile must select only its isolated diagnostic XML source.'
}
if ($diagnosticMovieProfile.HostMode -cne 'auxiliary-bootstrap' -or
    $diagnosticMovieProfile.AuxiliaryContract -cne 'diagnostic-bridge' -or
    $null -eq $diagnosticMovieProfile.AuxiliaryManifestPath -or
    $null -ne $diagnosticMovieProfile.SourceProfile -or
    $diagnosticMovieProfile.IncludesHudMessageMovies -or
    $diagnosticMovieNames.Count -ne $expectedDiagnosticMovieNames.Count -or
    @($expectedDiagnosticMovieNames | Where-Object { $_ -notin $diagnosticMovieNames }).Count -ne 0) {
  throw 'The PS5 Debug profile must contain exactly four HUD host movies and one diagnostic auxiliary movie.'
}

$requiredDiagnosticHostInspectionTokens = @(
  '$MAIN_Font_Bold'
  'uncaughtErrorEvents'
  'indexOf'
  'preventDefault'
  'stopImmediatePropagation'
  'venworkscui.swf'
  'CUI-AUX-LOAD'
  'PS5DBG-03 AUX LOAD STARTED'
  'PS5DBG-04 AUX INITIALIZED'
  'PS5DBG-OK AUX COMPLETE'
  'PS5DBG-ERR AUX | '
)
foreach ($hostMovie in @($diagnosticMovieProfile.DeploymentMovieDefinitions | Where-Object { $_.SourceGroup -ceq 'Bootstrap' })) {
  foreach ($requiredToken in $requiredDiagnosticHostInspectionTokens) {
    if ($requiredToken -cnotin @($hostMovie.RequiredInspectionTokens)) {
      throw "The PS5 Debug host contract for $($hostMovie.FileName) is missing required inspection token '$requiredToken'."
    }
  }
}
if (@($diagnosticMovieProfile.DeploymentMovieDefinitions | Where-Object { $_.SourceGroup -ceq 'HudMessages' }).Count -ne 0 -or
    @($diagnosticMovieProfile.DeploymentMovieDefinitions | Where-Object {
      $_.SourceGroup -ceq 'Auxiliary' -and $_.FileName -ceq 'venworkscui.swf'
    }).Count -ne 1) {
  throw 'The PS5 Debug profile must exclude HUD-message movies and deploy exactly one auxiliary movie.'
}

$expectedInventory = @('layout.xml')
$expectedInventory += @($components | ForEach-Object { "components/$_" })
$expectedInventory += @($palettes | ForEach-Object { "palettes/$_" })
$expectedInventory += @($assets | ForEach-Object { "Assets/$_" })
$movieHashes = @{}
foreach ($movie in $movies) {
  $movieHashes[$movie.FileName] = [System.Collections.Generic.List[string]]::new()
}

$layoutSourcePath = Join-Path $repositoryRoot 'Scaleform/shared/fixtures/chronomark-provider-probe.xml'
$componentSourceRoot = Join-Path $repositoryRoot 'Scaleform/shared/fixtures/components'
$paletteSourceRoot = Join-Path $repositoryRoot 'Scaleform/shared/palettes'
$assetSourceRoot = Join-Path $repositoryRoot 'Scaleform/shared/assets'

foreach ($variant in $variants) {
  $interfaceRoot = Join-Path (Join-Path $repositoryRoot $variant.Directory) 'Interface'
  $payloadRoot = Join-Path $interfaceRoot 'VenworksCUI'
  Assert-Inventory `
    -RootPath $payloadRoot `
    -ExpectedPaths $expectedInventory `
    -Description "$($variant.Name) staged VenworksCUI payload"

  foreach ($movie in $movies) {
    $expectedHashPath = [string]$movie.ExpectedHashPath
    $expectedHash = Read-ExpectedSha256 -Path $expectedHashPath
    $moviePath = Resolve-RequiredFile `
      -Path (Join-Path $interfaceRoot $movie.FileName) `
      -Description "$($variant.Name) $($movie.FileName)"
    $actualHash = Get-Sha256 -Path $moviePath
    if ($actualHash -cne $expectedHash) {
      throw "$($variant.Name) $($movie.FileName) hash mismatch. Expected $expectedHash; found $actualHash."
    }
    $movieMetadata = Get-ScaleformMovieMetadata `
      -Path $moviePath `
      -Context "$($variant.Name) $($movie.FileName)" `
      -ExpectedSignature ([string]$movie.ExpectedSignature)
    if ($movieMetadata.StageWidth -ne 1920 -or
        $movieMetadata.StageHeight -ne 1080 -or
        $movieMetadata.FrameRate -ne 30 -or
        $movieMetadata.FrameCount -ne 1) {
      throw "$($variant.Name) $($movie.FileName) must be 1920x1080 at 30 fps with one frame; found $($movieMetadata.StageWidth)x$($movieMetadata.StageHeight) at $($movieMetadata.FrameRate) fps with $($movieMetadata.FrameCount) frames."
    }
    $movieHashes[$movie.FileName].Add($actualHash)
  }
  foreach ($component in $components) {
    Assert-MatchingFile `
      -ExpectedPath (Join-Path $componentSourceRoot $component) `
      -ActualPath (Join-Path (Join-Path $payloadRoot 'components') $component) `
      -Description "$($variant.Name) component $component"
  }
  foreach ($palette in $palettes) {
    Assert-MatchingFile `
      -ExpectedPath (Join-Path $paletteSourceRoot $palette) `
      -ActualPath (Join-Path (Join-Path $payloadRoot 'palettes') $palette) `
      -Description "$($variant.Name) palette $palette"
  }
  foreach ($asset in $assets) {
    Assert-MatchingFile `
      -ExpectedPath (Join-Path $assetSourceRoot $asset) `
      -ActualPath (Join-Path (Join-Path $payloadRoot 'Assets') $asset) `
      -Description "$($variant.Name) asset $asset"
  }

  Assert-ExpectedLayout `
    -SourcePath $layoutSourcePath `
    -StagedPath (Join-Path $payloadRoot 'layout.xml') `
    -PaletteFileName $variant.Palette `
    -VariantName $variant.Name
}

foreach ($movie in $movies) {
  if (@($movieHashes[$movie.FileName] | Select-Object -Unique).Count -ne 1) {
    throw "The four themed staged $($movie.FileName) files are not byte-identical."
  }
}

Write-Host "Verified committed Scaleform movie hashes and complete staged VenworksCUI payloads for the four themed variants."

$archive2ScriptReferences = @(
  & git -C $repositoryRoot grep -l -F "Archive2.exe" -- `
    "Tools/*.ps1" `
    ":(exclude)Tools/verifyCommittedRelease.ps1" `
    ":(exclude)Tools/verifyCommittedReleaseV2.ps1"
)
if ($LASTEXITCODE -ne 0) {
  throw "Unable to inventory PowerShell Archive2 references."
}
$normalizedArchive2ScriptReferences = @(
  $archive2ScriptReferences |
    ForEach-Object { $_.Replace('\', '/') } |
    Sort-Object
)
$expectedArchive2ScriptReferences = @(
  'Tools/createPackages.ps1',
  'Tools/createPackagesV2.ps1'
)
if ($normalizedArchive2ScriptReferences.Count -ne $expectedArchive2ScriptReferences.Count -or
    [string]::Join("`n", $normalizedArchive2ScriptReferences) -cne
    [string]::Join("`n", $expectedArchive2ScriptReferences)) {
  throw "Only the shared release packaging script may invoke Archive2.exe. Found: $($normalizedArchive2ScriptReferences -join ', ')"
}
Write-Host "Verified the single shared Archive2 packaging owner."

$packageScriptPath = Join-Path $repositoryRoot 'Tools/createPackagesV2.ps1'
$packageScriptSource = [System.IO.File]::ReadAllText($packageScriptPath)
$archiveCompressionExpectations = @(
  [pscustomobject]@{ Name = 'Main'; Format = 'General'; Compression = 'None' },
  [pscustomobject]@{ Name = 'Textures'; Format = 'DDS'; Compression = 'LZ4' },
  [pscustomobject]@{ Name = 'Main_XBox'; Format = 'General'; Compression = 'None' },
  [pscustomobject]@{ Name = 'Textures_XBox'; Format = 'XBoxDDS'; Compression = 'LZ4' },
  [pscustomobject]@{ Name = 'Main_PS'; Format = 'General'; Compression = 'None' },
  [pscustomobject]@{ Name = 'Textures_PS'; Format = 'DDS'; Compression = 'LZ4' }
)
foreach ($archiveExpectation in $archiveCompressionExpectations) {
  $definitionPattern = '(?ms)^\s*"' + [regex]::Escape([string]$archiveExpectation.Name) +
    '"\s*=\s*\[pscustomobject\]@\{(?<Definition>.*?)^\s*\}'
  $definitionMatch = [regex]::Match($packageScriptSource, $definitionPattern)
  if (!$definitionMatch.Success) {
    throw "createPackagesV2.ps1 is missing archive definition '$($archiveExpectation.Name)'."
  }
  $definitionSource = $definitionMatch.Groups['Definition'].Value
  if ($definitionSource -cnotmatch ('(?m)^\s*Format\s*=\s*"' + [regex]::Escape([string]$archiveExpectation.Format) + '"\s*$') -or
      $definitionSource -cnotmatch ('(?m)^\s*Compression\s*=\s*"' + [regex]::Escape([string]$archiveExpectation.Compression) + '"\s*$')) {
    throw "createPackagesV2.ps1 archive '$($archiveExpectation.Name)' must use format=$($archiveExpectation.Format) and compression=$($archiveExpectation.Compression)."
  }
}
Write-Host 'Verified the Bethesda-style Archive2 format and compression matrix.'

$payloadGuardIndex = $packageScriptSource.IndexOf(
  'Verified every selected complete staged Interface payload before archive mutation.',
  [System.StringComparison]::Ordinal
)
$preArchiveVerifierIndex = $packageScriptSource.IndexOf(
  '-PreArchiveMutation',
  [System.StringComparison]::Ordinal
)
$archiveRemovalIndex = $packageScriptSource.IndexOf(
  'Remove-Item -LiteralPath $archivePath -Force',
  [System.StringComparison]::Ordinal
)
$archiveInvocationIndex = $packageScriptSource.IndexOf(
  '& $archive2Path @archiveArguments',
  [System.StringComparison]::Ordinal
)
if ($payloadGuardIndex -lt 0 -or
    $preArchiveVerifierIndex -lt 0 -or
    $archiveRemovalIndex -lt 0 -or
    $archiveInvocationIndex -lt 0 -or
    $preArchiveVerifierIndex -gt $payloadGuardIndex -or
    $payloadGuardIndex -gt $archiveRemovalIndex -or
    $payloadGuardIndex -gt $archiveInvocationIndex -or
    !$packageScriptSource.Contains('-VariantKeys $preArchiveVariantKeys') -or
    !$packageScriptSource.Contains('-Committed:$Committed')) {
  throw 'createPackagesV2.ps1 must verify every selected complete staged Interface payload before deleting or creating archives.'
}
Write-Host 'Verified the pre-Archive2 complete staged Interface payload guard.'

& (Join-Path $PSScriptRoot "verifyVariantV2.ps1") `
  -Committed `
  -PreArchiveMutation

Write-Host "Verified all six variants before archive mutation."

& (Join-Path $PSScriptRoot "verifyVariantV2.ps1") `
  -Committed

Write-Host "Verified all six variants through the shared release pipeline."
