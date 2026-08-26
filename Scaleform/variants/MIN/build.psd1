@{
  MovieProfile = 'minimalist-no-svg'
  ConfigurationMode = 'Embedded'
  MovieManifestPaths = @(
    'Scaleform/variants/MIN/movies/hudmenu.build.xml'
    'Scaleform/variants/MIN/movies/hudmenu_lrg.build.xml'
  )
  LayoutSource = 'Scaleform/variants/MIN/layout.xml'
  ComponentSourceDirectory = 'Scaleform/variants/MIN/components'
  ComponentFileNames = @(
    'contact-radar.xml'
    'environmental-hazard-scanner.xml'
    'helmet-awareness.xml'
    'player-status-scanner.xml'
    'quest-tracker.xml'
    'scanner-overlay.xml'
  )
  AssetSourceDirectory = ''
  AssetFileNames = @()
  PaletteMode = 'Literal'
  PaletteSourceDirectory = 'Scaleform/shared/palettes'
  PaletteFileNames = @()
  PluginSourcePath = 'Staging-TA/Venworks-CustomizableHUD-TrackersAlliance.esm'
}
