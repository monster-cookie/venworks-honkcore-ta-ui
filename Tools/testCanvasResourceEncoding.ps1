# Exercise the production consumer resource encoder against the Windows/Git checkout boundary.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'sharedCanvasConsumers.ps1')
$temporary = [IO.Path]::GetTempFileName()
try {
  $text = "<p>Oxygen — 100%</p>`n<p>Ready</p>`n"
  $expected = [Text.UTF8Encoding]::new($false).GetBytes($text)
  foreach ($ending in @("`n","`r`n","`r")) {
    foreach ($bom in @($false,$true)) {
      [IO.File]::WriteAllText($temporary,$text.Replace("`n",$ending),[Text.UTF8Encoding]::new($bom))
      $actual = Get-CanvasResourceBytes $temporary
      if ([Convert]::ToHexString($actual) -cne [Convert]::ToHexString($expected)) {
        throw 'Canvas resource encoding must produce the same UTF-8/LF bytes for every source line ending and BOM.'
      }
    }
  }
  [IO.File]::WriteAllText($temporary,$text.Replace('100%','99%'))
  if ([Convert]::ToHexString((Get-CanvasResourceBytes $temporary)) -ceq [Convert]::ToHexString($expected)) {
    throw 'Canvas resource encoding concealed a content change.'
  }
  Write-Host 'Canvas resource encoding passed LF, CRLF, CR, BOM, Unicode and content-change checks.'
}
finally {
  Remove-Item -LiteralPath $temporary -Force
}
