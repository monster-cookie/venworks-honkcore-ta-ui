#Requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Repository / workspace paths
# ---------------------------------------------------------------------------

$RepoRoot = Split-Path -Parent $PSScriptRoot

$WorkRoot = Join-Path $RepoRoot ".work"
$ToolRoot = Join-Path $WorkRoot "tools"

$FlexRoot = Join-Path $ToolRoot "flex"
$JpexsRoot = Join-Path $ToolRoot "jpexs"
$JavaRoot = Join-Path $ToolRoot "java"

$BuildRoot = Join-Path $WorkRoot "build"
$DecompileRoot = Join-Path $WorkRoot "decompiled"
$ExtractRoot = Join-Path $WorkRoot "extracted"
$LogRoot = Join-Path $WorkRoot "logs"
$TempRoot = Join-Path $WorkRoot "temp"

# ---------------------------------------------------------------------------
# Result tracking
# ---------------------------------------------------------------------------

$Failures = [System.Collections.Generic.List[string]]::new()
$Warnings = [System.Collections.Generic.List[string]]::new()

function Write-TestResult {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Success,

        [string]$Details
    )

    if ($Success) {
        Write-Host "[PASS] " -ForegroundColor Green -NoNewline
        Write-Host $Name -NoNewline

        if ($Details) {
            Write-Host " - $Details"
        }
        else {
            Write-Host ""
        }

        return
    }

    Write-Host "[FAIL] " -ForegroundColor Red -NoNewline
    Write-Host $Name -NoNewline

    if ($Details) {
        Write-Host " - $Details"
    }
    else {
        Write-Host ""
    }

    $script:Failures.Add($Name)
}

function Write-WarningResult {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Details
    )

    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Name -NoNewline

    if ($Details) {
        Write-Host " - $Details"
    }
    else {
        Write-Host ""
    }

    $script:Warnings.Add($Name)
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Starfield Scaleform Environment Verification" `
    -ForegroundColor Cyan

Write-Host "============================================"
Write-Host ""

Write-Host "Repository : $RepoRoot"
Write-Host "Workspace  : $WorkRoot"
Write-Host ""

# ---------------------------------------------------------------------------
# Git repository
# ---------------------------------------------------------------------------

$GitRoot = Join-Path $RepoRoot ".git"

Write-TestResult `
    -Name "Git repository" `
    -Success (Test-Path $GitRoot) `
    -Details $RepoRoot

$git = Get-Command "git" -ErrorAction SilentlyContinue

Write-TestResult `
    -Name "Git executable" `
    -Success ($null -ne $git) `
    -Details $(if ($git) {
        $git.Source
    }
    else {
        "git.exe not found on PATH"
    })

# ---------------------------------------------------------------------------
# Verify .work is ignored
# ---------------------------------------------------------------------------

if ($git) {
    Push-Location $RepoRoot

    try {
        & git check-ignore -q ".work"

        $workIgnored = $LASTEXITCODE -eq 0

        Write-TestResult `
            -Name ".work ignored by Git" `
            -Success $workIgnored `
            -Details $(if ($workIgnored) {
                "$WorkRoot is excluded from source control"
            }
            else {
                "Add /.work/ to .gitignore"
            })
    }
    finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Workspace directories
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Build workspace" -ForegroundColor Cyan
Write-Host "---------------"

$RequiredWorkDirectories = @(
    $WorkRoot
    $ToolRoot
    $BuildRoot
    $DecompileRoot
    $ExtractRoot
    $LogRoot
    $TempRoot
)

foreach ($directory in $RequiredWorkDirectories) {
    if (-not (Test-Path $directory)) {
        New-Item `
            -ItemType Directory `
            -Path $directory `
            -Force |
            Out-Null
    }

    Write-TestResult `
        -Name (
            "Workspace directory: " +
            (Split-Path $directory -Leaf)
        ) `
        -Success (Test-Path $directory) `
        -Details $directory
}

# ---------------------------------------------------------------------------
# Java
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Java" -ForegroundColor Cyan
Write-Host "----"

$JavaExe = Join-Path $JavaRoot "bin\java.exe"

Write-TestResult `
    -Name "Portable Java" `
    -Success (Test-Path $JavaExe) `
    -Details $JavaExe

if (Test-Path $JavaExe) {
    try {
        $javaVersion = (
            & $JavaExe -version 2>&1 |
                Select-Object -First 1
        )

        Write-TestResult `
            -Name "Java execution" `
            -Success ($LASTEXITCODE -eq 0) `
            -Details $javaVersion
    }
    catch {
        Write-TestResult `
            -Name "Java execution" `
            -Success $false `
            -Details $_.Exception.Message
    }
}

# ---------------------------------------------------------------------------
# Apache Flex
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Apache Flex" -ForegroundColor Cyan
Write-Host "-----------"

$Mxmlc = Join-Path $FlexRoot "bin\mxmlc.bat"
$Compc = Join-Path $FlexRoot "bin\compc.bat"
$MxmlcJar = Join-Path $FlexRoot "lib\mxmlc.jar"
$CompcJar = Join-Path $FlexRoot "lib\compc.jar"
$Asc = Join-Path $FlexRoot "lib\asc.jar"

Write-TestResult `
    -Name "Flex SDK" `
    -Success (Test-Path $FlexRoot) `
    -Details $FlexRoot

Write-TestResult `
    -Name "mxmlc compiler" `
    -Success (Test-Path $Mxmlc) `
    -Details $Mxmlc

Write-TestResult `
    -Name "compc compiler" `
    -Success (Test-Path $Compc) `
    -Details $Compc

Write-TestResult `
    -Name "mxmlc compiler library" `
    -Success (Test-Path $MxmlcJar) `
    -Details $MxmlcJar

Write-TestResult `
    -Name "compc compiler library" `
    -Success (Test-Path $CompcJar) `
    -Details $CompcJar

if (Test-Path $Asc) {
    Write-TestResult `
        -Name "ASC compiler library" `
        -Success $true `
        -Details $Asc
}
else {
    Write-WarningResult `
        -Name "ASC compiler library" `
        -Details "asc.jar was not found; some projects do not require it."
}

