# hudmenu

Normal-size Starfield player HUD movie. The GFX and SWF build manifests apply the same bounded `HUDMenu` auxiliary-loader bootstrap to their matching clean Bethesda inputs while retaining exactly one Bethesda ABC in each compiled intermediate.

The vanilla movie uses a 1920-by-1080 stage and contains 17,183 exported XML tags with character IDs through 353 at the currently validated game release. The current PS5 compatibility probe validates both compiled host containers but deploys the CWS `hudmenu.swf` bytes under both `Interface/hudmenu.swf` and `Interface/hudmenu.gfx`. At runtime the bootstrap loads `Interface/venworkscui.swf`, whose runtime then loads `Interface/VenworksCUI/layout.xml`. A valid document renders the configured CUI without a success message; a loader or configuration failure displays the upper diagnostics panel.
