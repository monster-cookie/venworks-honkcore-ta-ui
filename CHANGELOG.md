# Venworks - Customizable HUD and Themes

- https://www.nexusmods.com/starfield/mods/17104
- https://creations.bethesda.net/en/starfield/details/e8a7bdfa-7d88-4cf5-bba4-a5c4cad0d97f/Venworks_Customizable_HUD___Minimalist_Theme
- https://creations.bethesda.net/en/starfield/details/1d693691-1b23-48fe-9cc9-06be4fe63ad8/Venworks_Customizable_HUD___Venworks_Theme
- https://creations.bethesda.net/en/starfield/details/80994b40-c426-4f3c-b157-7beaee0aa473/Venworks_Customizable_HUD___Trackers_Alliance_Them
- https://creations.bethesda.net/en/starfield/details/03b616a3-1902-4b83-a109-fc176f658a69/Venworks_Customizable_HUD___Crimson_Fleet_Theme
- https://creations.bethesda.net/en/starfield/details/9b635bf7-8c6b-4530-bdbd-0912903b336b/Venworks_Customizable_HUD___Freestar_Collective_Th

## Version 2.1.0 (Unreleased)

- Rebuilt all five VWHUD themes to run as Venworks Canvas consumers instead of replacing the vanilla HUD directly.
- Migrated theme presentation to HTML, CSS, and standard SVG, making layouts and artwork easier for web developers and mod authors to understand.
- Replaced the old status bar with a compact themed effects display featuring buff and debuff counts, eight effects per page, and automatic page rotation.
- Improved status-effect recovery across startup, save loading, menu recreation, and temporarily unavailable HUD states.
- Removed competing vanilla HUD movie replacements from VWHUD packages and isolated each theme’s assets within its own Canvas consumer namespace.
- Added stable panel classes and a last-loaded `vwhud-overrides.css` file for PC color, placement, size, typography, and visibility overrides.
- Changed build and release packaging to keep installed and committed staging archive-only while reconstructing the Nexus Fully Loose package from the verified Windows Main BA2.
- Added a Canvas contract preflight and recovery guidance for diagnosing a deployed Canvas/VWHUD contract mismatch.
- Write every theme document with the lowercase `<!doctype html>` preamble Canvas requires, so the theme can parse and hide the Canvas watch.
- Use the lowercase `currentcolor` paint keyword in theme marks and icons. Canvas rejects `currentColor`.
- Now requires Venworks Canvas 1.0.4 and Venworks Core Utilities 2.1.8.
- Give the theme document a relative body so absolute panels have the containing block Canvas requires. A static body fails the theme with `absolute-containing-block-required`.
- Publish favorite slots as `favorite.slot01` through `favorite.slot12`. The previous rewrite left the literal key `favorite.slot$1.hotkey`, which Canvas rejects.
- Name the publish stage on a ready-callback failure. The chronomark shows `PUBLISH model`, `flags`, `effects`, `present`, or `setdata` with the Canvas access path.
- Remove the full-screen helmet visor shapes. Themed panels now use the minimalist holographic plate: a dark rectangle, a theme-accent halo, and corner brackets.
- Read compass and frequent environment fields only when the game object actually has them, so a missing property cannot abort the HUD update.
- Ask Canvas to hide the fake watch and the lower-right health and ammo cluster.
- Draw the top compass strip and the contact radar as Scaleform objects in the VWHUD movie again. Their ticks, labels, POI markers, and contacts are no longer HTML elements. Each POI marker is the game compass widget, placed on the strip and moved as the player turns. Copying that widget into a bitmap raises TypeError 2077 and aborts the update. Its added-to-stage hook is stopped so it cannot subscribe to control data.
- Rebuild the HTML panels only when a displayed value changes. Compass and environment packets still move the strip and radar on every update, without rebuilding the document for an unchanged clock or hazard set.
- Read player, inventory, favorite, and environment-effect fields only when the game object has them, matching the component gallery. A missing field was aborting the update, so health, level, credits, suit protection, and hazard rows stayed on their initial text.
- Darken the panel plates so the text can be read over bright ground.
- Read game data fields by name when the presence check misses them, so health, level, credits, suit protection, and hazard rows reach the panels. Copy compass marker fields the same way, and hide a marker whose frame is not the requested POI icon.
- Show the game POI icon on the top compass strip. The strip calls the compass widget's location and frame methods the same way the pre-Canvas tape did, instead of leaving the generic dot in place.
- Load each location icon after its compass frame is selected, and keep requesting it until the map-icon library finishes. The sealed-method test was skipping that call, so location markers stayed on the empty frame.
- Load the game map-icon library from the Interface folder when the compass widget's own request does not finish, and draw that icon on the strip. The widget request looks beside the consumer movie, so cave, ship, and structure markers stayed on the empty frame.
- Replace the generated Venworks crest with a trace of the canonical Venworks mark and wordmark. Each path stays under Canvas's 4096-character attribute limit so the logo cannot unload the HUD.

