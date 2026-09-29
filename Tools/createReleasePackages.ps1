<#
.SYNOPSIS
Assembles version-independent Nexus and Bethesda release ZIPs.

.PARAMETER VariantKeys
One or more keys from `$Global:ReleaseVariants`. Omit this parameter to process
all release variants. `VariantKey` remains a compatibility alias.
#>
[CmdletBinding()]
param(
  [string]$OutputDirectory = (Join-Path (Join-Path $PSScriptRoot "..") "artifacts/release"),

  [Alias("VariantKey")]
  [string[]]$VariantKeys
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if (!(Test-Path Variable:Global:SharedConfigurationLoaded) -or !$Global:SharedConfigurationLoaded) {
  Write-Host -ForegroundColor Green "Importing release variant configuration"
  . "$PSScriptRoot/sharedConfig.ps1" -SkipEnvironment
}
. (Join-Path $PSScriptRoot 'sharedCanvasConsumers.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-NotGitLfsPointer {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $buffer = [byte[]]::new([Math]::Min(128, [int]$stream.Length))
    [void]$stream.Read($buffer, 0, $buffer.Length)
  }
  finally {
    $stream.Dispose()
  }
  $prefix = [System.Text.Encoding]::UTF8.GetString($buffer)
  if ($prefix.StartsWith("version https://git-lfs.github.com/spec/v1", [System.StringComparison]::Ordinal)) {
    throw "$Description remains a Git LFS pointer: $Path"
  }
}

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

  $file = Get-Item -LiteralPath $Path
  if ($file.Length -le 0) {
    throw "$Description is empty: $Path"
  }
  Assert-NotGitLfsPointer -Path $file.FullName -Description $Description

  return $file.FullName
}

function New-PackageFile {
  param(
    [string]$SourcePath,

    [byte[]]$Bytes,

    [Parameter(Mandatory = $true)]
    [string]$EntryName
  )

  if ([string]::IsNullOrWhiteSpace($SourcePath) -eq ($null -eq $Bytes)) {
    throw "Package file '$EntryName' must use exactly one source."
  }

  return [pscustomobject]@{
    SourcePath = $SourcePath
    Bytes = $Bytes
    EntryName = $EntryName.Replace('\', '/')
  }
}

function New-ReleaseZip {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [Parameter(Mandatory = $true)]
    [object[]]$Files
  )

  if ($Files.Count -eq 0) {
    throw "Cannot create a release ZIP without files: $ZipPath"
  }

  $duplicateEntryNames = @(
    $Files |
      Group-Object -Property EntryName |
      Where-Object { $_.Count -ne 1 }
  )
  if ($duplicateEntryNames.Count -ne 0) {
    throw "Release ZIP '$ZipPath' contains duplicate entry names: $($duplicateEntryNames.Name -join ', ')"
  }

  foreach ($file in $Files) {
    if ([string]::IsNullOrWhiteSpace([string]$file.EntryName) -or
        [string]$file.EntryName -match '(^/|^[A-Za-z]:|(?:^|/)\.\.(?:/|$))') {
      throw "Release ZIP '$ZipPath' contains an unsafe entry name: $($file.EntryName)"
    }
  }

  if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
  }

  $archive = [System.IO.Compression.ZipFile]::Open(
    $ZipPath,
    [System.IO.Compression.ZipArchiveMode]::Create
  )
  try {
    foreach ($file in $Files) {
      if ($null -ne $file.Bytes) {
        $entry = $archive.CreateEntry([string]$file.EntryName,[System.IO.Compression.CompressionLevel]::Optimal)
        $stream = $entry.Open()
        try { $stream.Write([byte[]]$file.Bytes,0,([byte[]]$file.Bytes).Length) }
        finally { $stream.Dispose() }
      }
      else {
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
          $archive,
          [string]$file.SourcePath,
          [string]$file.EntryName,
          [System.IO.Compression.CompressionLevel]::Optimal
        )
      }
    }
  }
  finally {
    $archive.Dispose()
  }

  $zipFile = Get-Item -LiteralPath $ZipPath
  if ($zipFile.Length -le 0) {
    throw "Generated release ZIP is empty: $ZipPath"
  }

  $expectedEntries = @($Files.EntryName | Sort-Object)
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $actualEntries = @($archive.Entries.FullName | Sort-Object)
    if ($actualEntries.Count -ne $expectedEntries.Count) {
      throw "Generated release ZIP '$ZipPath' has $($actualEntries.Count) entries; expected $($expectedEntries.Count)."
    }
    for ($index = 0; $index -lt $expectedEntries.Count; $index++) {
      if ($actualEntries[$index] -cne $expectedEntries[$index]) {
        throw "Generated release ZIP '$ZipPath' has unexpected contents."
      }
    }
    foreach ($entryName in $actualEntries) {
      if (($entryName -split '/')[0] -match '^Staging-') {
        throw "Generated release ZIP '$ZipPath' contains a staging folder at its archive root: $entryName"
      }
    }
  }
  finally {
    $archive.Dispose()
  }

  Write-Host -ForegroundColor Green "Created $($zipFile.Name) with $($expectedEntries.Count) entries."
}

$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)

