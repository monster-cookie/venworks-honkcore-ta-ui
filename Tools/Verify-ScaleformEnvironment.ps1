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

$ExpectedJavaReleaseHash = "07117c72ce033949c14878e07fbf2fe23f59a1f8c90a6d1351b5c89099847ce7"
$ExpectedJpexsJarHash = "090ab695053ad94cba6408574c7d7eea20ec60b6ae789ee6056a23f45106762f"
$ExpectedFlexDescriptionHash = "e8bfe5fc4195379edab4044b0495d6cf10cf1be19ebeb400690344981d1538dd"
$ExpectedMxmlcJarHash = "cc07d749e376715e650271a9875289e49d94234902fff5e5fae287c478c8557b"
$ExpectedCompcJarHash = "843b4f9728d168abf3342585b47959d6120fa89718368e5d9acf636b2e7c6946"
$ExpectedPlayerGlobalHash = "2bbd5ffff3bb20c117db7206080079479b04c4b55d68dd21ab31b6566c99fb6b"

function Test-FileContract {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int64]$Length,

        [Parameter(Mandatory)]
        [string]$Sha256
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $file = Get-Item -LiteralPath $Path

    return (
        $file.Length -eq $Length -and
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -eq $Sha256
    )
}

function Test-PlayerGlobalArchive {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-FileContract `
        -Path $Path `
        -Length 337288 `
        -Sha256 $ExpectedPlayerGlobalHash)) {
        return $false
    }

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)

        try {
            $entries = @($archive.Entries | ForEach-Object { $_.FullName })

            return (
                $entries.Count -eq 2 -and
                $entries -contains "catalog.xml" -and
                $entries -contains "library.swf"
            )
        }
        finally {
            $archive.Dispose()
        }
    }
    catch {
        return $false
    }
}

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
$JavaReleaseFile = Join-Path $JavaRoot "release"

Write-TestResult `
    -Name "Portable Java" `
    -Success (Test-Path $JavaExe) `
    -Details $JavaExe

$javaReleasePinned = Test-FileContract `
    -Path $JavaReleaseFile `
    -Length 1664 `
    -Sha256 $ExpectedJavaReleaseHash

Write-TestResult `
    -Name "Pinned Temurin 21.0.12.1+1 release" `
    -Success $javaReleasePinned `
    -Details $JavaReleaseFile

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
$FlexDescription = Join-Path $FlexRoot "flex-sdk-description.xml"

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

$flexDescriptionPinned = Test-FileContract `
    -Path $FlexDescription `
    -Length 994 `
    -Sha256 $ExpectedFlexDescriptionHash

Write-TestResult `
    -Name "Pinned Apache Flex 4.16.1 description" `
    -Success $flexDescriptionPinned `
    -Details $FlexDescription

$mxmlcPinned = Test-FileContract `
    -Path $MxmlcJar `
    -Length 2107651 `
    -Sha256 $ExpectedMxmlcJarHash

Write-TestResult `
    -Name "Pinned Apache Flex mxmlc library" `
    -Success $mxmlcPinned `
    -Details $MxmlcJar

$compcPinned = Test-FileContract `
    -Path $CompcJar `
    -Length 5066 `
    -Sha256 $ExpectedCompcJarHash

Write-TestResult `
    -Name "Pinned Apache Flex compc library" `
    -Success $compcPinned `
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
$ExpectedPlayerGlobalPath = Join-Path $FrameworksRoot "libs\player\11.1\playerglobal.swc"

if (Test-Path $FrameworksRoot) {
    $PlayerGlobals = @(
        Get-ChildItem `
            -Path $FrameworksRoot `
            -Filter "playerglobal.swc" `
            -Recurse `
            -ErrorAction SilentlyContinue
    )

    $playerGlobalValid = (
        $PlayerGlobals.Count -eq 1 -and
        $PlayerGlobals[0].FullName -eq $ExpectedPlayerGlobalPath -and
        (Test-PlayerGlobalArchive -Path $ExpectedPlayerGlobalPath)
    )

    Write-TestResult `
        -Name "Pinned Flash Player 11.1 playerglobal.swc" `
        -Success $playerGlobalValid `
        -Details $(if ($PlayerGlobals.Count -ne 1) {
            "Expected exactly one playerglobal.swc; found $($PlayerGlobals.Count)."
        }
        elseif ($PlayerGlobals[0].FullName -ne $ExpectedPlayerGlobalPath) {
            "Expected $ExpectedPlayerGlobalPath; found $($PlayerGlobals[0].FullName)."
        }
        elseif (-not $playerGlobalValid) {
            "The SWC length, SHA-256, or ZIP inventory is invalid: $ExpectedPlayerGlobalPath"
        }
        else {
            $ExpectedPlayerGlobalPath
        })
}
else {
    Write-TestResult `
        -Name "Pinned Flash Player 11.1 playerglobal.swc" `
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

$jpexsJarPath = Join-Path $JpexsRoot "ffdec.jar"
$jpexsPinned = Test-FileContract `
    -Path $jpexsJarPath `
    -Length 5075015 `
    -Sha256 $ExpectedJpexsJarHash

Write-TestResult `
    -Name "Pinned JPEXS 26.2.1 library" `
    -Success $jpexsPinned `
    -Details $jpexsJarPath

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
Write-Host "  ./Tools/Setup-ScaleformEnvironment.ps1 -AcceptAdobeLicense"
Write-Host ""
Write-Host "Then rerun this verification."

exit 1
