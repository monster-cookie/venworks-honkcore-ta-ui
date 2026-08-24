[CmdletBinding()]
param(
  [string]$InterfacePath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-RequiredFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Description does not exist: $Path"
  }

  return (Resolve-Path -LiteralPath $Path).Path
}

function Read-ExpectedSha256 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $hashLine = Get-Content -LiteralPath $Path | Where-Object {
    $_ -match '^\s*[A-Fa-f0-9]{64}(?:\s|$)'
  } | Select-Object -First 1
  if (!$hashLine) {
    throw "No SHA-256 value was found in $Path."
  }

  return ([regex]::Match($hashLine, '[A-Fa-f0-9]{64}').Value).ToUpperInvariant()
}

function Get-ProviderRegistrations {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source
  )

  return @([regex]::Matches(
    $Source,
    'this\.subscribeProvider\s*\(\s*"(?<provider>[^"]+)"\s*,\s*this\.(?<handler>[A-Za-z][A-Za-z0-9]*)\s*\)'
  ) | ForEach-Object {
    [pscustomobject]@{
      Provider = [string]$_.Groups['provider'].Value
      Handler = [string]$_.Groups['handler'].Value
    }
  })
}

function Assert-ProviderLifecycle {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$Context,

    [Parameter(Mandatory = $true)]
    [object[]]$ExpectedRegistrations,

    [Parameter(Mandatory = $true)]
    [string]$Consumer
  )

  $actualRegistrations = @(Get-ProviderRegistrations -Source $Source)
  if ($actualRegistrations.Count -ne $ExpectedRegistrations.Count) {
    throw "$Context contains $($actualRegistrations.Count) registration intents; expected $($ExpectedRegistrations.Count)."
  }
  for ($index = 0; $index -lt $ExpectedRegistrations.Count; $index++) {
    $expected = $ExpectedRegistrations[$index]
    $actual = $actualRegistrations[$index]
    if ($actual.Provider -cne $expected.Provider -or $actual.Handler -cne $expected.Handler) {
      throw "$Context registration $($index + 1) is $($actual.Provider)/$($actual.Handler); expected $($expected.Provider)/$($expected.Handler)."
    }
  }

  $subscribeIndex = $Source.IndexOf('BSUIDataManager.Subscribe(param1,callback)')
  $pushIndex = $Source.IndexOf('this.providerSubscriptions.push(subscription)')
  if ([regex]::Matches($Source, 'BSUIDataManager\.Subscribe\s*\(').Count -ne 1 -or
      [regex]::Matches($Source, 'BSUIDataManager\.Unsubscribe\s*\(').Count -ne 1 -or
      [regex]::Matches($Source, 'callback\s*=\s*function\s*\(').Count -ne 1 -or
      $pushIndex -lt 0 -or $subscribeIndex -le $pushIndex) {
    throw "$Context does not use one guarded callback factory and one native subscribe/unsubscribe boundary."
  }

  foreach ($requiredPattern in @(
    'private\s+var\s+providerSubscriptions\s*:\s*Array',
    'private\s+var\s+started\s*:\s*Boolean\s*=\s*false',
    'private\s+var\s+disposed\s*:\s*Boolean\s*=\s*false',
    'private\s+var\s+faulted\s*:\s*Boolean\s*=\s*false',
    'public\s+function\s+start\s*\(',
    'state\s*:\s*"pending"',
    'subscription\.state\s*=\s*"active"',
    'this\.dispose\s*\(\s*\)',
    'CUI-EVT-SUBSCRIBE',
    'CUI-EVT-REENTRANT',
    'CUI-EVT-PAYLOAD',
    'CUI-EVT-CALLBACK',
    'providerSubscriptions\.pop\s*\(\s*\)',
    'String\(subscription\.state\)\s*==\s*"active"',
    'CUI-EVT-UNSUBSCRIBE',
    ('consumer\s*:\s*"' + [regex]::Escape($Consumer) + '"')
  )) {
    if ($Source -notmatch $requiredPattern) {
      throw "$Context is missing guarded lifecycle contract '$requiredPattern'."
    }
  }

  if ($Source -match 'CUIDataProvider(?:Hub|Broker)|fanout|fan-out') {
    throw "$Context introduces a shared provider broker or fan-out path."
  }

  return $actualRegistrations
}

