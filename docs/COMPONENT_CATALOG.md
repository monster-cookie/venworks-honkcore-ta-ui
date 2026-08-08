# Venworks CUI Component Catalog

Date: 2026-08-06

## Purpose and evidence boundary

This catalog defines the reusable building blocks needed before individual
player and ship UI surfaces are converted. It combines:

- components confirmed in vanilla Starfield UI files;
- user-visible requirements from Venworks-owned themes and screenshots; and
- reusable primitives needed to express those requirements without embedding
  one theme's layout in ActionScript.

This is a clean-room requirements catalog. It does not describe or reproduce
HONKCORE code, bytecode, parser behavior, file format, or internal class design.
Exact vanilla data-provider bindings remain unknown until each owning movie is
inspected and tested.

## Status vocabulary

- **Implemented:** available in the current runtime and schema.
- **Next:** expected in the next component-library or layout goal.
- **Future:** required before the corresponding UI surface can ship.
- **Research:** visible requirement identified; exact vanilla owner or provider
  contract still needs discovery.

## Foundation primitives

### Layout composition

| Capability | Status | Required behavior |
|---|---|---|
| Absolute positioning | Implemented | Preserve parent-relative `x` and `y` behavior when no anchor is configured. |
| Nine-point anchoring | Implemented | Align transformed configured bounds to top, center, or bottom and left, center, or right parent points with signed offsets. |
| Root safe area | Implemented | Anchor root components inside Starfield's visible rectangle after applying four independent design-space insets. |
| Nested anchoring | Implemented | Anchor children to their parent group's configured bounds. |
| Reusable template | Implemented | Instantiate a primitive-only component tree with bounded text, meter-value, and visibility overrides. |
| Repeater/list layout | Implemented | Lay out up to 64 declared items vertically, horizontally, or in a grid; hidden items collapse. |
| Bounded state selection | Implemented | Select one of up to 16 declared templates without expressions or arbitrary method calls. |
| Data-only conditions | Implemented | Evaluate bounded, case-insensitive visibility expressions against verified vanilla state with fail-hidden unknown initialization. |
| Vanilla visibility adapter | Implemented | Apply alpha presentation gates only to explicitly mapped default UI pieces while preserving vanilla visibility and lifecycle behavior. |

Goal 4A keeps a fixed 1920-by-1080 design coordinate system and relies on
Starfield's `Extensions.visibleRect` for viewport boundaries. It does not
apply nonuniform screen scaling. Runtime acceptance at standard and ultrawide
aspect ratios remains required before the capability is used by a live HUD
surface.

| Component | Status | Required behavior |
|---|---|---|
| Group | Implemented | Nest children and apply bounds, transforms, opacity, visibility, and z-order. |
| Text | Implemented | Style a bounded, timeline-linked Starfield text field with configurable size, color, weight, and alignment. |
| Panel | Implemented | Render a rectangular fill and stroke for cards, readouts, warnings, and composite backgrounds. |
| Shape | Implemented | Render rectangle and ellipse primitives with independent fill and stroke styling. |
| Divider | Implemented | Render configurable horizontal, vertical, or diagonal line geometry. |
| Error panel | Implemented | Show actionable load/schema errors in the upper center/right region and remain hidden after a valid load. |
| Repeater/list | Implemented | Lay out a bounded fixed collection vertically, horizontally, or in a grid with spacing and item limits. |
| State container | Implemented | Select one fixed configuration state without allowing arbitrary expressions or method calls. |
| Mask/clip | Implemented; acceptance pending | Bound one or more children to rectangle, ellipse, or approved path geometry, including nested masks. |

## Meter and bar family

All meter renderers share one contract: `value`, `max`, bounds, style reference,
fill and empty colors, fill and empty opacity, transforms, visibility, and
z-order. A renderer changes appearance without changing the owning HUD binding.
Values clamp to the range from zero through `max`.

| Renderer | Status | Primary uses |
|---|---|---|
| Continuous bar | Implemented | Health, oxygen, boost, enemy health, ship hull/shields, and other linear values; supports four fill directions. |
| Stacked triangles | Implemented | Uniform or alternating-orientation segments, four fill directions, and optional partial final-segment fill. |
| Segmented rectangles | Implemented | Discrete or visually stepped meters with whole or partial final segments. |
| Dots/circles | Implemented | Compact counters and alternate meter styling with whole or partial final dots. |
| Chevrons/notches | Future | Directional or technical segmented meters. |
| Radial/circular arc | Implemented | Bounded continuous clockwise/counterclockwise arcs for oxygen/CO2, cooldown, progress, and compact gauges. |
| Image-masked meter | Future | Theme-authored fills bounded by an approved image or vector mask. |
| Bipolar/center-origin bar | Future | Signed values or opposing states where the neutral point is centered. |

The reusable meter family is expected to cover at least these visible surfaces:
player health, oxygen, CO2, boost, enemy health, stealth/detection, experience or
progress, ship hull, ship shields, ship boost, individual weapon groups, and
power-allocation levels. Each surface still requires an independently verified
vanilla owner and provider contract.

## Vector, icon, and media components

