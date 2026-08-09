[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$JavaPath,

  [Parameter(Mandatory = $true)]
  [string]$JpexsJarPath,

  [Parameter(Mandatory = $true)]
  [string]$FontAwesomeRoot,

  [string]$OutputPath = (Join-Path $PSScriptRoot "..\Scaleform\shared\libraries\venworks-icons.swf"),

  [string]$WorkDirectory = (Join-Path $PSScriptRoot "..\Scaleform\.work\symbol-library"),

  [switch]$UpdateExpectedHash
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-File {
  param([string]$Path, [string]$Description)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Description was not found: $Path"
  }
}

function Invoke-Checked {
  param([string]$FilePath, [string[]]$Arguments, [string]$Description)
  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed with exit code $LASTEXITCODE."
  }
}

$java = [System.IO.Path]::GetFullPath($JavaPath)
$jpexsJar = [System.IO.Path]::GetFullPath($JpexsJarPath)
$fontAwesome = [System.IO.Path]::GetFullPath($FontAwesomeRoot)
$output = [System.IO.Path]::GetFullPath($OutputPath)
$work = [System.IO.Path]::GetFullPath($WorkDirectory)
$javac = Join-Path (Split-Path -Parent $java) "javac.exe"
$validationPath = Join-Path $PSScriptRoot "..\Scaleform\shared\libraries\validation\expected.sha256"
$venworksLogo = Join-Path $PSScriptRoot "..\Scaleform\shared\assets\venworks-logo.svg"
$fontAwesomeStyleRoot = Join-Path $fontAwesome "svgs\sharp-solid"

Assert-File -Path $java -Description "Java runtime"
Assert-File -Path $javac -Description "Java compiler"
Assert-File -Path $jpexsJar -Description "JPEXS jar"
Assert-File -Path $venworksLogo -Description "Venworks logo SVG"

$symbols = [ordered]@{
  "health" = "heart.svg"
  "oxygen" = "lungs.svg"
  "co2" = "wind.svg"
  "shield" = "shield-halved.svg"
  "armor" = "vest-patches.svg"
  "weapon" = "raygun.svg"
  "aiming" = "crosshairs.svg"
  "ship" = "shuttle-space.svg"
  "vehicle" = "car.svg"
  "fuel" = "gas-pump.svg"
  "cargo" = "box.svg"
  "scanner" = "radar.svg"
  "stealth" = "user-ninja.svg"
  "warning" = "triangle-exclamation.svg"
  "objective" = "bullseye.svg"
  "jolly-roger" = "skull-crossbones.svg"
  "death" = "skull.svg"
  "poison" = "flask-round-poison.svg"
  "burning" = "fire.svg"
  "electrocution" = "bolt.svg"
  "disease" = "disease.svg"
  "venworks-logo" = $venworksLogo
}

$resolvedSources = [ordered]@{}
foreach ($entry in $symbols.GetEnumerator()) {
  $source = if ([System.IO.Path]::IsPathRooted([string]$entry.Value)) {
    [string]$entry.Value
  } else {
    Join-Path $fontAwesomeStyleRoot ([string]$entry.Value)
  }
  Assert-File -Path $source -Description "Source SVG for symbol '$($entry.Key)'"
  $resolvedSources[$entry.Key] = $source
}

$sourceDirectory = Join-Path $work "source"
$classesDirectory = Join-Path $work "classes"
$shapeDirectory = Join-Path $work "shapes"
$scriptsDirectory = Join-Path $work "scripts"
$seedSwf = Join-Path $work "venworks-icons-seed.swf"
$compiledSwf = Join-Path $work "venworks-icons.swf"
$xmlPath = Join-Path $work "venworks-icons.xml"
$generatorPath = Join-Path $sourceDirectory "SymbolLibrarySeedGenerator.java"

New-Item -ItemType Directory -Path $sourceDirectory,$classesDirectory,$shapeDirectory,$scriptsDirectory,(Split-Path -Parent $output),(Split-Path -Parent $validationPath) -Force | Out-Null
Get-ChildItem -LiteralPath $shapeDirectory -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $scriptsDirectory -Recurse -File -Filter "VenworksCUI_*.as" -ErrorAction SilentlyContinue | Remove-Item -Force

