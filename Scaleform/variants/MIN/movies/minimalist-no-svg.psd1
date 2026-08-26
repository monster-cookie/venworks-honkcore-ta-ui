@{
  Name = 'minimalist-no-svg'
  ExcludedActionScriptPaths = @(
    'venworks/cui/CUIAssetManager.as'
    'venworks/cui/CUICompositeResolver.as'
    'venworks/cui/CUIIconLibrary.as'
    'venworks/cui/CUILayoutImportLoader.as'
    'venworks/cui/CUIPaletteLoader.as'
    'venworks/cui/CUISvgParser.as'
    'venworks/cui/CUISvgPathParser.as'
    'venworks/cui/components/CUIIcon.as'
    'venworks/cui/components/CUIMask.as'
    'venworks/cui/components/CUIPanel.as'
    'venworks/cui/components/CUIProviderSymbol.as'
    'venworks/cui/components/CUISvg.as'
    'venworks/cui/components/CUISvgPath.as'
  )
  ActionScriptPatchPath = '../patches/minimalist-no-svg.xml'
  ForbiddenBytecodeTokens = @(
    'CUIAssetManager'
    'CUICompositeResolver'
    'CUIIconLibrary'
    'CUILayoutImportLoader'
    'CUIPaletteLoader'
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
