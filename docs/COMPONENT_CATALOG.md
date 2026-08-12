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

Root layouts may place reusable external fragments with bounded imports:

```xml
<includes>
  <include id="chronomark.weapon-status" src="weapon-status.xml"
           x="0" y="0" anchor="bottom-left"
           visible="true" visibleWhen="always" z="102" />
</includes>
```

The runtime loads `src` only from `Interface/VenworksCUI/components`, resolves
all includes atomically, prefixes fragment-local IDs with the include ID, and
then passes the complete document to ordinary composition and validation. A
fragment is a `venworksCUIFragment` containing exactly one local root `group`.
Fragments cannot import other fragments. The root owns placement, anchoring,
visibility, and z-order.

At most 16 fragments may be included. Paths cannot contain traversal,
subdirectories, backslashes, schemes, query strings, or URL fragments, and a
fragment is limited to 65,536 characters. Missing, malformed, unsafe, nested,
or duplicate imports fail the complete configurable layer with an actionable
diagnostic.

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
Each renderer owns its empty and filled drawing and redraws in place when a
live binding changes. Dynamic meters do not require a second background meter
or an external whole-component mask.

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
| Bethesda embedded symbol | Implemented; acceptance pending | Reference a semantic name from a movie-aware hardcoded allowlist of symbols embedded in the owning vanilla movie; mappings are `environment-alert`, `quest-door-marker`, `boost-fill`, and noninteractive `vehicle-exit-prompt`. The vehicle mapping extracts Bethesda's initialized `GetUpButton_mc` hold-button child and bounds its presentation to the union of the keyboard and controller glyph children, so the full HUD timeline and the hold-button label area are never fitted into the CUI box. The mobility fragment composes that live mapped glyph with Bethesda's localized `$EXIT HOLD` label. |
| Built-in icon | Implemented; acceptance pending | Reference one of 21 generated semantic icons compiled directly into each HUD movie; supports tint, fit, and alignment without a runtime asset handle. |
| Supplemental symbol library | Retired | Starfield raised Error #1034 across the child-domain SWF compatibility attempts; external SWF libraries are no longer loaded. |
| SVG path | Implemented; acceptance pending | Render a bounded authored path with fill, stroke, transform, and view box; arc commands are rejected. |
| SVG asset | Implemented; in-game loading confirmed | Load and validate a restricted local SVG through the fixed `Interface/VenworksCUI/Assets` root; no network URLs, scripts, text, or external references. |
| Direct raster/DDS image | Unsupported | PNG, JPEG, and DDS probes were found at their loose paths but rejected by Starfield Scaleform; use loose SVG or a built-in icon. |
| Curated Font Awesome icon | Implemented; acceptance pending | Generate only the approved 21-icon subset into committed ActionScript; Font Awesome source SVGs remain developer inputs and are not committed. |

The icon generator receives the local Font Awesome Pro root through an explicit
parameter. Its machine-specific path is never recorded. It converts source arcs
to cubic paths and writes a deterministic same-domain library containing only
the approved icon subset; source SVGs are not committed.

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

Goal 4E adds atomic restricted SVG loading, generated same-domain icons,
authored SVG paths, nested rectangle/ellipse/path masks, and movie-aware
Bethesda semantic symbols. Loose SVGs are confined to
`Interface/VenworksCUI/Assets`; the 21 built-in icons are compiled into both HUD
movies and create no runtime file handles. Supplemental SWF and direct
DDS/raster loading are retired after failed in-game probes. Unsupported or
missing content fails the entire CUI layer with an actionable diagnostic.

## Goal 5 live-value probe

Goal 5 adds an allowlisted live-value adapter for the player HUD. `text`
accepts either one `source` with a bounded `format`, or a bounded
`valueTemplate` containing up to eight allowlisted variables with optional
per-variable formats. `meter` accepts an optional numeric `source` and numeric
`maxSource`. Required static values remain fallbacks until every required
vanilla value publishes its first update. Dynamic meters redraw the ordinary
approved meter renderer's empty and filled portions, so continuous, segmented,
triangle, dot, and radial visuals remain reusable rather than gaining
provider-specific implementations.

The first probe replaces the complete bottom-left Chronomark presentation and
confirms values published to `hudmenu.gfx`, including weapon name/ammo type.
The discovery gallery compares direct and templated carry/credits values from
`PlayerInventoryData` and tests whether `PowersMenuData` is sufficiently live
to resolve the active power key to a player-facing name. Arbitrary
provider/member selection remains prohibited.

Goal 5 also exposes bounded explosive count/type and jetpack charge values.
The weapon fragment uses them for grenade/mine presentation, while the mobility
fragment owns boost and an `inVehicle`-conditioned vehicle prompt. The prompt
extracts the initialized `GetUpButton_mc` child from a temporary embedded
Bethesda vehicle control, then fits only that bounded hold button. It disables
mouse interaction and receives no routed user events. The hidden vanilla
`HUDVehicle_mc` remains alive and exclusively processes vehicle-exit input.
