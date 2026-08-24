# Venworks - Customizable HUD and Themes

## UNRELEASED

- Added a local-time countdown to the next 06:00 sunrise or 18:00 sunset in the Planet Data panel.
- Added the PS5-only Minimalist release variant with the faction panel removed, the radar restored to the upper-left slot, literal Starfield colors, and no external SVG, palette, or DDS payload.
- Hardened the independent HUD provider registrations with transactional startup, callback containment, diagnostics, and idempotent teardown while preserving all intentional cross-context registrations.
- Added independent data-driven build profiles for all five variants, a single shared GFX compile, committed-artifact regeneration, and a 21-package release matrix with Minimalist published only as a Bethesda PS5 package.
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
