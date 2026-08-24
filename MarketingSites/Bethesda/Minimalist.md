# Overview

Venworks Customizable HUD - Minimalist is an experimental PS5-focused variant of the Venworks HUD. It removes the faction-logo panel, returns the contact radar to that upper-left position, and keeps the rest of the tactical HUD available while the broader minimalist design is developed.

**Beta platform:** This initial package targets PS5. It has been cold-started, save-loaded, and exercised in normal HUD and scanner modes on PS5, but continued console testing and feedback are welcome.

# Current features

- A configurable helmet frame with compass heading, threat state, active status effects, and Bethesda's current vehicle-exit control glyph.
- Player information for level, experience, health, oxygen, CO2, boost, carry mass, credits, digipicks, universal time, and a deterministic player serial.
- A passive equipment rail for all 12 favorite slots plus live weapon, ammunition, explosive, and power information.
- Planet and environment panels for location, local time, the next sunrise or sunset, oxygen, temperature, gravity, suit protection, and active thermal, airborne, corrosive, and radiation categories.
- A persistent tracked-objective panel.
- A full 360-degree acquired-contact radar in the former faction-panel position.
- Guarded HUD startup, independent event registrations, contained callbacks, and categorized diagnostics intended to expose configuration or provider failures without leaving a partially initialized custom HUD.

# PS5 Minimalist configuration

This package intentionally contains no external SVG, palette, or DDS files. Its Starfield colors are written directly into the XML configuration, and it does not include the faction display or a texture archive.

This isolation narrows the PS5 crash investigation, but it does not prove that any one removed feature or asset format caused earlier crashes. Shared SVG-capable code remains inside the compiled HUD movies even though this configuration has no external SVG content to load.

# Contact radar and scanner

The radar displays companions, parked ships, parked or recently exited vehicles, and acquired hostile contacts up to 200 provider units away. Bethesda controls when a hostile is initially detected and delivered to the HUD. Once acquired, it remains tracked until it leaves the radar range. The radar is not a life-form detector, and the provider range is not claimed to be meters.

The separate scanner display covers a 90-degree forward field, validates contact data, shows the nearest five contacts, and assigns deterministic display-only codenames for enemies, companions, ships, vehicles, positions, and other points of interest. It does not invent random contacts.

# Installation

Install this Creation through Starfield Creations and enable only one Venworks Customizable HUD variant. All five variants replace the same HUD movies and configuration paths, so enabling more than one creates file conflicts.

For manual or mod-manager testing, deploy the package to Starfield's `Data` location. An `Engine` deployment does not place these interface overrides where the game expects them.

**Compatibility warning:** This Creation is incompatible with any mod or Creation that replaces `hudmenu.gfx`, `hudmenu_lrg.gfx`, `hudmessagesmenu.gfx`, or `hudmessagesmenu_lrg.gfx` unless a purpose-built compatibility patch combines their changes. Load order only selects which mod's changes are discarded; it does not make the movies compatible.

# Work-in-progress roadmap

The current Minimalist roadmap is a planning snapshot, not a promise of dates, versions, order, or final inclusion.

- Replace the full equipment rail with a significantly smaller presentation retaining up to three active buttons.
- Remove the remaining helmet cutout panels.
- Migrate the remaining panel-based interface toward holographic displays.

# Current beta boundaries

- The current package is a PS5-focused stability spike, not the finished Minimalist visual redesign.
- Neutral creatures and unaware potential hostiles are not guaranteed to appear on the acquired-contact radar.
- Large-HUD, ultrawide, radar-transition, and additional console feedback remain valuable during beta testing.

# Documentation

- Source and overview: https://github.com/monster-cookie/venworks-honkcore-ta-ui
- User configuration guide: https://github.com/monster-cookie/venworks-honkcore-ta-ui/blob/master/docs/USER_CONFIGURATION.md
- Layout reference: https://github.com/monster-cookie/venworks-honkcore-ta-ui/blob/master/docs/LAYOUT_CONFIGURATION_REFERENCE.md

# Venworks Discord Community

I've reopened the Venworks Discord community as a central place for my mods, modding research, support, beta feedback, and bug reports: https://discord.gg/DTbmrJDMxZ

I'll continue releasing my mods through Bethesda Game Studios Creations and on Nexus, but recent site updates have made Nexus notifications and the Bugs and Posts sections less reliable.
