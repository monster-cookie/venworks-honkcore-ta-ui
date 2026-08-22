# Title

Venworks Customizable HUD - Venworks Theme

# Tagline

A from-scratch, XML-customizable Starfield HUD with the Venworks palette, tactical data, a contact radar, and five included color palettes.

# Description Markdown

# Overview

Venworks Customizable HUD overhauls Starfield's interface with a new HUD written from the ground up in Scaleform and ActionScript 3. This Creation starts with the blue Venworks palette and crest. Every gauge, contact, status bar, and information panel has a defined gameplay or interface purpose; this is not a static mockup placed over the game.

**Beta platforms:** This beta targets PC and every console platform supported by Starfield Creations. Console testing and feedback are especially welcome.

> **New HUD and HONKCORE compatibility**
>
> This is a new custom HUD written from the ground up in Scaleform and ActionScript. It is not compatible with HONKCORE and has an expanded feature set.

# Features

- A configurable helmet frame with compass heading, threat state, active status effects, and Bethesda's current vehicle-exit control glyph.
- Player information for level, experience, health, oxygen, CO2, boost, carry mass, credits, digipicks, universal time, and a deterministic player serial.
- A passive equipment rail for all 12 favorite slots plus live weapon, ammunition, explosive, and power information.
- Planet and environment panels for location, local time, oxygen, temperature, gravity, suit protection, and active thermal, airborne, corrosive, and radiation categories.
- Environmental exposure bars that combine active Bethesda hazard categories, suit-protection depletion, and sustained player-O2 drain into modeled relative indicators rather than unsupported real-world measurements.
- A persistent tracked-objective panel.
- Strict, atomic configuration loading. Invalid or unsafe XML, palette, or SVG configuration prevents a partial custom HUD and displays a categorized diagnostic.

# Contact radar and scanner

The full 360-degree radar displays companions, parked ships, parked or recently exited vehicles, and acquired hostile contacts up to 200 provider units away. Bethesda controls when a hostile is initially detected and delivered to the HUD. Once acquired, it remains tracked until it leaves the radar range. The radar is not a life-form detector, and the provider range is not claimed to be meters.

The separate scanner display covers a 90-degree forward field, validates contact data, shows the nearest five contacts, and assigns deterministic display-only codenames for enemies, companions, ships, vehicles, positions, and other points of interest. It does not invent random contacts.

# Themes and customization

This Creation starts with `venworks.xml`, but every variant includes all five stock palettes.

- `venworks.xml`
- `trackers-alliance.xml`
- `freestar-collective.xml`
- `crimson-fleet.xml`
- `starfield.xml`

Versioned XML controls layout, visibility, colors, typography, meters, icons, reusable fragments, and selected Bethesda HUD sections. The GitHub documentation covers common changes and the complete layout and palette contracts. A .NET WYSIWYG theme editor is a long-term roadmap item and is not included in this beta.

# Installation

Install this Creation through Starfield Creations and enable only one Venworks Customizable HUD theme. All four theme Creations replace the same HUD movies and configuration paths, so enabling more than one creates file conflicts.

**Compatibility:** This HUD has no HONKCORE dependency. Do not install it with HONKCORE or another mod that replaces `hudmenu.gfx` or `hudmenu_lrg.gfx` unless a purpose-built compatibility patch explicitly combines them.

## Change the active palette on PC

Console players should install the Creation whose title matches the starting palette they want. PC players can switch among all five packaged palettes:

1. Fully exit Starfield.
2. Back up the active `Interface\VenworksCUI` directory.
3. Open `Interface\VenworksCUI\layout.xml` in a plain-text or XML editor.
4. Find the root `<venworksCUI>` element and change only its `palette` attribute, for example `palette="trackers-alliance.xml"`.
5. Use one filename from the packaged list above. It must refer directly to a file under `Interface\VenworksCUI\palettes`; subdirectories and URLs are rejected.
6. Save the file and fully restart Starfield. Live palette switching is not supported.

Mod-manager updates and Creation reinstalls can overwrite PC XML changes. Keep a backup or a small personal override that wins the file conflict.

# Current beta boundaries

- Neutral creatures and unaware potential hostiles are not guaranteed to appear on the acquired-contact radar.
- Large-HUD, ultrawide, radar-transition, and console feedback remain valuable during beta testing.

# Documentation

- Source and overview: <https://github.com/monster-cookie/venworks-honkcore-ta-ui>
- User configuration guide: <https://github.com/monster-cookie/venworks-honkcore-ta-ui/blob/master/docs/USER_CONFIGURATION.md>
- Layout reference: <https://github.com/monster-cookie/venworks-honkcore-ta-ui/blob/master/docs/LAYOUT_CONFIGURATION_REFERENCE.md>
- Palette reference: <https://github.com/monster-cookie/venworks-honkcore-ta-ui/blob/master/docs/PALETTE_CONFIGURATION_REFERENCE.md>

> **Venworks Discord Community**
>
> I've reopened the Venworks Discord community as a central place for my mods, modding research, support, beta feedback, and bug reports:
> <https://discord.gg/DTbmrJDMxZ>
>
> I'll continue releasing my mods through Bethesda Game Studios Creations and on Nexus, but recent site updates have made Nexus notifications and the Bugs and Posts sections less reliable.
