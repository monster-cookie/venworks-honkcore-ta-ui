# Venworks CUI Component Catalog

Date: 2026-08-17

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

- **Complete:** implemented and accepted for the documented component scope.
- **Implemented:** available in the current runtime and schema, with remaining
  documented acceptance work.
- **Next:** expected in the next component-library or layout goal.
- **Future:** required before the corresponding UI surface can ship.
- **Research:** visible requirement identified; exact vanilla owner or provider
  contract still needs discovery.

## Foundation primitives

### Layout composition

Root layouts may place reusable external fragments with bounded imports:

```xml
<includes>
  <include id="player-status-scanner" src="player-status-scanner.xml"
           x="-39" y="11" anchor="bottom-left"
           visible="true" visibleWhen="always" z="100" />
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
| Vanilla visibility adapter | Implemented | Compose real display visibility and optional bounded absolute or original-position-relative placement only for explicitly mapped whole default UI pieces while preserving vanilla providers and lifecycle behavior. |

Goal 4A keeps a fixed 1920-by-1080 design coordinate system and relies on
Starfield's `Extensions.visibleRect` for viewport boundaries. It does not
apply nonuniform screen scaling. Runtime acceptance at standard and ultrawide
aspect ratios remains required before the capability is used by a live HUD
surface.

| Component | Status | Required behavior |
|---|---|---|
| Group | Implemented | Nest children and apply bounds, transforms, opacity, visibility, and z-order. |
| Text | Implemented | Style a bounded, timeline-linked Starfield text field with configurable size, color, weight, and alignment. Static text requires a nonempty value; source- or template-bound text may use an empty fallback until live data publishes. |
| Panel | Implemented | Render a rectangular fill and stroke for cards, readouts, warnings, and composite backgrounds. |
| Shape | Implemented | Render rectangle and ellipse primitives with independent fill and stroke styling. |
| Divider | Implemented | Render configurable horizontal, vertical, or diagonal line geometry. |
| Error panel | Implemented | Show actionable load/schema errors in the upper center/right region and remain hidden after a valid load. |
| Repeater/list | Implemented | Lay out a bounded fixed collection vertically, horizontally, or in a grid with spacing and item limits. |
| State container | Implemented | Select one fixed configuration state without allowing arbitrary expressions or method calls. |
| Mask/clip | Complete | Bound one or more children to rectangle, ellipse, or approved path geometry, including nested masks. |

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
| Continuous bar | Complete | Health, oxygen, boost, enemy health, ship hull/shields, and other linear values; supports four fill directions. |
| Stacked triangles | Complete | Uniform or alternating-orientation segments, four fill directions, and optional partial final-segment fill. |
| Segmented rectangles | Complete | Discrete or visually stepped meters with whole or partial final segments. |
| Dots/circles | Complete | Compact counters and alternate meter styling with whole or partial final dots. |
| Chevrons/notches | Future | Directional or technical segmented meters. |
| Radial/circular arc | Complete | Bounded continuous clockwise/counterclockwise arcs for oxygen/CO2, cooldown, progress, and compact gauges. |
| Image-masked meter | Future | Theme-authored fills bounded by an approved image or vector mask. |
| Bipolar/center-origin bar | Future | Signed values or opposing states where the neutral point is centered. |

The reusable meter family is expected to cover at least these visible surfaces:
player health, oxygen, CO2, boost, experience or
progress, ship hull, ship shields, ship boost, individual weapon groups, and
power-allocation levels. Each surface still requires an independently verified
vanilla owner and provider contract.

## Vector, icon, and media components

| Component | Status | Required behavior |
|---|---|---|
| Bethesda embedded symbol | Complete | Reference a semantic name from a movie-aware hardcoded allowlist of symbols embedded in the owning vanilla movie; mappings are `environment-alert`, `quest-door-marker`, `boost-fill`, and noninteractive `vehicle-exit-prompt`. The vehicle mapping extracts Bethesda's initialized `GetUpButton_mc` hold-button child and bounds its presentation to the union of the keyboard and controller glyph children, so the full HUD timeline and the hold-button label area are never fitted into the CUI box. The production layout composes that live mapped glyph with Bethesda's localized `$EXIT HOLD` label in an `inVehicle`-conditioned group centered in the lower helmet seal. |
| Built-in icon | Complete | Reference one of 21 generated semantic icons compiled directly into each HUD movie; supports tint, fit, and alignment without a runtime asset handle. |
| Supplemental symbol library | Retired | Starfield raised Error #1034 across the child-domain SWF compatibility attempts; external SWF libraries are no longer loaded. |
| SVG path | Complete | Render a bounded authored path with fill, stroke, transform, and view box; arc commands are rejected. |
| SVG asset | Complete | Load and validate a restricted local SVG through the fixed `Interface/VenworksCUI/Assets` root; no network URLs, scripts, text, or external references. |
| Direct raster/DDS image | Unsupported | PNG, JPEG, and DDS probes were found at their loose paths but rejected by Starfield Scaleform; use loose SVG or a built-in icon. |
| Curated Font Awesome icon | Complete | Generate only the approved 21-icon subset into committed ActionScript; Font Awesome source SVGs remain developer inputs and are not committed. |

The icon generator receives the local Font Awesome Pro root through an explicit
parameter. Its machine-specific path is never recorded. It converts source arcs
to cubic paths and writes a deterministic same-domain library containing only
the approved icon subset; source SVGs are not committed.

## Composite components

Composite components are authored from primitives and expose a smaller,
gamer-facing configuration surface.

| Composite | Status | Composition and behavior |
|---|---|---|
| Button | Complete | Panel/shape, icon, label, key hint, enabled state, selected state, and cooldown/quantity overlay. |
| Quick bar | Complete | Compose up to 16 independently visible buttons through the bounded Goal 4G composite contract. |
| Tactical equipment rail | Complete | Fifteen passive contacts: twelve remapping-aware FavoritesData readouts wrapped around independently live weapon, explosive, and power contacts in the center of the ribbon. Contacts do not own input or present themselves as buttons. Runtime visual and behavior acceptance completed on 2026-08-15. |
| Compass | Implemented | Line/divider, heading label, direction ticks, markers, and optional background; normal-view acceptance is complete and large-HUD acceptance remains pending. |
| Minimap/radar | Implemented | Bounded acquired-threat radar, player marker, verified contact types, range rings, and clip behavior; final startup and live-transition acceptance remains pending. |
| Information panel | Complete | Panel, title, key/value text, dividers, optional scroll/overflow indicator, and status accents. |
| Notification/toast | Future | Panel, icon, primary/secondary text, priority, duration, and bounded entrance/exit effects. |
| Warning panel | Complete | Severity color, icon, title, detail, and visibility/state rules. |
| Item/ammo readout | Future | Weapon/item icon, amount, reserve amount, state color, and optional meter. |
| Status-effect row | Implemented | Bounded active-effects presentation using verified HUD data; large-HUD acceptance remains pending. |
| Scanner overlay | Implemented | Scanner-only heading banner, 5-by-5 square-to-dot radial pulse, and up to five validated forward contacts. It preserves Bethesda's reticle/crosshair and uses deterministic type/handle codenames instead of names or random data. |
| Reticle/crosshair | Vanilla-owned; not configurable | Bethesda retains the complete visual and lifecycle owner; proven crosshair data remains condition input only. |

The Goal 7 equipment rail is intentionally passive. Favorites Menu remains the
only owner of favorite assignment and input. Contacts 1-12 preserve the latest
twelve-entry snapshot and resolve `Quickkey1..12` through Bethesda's
`ButtonKeyHelper`, while contacts 13-15 remain independently live. Exact
weapon/power name matches may accent a favorite contact; menu cursor state and
stale equipped flags are not treated as active state. The live explosive
provider supplies only generic category and count, so exact favorite
grenade/mine highlighting is unsupported rather than heuristically inferred.

## Player HUD coverage targets

- health and damage state;
- oxygen/CO2 and environmental state;
- boost/jetpack;
- weapon, ammunition, explosives, and inventory/readout state;
- compass, quest markers, and location information;
- enemy health and legendary/state indicators remain exclusively vanilla-owned
  and are not CUI coverage targets;
- stealth/detection, hit indicators, and reticles remain exclusively
  vanilla-owned and are not CUI coverage targets;
- scanner overlays and interaction prompts;
- notifications, warnings, mission updates, and status effects;
- quick-access or ability buttons where supported by vanilla providers.

The generic meter primitives do not authorize replacing Bethesda's enemy health
or legendary/state presentation. HONKCORE demonstrated that customizing those
surfaces can break legendary enemy hit bars, so the complete vanilla owner and
its lifecycle remain untouched.

Stealth/detection presentation, hit/kill/damage indicators, weapon reticles,
and crosshairs also remain exclusively vanilla-owned. Changing these
engine-controlled surfaces can cause lifecycle problems; although crosshair
switching may be technically safe, the vanilla presentation is adequate and a
custom replacement provides no meaningful benefit. Proven crosshair, sneaking,
and combat fields remain available as read-only condition inputs for the player
threat meter and approved layout choreography. The player threat meter and
player status effects remain approved custom surfaces.

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

## Goal 4 completed component-library gates

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

Goal 4F completes the 21-icon allowlist and deterministic same-domain icon
generation. Goal 4G completes the bounded button, quick-bar, information-panel,
and warning composites. Their positive and negative in-game gallery checks are
accepted.

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
The production layout uses the explosive fields for grenade/mine presentation
and owns a bottom-center `inVehicle`-conditioned vehicle prompt. The prompt
extracts the initialized `GetUpButton_mc` child from a temporary embedded
Bethesda vehicle control, then fits only that bounded hold button. It disables
mouse interaction and receives no routed user events. The hidden vanilla
`HUDVehicle_mc` remains alive and exclusively processes vehicle-exit input.

## Goal 6 environmental scanner bindings

Goal 6 adds an allowlisted `EnvironmentEffectsData` adapter and a compact,
persistent environmental readout. The following sources are available to
ordinary text templates or meters after their owning provider publishes:

| Source | Kind | Confirmed meaning |
| --- | --- | --- |
| `environment.protectionLevel` | Number `0..1` | Clamped Bethesda `fSoakDamagePct`; `1` is ready and `0` is exhausted. |
| `environment.protectionPercentage` | Number `0..100` | Display scaling of the same normalized protection value. |
| `environment.protectionStatus` | String | `PROTECTION READY`, `PROTECTION PARTIAL`, or `PROTECTION DEPLETED`, derived only from the normalized value and Bethesda full-soak flag. |
| `environment.fullSoakAlertCandidate` | Boolean | Bethesda `bShouldPlayAlertAtFullSoak`; retained for diagnostics. |
| `environment.hazard.airWaterLevel` | Number `0` or `1` | Presence of `HazardEffect_Airborne`; runtime confirmed both unsafe biological water and airborne flora use this category. |
| `environment.hazard.thermalLevel` | Number `0` or `1` | Presence of `HazardEffect_Thermal`. |
| `environment.hazard.corrosiveLevel` | Number `0` or `1` | Presence of `HazardEffect_Corrosive`. |
| `environment.hazard.radiationLevel` | Number `0` or `1` | Presence of `HazardEffect_Radiation`. |
| `environment.hazard.airWaterExposureLevel` | Number `0..1` | Modeled relative load for an active Airborne category; `0` when absent. |
| `environment.hazard.thermalExposureLevel` | Number `0..1` | Modeled relative load for an active Thermal category; `0` when absent. |
| `environment.hazard.corrosiveExposureLevel` | Number `0..1` | Modeled relative load for an active Corrosive category; `0` when absent. |
| `environment.hazard.radiationExposureLevel` | Number `0..1` | Modeled relative load for an active Radiation category; `0` when absent. |
| Corresponding `...Status` sources | String | Provider waiting, clear, or detected text for the four categories. |

The four `...Level` values are categorical activity gates, not magnitudes. The
four `...ExposureLevel` values are explicitly modeled display values rather
than Bethesda telemetry or physical measurements. Inactive channels are
exactly `0`. Each active channel uses an independent slowly changing random
value and the bounded model `clamp(0.05 + 0.10 * random + 0.25 * activity +
0.70 * depletion, 0, 1)`. `depletion` is `1 - protection`; `activity` is a
gradual envelope driven only by sustained downward changes in the normalized
player-O2 reserve represented by the pink HUD meter. Boost charge and
atmospheric O2 do not contribute. An active category snaps to `1` while
protection is `0` and Bethesda's `bShouldPlayAlertAtFullSoak` is true. This
environmental critical override does not inspect generic player-health loss.

The production fragment stacks a confirmed `PLANET DATA` context section above
the suit-exposure section. It reuses `location.name`,
`environment.localTime`, `environment.oxygenPercentage`,
`environment.temperature`, and `environment.gravity`; those values are no
longer duplicated by the lower-left environment fragment. Local temperature
can provide hot/cold context but is not Thermal severity. O2 `0%` cannot
distinguish vacuum from an oxygen-free atmosphere. No
allowlisted source currently claims CO2 composition, atmospheric pressure,
vacuum, physical hazard units, per-channel Bethesda severity, or an aggregate
environmental Threat Index. Runtime testing found no walking or ground-vehicle
speed value in the bounded HUD provider probe. The temporary scanner-only
calibration strip established current player-O2 reserve, downward-drain
detection, the gradual O2 activity envelope, protection depletion, and the four
modeled channel loads; it is not included in the accepted production layout.

`LocalEnvData_Frequent.fGalacticStandardTime` is a decimal-hours universal-time
value confirmed by the bounded HUD runtime probe and a Character Menu comparison.
The production data context divides it by 24 before the shared day-fraction
clock formatter. `fLocalPlanetTime` is already a normalized local-day fraction
and is not converted.

## Goal 6 player scanner bindings

The 360-design-unit lower-left Player Data fragment uses only runtime-confirmed
HUD-lifetime values. It is anchored 25 design units from the physical left and
bottom edges. Its production sources are:

| Source | Kind | Confirmed meaning |
| --- | --- | --- |
| `player.serial` | String | Display-only deterministic 8-4-6 serial derived from the exact character name. |
| `player.level` | Number | `PlayerData.uLevel`. |
| `player.xpPercentage` | Number `0..100` | Bounded ratio of `fLevelXP` to `fNextLevelXP`. |
| `player.universalTime` | Number | `LocalEnvData_Frequent.fGalacticStandardTime / 24`, normalized for the shared 24-hour clock formatter. |
| `player.healthPercentage` | Number `0..100` | Bounded health ratio. |
| `player.oxygenPercentage` | Number `0..100` | Bounded remaining O2 ratio. |
| `player.carbonDioxidePercentage` | Number `0..100` | Bounded CO2 ratio using the shared O2/CO2 maximum. |
| `player.digipicks` | Number | Count for exact base form `00000A:Starfield.esm`; shown only when the inventory array is available. |
| `boost.percentage` | Number `0..100` | Normalized jetpack charge. |
| `carry.percentage` | Number `0..100` | Bounded current/max encumbrance ratio; full at or above capacity. |

O2 and CO2 use one visual track with a transparent-empty red CO2 overlay. All
five player tracks use the same bounded percentage contract.

## Goal 7 tactical equipment rail

Goal 7 retires the temporary FavoritesData diagnostic and the standalone
upper-right weapon fragment. The production 720-by-747 group offsets its
top-right safe-area anchor to land on the physical right edge and terminates
exactly where Planet Data begins, so the separately authored surfaces meet
without a hidden underlap. A compact curved path at no more than 24 percent
opacity widens through its middle to contain live contacts 13-15, then curves
inward only at its bottom return to meet the existing Planet Data width. It
tightly contains contacts in the exact visual order 1-5, 13-15, then
6-12 without an opaque rectangular backing, cyan outer arc, decorative guide,
or join seams. Favorite contacts 1 and 12 share an exact mirrored endpoint, and
the upper and lower favorite rows step evenly toward the center live-contact
group.
Contact 13 uses live WeaponData and equipped-ammunition data; contact 14 derives
`NO THROWABLE`, `GRENADE`, or `MINE` plus count from the live explosive fields;
contact 15 uses the live mapped power name.

Favorite rows show the current PC/controller/remapped Quickkey resolved from
`ControlMapData.vMappedEvents`, generic icon, and name on their first line. A
dedicated second detail line is blank unless meaningful ammunition or stack
quantity exists, and then it shows only the compact count. Both the name and
detail fields are 20 design units high. A magenta chevron marks an exact active
weapon or power favorite, while
live contacts 13-15 use strong gold outlines. Redundant item, power, and
weapon-type labels and fake 13-15 key numbers are not authored.

Favorite weapon and power accents require an exact normalized match to the
independently live name. This permits an ammo-less active melee entry to change
from the generic item presentation to the weapon presentation without treating
every ammo-less favorite as a weapon. Bethesda key
`ArtifactPower_ElementalBlast` maps to `Elemental Pull` in both the data and
condition contexts. `uStartingSelection`, `bIsEquipped`, menu-owned image
buffers, and unproven slot indices are not production inputs. The ribbon
contains no actions or input handlers. The vehicle-exit prompt is independently
centered in the fixed lower helmet seal and remains visible only in a vehicle.
Because no confirmed provider correlates the generic live explosive category
to an exact favorite, grenade and mine favorite rows remain neutral; this
limitation must be included in end-user documentation.

## Goal 8 contact radar

`contactRadar` is a bounded, passive HUDMenu component driven exclusively by
`HudCompassData`. It places contacts with Bethesda's Watch heading transform,
the marker's `fDistanceToPlayer`, fixed `1.0` marker scale, and bounded distance
alpha. A fixed 200-provider-unit range maps contacts proportionally from the
player center to subdued 50-, 100-, 150-, and 200-unit circles; invalid or
over-range contacts fail closed. Bethesda's `bIsNear` is no longer used for
placement, and `fDistanceScale` remains deliberately ignored because unbounded
transition values are unsafe for a pooled vector marker. Runtime later proved that fixed
scale alone did not eliminate the kill-event black surface. The component
therefore hides a selected pooled marker before evaluation and assigns display
coordinates and alpha only after distance, heading, player direction,
intermediate vectors, and final coordinates are finite. The component owns a
fixed pool of 32 display objects and creates no input handlers or persistent
state.

The production semantic mapping is deliberately narrow: all
`aEnemyMarkers` entries are red dots; general marker type 8 companions are white
dots; type 10 parked ships, type 13 parked-vehicle positions, and formal type 14
vehicles are white squares; and the player is a fixed purple center square.
Bethesda's decompiled enum names type 13 `MIT_MARKER_POSITION`, but runtime
showed that it appears when the player exits the vehicle and disappears while
the player occupies it. Type 10 was delivered beside the parked ship. Formal
type 14 delivery remains unobserved. Locations, mission markers, unknown types,
and aggressive/defensive/passive distinctions are not rendered or inferred.
The 200-unit scale uses Bethesda's provider value and does not claim a real-world
unit such as meters.

Runtime establishes `aEnemyMarkers` as an engine-filtered acquired-hostile
channel, not an inventory of nearby life forms. Neutral creatures and harmless
critters are absent. Potentially hostile creatures generally enter only after
Bethesda's detection or hostility gate accepts them; once acquired, contacts
remain correctly ranged while the player retreats and production rendering
hides them beyond 200 provider units. The component's range therefore governs
placement and acquired-contact retention, not AI detection or initial discovery.
Attacking a neutral creature is expected to make it eligible after hostility
changes, but that transition remains unconfirmed.

Runtime Game Setting probes found `fPerceptionCompassBase = 10000`,
`fPerceptionCompassMult = 3`, and tested player `Perception = 7`. A base of `10`
restricted presentation to point-blank range, while larger values did not expose
unaware actors earlier and `10000` versus `20000` did not change acquired-hostile
retention. Production therefore preserves the game's defaults and adds no GMST,
native provider, SFSE component, or synthetic position source. The unrelated
AVIF `MapMarkerMaxCompassDistanceMult` governs ordinary map-marker behavior and
is not an enemy-channel input.

Future player documentation must call the component a
**200-provider-unit acquired-threat radar**, state that it is not a life-form
detector, and explain that its circles range only contacts delivered by
HUDMenu's persistent compass data.

The retired top-center probe reported the complete general-marker count and
unique numeric marker types as `G:<count> TYPES:<types>`. It established the
10/13 runtime mapping without adding another provider, recursive field dumping,
input, callbacks, persistence, native code, or SFSE behavior. Its panel, binding,
and count/type formatting are absent from the production HUD; the existing
`HudCompassData` subscription remains solely to deliver radar data.

The adjacent `faction-display` fragment owns the Venworks SVG crest and its
panel separately from `contact-radar`. Each has an independent layout include,
so a theme or player configuration can hide the faction display while leaving
the passive radar active. The crest identifies the configured theme, not the
player's live faction membership. Branding text embedded in the owned SVG is
the sole Venworks label; the layout must not add a duplicate text label.

The contact radar is also independent from Bethesda's Watch. It remains on the
owned `VenworksCUIComponentLayer`, uses its own fixed-size `Shape` pool, and only
shares the read-only `HudCompassData` provider. Vanilla visibility targets use
real display visibility composed from Bethesda `HudModeData` and the configured
`visibleWhen` expression. Consequently a false expression removes the target
tree from rendering instead of leaving it active at alpha zero. A target may use
paired `offsetX` and `offsetY` values to retain its original Bethesda-authored
position plus a design-space offset; relative offsets cannot be mixed with the
absolute `x`, `y`, and `anchor` placement contract. Neither Watch state changes
radar ownership or visibility, and the separate faction-display include can be
disabled independently.

## Card 142 persistent quest tracker

The `quest-tracker` fragment is an independent noninteractive 447-by-90 panel
joined directly below the upper-left faction and contact-radar panels. The three
panels preserve their matching 18-design-unit corner locations with rounded
quadratic returns instead of straight bevels. Its multiline, word-wrapped text
binds to `quest.objective`. The include uses `always`, so the panel remains
present with a blank text field when no active tracked-objective text exists.
It has no scanner, aiming, combat, or view-mode condition and therefore remains
part of normal, aiming, and scanner HUD compositions.

The Bethesda-owned `bottomLeft` survey group remains independent of the quest
component. It is configured with `visibleWhen="inScanner"`, `offsetX="0"`, and
`offsetY="266"`, placing its survey window about 125 design units above Player
Data while retaining Bethesda's original transform, provider processing, and
timeline animation. Outside scanner mode the whole group is set to
`visible = false`; alpha is not used as the hiding contract.

The value is derived from the existing read-only
`HudCompassData.aMissionMarkers` array. Resolution prefers the non-empty
`strText` entry whose `bShouldShowText` flag matches vanilla's selected
objective and otherwise uses the first non-empty mission-marker text. It does
not depend on `bFloatingMarkerVisible`, keeping the tracked objective available
when Bethesda suppresses the floating marker outside scanner mode without
inventing a new provider or mutating provider data.

Vanilla `FloatingQuestMarkerBase` remains active and completes its provider
processing before suppression. After each compass update the runtime schedules
a one-shot `Event.RENDER` pass, mirrors Bethesda's visible-marker clip ordering,
and sets `visible = false` only on the `Text_mc` for a marker with non-empty
tracked-objective text and `bShouldShowText`. Quest icons, offscreen arrows, and
numeric distance text stay under Bethesda ownership; the production layout
does not hide the whole `floatingQuestMarkers` target or use alpha suppression.

Live CUI delivery is dependency-aware. `HudCompassData` dispatches a dedicated
radar event, so weapon, XP, inventory, environment, and other value-provider
updates cannot redraw `contactRadar`. Value events carry only normalized sources
whose effective values changed, and each binding matches its primary source,
optional meter maximum, and template variables before applying. Condition
events use the same changed-name contract; owned visibility bindings and
vanilla adapters re-evaluate only when their expressions consume one of those
names, with HUD opacity retained as an explicit vanilla-adapter dependency.
Bethesda HUD-mode changes reapply only vanilla adapters. Initial component
construction remains a complete one-time evaluation so unchanged defaults are
still rendered. Live callbacks apply their affected domain directly; the
rejected next-frame queue caused lag, stalls, and delayed pause response during
Bloodthirsty testing and is absent from the current production baseline.

The radar's 32 pooled contact containers retain prebuilt red-dot, white-dot, and
white-square children. Live compass updates only select the required child and
assign validated position, bounded alpha, fixed scale, and visibility. No live
radar path clears or reconstructs vector geometry. This hardening was introduced
after runtime isolated the remaining kill blackout to the Bloodthirsty legendary
effect across multiple weapon types. Persistent radar geometry did not eliminate
that blackout and is retained only as bounded rendering hygiene.

The Player Data scanner is instantiated in the accepted layout. A controlled
A/B temporarily removed it without removing the Bloodthirsty kill blackout at
either full or reduced health, disproving its text and segmented health meter as
the triggering rendering path. The faction display, radar, Player Data,
environmental scanner, equipment rail, and helmet frame remain independently
instantiated.

## Goal 10 scanner overlay

`scannerOverlay` is a passive, scanner-only HUDMenu component driven by the
existing tactical-awareness event. Its layout include uses
`visibleWhen="inScanner"`, whose value is the already established
`HudCompassData.bIsHandscannerOpen` condition. It neither hides nor replaces
Bethesda's scanner reticle, crosshair, interaction prompts, or scanner command
surfaces.

The tactical snapshot projects scanner candidates from `aEnemyMarkers`,
`aMissionMarkers`, and `aMarkers`. Candidates must have a nonzero finite handle,
finite nonnegative heading, a finite `fDistanceToPlayer` from 0 through 1000,
and a finite nonnegative integer marker type. All structurally valid marker
types are eligible. Handles are deduplicated, names are not consumed, and each
candidate receives a deterministic display-only codename derived from marker
type and handle. Established enemy, companion, ship, vehicle, and position types
retain their specialized prefixes; every other type uses `POI-*`.

The component filters that validated set to its configured forward field of
view, orders contacts by nearest distance with stable handle/type tie breakers,
and renders at most five rows. Direction is shown relative to the player's
heading. Distance is deliberately unitless because the provider value has not
been proven to represent meters or another real-world unit. An empty result is
shown as `NO VALID CONTACTS`; random or placeholder contacts are prohibited.

The centered production fragment configures a 90-degree field, five contact
rows, a 140-millisecond bounded pulse-step interval, and semantic colors for the
scanner heading, grid, general contacts, hostile contacts, and backing panels.
Its 24 noncentral markers begin as hollow squares, convert to filled dots in
five radial bands from the center outward, hold briefly, and reset. The grid
owns a stage-scoped `Timer` and no frame listener, input handler, persistence,
native code, SFSE behavior, or third-party dependency.