foreach ($variant in $variants) {
  $stagingPath = (Resolve-Path -LiteralPath $variant.StagingFolderPath).Path
  $packageSuffixes = @(Get-VariantReleasePackageSuffixes -Variant $variant)
  if ($packageSuffixes.Count -eq 0) {
    throw "$($variant.VariantName) metadata does not enable any release package shapes."
  }

  $pluginName = "$($variant.PackageBaseName).esm"
  $mainName = "$($variant.PackageBaseName) - Main.ba2"
  $mainXboxName = "$($variant.PackageBaseName) - Main_XBox.ba2"
  $mainPsName = "$($variant.PackageBaseName) - Main_PS.ba2"

  $pluginPath = Resolve-RequiredFile -Path (Join-Path $stagingPath $pluginName) -Description "$($variant.VariantName) plugin"
  $pluginFile = New-PackageFile -SourcePath $pluginPath -EntryName $pluginName
  $evidence = Join-Path $repositoryRoot "CanvasConsumer/build/expected/$($variant.VariantKey).json"
  $windowsArchiveFiles = @()
  if (@($packageSuffixes | Where-Object { $_ -in @('Nexus PC - Normal', 'Bethesda PC') }).Count -ne 0) {
    $mainPath = Resolve-RequiredFile -Path (Join-Path $stagingPath $mainName) -Description "$($variant.VariantName) Windows Main archive"
    $windowsArchiveFiles = @(New-PackageFile -SourcePath $mainPath -EntryName $mainName)
  }
  $xboxArchiveFiles = @()
  if ('Bethesda Xbox' -in $packageSuffixes) {
    $mainXboxPath = Resolve-RequiredFile -Path (Join-Path $stagingPath $mainXboxName) -Description "$($variant.VariantName) Xbox Main archive"
    $xboxArchiveFiles = @(New-PackageFile -SourcePath $mainXboxPath -EntryName $mainXboxName)
  }
  $psArchiveFiles = @()
  if ('Bethesda PS5' -in $packageSuffixes) {
    $mainPsPath = Resolve-RequiredFile -Path (Join-Path $stagingPath $mainPsName) -Description "$($variant.VariantName) PS5 Main archive"
    $psArchiveFiles = @(New-PackageFile -SourcePath $mainPsPath -EntryName $mainPsName)
  }

  $looseFiles = @()
  if (@($packageSuffixes | Where-Object { $_ -like 'Nexus PC*' }).Count -ne 0) {
    $looseFiles = @(Get-CanvasConsumerLoosePackageFiles -RepositoryRoot $repositoryRoot -Key ([string]$variant.VariantKey) -Payload $stagingPath -Evidence $evidence | ForEach-Object {
      New-PackageFile -Bytes ([byte[]]$_.Bytes) -EntryName ([string]$_.EntryName)
    })
    $looseFiles += @($pluginFile)
  }

  $packages = @($packageSuffixes | ForEach-Object {
    $suffix = [string]$_
    $files = switch ($suffix) {
      'Nexus PC - Normal' { @($pluginFile) + $windowsArchiveFiles; break }
      'Nexus PC - Fully Loose Files' { $looseFiles; break }
      'Bethesda PC' { @($pluginFile) + $windowsArchiveFiles; break }
      'Bethesda Xbox' { @($pluginFile) + $xboxArchiveFiles; break }
      'Bethesda PS5' { @($pluginFile) + $psArchiveFiles; break }
      default { throw "$($variant.VariantName) has unsupported release package suffix '$suffix'." }
    }
    [pscustomobject]@{ Suffix = $suffix; Files = @($files) }
  })

  $zipNamePrefix = "$($variant.ReleaseDisplayName) - "
  $expectedZipNames = @(
    $packages |
      ForEach-Object { "$zipNamePrefix$($_.Suffix).zip" } |
      Sort-Object
  )
  $existingVariantZipFiles = @(
    Get-ChildItem -LiteralPath $resolvedOutputDirectory -File -Filter '*.zip' |
      Where-Object { $_.Name.StartsWith($zipNamePrefix, [System.StringComparison]::Ordinal) }
  )
  foreach ($existingVariantZipFile in $existingVariantZipFiles) {
    Remove-Item -LiteralPath $existingVariantZipFile.FullName -Force
  }

  foreach ($package in $packages) {
    $zipName = "$($variant.ReleaseDisplayName) - $($package.Suffix).zip"
    New-ReleaseZip -ZipPath (Join-Path $resolvedOutputDirectory $zipName) -Files $package.Files
  }

  $actualZipNames = @(
    Get-ChildItem -LiteralPath $resolvedOutputDirectory -File -Filter '*.zip' |
      Where-Object { $_.Name.StartsWith($zipNamePrefix, [System.StringComparison]::Ordinal) } |
      ForEach-Object { $_.Name } |
      Sort-Object
  )
  if ($actualZipNames.Count -ne $expectedZipNames.Count -or
      [string]::Join("`n", $actualZipNames) -cne [string]::Join("`n", $expectedZipNames)) {
    throw "$($variant.VariantName) release output does not contain its exact configured ZIP inventory."
  }
}

if ($null -eq $VariantKeys -or $VariantKeys.Count -eq 0) {
  Write-Host -ForegroundColor Cyan "Created every configured release package shape for all variants."
}
else {
  Write-Host -ForegroundColor Cyan "Created the configured release package shapes for the selected variants."
}
