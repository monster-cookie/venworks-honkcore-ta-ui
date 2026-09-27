$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-VWHudFileSha256 {
  param([Parameter(Mandatory)][string]$Path)
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required package file does not exist: $Path" }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Resolve-VWHudPackageTarget {
  param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$Target
  )
  if ([string]::IsNullOrWhiteSpace($Target) -or [IO.Path]::IsPathRooted($Target) -or $Target -match '(^|[\\/])\.\.([\\/]|$)') {
    throw "Unsafe package target: $Target"
  }
  $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
  $resolved = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $Target))
  if (!$resolved.StartsWith($resolvedRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
    throw "Package target escapes its root: $Target"
  }
  return $resolved
}

function Copy-VWHudVerifiedFile {
  param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string]$ExpectedSha256,
    [Parameter(Mandatory)][string]$Description
  )
  if ((Get-VWHudFileSha256 $Source) -cne $ExpectedSha256) { throw "$Description source hash changed." }
  $parent = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Destination))
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  Copy-Item -LiteralPath $Source -Destination $Destination -Force
  if ((Get-VWHudFileSha256 $Destination) -cne $ExpectedSha256) { throw "$Description destination hash differs." }
}

function Install-VWHudVerifiedFile {
  param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string]$ExpectedSha256,
    [Parameter(Mandatory)][string]$Description
  )
  $resolvedDestination = [IO.Path]::GetFullPath($Destination)
  New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($resolvedDestination)) | Out-Null
  $temporary = "$resolvedDestination.$PID-$([guid]::NewGuid().ToString('N')).new"
  try {
    Copy-VWHudVerifiedFile -Source $Source -Destination $temporary -ExpectedSha256 $ExpectedSha256 -Description $Description
    [IO.File]::Move($temporary,$resolvedDestination,$true)
    if ((Get-VWHudFileSha256 $resolvedDestination) -cne $ExpectedSha256) { throw "$Description differs after installation." }
  }
  finally {
    if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
  }
}

function Enter-VWHudPackageLock {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$TransactionId
  )
  New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))) | Out-Null
  try {
    $stream = [IO.File]::Open($Path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  }
  catch {
    throw "Another VWHUD package transaction owns the package lock: $Path"
  }
  try {
    $stream.SetLength(0)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($TransactionId)
    $stream.Write($bytes,0,$bytes.Length)
    $stream.Flush($true)
    return $stream
  }
  catch {
    $stream.Dispose()
    throw
  }
}

function Assert-VWHudNoRetainedPackageTransactions {
  param([Parameter(Mandatory)][string]$TransactionRoot)
  $root = [IO.Path]::GetFullPath($TransactionRoot)
  if (!(Test-Path -LiteralPath $root -PathType Container)) { return }
  $retained = @(Get-ChildItem -LiteralPath $root -Directory -Force)
  if ($retained.Count -eq 0) { return }
  $descriptions = @($retained | ForEach-Object {
    $journalPath = Join-Path $_.FullName 'transaction.json'
    if (Test-Path -LiteralPath $journalPath -PathType Leaf) {
      try {
        $journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
        "$($_.Name) [$($journal.Status)]"
      }
      catch { "$($_.Name) [unreadable journal]" }
    }
    else { "$($_.Name) [missing journal]" }
  })
  throw "Retained package transactions require manual inspection before packaging: $([string]::Join(', ',@($descriptions)))"
}

function Write-VWHudPackageJournal {
  param(
    [Parameter(Mandatory)][string]$TransactionPath,
    [Parameter(Mandatory)][string]$TransactionId,
    [Parameter(Mandatory)][string]$Status,
    [Parameter(Mandatory)][string[]]$VariantKeys,
    [string]$Failure
  )
  $record = [ordered]@{Schema='VWHUD_PACKAGE_TRANSACTION/1';TransactionId=$TransactionId;ProcessId=$PID;Status=$Status;VariantKeys=@($VariantKeys);Failure=$Failure}
  [IO.File]::WriteAllText((Join-Path $TransactionPath 'transaction.json'),($record | ConvertTo-Json -Depth 4)+"`n",[Text.UTF8Encoding]::new($false))
}

