@{
  Name = 'minimalist-static'
  ExcludedActionScriptPaths = @()
  ActionScriptReplacementPaths = @{
    'venworks/cui/CUIConditionContext.as' = '../patches/static/CUIConditionContext.as'
    'venworks/cui/CUIPlayerHudDataContext.as' = '../patches/static/CUIPlayerHudDataContext.as'
  }
  ActionScriptPatchPath = '../patches/minimalist-static.xml'
  ForbiddenBytecodeTokens = @(
    'BSUIDataManager'
    'FromClientDataEvent'
    'CustomEvent'
    'subscribeProvider'
    'cuiConditionChange'
    'cuiConditionProviderError'
    'cuiValueChange'
    'cuiCompassChange'
    'cuiTacticalAwarenessChange'
    'cuiValueProviderError'
    'EXPOSURE_UPDATE_MS'
    'LocalEnvironmentData'
    'LocalEnvData_Frequent'
    'PlayerData'
    'PlayerFrequentData'
    'PlayerInventoryData'
    'WeaponData'
    'HudJetpackData'
    'HUDStarbornPowersData'
    'FavoritesData'
    'ControlMapData'
    'EnvironmentEffectsData'
    'PersonalEffectsData'
    'StarmapSystemBodyInfoProvider'
    'HudCompassData'
    'HudCrosshairData'
    'HUDStealthData'
    'HUDVehicleData'
    'HUDOpacityData'
  )
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
  ValueProviders = @()
  ConditionProviders = @()
  CrossContextProviderCount = 0
}