## Version 2.0.19 (September 1, 2026)

- All: Moved the 11 supplied reusable HUD component definitions into `venworkscui.swf`, replaced their shipped XML includes with bounded `<swfComponent>` references, and removed the duplicate component XML payloads.
- All: Split the scanner overlay into independently placeable hash and data panel definitions while preserving their combined presentation in the shipped layouts.
- Minimalist: Uses the same 11-component SWF registry as the four themed variants and instantiates the nine applicable definitions with literal Starfield colors.

NOTE: This will be the last release until 2.1.0 release (in a week or 2), this new release will be based on Venworks Canvas which is a HTML and CSS Engine written in ActionScript and will have a Papyrus to Scaleform data layer. Also, I've had to disable PS5 there is no way to recover PS5 functionality without the Canvas changes. 

## Version 2.0.18 (August 31, 2026)

- PS5Debug: Load `VenworksCUI/layout.xml` only as bounded text and parse its exact `html/head/title/body/section/h1/p` structure with a custom ActionScript parser that does not invoke Scaleform XML, E4X, or the disabled HTML engine.
- PS5Debug: Render the accepted heading and paragraph through a native Scaleform text field without CSS, JavaScript, attributes, namespaces, entities, mixed content, or browser behavior.

## Version 2.0.17 (August 31, 2026)

- PS5Debug: Keep PlayerData and XML loader results on separate persistent rows and report whether the isolated XML load call returns.
- PS5Debug: Parse one isolated XML value with the same root-name and direct-child E4X operations used by the player-facing runtime, and display it alongside the verified player name.

## Version 2.0.15 (August 30, 2026)

- PS5Debug: Add a `PlayerData` subscription test that displays the sanitized `sName` value in the debug pane.

## Version 2.0.14 (August 30, 2026)

- PS5Debug: Loading an isolated one-class `venworkscui.swf` diagnostic bridge without XML, providers, or the full CUI runtime.

## Version 2.0.13 (August 29, 2026)

- PS5Debug: Add an isolated diagnostic variant for end-user PS5 startup testing.
- PS5Debug: Add a top-center lifecycle/error pane patched directly into the existing one-ABC HUDMenu bytecode.

## Version 2.0.11 (August 29, 2026)

- All: Restore independently compiled native GFX and CWS normal/large HUD pairs after the byte-identical alias experiment produced no change in the reported PS5 crash.
- All: Match Bethesda's Archive2 storage by disabling compression for General Main archives and using LZ4 for DDS texture archives.

## Version 2.0.10 (August 29, 2026)

- All: Deploy the CWS normal and large HUD movies byte-for-byte under both their `.swf` and `.gfx` names for the next PS5 compatibility probe while retaining the native GFX/CWS HUD-message split.
- All: Include active environmental afflictions in the status-effect bar alongside personal and sustenance effects, with duplicate icons collapsed.
- All: Render negative food and drink status tiles with the configured debuff color while preserving sustenance classification and ordering.

## Version 2.0.9 (August 28, 2026)

- All: Set movie resolution to 1920x1080, 30-fps, one-frame metadata.
- All: Moved movie registration/teardown to the `Event.INIT` and `Event.COMPLETE` handlers.

## Version 2.0.8 (August 27, 2026)

- All: Moved the complete CUI runtime into a standalone `venworkscui.swf`.
- All: Added better error handling and fault tolerance for the new movie setup. 
- All: Apply Starfield's embedded bold font to the auxiliary marker and bootstrap load-error messages so loader failures remain readable in game.

## Version 2.0.7 (August 27, 2026)

- Minimalist: Restored the live data registrations.
- All: All variants now compile independent native GFX and ZLIB-compressed CWS versions of all four HUD movies from their matching clean Bethesda source files. 
- All: Every Windows, Xbox, and PlayStation Main archive ships both `.gfx` and `.swf` paths, matching Bethesda's dual-movie packaging.

## Version 2.0.6 (August 26, 2026)

- Minimalist: Restored loose XML configuration as it produced no change in the PS5 startup crash.
- Minimalist: Replaced both live data contexts with static implementations and removed all game-provider registrations and provider-driven runtime events for the next PS5 isolation test.

BREAKING: This version disables all live data and is really only for testing the PS5 crash. 

## Version 2.0.5 (August 26, 2026)

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
