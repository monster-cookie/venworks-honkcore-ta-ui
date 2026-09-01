# Venworks Customizable HUD: Player Guide

This guide is for players who want to customize the look, placement, visibility, and colors of the Venworks Customizable HUD. You do not need to change HUD movies or write code; edit the supplied root layout and palette XML files. The supplied reusable component definitions themselves are compiled into `venworkscui.swf`.

For every supported XML element and attribute, use the
[layout configuration reference](LAYOUT_CONFIGURATION_REFERENCE.md). For a
complete palette contract and custom-theme workflow, use the
[palette configuration reference](PALETTE_CONFIGURATION_REFERENCE.md). For a
list of reusable HUD sections, components, and display filters, use the
[component library](COMPONENT_LIBRARY.md).

## Before you edit

1. Enable only one of the five Venworks Customizable HUD release variants. All
   variants install the same HUD and configuration paths, so they must never be
   enabled together.
2. Fully exit Starfield.
3. Back up the loose `Interface\VenworksCUI\layout.xml` from the normal package.
   If you use the fully loose package or an advanced override, back up the
   complete `Interface\VenworksCUI` directory.
4. Use a plain-text or XML editor that preserves UTF-8 text and straight ASCII
   quotation marks.
5. Keep a copy of every customized file outside the downloaded mod package.

When replacing an experimental Bethesda Creation with an official release that owns the same ESM identity, uninstall the experimental entry first and verify that only one remains before installing the replacement; duplicate Creation entries can compete over the same plugin and BA2 files.

Mod-manager updates, reinstalls, purge/deploy operations, and file-conflict
changes can replace local edits. The normal Nexus package supplies only
`layout.xml` loose; its supplied component definitions remain in `venworkscui.swf`, while palettes and SVG assets remain in
the BA2. The safest long-term setup for advanced changes is a small personal
override mod containing only your changed `Interface\VenworksCUI` files and
loading after the selected theme variant. Alternatively, use the Nexus PC -
Fully Loose Files package by itself. If you edit a downloaded file directly,
keep a separate backup that an update cannot overwrite.

Do not edit `hudmenu.gfx`, `hudmenu_lrg.gfx`, or `venworkscui.swf` to make the XML changes in this guide. The base HUD movies load the packaged standalone configuration runtime automatically.

## Installed files

The release variants expose these runtime paths relative to Starfield's
`Data\Interface` directory:

```text
VenworksCUI\
  layout.xml
  Assets\
    *.svg
  palettes\
    *.xml
```

The important files are:

| Path | Purpose |
|---|---|
| `Interface\VenworksCUI\layout.xml` | Selects the palette, defines shared meter styles, controls Bethesda HUD targets, places supplied SWF components or optional legacy custom fragments, and contains small root-level components. |
| `Interface\venworkscui.swf` | Contains the runtime and all 11 supplied reusable component definitions. |
| `Interface\VenworksCUI\palettes\*.xml` | Defines semantic colors, typography, opacity, strokes, and the faction crest. |
| `Interface\VenworksCUI\Assets\*.svg` | Contains supported local vector artwork used by the layout or palettes. |

Minimalist includes only `layout.xml` under `VenworksCUI` and intentionally omits the `components`, `Assets`, and `palettes` directories. Its build resolves the shipped Starfield color roles to literals in the layout and compiled `minimalist` definitions. The normal package exposes its layout loose; the fully loose package exposes that root XML and nine movies: byte-identical CWS normal/large HUD aliases at both `.gfx` and `.swf` paths, the native GFX/CWS HUD-message pairs, and the standalone CWS `venworkscui.swf` runtime.

The Nexus PC - Normal package exposes only `layout.xml` from this tree as a
loose file. The runtime resolves supplied component names from `venworkscui.swf` and, when
configured, palettes and SVG assets from the package's BA2. Do not install the
normal and fully loose packages together.

When using a mod manager, open the active mod's own file directory rather than
assuming the deployed `Data` copy is the authoritative source. The exact
manager-specific staging location is intentionally not fixed by this project.

## How configuration loading works

At HUD startup, the base HUD bootstrap asynchronously loads `Interface\venworkscui.swf`. After the auxiliary bridge initializes, the runtime:

