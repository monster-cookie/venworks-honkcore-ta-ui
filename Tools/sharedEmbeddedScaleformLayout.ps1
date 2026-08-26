$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-VenworksEmbeddedPaletteColors {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PalettePath
  )

  [xml]$palette = Get-Content -LiteralPath $PalettePath -Raw
  $colors = @{}
  foreach ($colorNode in @($palette.SelectNodes('/venworksCUIPalette/colors/color'))) {
    $role = [string]$colorNode.role
    $value = [string]$colorNode.value
    if ([string]::IsNullOrWhiteSpace($role) -or $value -notmatch '^#[0-9A-Fa-f]{6}$') {
      throw "Embedded-layout palette contains an invalid color entry: $PalettePath"
    }
    if ($colors.ContainsKey($role)) {
      throw "Embedded-layout palette repeats color role '$role': $PalettePath"
    }
    $colors[$role] = $value
  }
  if ($colors.Count -eq 0) {
    throw "Embedded-layout palette does not define any colors: $PalettePath"
  }

  return $colors
}

function Resolve-VenworksEmbeddedPaletteReferences {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text,

    [Parameter(Mandatory = $true)]
    [hashtable]$Colors,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $resolvedText = $Text
  foreach ($match in @([regex]::Matches($resolvedText, '@palette\.colors\.([A-Za-z][A-Za-z0-9.-]*)'))) {
    $role = [string]$match.Groups[1].Value
    if (!$Colors.ContainsKey($role)) {
      throw "$Context references unknown palette color '$role'."
    }
    $resolvedText = $resolvedText.Replace([string]$match.Value, [string]$Colors[$role])
  }
  if ($resolvedText -match '@palette\.') {
    throw "$Context retains an unresolved palette reference."
  }

  return $resolvedText
}

function Add-VenworksEmbeddedIdPrefix {
  param(
    [Parameter(Mandatory = $true)]
    [System.Xml.XmlElement]$Node,

    [Parameter(Mandatory = $true)]
    [string]$Prefix
  )

  if ($Node.HasAttribute('id')) {
    $Node.SetAttribute('id', $Prefix + $Node.GetAttribute('id'))
  }
  foreach ($child in @($Node.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] })) {
    Add-VenworksEmbeddedIdPrefix -Node $child -Prefix $Prefix
  }
}

