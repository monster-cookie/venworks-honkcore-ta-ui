#Requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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
# Versions
# ---------------------------------------------------------------------------

$FlexVersion = "4.16.1"
$JavaMajorVersion = 21

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Reset-Directory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Invoke-Download {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile
    )

    Write-Host "Downloading:"
    Write-Host "  $Uri"

    Invoke-WebRequest `
        -Uri $Uri `
        -OutFile $OutFile `
        -UseBasicParsing
}

# ---------------------------------------------------------------------------
# Create .work structure
# ---------------------------------------------------------------------------

Write-Step "Creating Scaleform workspace"

@(
    $WorkRoot
    $ToolRoot
    $BuildRoot
    $DecompileRoot
    $ExtractRoot
    $LogRoot
    $TempRoot
) | ForEach-Object {
    New-Item `
        -ItemType Directory `
        -Path $_ `
        -Force |
        Out-Null
}

Write-Host "Repository : $RepoRoot"
Write-Host "Workspace  : $WorkRoot"

# ---------------------------------------------------------------------------
# Portable Java
# ---------------------------------------------------------------------------

Write-Step "Checking portable Java"

$JavaExe = Join-Path $JavaRoot "bin\java.exe"

if (-not (Test-Path $JavaExe)) {
    Write-Host "Portable Java was not found."
    Write-Host "Installing Eclipse Temurin JDK $JavaMajorVersion..."

    $temurinApi = (
        "https://api.adoptium.net/v3/assets/latest/" +
        "$JavaMajorVersion/hotspot" +
        "?architecture=x64" +
        "&image_type=jdk" +
        "&os=windows" +
        "&vendor=eclipse"
    )

    $assets = Invoke-RestMethod `
        -Uri $temurinApi `
        -Headers @{
            "User-Agent" = "Starfield-Scaleform-Installer"
        }

    $asset = $assets |
        Where-Object {
            $_.binary.package.link -match '\.zip$'
        } |
        Select-Object -First 1

    if (-not $asset) {
        throw "Could not locate a Windows x64 Temurin JDK ZIP."
    }

    $javaZip = Join-Path $TempRoot "temurin-jdk.zip"
    $javaExtract = Join-Path $TempRoot "java-extract"

    Invoke-Download `
        -Uri $asset.binary.package.link `
        -OutFile $javaZip

    Reset-Directory $javaExtract
    Reset-Directory $JavaRoot

    Expand-Archive `
        -Path $javaZip `
        -DestinationPath $javaExtract `
        -Force

    $javaSource = Get-ChildItem `
        -Path $javaExtract `
        -Directory |
        Select-Object -First 1

    if (-not $javaSource) {
        throw "Temurin archive did not contain the expected JDK directory."
    }

    Get-ChildItem `
        -Path $javaSource.FullName `
        -Force |
        Move-Item `
            -Destination $JavaRoot `
            -Force

    Remove-Item $javaZip -Force
    Remove-Item $javaExtract -Recurse -Force

    if (-not (Test-Path $JavaExe)) {
        throw "Java installation completed but java.exe was not found."
    }

    Write-Host "Java installed to:"
    Write-Host "  $JavaRoot"
}
else {
    Write-Host "Portable Java already exists:"
    Write-Host "  $JavaRoot"
}

& $JavaExe -version

# ---------------------------------------------------------------------------
# JPEXS Free Flash Decompiler
# ---------------------------------------------------------------------------

Write-Step "Checking JPEXS Free Flash Decompiler"

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

if (-not $JpexsExe -and -not $JpexsJar) {
    Write-Host "JPEXS was not found."
    Write-Host "Finding latest release..."

    $releaseUri = (
        "https://api.github.com/repos/" +
        "jindrapetrik/jpexs-decompiler/releases/latest"
    )

    $release = Invoke-RestMethod `
        -Uri $releaseUri `
        -Headers @{
            "User-Agent" = "Starfield-Scaleform-Installer"
        }

    $asset = $release.assets |
        Where-Object {
            $_.name -match '^ffdec_[0-9.]+\.zip$'
        } |
        Select-Object -First 1

    if (-not $asset) {
        throw "Could not locate the JPEXS ZIP in the latest release."
    }

    Write-Host "JPEXS release: $($release.tag_name)"

    $jpexsZip = Join-Path $TempRoot $asset.name

    Invoke-Download `
        -Uri $asset.browser_download_url `
        -OutFile $jpexsZip

    Reset-Directory $JpexsRoot

    Expand-Archive `
        -Path $jpexsZip `
        -DestinationPath $JpexsRoot `
        -Force

    Remove-Item $jpexsZip -Force

    Write-Host "JPEXS installed to:"
    Write-Host "  $JpexsRoot"
}
else {
    Write-Host "JPEXS already exists:"
    Write-Host "  $JpexsRoot"
}

# ---------------------------------------------------------------------------
# Apache Flex SDK
# ---------------------------------------------------------------------------

Write-Step "Checking Apache Flex SDK $FlexVersion"

$Mxmlc = Join-Path $FlexRoot "bin\mxmlc.bat"

if (-not (Test-Path $Mxmlc)) {
    Write-Host "Apache Flex was not found."

    $flexFile = "apache-flex-sdk-$FlexVersion-bin.zip"

    $flexUri = (
        "https://archive.apache.org/dist/flex/" +
        "$FlexVersion/binaries/$flexFile"
    )

    $flexZip = Join-Path $TempRoot $flexFile

    Invoke-Download `
        -Uri $flexUri `
        -OutFile $flexZip

    Reset-Directory $FlexRoot

    Expand-Archive `
        -Path $flexZip `
        -DestinationPath $FlexRoot `
        -Force

    Remove-Item $flexZip -Force

    if (-not (Test-Path $Mxmlc)) {
        throw "Flex installation completed but mxmlc.bat was not found."
    }

    Write-Host "Apache Flex installed to:"
    Write-Host "  $FlexRoot"
}
else {
    Write-Host "Apache Flex already exists:"
    Write-Host "  $FlexRoot"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Step "Scaleform environment installed"

Write-Host ""
Write-Host "Repository:"
Write-Host "  $RepoRoot"
Write-Host ""
Write-Host "Workspace:"
Write-Host "  $WorkRoot"
Write-Host ""
Write-Host "Tools:"
Write-Host "  Java  : $JavaRoot"
Write-Host "  Flex  : $FlexRoot"
Write-Host "  JPEXS : $JpexsRoot"
Write-Host ""
Write-Host "Pipeline directories:"
Write-Host "  Build      : $BuildRoot"
Write-Host "  Decompiled : $DecompileRoot"
Write-Host "  Extracted  : $ExtractRoot"
Write-Host "  Logs       : $LogRoot"
Write-Host "  Temp       : $TempRoot"
Write-Host ""
Write-Host "No machine-wide software or environment variables were modified."