| Component | Status | Required behavior |
|---|---|---|
| Built-in symbol/icon | Implemented; acceptance pending | Reference a semantic name from a movie-aware hardcoded allowlist of symbols embedded in the owning vanilla movie; initial mappings are `environment-alert`, `quest-door-marker`, and `boost-fill`. |
| SVG path | Implemented; acceptance pending | Render a bounded authored path with fill, stroke, transform, and view box; arc commands are rejected. |
| SVG asset | Implemented; in-game loading confirmed | Load and validate a restricted local SVG through the fixed `Interface/VenworksCUI/Assets` root; no network URLs, scripts, text, or external references. |
| DDS image | Implemented; acceptance pending | Atomically preload a local DDS through `img://textures/interface/VenworksCUI/Assets/` with contain, cover, stretch, or intrinsic/clipped placement. |
| PNG/JPEG image | Unsupported for direct runtime loading | Convert raster source artwork to DDS; direct `img://` PNG and JPEG probes were found and attempted but rejected by Starfield Scaleform. |
| Font icon | Future | Render an approved glyph from a packaged font subset with a stable semantic icon name. |

A local Font Awesome Pro installation is available and may simplify future
icon or bar renderers. Its machine-specific path is intentionally not recorded
in the repository. No Font Awesome file is inspected, copied, subset, or
distributed by Goal 3. Before use, the exact installed version, source file,
glyph subset, embedding method, notices, and redistribution terms must be
approved. Native vector geometry remains the default when it is sufficient.

## Composite components

Composite components are authored from primitives and expose a smaller,
gamer-facing configuration surface.

| Composite | Status | Composition and behavior |
|---|---|---|
| Button | Future | Panel/shape, icon, label, key hint, enabled state, selected state, and cooldown/quantity overlay. |
| Quick bar | Future | A panel containing an ordered, bounded collection of buttons. Each button can be enabled, disabled, or reordered in configuration. |
| Compass | Research | Line/divider, heading label, direction ticks, markers, and optional background; marker data must remain owned by the vanilla compass provider. |
| Minimap/radar | Research | Bounded panel, player marker, contacts/POIs, sweep/cone, grid, scale label, and clip mask. Feasibility depends on vanilla data exposed to the owning movie. |
| Information panel | Future | Panel, title, key/value text, dividers, optional scroll/overflow indicator, and status accents. |
| Notification/toast | Future | Panel, icon, primary/secondary text, priority, duration, and bounded entrance/exit effects. |
| Warning panel | Future | Severity color, icon, title, detail, and visibility/state rules. |
| Item/ammo readout | Future | Weapon/item icon, amount, reserve amount, state color, and optional meter. |
| Status-effect row | Research | Bounded list of icons, labels, timers/stacks, and severity states using only available vanilla data. |
| Reticle/crosshair | Research | Vector/symbol parts, spread/state transitions, hit feedback, and weapon-specific visibility. |

The quick bar is intentionally modeled as a panel plus buttons rather than one
fixed image. Configuration should allow a theme author to disable individual
buttons, change their order, and style the shared button template without
editing ActionScript.

## Player HUD coverage targets

- health and damage state;
- oxygen/CO2 and environmental state;
- boost/jetpack;
- weapon, ammunition, explosives, and inventory/readout state;
- compass, quest markers, and location information;
- enemy health and legendary/state indicators;
- stealth/detection, hit indicators, and reticles;
- scanner overlays and interaction prompts;
- notifications, warnings, mission updates, and status effects;
- quick-access or ability buttons where supported by vanilla providers.

## Ship UI coverage targets

- hull, shield, and boost meters;
- weapon group state, charge, ammunition, and target lock;
- power allocation and subsystem damage;
- speed, throttle, attitude, and navigation indicators;
- targeting, lead/reticle, and selected-target panels;
- warnings, notifications, docking, and interaction prompts;
- interactive ship menus only after their navigation contracts are mapped.

## Configuration safety rules

- Local packaged assets only; no network resources.
- No ActionScript, JavaScript, method names, executable expressions, or dynamic
  class names in user configuration.
- Unknown elements, attributes, renderers, references, or duplicate IDs fail
  with an actionable error.
- Counts, dimensions, coordinates, opacity, and animation parameters are
  bounded before a component renders.
- Components cannot invoke game methods or subscribe to arbitrary providers.
- Bindings will be selected from an allowlist owned by each verified vanilla
  movie adapter.

## Goal 3 implemented subset

Goal 3 deliberately implements only the foundation needed to prove the model:
group, text, panel, rectangle/ellipse shape, divider, the shared meter contract,
continuous bar, and stacked-triangle bar. The fixed gallery uses static values;
it does not replace health or bind to live game data.

## Goal 4 implemented subset and next gate

Goal 4A adds nine-point root and nested anchoring plus root safe-area insets.
Goal 4B adds primitive-only templates, instances, fixed repeaters, static state
selection, and small text/meter-value/visibility overrides. These remain fixed
configuration and do not connect to live Starfield data.

Goal 4C adds `visibleWhen` to components and composition placements, a bounded
Boolean/numeric expression evaluator, confirmed player-HUD provider adapters,
and a hardcoded initial vanilla target allowlist. Ship values, named effects,
and engine-sensitive vanilla targets remain unavailable pending owner-specific
discovery and isolated tests.

Goal 4D completes the current fixed-data meter renderer family with segmented
rectangles, dots/circles, alternating triangles, four linear fill directions,
optional partial segments, and bounded continuous radial arcs. These renderers
remain independent of live Starfield providers.

Goal 4E adds atomic packaged DDS/SVG loading, restricted static SVG parsing,
authored SVG paths, rectangle/ellipse/path masks with nesting, and a
movie-aware semantic allowlist for embedded vanilla symbols. DDS textures are
confined to `Textures/Interface/VenworksCUI/Assets`; SVG files are confined to
`Interface/VenworksCUI/Assets`. Unsupported or missing content fails the entire
CUI layer with an actionable diagnostic. Composite components remain the next
Goal 4 gate.