$generatorSource = @'
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.abc.avm2.parser.script.AbcIndexing;
import com.jpexs.decompiler.flash.abc.avm2.parser.script.ActionScript3Parser;
import com.jpexs.decompiler.flash.tags.DefineShape3Tag;
import com.jpexs.decompiler.flash.tags.DefineSpriteTag;
import com.jpexs.decompiler.flash.tags.DoABC2Tag;
import com.jpexs.decompiler.flash.tags.EndTag;
import com.jpexs.decompiler.flash.tags.FileAttributesTag;
import com.jpexs.decompiler.flash.tags.PlaceObject2Tag;
import com.jpexs.decompiler.flash.tags.ShowFrameTag;
import com.jpexs.decompiler.flash.tags.SymbolClassTag;
import com.jpexs.decompiler.flash.types.MATRIX;
import com.jpexs.decompiler.flash.types.RECT;
import com.jpexs.decompiler.flash.types.SHAPEWITHSTYLE;
import java.io.FileOutputStream;
import java.util.ArrayList;

public final class SymbolLibrarySeedGenerator {
    private SymbolLibrarySeedGenerator() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            throw new IllegalArgumentException("Expected an output SWF path and at least one semantic-name/linkage pair.");
        }

        SWF.initPlayer();
        SWF swf = new SWF();
        swf.version = 12;
        swf.displayRect = new RECT(0, 10240, 0, 10240);
        swf.frameRate = 30;
        swf.frameCount = 1;

        FileAttributesTag attributes = new FileAttributesTag(swf);
        attributes.actionScript3 = true;
        swf.addTag(attributes);

        DoABC2Tag abcTag = new DoABC2Tag(swf);
        abcTag.name = "venworks.cui.symbols.seed";
        abcTag.flags = 1;
        swf.addTag(abcTag);
        abcTag.setTimelined(swf);

        AbcIndexing abcIndex = swf.getAbcIndex();
        abcIndex.selectAbc(abcTag.getABC());
        ActionScript3Parser parser = new ActionScript3Parser(abcIndex);

        SymbolClassTag symbols = new SymbolClassTag(swf);
        symbols.tags = new ArrayList<Integer>();
        symbols.names = new ArrayList<String>();

        int shapeCount = args.length - 1;
        ArrayList<String> semanticNames = new ArrayList<String>();
        ArrayList<String> linkageNames = new ArrayList<String>();
        for (int index = 1; index < args.length; index++) {
            int separator = args[index].indexOf('|');
            if (separator <= 0 || separator == args[index].length() - 1) {
                throw new IllegalArgumentException("Invalid semantic-name/linkage pair: " + args[index]);
            }
            semanticNames.add(args[index].substring(0, separator));
            linkageNames.add(args[index].substring(separator + 1));
        }

        for (int index = 0; index < linkageNames.size(); index++) {
            String className = linkageNames.get(index);
            String source = "package { import flash.display.MovieClip; public class " + className
                + " extends MovieClip { public function " + className + "() { super(); } } }";
            parser.addScript(source, className, 0, 0, swf.getDocumentClass(), abcTag.getABC());

            int shapeId = index + 1;
            DefineShape3Tag shape = new DefineShape3Tag(swf);
            shape.shapeId = shapeId;
            shape.shapeBounds = new RECT(0, 2000, 0, 2000);
            shape.shapes = SHAPEWITHSTYLE.createEmpty(3);
            shape.setModified(true);
            swf.addTag(shape);

            int spriteId = shapeCount + shapeId;
            DefineSpriteTag sprite = new DefineSpriteTag(swf);
            sprite.spriteId = spriteId;
            sprite.frameCount = 1;
            sprite.addTag(new PlaceObject2Tag(
                swf,
                false,
                1,
                shapeId,
                new MATRIX(),
                null,
                0,
                null,
                0,
                null
            ));
            sprite.addTag(new ShowFrameTag(swf));
            sprite.addTag(new EndTag(swf));
            sprite.hasEndTag = true;
            sprite.setModified(true);
            swf.addTag(sprite);

            symbols.tags.add(spriteId);
            symbols.names.add(className);
        }

        String controllerName = "VenworksCUI_SymbolLibrary";
        StringBuilder controllerSource = new StringBuilder();
        controllerSource.append("package { import flash.display.MovieClip; public dynamic class ")
            .append(controllerName)
            .append(" extends MovieClip { public function ")
            .append(controllerName)
            .append("() { super(); var requestedValue:Object = loaderInfo.parameters[\"symbol\"]; ")
            .append("var requested:String = requestedValue == null ? \"\" : String(requestedValue); switch(requested) {");
        for (int index = 0; index < semanticNames.size(); index++) {
            controllerSource.append("case \"")
                .append(semanticNames.get(index))
                .append("\": addChild(new ")
                .append(linkageNames.get(index))
                .append("()); break;");
        }
        controllerSource.append("default: break; } } } }");
        parser.addScript(controllerSource.toString(), controllerName, 0, 0, swf.getDocumentClass(), abcTag.getABC());
        symbols.tags.add(0);
        symbols.names.add(controllerName);

        abcTag.setModified(true);
        swf.addTag(symbols);
        swf.addTag(new ShowFrameTag(swf));
        swf.addTag(new EndTag(swf));
        swf.clearAllCache();
        swf.setModified(true);

        try (FileOutputStream output = new FileOutputStream(args[0])) {
            swf.saveTo(output);
        }
    }
}
'@

