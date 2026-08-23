[CmdletBinding()]
param()

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
  $expectedHash = Get-Sha256 -Path $resolvedExpectedPath
  $actualHash = Get-Sha256 -Path $resolvedActualPath
  if ($actualHash -cne $expectedHash) {
    throw "$Description hash mismatch. Expected $expectedHash from $resolvedExpectedPath; found $actualHash at $resolvedActualPath."
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
  $sourceText = [System.IO.File]::ReadAllText($resolvedSourcePath)
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

$trackedPowerShellScripts = @(& git -C $repositoryRoot ls-files -- '*.ps1')
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
$movies = @(
  [pscustomobject]@{
    FileName = 'hudmenu.gfx'
    ExpectedHashPath = 'Scaleform/hudmenu/validation/expected.sha256'
  },
  [pscustomobject]@{
    FileName = 'hudmenu_lrg.gfx'
    ExpectedHashPath = 'Scaleform/hudmenu_lrg/validation/expected.sha256'
  },
  [pscustomobject]@{
    FileName = 'hudmessagesmenu.gfx'
    ExpectedHashPath = 'Scaleform/hudmessagesmenu/validation/expected.sha256'
  },
  [pscustomobject]@{
    FileName = 'hudmessagesmenu_lrg.gfx'
    ExpectedHashPath = 'Scaleform/hudmessagesmenu_lrg/validation/expected.sha256'
  }
)

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
    $expectedHashPath = Join-Path $repositoryRoot $movie.ExpectedHashPath
    $expectedHash = Read-ExpectedSha256 -Path $expectedHashPath
    $moviePath = Resolve-RequiredFile `
      -Path (Join-Path $interfaceRoot $movie.FileName) `
      -Description "$($variant.Name) $($movie.FileName)"
    $actualHash = Get-Sha256 -Path $moviePath
    if ($actualHash -cne $expectedHash) {
      throw "$($variant.Name) $($movie.FileName) hash mismatch. Expected $expectedHash; found $actualHash."
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
    throw "The four staged $($movie.FileName) files are not byte-identical."
  }
}

Write-Host "Verified committed Scaleform movie hashes and complete staged VenworksCUI payloads for all four variants."
