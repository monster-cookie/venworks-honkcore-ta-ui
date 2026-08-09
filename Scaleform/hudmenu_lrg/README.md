# hudmenu_lrg

Large-size Starfield player HUD movie. The build manifest injects the shared
Venworks-only component ABC seed, imports the repository-authored CUI runtime,
and adds the `HUDMenu` bootstrap to a clean vanilla `hudmenu_lrg.gfx`.

The vanilla movie uses a 1920-by-1080 stage and contains 17,175 exported XML
tags with character IDs through 353 at the currently validated game release.
The generated movie is distributed from each themed staging variant's
`Interface/hudmenu_lrg.gfx`. `Staging-VWKS` is the active CUI layout project
while the other themed layouts are migrated. At runtime it loads
`Interface/VenworksCUI/layout.xml`. A valid document renders the configured CUI
without a success message; a load or schema failure displays the upper
diagnostics panel.
