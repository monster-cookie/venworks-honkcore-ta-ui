<#
.SYNOPSIS
Exercises the production package backup, loose cleanup, and recovery helpers against an isolated fixture.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'sharedPackageTransactions.ps1')

$testRoot = Join-Path $repositoryRoot ('.work/package-transaction-tests/'+[guid]::NewGuid().ToString('N'))
$installRoot = Join-Path $testRoot 'install'
$candidateRoot = Join-Path $testRoot 'candidate'
$backupRoot = Join-Path $testRoot 'backup'
New-Item -ItemType Directory -Path $installRoot,$candidateRoot,$backupRoot -Force | Out-Null

function Write-TestFile([string]$Root,[string]$Relative,[string]$Value) {
  $path = Resolve-VWHudPackageTarget -Root $Root -Target $Relative
  New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($path)) | Out-Null
  [IO.File]::WriteAllText($path,$Value,[Text.UTF8Encoding]::new($false))
  return $path
}

try {
  $managed = @('Theme.esm','Theme - Main.ba2')
  $loose = @('Interface/VenworksCanvas/Consumers/test/index.html','Scripts/Venworks/Test.pex')
  foreach ($name in $managed) { [void](Write-TestFile $installRoot $name "old:$name"); [void](Write-TestFile $candidateRoot $name "new:$name") }
  foreach ($target in $loose) { [void](Write-TestFile $installRoot $target "loose:$target") }
  $unrelated = Write-TestFile $installRoot 'notes/keep.txt' 'unrelated'
  $operation = [pscustomobject]@{Key='TEST';InstallPath=$installRoot;ManagedNames=$managed;LooseTargets=$loose}
  Backup-VWHudPackageOperation -Operation $operation -BackupRoot $backupRoot
  foreach ($name in $managed) {
    $source = Resolve-VWHudPackageTarget -Root $candidateRoot -Target $name
    Install-VWHudVerifiedFile -Source $source -Destination (Resolve-VWHudPackageTarget -Root $installRoot -Target $name) -ExpectedSha256 (Get-VWHudFileSha256 $source) -Description "test install '$name'"
  }
  Remove-VWHudLoosePayloads -Operation $operation
  Assert-VWHudNoLoosePayloads -Operation $operation
  foreach ($target in $loose) { if (Test-Path -LiteralPath (Resolve-VWHudPackageTarget -Root $installRoot -Target $target)) { throw "Loose fixture survived cleanup: $target" } }
  if ([IO.File]::ReadAllText($unrelated) -cne 'unrelated') { throw 'Unrelated fixture changed during cleanup.' }
  Restore-VWHudPackageOperation -Operation $operation
  foreach ($name in $managed) { if ([IO.File]::ReadAllText((Resolve-VWHudPackageTarget -Root $installRoot -Target $name)) -cne "old:$name") { throw "Managed fixture was not restored: $name" } }
  foreach ($target in $loose) { if ([IO.File]::ReadAllText((Resolve-VWHudPackageTarget -Root $installRoot -Target $target)) -cne "loose:$target") { throw "Loose fixture was not restored: $target" } }
  if ([IO.File]::ReadAllText($unrelated) -cne 'unrelated') { throw 'Unrelated fixture changed during recovery.' }
  $escaped = $false
  try { [void](Resolve-VWHudPackageTarget -Root $installRoot -Target '../outside.txt') }
  catch { $escaped = $true }
  if (!$escaped) { throw 'Traversal fixture was not rejected.' }
  $retainedRoot = Join-Path $testRoot 'retained'
  $retainedTransaction = Join-Path $retainedRoot 'fixture'
  New-Item -ItemType Directory -Path $retainedTransaction -Force | Out-Null
  Write-VWHudPackageJournal -TransactionPath $retainedTransaction -TransactionId fixture -Status Failed -VariantKeys TEST -Failure injected
  $retainedRejected = $false
  try { Assert-VWHudNoRetainedPackageTransactions -TransactionRoot $retainedRoot }
  catch { $retainedRejected = $_.Exception.Message -match 'fixture \[Failed\]' }
  if (!$retainedRejected) { throw 'Retained transaction fixture was not rejected with its status.' }
  $outside = Join-Path $testRoot 'outside'
  New-Item -ItemType Directory -Path $outside -Force | Out-Null
  $secret = Join-Path $outside 'secret.txt'
  [IO.File]::WriteAllText($secret,'secret',[Text.UTF8Encoding]::new($false))
  $nested = Join-Path $installRoot 'InterfaceLink'
  New-Item -ItemType Junction -Path $nested -Target $outside | Out-Null
  $reparseRejected = $false
  try { Remove-VWHudLoosePayloads -Operation ([pscustomobject]@{Key='TEST';InstallPath=$installRoot;LooseTargets=@('InterfaceLink/secret.txt')}) }
  catch { $reparseRejected = $_.Exception.Message -match 'reparse point' }
  if (!$reparseRejected) { throw 'Nested junction fixture was not rejected.' }
  if ([IO.File]::ReadAllText($secret) -cne 'secret') { throw 'Nested junction fixture deleted the outside file.' }
  $stagingRoot = Join-Path $testRoot 'staging-root'
  New-Item -ItemType Junction -Path $stagingRoot -Target $installRoot | Out-Null
  $throughRoot = Resolve-VWHudPackageTarget -Root $stagingRoot -Target 'notes/keep.txt'
  if ([IO.File]::ReadAllText($throughRoot) -cne 'unrelated') { throw 'Module-root junction did not resolve inside the module.' }
  Write-Host 'Package transaction helper cleanup, preservation, recovery, traversal, reparse-point, and retained-transaction checks passed.'
}
finally {
  $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
  $allowedRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.work/package-transaction-tests')).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
  if ($resolvedTestRoot.StartsWith($allowedRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot -PathType Container)) { Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force }
}
