# Abort on first error
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# If not loaded already pull in the shared config
if (!$Global:SharedConfigurationLoaded) {
  Write-Host -ForegroundColor Green "Importing Shared Configuration"
  . "$PSScriptRoot\sharedConfig.ps1"
}

If (![System.IO.File]::Exists(".env")) {
  Write-Host -ForegroundColor Red "ERROR: .env file must be created and configured to run this."
  Exit
}

$expectedVariantPalettes = [ordered]@{
  "Trackers Alliance" = "trackers-alliance.xml"
  "Freestar Collective" = "freestar-collective.xml"
  "Crimson Fleet" = "crimson-fleet.xml"
  "Venworks" = "venworks.xml"
}
$defaultPaletteFileName = "venworks.xml"
$paletteSourceDirectory = Join-Path $PSScriptRoot "..\Scaleform\shared\palettes"

if ($Global:Variants.Count -ne $expectedVariantPalettes.Count) {
  throw "Expected exactly $($expectedVariantPalettes.Count) release variants; found $($Global:Variants.Count)."
}
foreach ($expectedVariantName in $expectedVariantPalettes.Keys) {
  $matchingVariants = @($Global:Variants | Where-Object { [string]$_.VariantName -eq $expectedVariantName })
  if ($matchingVariants.Count -ne 1) {
    throw "Expected release variant '$expectedVariantName' exactly once; found $($matchingVariants.Count)."
  }
}

foreach ($variant in $Global:Variants) {
  Write-Host -ForegroundColor Cyan "Validating variant $($variant.VariantName) in $($variant.StagingFolderPath)"

  if (!$expectedVariantPalettes.Contains([string]$variant.VariantName)) {
    throw "Unexpected release variant name '$($variant.VariantName)'."
  }
  $expectedPaletteFileName = [string]$expectedVariantPalettes[[string]$variant.VariantName]
  if ([string]$variant.PaletteFileName -ne $expectedPaletteFileName) {
    throw "Release variant '$($variant.VariantName)' must map to palette '$expectedPaletteFileName'; found '$($variant.PaletteFileName)'."
  }

  if (![System.IO.Directory]::Exists($variant.StagingFolderPath)) {
    Write-Host -ForegroundColor Red "$($variant.VariantName) variant Staging folder doesn't exist. Please rerun the setupRepo script."
    Exit
  }

  if ([System.IO.Directory]::Exists("$($variant.StagingFolderPath)")) {
    if ((Get-Item -Path "$($variant.StagingFolderPath)").LinkType -ne "Junction") {
      Write-Host -ForegroundColor Red "$($variant.VariantName) variant Staging folder is no longer a Junction. Please delete it and rerun the setupRepo script."
      Exit
    }
  }

  $variantCuiDirectory = Join-Path $variant.StagingFolderPath "Interface\VenworksCUI"
  $variantLayoutPath = Join-Path $variantCuiDirectory "layout.xml"
  if (!(Test-Path -LiteralPath $variantLayoutPath -PathType Leaf)) {
    throw "$($variant.VariantName) is missing its staged Venworks CUI layout: $variantLayoutPath"
  }
  [xml]$variantLayout = Get-Content -LiteralPath $variantLayoutPath -Raw
  if ([string]$variantLayout.venworksCUI.palette -ne $defaultPaletteFileName) {
    throw "$($variant.VariantName) layout must default to '$defaultPaletteFileName'; found '$([string]$variantLayout.venworksCUI.palette)'."
  }

  foreach ($paletteFileName in $expectedVariantPalettes.Values) {
    $paletteSourcePath = Join-Path $paletteSourceDirectory $paletteFileName
    $variantPalettePath = Join-Path (Join-Path $variantCuiDirectory "palettes") $paletteFileName
    if (!(Test-Path -LiteralPath $paletteSourcePath -PathType Leaf)) {
      throw "Palette source is missing: $paletteSourcePath"
    }
    if (!(Test-Path -LiteralPath $variantPalettePath -PathType Leaf)) {
      throw "$($variant.VariantName) is missing staged palette '$paletteFileName'."
    }
    $sourcePaletteHash = (Get-FileHash -LiteralPath $paletteSourcePath -Algorithm SHA256).Hash
    $stagedPaletteHash = (Get-FileHash -LiteralPath $variantPalettePath -Algorithm SHA256).Hash
    if ($stagedPaletteHash -ne $sourcePaletteHash) {
      throw "$($variant.VariantName) staged palette '$paletteFileName' does not match its source file."
    }
  }
}

Write-Host -ForegroundColor Cyan "`n`n"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "**    Folder Junctions and Palettes Valid       **"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "`n`n"
