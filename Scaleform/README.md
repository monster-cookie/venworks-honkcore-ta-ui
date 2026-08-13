# Scaleform Sources

This directory contains only Venworks-authored ActionScript, a minimal owned
ABC seed, patch definitions, XML fixtures, build manifests, hashes, and
validation records. It intentionally does not contain Bethesda GFX/SWF files,
full JPEXS XML exports, decompiled Bethesda ActionScript, or extracted game
assets.

The developer scripts in `../Tools` operate on files extracted from a locally
installed copy of Starfield. Temporary XML is written to `Scaleform/.work`,
which is ignored by Git.

## Requirements

- Eclipse Temurin Java 21 (or a compatible Java 21 runtime)
- JPEXS Free Flash Decompiler 26.2.1
- Clean `hudmenu.gfx` and `hudmenu_lrg.gfx` files extracted from
  `Starfield - Interface.ba2`

## Build

From the repository root:

```powershell
./Tools/compileScaleform.ps1 `
  -JavaPath "C:\path\to\java.exe" `
  -JpexsJarPath "C:\path\to\ffdec.jar" `
  -VanillaInterfacePath "C:\path\to\extracted\interface"
```

By default, validated GFX files are copied to the `Interface` directories under
`Staging-VWKS`, `Staging-CF`, `Staging-FC`, and `Staging-TA`. The first
`-OutputDirectory` destination receives the active `layout.xml` and loose SVG
assets; the default first destination is `Staging-VWKS/Interface`. The script
refuses to build from unrecognized vanilla inputs or publish outputs whose
hashes differ from the validation records.

The first output also receives the root-placed production fragments under
`VenworksCUI/components`. Deploy `layout.xml` and that directory together.
Component imports are relative filenames resolved only inside this fixed
directory; nested imports and path traversal are unsupported.

Regenerate the curated built-in icon definitions when their approved Font
Awesome source subset changes:

```powershell
./Tools/generateIconLibrary.ps1 `
  -FontAwesomeRoot "C:\path\to\FontAwesome"
```

Font Awesome source SVGs are not repository content. The generator imports only
the approved 21-icon subset, converts SVG arcs to bounded cubic paths, and
writes deterministic same-domain ActionScript. Normal Scaleform builds use the
committed generated class and do not require Font Awesome. The Venworks logo is
not part of this library; it remains a Venworks-owned loose SVG.

The build injects the Venworks-only ABC seed, exports Bethesda ActionScript only
into ignored temporary storage, verifies the authored `HUDMenu` patch anchors,
and imports the patched document class plus the repository-authored CUI
classes. It confirms that every other exported class remains textually
identical and that the reopened output contains the required layout and
production contracts. Full exported Bethesda classes are never repository
source.

Dynamic CUI text retains Starfield's exported `PromptMessageWidget` symbol and
styles its timeline-created `textField` child. The build verifies that this
vanilla field remains linked to the locale-specific `$MAIN_Font_Bold` outline
font. The repository does not copy or bundle the vanilla symbol or font files.

`decompileScaleform.ps1` is a lower-level helper for producing a temporary
JPEXS XML file during patch development. Its output must not be committed.

Files under `shared/fixtures` are developer test inputs. The Goal 3 component
gallery remains the absolute-positioning compatibility fixture, and the Goal
4A anchor gallery exercises responsive placement. The Goal 4B composition
gallery exercises reusable templates, approved overrides,
vertical/horizontal/grid repeaters, collapsed hidden items, and static state
selection. The Goal 4C condition gallery is the staged `layout.xml`; it
exercises case-insensitive visibility expressions, confirmed HUD providers,
composition visibility, and dynamic repeater-item gates. The separate vanilla
visibility gallery hides only the allowlisted top-center group for an isolated
adapter test. The Goal 4D meter gallery uses two compact top panels to exercise
continuous, rectangle, dot, uniform-triangle, alternating-triangle, vertical,
reverse, and radial renderers without live HUD data. The Goal 4F asset and icon
gallery exercises all 21 built-in icons, packaged SVG,
the Venworks logo SVG, authored paths, masks, and movie-aware allowlisted
embedded symbols. The Goal 4G composite gallery exercises
exercises all four warning severities and button states, a bounded quick bar
with an independently hidden button, and an information panel with metadata,
divider, and meter content. Goal 4G's positive and negative in-game checks are
accepted. The staged `layout.xml` is the Goal 6 production HUD: it hides the
allowlisted vanilla bottom-left and right-meter groups, places the Player Data
scanner at lower-left and the Planet Data/environmental scanner at lower-right,
and moves the temporary weapon/power presentation to upper-right.
Malformed fixtures are
intentionally not well-formed XML, while other negative fixtures may be
schema-valid and rejected by runtime semantic checks. See
`../docs/GOAL_3_COMPONENT_LIBRARY.md`,
`../docs/GOAL_4A_RESPONSIVE_LAYOUT.md`,
`../docs/GOAL_4B_COMPOSITION.md`,
`../docs/GOAL_4C_CONDITIONS.md`,
`../docs/GOAL_4D_METER_RENDERERS.md`,
`../docs/GOAL_4E_ASSET_PRIMITIVES.md`, and
`../docs/GOAL_5_CHRONOMARK_REPLACEMENT.md`, and
`../docs/COMPONENT_CATALOG.md`.