1. loads `layout.xml`;
2. resolves and places every declared SWF component, while retaining the legacy external-fragment path for separately authored custom includes;
3. loads the selected palette;
4. expands composites, templates, repeaters, and states;
5. validates the resolved layout and all conditions and live-value bindings;
6. preloads every referenced local SVG; and
7. displays the complete custom layer only after those steps succeed.

The process is atomic. One invalid file prevents the configurable layer from
partially rendering. A diagnostic panel identifies the failure category and,
when available, the phase, checkpoint, component type, and component ID.

Minimalist follows the same root-layout loading path and uses live data contexts. It omits only the four providers used exclusively by its removed equipment rail; all remaining conditions and live-value bindings stay active. Every variant uses the same nine-path movie inventory in its fully loose package and in each platform's Main archive: CWS normal/large HUD bytes under both `.gfx` and `.swf` aliases, native GFX/CWS HUD-message pairs, and `venworkscui.swf`. The base HUD and HUD-message paths are shared across all variants; Minimalist's standalone CUI movie is profile-specific.

There is no live reload command. After every XML or SVG change, fully exit and
restart Starfield. Merely closing the scanner or opening a menu is not a
guaranteed reload.

## Switch the active theme

Open `Interface\VenworksCUI\layout.xml` and change only the root `palette`
attribute:

```xml
<venworksCUI schemaVersion="1" runtimeVersion="1"
             designWidth="1920" designHeight="1080"
             safeLeft="64" safeTop="36"
             safeRight="64" safeBottom="36"
             palette="trackers-alliance.xml">
```

The packaged choices are:

| Appearance | Palette filename |
|---|---|
| Venworks Customizable HUD - Venworks Theme | `venworks.xml` |
| Venworks Customizable HUD - Trackers Alliance Theme | `trackers-alliance.xml` |
| Venworks Customizable HUD - Freestar Collective Theme | `freestar-collective.xml` |
| Venworks Customizable HUD - Crimson Fleet Theme | `crimson-fleet.xml` |
| Neutral Starfield option | `starfield.xml` |

The filename must name one XML file directly inside
`Interface\VenworksCUI\palettes`. Subdirectories, path traversal, URLs, query
strings, and fragments are rejected.

Every themed release variant includes all five palette XML files. The themed
variant only chooses the initial default. All five current palette logo
references resolve to SVG files included with the themed HUD. Minimalist does
not ship an external palette or SVG asset, and its root layout has no palette
selector, although its movie retains the same palette and SVG runtime.

## Move a complete HUD section

Reusable supplied HUD sections are placed in the `<includes>` block of `layout.xml`.
Each `<swfComponent>` has an `x`, `y`, and optional `anchor`:

```xml
<swfComponent id="equipment-rail" name="equipment-rail"
              x="64" y="36" anchor="top-right"
              visible="true" visibleWhen="always" z="102" />
```

For anchored sections, `x` and `y` are signed offsets from the selected anchor
inside the root safe area. Increasing `x` moves the section right; increasing
`y` moves it down. Negative values move left or up.

The nine supported anchors are:

```text
top-left       top-center       top-right
center-left    center           center-right
bottom-left    bottom-center    bottom-right
```

The supplied SWF components are:

| Name | HUD section |
|---|---|
| `faction-icon` | Palette-selected faction crest. |
| `radar` | Bounded acquired-contact radar. |
| `quest-tracker` | Persistent tracked objective. |
| `planet-data-panel` | Location, planet, local solar-transition countdown, protection, and exposure status. |
| `player-data-panel` | Player statistics and meters. |
| `equipment-rail` | Favorites, weapon, explosive, and power information. |
| `compass` | Compass heading. |
| `threat-meter` | Threat state. |
| `status-effect-screen` | Active status effects. |
| `scanner-hash-panel` | Scanner-only heading, pulse, and hash grid. |
| `scanner-data-panel` | Scanner-only forward contacts. |

All 11 definitions exist in both production movies. The four themed layouts instantiate all 11 with the default `standard` variant. Minimalist instantiates nine with `variant="minimalist"` and omits `faction-icon` and `equipment-rail`.

Change one axis at a time in small increments, restart the game, and check
normal, aiming, scanner, and vehicle states. A placement that looks correct in
one state can overlap Bethesda-owned content in another.

## Hide a complete HUD section

Set the reference's `visible` attribute to `false`:

```xml
<swfComponent id="faction-icon" name="faction-icon"
              x="-64" y="-36" anchor="top-left"
              visible="false" visibleWhen="always" z="103" />
```

