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
  $loaderPath = Join-Path $fixtureRoot 'Scaleform/canvas/actionscript/CanvasHtmlDocumentLoader.as'
  foreach ($path in @($registryPath,$hostPath,$enginePath,$loaderPath)) { New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($path)) | Out-Null }
  [IO.File]::WriteAllText($registryPath, "String Function BuildCanvasDatagramBody()`nEndFunction`nOperationResult Function TryPublishCanvasDatagram()`nEndFunction")
  [IO.File]::WriteAllText($hostPath, 'private static const DATAGRAM_CONSUMER_PROTOCOL:String = "VWCANVAS_CONSUMER/3";')
  [IO.File]::WriteAllText($enginePath, 'if(param2.contract != "VWCANVAS_HTML/2") {}')
  [IO.File]::WriteAllText($loaderPath, 'loader.load(new URLRequest(this.resourceRoot + String(this.activeItem.path)));')

  Assert-VWHudCanvasCompatibility -CanvasProjectPath $fixtureRoot

  foreach ($rejectedLoader in @(
    'var textureUrl:String = "img://Textures/Interface/" + this.resourceRoot + String(this.activeItem.path);',
    'var dds:Object = CanvasDdsDecoder.read(bytes); loader.load(new URLRequest(this.resourceRoot + String(this.activeItem.path)));'
  )) {
    [IO.File]::WriteAllText($loaderPath, $rejectedLoader)
    try {
      Assert-VWHudCanvasCompatibility -CanvasProjectPath $fixtureRoot
      throw 'Canvas fixture with a runtime bitmap plate unexpectedly passed the VWHUD contract preflight.'
    }
    catch {
      if ($_.Exception.Message -cnotmatch 'Missing: runtime bitmap plate') { throw }
    }
  }
  [IO.File]::WriteAllText($loaderPath, 'loader.load(new URLRequest(this.resourceRoot + String(this.activeItem.path)));')

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
