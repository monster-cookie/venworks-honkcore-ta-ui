# Venworks Customizable UI Implementation Plan

## Purpose

Build a clean-room, configuration-driven Starfield UI replacement based only on
vanilla Starfield Scaleform assets and documented/user-visible behavior. The
game package must be usable by nontechnical players: installing a prepared
variant must not require an end-user compiler, GUI application, SFSE, a native
plugin, or a background service.

The runtime will use a core layout configuration that references a separate
palette configuration. The customizable base package will include three or
four example palettes. The four existing Freestar Collective, Crimson Fleet,
Trackers Alliance, and Venworks variants will migrate to this clean-room format.

A visual editor is a separate, long-term project after the configuration-only
runtime and supported UI surfaces have shipped.

## Confirmed product decisions

- Use vanilla Starfield SWF/GFX assets as the implementation baseline.
- Do not inspect, copy, translate, patch, or redistribute HONKCORE code,
  ActionScript, bytecode, binaries, artwork, parser design, or file format.
- Existing owned configuration files may be inventoried only for observable
  behavior and theme intent.
- Use a core layout file plus a referenced palette file.
- Prefer XML over TOML for the first runtime probe because Scaleform exposes
  native XML support. Do not make XML final until Starfield loads an adjacent
  XML file through its actual file opener.
- Themes are selected before Starfield launches. Runtime palette switching is
  optional and must not delay the install-time workflow.
- SVG path rendering and compiled SWF symbol-library support are required.
  Direct PNG, JPEG, and DDS loading is unsupported after in-game probes;
  raster artwork must be converted to an approved vector or compiled symbol.
- Exclude SPECTR, TACR, and rear-view/secondary-camera rendering.
- Support the player HUD and the approved ship UI surfaces, but preserve each
  vanilla movie's input, lifecycle, data-provider, and root contracts.
- The customizable base release contains only permitted Scaleform movies,
  configuration, palettes, fonts, images, and documentation.
- The future editor is outside this repository and outside the current release
  workflow.

## Architecture target

```text
Interface/VenworksCUI/layout.xml
          |
          +--> Interface/VenworksCUI/Palettes/<selected>.xml
          |
          +--> Interface/VenworksCUI/Assets/...
          |
          +--> Interface/VenworksCUI/Libraries/...
          |
          v
modified vanilla-derived Starfield Scaleform movies
          |
          v
Starfield data providers and menu lifecycle
```

Names and paths above are provisional until the external-file loading probe
passes. A package is preconfigured by setting the palette reference in its
layout or manifest. Players install the prepared files; they do not compile
them.

## Evidence rules

- Label claims as confirmed by source/static inspection, confirmed by an
  automated check, confirmed in Starfield, inferred, or unknown.
- Do not claim a vanilla provider, loose path, external file, image, or lifecycle
  behavior works until the exact artifact passes the relevant runtime probe.
- Do not claim that a SWF/GFX editing tool produces a safe artifact until the
  produced movie loads and preserves the required vanilla contracts.
- Pause after every goal for review and an optional user commit.

## Current master-feature status

These statuses summarize the documented implementation and runtime evidence.
They do not treat planned work as complete.

| Master feature | Status | Remaining documented work |
|---|---|---|
| Clean-room CUI runtime and component framework | Complete | None for the current component-foundation scope. |
| Chronomark replacement | Complete | None for the accepted Goal 5 scope. |
| Environmental scanner and Player Data HUD | In progress | Complete final visual acceptance of the unified frame and vertical-channel layout. |
| Tactical equipment rail | Complete | None for the accepted Goal 7 equipment-rail scope. |
| Contact radar and faction display | In progress | Confirm corrected single-domain startup and complete live ranging, contact, and kill-transition acceptance. |
| Helmet compass, threat alert, and active effects | In progress | Validate combat/proximity threat escalation and accept the large HUD variant. |
| Remaining player HUD surfaces | Planned | Inventory, implement, and validate the remaining approved player HUD surfaces. |
| Ship UI configurability | Planned | Map owner movies and provider contracts, then implement and validate the approved ship surfaces. |
| Palette system and four theme migrations | Planned | Define the palette schema, ship examples, migrate the four themes, and validate them in Starfield. |
| Packaging and release integration | In progress | Integrate the final layouts, palettes, assets, notices, validation, workflow, and release archives. |

## Goal 0: Repository and toolchain discovery

**Current status:** Complete.

Inventory the repository, vanilla Interface archive, HUD/ship movies, data
providers, available tools, configuration-loading options, existing theme
behaviors, packaging paths, and clean-room boundaries. Recommend the first
runtime toolchain and probe without changing product code.

Done when `GOAL_0_DISCOVERY.md` and `CLEAN_ROOM.md` record the evidence,
unknowns, proposed layout, and blocking decisions.

## Goal 1: Prove the runtime editing toolchain

**Current status:** Complete.

