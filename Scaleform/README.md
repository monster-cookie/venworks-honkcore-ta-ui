# Scaleform Sources

This directory contains only Venworks-authored ActionScript, bounded bootstrap patches, compile-only host externs, XML fixtures, build manifests, hashes, and validation records. It intentionally does not contain Bethesda GFX/SWF files, full JPEXS XML exports, decompiled Bethesda ActionScript, or extracted game assets as tracked repository content.

The developer scripts in `../Tools` operate on files extracted from a locally
installed copy of Starfield. Ignored developer references and temporary build
output are written to `Scaleform/.work`.

## Requirements

- Eclipse Temurin Java 21 (or a compatible Java 21 runtime)
- JPEXS Free Flash Decompiler 26.2.1
- Apache Flex SDK 4.16.1 with exactly one compatible `playerglobal.swc`
- Clean GFX and SWF copies of `hudmenu`, `hudmenu_lrg`, `hudmessagesmenu`, and `hudmessagesmenu_lrg` extracted from `Starfield - Interface.ba2`
- The complete reference-cache command additionally requires every movie and
  provider fixture listed in `reference-cache.xml` from the same vanilla
  Interface extraction

## BGS reference cache

Populate the curated vanilla reference cache when investigating the on-foot
HUD, Watch/Chronomark, recurring provider consumers, or Ship HUD:

```powershell
./Tools/cacheBgsScaleform.ps1 `
  -JavaPath "C:\path\to\java.exe" `
  -JpexsJarPath "C:\path\to\ffdec.jar" `
  -VanillaInterfacePath "C:\path\to\extracted\interface"
```

The versioned `reference-cache.xml` manifest limits the cache to the approved
movies and provider fixtures. Each movie retains stable `movie.xml`, `scripts`,
and hash metadata below `Scaleform/.work/bgs-decompiled/movies`; provider JSON
fixtures are mirrored below `Scaleform/.work/bgs-decompiled/files`. An entry is
reused only when its source SHA-256, JPEXS JAR SHA-256, metadata, XML, and script
directory remain valid. `-ForceRefresh` regenerates the curated entries.

The complete cache is local, ignored, and regenerable. Do not copy its Bethesda
content into tracked source or staging directories. The normal HUD build uses
the cached vanilla HUD XML but continues to create temporary patched and
reopened exports for its full validation cycle.

## Build

From the repository root:

```powershell
./Tools/buildVariant.ps1 `
  -JavaPath "C:\path\to\java.exe" `
  -JpexsJarPath "C:\path\to\ffdec.jar" `
  -VanillaInterfacePath "C:\path\to\extracted\interface"
```

`buildVariant.ps1` independently compiles each selected host manifest profile from clean GFX and SWF inputs, compiles shared HUD-message GFX/SWF pairs only for profiles that declare them, and compiles each selected standalone CUI source profile once. The deployment mapping stages each native GFX output at its `.gfx` path and each independently compiled CWS output at its `.swf` path. The five player-facing variants each receive nine movies from `Scaleform/variants/<KEY>/build.psd1`: four base HUD paths, four HUD-message movies, and `venworkscui.swf`. The four themed profiles share the production layout, components, SVG assets, external palettes, and standalone CUI hash. Minimalist uses its own faction-free layout, six-component inventory, literal Starfield colors, and profile-specific standalone CUI hash with no external SVG, palette, or DDS files. PS5 Debug selects four unique host manifests that patch a lifecycle pane into Bethesda's existing single ABC and declares no HUD-message, CUI, or external configuration payload. Omitting `-VariantKeys` selects all six release variants. Pass one key, such as `-VariantKeys PS5DBG`, or an array, such as `-VariantKeys @("TA", "PS5DBG")`, to select a subset. The singular `-VariantKey` name remains a compatibility alias. Use `-Committed` to regenerate tracked staging directories without Vortex Junctions.

