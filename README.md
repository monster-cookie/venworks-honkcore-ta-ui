# Venworks Customizable HUD

Venworks Customizable HUD is my own customizable Starfield HUD, written from
the ground up in Scaleform and ActionScript 3. It does not depend on HONKCORE
and does not reuse HONKCORE code, bytecode, or configuration formats.

The HUD is driven by versioned XML files that control layout, visibility,
colors, typography, meters, icons, and reusable component fragments. The
runtime validates that configuration before displaying it and reports an
on-screen diagnostic instead of partially applying an invalid layout.

## Current release

The current release replaces the on-foot player HUD in both Starfield HUD
movies while deliberately leaving engine-sensitive Bethesda surfaces under
Bethesda's ownership.

Current custom surfaces include:

- a helmet frame with compass, threat state, and active status effects;
- a persistent tracked-objective panel and bounded contact radar;
- player status for level, experience, health, oxygen, CO2, boost, carry mass,
  credits, digipicks, universal time, and a deterministic player serial;
- environmental status for location, local time, oxygen, temperature, gravity,
  suit protection, and exposure categories;
- a passive equipment rail for all 12 favorite slots plus live weapon,
  ammunition, explosive, and power information;
- a scanner-only heading, pulse grid, and bounded forward-contact display;
- a faction crest selected by the active palette; and
- a localized vehicle-exit label with Bethesda's current keyboard or
  controller glyph.

Bethesda continues to own enemy health and legendary state, stealth and
detection presentation, hit and kill indicators, weapon reticles, crosshairs,
and their associated lifecycle behavior. The custom HUD may read approved
state from those systems for conditions, but it does not replace them.

## Release themes

Four separately distributed variants select different default palettes. Every
variant includes all five packaged palettes, so the active palette can be
changed without reinstalling the HUD.

| Public release name | Default palette |
|---|---|
| Venworks Customizable HUD - Venworks Theme | `venworks.xml` |
| Venworks Customizable HUD - Trackers Alliance Theme | `trackers-alliance.xml` |
| Venworks Customizable HUD - Freestar Alliance Theme | `freestar-collective.xml` |
| Venworks Customizable HUD - Crimson Fleet Theme | `crimson-fleet.xml` |
| Additional included neutral option | `starfield.xml` |

Enable only one release variant at a time. The variants install the same HUD
movie and configuration paths, so whichever package wins file conflicts also
determines the starting configuration.

The public Freestar Alliance name intentionally maps to the existing
`freestar-collective.xml` configuration filename for compatibility.

## Installation

Install one theme variant with a Starfield-capable mod manager and let it win
conflicts with other packages that replace `hudmenu.gfx` or
`hudmenu_lrg.gfx`. Advanced manual installation is possible by copying the
package's `Interface` directory into Starfield's `Data` directory, but a mod
manager makes conflict handling and recovery safer.

This release has no HONKCORE dependency. It will conflict with other HUD mods
that overwrite either of the same GFX movies unless a purpose-built compatible
patch combines their changes.

## Configuration

Start with the [user configuration guide](docs/USER_CONFIGURATION.md) for
backups, file locations, palette switching, moving or hiding sections, safe
areas, vanilla HUD visibility, basic color changes, reload behavior, and
troubleshooting.

Configuration authors can use the complete references:

- [Layout configuration reference](docs/LAYOUT_CONFIGURATION_REFERENCE.md)
  covers the root document, fragments, conditions, live values, templates,
  components, composites, limits, and assets.
- [Palette configuration reference](docs/PALETTE_CONFIGURATION_REFERENCE.md)
  covers packaged themes, required semantic roles, custom palettes, and
  `@palette.*` references.

Configuration files are loaded when the HUD movie starts. There is no live
reload command; fully exit and restart Starfield after changing XML or SVG
files.

## Current limitations and validation status

- The configurable release currently covers the on-foot player HUD. Ship UI
  remains outside the current release.
- Configuration is strict and atomic. A missing, malformed, unsafe, or invalid
  layout, fragment, palette, or SVG prevents the custom layer from loading and
  displays a categorized diagnostic.
- Direct PNG, JPEG, and DDS assets are unsupported by the Starfield Scaleform
  runtime. Custom loose artwork must use the supported local SVG subset.
- Palette changes require a new HUD load; live switching is unsupported.
- The normal HUD has broader current in-game evidence than the large HUD and
  ultrawide presentation. Final large-HUD, ultrawide, and contact-radar
  startup/transition acceptance remains in progress; build and staging success
  alone is not treated as gameplay acceptance.

## Technical documentation

- The [component catalog](docs/COMPONENT_CATALOG.md) records implemented
  runtime components, provider ownership, evidence boundaries, and known
  behavior.
- The [build system](docs/BUILDSYSTEM.md) documents the Scaleform build and
  staging pipeline.
- The [Scaleform source guide](Scaleform/README.md) covers local build
  requirements and authored source structure.
- [Visual references](docs/reference/) preserve clean-room behavioral and
  visual evidence.
- [Release history](CHANGELOG.md) preserves the earlier release changelog.

Current product intent, delivery state, and acceptance criteria are maintained
in the [Venworks Codecks workspace](https://venworks.codecks.io/). Repository
documentation owns the technical configuration contract and verified runtime
evidence.

Repository-specific automation requirements are documented in
[`AGENT-REPO-CONTEXT.md`](AGENT-REPO-CONTEXT.md).

## License

See [LICENSE](LICENSE).
