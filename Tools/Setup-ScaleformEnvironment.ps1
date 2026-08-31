#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$AcceptAdobeLicense,

    [string]$ArtifactCachePath
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$WorkRoot = Join-Path $RepoRoot ".work"
$ToolRoot = Join-Path $WorkRoot "tools"
$BuildRoot = Join-Path $WorkRoot "build"
$DecompileRoot = Join-Path $WorkRoot "decompiled"
$ExtractRoot = Join-Path $WorkRoot "extracted"
$LogRoot = Join-Path $WorkRoot "logs"
$TempRoot = Join-Path $WorkRoot "temp"
$JavaRoot = Join-Path $ToolRoot "java"
$FlexRoot = Join-Path $ToolRoot "flex"
$JpexsRoot = Join-Path $ToolRoot "jpexs"
$PlayerGlobalPath = Join-Path $FlexRoot "frameworks\libs\player\11.1\playerglobal.swc"

$JavaRelease = "21.0.12.1+1"
$JpexsVersion = "26.2.1"
$FlexVersion = "4.16.1"
$AdobeFlexVersion = "4.6.0.23201B"

$Artifacts = @{
    Java = @{
        FileName = "OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip"
        Uri = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip"
        Length = [int64]205073461
        Sha256 = "f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e"
    }
    Jpexs = @{
        FileName = "ffdec_26.2.1.zip"
        Uri = "https://github.com/jindrapetrik/jpexs-decompiler/releases/download/version26.2.1/ffdec_26.2.1.zip"
        Length = [int64]19824405
        Sha256 = "0333b56998a55bd83f4e0deb678a811fcdc45607582b4f5dd438309c8c3ad5ce"
    }
    Flex = @{
        FileName = "apache-flex-sdk-4.16.1-bin.zip"
        Uri = "https://archive.apache.org/dist/flex/4.16.1/binaries/apache-flex-sdk-4.16.1-bin.zip"
        Length = [int64]72396756
        Sha256 = "757aa19299c8a9c8af0901c1ae35f97fa94b7af0b0a9abc2bab04fe61d756e8b"
    }
    AdobeFlex = @{
        FileName = "flex_sdk_4.6.0.23201B.zip"
        Uri = "https://fpdownload.adobe.com/pub/flex/sdk/builds/flex4.6/flex_sdk_4.6.0.23201B.zip"
        Length = [int64]343973963
        Sha256 = "622b63f29de44600ff8d4231174a70fcb3085812c0e146a42e91877ca8b46798"
    }
}

$ExpectedJavaReleaseHash = "07117c72ce033949c14878e07fbf2fe23f59a1f8c90a6d1351b5c89099847ce7"
$ExpectedJpexsJarHash = "090ab695053ad94cba6408574c7d7eea20ec60b6ae789ee6056a23f45106762f"
$ExpectedFlexDescriptionHash = "e8bfe5fc4195379edab4044b0495d6cf10cf1be19ebeb400690344981d1538dd"
$ExpectedMxmlcJarHash = "cc07d749e376715e650271a9875289e49d94234902fff5e5fae287c478c8557b"
$ExpectedCompcJarHash = "843b4f9728d168abf3342585b47959d6120fa89718368e5d9acf636b2e7c6946"
$ExpectedPlayerGlobalLength = [int64]337288
$ExpectedPlayerGlobalHash = "2bbd5ffff3bb20c117db7206080079479b04c4b55d68dd21ab31b6566c99fb6b"

function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-NormalizedHash {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Algorithm = "SHA256"
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
}

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

    if ($file.Length -ne $Length) {
        return $false
    }

    if ((Get-NormalizedHash -Path $Path) -ne $Sha256) {
        return $false
    }

    return $true
}

