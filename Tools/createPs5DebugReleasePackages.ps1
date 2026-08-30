<#
.SYNOPSIS
Creates only the Bethesda PC and Bethesda PS5 ZIPs for the isolated PS5 debug variant.
#>
[CmdletBinding()]
param(
  [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\.work\ps5-debug-release")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot "sharedConfig.ps1") -SkipEnvironment
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
  return (Resolve-Path -LiteralPath $Path).Path
}

function Assert-NotGitLfsPointer {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $prefix = [System.Text.Encoding]::UTF8.GetString($bytes, 0, [Math]::Min(128, $bytes.Length))
  if ($prefix.StartsWith("version https://git-lfs.github.com/spec/v1", [System.StringComparison]::Ordinal)) {
    throw "$Description remains a Git LFS pointer: $Path"
  }
}

function New-DiagnosticReleaseZip {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [Parameter(Mandatory = $true)]
    [object[]]$Files
  )

  if (Test-Path -LiteralPath $ZipPath -PathType Leaf) {
    Remove-Item -LiteralPath $ZipPath -Force
  }
  $stream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::CreateNew)
  try {
    $archive = [System.IO.Compression.ZipArchive]::new(
      $stream,
      [System.IO.Compression.ZipArchiveMode]::Create
    )
    try {
      foreach ($file in $Files) {
        $entry = $archive.CreateEntry([string]$file.EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        try {
          $sourceStream = [System.IO.File]::OpenRead([string]$file.SourcePath)
          try {
            $sourceStream.CopyTo($entryStream)
          }
          finally {
            $sourceStream.Dispose()
          }
        }
        finally {
          $entryStream.Dispose()
        }
      }
    }
    finally {
      $archive.Dispose()
    }
  }
  finally {
    $stream.Dispose()
  }

  $reopened = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $actualEntries = @($reopened.Entries.FullName | Sort-Object)
  }
  finally {
    $reopened.Dispose()
  }
  $expectedEntries = @($Files.EntryName | Sort-Object)
  if ([string]::Join("`n", $actualEntries) -cne [string]::Join("`n", $expectedEntries)) {
    throw "PS5 Debug ZIP contains an unexpected entry inventory: $ZipPath"
  }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$variant = @(Get-DiagnosticVariants -VariantKeys "PS5DBG")[0]
$stagingPath = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot ([string]$variant.StagingFolderPath))).Path
$pluginName = "$($variant.PackageBaseName).esm"
$pluginPath = Resolve-RequiredFile -Path (Join-Path $stagingPath $pluginName) -Description "PS5 Debug plugin"
Assert-NotGitLfsPointer -Path $pluginPath -Description "PS5 Debug plugin"

$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null
$packageDefinitions = @(
  [pscustomobject]@{ Suffix = 'Bethesda PC'; ArchiveName = "$($variant.PackageBaseName) - Main.ba2" },
  [pscustomobject]@{ Suffix = 'Bethesda PS5'; ArchiveName = "$($variant.PackageBaseName) - Main_PS.ba2" }
)

foreach ($packageDefinition in $packageDefinitions) {
  $archivePath = Resolve-RequiredFile `
    -Path (Join-Path $stagingPath ([string]$packageDefinition.ArchiveName)) `
    -Description "PS5 Debug $($packageDefinition.Suffix) Main archive"
  Assert-NotGitLfsPointer -Path $archivePath -Description "PS5 Debug $($packageDefinition.Suffix) Main archive"
  $zipPath = Join-Path $resolvedOutputDirectory "$($variant.ReleaseDisplayName) - $($packageDefinition.Suffix).zip"
  New-DiagnosticReleaseZip `
    -ZipPath $zipPath `
    -Files @(
      [pscustomobject]@{ SourcePath = $pluginPath; EntryName = $pluginName },
      [pscustomobject]@{ SourcePath = $archivePath; EntryName = [string]$packageDefinition.ArchiveName }
    )
  Write-Host -ForegroundColor Green "Created $zipPath with the unique plugin and one platform Main archive."
}

$zipFiles = @(Get-ChildItem -LiteralPath $resolvedOutputDirectory -File -Filter '*.zip')
if ($zipFiles.Count -ne 2) {
  throw "PS5 Debug release output must contain exactly two Bethesda ZIPs; found $($zipFiles.Count)."
}
Write-Host -ForegroundColor Cyan "Created only the isolated PS5 Debug Bethesda PC and PS5 packages."
