# Every absolute element needs a relative or absolute parent. Canvas rejects a static parent with absolute-containing-block-required.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$resourcesRoot = Join-Path $repositoryRoot 'CanvasConsumer/resources'

function Get-PositionRules([string[]]$Stylesheets) {
  $rules = [Collections.Generic.List[object]]::new()
  foreach ($relative in $Stylesheets) {
    $text = [IO.File]::ReadAllText((Join-Path $resourcesRoot $relative)).Replace("`r`n","`n").Replace("`r","`n")
    foreach ($match in [regex]::Matches($text, '(?m)^(?<selector>[^{]+)\{(?<declarations>[^}]+)\}')) {
      $selector = $match.Groups['selector'].Value.Trim()
      if ($selector.Contains(',')) { throw "Unsupported CSS selector in ${relative}: $selector" }
      $positions = [regex]::Matches($match.Groups['declarations'].Value, 'position\s*:\s*(absolute|relative|static)')
      if ($positions.Count -eq 0) { continue }
      $rules.Add([pscustomobject]@{
        Selector = $selector
        Position = $positions[$positions.Count - 1].Groups[1].Value
      })
    }
  }
  return $rules
}

function Get-ElementPosition([object]$Rules, [string]$Name, [string[]]$Classes) {
  $position = 'static'
  foreach ($rule in $Rules) {
    $matchesName = $rule.Selector -ceq $Name
    $matchesClass = $rule.Selector.StartsWith('.') -and @($Classes) -ccontains $rule.Selector.Substring(1)
    if ($matchesName -or $matchesClass) { $position = $rule.Position }
  }
  return $position
}

function Read-Body([string]$Path) {
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n","`n").Replace("`r","`n")
  $match = [regex]::Match($text, '(?s)<body(?<attributes>[^>]*)>(?<inner>.*)</body>\s*</html>\s*$')
  if (!$match.Success) { throw "Canvas document is missing a single body: $Path" }
  return $match
}

function Add-Elements([string]$Html, [object]$Parent, [object]$Rules, [string]$Resource) {
  $stack = [Collections.Generic.Stack[object]]::new()
  $stack.Push($Parent)
  foreach ($match in [regex]::Matches($Html, '<(?<close>/)?(?<name>[a-z][a-z0-9-]*)(?<attributes>[^>]*)>')) {
    $name = $match.Groups['name'].Value
    if ($match.Groups['close'].Success) {
      if ($stack.Count -eq 0 -or $stack.Peek().Name -cne $name) { throw "Mismatched </$name> in $Resource" }
      [void]$stack.Pop()
      continue
    }
    $attributes = $match.Groups['attributes'].Value
    $classes = @()
    $classMatch = [regex]::Match($attributes, 'class="([^"]*)"')
    if ($classMatch.Success) {
      $classes = @($classMatch.Groups[1].Value.Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
    }
    if ($name -ceq 'vw-include') {
      $sourceMatch = [regex]::Match($attributes, 'src="([^"]+)"')
      if (!$sourceMatch.Success) { throw "vw-include is missing src in $Resource" }
      $included = Read-Body (Join-Path $resourcesRoot $sourceMatch.Groups[1].Value)
      Add-Elements $included.Groups['inner'].Value $stack.Peek() $Rules $sourceMatch.Groups[1].Value
      $stack.Push([pscustomobject]@{ Name = 'vw-include'; Position = 'static'; Children = $null; Resource = $Resource })
      continue
    }
    $node = [pscustomobject]@{
      Name = $name
      Position = (Get-ElementPosition $Rules $name $classes)
      Children = $null
      Resource = $Resource
    }
    if ($null -eq $stack.Peek().Children) { throw "Opened <$name> inside a childless element in $Resource" }
    $stack.Peek().Children.Add($node)
    $stack.Push($node)
    $node.Children = [Collections.Generic.List[object]]::new()
  }
  if ($stack.Count -ne 1 -or $stack.Peek() -ne $Parent) { throw "Unclosed element in $Resource" }
}

function Assert-ContainingBlocks([object]$Node) {
  foreach ($child in @($Node.Children)) {
    if ($child.Name -ceq 'vw-include') { continue }
    if ($child.Position -ceq 'absolute' -and $Node.Position -ceq 'static') {
      throw "Absolute element in $($child.Resource) has a static parent $($Node.Name) from $($Node.Resource)."
    }
    Assert-ContainingBlocks $child
  }
}

$failures = [Collections.Generic.List[string]]::new()
foreach ($key in @('VWKS', 'TA', 'FC', 'CF', 'MIN')) {
  $indexPath = Join-Path $repositoryRoot "CanvasConsumer/variants/$key/index.html"
  $index = Read-Body $indexPath
  $indexText = [IO.File]::ReadAllText($indexPath)
  $stylesheets = @([regex]::Matches($indexText, 'href="([^"]+\.css)"') | ForEach-Object { $_.Groups[1].Value })
  $rules = Get-PositionRules $stylesheets
  $bodyClasses = @()
  $bodyClass = [regex]::Match($index.Groups['attributes'].Value, 'class="([^"]*)"')
  if ($bodyClass.Success) { $bodyClasses = @($bodyClass.Groups[1].Value.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) }
  $body = [pscustomobject]@{
    Name = 'body'
    Position = (Get-ElementPosition $rules 'body' $bodyClasses)
    Children = [Collections.Generic.List[object]]::new()
    Resource = 'index.html'
  }
  if ($body.Position -cne 'relative') { $failures.Add("$key body position is $($body.Position); absolute panels require position: relative.") }
  Add-Elements $index.Groups['inner'].Value $body $rules 'index.html'
  try { Assert-ContainingBlocks $body }
  catch { $failures.Add("${key}: $($_.Exception.Message)") }
}

if ($failures.Count -ne 0) { throw ($failures -join [Environment]::NewLine) }
Write-Host 'Canvas absolute containing blocks passed for VWKS, TA, FC, CF, and MIN.'