function Assert-FileContract {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [hashtable]$Artifact
    )

    $contractMatches = Test-FileContract `
        -Path $Path `
        -Length $Artifact.Length `
        -Sha256 $Artifact.Sha256

    if (-not $contractMatches) {
        throw "Artifact failed its pinned length or checksum contract: $Path"
    }
}

function Assert-PathWithinDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Directory
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $resolvedDirectory = [System.IO.Path]::GetFullPath($Directory).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $requiredPrefix = $resolvedDirectory + [System.IO.Path]::DirectorySeparatorChar

    if (-not $resolvedPath.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the required directory '$resolvedDirectory': $resolvedPath"
    }
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

function Resolve-PinnedArtifact {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Artifact
    )

    $cacheFile = Join-Path $script:ResolvedArtifactCachePath $Artifact.FileName

    if (Test-Path -LiteralPath $cacheFile) {
        Assert-FileContract -Path $cacheFile -Artifact $Artifact
        Write-Host "Using pinned cached artifact:"
        Write-Host "  $cacheFile"
        return $cacheFile
    }

    New-Item -ItemType Directory -Path $script:ResolvedArtifactCachePath -Force | Out-Null

    $downloadPath = Join-Path $TempRoot ($Artifact.FileName + ".download-$PID")
    $cacheStagingPath = Join-Path $script:ResolvedArtifactCachePath ($Artifact.FileName + ".partial-$PID")

    Assert-PathWithinDirectory -Path $downloadPath -Directory $TempRoot
    Assert-PathWithinDirectory -Path $cacheStagingPath -Directory $script:ResolvedArtifactCachePath

    try {
        Invoke-Download -Uri $Artifact.Uri -OutFile $downloadPath
        Assert-FileContract -Path $downloadPath -Artifact $Artifact

        Copy-Item -LiteralPath $downloadPath -Destination $cacheStagingPath
        Assert-FileContract -Path $cacheStagingPath -Artifact $Artifact
        Move-Item -LiteralPath $cacheStagingPath -Destination $cacheFile

        Write-Host "Cached pinned artifact:"
        Write-Host "  $cacheFile"

        return $cacheFile
    }
    finally {
        foreach ($temporaryPath in @($downloadPath, $cacheStagingPath)) {
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force
            }
        }
    }
}

function Test-JavaInstallation {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $javaExe = Join-Path $Root "bin\java.exe"
    $releaseFile = Join-Path $Root "release"

    return (
        (Test-Path -LiteralPath $javaExe -PathType Leaf) -and
        (Test-FileContract `
            -Path $releaseFile `
            -Length 1664 `
            -Sha256 $ExpectedJavaReleaseHash)
    )
}

function Test-JpexsInstallation {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    return Test-FileContract `
        -Path (Join-Path $Root "ffdec.jar") `
        -Length 5075015 `
        -Sha256 $ExpectedJpexsJarHash
}

function Test-FlexInstallation {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    return (
        (Test-FileContract `
            -Path (Join-Path $Root "flex-sdk-description.xml") `
            -Length 994 `
            -Sha256 $ExpectedFlexDescriptionHash) -and
        (Test-FileContract `
            -Path (Join-Path $Root "lib\mxmlc.jar") `
            -Length 2107651 `
            -Sha256 $ExpectedMxmlcJarHash) -and
        (Test-FileContract `
            -Path (Join-Path $Root "lib\compc.jar") `
            -Length 5066 `
            -Sha256 $ExpectedCompcJarHash)
    )
}