An optional component `anchor` uses one of `top-left`, `top-center`,
`top-right`, `center-left`, `center`, `center-right`, `bottom-left`,
`bottom-center`, or `bottom-right`. Without `anchor`, `x` and `y` retain their
absolute parent-relative meaning. Root anchors use Starfield's
`Extensions.visibleRect` with the four configured safe-area insets; nested
anchors use the parent group's configured bounds.

Templates are declared in `definitions` and contain exactly one primitive-only
root group. `instance`, `repeater`, and `state` elements expand those templates
before ordinary component validation and rendering. The runtime permits only
text, meter-value, and visibility overrides; it does not evaluate scripts,
expressions, interpolation, or arbitrary live bindings in Goal 4B.

Goal 4C adds the bounded `visibleWhen` language described in
`../docs/GOAL_4C_CONDITIONS.md`. Identifiers and keywords are case-insensitive,
underscores are ignored, and provider values remain unknown/hidden until their
first confirmed vanilla update. An optional `vanillaVisibility` section accepts
only the hardcoded target allowlist; configuration cannot provide display paths
or ActionScript method names. Engine-sensitive controls remain blocked.

Goal 4D extends the shared meter-style contract with `segments`, `dots`, and
`radial` renderers. Linear meters accept `right`, `left`, `down`, or `up`
directions. Segmented renderers optionally preserve a partially filled final
segment, and triangle styles may select `uniform` or `alternating` orientation.
Radial styles use a bounded start angle, sweep angle, direction, and stroke
thickness. See `../docs/GOAL_4D_METER_RENDERERS.md` for the exact XML contract.

Goal 4E adds `svg`, `path`, `mask`, `icon`, and `symbol` primitives. Loose SVG
files resolve below `Interface/VenworksCUI/Assets` and preload atomically before
the CUI layer renders. Built-in icons are generated into each HUD movie and
require no runtime file handles. Placement supports `contain`, `cover`,
`stretch`, or `none` plus bounded alignment. The SVG parser accepts only a small
static vector subset, authored paths reject arc commands, masks use
rectangle/ellipse/path geometry, and symbols resolve only through a movie-aware
Bethesda allowlist. Font Awesome arcs are converted to cubic paths by the
developer generator. Direct raster, DDS, and supplemental SWF loading are
unsupported after failed in-game probes. See
`../docs/GOAL_4E_ASSET_PRIMITIVES.md` for the full contract and test fixtures.

Goal 4G adds gamer-facing `button`, `quickBar`, `informationPanel`, and
`warning` composite elements. The composition resolver lowers them to existing
groups, panels, text, icons, dividers, and meters before the ordinary layout
parser validates and creates display objects. Unknown attributes and children
are rejected. Buttons support `normal`, `selected`, `disabled`, and `warning`
states; quick bars accept at most 16 buttons; information panels accept at most
12 metadata rows and 20 total child items; warnings support `info`, `warning`,
`danger`, and `critical` severities. The staged gallery uses fixed values and
does not replace or bind live vanilla HUD data.

Goal 5 adds bounded live values to ordinary `text` and `meter` primitives.
A text keeps its required static `value` as a provider-not-ready fallback and
may add either `source` plus one bounded format, or `valueTemplate` with up to
eight `{source:format}` variables. The complete fallback remains until every
template variable is available. A meter keeps required static `value` and
`max` fallbacks and may add numeric `source` plus optional `maxSource`.
Source identifiers are case-insensitive and ignore underscores, but they must
belong to the hardcoded `hudmenu.gfx` allowlist. Unknown sources and incompatible
source/format combinations fail before the component renders. The runtime does
not accept provider names, member names, scripts, or arbitrary expressions from
configuration.

The current allowlist covers `location.name`, the environmental scanner values,
the production player serial/level/XP/time/health/O2/CO2/Digipick values,
power/boost values, weapon values, and carry/credits values.
See `../docs/GOAL_5_CHRONOMARK_REPLACEMENT.md` for the exact list.