Keep the reference in the file. Removing it also works structurally, but toggling
`visible` makes the customization easier to maintain and reverse.

`visible="false"` always hides the section. `visibleWhen` cannot override a
static false value.

## Show a section only in a specific state

Use `visibleWhen` with an allowlisted condition:

```xml
<swfComponent id="scanner-data-panel" name="scanner-data-panel"
              x="0" y="0" anchor="center"
              visible="true" visibleWhen="inScanner" z="109" />
```

Conditions are case-insensitive and ignore underscores. They support `AND`,
`OR`, `NOT`, parentheses, and the numeric comparison operators `=`, `!=`,
`<>`, `<`, `<=`, `>`, and `>=`.

Examples:

```xml
visibleWhen="inScanner"
visibleWhen="inCombat AND NOT inScanner"
visibleWhen="firstPerson AND hudVisible"
visibleWhen="weaponAiming OR inScanner"
visibleWhen="hudOpacityPercentage >= 50"
```

Unknown live state evaluates as unknown and therefore remains hidden. Use the
[condition reference](LAYOUT_CONFIGURATION_REFERENCE.md#visibility-conditions)
for the complete allowlist and expression limits.

## Adjust the root safe area

The root layout always uses a 1920-by-1080 design coordinate system. The four
safe-area values inset the area used by root anchors from Starfield's visible
rectangle:

```xml
safeLeft="64" safeTop="36" safeRight="64" safeBottom="36"
```

Larger values move anchored content farther inward from that edge. Values must
be non-negative. `safeLeft + safeRight` cannot exceed 1920, and
`safeTop + safeBottom` cannot exceed 1080. The insets must leave a nonempty
visible area.

Safe-area changes affect anchored root components and included fragments. They
do not apply nonuniform screen scaling and should be tested at the actual aspect
ratio where they will be used.

## Move, resize, scale, or fade an individual component

Open the owning file under `Interface\VenworksCUI\components`. Most rendered
components share these attributes:

```xml
<group id="unique.name"
       x="0" y="0" width="320" height="80"
       opacity="1" visible="true" visibleWhen="always"
       rotation="0" scaleX="1" scaleY="1" z="1"
       anchor="top-left">
  <!-- Child components. -->
</group>
```

- `x` and `y` place the component relative to its parent when no anchor is
  present, or offset it from its anchor when an anchor is present.
- `width` and `height` define design-space bounds. Most visible components
  require positive values.
- `opacity` ranges from `0` through `1`.
- `rotation` is expressed in degrees.
- `scaleX` and `scaleY` are finite multipliers. Use equal values to preserve
  proportions.
- `z` is an integer used to order siblings; larger values draw above smaller
  values.
- `visible` and `visibleWhen` combine: both must permit display.

To scale a complete imported fragment, change `scaleX` and `scaleY` on the
fragment's one root `<group>`. Include declarations do not have scale
attributes. Scaling does not automatically reflow surrounding sections, so
recheck overlaps and anchor offsets.

Keep every `id` unique within its document. IDs must start with a letter, may
contain letters, numbers, dots, underscores, and hyphens, and may be no longer
than 64 characters.

## Control approved Bethesda HUD sections

The optional `<vanillaVisibility>` block in `layout.xml` can conditionally show,
hide, or reposition only six whole Bethesda HUD targets:

| Target ID | Bethesda display |
|---|---|
| `topCenter` | Top-center HUD group. |
| `bottomLeft` | Watch/environment HUD group. |
| `rightMeters` | Right-side meters. |
| `socialCommandIcons` | Social command icons. |
| `floatingQuestMarkers` | Floating quest markers. |
| `crewBuffWidget` | Crew buff widget. |

Target names are case-insensitive and ignore underscores. The production layout
suppresses the Bethesda Watch/environment group and right-side meters with real
display visibility:

```xml
<vanillaVisibility>
  <target id="bottomLeft" visibleWhen="never" />
  <target id="rightMeters" visibleWhen="never" />
</vanillaVisibility>
```

Do not use an offset to move an unwanted target outside the design area. That
is not a visibility contract and can fail under UI scaling or aspect-ratio
changes.

Relative placement requires `offsetX` and `offsetY` together and adds them to
Bethesda's original position. Absolute placement requires `x`, `y`, and
`anchor` together. Do not combine relative and absolute placement on one
target.

The adapter still composes your condition with Bethesda's own HUD-mode
visibility and HUD opacity. It does not force an engine-hidden element to
display.

Do not attempt to name a timeline clip or arbitrary Bethesda class. Only the
six allowlisted target IDs are accepted.

## Make basic color changes

Do not replace palette references throughout the layout for ordinary theme
changes. Instead:

1. Copy a complete packaged palette XML file.
2. Give the copy a safe filename such as `my-hud.xml`.
3. Keep it directly under `Interface\VenworksCUI\palettes`.
4. Change the desired `value="#RRGGBB"` entries.
5. Point `layout.xml` at `palette="my-hud.xml"`.

For example:

```xml
<color role="accent.primary" value="#19C8FF" />
<color role="panel.background" value="#061722" />
<color role="marker.hostile" value="#FF3C54" />
```

Always begin with a complete shipped palette. The runtime requires every core
semantic role even if the current layout does not visibly use it. Colors must
use six-digit `#RRGGBB`; shorthand and alpha-channel forms are rejected.

See the [palette configuration reference](PALETTE_CONFIGURATION_REFERENCE.md)
before changing typography, strokes, opacities, or faction artwork.

## Troubleshooting

### The custom HUD is replaced by an error panel

Read the title and first detail line. Common categories are:

| Diagnostic | Check |
|---|---|
| `CUI LAYOUT MISSING` | Confirm `Interface\VenworksCUI\layout.xml` exists in the active deployment. |
| `CUI LAYOUT MALFORMED` | Check XML quoting, closing tags, and entity escaping. |
| `CUI LAYOUT INVALID` | Check the named element, attribute, ID, limit, reference, condition, or source. |
| `CUI COMPONENT MISSING` | For a supplied component, confirm the `name` and optional `variant` are supported; for a legacy custom include, confirm its fragment exists directly under `components`. |
| `CUI PALETTE MISSING` | Confirm the root `palette` filename exists directly under `palettes`. |
| `CUI PALETTE INVALID` | Restore all required roles and valid values from a packaged palette. |
| `CUI ASSET LOAD ERROR` | Confirm the named local SVG exists under `Assets` and uses the supported subset. |
| `CUI LAYOUT SECURITY ERROR` | Scaleform denied access to `layout.xml`; check deployment and file access. Unsafe include names are reported as layout-invalid errors instead. |
| `CUI PALETTE SECURITY ERROR` | Remove traversal, subdirectories, URLs, schemes, query strings, or fragments from the palette selection/asset, or check file access. |

The diagnostic may also show `PHASE`, `CHECKPOINT`, and `COMPONENT`. Use the component ID to search `layout.xml`; if the failure belongs to a separately authored legacy include, search its file under `components` as well.

### The theme changed but the old colors remain

- Fully exit and restart Starfield.
- Confirm the deployed `layout.xml`, not only a mod-manager staging copy, names
  the expected palette.
- Check which mod wins `Interface\VenworksCUI\layout.xml` conflicts.
- Check for a personal override that still contains an older layout or palette.

### A moved section does not appear

- Temporarily set `visible="true"` and `visibleWhen="always"`.
- Return `opacity`, `scaleX`, and `scaleY` to `1`.
- Return the SWF component reference to its shipped anchor and offsets.
- Check whether the section was moved outside the 1920-by-1080 design area.
- Check whether the error panel reports a different invalid component that
  prevented the entire custom layer from loading.

### Restore the shipped configuration

Disable or remove your personal override, then reinstall or redeploy the chosen
theme variant. If you edited the active package directly, replace the complete
`Interface\VenworksCUI` directory from your backup or a clean copy of the same
release. Do not combine configuration files from different release versions
unless you have checked their `schemaVersion` and `runtimeVersion` contracts.

## Safe customization checklist

Before considering a customization finished:

- restart Starfield after the final change;
- test normal, aiming, scanner, combat, sneaking, vehicle, and low-health states;
- test the normal HUD and the large-HUD configuration you actually use;
- test at the target aspect ratio and HUD opacity;
- verify Bethesda-owned reticles, crosshairs, enemy health, and prompts still
  follow their original lifecycle;
- keep the diagnostic panel absent during startup and transitions; and
- preserve a clean copy of every customized file outside the managed mod.
