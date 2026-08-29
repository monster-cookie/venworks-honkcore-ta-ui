# Venworks Customizable HUD

Venworks Customizable HUD is my own customizable Starfield HUD, written from
the ground up in Scaleform and ActionScript 3. It does not depend on HONKCORE
and does not reuse HONKCORE code, bytecode, or configuration formats.

All five HUD variants are driven by versioned XML files that control layout,
visibility, colors, typography, meters, icons, and reusable component fragments.
The runtime validates that configuration before displaying it and reports an
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
- a passive equipment rail in the four themed variants for all 12 favorite
  slots plus live weapon, ammunition, explosive, and power information;
- a scanner-only heading, pulse grid, and bounded forward-contact display;
- a faction crest selected by the active palette in all four themed variants; and
- a localized vehicle-exit label with Bethesda's current keyboard or
  controller glyph.

Bethesda continues to own enemy health and legendary state, stealth and
detection presentation, hit and kill indicators, weapon reticles, crosshairs,
and their associated lifecycle behavior. The custom HUD may read approved
state from those systems for conditions, but it does not replace them.

## Release variants

Five separately distributed variants are available. All five use the same thin normal and large HUD bootstrap movies and the same HUD-message movies. The four themed variants share one standalone CUI runtime movie and include all five packaged palettes, so their active palette can be changed without reinstalling the HUD. Minimalist uses its own standalone CUI runtime movie, literal Starfield colors, fitted holographic readouts with pale-blue translucent native-shape backings, and the same complete XML, palette, SVG, path, panel, icon, and mask runtime. Its live profile retains the ten required value registrations, seven required condition registrations, and three intentional cross-context overlaps while omitting the providers used only by the removed equipment rail.

| Public release name | Default palette |
|---|---|
| Venworks Customizable HUD - Venworks Theme | `venworks.xml` |
| Venworks Customizable HUD - Trackers Alliance Theme | `trackers-alliance.xml` |
| Venworks Customizable HUD - Freestar Collective Theme | `freestar-collective.xml` |
| Venworks Customizable HUD - Crimson Fleet Theme | `crimson-fleet.xml` |
| Venworks Customizable HUD - Minimalist | Literal Starfield colors; no palette file |

The four themed variants also include `starfield.xml` as a neutral palette option. The faction crest and equipment rail are available only in those four variants. Minimalist omits both from its shipped layout and also ships no SVG assets, palette files, helmet cutout paths, or active `svg`, `path`, `mask`, `icon`, `panel`, or `providerSymbol` elements. Those runtime capabilities are not compiled out of its standalone CUI movie.

Each installed variant carries nine Interface movies. The normal and large HUD bootstrap CWS files are deployed byte-for-byte under both their `.swf` and `.gfx` names, matching the working TACOS dual-name structure being tested for PS5 compatibility. The HUD-message `.gfx` files remain native GFX while their `.swf` partners remain independently compiled CWS, and `Interface\venworkscui.swf` contains the complete Venworks runtime in one separately loaded ABC domain. The normal and large HUD movies retain one Bethesda ABC apiece and load the auxiliary movie through a guarded asynchronous bootstrap. The auxiliary uses Bethesda's 1920-by-1080, 30-fps, one-frame stage contract; the bootstrap starts from the HUD constructor, initializes the child runtime at `Event.INIT`, and attaches the loaded child directly to the HUD at `Event.COMPLETE`.

Enable only one release variant at a time. The variants install the same HUD
movie and configuration paths, so whichever package wins file conflicts also
determines the starting configuration.

## Installation

Choose one variant and one PC package shape. The recommended Nexus PC - Normal package installs a root ESM, Windows BA2 archives, and one loose `Interface\VenworksCUI\layout.xml`. Enable the ESM and let the package win HUD conflicts. The official v2.0.10 release publishes both Nexus package shapes for all five variants while PS5 compatibility remains subject to end-user acceptance.

The Nexus PC - Fully Loose Files package installs the complete `Interface`
tree without an ESM or BA2. Use it only when component fragments, or palettes
and SVG assets in a themed variant, must also remain loose. Do not install the
normal and fully loose packages together. A Starfield-capable mod manager is
strongly recommended for either package shape.

Bethesda Creations use separate ESM-and-BA2-only packages for PC, Xbox, and
PS5. Install only the package supplied for the current platform and enable only
one release variant.

When replacing an experimental Creation with an official release, uninstall the experimental entry first and verify that only one Creation owning that ESM identity remains; Bethesda's manager can otherwise leave both entries competing to install, replace, or remove the same plugin and archives.

This release has no HONKCORE dependency. It is incompatible with any mod that
replaces `hudmenu.gfx`, `hudmenu_lrg.gfx`, `hudmessagesmenu.gfx`, or
`hudmessagesmenu_lrg.gfx` unless a purpose-built compatibility patch combines
their changes. Load order only selects which mod's changes are discarded; it
does not make the movies compatible. This release does not ship Monocle menu
overrides.

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

All five variants load their configuration files when the HUD movie starts.
There is no live reload command; fully exit and restart Starfield after changing
XML or SVG files.

The normal Nexus package exposes only `layout.xml` as a loose file. Advanced
component, palette, and SVG customization requires the fully loose package or a
separate loose override containing the additional changed files.

## Current limitations and validation status

- The configurable release currently covers the on-foot player HUD. Ship UI
  remains outside the current release.
- Configuration is strict and atomic. A missing, malformed, unsafe, or invalid
  layout, fragment, palette, or SVG prevents the custom layer from loading and
  displays a categorized diagnostic.
- Direct PNG, JPEG, and DDS assets are unsupported by the Starfield Scaleform
  runtime. All movie profiles support the documented local SVG subset;
  Minimalist's shipped configuration simply does not use it.
- Every platform package contains CWS normal and large HUD movies under both the `.gfx` and `.swf` paths, with each pair byte-identical. HUD-message `.gfx` files remain native GFX and HUD-message `.swf` files remain independently compiled CWS.
- Palette changes require a new HUD load; live switching is unsupported.
- In the four themed variants, active-power highlighting for favorite slots
  currently compares Bethesda's
  localized favorite name with an English name mapped from the live HUD power
  key. It is therefore reliable only in English until HUDMenu exposes a stable
  language-independent favorite-power identifier.
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
- The [Starfield Scaleform workflow](docs/STARFIELD_SCALEFORM_WORKFLOW.md) documents clean extraction, decompilation, modification, independent GFX/CWS recompilation, staging, packaging, and cross-platform validation.
- The [Scaleform source guide](Scaleform/README.md) covers local build
  requirements and authored source structure.
- [Visual references](docs/reference/) preserve clean-room behavioral and
  visual evidence.
- [Release history](CHANGELOG.md) preserves the earlier release changelog.

Current product intent, delivery state, and acceptance criteria are maintained
in Plane project `VWKSHUD`. Repository documentation owns the technical
configuration contract and verified runtime evidence.

Repository-specific automation requirements are documented in
[`AGENT-REPO-CONTEXT.md`](AGENT-REPO-CONTEXT.md).

## License

See [LICENSE](LICENSE).
