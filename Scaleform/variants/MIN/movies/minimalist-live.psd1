@{
  Name = 'minimalist-live'
  ExcludedActionScriptPaths = @()
  ActionScriptReplacementPaths = @{}
  ActionScriptPatchPath = '../patches/minimalist-live.xml'
  ForbiddenBytecodeTokens = @()
  RequiredBytecodeTokens = @(
    'CUILayoutImportLoader'
    'CUIPaletteLoader'
    'CUIAssetManager'
    'CUICompositeResolver'
    'CUIIconLibrary'
    'CUISvgParser'
    'CUISvgPathParser'
    'CUIIcon'
    'CUIMask'
    'CUIPanel'
    'CUIProviderSymbol'
    'CUISvg'
    'CUISvgPath'
  )
  ValueProviders = @(
    'LocalEnvironmentData'
    'LocalEnvData_Frequent'
    'PlayerData'
    'PlayerFrequentData'
    'PlayerInventoryData'
    'HudJetpackData'
    'EnvironmentEffectsData'
    'PersonalEffectsData'
    'StarmapSystemBodyInfoProvider'
    'HudCompassData'
  )
  ConditionProviders = @(
    'HudCrosshairData'
    'HUDStealthData'
    'HudCompassData'
    'HUDVehicleData'
    'HUDOpacityData'
    'HudJetpackData'
    'PlayerInventoryData'
  )
  CrossContextProviderCount = 3
}