function Test-PlayerGlobalInstallation {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-FileContract `
        -Path $Path `
        -Length $ExpectedPlayerGlobalLength `
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

function Replace-ToolDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    Assert-PathWithinDirectory -Path $SourcePath -Directory $TempRoot
    Assert-PathWithinDirectory -Path $DestinationPath -Directory $ToolRoot

    $backupPath = $DestinationPath + ".backup-$PID"
    Assert-PathWithinDirectory -Path $backupPath -Directory $ToolRoot

    if (Test-Path -LiteralPath $backupPath) {
        throw "Tool backup path already exists: $backupPath"
    }

    $hadDestination = Test-Path -LiteralPath $DestinationPath

    if ($hadDestination) {
        Move-Item -LiteralPath $DestinationPath -Destination $backupPath
    }

    try {
        Move-Item -LiteralPath $SourcePath -Destination $DestinationPath
    }
    catch {
        if ($hadDestination -and (Test-Path -LiteralPath $backupPath)) {
            Move-Item -LiteralPath $backupPath -Destination $DestinationPath
        }

        throw
    }

    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item -LiteralPath $backupPath -Recurse -Force
    }
}

function Install-Java {
    $archivePath = Resolve-PinnedArtifact -Artifact $Artifacts.Java
    $stagingRoot = Join-Path $TempRoot "java-extract-$PID"

    Assert-PathWithinDirectory -Path $stagingRoot -Directory $TempRoot

    try {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }

        Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingRoot

        $sourceDirectories = @(Get-ChildItem -LiteralPath $stagingRoot -Directory)

        if ($sourceDirectories.Count -ne 1) {
            throw "Pinned Temurin archive must contain exactly one top-level directory; found $($sourceDirectories.Count)."
        }

        $sourcePath = $sourceDirectories[0].FullName

        if (-not (Test-JavaInstallation -Root $sourcePath)) {
            throw "Pinned Temurin $JavaRelease archive did not produce the expected installation."
        }

        Replace-ToolDirectory -SourcePath $sourcePath -DestinationPath $JavaRoot
    }
    finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }
    }
}

function Install-Jpexs {
    $archivePath = Resolve-PinnedArtifact -Artifact $Artifacts.Jpexs
    $stagingRoot = Join-Path $TempRoot "jpexs-extract-$PID"

    Assert-PathWithinDirectory -Path $stagingRoot -Directory $TempRoot

    try {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }

        Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingRoot

        if (-not (Test-JpexsInstallation -Root $stagingRoot)) {
            throw "Pinned JPEXS $JpexsVersion archive did not produce the expected installation."
        }

        Replace-ToolDirectory -SourcePath $stagingRoot -DestinationPath $JpexsRoot
    }
    finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }
    }
}

function Install-Flex {
    $archivePath = Resolve-PinnedArtifact -Artifact $Artifacts.Flex
    $stagingRoot = Join-Path $TempRoot "flex-extract-$PID"

    Assert-PathWithinDirectory -Path $stagingRoot -Directory $TempRoot

    try {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }

        Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingRoot

        if (-not (Test-FlexInstallation -Root $stagingRoot)) {
            throw "Pinned Apache Flex $FlexVersion archive did not produce the expected installation."
        }

        Replace-ToolDirectory -SourcePath $stagingRoot -DestinationPath $FlexRoot
    }
    finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }
    }
}

function Install-PlayerGlobal {
    param(
        [Parameter(Mandatory)]
        [bool]$LicenseAccepted
    )

    if (-not $LicenseAccepted) {
        throw (
            "Player 11.1 installation requires acceptance of the Adobe Flex SDK license. " +
            "Review the license in the Adobe Flex SDK archive, then rerun setup with -AcceptAdobeLicense."
        )
    }

    $archivePath = Resolve-PinnedArtifact -Artifact $Artifacts.AdobeFlex
    $stagingPath = Join-Path $TempRoot "playerglobal-11.1-$PID.swc"

    Assert-PathWithinDirectory -Path $stagingPath -Directory $TempRoot

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)

        try {
            $entries = @(
                $archive.Entries |
                    Where-Object {
                        ($_.FullName -replace "\\", "/") -eq
                            "frameworks/libs/player/11.1/playerglobal.swc"
                    }
            )

            if ($entries.Count -ne 1) {
                throw "Pinned Adobe Flex SDK archive must contain exactly one Player 11.1 SWC; found $($entries.Count)."
            }

            $inputStream = $entries[0].Open()
            $outputStream = [System.IO.File]::Create($stagingPath)

            try {
                $inputStream.CopyTo($outputStream)
            }
            finally {
                $outputStream.Dispose()
                $inputStream.Dispose()
            }
        }
        finally {
            $archive.Dispose()
        }

        if (-not (Test-PlayerGlobalInstallation -Path $stagingPath)) {
            throw "Pinned Adobe Flex SDK $AdobeFlexVersion did not contain the expected Player 11.1 SWC."
        }

        $destinationDirectory = Split-Path -Parent $PlayerGlobalPath
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null

        $backupPath = $PlayerGlobalPath + ".backup-$PID"
        Assert-PathWithinDirectory -Path $PlayerGlobalPath -Directory $FlexRoot
        Assert-PathWithinDirectory -Path $backupPath -Directory $FlexRoot

        $hadDestination = Test-Path -LiteralPath $PlayerGlobalPath

        if ($hadDestination) {
            Move-Item -LiteralPath $PlayerGlobalPath -Destination $backupPath
        }

        try {
            Move-Item -LiteralPath $stagingPath -Destination $PlayerGlobalPath

            if (-not (Test-PlayerGlobalInstallation -Path $PlayerGlobalPath)) {
                throw "Installed Player 11.1 SWC failed post-installation validation."
            }
        }
        catch {
            if (Test-Path -LiteralPath $PlayerGlobalPath) {
                Remove-Item -LiteralPath $PlayerGlobalPath -Force
            }

            if ($hadDestination -and (Test-Path -LiteralPath $backupPath)) {
                Move-Item -LiteralPath $backupPath -Destination $PlayerGlobalPath
            }

            throw
        }

        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Force
        }
    }
    finally {
        if (Test-Path -LiteralPath $stagingPath) {
            Remove-Item -LiteralPath $stagingPath -Force
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ArtifactCachePath)) {
    $localAppData = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::LocalApplicationData
    )

    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw "Could not resolve the local application-data directory for the artifact cache."
    }

    $ArtifactCachePath = Join-Path $localAppData "Venworks\ScaleformArtifacts"
}

$script:ResolvedArtifactCachePath = [System.IO.Path]::GetFullPath($ArtifactCachePath)

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
    New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

Write-Host "Repository     : $RepoRoot"
Write-Host "Workspace      : $WorkRoot"
Write-Host "Artifact cache : $script:ResolvedArtifactCachePath"

Write-Step "Checking pinned Eclipse Temurin $JavaRelease"

if (Test-JavaInstallation -Root $JavaRoot) {
    Write-Host "Pinned Temurin installation is valid:"
    Write-Host "  $JavaRoot"
}
else {
    Install-Java
}

Write-Step "Checking pinned JPEXS $JpexsVersion"

if (Test-JpexsInstallation -Root $JpexsRoot) {
    Write-Host "Pinned JPEXS installation is valid:"
    Write-Host "  $JpexsRoot"
}
else {
    Install-Jpexs
}

Write-Step "Checking pinned Apache Flex SDK $FlexVersion"

if (Test-FlexInstallation -Root $FlexRoot) {
    Write-Host "Pinned Apache Flex installation is valid:"
    Write-Host "  $FlexRoot"
}
else {
    Install-Flex
}

Write-Step "Checking pinned Flash Player 11.1 compiler library"

if (Test-PlayerGlobalInstallation -Path $PlayerGlobalPath) {
    Write-Host "Pinned Player 11.1 SWC is valid:"
    Write-Host "  $PlayerGlobalPath"
}
else {
    Install-PlayerGlobal -LicenseAccepted $AcceptAdobeLicense.IsPresent
}

Write-Step "Scaleform environment installed"

Write-Host ""
Write-Host "No machine-wide software or environment variables were modified."
Write-Host "Running environment verification..."

& "$PSScriptRoot\Verify-ScaleformEnvironment.ps1"

exit $LASTEXITCODE
