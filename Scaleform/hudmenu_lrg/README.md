# hudmenu_lrg

Large-size Starfield player HUD movie. The build manifest applies the shared,
always-visible bottom-center CUI test probe and the provisional external XML
loader to a clean vanilla `hudmenu_lrg.gfx`.

The vanilla movie uses a 1920-by-1080 stage and contains 17,175 exported XML
tags with character IDs through 353 at the currently validated game release.
The generated movie is distributed from
`Staging-CUI/Interface/hudmenu_lrg.gfx`.
At runtime it attempts to load `Interface/VenworksCUI/probe.xml`; this path and
schema are Goal 2 test contracts, not the final layout format.