Set-Content -LiteralPath $generatorPath -Value $generatorSource -Encoding UTF8

$jpexsRoot = Split-Path -Parent $jpexsJar
$classPathItems = @($jpexsJar)
$jpexsLib = Join-Path $jpexsRoot "lib"
if (Test-Path -LiteralPath $jpexsLib -PathType Container) {
  $classPathItems += @(Get-ChildItem -LiteralPath $jpexsLib -Filter "*.jar" -File | ForEach-Object FullName)
}
$classPath = $classPathItems -join ";"

Invoke-Checked -FilePath $javac -Arguments @("-encoding","UTF-8","-cp",$classPath,"-d",$classesDirectory,$generatorPath) -Description "Symbol seed generator compilation"

$linkageNames = @()
$symbolDefinitions = @()
$shapeId = 1
foreach ($entry in $resolvedSources.GetEnumerator()) {
  $linkage = "VenworksCUI_venworks_icons_" + ([string]$entry.Key).Replace("-","_")
  $linkageNames += $linkage
  $symbolDefinitions += ("{0}|{1}" -f [string]$entry.Key, $linkage)
  Copy-Item -LiteralPath ([string]$entry.Value) -Destination (Join-Path $shapeDirectory ("{0}.svg" -f $shapeId)) -Force
  ++$shapeId
}

$runtimeClassPath = $classPath + ";" + $classesDirectory
Invoke-Checked -FilePath $java -Arguments (@("-cp",$runtimeClassPath,"SymbolLibrarySeedGenerator",$seedSwf) + $symbolDefinitions) -Description "Symbol seed generation"
Invoke-Checked -FilePath $java -Arguments @("-jar",$jpexsJar,"-importShapes",$seedSwf,$compiledSwf,$shapeDirectory) -Description "SVG shape import"
Invoke-Checked -FilePath $java -Arguments @("-jar",$jpexsJar,"-swf2xml",$compiledSwf,$xmlPath) -Description "Symbol library inspection export"
Invoke-Checked -FilePath $java -Arguments @("-jar",$jpexsJar,"-format","script:as","-export","script",$scriptsDirectory,$compiledSwf) -Description "Symbol library ActionScript export"

$exportedClasses = @(Get-ChildItem -LiteralPath $scriptsDirectory -Recurse -File -Filter "VenworksCUI_venworks_icons_*.as")
if ($exportedClasses.Count -ne $symbols.Count) {
  throw "Expected $($symbols.Count) exported linkage classes, found $($exportedClasses.Count)."
}
foreach ($linkage in $linkageNames) {
  $classFiles = @($exportedClasses | Where-Object { $_.BaseName -eq $linkage })
  if ($classFiles.Count -ne 1) {
    throw "Expected one exported ActionScript class for $linkage, found $($classFiles.Count)."
  }
  $classSource = Get-Content -LiteralPath $classFiles[0].FullName -Raw
  $classPattern = "public\s+(?:dynamic\s+)?class\s+" + [regex]::Escape($linkage) + "\s+extends\s+MovieClip\b"
  if ($classSource -notmatch $classPattern) {
    throw "Exported linkage class $linkage does not extend MovieClip."
  }
}

$controllerFiles = @(Get-ChildItem -LiteralPath $scriptsDirectory -Recurse -File -Filter "VenworksCUI_SymbolLibrary.as")
if ($controllerFiles.Count -ne 1) {
  throw "Expected one exported VenworksCUI_SymbolLibrary controller class, found $($controllerFiles.Count)."
}
$controllerSource = Get-Content -LiteralPath $controllerFiles[0].FullName -Raw
if ($controllerSource -notmatch 'class\s+VenworksCUI_SymbolLibrary\s+extends\s+MovieClip\b' -or
    $controllerSource -notmatch 'loaderInfo\.parameters\["symbol"\]' -or
    $controllerSource -notmatch 'addChild\s*\(') {
  throw "Exported VenworksCUI_SymbolLibrary does not contain the required loader-parameter controller."
}
foreach ($entry in $resolvedSources.GetEnumerator()) {
  if ($controllerSource -notmatch ('case\s+"' + [regex]::Escape([string]$entry.Key) + '"')) {
    throw "Symbol-library controller is missing semantic symbol '$($entry.Key)'."
  }
}

