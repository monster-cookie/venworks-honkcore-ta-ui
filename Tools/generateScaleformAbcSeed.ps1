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
$mxmlcJarPath = Resolve-RequiredFile -Path (Join-Path $resolvedFlexSdkPath 'lib\mxmlc.jar') -Description 'Apache Flex mxmlc compiler'
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
$duplicateClassNames = @($classes | Group-Object Name | Where-Object Count -gt 1)
if ($duplicateClassNames.Count -gt 0) {
  $duplicateNames = ($duplicateClassNames.Name | Sort-Object) -join ', '
  throw "Single-domain seed imports require unique authored class names; duplicates: $duplicateNames"
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("venworks-cui-seed-" + [guid]::NewGuid().ToString('N'))
$stubRoot = Join-Path $temporaryRoot 'stubs'
$rootSourceDirectory = Join-Path $temporaryRoot 'root'
$seedRootPath = Join-Path $rootSourceDirectory 'CUISeedRoot.as'
$seedSwfPath = Join-Path $temporaryRoot 'cui-seed.swf'
$seedXmlPath = Join-Path $temporaryRoot 'seed.xml'

try {
  New-Item -ItemType Directory -Force -Path $stubRoot, $rootSourceDirectory | Out-Null
  foreach ($class in $classes) {
    $packageDirectory = Join-Path $stubRoot ($class.Package.Replace('.', [System.IO.Path]::DirectorySeparatorChar))
    New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
    $stubPath = Join-Path $packageDirectory "$($class.Name).as"
    $stubText = "package $($class.Package)`r`n{`r`n   public class $($class.Name)`r`n   {`r`n      public function $($class.Name)()`r`n      {`r`n      }`r`n   }`r`n}`r`n"
    [System.IO.File]::WriteAllText($stubPath, $stubText, [System.Text.UTF8Encoding]::new($false))
  }

  $classImports = ($classes.QualifiedName | ForEach-Object { "   import $_;" }) -join "`r`n"
  $classReferences = ($classes.Name | ForEach-Object { "         $_" }) -join ",`r`n"
  $seedRootText = "package`r`n{`r`n   import flash.display.Sprite;`r`n$classImports`r`n`r`n   public final class CUISeedRoot extends Sprite`r`n   {`r`n      private static const CLASSES:Array = [`r`n$classReferences`r`n      ];`r`n`r`n      public function CUISeedRoot()`r`n      {`r`n         super();`r`n      }`r`n   }`r`n}`r`n"
  [System.IO.File]::WriteAllText($seedRootPath, $seedRootText, [System.Text.UTF8Encoding]::new($false))

  $compilerArguments = @(
    '-jar', $mxmlcJarPath,
    "-load-config=$flexConfigPath",
    '-compiler.source-path', $stubRoot,
    '-compiler.library-path=',
    '-compiler.external-library-path', $resolvedPlayerGlobalPath,
    '-output', $seedSwfPath,
    $seedRootPath
  )
  Push-Location (Join-Path $resolvedFlexSdkPath 'frameworks')
  try {
    & $resolvedJavaPath @compilerArguments
  }
  finally {
    Pop-Location
  }
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $seedSwfPath -PathType Leaf)) {
    throw "Apache Flex mxmlc failed with exit code $LASTEXITCODE."
  }
  & $resolvedJavaPath -jar $resolvedJpexsJarPath -swf2xml $seedSwfPath $seedXmlPath
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $seedXmlPath -PathType Leaf)) {
    throw "JPEXS seed export failed with exit code $LASTEXITCODE."
  }

  $seedDocument = [xml](Get-Content -LiteralPath $seedXmlPath -Raw)
  $abcTags = @($seedDocument.SelectNodes('/swf/tags/item[@type="DoABC2Tag"]'))
  if ($abcTags.Count -ne 1) {
    throw "Generated seed must contain exactly one Venworks ABC linkage domain; found $($abcTags.Count)."
  }
  foreach ($class in $classes) {
    $abcClassName = "$($class.Package):$($class.Name)"
    if (!$abcTags[0].InnerText.Contains($abcClassName)) {
      throw "Generated single-domain seed is missing authored class $($class.QualifiedName)."
    }
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
  $abcTag = $outputDocument.ImportNode($abcTags[0], $true)
  $abcTag.SetAttribute('flags', '1')
  $abcTag.SetAttribute('forceWriteAsLong', 'true')
  $abcTag.SetAttribute('name', 'venworks.cui.components.seed.000')
  [void]$tags.AppendChild($abcTag)

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
  Write-Host "Generated one ABC linkage domain for $($classes.Count) authored classes: $OutputPath"
}
finally {
  if (Test-Path -LiteralPath $temporaryRoot) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}
