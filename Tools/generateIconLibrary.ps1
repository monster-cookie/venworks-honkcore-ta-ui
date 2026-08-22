[CmdletBinding()]
param(
  [Parameter()]
  [string]$FontAwesomeRoot = 'C:\FontAwesome',

  [Parameter()]
  [string]$OutputPath = (Join-Path $PSScriptRoot '..\Scaleform\shared\actionscript\venworks\cui\CUIIconLibrary.as')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$icons = [ordered]@{
  'health'        = 'heart.svg'
  'oxygen'        = 'lungs.svg'
  'co2'           = 'wind.svg'
  'shield'        = 'shield-halved.svg'
  'armor'         = 'vest-patches.svg'
  'weapon'        = 'raygun.svg'
  'aiming'        = 'crosshairs.svg'
  'ship'          = 'shuttle-space.svg'
  'vehicle'       = 'car.svg'
  'fuel'          = 'gas-pump.svg'
  'cargo'         = 'box.svg'
  'scanner'       = 'radar.svg'
  'stealth'       = 'user-ninja.svg'
  'warning'       = 'triangle-exclamation.svg'
  'objective'     = 'bullseye.svg'
  'jolly-roger'   = 'skull-crossbones.svg'
  'death'         = 'skull.svg'
  'poison'        = 'flask-round-poison.svg'
  'burning'       = 'fire.svg'
  'electrocution' = 'bolt.svg'
  'disease'       = 'disease.svg'
}

$sourceDirectory = Join-Path $FontAwesomeRoot 'svgs\sharp-solid'
$definitions = [System.Collections.Generic.List[object]]::new()

function Format-PathNumber {
  param([double]$Value)
  if ([Math]::Abs($Value) -lt 0.000000005) {
    $Value = 0
  }
  return $Value.ToString('0.########', [Globalization.CultureInfo]::InvariantCulture)
}

function Get-VectorAngle {
  param(
    [double]$Ux,
    [double]$Uy,
    [double]$Vx,
    [double]$Vy
  )
  return [Math]::Atan2(($Ux * $Vy) - ($Uy * $Vx), ($Ux * $Vx) + ($Uy * $Vy))
}

function Convert-SvgArcToCubics {
  param(
    [double]$StartX,
    [double]$StartY,
    [double]$RadiusX,
    [double]$RadiusY,
    [double]$RotationDegrees,
    [int]$LargeArcFlag,
    [int]$SweepFlag,
    [double]$EndX,
    [double]$EndY
  )

  $result = [System.Collections.Generic.List[string]]::new()
  if ($StartX -eq $EndX -and $StartY -eq $EndY) {
    return $result.ToArray()
  }

  $rx = [Math]::Abs($RadiusX)
  $ry = [Math]::Abs($RadiusY)
  if ($rx -eq 0 -or $ry -eq 0) {
    $result.Add(('L {0} {1}' -f (Format-PathNumber $EndX), (Format-PathNumber $EndY))) | Out-Null
    return $result.ToArray()
  }

  $phi = ($RotationDegrees % 360) * [Math]::PI / 180
  $cosPhi = [Math]::Cos($phi)
  $sinPhi = [Math]::Sin($phi)
  $halfDx = ($StartX - $EndX) / 2
  $halfDy = ($StartY - $EndY) / 2
  $xPrime = ($cosPhi * $halfDx) + ($sinPhi * $halfDy)
  $yPrime = (-$sinPhi * $halfDx) + ($cosPhi * $halfDy)

  $radiusScale = (($xPrime * $xPrime) / ($rx * $rx)) + (($yPrime * $yPrime) / ($ry * $ry))
  if ($radiusScale -gt 1) {
    $scale = [Math]::Sqrt($radiusScale)
    $rx *= $scale
    $ry *= $scale
  }

  $rxSquared = $rx * $rx
  $rySquared = $ry * $ry
  $xPrimeSquared = $xPrime * $xPrime
  $yPrimeSquared = $yPrime * $yPrime
  $denominator = ($rxSquared * $yPrimeSquared) + ($rySquared * $xPrimeSquared)
  $numerator = ($rxSquared * $rySquared) - ($rxSquared * $yPrimeSquared) - ($rySquared * $xPrimeSquared)
  $factor = 0.0
  if ($denominator -ne 0) {
    $factor = [Math]::Sqrt([Math]::Max(0, $numerator / $denominator))
  }
  if ($LargeArcFlag -eq $SweepFlag) {
    $factor = -$factor
  }

  $centerPrimeX = $factor * (($rx * $yPrime) / $ry)
  $centerPrimeY = $factor * (-($ry * $xPrime) / $rx)
  $centerX = ($cosPhi * $centerPrimeX) - ($sinPhi * $centerPrimeY) + (($StartX + $EndX) / 2)
  $centerY = ($sinPhi * $centerPrimeX) + ($cosPhi * $centerPrimeY) + (($StartY + $EndY) / 2)

  $startVectorX = ($xPrime - $centerPrimeX) / $rx
  $startVectorY = ($yPrime - $centerPrimeY) / $ry
  $endVectorX = (-$xPrime - $centerPrimeX) / $rx
  $endVectorY = (-$yPrime - $centerPrimeY) / $ry
  $startAngle = Get-VectorAngle 1 0 $startVectorX $startVectorY
  $sweepAngle = Get-VectorAngle $startVectorX $startVectorY $endVectorX $endVectorY
  if ($SweepFlag -eq 0 -and $sweepAngle -gt 0) {
    $sweepAngle -= 2 * [Math]::PI
  }
  elseif ($SweepFlag -eq 1 -and $sweepAngle -lt 0) {
    $sweepAngle += 2 * [Math]::PI
  }

  $segmentCount = [Math]::Max(1, [Math]::Ceiling([Math]::Abs($sweepAngle) / ([Math]::PI / 2)))
  $segmentAngle = $sweepAngle / $segmentCount
  for ($segmentIndex = 0; $segmentIndex -lt $segmentCount; ++$segmentIndex) {
    $theta1 = $startAngle + ($segmentIndex * $segmentAngle)
    $theta2 = $theta1 + $segmentAngle
    $alpha = (4.0 / 3.0) * [Math]::Tan(($theta2 - $theta1) / 4.0)

    $cos1 = [Math]::Cos($theta1)
    $sin1 = [Math]::Sin($theta1)
    $cos2 = [Math]::Cos($theta2)
    $sin2 = [Math]::Sin($theta2)
    $control1UnitX = $cos1 - ($alpha * $sin1)
    $control1UnitY = $sin1 + ($alpha * $cos1)
    $control2UnitX = $cos2 + ($alpha * $sin2)
    $control2UnitY = $sin2 - ($alpha * $cos2)

    $control1X = $centerX + ($rx * $cosPhi * $control1UnitX) - ($ry * $sinPhi * $control1UnitY)
    $control1Y = $centerY + ($rx * $sinPhi * $control1UnitX) + ($ry * $cosPhi * $control1UnitY)
    $control2X = $centerX + ($rx * $cosPhi * $control2UnitX) - ($ry * $sinPhi * $control2UnitY)
    $control2Y = $centerY + ($rx * $sinPhi * $control2UnitX) + ($ry * $cosPhi * $control2UnitY)
    $point2X = $centerX + ($rx * $cosPhi * $cos2) - ($ry * $sinPhi * $sin2)
    $point2Y = $centerY + ($rx * $sinPhi * $cos2) + ($ry * $cosPhi * $sin2)

    if ($segmentIndex -eq $segmentCount - 1) {
      $point2X = $EndX
      $point2Y = $EndY
    }
    $result.Add(('C {0} {1} {2} {3} {4} {5}' -f
      (Format-PathNumber $control1X), (Format-PathNumber $control1Y),
      (Format-PathNumber $control2X), (Format-PathNumber $control2Y),
      (Format-PathNumber $point2X), (Format-PathNumber $point2Y))) | Out-Null
  }
  return $result.ToArray()
}

function Convert-SvgPathToRuntimePath {
  param([string]$Data)

  $tokenPattern = '[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?'
  $remaining = [regex]::Replace($Data, $tokenPattern, '')
  if (($remaining -replace '[,\s]', '').Length -ne 0) {
    throw 'Path contains unsupported syntax.'
  }
  $tokens = @([regex]::Matches($Data, $tokenPattern) | ForEach-Object { $_.Value })
  $output = [System.Collections.Generic.List[string]]::new()
  $index = 0
  $command = $null
  $currentX = 0.0
  $currentY = 0.0
  $subpathX = 0.0
  $subpathY = 0.0

  while ($index -lt $tokens.Count) {
    if ($tokens[$index] -match '^[A-Za-z]$') {
      $command = $tokens[$index]
      ++$index
      if ($command -match '^[Zz]$') {
        $output.Add('Z') | Out-Null
        $currentX = $subpathX
        $currentY = $subpathY
        $command = $null
        continue
      }
    }
    if ($null -eq $command) {
      throw 'Path data requires a command before numeric parameters.'
    }

    $upper = $command.ToUpperInvariant()
    $parameterCount = switch ($upper) {
      'M' { 2 }
      'L' { 2 }
      'H' { 1 }
      'V' { 1 }
      'C' { 6 }
      'S' { 4 }
      'Q' { 4 }
      'T' { 2 }
      'A' { 7 }
      default { throw "Unsupported SVG path command: $command" }
    }
    if ($index + $parameterCount -gt $tokens.Count) {
      throw "SVG path command '$command' has too few parameters."
    }
    $values = [System.Collections.Generic.List[double]]::new()
    for ($parameterIndex = 0; $parameterIndex -lt $parameterCount; ++$parameterIndex) {
      $token = $tokens[$index + $parameterIndex]
      if ($token -match '^[A-Za-z]$') {
        throw "SVG path command '$command' has too few parameters."
      }
      $number = 0.0
      if (-not [double]::TryParse($token, [Globalization.NumberStyles]::Float,
          [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        throw "SVG path contains an invalid number: $token"
      }
      $values.Add($number)
    }
    $index += $parameterCount
    $relative = $command -cmatch '^[a-z]$'

    switch ($upper) {
      'M' {
        $x = $values[0] + $(if ($relative) { $currentX } else { 0 })
        $y = $values[1] + $(if ($relative) { $currentY } else { 0 })
        $output.Add(('M {0} {1}' -f (Format-PathNumber $x), (Format-PathNumber $y))) | Out-Null
        $currentX = $x; $currentY = $y; $subpathX = $x; $subpathY = $y
        $command = if ($relative) { 'l' } else { 'L' }
      }
      'L' {
        $x = $values[0] + $(if ($relative) { $currentX } else { 0 })
        $y = $values[1] + $(if ($relative) { $currentY } else { 0 })
        $output.Add(('L {0} {1}' -f (Format-PathNumber $x), (Format-PathNumber $y))) | Out-Null
        $currentX = $x; $currentY = $y
      }
      'H' {
        $x = $values[0] + $(if ($relative) { $currentX } else { 0 })
        $output.Add(('H {0}' -f (Format-PathNumber $x))) | Out-Null
        $currentX = $x
      }
      'V' {
        $y = $values[0] + $(if ($relative) { $currentY } else { 0 })
        $output.Add(('V {0}' -f (Format-PathNumber $y))) | Out-Null
        $currentY = $y
      }
      'C' {
        $x1 = $values[0] + $(if ($relative) { $currentX } else { 0 }); $y1 = $values[1] + $(if ($relative) { $currentY } else { 0 })
        $x2 = $values[2] + $(if ($relative) { $currentX } else { 0 }); $y2 = $values[3] + $(if ($relative) { $currentY } else { 0 })
        $x = $values[4] + $(if ($relative) { $currentX } else { 0 }); $y = $values[5] + $(if ($relative) { $currentY } else { 0 })
        $output.Add(('C {0} {1} {2} {3} {4} {5}' -f (Format-PathNumber $x1), (Format-PathNumber $y1), (Format-PathNumber $x2), (Format-PathNumber $y2), (Format-PathNumber $x), (Format-PathNumber $y))) | Out-Null
        $currentX = $x; $currentY = $y
      }
      'S' {
        $x2 = $values[0] + $(if ($relative) { $currentX } else { 0 }); $y2 = $values[1] + $(if ($relative) { $currentY } else { 0 })
        $x = $values[2] + $(if ($relative) { $currentX } else { 0 }); $y = $values[3] + $(if ($relative) { $currentY } else { 0 })
        $output.Add(('S {0} {1} {2} {3}' -f (Format-PathNumber $x2), (Format-PathNumber $y2), (Format-PathNumber $x), (Format-PathNumber $y))) | Out-Null
        $currentX = $x; $currentY = $y
      }
      'Q' {
        $x1 = $values[0] + $(if ($relative) { $currentX } else { 0 }); $y1 = $values[1] + $(if ($relative) { $currentY } else { 0 })
        $x = $values[2] + $(if ($relative) { $currentX } else { 0 }); $y = $values[3] + $(if ($relative) { $currentY } else { 0 })
        $output.Add(('Q {0} {1} {2} {3}' -f (Format-PathNumber $x1), (Format-PathNumber $y1), (Format-PathNumber $x), (Format-PathNumber $y))) | Out-Null
        $currentX = $x; $currentY = $y
      }
      'T' {
        $x = $values[0] + $(if ($relative) { $currentX } else { 0 }); $y = $values[1] + $(if ($relative) { $currentY } else { 0 })
        $output.Add(('T {0} {1}' -f (Format-PathNumber $x), (Format-PathNumber $y))) | Out-Null
        $currentX = $x; $currentY = $y
      }
      'A' {
        if (($values[3] -ne 0 -and $values[3] -ne 1) -or ($values[4] -ne 0 -and $values[4] -ne 1)) {
          throw 'SVG arc flags must be 0 or 1.'
        }
        $x = $values[5] + $(if ($relative) { $currentX } else { 0 }); $y = $values[6] + $(if ($relative) { $currentY } else { 0 })
        foreach ($curve in @(Convert-SvgArcToCubics $currentX $currentY $values[0] $values[1] $values[2] ([int]$values[3]) ([int]$values[4]) $x $y)) {
          $output.Add($curve) | Out-Null
        }
        $currentX = $x; $currentY = $y
      }
    }
  }
  return ($output -join ' ')
}

foreach ($entry in $icons.GetEnumerator()) {
  $sourcePath = Join-Path $sourceDirectory $entry.Value
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Missing Font Awesome source for '$($entry.Key)': $sourcePath"
  }

  [xml]$document = Get-Content -LiteralPath $sourcePath -Raw
  $svg = $document.DocumentElement
  if ($null -eq $svg -or $svg.LocalName -ne 'svg') {
    throw "'$($entry.Value)' does not have an SVG root element."
  }

  $viewBoxParts = @($svg.GetAttribute('viewBox') -split '[,\s]+' | Where-Object { $_ -ne '' })
  if ($viewBoxParts.Count -ne 4) {
    throw "'$($entry.Value)' must have a four-number viewBox."
  }

  $viewBox = foreach ($part in $viewBoxParts) {
    $number = 0.0
    if (-not [double]::TryParse($part, [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
      throw "'$($entry.Value)' contains invalid viewBox data."
    }
    $number
  }
  if ($viewBox[2] -le 0 -or $viewBox[3] -le 0) {
    throw "'$($entry.Value)' must have positive viewBox dimensions."
  }

  $elementChildren = @($svg.ChildNodes | Where-Object { $_.NodeType -eq [Xml.XmlNodeType]::Element })
  $unsupported = @($elementChildren | Where-Object { $_.LocalName -ne 'path' })
  if ($unsupported.Count -ne 0) {
    throw "'$($entry.Value)' contains unsupported SVG elements: $($unsupported.LocalName -join ', ')."
  }

  $paths = @($elementChildren | Where-Object { $_.LocalName -eq 'path' })
  if ($paths.Count -eq 0) {
    throw "'$($entry.Value)' contains no paths."
  }

  $pathData = [System.Collections.Generic.List[string]]::new()
  foreach ($path in $paths) {
    $data = $path.GetAttribute('d').Trim()
    if ([string]::IsNullOrWhiteSpace($data)) {
      throw "'$($entry.Value)' contains an empty path."
    }
    if ($data.Length -gt 8192) {
      throw "'$($entry.Value)' contains a path longer than the runtime limit."
    }
    if ($data -match '[^0-9eE+.,\sMmLlHhVvQqTtCcSsAaZz-]') {
      throw "'$($entry.Value)' contains unsupported SVG path syntax."
    }
    try {
      $data = Convert-SvgPathToRuntimePath $data
    }
    catch {
      throw "'$($entry.Value)' could not be converted for the runtime. $($_.Exception.Message)"
    }
    if ($data -match '[Aa]') {
      throw "'$($entry.Value)' still contains SVG arc commands after conversion."
    }
    $commandCount = ([regex]::Matches($data, '[MmLlHhVvQqTtCcSsZz]')).Count
    if ($commandCount -gt 512) {
      throw "'$($entry.Value)' exceeds the runtime command limit."
    }
    $tokenCount = ([regex]::Matches($data, '[MmLlHhVvQqTtCcSsZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')).Count
    if ($tokenCount -gt 2048) {
      throw "'$($entry.Value)' exceeds the runtime token limit."
    }
    $pathData.Add($data)
  }

  $definitions.Add([pscustomobject]@{
    Name = [string]$entry.Key
    ViewBoxX = [double]$viewBox[0]
    ViewBoxY = [double]$viewBox[1]
    ViewBoxWidth = [double]$viewBox[2]
    ViewBoxHeight = [double]$viewBox[3]
    Paths = @($pathData)
  })
}

function ConvertTo-As3Number {
  param([double]$Value)
  return $Value.ToString('0.################', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-As3String {
  param([string]$Value)
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('package venworks.cui')
$lines.Add('{')
$lines.Add('   import flash.display.Sprite;')
$lines.Add('')
$lines.Add('   // Generated by Tools/generateIconLibrary.ps1. Do not edit by hand.')
$lines.Add('   public final class CUIIconLibrary')
$lines.Add('   {')
$lines.Add('      private static const ICONS:Object = {')
for ($index = 0; $index -lt $definitions.Count; ++$index) {
  $definition = $definitions[$index]
  $paths = @($definition.Paths | ForEach-Object { ConvertTo-As3String $_ }) -join ','
  $suffix = if ($index -lt $definitions.Count - 1) { ',' } else { '' }
  $lines.Add(('         {0}:{{viewBoxX:{1},viewBoxY:{2},viewBoxWidth:{3},viewBoxHeight:{4},paths:[{5}]}}{6}' -f
    (ConvertTo-As3String $definition.Name),
    (ConvertTo-As3Number $definition.ViewBoxX),
    (ConvertTo-As3Number $definition.ViewBoxY),
    (ConvertTo-As3Number $definition.ViewBoxWidth),
    (ConvertTo-As3Number $definition.ViewBoxHeight),
    $paths,
    $suffix))
}
$lines.Add('      };')
$lines.Add('')
$lines.Add('      public static function isAllowlisted(param1:String) : Boolean')
$lines.Add('      {')
$lines.Add('         return ICONS[param1] != null;')
$lines.Add('      }')
$lines.Add('')
$lines.Add('      public static function create(param1:String) : Sprite')
$lines.Add('      {')
$lines.Add('         var definition:Object = ICONS[param1];')
$lines.Add('         var result:Sprite = null;')
$lines.Add('         var path:String = null;')
$lines.Add('         if(definition == null)')
$lines.Add('         {')
$lines.Add('            throw new Error("INVALID|Built-in icon is not allowlisted: " + param1);')
$lines.Add('         }')
$lines.Add('         result = new Sprite();')
$lines.Add('         result.graphics.beginFill(0,0);')
$lines.Add('         result.graphics.drawRect(definition.viewBoxX,definition.viewBoxY,definition.viewBoxWidth,definition.viewBoxHeight);')
$lines.Add('         result.graphics.endFill();')
$lines.Add('         for each(path in definition.paths)')
$lines.Add('         {')
$lines.Add('            result.graphics.beginFill(0xFFFFFF,1);')
$lines.Add('            CUISvgPathParser.draw(result.graphics,path,definition.viewBoxX,definition.viewBoxY,1,1);')
$lines.Add('            result.graphics.endFill();')
$lines.Add('         }')
$lines.Add('         return result;')
$lines.Add('      }')
$lines.Add('   }')
$lines.Add('}')

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
[IO.File]::WriteAllLines($resolvedOutput, $lines, [Text.UTF8Encoding]::new($false))

$hash = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Generated $($definitions.Count) built-in icons at $resolvedOutput"
Write-Host "SHA256 $hash"