if (
    (Test-Path $Mxmlc) -and
    (Test-Path $JavaExe)
) {
    try {
        # Ensure Flex uses our portable Java for this child process.
        $previousJavaHome = $env:JAVA_HOME
        $previousPath = $env:Path

        try {
            $env:JAVA_HOME = $JavaRoot
            $env:Path = (
                (Join-Path $JavaRoot "bin") +
                ";" +
                $previousPath
            )

            $versionOutput = & $Mxmlc -version 2>&1

            $versionText = (
                $versionOutput |
                    Out-String
            ).Trim()

            Write-TestResult `
                -Name "Flex compiler execution" `
                -Success ($LASTEXITCODE -eq 0) `
                -Details $versionText
        }
        finally {
            $env:JAVA_HOME = $previousJavaHome
            $env:Path = $previousPath
        }
    }
    catch {
        Write-TestResult `
            -Name "Flex compiler execution" `
            -Success $false `
            -Details $_.Exception.Message
    }
}

# ---------------------------------------------------------------------------
# playerglobal.swc
# ---------------------------------------------------------------------------

$FrameworksRoot = Join-Path $FlexRoot "frameworks"

if (Test-Path $FrameworksRoot) {
    $PlayerGlobals = @(
        Get-ChildItem `
            -Path $FrameworksRoot `
            -Filter "playerglobal.swc" `
            -Recurse `
            -ErrorAction SilentlyContinue
    )

    if ($PlayerGlobals.Count -eq 1) {
        Write-TestResult `
            -Name "playerglobal.swc" `
            -Success $true `
            -Details $PlayerGlobals[0].FullName
    }
    else {
        Write-TestResult `
            -Name "playerglobal.swc" `
            -Success $false `
            -Details "Expected exactly one playerglobal.swc; found $($PlayerGlobals.Count)."
    }
}
else {
    Write-TestResult `
        -Name "playerglobal.swc" `
        -Success $false `
        -Details "Flex frameworks directory was not found: $FrameworksRoot"
}

# ---------------------------------------------------------------------------
# JPEXS
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "JPEXS" -ForegroundColor Cyan
Write-Host "-----"

Write-TestResult `
    -Name "JPEXS directory" `
    -Success (Test-Path $JpexsRoot) `
    -Details $JpexsRoot

$JpexsExe = Get-ChildItem `
    -Path $JpexsRoot `
    -Filter "ffdec.exe" `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

$JpexsJar = Get-ChildItem `
    -Path $JpexsRoot `
    -Filter "ffdec.jar" `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($JpexsExe) {
    Write-TestResult `
        -Name "JPEXS executable" `
        -Success $true `
        -Details $JpexsExe.FullName
}
elseif ($JpexsJar) {
    Write-TestResult `
        -Name "JPEXS JAR" `
        -Success $true `
        -Details $JpexsJar.FullName
}
else {
    Write-TestResult `
        -Name "JPEXS executable" `
        -Success $false `
        -Details "Neither ffdec.exe nor ffdec.jar was found."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Pipeline paths" -ForegroundColor Cyan
Write-Host "--------------"

Write-Host "Build      : $BuildRoot"
Write-Host "Decompiled : $DecompileRoot"
Write-Host "Extracted  : $ExtractRoot"
Write-Host "Logs       : $LogRoot"
Write-Host "Temp       : $TempRoot"

Write-Host ""
Write-Host "============================================"

if ($Failures.Count -eq 0) {
    Write-Host "Scaleform environment is ready." `
        -ForegroundColor Green

    if ($Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host (
            "$($Warnings.Count) warning(s) require " +
            "project-specific review."
        ) -ForegroundColor Yellow
    }

    exit 0
}

Write-Host ""
Write-Host "$($Failures.Count) required check(s) failed." `
    -ForegroundColor Red

foreach ($failure in $Failures) {
    Write-Host "  - $failure"
}

Write-Host ""
Write-Host "Run:"
Write-Host "  ./tools/Install-ScaleformEnvironment.ps1"
Write-Host ""
Write-Host "Then rerun this verification."

exit 1