`compileScaleform.ps1` is the lower-level HUD host compiler. Each invocation preserves the build input container contract: `.gfx` inputs must carry a `GFX` signature and generate GFX outputs, while `.swf` inputs must carry a `CWS` signature and generate CWS outputs. Its manifest mode selects a bounded host patch, and every mode patches Bethesda's existing HUD ABC without adding another `DoABC` tag. The shared mode installs the auxiliary loader; the PS5 Debug mode installs only the native lifecycle/error pane in the existing `HUDMenu` class. The variant builder, not the compiler, applies the explicit deployment mapping that preserves each output's native extension and container. `compileScaleformAuxiliary.ps1` compiles the complete CUI runtime into one deterministic CWS auxiliary movie using Apache Flex, compile-only Bethesda externs, and JPEXS normalization/reopen validation. The auxiliary manifest fixes the movie at 1920 by 1080, 30 fps, and one frame, matching Bethesda's HUD stage metadata; the `_lrg` host remains 1920 by 1080 rather than using an ultrawide stage. Neither compiler mirrors variant configuration or runs Archive2. Deploy each CUI profile's generated `layout.xml` and component directory together. Component imports are relative filenames resolved only inside this fixed directory; nested imports and path traversal are unsupported. The production payload includes `quest-tracker.xml`, whose upper-left panel joins directly beneath the faction and contact-radar panels, binds the existing `HudCompassData` tracked-objective text, and remains independent of scanner and aiming state while leaving its text field blank when the objective is empty. The objective resolver is independent of floating-marker visibility. Vanilla quest markers, icons, arrows, distance labels, and temporary quest notifications remain under Bethesda ownership. `HUDMessagesMenu` is patched at its `MonocleMenu_Opened` handler so opening the on-foot scanner keeps only the always-up objective list hidden; ship-scanner behavior is unchanged. The HUDMenu-owned Watch/environment cluster is configured with `visibleWhen="never"`, which applies real display visibility without positional hiding. Bethesda's original Monocle movies retain scanner input, labels, and survey placement. No HUD-wide frame callback or cross-movie display lookup is used.

The auxiliary compiler records two independent SHA-256 contracts: the final movie bytes and the compiled class inventory. It also embeds the current transformed-source and class-inventory fingerprints into `VenworksCUIEntrypoint`; verification recomputes both from the current manifest, externs, generated Scaleform stub, entrypoint, and profiled ActionScript. A source or definition change therefore cannot pass by leaving an older auxiliary SWF and its old expected movie hash in place.

`createPackages.ps1` resolves each selected variant's complete deployment profile and requires that profile's exact movie inventory, production hashes, and declared native GFX/CWS signatures before it deletes or writes any archive. This enforces nine movies for every player-facing profile and four one-ABC host movies for PS5 Debug, while blocking the local marker probe, stale output, wrong containers, and incomplete mappings from every selected platform archive path.

Regenerate the curated built-in icon definitions when their approved Font
Awesome source subset changes:

```powershell
./Tools/generateIconLibrary.ps1 `
  -FontAwesomeRoot "C:\path\to\FontAwesome"
