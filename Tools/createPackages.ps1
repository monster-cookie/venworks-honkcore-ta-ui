<#
.SYNOPSIS
Builds and installs archive-only VWHUD packages from validated isolated payloads.
.DESCRIPTION
Creates all archive candidates before changing staging. Installation backs up managed files and exact loose payload targets, installs verified candidates, removes archive-shadowing loose files, and restores the prior state if any operation fails.
.PARAMETER VariantKeys
One or more keys from `$Global:ReleaseVariants`. Omit this parameter to process all release variants.
.PARAMETER PayloadRoot
Directory containing validated `<VariantKey>` payloads created by `buildVariant.ps1`. It must be beneath the repository `.work` directory.
.PARAMETER Committed
Installs the archive-only result into the tracked `Staging-*` directories. Without this switch, installation uses the verified configured module junctions.
#>
[CmdletBinding()]
param(
  [Alias('VariantKey')][string[]]$VariantKeys,
  [string]$PayloadRoot,
  [switch]$Committed
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.work')).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $PayloadRoot = Join-Path $workRoot 'canvas-payloads' }
$payloadRootPath = [IO.Path]::GetFullPath($PayloadRoot).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
if (!$payloadRootPath.StartsWith($workRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Package input must be beneath the repository .work directory.' }

if (!(Get-Variable -Name SharedConfigurationLoaded -Scope Global -ErrorAction SilentlyContinue)) {
  if ($Committed) { . (Join-Path $PSScriptRoot 'sharedConfig.ps1') -SkipEnvironment }
  else { . (Join-Path $PSScriptRoot 'sharedConfig.ps1') }
}
. (Join-Path $PSScriptRoot 'sharedCanvasConsumers.ps1')
. (Join-Path $PSScriptRoot 'sharedPackageTransactions.ps1')

if ([string]::IsNullOrWhiteSpace($env:TOOL_PATH_ARCHIVER)) { throw 'TOOL_PATH_ARCHIVER must name the directory containing Archive2.exe.' }
$archive2Path = Join-Path $env:TOOL_PATH_ARCHIVER 'Archive2.exe'
if (!(Test-Path -LiteralPath $archive2Path -PathType Leaf)) { throw 'Archive2.exe was not found at the TOOL_PATH_ARCHIVER location.' }

$archiveDefinitions = [ordered]@{
  "Main" = [pscustomobject]@{
    FileSuffix = "Main.ba2"
    Format = "General"
    Compression = "None"
    FilterArgument = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2'
  }
  "Textures" = [pscustomobject]@{
    FileSuffix = "Textures.ba2"
    Format = "DDS"
    Compression = "LZ4"
    FilterArgument = '-includeFilters=.*\\.*\.dds'
  }
  "Main_XBox" = [pscustomobject]@{
    FileSuffix = "Main_XBox.ba2"
    Format = "General"
    Compression = "None"
    FilterArgument = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2'
  }
  "Textures_XBox" = [pscustomobject]@{
    FileSuffix = "Textures_XBox.ba2"
    Format = "XBoxDDS"
    Compression = "LZ4"
    FilterArgument = '-includeFilters=.*\\.*\.dds'
  }
  "Main_PS" = [pscustomobject]@{
    FileSuffix = "Main_PS.ba2"
    Format = "General"
    Compression = "None"
    FilterArgument = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2'
  }
  "Textures_PS" = [pscustomobject]@{
    FileSuffix = "Textures_PS.ba2"
    Format = "DDS"
    Compression = "LZ4"
    FilterArgument = '-includeFilters=.*\\.*\.dds'
  }
}

$variants = @(Get-ModuleVariants -VariantKeys $VariantKeys)
$operations = [Collections.Generic.List[object]]::new()
foreach ($variant in $variants) {
  $key = [string]$variant.VariantKey
  $sourcePayload = Join-Path $payloadRootPath $key
  $evidence = Join-Path $repositoryRoot "CanvasConsumer/build/expected/$key.json"
  Assert-CanvasConsumerPayload -RepositoryRoot $repositoryRoot -Key $key -Payload $sourcePayload -Evidence $evidence
  $record = Get-CanvasConsumerBuildRecord $repositoryRoot $key $evidence
  $inventory = Get-CanvasConsumerBuildInventory $repositoryRoot $key $record
  $stagingPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $variant.StagingFolderPath))
  if (!(Test-Path -LiteralPath $stagingPath -PathType Container)) { throw "$($variant.VariantName) staging directory is missing: $stagingPath" }
  if ($Committed) {
    $installPath = $stagingPath
    $stagingItem = Get-Item -LiteralPath $stagingPath
    if ($stagingItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "$($variant.VariantName) committed staging path must not be a reparse point." }
  }
  else {
    if ([string]::IsNullOrWhiteSpace($variant.PluginModulePath) -or !(Test-Path -LiteralPath $variant.PluginModulePath -PathType Container)) { throw "$($variant.VariantName) configured physical module directory is missing." }
    $junction = Get-Item -LiteralPath $stagingPath
    $installPath = [IO.Path]::GetFullPath($variant.PluginModulePath)
    if ($junction.LinkType -ne 'Junction' -or @($junction.Target).Count -ne 1 -or [IO.Path]::GetFullPath([string]$junction.Target[0]) -ine $installPath) { throw "$($variant.VariantName) staging junction does not match its configured physical module directory." }
  }
  $archiveNames = @($variant.ArchiveTargets | ForEach-Object {
    if (!$archiveDefinitions.Contains([string]$_)) { throw "$($variant.VariantName) defines unknown archive target '$_'." }
    "$($variant.PackageBaseName) - $($archiveDefinitions[[string]$_].FileSuffix)"
  })
  $expectedArchiveTargets = @('Main','Textures','Main_XBox','Textures_XBox','Main_PS','Textures_PS')
  if ([string]::Join("`n", @($variant.ArchiveTargets)) -cne [string]::Join("`n", $expectedArchiveTargets) -or $archiveNames.Count -ne 6 -or @($archiveNames | Select-Object -Unique).Count -ne 6) { throw "$($variant.VariantName) must define the PC, Xbox, and PS5 Main and Textures archives." }
  $operations.Add([pscustomobject]@{
    Key = $key
    Variant = $variant
    SourcePayload = $sourcePayload
    Evidence = $evidence
    Record = $record
    Inventory = $inventory
    StagingPath = $stagingPath
    InstallPath = $installPath
    ManagedNames = @($inventory.Plugin) + $archiveNames
    LooseTargets = @($inventory.ArchivePayload)
    ArchiveNames = $archiveNames
    Committed = [bool]$Committed
  })
}

$transactionId = [guid]::NewGuid().ToString('N')
$transactionRoot = Join-Path $workRoot 'package-transactions'
$transactionPath = Join-Path $transactionRoot $transactionId
$candidateRoot = Join-Path $transactionPath 'candidates'
$archiveRoots = Join-Path $transactionPath 'archive-roots'
$backupRoot = Join-Path $transactionPath 'backups'
$lockPath = Join-Path $workRoot 'package.lock'
$packageLock = $null
$transactionCreated = $false
$completed = $false
$installed = [Collections.Generic.List[object]]::new()

try {
  $packageLock = Enter-VWHudPackageLock -Path $lockPath -TransactionId $transactionId
  New-Item -ItemType Directory -Force -Path $transactionRoot | Out-Null
  Assert-VWHudNoRetainedPackageTransactions -TransactionRoot $transactionRoot
  New-Item -ItemType Directory -Path $transactionPath,$candidateRoot,$archiveRoots,$backupRoot | Out-Null
  $transactionCreated = $true
  Write-VWHudPackageJournal -TransactionPath $transactionPath -TransactionId $transactionId -Status Active -VariantKeys @($variants.VariantKey)

  foreach ($operation in $operations) {
    $candidateDirectory = Join-Path $candidateRoot $operation.Key
    $archiveRoot = Join-Path $archiveRoots $operation.Key
    New-Item -ItemType Directory -Path $candidateDirectory,$archiveRoot | Out-Null
    $pluginSource = Resolve-VWHudPackageTarget -Root $operation.SourcePayload -Target $operation.Inventory.Plugin
    Copy-VWHudVerifiedFile -Source $pluginSource -Destination (Join-Path $candidateDirectory $operation.Inventory.Plugin) -ExpectedSha256 ([string]$operation.Record.Files[$operation.Inventory.Plugin]) -Description "$($operation.Key) plugin candidate"
    foreach ($target in @($operation.LooseTargets)) {
      $source = Resolve-VWHudPackageTarget -Root $operation.SourcePayload -Target $target
      $destination = Resolve-VWHudPackageTarget -Root $archiveRoot -Target $target
      Copy-VWHudVerifiedFile -Source $source -Destination $destination -ExpectedSha256 ([string]$operation.Record.Files[$target]) -Description "$($operation.Key) archive input '$target'"
    }
    foreach ($archiveTarget in @($operation.Variant.ArchiveTargets)) {
      $definition = $archiveDefinitions[[string]$archiveTarget]
      $archiveName = "$($operation.Variant.PackageBaseName) - $($definition.FileSuffix)"
      $archivePath = Join-Path $candidateDirectory $archiveName
      $rootArgument = $archiveRoot.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
      $arguments = @($rootArgument,"-root=$rootArgument","-create=$archivePath","-format=$($definition.Format)","-compression=$($definition.Compression)",'-maxSizeMB=2048',[string]$definition.FilterArgument)
      & $archive2Path @arguments
      if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $archivePath -PathType Leaf) -or (Get-Item -LiteralPath $archivePath).Length -le 0) { throw "Archive2 failed to create $($operation.Key) archive '$archiveName'." }
    }
    Assert-CanvasConsumerArchivePayload -RepositoryRoot $repositoryRoot -Key $operation.Key -Payload $candidateDirectory -Evidence $operation.Evidence
    $operation | Add-Member -NotePropertyName CandidatePath -NotePropertyValue $candidateDirectory -Force
    $candidateHashes = @{}
    foreach ($name in @($operation.ManagedNames)) { $candidateHashes[$name] = Get-VWHudFileSha256 (Join-Path $candidateDirectory $name) }
    $operation | Add-Member -NotePropertyName CandidateHashes -NotePropertyValue $candidateHashes -Force
  }

  foreach ($operation in $operations) {
    if (!$operation.Committed) {
      $junction = Get-Item -LiteralPath $operation.StagingPath
      if ($junction.LinkType -ne 'Junction' -or @($junction.Target).Count -ne 1 -or [IO.Path]::GetFullPath([string]$junction.Target[0]) -ine [IO.Path]::GetFullPath($operation.InstallPath)) { throw "$($operation.Key) staging junction changed during packaging." }
    }
    Backup-VWHudPackageOperation -Operation $operation -BackupRoot $backupRoot
    $installed.Add($operation)
    foreach ($name in @($operation.ManagedNames)) {
      Install-VWHudVerifiedFile -Source (Join-Path $operation.CandidatePath $name) -Destination (Resolve-VWHudPackageTarget -Root $operation.InstallPath -Target $name) -ExpectedSha256 ([string]$operation.CandidateHashes[$name]) -Description "$($operation.Key) installed '$name'"
    }
    Remove-VWHudLoosePayloads -Operation $operation
    Assert-VWHudNoLoosePayloads -Operation $operation
    Assert-CanvasConsumerArchivePayload -RepositoryRoot $repositoryRoot -Key $operation.Key -Payload $operation.InstallPath -Evidence $operation.Evidence -AllowUnmanagedFiles:(!$operation.Committed)
  }

  Write-VWHudPackageJournal -TransactionPath $transactionPath -TransactionId $transactionId -Status Complete -VariantKeys @($variants.VariantKey)
  foreach ($operation in $operations) {
    $pendingPayload = [IO.Path]::GetFullPath($operation.SourcePayload)
    if ($pendingPayload.StartsWith($payloadRootPath+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $pendingPayload -PathType Container)) { Remove-Item -LiteralPath $pendingPayload -Recurse -Force }
  }
  $completed = $true
}
catch {
  $packageError = $_
  $recoveryErrors = [Collections.Generic.List[string]]::new()
  for ($index=$installed.Count-1;$index -ge 0;$index--) {
    try { Restore-VWHudPackageOperation -Operation $installed[$index] }
    catch { $recoveryErrors.Add("Recovery failed for '$($installed[$index].Key)': $($_.Exception.Message)") }
  }
  if ($transactionCreated) {
    try { Write-VWHudPackageJournal -TransactionPath $transactionPath -TransactionId $transactionId -Status Failed -VariantKeys @($variants.VariantKey) -Failure $packageError.Exception.Message }
    catch { $recoveryErrors.Add("Transaction journal update failed: $($_.Exception.Message)") }
  }
  if ($recoveryErrors.Count -ne 0) { throw "Package transaction $transactionId failed and recovery is incomplete. Recovery material remains at $transactionPath. $($packageError.Exception.Message) $([string]::Join(' | ',@($recoveryErrors)))" }
  throw "Package transaction $transactionId failed; managed files and loose payloads were restored. Recovery material remains at $transactionPath. $($packageError.Exception.Message)"
}
finally {
  if ($null -ne $packageLock) {
    try { if ($completed) { Remove-VWHudSuccessfulTransaction -TransactionPath $transactionPath -TransactionRoot $transactionRoot } }
    finally { $packageLock.Dispose() }
  }
}

Write-Host -ForegroundColor Cyan "Created and installed archive-only packages for: $([string]::Join(', ',@($variants.VariantKey)))"