function Get-VenworksEmbeddedLayoutText {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $true)]
    [object]$Variant,

    [Parameter(Mandatory = $true)]
    [hashtable]$VariantBuildProfile
  )

  $resolvedRoot = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $rootPrefix = $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar
  $resolveProfilePath = {
    param([string]$RelativePath, [string]$Description, [bool]$Directory)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
      throw "$Description must define a safe repository-relative path: $RelativePath"
    }
    $path = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $RelativePath))
    if (!$path.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "$Description resolves outside the repository: $path"
    }
    $pathType = if ($Directory) { 'Container' } else { 'Leaf' }
    if (!(Test-Path -LiteralPath $path -PathType $pathType)) {
      throw "$Description does not exist: $path"
    }
    return (Resolve-Path -LiteralPath $path).Path
  }

  $variantName = [string]$Variant.VariantName
  $layoutPath = & $resolveProfilePath ([string]$VariantBuildProfile.LayoutSource) "$variantName layout source" $false
  $componentDirectory = & $resolveProfilePath ([string]$VariantBuildProfile.ComponentSourceDirectory) "$variantName component source" $true
  $paletteDirectory = & $resolveProfilePath ([string]$VariantBuildProfile.PaletteSourceDirectory) "$variantName palette source" $true
  $palettePath = Join-Path $paletteDirectory ([string]$Variant.PaletteFileName)
  if (!(Test-Path -LiteralPath $palettePath -PathType Leaf)) {
    throw "$variantName selected palette does not exist: $palettePath"
  }

  if ([string]$VariantBuildProfile.PaletteMode -cne 'Literal') {
    throw "$variantName embedded layout must use literal palette resolution."
  }
  $colors = Get-VenworksEmbeddedPaletteColors -PalettePath $palettePath
  $layoutText = Resolve-VenworksEmbeddedPaletteReferences `
    -Text ([System.IO.File]::ReadAllText($layoutPath)) `
    -Colors $colors `
    -Context "$variantName layout"
  [xml]$layout = $layoutText
  $root = $layout.DocumentElement
  if ($null -eq $root -or $root.Name -cne 'venworksCUI' -or
      $root.GetAttribute('schemaVersion') -cne '1' -or
      $root.GetAttribute('runtimeVersion') -cne '1' -or
      $root.HasAttribute('palette')) {
    throw "$variantName embedded layout root is invalid or retains a palette selector."
  }

  $componentsNodes = @($layout.SelectNodes('/venworksCUI/components'))
  $includesNodes = @($layout.SelectNodes('/venworksCUI/includes'))
  if ($componentsNodes.Count -ne 1 -or $includesNodes.Count -ne 1) {
    throw "$variantName embedded layout must contain exactly one components and one includes element."
  }
  $includes = @($layout.SelectNodes('/venworksCUI/includes/include'))
  if ($includes.Count -gt 16) {
    throw "$variantName embedded layout exceeds the 16-component include limit."
  }
  $declaredFileNames = @($VariantBuildProfile.ComponentFileNames | ForEach-Object { [string]$_ } | Sort-Object)
  $includedFileNames = @($includes | ForEach-Object { [string]$_.GetAttribute('src') } | Sort-Object)
  if ($declaredFileNames.Count -ne $includedFileNames.Count -or
      [string]::Join("`n", $declaredFileNames) -cne [string]::Join("`n", $includedFileNames)) {
    throw "$variantName embedded layout includes do not match its component profile."
  }

  $allowedIncludeAttributes = @('id', 'src', 'x', 'y', 'anchor', 'visible', 'visibleWhen', 'z')
  $seenIds = @{}
  $seenSources = @{}
  foreach ($include in $includes) {
    foreach ($attribute in @($include.Attributes)) {
      if ([string]$attribute.Name -notin $allowedIncludeAttributes) {
        throw "$variantName include '$($include.GetAttribute('id'))' has unsupported attribute '$($attribute.Name)'."
      }
    }
    $id = $include.GetAttribute('id')
    $source = $include.GetAttribute('src')
    if ($id -notmatch '^[A-Za-z][A-Za-z0-9._-]{0,63}$' -or
        $source -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,59}\.xml$' -or
        $source.Contains('..') -or $seenIds.ContainsKey($id) -or $seenSources.ContainsKey($source)) {
      throw "$variantName contains an unsafe or duplicate component include: $id / $source"
    }
    $seenIds[$id] = $true
    $seenSources[$source] = $true

    $componentPath = Join-Path $componentDirectory $source
    if (!(Test-Path -LiteralPath $componentPath -PathType Leaf)) {
      throw "$variantName component include does not exist: $componentPath"
    }
    $fragmentText = Resolve-VenworksEmbeddedPaletteReferences `
      -Text ([System.IO.File]::ReadAllText($componentPath)) `
      -Colors $colors `
      -Context "$variantName component '$source'"
    [xml]$fragment = $fragmentText
    $fragmentRoot = $fragment.DocumentElement
    $fragmentGroups = @($fragment.SelectNodes('/venworksCUIFragment/group'))
    if ($null -eq $fragmentRoot -or $fragmentRoot.Name -cne 'venworksCUIFragment' -or
        $fragmentRoot.GetAttribute('schemaVersion') -cne '1' -or
        $fragmentRoot.GetAttribute('runtimeVersion') -cne '1' -or
        $fragmentRoot.Attributes.Count -ne 2 -or $fragmentGroups.Count -ne 1 -or
        @($fragmentRoot.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] }).Count -ne 1 -or
        @($fragment.SelectNodes('//include|//includes')).Count -ne 0) {
      throw "$variantName component '$source' must contain exactly one import-free version-1 group."
    }

    $group = [System.Xml.XmlElement]$layout.ImportNode($fragmentGroups[0], $true)
    Add-VenworksEmbeddedIdPrefix -Node $group -Prefix "$id."
    $wrapper = $layout.CreateElement('group')
    $wrapper.SetAttribute('id', $id)
    $wrapper.SetAttribute('x', $include.GetAttribute('x'))
    $wrapper.SetAttribute('y', $include.GetAttribute('y'))
    $wrapper.SetAttribute('width', $group.GetAttribute('width'))
    $wrapper.SetAttribute('height', $group.GetAttribute('height'))
    $wrapper.SetAttribute('opacity', '1')
    $wrapper.SetAttribute('visible', $(if ($include.HasAttribute('visible')) { $include.GetAttribute('visible') } else { 'true' }))
    if ($include.HasAttribute('visibleWhen')) {
      $wrapper.SetAttribute('visibleWhen', $include.GetAttribute('visibleWhen'))
    }
    $wrapper.SetAttribute('rotation', '0')
    $wrapper.SetAttribute('scaleX', '1')
    $wrapper.SetAttribute('scaleY', '1')
    $wrapper.SetAttribute('z', $include.GetAttribute('z'))
    if ($include.HasAttribute('anchor')) {
      $wrapper.SetAttribute('anchor', $include.GetAttribute('anchor'))
    }
    $group.SetAttribute('x', '0')
    $group.SetAttribute('y', '0')
    $group.SetAttribute('anchor', 'top-left')
    [void]$wrapper.AppendChild($group)
    [void]$componentsNodes[0].AppendChild($wrapper)
  }

  [void]$root.RemoveChild($includesNodes[0])
  $resolvedText = $root.OuterXml
  if ($resolvedText -match '(?i)<includes\b|<include\b|@palette\.|\bpalette="') {
    throw "$variantName embedded layout retains an include or palette reference."
  }
  return $resolvedText
}

function New-VenworksEmbeddedScaleformPatch {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePatchPath,

    [Parameter(Mandatory = $true)]
    [string]$EmbeddedLayoutPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
  )

  $marker = '__VENWORKS_EMBEDDED_LAYOUT__'
  $patchText = [System.IO.File]::ReadAllText($SourcePatchPath)
  $layoutText = [System.IO.File]::ReadAllText($EmbeddedLayoutPath).Trim()
  if ([regex]::Matches($patchText, [regex]::Escape($marker)).Count -ne 1) {
    throw "Embedded Scaleform patch must contain exactly one $marker marker: $SourcePatchPath"
  }
  if ([string]::IsNullOrWhiteSpace($layoutText) -or $layoutText -match '<\?xml') {
    throw "Embedded Scaleform layout must contain one declaration-free XML root: $EmbeddedLayoutPath"
  }
  $materializedPatch = $patchText.Replace($marker, $layoutText)
  [System.IO.File]::WriteAllText($OutputPath, $materializedPatch, [System.Text.UTF8Encoding]::new($false))
  [xml](Get-Content -LiteralPath $OutputPath -Raw) | Out-Null
  return (Resolve-Path -LiteralPath $OutputPath).Path
}
