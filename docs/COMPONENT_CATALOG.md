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

- **Implemented:** available in the Goal 3 runtime and schema.
- **Next:** expected in the next component-library or layout goal.
- **Future:** required before the corresponding UI surface can ship.
- **Research:** visible requirement identified; exact vanilla owner or provider
  contract still needs discovery.

## Foundation primitives

| Component | Status | Required behavior |
|---|---|---|
| Group | Implemented | Nest children and apply bounds, transforms, opacity, visibility, and z-order. |
| Text | Implemented | Style a bounded, timeline-linked Starfield text field with configurable size, color, weight, and alignment. |
| Panel | Implemented | Render a rectangular fill and stroke for cards, readouts, warnings, and composite backgrounds. |
| Shape | Implemented | Render rectangle and ellipse primitives with independent fill and stroke styling. |
| Divider | Implemented | Render configurable horizontal, vertical, or diagonal line geometry. |
| Error panel | Implemented | Show actionable load/schema errors in the upper center/right region and remain hidden after a valid load. |
| Repeater/list | Future | Lay out a bounded collection vertically, horizontally, or in a grid with spacing and item limits. |
| State container | Future | Select one child state without allowing arbitrary expressions or method calls. |
| Mask/clip | Future | Bound child rendering to rectangular, circular, or approved vector geometry. |

## Meter and bar family

All meter renderers share one contract: `value`, `max`, bounds, style reference,
fill and empty colors, fill and empty opacity, transforms, visibility, and
z-order. A renderer changes appearance without changing the owning HUD binding.
Values clamp to the range from zero through `max`.

| Renderer | Status | Primary uses |
|---|---|---|
| Continuous bar | Implemented | Health, oxygen, boost, enemy health, ship hull/shields, and other linear values. |
| Stacked triangles | Implemented | Venworks health style and other segmented linear values; supports partial final-segment fill. |
| Segmented rectangles | Next | Discrete or visually stepped meters. |
| Dots/circles | Next | Compact counters and alternate meter styling. |
| Chevrons/notches | Future | Directional or technical segmented meters. |
| Radial/circular arc | Future | Oxygen/CO2, cooldown, progress, and compact gauges. |
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
| Built-in symbol/icon | Future | Reference a permitted symbol already embedded in the owning vanilla movie. |
| SVG path | Future | Render an authored path with bounded fill, stroke, transform, and view box. |
| SVG asset | Future | Load a local, packaged SVG through a fixed asset root; no network URLs or scripts. |
| PNG image | Future | Load a local transparent PNG through a fixed asset root with fit/crop behavior. |
| JPEG image | Future | Load an opaque local image where transparency is not needed. |
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