function Backup-VWHudPackageOperation {
  param(
    [Parameter(Mandatory)][psobject]$Operation,
    [Parameter(Mandatory)][string]$BackupRoot
  )
  $backupPath = Join-Path $BackupRoot ([string]$Operation.Key)
  $managedRoot = Join-Path $backupPath 'managed'
  $looseRoot = Join-Path $backupPath 'loose'
  New-Item -ItemType Directory -Path $managedRoot,$looseRoot -Force | Out-Null
  $managedNames = [Collections.Generic.List[string]]::new()
  $managedHashes = @{}
  foreach ($name in @($Operation.ManagedNames)) {
    $installed = Resolve-VWHudPackageTarget -Root $Operation.InstallPath -Target $name
    $item = Get-Item -LiteralPath $installed -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { continue }
    if ($item.PSIsContainer) { throw "$($Operation.Key) managed package target is a directory: $installed" }
    $hash = Get-VWHudFileSha256 $installed
    Copy-VWHudVerifiedFile -Source $installed -Destination (Join-Path $managedRoot $name) -ExpectedSha256 $hash -Description "$($Operation.Key) managed backup '$name'"
    $managedNames.Add($name)
    $managedHashes[$name] = $hash
  }
  $looseTargets = [Collections.Generic.List[string]]::new()
  $looseHashes = @{}
  foreach ($target in @($Operation.LooseTargets)) {
    $installed = Resolve-VWHudPackageTarget -Root $Operation.InstallPath -Target $target
    $item = Get-Item -LiteralPath $installed -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { continue }
    if ($item.PSIsContainer) { throw "$($Operation.Key) loose package target is a directory: $installed" }
    $hash = Get-VWHudFileSha256 $installed
    $backup = Resolve-VWHudPackageTarget -Root $looseRoot -Target $target
    Copy-VWHudVerifiedFile -Source $installed -Destination $backup -ExpectedSha256 $hash -Description "$($Operation.Key) loose backup '$target'"
    $looseTargets.Add($target)
    $looseHashes[$target] = $hash
  }
  $Operation | Add-Member -NotePropertyName BackupPath -NotePropertyValue $backupPath -Force
  $Operation | Add-Member -NotePropertyName OriginalManagedNames -NotePropertyValue @($managedNames) -Force
  $Operation | Add-Member -NotePropertyName OriginalManagedHashes -NotePropertyValue $managedHashes -Force
  $Operation | Add-Member -NotePropertyName OriginalLooseTargets -NotePropertyValue @($looseTargets) -Force
  $Operation | Add-Member -NotePropertyName OriginalLooseHashes -NotePropertyValue $looseHashes -Force
}

function Remove-VWHudLoosePayloads {
  param([Parameter(Mandatory)][psobject]$Operation)
  foreach ($target in @($Operation.LooseTargets)) {
    $path = Resolve-VWHudPackageTarget -Root $Operation.InstallPath -Target $target
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { continue }
    if ($item.PSIsContainer) { throw "$($Operation.Key) loose package target is a directory: $path" }
    Remove-Item -LiteralPath $path -Force
  }
}

function Assert-VWHudNoLoosePayloads {
  param([Parameter(Mandatory)][psobject]$Operation)
  $remaining = [Collections.Generic.List[string]]::new()
  foreach ($target in @($Operation.LooseTargets)) {
    $path = Resolve-VWHudPackageTarget -Root $Operation.InstallPath -Target $target
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { continue }
    if ($item.PSIsContainer) { throw "$($Operation.Key) loose package target is a directory: $path" }
    $remaining.Add($target)
  }
  if ($remaining.Count -ne 0) { throw "$($Operation.Key) installed package has archive-shadowing loose files: $([string]::Join(', ',@($remaining)))" }
}

function Restore-VWHudPackageOperation {
  param([Parameter(Mandatory)][psobject]$Operation)
  $managedRoot = Join-Path $Operation.BackupPath 'managed'
  $looseRoot = Join-Path $Operation.BackupPath 'loose'
  foreach ($name in @($Operation.ManagedNames)) {
    $path = Resolve-VWHudPackageTarget -Root $Operation.InstallPath -Target $name
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($null -ne $item) {
      if ($item.PSIsContainer) { throw "$($Operation.Key) recovery target is a directory: $path" }
      Remove-Item -LiteralPath $path -Force
    }
  }
  foreach ($name in @($Operation.OriginalManagedNames)) {
    $source = Resolve-VWHudPackageTarget -Root $managedRoot -Target $name
    Install-VWHudVerifiedFile -Source $source -Destination (Resolve-VWHudPackageTarget -Root $Operation.InstallPath -Target $name) -ExpectedSha256 ([string]$Operation.OriginalManagedHashes[$name]) -Description "$($Operation.Key) managed recovery '$name'"
  }
  Remove-VWHudLoosePayloads -Operation $Operation
  foreach ($target in @($Operation.OriginalLooseTargets)) {
    $source = Resolve-VWHudPackageTarget -Root $looseRoot -Target $target
    Install-VWHudVerifiedFile -Source $source -Destination (Resolve-VWHudPackageTarget -Root $Operation.InstallPath -Target $target) -ExpectedSha256 ([string]$Operation.OriginalLooseHashes[$target]) -Description "$($Operation.Key) loose recovery '$target'"
  }
}

function Remove-VWHudSuccessfulTransaction {
  param(
    [Parameter(Mandatory)][string]$TransactionPath,
    [Parameter(Mandatory)][string]$TransactionRoot
  )
  $resolvedRoot = [IO.Path]::GetFullPath($TransactionRoot).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
  $resolvedPath = [IO.Path]::GetFullPath($TransactionPath)
  if (!$resolvedPath.StartsWith($resolvedRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Transaction cleanup escaped its work root.' }
  if (Test-Path -LiteralPath $resolvedPath -PathType Container) { Remove-Item -LiteralPath $resolvedPath -Recurse -Force }
}
