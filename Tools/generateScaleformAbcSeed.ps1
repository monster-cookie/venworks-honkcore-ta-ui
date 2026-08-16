[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$FlexSdkPath,

  [Parameter(Mandatory = $true)]
  [string]$PlayerGlobalPath,

  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [string]$ActionScriptSourcePath = (Join-Path $PSScriptRoot '..\Scaleform\shared\actionscript'),

  [string]$OutputPath = (Join-Path $PSScriptRoot '..\Scaleform\shared\patches\cui-component-abc-seed.xml')
)

$ErrorActionPreference = 'Stop'

function Resolve-RequiredFile {
  param([string]$Path, [string]$Description)
  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
  if ($null -eq $resolved -or !(Test-Path -LiteralPath $resolved.Path -PathType Leaf)) {
    throw "$Description does not exist: $Path"
  }
  return $resolved.Path
}

function Resolve-RequiredDirectory {
  param([string]$Path, [string]$Description)
  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
  if ($null -eq $resolved -or !(Test-Path -LiteralPath $resolved.Path -PathType Container)) {
    throw "$Description does not exist: $Path"
  }
  return $resolved.Path
}

$resolvedFlexSdkPath = Resolve-RequiredDirectory -Path $FlexSdkPath -Description 'Apache Flex SDK directory'
$resolvedPlayerGlobalPath = Resolve-RequiredFile -Path $PlayerGlobalPath -Description 'playerglobal.swc'
$resolvedJavaPath = Resolve-RequiredFile -Path $JavaPath -Description 'Java executable'
$resolvedJpexsJarPath = Resolve-RequiredFile -Path $JpexsJarPath -Description 'JPEXS JAR'
$resolvedActionScriptSourcePath = Resolve-RequiredDirectory -Path $ActionScriptSourcePath -Description 'Authored ActionScript directory'
$compcJarPath = Resolve-RequiredFile -Path (Join-Path $resolvedFlexSdkPath 'lib\compc.jar') -Description 'Apache Flex compc compiler'
$flexConfigPath = Resolve-RequiredFile -Path (Join-Path $resolvedFlexSdkPath 'frameworks\flex-config.xml') -Description 'Apache Flex compiler configuration'

$classes = @()
foreach ($sourceFile in Get-ChildItem -LiteralPath $resolvedActionScriptSourcePath -Recurse -File -Filter '*.as') {
  $sourceText = Get-Content -LiteralPath $sourceFile.FullName -Raw
  $packageMatch = [regex]::Match($sourceText, '(?m)^package\s+([A-Za-z_][A-Za-z0-9_.]*)\s*$')
  $classMatch = [regex]::Match($sourceText, '(?m)^\s*public\s+(?:final\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)\b')
  if (!$packageMatch.Success -or !$classMatch.Success) {
    throw "Unable to discover one public class in $($sourceFile.FullName)."
  }
  $classes += [pscustomobject]@{
    Package = $packageMatch.Groups[1].Value
    Name = $classMatch.Groups[1].Value
    QualifiedName = "$($packageMatch.Groups[1].Value).$($classMatch.Groups[1].Value)"
  }
}
$classes = @($classes | Sort-Object QualifiedName -Unique)
if ($classes.Count -eq 0) {
  throw 'No authored ActionScript classes were discovered.'
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("venworks-cui-seed-" + [guid]::NewGuid().ToString('N'))
$stubRoot = Join-Path $temporaryRoot 'stubs'
$swcPath = Join-Path $temporaryRoot 'cui-seed.swc'
$expandedSwcPath = Join-Path $temporaryRoot 'expanded'
$seedSwfPath = Join-Path $expandedSwcPath 'library.swf'
$seedXmlPath = Join-Path $temporaryRoot 'seed.xml'

try {
  New-Item -ItemType Directory -Force -Path $stubRoot | Out-Null
  foreach ($class in $classes) {
    $packageDirectory = Join-Path $stubRoot ($class.Package.Replace('.', [System.IO.Path]::DirectorySeparatorChar))
    New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
    $stubPath = Join-Path $packageDirectory "$($class.Name).as"
    $stubText = "package $($class.Package)`r`n{`r`n   public class $($class.Name)`r`n   {`r`n      public function $($class.Name)()`r`n      {`r`n      }`r`n   }`r`n}`r`n"
    [System.IO.File]::WriteAllText($stubPath, $stubText, [System.Text.UTF8Encoding]::new($false))
  }

  $compilerArguments = @(
    '-jar', $compcJarPath,
    "-load-config=$flexConfigPath",
    '-compiler.source-path', $stubRoot,
    '-compiler.library-path=',
    '-compiler.external-library-path', $resolvedPlayerGlobalPath,
    '-include-classes'
  ) + @($classes.QualifiedName) + @('-output', $swcPath)
  Push-Location (Join-Path $resolvedFlexSdkPath 'frameworks')
  try {
    & $resolvedJavaPath @compilerArguments
  }
  finally {
    Pop-Location
  }
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $swcPath -PathType Leaf)) {
    throw "Apache Flex compc failed with exit code $LASTEXITCODE."
  }

  Expand-Archive -LiteralPath $swcPath -DestinationPath $expandedSwcPath
  if (!(Test-Path -LiteralPath $seedSwfPath -PathType Leaf)) {
    throw 'The generated SWC does not contain library.swf.'
  }
  & $resolvedJavaPath -jar $resolvedJpexsJarPath -swf2xml $seedSwfPath $seedXmlPath
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $seedXmlPath -PathType Leaf)) {
    throw "JPEXS seed export failed with exit code $LASTEXITCODE."
  }

  $seedDocument = [xml](Get-Content -LiteralPath $seedXmlPath -Raw)
  $abcTags = @($seedDocument.SelectNodes('/swf/tags/item[@type="DoABC2Tag"]'))
  if ($abcTags.Count -lt $classes.Count) {
    throw "Generated seed contains $($abcTags.Count) ABC tags for $($classes.Count) authored classes."
  }
  $outputDocument = [System.Xml.XmlDocument]::new()
  $declaration = $outputDocument.CreateXmlDeclaration('1.0', 'utf-8', $null)
  [void]$outputDocument.AppendChild($declaration)
  $root = $outputDocument.CreateElement('scaleformAbcPatch')
  $root.SetAttribute('name', 'cui-component-abc-seed')
  $root.SetAttribute('version', '1')
  [void]$outputDocument.AppendChild($root)
  $tags = $outputDocument.CreateElement('tags')
  [void]$root.AppendChild($tags)
  $tagIndex = 0
  foreach ($sourceAbcTag in $abcTags) {
    $abcTag = $outputDocument.ImportNode($sourceAbcTag, $true)
    $abcTag.SetAttribute('flags', '1')
    $abcTag.SetAttribute('forceWriteAsLong', 'true')
    $abcTag.SetAttribute('name', ('venworks.cui.components.seed.{0:D3}' -f $tagIndex))
    [void]$tags.AppendChild($abcTag)
    $tagIndex++
  }

  $settings = [System.Xml.XmlWriterSettings]::new()
  $settings.Indent = $true
  $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
  $writer = [System.Xml.XmlWriter]::Create([System.IO.Path]::GetFullPath($OutputPath), $settings)
  try {
    $outputDocument.Save($writer)
  }
  finally {
    $writer.Dispose()
  }
  Write-Host "Generated ABC seed for $($classes.Count) authored classes: $OutputPath"
}
finally {
  if (Test-Path -LiteralPath $temporaryRoot) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}
