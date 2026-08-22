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

$expectedVariants = [ordered]@{
  "TA" = [ordered]@{
    VariantName = "Trackers Alliance"
    ReleaseDisplayName = "Venworks Customizable HUD - Trackers Alliance Theme"
    PackageBaseName = "Venworks-CustomizableHUD-TrackersAlliance"
    StagingFolderPath = "./Staging-TA"
    PaletteFileName = "trackers-alliance.xml"
  }
  "FC" = [ordered]@{
    VariantName = "Freestar Collective"
    ReleaseDisplayName = "Venworks Customizable HUD - Freestar Collective Theme"
    PackageBaseName = "Venworks-CustomizableHUD-FreestarCollective"
    StagingFolderPath = "./Staging-FC"
    PaletteFileName = "freestar-collective.xml"
  }
  "CF" = [ordered]@{
    VariantName = "Crimson Fleet"
    ReleaseDisplayName = "Venworks Customizable HUD - Crimson Fleet Theme"
    PackageBaseName = "Venworks-CustomizableHUD-CrimsonFleet"
    StagingFolderPath = "./Staging-CF"
    PaletteFileName = "crimson-fleet.xml"
  }
  "VWKS" = [ordered]@{
    VariantName = "Venworks"
    ReleaseDisplayName = "Venworks Customizable HUD - Venworks Theme"
    PackageBaseName = "Venworks-CustomizableHUD-Venworks"
    StagingFolderPath = "./Staging-VWKS"
    PaletteFileName = "venworks.xml"
  }
}
$expectedPaletteFileNames = @(
  "venworks.xml"
  "crimson-fleet.xml"
  "freestar-collective.xml"
  "trackers-alliance.xml"
  "starfield.xml"
)
$paletteSourceDirectory = Join-Path $PSScriptRoot "..\Scaleform\shared\palettes"

if ($Global:Variants.Count -ne $expectedVariants.Count) {
  throw "Expected exactly $($expectedVariants.Count) release variants; found $($Global:Variants.Count)."
}
foreach ($expectedVariantKey in $expectedVariants.Keys) {
  $matchingVariants = @($Global:Variants | Where-Object { [string]$_.VariantKey -eq $expectedVariantKey })
  if ($matchingVariants.Count -ne 1) {
    throw "Expected release variant key '$expectedVariantKey' exactly once; found $($matchingVariants.Count)."
  }
}