[xml]$scaleform = Get-Content -LiteralPath $xmlPath -Raw
$shapeTags = @($scaleform.SelectNodes('/swf/tags/item[@type="DefineShape3Tag"]'))
if ($shapeTags.Count -ne $symbols.Count) {
  throw "Expected $($symbols.Count) imported shapes, found $($shapeTags.Count)."
}
foreach ($shape in $shapeTags) {
  $width = [int]$shape.shapeBounds.Xmax - [int]$shape.shapeBounds.Xmin
  $height = [int]$shape.shapeBounds.Ymax - [int]$shape.shapeBounds.Ymin
  if ($width -le 0 -or $height -le 0) {
    throw "Imported shape $($shape.shapeId) has no renderable dimensions."
  }
}

$spriteTags = @($scaleform.SelectNodes('/swf/tags/item[@type="DefineSpriteTag"]'))
if ($spriteTags.Count -ne $symbols.Count) {
  throw "Expected $($symbols.Count) symbol wrapper sprites, found $($spriteTags.Count)."
}

$symbolTargets = @{}
foreach ($symbolClassTag in $scaleform.SelectNodes('/swf/tags/item[@type="SymbolClassTag"]')) {
  for ($index = 0; $index -lt $symbolClassTag.names.item.Count; ++$index) {
    $symbolTargets[[string]$symbolClassTag.names.item[$index]] = [int]$symbolClassTag.tags.item[$index]
  }
}

if (!$symbolTargets.ContainsKey('VenworksCUI_SymbolLibrary') -or
    [int]$symbolTargets['VenworksCUI_SymbolLibrary'] -ne 0) {
  throw "Compiled symbol library does not map VenworksCUI_SymbolLibrary to the root timeline."
}

for ($index = 0; $index -lt $linkageNames.Count; ++$index) {
  $linkage = $linkageNames[$index]
  $shapeId = $index + 1
  $expectedSpriteId = $symbols.Count + $shapeId
  if (!$symbolTargets.ContainsKey($linkage)) {
    throw "Compiled symbol library is missing linkage class: $linkage"
  }
  if ([int]$symbolTargets[$linkage] -ne $expectedSpriteId) {
    throw "Linkage $linkage targets character $($symbolTargets[$linkage]); expected wrapper sprite $expectedSpriteId."
  }

  $wrapper = $spriteTags | Where-Object { [int]$_.spriteId -eq $expectedSpriteId } | Select-Object -First 1
  if ($null -eq $wrapper) {
    throw "Wrapper sprite $expectedSpriteId was not found for $linkage."
  }
  if ([int]$wrapper.frameCount -ne 1 -or [string]$wrapper.hasEndTag -ne "true") {
    throw "Wrapper sprite $expectedSpriteId must contain exactly one completed frame."
  }

  $placedShapes = @($wrapper.subTags.item | Where-Object { [string]$_.type -eq "PlaceObject2Tag" })
  $showFrames = @($wrapper.subTags.item | Where-Object { [string]$_.type -eq "ShowFrameTag" })
  if ($placedShapes.Count -ne 1 -or $showFrames.Count -ne 1) {
    throw "Wrapper sprite $expectedSpriteId must contain one placed shape and one frame tag."
  }

  $placedShape = $placedShapes[0]
  if ([int]$placedShape.characterId -ne $shapeId -or [int]$placedShape.depth -ne 1) {
    throw "Wrapper sprite $expectedSpriteId does not place shape $shapeId at depth 1."
  }
  if ([string]$placedShape.matrix.hasScale -ne "false" -or
      [string]$placedShape.matrix.hasRotate -ne "false" -or
      [int]$placedShape.matrix.translateX -ne 0 -or
      [int]$placedShape.matrix.translateY -ne 0) {
    throw "Wrapper sprite $expectedSpriteId does not use an identity placement matrix."
  }
}

Copy-Item -LiteralPath $compiledSwf -Destination $output -Force
$hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
if ($UpdateExpectedHash) {
  Set-Content -LiteralPath $validationPath -Value ("{0}  venworks-icons.swf" -f $hash) -Encoding ASCII
} else {
  Assert-File -Path $validationPath -Description "Expected symbol library hash"
  $expected = ((Get-Content -LiteralPath $validationPath -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
  if ($hash -ne $expected) {
    throw "Symbol library hash mismatch. Expected $expected but built $hash."
  }
}

Write-Host "Compiled $($symbols.Count) symbols to $output"
Write-Host "SHA-256: $hash"
