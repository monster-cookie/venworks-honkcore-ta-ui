<#
.SYNOPSIS
Exercises the production Canvas source-contract preflight against isolated fixtures.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'sharedCanvasCompatibility.ps1')

$fixtureRoot = Join-Path $repositoryRoot ('.work/canvas-compatibility-test/' + [guid]::NewGuid().ToString('N'))
try {
  $registryPath = Join-Path $fixtureRoot 'Papyrus/Venworks/Canvas/Registry.psc'
  $hostPath = Join-Path $fixtureRoot 'Scaleform/canvas/actionscript/CanvasHost.as'
  $enginePath = Join-Path $fixtureRoot 'Scaleform/canvas/actionscript/CanvasHtmlEngine.as'
  $decoderPath = Join-Path $fixtureRoot 'Scaleform/canvas/actionscript/CanvasDdsDecoder.as'
  foreach ($path in @($registryPath,$hostPath,$enginePath,$decoderPath)) { New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($path)) | Out-Null }
  [IO.File]::WriteAllText($registryPath, "String Function BuildCanvasDatagramBody()`nEndFunction`nOperationResult Function TryPublishCanvasDatagram()`nEndFunction")
  [IO.File]::WriteAllText($hostPath, 'private static const DATAGRAM_CONSUMER_PROTOCOL:String = "VWCANVAS_CONSUMER/3";')
  [IO.File]::WriteAllText($enginePath, 'if(param2.contract != "VWCANVAS_HTML/2") {}')
  [IO.File]::WriteAllText($decoderPath, 'public static function upload(width:int, height:int, pixels:ByteArray) : BitmapData { return null; }')

  Assert-VWHudCanvasCompatibility -CanvasProjectPath $fixtureRoot

  [IO.File]::WriteAllText($decoderPath, 'public static function read(bytes:ByteArray) : Object { return null; }')
  try {
    Assert-VWHudCanvasCompatibility -CanvasProjectPath $fixtureRoot
    throw 'Canvas fixture without DDS plate upload unexpectedly passed the VWHUD contract preflight.'
  }
  catch {
    if ($_.Exception.Message -cnotmatch 'Missing: DDS plate upload') { throw }
  }
  [IO.File]::WriteAllText($decoderPath, 'public static function upload(width:int, height:int, pixels:ByteArray) : BitmapData { return null; }')

  [IO.File]::WriteAllText($hostPath, 'private static const CONSUMER_PROTOCOL:String = "VWCANVAS_CONSUMER/2";')
  try {
    Assert-VWHudCanvasCompatibility -CanvasProjectPath $fixtureRoot
    throw 'Incompatible Canvas fixture unexpectedly passed the VWHUD contract preflight.'
  }
  catch {
    if ($_.Exception.Message -cnotmatch 'Missing: VWCANVAS_CONSUMER/3 host support') { throw }
  }
}
finally {
  if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}

Write-Host 'Validated Canvas compatibility preflight acceptance and rejection.'
