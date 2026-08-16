$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$WorkRoot = Join-Path $RepoRoot ".work"
$ToolRoot = Join-Path $WorkRoot "tools"

$RequiredPaths = @(
    (Join-Path $ToolRoot "java")
    (Join-Path $ToolRoot "flex")
    (Join-Path $ToolRoot "jpexs")
)

$NeedsInstall = $false

foreach ($path in $RequiredPaths) {
    if (-not (Test-Path $path)) {
        $NeedsInstall = $true
        break
    }
}

if ($NeedsInstall) {
    & "$PSScriptRoot\Install-ScaleformEnvironment.ps1"

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

& "$PSScriptRoot\Verify-ScaleformEnvironment.ps1"

exit $LASTEXITCODE