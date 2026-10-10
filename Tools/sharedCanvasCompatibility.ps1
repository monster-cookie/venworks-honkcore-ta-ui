Set-StrictMode -Version Latest

function Assert-VWHudCanvasCompatibility {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$CanvasProjectPath)

  $canvasRoot = [IO.Path]::GetFullPath($CanvasProjectPath)
  function Read-RequiredCanvasSource([string]$RelativePath) {
    $path = Join-Path $canvasRoot $RelativePath
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Canvas source is missing: $path" }
    [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path).Path)
  }

  $registryText = Read-RequiredCanvasSource 'Papyrus/Venworks/Canvas/Registry.psc'
  $hostText = Read-RequiredCanvasSource 'Scaleform/canvas/actionscript/CanvasHost.as'
  $htmlEngineText = Read-RequiredCanvasSource 'Scaleform/canvas/actionscript/CanvasHtmlEngine.as'
  $loaderText = Read-RequiredCanvasSource 'Scaleform/canvas/actionscript/CanvasHtmlDocumentLoader.as'
  $missingCanvasContracts = [Collections.Generic.List[string]]::new()
  if ($hostText -cnotmatch 'DATAGRAM_CONSUMER_PROTOCOL:String\s*=\s*"VWCANVAS_CONSUMER/3"') { $missingCanvasContracts.Add('VWCANVAS_CONSUMER/3 host support') }
  if ($htmlEngineText -cnotmatch 'param2\.contract\s*!=\s*"VWCANVAS_HTML/2"') { $missingCanvasContracts.Add('VWCANVAS_HTML/2 rendering support') }
  if ($registryText -cnotmatch 'String Function BuildCanvasDatagramBody\s*\(') { $missingCanvasContracts.Add('Registry.BuildCanvasDatagramBody') }
  if ($registryText -cnotmatch 'OperationResult Function TryPublishCanvasDatagram\s*\(') { $missingCanvasContracts.Add('Registry.TryPublishCanvasDatagram') }
  if ($loaderText -cmatch 'CanvasDdsDecoder\.read\(' -or $loaderText -cmatch 'img://') { $missingCanvasContracts.Add('runtime bitmap plate') }
  if ($missingCanvasContracts.Count -ne 0) {
    throw "The selected Canvas checkout is incompatible with VWHUD. Missing: $([string]::Join(', ', $missingCanvasContracts)). Use a Venworks Canvas checkout that provides the missing contracts."
  }
}
