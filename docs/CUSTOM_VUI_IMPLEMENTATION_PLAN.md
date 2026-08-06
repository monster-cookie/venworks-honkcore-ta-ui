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
- SVG path rendering and PNG support are required. JPEG remains useful for
  opaque photographic art.
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

## Goal 0: Repository and toolchain discovery

Inventory the repository, vanilla Interface archive, HUD/ship movies, data
providers, available tools, configuration-loading options, existing theme
behaviors, packaging paths, and clean-room boundaries. Recommend the first
runtime toolchain and probe without changing product code.

Done when `GOAL_0_DISCOVERY.md` and `CLEAN_ROOM.md` record the evidence,
unknowns, proposed layout, and blocking decisions.

## Goal 1: Prove the runtime editing toolchain

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

Add the smallest XML loader to the approved test movie. Load an adjacent XML
file through Starfield's file opener and render one configured value.

The probe must cover success, missing file, malformed XML, unsupported schema
version, and safe diagnostic behavior. If XML loading is unavailable, stop and
compare an embedded JSON/default configuration or another vanilla-supported
data-only path. Do not implement TOML parsing in ActionScript without a new
approved plan.

## Goal 3: Define the versioned layout and palette schemas

Define strict XML schemas for:

- a layout root and schema/runtime versions;
- design resolution and safe area;
- palette reference;
- modules and nodes;
- anchors, bounds, transforms, z-order, and visibility;
- labels, meters, images, shapes, and SVG paths;
- bounded bindings and expressions;
- palette colors, typography, opacity, strokes, and state values;
- a defined extension area for forward-compatible optional metadata.

Unknown required elements and attributes fail with actionable diagnostics.
Arbitrary ActionScript, JavaScript, network resources, method calls, and
executable extensions are prohibited.

## Goal 4: Implement the minimal configurable player HUD runtime

Load one core layout and referenced palette, then render:

- one static shape;
- one text field;
- one proven HUD-provider binding;
- one conditionally visible node;
- one transparent PNG;
- one SVG path.

Ship at least three distinct palette examples. Validate reload, save load,
first/third person, scanner, death/reload, ladder, and workbench transitions.

## Goal 5: Migrate the four existing variants

Create clean-room palette packages for Freestar Collective, Crimson Fleet,
Trackers Alliance, and Venworks. Recreate shared layout behavior independently
against vanilla provider contracts. Existing HONKCORE configuration may supply
only observable requirements, labels, coordinates, colors, and user-authored
art intent; it is not parser or runtime source material.

Exclude SPECTR and TACR during migration. Every migrated behavior is either
validated against Starfield or explicitly marked unavailable/unknown.

## Goal 6: Reimplement approved player HUD configurability

Implement in bounded batches:

1. vanilla component visibility and positioning;
2. health, oxygen/CO2, boost, inventory, weapon, ammo, and explosives;
3. warnings and state transitions;
4. scanner, enemy, hit, sneak, crosshair, quest, and quick-access surfaces;
5. bounded effects and animations;
6. status effects only to the level proven available in an always-loaded HUD.

Each component requires a schema representation, vanilla provider contract,
default layout, palette hooks, static checks, and Starfield lifecycle tests.

## Goal 7: Implement approved ship UI configurability

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

## Goal 8: Packaging and release integration

Add `Staging-CUI` and the four migrated staging variants when their required
runtime artifacts exist. Update the existing release workflow rather than
creating an application-specific workflow.

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