```

Font Awesome source SVGs are not repository content. The generator imports only
the approved 21-icon subset, converts SVG arcs to bounded cubic paths, and
writes deterministic same-domain ActionScript. Normal Scaleform builds use the
committed generated class and do not require Font Awesome. The Venworks,
Freestar Collective, Crimson Fleet, and Trackers Alliance logos are not part of
this library; they remain authored loose SVG assets. Their raster and DDS visual
references are not repository content.

The HUD bootstrap build reads vanilla XML from the ignored reference cache, exports patched and reopened ActionScript only into ignored temporary storage, verifies the authored `HUDMenu` patch anchors, and imports only the patched Bethesda document class back into its existing ABC. The HUD constructor starts the guarded loader, `Event.INIT` initializes the auxiliary bridge against the host HUD, and `Event.COMPLETE` attaches the loaded auxiliary root directly to that HUD before replaying the cached visibility state. Teardown removes both listeners, disposes the bridge, removes the direct child, and unloads idempotently. Bootstrap diagnostics use Starfield's embedded `$MAIN_Font_Bold` format so missing or rejected auxiliary movies produce readable error codes. The auxiliary build compiles the repository-authored CUI classes and `VenworksCUIEntrypoint` into one child-domain ABC; the six Bethesda API stubs and generated Scaleform extension stub are external libraries and must not appear as definitions in the output. A separate bounded override pass patches only the normal and large `HUDMessagesMenu` document classes at their exact vanilla anchor. Every pass confirms that unrelated exported Bethesda classes remain textually identical and that reopened outputs contain the required contracts. Full exported Bethesda classes are never repository source.

Root layouts may select one optional, version-1 palette by filename with the
`palette` attribute. The runtime loads that file only from
`Interface/VenworksCUI/palettes`, validates its bounded semantic color,
typography, opacity, stroke, and asset roles, and resolves all `@palette.*`
references after component imports and bounded composite/template/repeater
lowering but before ordinary layout validation. Composite output uses the same
semantic color, typography, opacity, stroke, and asset roles as direct
primitives. Fragments may consume those references but cannot select or import
a palette themselves. Existing layouts containing only literal values retain
their original composite styling. The production layout selects `venworks.xml`
by default, and the build deploys `venworks.xml`, `crimson-fleet.xml`,
`freestar-collective.xml`, `trackers-alliance.xml`, and `starfield.xml` under
the fixed palette directory in all four themed staging variants. The Starfield palette
preserves the neutral white-and-slate presentation, while Crimson Fleet and
Trackers Alliance use their faction-specific dark-red-and-white identities.
Palette selection occurs when the HUD starts; live theme switching is not part
of the runtime contract.

Dynamic CUI text retains Starfield's exported `PromptMessageWidget` symbol and
styles its timeline-created `textField` child. The build verifies that this
vanilla field remains linked to the locale-specific `$MAIN_Font_Bold` outline
font. The repository does not copy or bundle the vanilla symbol or font files.

`decompileScaleform.ps1` remains a lower-level helper for producing a one-off
JPEXS XML file during patch development. Its output must not be committed.

Files under `shared/fixtures` are developer test inputs. The Goal 3 component
gallery remains the absolute-positioning compatibility fixture, and the Goal
4A anchor gallery exercises responsive placement. The Goal 4B composition
gallery exercises reusable templates, approved overrides,
vertical/horizontal/grid repeaters, collapsed hidden items, and static state
selection. The Goal 4C condition gallery is the staged `layout.xml`; it
exercises case-insensitive visibility expressions, confirmed HUD providers,
composition visibility, and dynamic repeater-item gates. The separate vanilla
visibility gallery hides the allowlisted top-center group and exercises bounded
safe-area placement of the complete bottom-left group for an isolated adapter
test. The Goal 4D meter gallery uses two compact top panels to exercise
continuous, rectangle, dot, uniform-triangle, alternating-triangle, vertical,
reverse, and radial renderers without live HUD data. The Goal 4F asset and icon
gallery exercises all 21 built-in icons, packaged SVG,
the Venworks logo SVG, authored paths, masks, and movie-aware allowlisted
embedded symbols. The Goal 4G composite gallery exercises all four warning
severities and button states, a bounded quick bar
with an independently hidden button, and an information panel with metadata,
divider, and meter content. Goal 4G's positive and negative in-game checks are
accepted. The palette contract fixtures exercise schema versioning, duplicate
roles, bounded values, safe palette selection, unknown references, category
compatibility, and every supported semantic reference family. The four shipped
example palettes exercise the complete required semantic role set while
preserving shared warning-state meanings. The palette-composite gallery
additionally runs palette-backed icons and generated semantic styling through
every bounded composite family. The staged `layout.xml` is the Goal 6 production HUD: it hides the
diagnostic vanilla bottom-left Chronomark and right-meter group, places the
split-tab Player Data scanner at lower-left and the split-tab Planet
Data/environmental scanner at lower-right, and places the passive Goal 7
tactical loadout ribbon at upper-right. The ribbon begins at the physical right
edge, runs from the upper helmet brow to the exact top of Planet Data without
extending behind it, widens through the middle to contain the three live
contacts, and curves inward only at its bottom return to meet the existing
Planet Data width. Its single translucent silhouette contains every contact
without a cyan outer arc or decorative guide. It orders favorite
contacts 1-5 around gold-outlined live weapon/explosive/power contacts and then
favorites 6-12, with mirrored outer endpoints and evenly stepped inner rows.
Favorite hotkeys resolve through Bethesda's current PC/controller control map,
and a magenta chevron marks an exact live weapon or power match. Favorite rows
put hotkey/icon/name on line one and reserve 20 design units on each of the name
and detail lines for meaningful ammunition or stack counts; the live explosive
provider cannot authoritatively
identify an exact grenade/mine favorite, so those favorite rows remain neutral.
Each lower scanner uses one continuous rounded path with separate title and
clock tabs around a wide transparent center notch. Mirrored overflow rails extend through the nearest
side and bottom screen margins so both scanners appear integrated into the
helmet edge without moving their accepted content geometry. The vehicle-only
exit label and Bethesda hold glyph are centered in the fixed lower helmet seal
instead of extending the tactical ribbon behind Planet Data.
Malformed fixtures are intentionally not well-formed XML, while other negative
fixtures may be schema-valid and rejected by runtime semantic checks. See the
technical component and binding contracts in
`../docs/COMPONENT_CATALOG.md`. Feature design, implementation history, and
acceptance criteria are maintained in the Venworks Codecks workspace.

An optional component `anchor` uses one of `top-left`, `top-center`,
`top-right`, `center-left`, `center`, `center-right`, `bottom-left`,
`bottom-center`, or `bottom-right`. Without `anchor`, `x` and `y` retain their
absolute parent-relative meaning. Root anchors use Starfield's
`Extensions.visibleRect` with the four configured safe-area insets; nested
anchors use the parent group's configured bounds.

An allowlisted `vanillaVisibility` target may also provide `x`, `y`, and
`anchor` together. That bounded placement uses the same visible-rectangle and
safe-area convention while moving the existing Bethesda-owned display object;
it does not clone the object, expose a display path, or override the object's
provider-driven `visible` state. Alternatively, `offsetX` and `offsetY` may be
provided together to move the target relative to its original Bethesda-authored
position. Relative offsets cannot be mixed with `x`, `y`, and `anchor`.

Templates are declared in `definitions` and contain exactly one primitive-only
root group. `instance`, `repeater`, and `state` elements expand those templates
before ordinary component validation and rendering. The runtime permits only
text, meter-value, and visibility overrides; it does not evaluate scripts,
expressions, interpolation, or arbitrary live bindings in Goal 4B.

Goal 4C adds the bounded `visibleWhen` language cataloged in
`../docs/COMPONENT_CATALOG.md`. Identifiers and keywords are case-insensitive,
underscores are ignored, and provider values remain unknown/hidden until their
first confirmed vanilla update. An optional `vanillaVisibility` section accepts
only the hardcoded target allowlist; configuration cannot provide display paths
or ActionScript method names. Engine-sensitive controls remain blocked.

Goal 4D extends the shared meter-style contract with `segments`, `dots`, and
`radial` renderers. Linear meters accept `right`, `left`, `down`, or `up`
directions. Segmented renderers optionally preserve a partially filled final
segment, and triangle styles may select `uniform` or `alternating` orientation.
Radial styles use a bounded start angle, sweep angle, direction, and stroke
thickness. See `../docs/COMPONENT_CATALOG.md` for the technical component
contract.

Goal 4E adds `svg`, `path`, `mask`, `icon`, and `symbol` primitives. Loose SVG
files resolve below `Interface/VenworksCUI/Assets` and preload atomically before
the CUI layer renders. Built-in icons are generated into each HUD movie and
require no runtime file handles. Placement supports `contain`, `cover`,
`stretch`, or `none` plus bounded alignment. The SVG parser accepts only a small
static vector subset, authored paths reject arc commands, masks use
rectangle/ellipse/path geometry, and symbols resolve only through a movie-aware
Bethesda allowlist. Font Awesome arcs are converted to cubic paths by the
developer generator. Direct raster, DDS, and supplemental SWF loading are
unsupported after failed in-game probes. See `../docs/COMPONENT_CATALOG.md` for
the technical component contract.

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
power/boost values, weapon values, and carry/credits values. See
`../docs/COMPONENT_CATALOG.md` for the technical binding catalog.