Select an approved SWF/GFX inspection and editing workflow. Work from vanilla
Starfield artifacts extracted from `Starfield - Interface.ba2`. Produce the
smallest repository-local test artifact and document reproducible steps.

Required gate:

1. Inspect vanilla SWF and GFX structure without HONKCORE inputs.
2. Make a harmless visible change to a vanilla-derived HUD movie.
3. Package it as a loose override in repository-local staging.
4. Confirm it loads in Starfield and preserves basic HUD lifecycle.

Stop before installing a new tool, adding a dependency, committing a
vanilla-derived binary, or selecting an exporter/editor.

## Goal 2: Prove external XML configuration loading

**Current status:** Complete.

Add the smallest XML loader to the approved test movie. Load an adjacent XML
file through Starfield's file opener and render one configured value.

The probe must cover success, missing file, malformed XML, unsupported schema
version, and safe diagnostic behavior. If XML loading is unavailable, stop and
compare an embedded JSON/default configuration or another vanilla-supported
data-only path. Do not implement TOML parsing in ActionScript without a new
approved plan.

## Goal 3: Establish the reusable component library

**Current status:** Complete.

Define the full component catalog before converting individual HUD surfaces.
Implement the first strict layout subset and prove reusable primitives with a
fixed, unbound gallery:

- group, text, panel, shape, and divider;
- a shared meter contract;
- continuous and stacked-triangle meter renderers;
- strict IDs, bounds, transforms, z-order, visibility, and style references;
- actionable, error-only diagnostics in a dedicated upper panel.

Unknown elements, attributes, renderers, duplicate IDs, invalid references,
and invalid bounds fail safely. Arbitrary ActionScript, JavaScript, network
resources, method calls, and executable extensions are prohibited. No live HUD
provider is connected during this goal.

## Goal 4: Complete composition, conditions, and asset primitives

**Current status:** Complete for the accepted component-foundation scope.

Extend the versioned layout schema and runtime through bounded review gates:

- anchors, safe-area behavior, reusable templates, repeaters, and bounded state
  selection;
- data-only conditions and allowlisted adapters that control verified vanilla
  HUD visibility without exposing arbitrary providers or methods;
- segmented rectangles, dots/circles, and radial meter renderers;
- local SVG assets and curated compiled SWF symbol libraries;
- authored SVG paths, masks, and permitted embedded symbols;
- composite button, quick-bar, information-panel, and warning foundations.

Validate each component in a gallery before it is connected to live data.
Font Awesome Pro may be evaluated as an explicitly approved, licensed icon
source, but it is not required when native vector geometry is sufficient.

Goal 4 is divided into bounded review gates:

- **Goal 4A — responsive layout:** optional nine-point anchoring, operational
  root safe-area insets, group-relative anchoring, and unchanged absolute
  positioning. It uses Starfield's vanilla `Extensions.visibleRect` contract
  and retains fixed 1920-by-1080 design proportions.
- **Goal 4B — fixed-data composition:** primitive-only reusable templates,
  instances with small gamer-facing overrides, bounded vertical/horizontal/grid
  repeaters, and configuration-selected states. No live providers are connected.
- **Goal 4C — conditions and vanilla visibility adapters:** bounded,
  case-insensitive visibility expressions, tri-state provider initialization,
  and hardcoded per-movie presentation adapters for independently verified
  default UI pieces. The implementation is accepted, with the combat transition
  smoke test deferred until the Venworks UI duplication. Unknown or unavailable
  providers and unsafe targets fail safely;
  arbitrary provider names, display paths, properties, and methods remain
  prohibited.
- **Goal 4D — remaining meter renderers:** segmented rectangles, dots/circles,
  alternating triangles, four linear fill directions, optional partial
  segments, and bounded continuous radial renderers. The implementation and
  positive/negative in-game gallery checks are accepted.
- **Goal 4E — assets and vector primitives:** local SVG, authored SVG paths,
  masks, and permitted embedded Bethesda symbols. Direct DDS/raster and
  supplemental SWF loading were retired after failed probes. The implementation
  and its positive/negative in-game gallery checks are accepted.
- **Goal 4F — built-in icon library:** 21 allowlisted icons generated from the
  approved Font Awesome Pro subset and embedded in the HUD movies as same-domain
  ActionScript drawing data. SVG arcs are converted to cubic Bézier paths during
  generation, so round icons remain available without runtime arc support or
  external asset handles. The implementation and its in-game gallery checks are
  accepted.
- **Goal 4G — composite foundations:** reusable button, quick-bar, information
  panel, and warning components assembled from approved primitives. Composite
  configuration lowers into the existing bounded primitive runtime before
  ordinary parsing and validation. Buttons provide normal, selected, disabled,
  and warning states; quick bars allow at most 16 independently visible buttons;
  information panels allow at most 12 metadata rows and 20 total content items;
  warnings provide info, warning, danger, and critical severities. The
  implementation and its positive/negative in-game gallery checks are
  accepted.