function Assert-OrderedTokens {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Text,

    [Parameter(Mandatory = $true)]
    [string[]]$Tokens,

    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  $lastIndex = -1
  foreach ($token in $Tokens) {
    $tokenIndex = $Text.IndexOf($token, $lastIndex + 1, [System.StringComparison]::Ordinal)
    if ($tokenIndex -lt 0) {
      throw "$Context is missing '$token'."
    }
    $lastIndex = $tokenIndex
  }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$conditionPath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Scaleform\shared\actionscript\venworks\cui\CUIConditionContext.as") `
  -Description "Condition provider context"
$valuePath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Scaleform\shared\actionscript\venworks\cui\CUIPlayerHudDataContext.as") `
  -Description "Value provider context"
$runtimePath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Scaleform\shared\actionscript\venworks\cui\CUIRuntime.as") `
  -Description "CUI runtime"
$bootstrapPatchPath = Resolve-RequiredFile `
  -Path (Join-Path $repositoryRoot "Scaleform\shared\patches\cui-probe-loader.xml") `
  -Description "HUD bootstrap patch"

$conditionSource = [System.IO.File]::ReadAllText($conditionPath)
$valueSource = [System.IO.File]::ReadAllText($valuePath)
$runtimeSource = [System.IO.File]::ReadAllText($runtimePath)
$bootstrapPatchSource = [System.IO.File]::ReadAllText($bootstrapPatchPath)
[xml]$bootstrapPatchDocument = $bootstrapPatchSource

$conditionExpected = @(
  [pscustomobject]@{ Provider = "HudCrosshairData"; Handler = "onCrosshairData" },
  [pscustomobject]@{ Provider = "HUDStealthData"; Handler = "onStealthData" },
  [pscustomobject]@{ Provider = "HudCompassData"; Handler = "onCompassData" },
  [pscustomobject]@{ Provider = "HUDVehicleData"; Handler = "onVehicleData" },
  [pscustomobject]@{ Provider = "HUDOpacityData"; Handler = "onOpacityData" },
  [pscustomobject]@{ Provider = "WeaponData"; Handler = "onWeaponData" },
  [pscustomobject]@{ Provider = "HUDStarbornPowersData"; Handler = "onStarbornPowersData" },
  [pscustomobject]@{ Provider = "FavoritesData"; Handler = "onFavoritesData" },
  [pscustomobject]@{ Provider = "HudJetpackData"; Handler = "onJetpackData" },
  [pscustomobject]@{ Provider = "PlayerInventoryData"; Handler = "onPlayerInventoryData" }
)
$valueExpected = @(
  [pscustomobject]@{ Provider = "LocalEnvironmentData"; Handler = "onLocalEnvironmentData" },
  [pscustomobject]@{ Provider = "LocalEnvData_Frequent"; Handler = "onLocalEnvironmentFrequentData" },
  [pscustomobject]@{ Provider = "PlayerData"; Handler = "onPlayerData" },
  [pscustomobject]@{ Provider = "PlayerFrequentData"; Handler = "onPlayerFrequentData" },
  [pscustomobject]@{ Provider = "PlayerInventoryData"; Handler = "onPlayerInventoryData" },
  [pscustomobject]@{ Provider = "WeaponData"; Handler = "onWeaponData" },
  [pscustomobject]@{ Provider = "HudJetpackData"; Handler = "onJetpackData" },
  [pscustomobject]@{ Provider = "HUDStarbornPowersData"; Handler = "onStarbornPowersData" },
  [pscustomobject]@{ Provider = "FavoritesData"; Handler = "onFavoritesData" },
  [pscustomobject]@{ Provider = "ControlMapData"; Handler = "onControlMapData" },
  [pscustomobject]@{ Provider = "EnvironmentEffectsData"; Handler = "onEnvironmentEffectsData" },
  [pscustomobject]@{ Provider = "PersonalEffectsData"; Handler = "onPersonalEffectsData" },
  [pscustomobject]@{ Provider = "StarmapSystemBodyInfoProvider"; Handler = "onStarmapSystemBodyInfoData" },
  [pscustomobject]@{ Provider = "HudCompassData"; Handler = "onRadarCompassData" }
)

$conditionRegistrations = @(Assert-ProviderLifecycle `
  -Source $conditionSource `
  -Context "CUIConditionContext" `
  -ExpectedRegistrations $conditionExpected `
  -Consumer "CONDITION")
$valueRegistrations = @(Assert-ProviderLifecycle `
  -Source $valueSource `
  -Context "CUIPlayerHudDataContext" `
  -ExpectedRegistrations $valueExpected `
  -Consumer "VALUE")

$conditionProviders = @($conditionRegistrations.Provider)
$valueProviders = @($valueRegistrations.Provider)
$overlapProviders = @($conditionProviders | Where-Object {
  $valueProviders -ccontains $_
} | Sort-Object -Unique)
$expectedOverlapProviders = @(
  "FavoritesData",
  "HUDStarbornPowersData",
  "HudCompassData",
  "HudJetpackData",
  "PlayerInventoryData",
  "WeaponData"
) | Sort-Object
if ($overlapProviders.Count -ne $expectedOverlapProviders.Count) {
  throw "Provider overlap count changed from the approved six-provider baseline."
}
for ($index = 0; $index -lt $expectedOverlapProviders.Count; $index++) {
  if ($overlapProviders[$index] -cne $expectedOverlapProviders[$index]) {
    throw "Provider overlap changed. Expected '$($expectedOverlapProviders[$index])'; found '$($overlapProviders[$index])'."
  }
}

Assert-OrderedTokens -Text $runtimeSource -Context "Value provider startup" -Tokens @(
  "valueContext = new CUIPlayerHudDataContext()",
  "valueContext.addEventListener(CUIPlayerHudDataContext.PROVIDER_ERROR,this.onProviderError)",
  "valueContext.start()",
  "paletteLoader.load(config)"
)
Assert-OrderedTokens -Text $runtimeSource -Context "Condition provider startup" -Tokens @(
  "conditionContext = new CUIConditionContext()",
  "conditionContext.addEventListener(CUIConditionContext.PROVIDER_ERROR,this.onProviderError)",
  "conditionContext.start()",
  "conditionContext.addEventListener(CUIConditionContext.CONDITION_CHANGE,this.onConditionChanged)"
)

foreach ($requiredRuntimePattern in @(
  'private\s+function\s+onProviderError',
  'CUI EVENT HANDLER ERROR',
  'CUI EVENT REGISTRATION ERROR',
  'CODE: CUI-EVT-CALLBACK',
  'CODE: CUI-EVT-TEARDOWN',
  'owner\.addEventListener\(Event\.ENTER_FRAME,this\.onDeferredComponentTeardown\)',
  'owner\.removeEventListener\(Event\.ENTER_FRAME,this\.onDeferredComponentTeardown\)',
  'owner\.addEventListener\(Event\.REMOVED_FROM_STAGE,this\.onOwnerRemovedFromStage\)',
  'public\s+function\s+dispose\s*\(',
  'conditionContext\.removeEventListener\(CUIConditionContext\.PROVIDER_ERROR,this\.onProviderError\)',
  'valueContext\.removeEventListener\(CUIPlayerHudDataContext\.PROVIDER_ERROR,this\.onProviderError\)',
  'conditionContext\.dispose\(\)',
  'valueContext\.dispose\(\)'
)) {
  if ($runtimeSource -notmatch $requiredRuntimePattern) {
    throw "CUIRuntime is missing PS5 event lifecycle contract '$requiredRuntimePattern'."
  }
}
foreach ($eventPhase in @(
  "VANILLA SAFE-RECT PLACEMENT",
  "VANILLA HUD MODE VISIBILITY",
  "CONDITION CHANGE",
  "VALUE CHANGE",
  "COMPASS CHANGE",
  "TACTICAL AWARENESS CHANGE"
)) {
  if ($runtimeSource -notmatch ('showLiveEventError\([^;]+,"' + [regex]::Escape($eventPhase) + '"\)')) {
    throw "CUIRuntime does not contain errors from the $eventPhase callback."
  }
}

foreach ($bootstrapPattern in @(
  'import\s+venworks\.cui\.CUIDiagnosticsPanel',
  'VenworksCUIRuntimeInstance\.isDisposed',
  'try\s*\{',
  'catch\(venworksBootstrapError:Error\)',
  'CUI-EVT-BOOTSTRAP',
  'VenworksCUIBootstrapDiagnostics\.showError'
)) {
  if ($bootstrapPatchSource -notmatch $bootstrapPattern) {
    throw "HUD bootstrap patch is missing early failure contract '$bootstrapPattern'."
  }
}

if ($conditionSource + $valueSource + $runtimeSource -match 'CUIDataProvider(?:Hub|Broker)|fanout|fan-out') {
  throw "PS5 lifecycle sources contain a shared provider broker or fan-out path."
}

if (![string]::IsNullOrWhiteSpace($InterfacePath)) {
  if (!(Test-Path -LiteralPath $InterfacePath -PathType Container)) {
    throw "PS5 Scaleform Interface output does not exist: $InterfacePath"
  }
  $resolvedInterfacePath = (Resolve-Path -LiteralPath $InterfacePath).Path
  foreach ($movie in @(
    [pscustomobject]@{
      FileName = "hudmenu.gfx"
      ExpectedHashPath = "Scaleform\ps5-minimalist\validation\hudmenu.sha256"
    },
    [pscustomobject]@{
      FileName = "hudmenu_lrg.gfx"
      ExpectedHashPath = "Scaleform\ps5-minimalist\validation\hudmenu_lrg.sha256"
    }
  )) {
    $moviePath = Resolve-RequiredFile `
      -Path (Join-Path $resolvedInterfacePath $movie.FileName) `
      -Description "PS5 Scaleform movie $($movie.FileName)"
    $expectedHash = Read-ExpectedSha256 `
      -Path (Join-Path $repositoryRoot $movie.ExpectedHashPath)
    $actualHash = (Get-FileHash -LiteralPath $moviePath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualHash -cne $expectedHash) {
      throw "PS5 Scaleform movie $($movie.FileName) hash mismatch. Expected $expectedHash; found $actualHash."
    }
  }
}

Write-Host -ForegroundColor Green "PS5 Minimalist Scaleform event lifecycle validation passed."