$pluginHashes = [System.Collections.Generic.List[string]]::new()
foreach ($variant in $Global:Variants) {
  Write-Host -ForegroundColor Cyan "Validating variant $($variant.VariantName) in $($variant.StagingFolderPath)"

  if (!$expectedVariants.Contains([string]$variant.VariantKey)) {
    throw "Unexpected release variant key '$($variant.VariantKey)'."
  }
  $expectedVariant = $expectedVariants[[string]$variant.VariantKey]
  foreach ($propertyName in @(
    "VariantName",
    "ReleaseDisplayName",
    "PackageBaseName",
    "StagingFolderPath",
    "PaletteFileName"
  )) {
    if ([string]$variant.$propertyName -cne [string]$expectedVariant[$propertyName]) {
      throw "Release variant '$($variant.VariantKey)' must use $propertyName '$($expectedVariant[$propertyName])'; found '$($variant.$propertyName)'."
    }
  }

  $expectedPaletteFileName = [string]$expectedVariant.PaletteFileName
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

  $expectedPluginName = "$($variant.PackageBaseName).esm"
  $pluginFiles = @(Get-ChildItem -LiteralPath $variant.StagingFolderPath -Recurse -File -Filter "*.esm")
  if ($pluginFiles.Count -ne 1 -or $pluginFiles[0].Name -cne $expectedPluginName -or
      $pluginFiles[0].Directory.FullName -cne (Resolve-Path -LiteralPath $variant.StagingFolderPath).Path) {
    throw "$($variant.VariantName) must contain exactly one root plugin named '$expectedPluginName'."
  }
  if ($pluginFiles[0].Length -le 0) {
    throw "$($variant.VariantName) plugin is empty: $($pluginFiles[0].FullName)"
  }
  $pluginHashes.Add((Get-FileHash -LiteralPath $pluginFiles[0].FullName -Algorithm SHA256).Hash)

  $expectedMainArchiveNames = @(
    "$($variant.PackageBaseName) - Main.ba2",
    "$($variant.PackageBaseName) - Main_XBox.ba2",
    "$($variant.PackageBaseName) - Main_PS.ba2"
  )
  $expectedTextureArchiveNames = @(
    "$($variant.PackageBaseName) - Textures.ba2",
    "$($variant.PackageBaseName) - Textures_XBox.ba2",
    "$($variant.PackageBaseName) - Textures_PS.ba2"
  )
  $archiveFiles = @(Get-ChildItem -LiteralPath $variant.StagingFolderPath -Recurse -File -Filter "*.ba2")
  $stagingRoot = (Resolve-Path -LiteralPath $variant.StagingFolderPath).Path
  $allowedArchiveNames = @($expectedMainArchiveNames + $expectedTextureArchiveNames)
  foreach ($archiveFile in $archiveFiles) {
    if ($archiveFile.Directory.FullName -cne $stagingRoot -or
        $allowedArchiveNames -cnotcontains $archiveFile.Name) {
      throw "$($variant.VariantName) contains an unexpected BA2 archive: $($archiveFile.FullName)"
    }
    if ($archiveFile.Length -le 0) {
      throw "$($variant.VariantName) BA2 is empty: $($archiveFile.FullName)"
    }
  }
  foreach ($expectedArchiveName in $expectedMainArchiveNames) {
    $matchingArchives = @($archiveFiles | Where-Object {
      $_.Name -ceq $expectedArchiveName -and $_.Directory.FullName -ceq $stagingRoot
    })
    if ($matchingArchives.Count -ne 1) {
      throw "$($variant.VariantName) must contain one root BA2 named '$expectedArchiveName'."
    }
  }
  $ddsFiles = @(Get-ChildItem -LiteralPath (Join-Path $variant.StagingFolderPath "Interface") -Recurse -File -Filter "*.dds")
  if ($ddsFiles.Count -ne 0) {
    foreach ($expectedArchiveName in $expectedTextureArchiveNames) {
      $matchingArchives = @($archiveFiles | Where-Object {
        $_.Name -ceq $expectedArchiveName -and $_.Directory.FullName -ceq $stagingRoot
      })
      if ($matchingArchives.Count -ne 1) {
        throw "$($variant.VariantName) has DDS sources and must contain one root BA2 named '$expectedArchiveName'."
      }
    }
  }

  $variantCuiDirectory = Join-Path $variant.StagingFolderPath "Interface\VenworksCUI"
  $variantLayoutPath = Join-Path $variantCuiDirectory "layout.xml"
  if (!(Test-Path -LiteralPath $variantLayoutPath -PathType Leaf)) {
    throw "$($variant.VariantName) is missing its staged Venworks CUI layout: $variantLayoutPath"
  }
  [xml]$variantLayout = Get-Content -LiteralPath $variantLayoutPath -Raw
  if ([string]$variantLayout.venworksCUI.palette -ne $expectedPaletteFileName) {
    throw "$($variant.VariantName) layout must select '$expectedPaletteFileName'; found '$([string]$variantLayout.venworksCUI.palette)'."
  }

  foreach ($paletteFileName in $expectedPaletteFileNames) {
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

if (@($pluginHashes | Select-Object -Unique).Count -ne 1) {
  throw "The four release plugins must remain byte-identical stub ESM payloads."
}

Write-Host -ForegroundColor Cyan "`n`n"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "**  Variant Staging and Package Artifacts Valid **"
Write-Host -ForegroundColor Cyan "**************************************************"
Write-Host -ForegroundColor Cyan "`n`n"
