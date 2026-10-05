<#
.SYNOPSIS
Verifies the committed five-theme Canvas consumer release.
#>
[CmdletBinding()]
param()

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

$trackedPowerShellScripts = @(
  & git -C $repositoryRoot ls-files -- '*.ps1' |
    Where-Object { Test-Path -LiteralPath (Join-Path $repositoryRoot $_) -PathType Leaf }
)
if ($LASTEXITCODE -ne 0 -or $trackedPowerShellScripts.Count -eq 0) {
  throw 'Unable to inventory tracked PowerShell scripts.'
}
foreach ($relativeScriptPath in $trackedPowerShellScripts) {
  $tokens = $null
  $parseErrors = $null
  [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $repositoryRoot $relativeScriptPath), [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count -ne 0) {
    throw "PowerShell syntax validation failed for ${relativeScriptPath}: $(@($parseErrors.Message) -join '; ')"
  }
}
Write-Host "Validated PowerShell syntax for $($trackedPowerShellScripts.Count) tracked scripts."

& (Join-Path $PSScriptRoot 'testCanvasResourceEncoding.ps1')
& (Join-Path $PSScriptRoot 'testCanvasCompatibility.ps1')
& (Join-Path $PSScriptRoot 'testCanvasContainingBlocks.ps1')
& (Join-Path $PSScriptRoot 'testPackageTransactions.ps1')

$archive2Owners = @(
  & git -C $repositoryRoot grep -l -E 'TOOL_PATH_ARCHIVER.*Archive2\.exe' -- 'Tools/*.ps1' |
    ForEach-Object { $_.Replace('\', '/') } |
    Sort-Object
)
if ($LASTEXITCODE -ne 0 -or [string]::Join("`n", $archive2Owners) -cne 'Tools/createPackages.ps1') {
  throw "Only Tools/createPackages.ps1 may invoke Archive2.exe. Found: $($archive2Owners -join ', ')"
}

$packageSource = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'Tools/createPackages.ps1'))
$expectedPackageArchives = @(
  @{ Name = 'Main'; Format = 'General'; Compression = 'None'; Filter = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2' }
  @{ Name = 'Textures'; Format = 'DDS'; Compression = 'LZ4'; Filter = '-includeFilters=.*\\.*\.dds' }
  @{ Name = 'Main_XBox'; Format = 'General'; Compression = 'None'; Filter = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2' }
  @{ Name = 'Textures_XBox'; Format = 'XBoxDDS'; Compression = 'LZ4'; Filter = '-includeFilters=.*\\.*\.dds' }
  @{ Name = 'Main_PS'; Format = 'General'; Compression = 'None'; Filter = '-excludeFilters=.*\\meta\.ini|.*\\.*\.dds|.*\\.*\.btc|.*\\.*\.esp|.*\\.*\.esm|.*\\.*\.ba2' }
  @{ Name = 'Textures_PS'; Format = 'DDS'; Compression = 'LZ4'; Filter = '-includeFilters=.*\\.*\.dds' }
)
foreach ($archiveTarget in $expectedPackageArchives) {
  $pattern = '(?ms)^\s*"' + [regex]::Escape([string]$archiveTarget.Name) + '"\s*=\s*\[pscustomobject\]@\{(?<Definition>.*?)^\s*\}'
  $match = [regex]::Match($packageSource, $pattern)
  $definition = if ($match.Success) { $match.Groups['Definition'].Value } else { '' }
  if ($definition -cnotmatch ('(?m)^\s*Format\s*=\s*"' + [regex]::Escape([string]$archiveTarget.Format) + '"\s*$') -or
      $definition -cnotmatch ('(?m)^\s*Compression\s*=\s*"' + [regex]::Escape([string]$archiveTarget.Compression) + '"\s*$') -or
      $definition -cnotmatch ('(?m)^\s*FilterArgument\s*=\s*''' + [regex]::Escape([string]$archiveTarget.Filter) + '''\s*$')) {
    throw "Archive target '$($archiveTarget.Name)' does not keep DDS files in the texture archives."
  }
}

& (Join-Path $PSScriptRoot 'checkRepo.ps1') -Committed
& (Join-Path $PSScriptRoot 'verifyVariant.ps1') -Committed

Write-Host 'Verified all five committed Canvas consumer variants and their thirty platform archives.'
