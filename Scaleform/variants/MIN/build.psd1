@{
  MovieProfile = 'minimalist-live'
  MovieManifestPaths = @(
    'Scaleform/variants/MIN/movies/hudmenu.build.xml'
    'Scaleform/variants/MIN/movies/hudmenu_lrg.build.xml'
  )
  Ps5CwsMovies = @(
    @{
      InputFileName = 'hudmenu.gfx'
      SourcePath = 'Scaleform/variants/MIN/movies/ps5/hudmenu.swf'
      ExpectedHashPath = 'Scaleform/variants/MIN/movies/ps5/hudmenu.expected.sha256'
    }
    @{
      InputFileName = 'hudmenu_lrg.gfx'
      SourcePath = 'Scaleform/variants/MIN/movies/ps5/hudmenu_lrg.swf'
      ExpectedHashPath = 'Scaleform/variants/MIN/movies/ps5/hudmenu_lrg.expected.sha256'
    }
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
