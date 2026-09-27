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

$archive2Owners = @(
  & git -C $repositoryRoot grep -l -E 'TOOL_PATH_ARCHIVER.*Archive2\.exe' -- 'Tools/*.ps1' |
    ForEach-Object { $_.Replace('\', '/') } |
    Sort-Object
)
if ($LASTEXITCODE -ne 0 -or [string]::Join("`n", $archive2Owners) -cne 'Tools/createPackages.ps1') {
  throw "Only Tools/createPackages.ps1 may invoke Archive2.exe. Found: $($archive2Owners -join ', ')"
}

$packageSource = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'Tools/createPackages.ps1'))
foreach ($archiveTarget in @('Main', 'Main_XBox', 'Main_PS')) {
  $pattern = '(?ms)^\s*"' + [regex]::Escape($archiveTarget) + '"\s*=\s*\[pscustomobject\]@\{(?<Definition>.*?)^\s*\}'
  $match = [regex]::Match($packageSource, $pattern)
  if (!$match.Success -or $match.Groups['Definition'].Value -cnotmatch '(?m)^\s*Format\s*=\s*"General"\s*$' -or $match.Groups['Definition'].Value -cnotmatch '(?m)^\s*Compression\s*=\s*"None"\s*$') {
    throw "Archive target '$archiveTarget' must use uncompressed General BA2 output."
  }
}
if ($packageSource -match 'Textures(?:_XBox|_PS)?\.ba2') {
  throw 'The consumer-only package pipeline must not create retired texture archive shapes.'
}

& (Join-Path $PSScriptRoot 'checkRepo.ps1') -Committed
& (Join-Path $PSScriptRoot 'verifyVariant.ps1') -Committed -PreArchiveMutation
& (Join-Path $PSScriptRoot 'verifyVariant.ps1') -Committed

Write-Host 'Verified all five committed Canvas consumer variants and their fifteen platform archives.'
