# hudmenu

Normal-size Starfield player HUD movie. The build manifest injects the shared
Venworks-only component ABC seed, imports the repository-authored CUI runtime,
and adds the `HUDMenu` bootstrap to a clean vanilla `hudmenu.gfx`.

The vanilla movie uses a 1920-by-1080 stage and contains 17,183 exported XML
tags with character IDs through 353 at the currently validated game release.
The generated movie is distributed from `Staging-CUI/Interface/hudmenu.gfx`.
At runtime it loads `Interface/VenworksCUI/layout.xml`. A valid document renders
the Goal 3 fixed component gallery without a success message; a load or schema
failure displays the upper diagnostics panel.
