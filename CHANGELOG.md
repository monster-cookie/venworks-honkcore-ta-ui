# Venworks - Customizable HUD and Themes

- https://www.nexusmods.com/starfield/mods/17104
- https://creations.bethesda.net/en/starfield/details/e8a7bdfa-7d88-4cf5-bba4-a5c4cad0d97f/Venworks_Customizable_HUD___Minimalist_Theme
- https://creations.bethesda.net/en/starfield/details/1d693691-1b23-48fe-9cc9-06be4fe63ad8/Venworks_Customizable_HUD___Venworks_Theme
- https://creations.bethesda.net/en/starfield/details/80994b40-c426-4f3c-b157-7beaee0aa473/Venworks_Customizable_HUD___Trackers_Alliance_Them
- https://creations.bethesda.net/en/starfield/details/03b616a3-1902-4b83-a109-fc176f658a69/Venworks_Customizable_HUD___Crimson_Fleet_Theme
- https://creations.bethesda.net/en/starfield/details/9b635bf7-8c6b-4530-bdbd-0912903b336b/Venworks_Customizable_HUD___Freestar_Collective_Th

## Version 2.0.10 (September 29, 2026)

- All: Deploy the CWS normal and large HUD movies byte-for-byte under both their `.swf` and `.gfx` names for the next PS5 compatibility probe while retaining the native GFX/CWS HUD-message split.
- All: Include active environmental afflictions in the status-effect bar alongside personal and sustenance effects, with duplicate icons collapsed.
- All: Render negative food and drink status tiles with the configured debuff color while preserving sustenance classification and ordering.

## Version 2.0.9 (September 28, 2026)

- All: Set movie resolution to 1920x1080, 30-fps, one-frame metadata.
- All: Moved movie registration/teardown to the `Event.INIT` and `Event.COMPLETE` handlers.

## Version 2.0.8 (September 27, 2026)

- All: Moved the complete CUI runtime into a standalone `venworkscui.swf`.
- All: Added better error handling and fault tolerance for the new movie setup. 
- All: Apply Starfield's embedded bold font to the auxiliary marker and bootstrap load-error messages so loader failures remain readable in game.

## Version 2.0.7 (September 27, 2026)

- Minimalist: Restored the live data registrations.
- All: All variants now compile independent native GFX and ZLIB-compressed CWS versions of all four HUD movies from their matching clean Bethesda source files. 
- All: Every Windows, Xbox, and PlayStation Main archive ships both `.gfx` and `.swf` paths, matching Bethesda's dual-movie packaging.

## Version 2.0.6 (September 26, 2026)

- Minimalist: Restored loose XML configuration as it produced no change in the PS5 startup crash.
- Minimalist: Replaced both live data contexts with static implementations and removed all game-provider registrations and provider-driven runtime events for the next PS5 isolation test.

BREAKING: This version disables all live data and is really only for testing the PS5 crash. 

## Version 2.0.5 (September 26, 2026)

- Minimalist: Remove XML support and baked in the components into the movies for PS5 startup crash isolation. Hopefully this doesn't fix anything cause it kills the customization part lol. 

## Version 2.0.4 (August 25, 2026)

- Minimalist: Removed all SVG support from the movies and actionscript.
- Minimalist: Removed helmet cutout paths and complete equipment rail.
- Minimalist: Replaced HUD with fitted holographic readouts using dark, pale-blue translucent native rectangle and ellipse backings behind the active content, while preserving its corner brackets, dividers, meters, radar, compass, markers, and sunrise/sunset countdown.

## Version 2.0.3 (August 24, 2026)

- Added a local-time countdown to the next 06:00 sunrise or 18:00 sunset in the Planet Data panel.
- Added the work-in-progress Minimalist release variant for PS5 testing with the faction panel removed, the radar restored to the upper-left slot, literal Starfield colors, and no external SVG, palette, or DDS payload.
- Hardened the independent HUD provider registrations with transactional startup, callback containment, diagnostics, and idempotent teardown while preserving all intentional cross-context registrations.
- Added independent data-driven build profiles for all five variants, a single shared GFX compile, committed-artifact regeneration, and a 25-package release matrix covering Nexus PC and Bethesda PC, Xbox, and PS5 packages for every variant.
- Fixed scanner startup restoring the vanilla tracked quest while keeping the vanilla Watch display hidden.
- Documented that mods replacing `hudmessagesmenu.gfx` or `hudmessagesmenu_lrg.gfx` are incompatible unless a purpose-built patch combines their changes; load order alone is not a compatibility solution.

## Version 2.0.2 (August 22, 2026)

- No changes just wiring up Nexus API from GitHub Actions.

## Version 2.0.0 (August 22, 2026)

**BREAKING CHANGE — READ BEFORE UPGRADING:** This release completely replaces the previous HONKCORE-based themes. It no longer depends on or works with HONKCORE, and the old HONKCORE theme and configuration files are no longer included. Do not upgrade unless you are willing to stop using HONKCORE for this HUD. Remove the previous theme and install either a legacy HONKCORE version or the new Venworks Customizable HUD—never both.

- Rebuilt the player HUD from the ground up as the new Venworks Customizable HUD.
- Added a helmet display with compass heading, threat warnings, active status effects, and the environment warnings.
- Added expanded player, equipment, and environmental information, including health, oxygen, boost, carry weight, favorites, weapons, ammunition, explosives, powers, suit protection, gravity, temperature, and environmental hazards.
- Added a persistent tracked-objective panel, a 360-degree acquired-contact radar, and a scanner-only forward-contact display with consistent contact codenames.
- Added four separately packaged themes: Venworks, Trackers Alliance, Freestar Collective, and Crimson Fleet—with five included color palettes.
- Added PC customization for HUD placement, visibility, colors, typography, meters, icons, and individual HUD sections through XML configuration.
- Added clear on-screen diagnostics when a custom configuration is missing or invalid instead of partially loading a broken HUD.
- Added Nexus PC packages for normal or fully loose installation and Bethesda Creations packages for PC, Xbox, and PlayStation 5. Enable only one theme package at a time.
- Preserved Bethesda's combat-sensitive HUD elements, including reticles, crosshairs, enemy health, stealth indicators, and hit or kill feedback to avoid engine crashes.
- Other mods that replace `hudmenu.gfx` or `hudmenu_lrg.gfx` are incompatible unless a purpose-built patch combines their changes.

## Version 1.0.8

- ALL: No changes just setting up build pipeline for the new Venworks theme.

## Version 1.0.7

- Venworks: New blue themed UI for all my Venworks creations

## Version 1.0.6

- ALL: Removing SPECTR it causes issues with ladders and workbenches. While I loved it for the immersion when in third person a lot it wears on you. I can probably be talked into making a second version of each theme with it but for now it goes.

## Version 1.0.5

- ALL: Support for Hud Info Widget 1.5.3

## Version 1.0.4

- ALL: Fixed the default cursor problem I hope. I hate random issues. :)
- Crimson Fleet: Initial Release

## Version 1.0.3

- Freestar Collective: Added my own color theme
- Trackers Alliance: Added my own color theme
- More stupid deadlink text overlay problems, removed it for now.
- I think I fixed the weird text artifact on the ammo label when aiming.

## Version 1.0.2

- Added a Freestar Collective Version (Available as a separate file and GitHub Branch)

## Version 1.0.1

- Hid the heading, it made the UI too busy
- Moved the quick bar to Upper Right and added button names.

## Version 1.0.0

- Initial Release