Each gate requires a gallery and failure fixtures before use on a live HUD
surface. Each remaining goal follows acceptance of the preceding gate; palettes
remain deferred until the UI work is complete.

## Goal 5: Implement the first configurable player HUD surface

**Current status:** Complete.

The approved first surface is the bottom-left Chronomark replacement. Goal 5
starts with a provider probe in approximately the final layout: it hides the
complete vanilla bottom-left group through the lifecycle-safe adapter, renders
the replacement whenever the HUD is active, and ignores scanner state. Only
allowlisted fields confirmed in the vanilla `hudmenu.gfx` provider contract may
bind. The probe exposes location, local time, atmospheric oxygen, temperature,
gravity, health, O2, active-power data, and weapon ammo. Weapon name/ammo type,
carry weight, and credits remain visibly labeled provider gaps until an
always-loaded owner is proven; they are not guessed.

The live binding contract is deliberately smaller than an expression system:
text selects one allowlisted `source` and bounded `format`, while meters select
one numeric `source` and optional numeric `maxSource`. Configuration cannot
subscribe to arbitrary providers or name ActionScript members. See
`GOAL_5_CHRONOMARK_REPLACEMENT.md` for the discovered provider map, probe
acceptance checks, and final-layout requirements.

Validate reload, save load, first/third person, scanner, death/reload, ladder,
workbench, and ship transitions before expanding the runtime.

## Goal 6: Reimplement approved player HUD configurability

**Current status:** In progress. The environmental scanner, Player Data HUD,
tactical equipment rail, contact radar, faction display, helmet compass,
threat alert, and active-effects implementation work is present. The master
status table records the remaining runtime and large-HUD acceptance work.

Implement in bounded batches:

1. vanilla component visibility and positioning;
2. health, oxygen/CO2, boost, inventory, weapon, ammo, and explosives;
3. warnings and state transitions;
4. scanner, enemy, hit, sneak, crosshair, quest, and quick-access surfaces;
5. compass, permitted minimap/radar behavior, panels, and notifications;
6. bounded effects and animations;
7. status effects only to the level proven available in an always-loaded HUD.

Each component requires a schema representation, vanilla provider contract,
default layout, future palette hooks, static checks, and Starfield lifecycle
tests.

## Goal 7: Implement approved ship UI configurability

**Current status:** Planned.

Inventory and modify the actual vanilla owner movies in stages:

1. cockpit HUD presentation;
2. targeting and weapons;
3. power allocation;
4. ship notifications and warnings;
5. interactive ship menus;
6. ship builder/management surfaces.

Pause between noninteractive and interactive work. Preserve controller and
keyboard/mouse navigation, warning priority, critical information, and menu
lifecycle.

## Goal 8: Define palettes and migrate the four existing variants

**Current status:** Planned.

After the approved player and ship component work is stable, define the strict
palette schema and reference it from the core layout. Palette configuration
covers named colors, typography, opacity, strokes, states, and permitted asset
choices without changing component structure or bindings.

Ship three or four example palettes with the customizable base. Create
clean-room configurations for Freestar Collective, Crimson Fleet, Trackers
Alliance, and Venworks. Existing owned configuration may supply only observable
requirements, labels, coordinates, colors, and user-authored art intent; it is
not parser or runtime source material.

Exclude SPECTR and TACR during migration. Every migrated behavior is either
validated against Starfield or explicitly marked unavailable/unknown.

## Goal 9: Packaging and release integration

**Current status:** In progress. The current loose CUI payload is synchronized
byte-identically across all four staging variants; final palette and release
packaging remains pending.

Add the required runtime artifacts directly to the four themed staging
variants. `Staging-VWKS` remains the initial runtime-tested layout project;
Goal 6 synchronizes its accepted loose CUI payload to CF, FC, and TA so compiled
HUD and editable layout artifacts cannot drift while those themes await their
own conversion passes. Update the existing release workflow
rather than creating an application-specific workflow.

Packages must:

- contain files at the expected `Interface` root without a staging wrapper;
- contain no HONKCORE, SFSE, or native-plugin files;
- contain the correct core layout and referenced palette;
- include three or four palettes in the customizable base;
- include required notices;
- preserve filename case and separators;
- be nonempty and reproducible;
- remain installable without running an executable.

## Final acceptance criteria

- Starfield loads a vanilla-derived, independently modified HUD runtime.
- The runtime reads a versioned core layout and referenced palette directly.
- Three or four example palettes ship with the customizable base.
- The four existing themes use the clean-room configuration system.
- Approved player and ship UI capabilities are implemented or explicitly
  documented as unavailable through vanilla console-safe contracts.
- No HONKCORE implementation or format is reused.
- No SFSE, native plugin, end-user compiler, or editor is required.
- SPECTR, TACR, and rear-view rendering are absent.
- Release archives are reproducible and install at the correct root.
- The future GUI editor remains a separate post-release project.
