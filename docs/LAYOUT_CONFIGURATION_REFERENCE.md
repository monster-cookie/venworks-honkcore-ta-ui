# Layout Configuration Reference

This document is the authoring reference for version 1 Venworks Customizable
HUD layouts. It covers the checked-in XML schema and the stricter behavior of
the current Scaleform/ActionScript runtime.

The structural contract is
[`Schemas/VenworksCUI/layout-v1.xsd`](../Schemas/VenworksCUI/layout-v1.xsd).
The runtime remains authoritative where it imposes a narrower rule than the
XSD. A document must satisfy both layers.

For common player changes, start with the
[user configuration guide](USER_CONFIGURATION.md). Palette roles and
references are documented separately in the
[palette configuration reference](PALETTE_CONFIGURATION_REFERENCE.md).

## Fixed runtime paths

All paths below are relative to Starfield's `Data\Interface` directory.

| Resource | Runtime path |
|---|---|
| Root layout | `VenworksCUI\layout.xml` |
| Imported fragments | `VenworksCUI\components\<filename>.xml` |
| Selected palette | `VenworksCUI\palettes\<filename>.xml` |
| Local SVG assets | `VenworksCUI\Assets\<relative-path>.svg` |

The runtime does not load a user-selected layout from any other root, execute
scripts from XML, call arbitrary game methods, subscribe to arbitrary data
providers, or fetch network resources.

## Load and validation order

The runtime processes an authored layout as one atomic configuration:

1. Load and parse `layout.xml`.
2. Validate no more than 16 `<include>` declarations and load their fragments.
3. Require each fragment to contain one local root `<group>`, prefix its IDs,
   and append its wrapper to the root `<components>` collection.
4. Expand `button`, `quickBar`, `informationPanel`, and `warning` composites.
5. Expand templates, instances, repeaters, and the selected static state.
6. Load and validate the optional selected palette, then resolve compatible
   `@palette.*` attributes.
7. Validate the fully resolved component tree, conditions, live-value sources,
   and references.
8. Preload and validate every referenced local SVG.
9. Create the display layer and subscribe only to the hardcoded HUD providers.

Any failure prevents the complete configurable layer from rendering and shows
a categorized diagnostic. No invalid subtree is skipped or partially accepted.

## Root layout document

The source `layout.xml` uses this order:

```xml
<?xml version="1.0" encoding="utf-8"?>
<venworksCUI schemaVersion="1" runtimeVersion="1"
             designWidth="1920" designHeight="1080"
             safeLeft="64" safeTop="36"
             safeRight="64" safeBottom="36"
             palette="venworks.xml">
  <definitions>
    <meterStyle id="example.continuous" renderer="continuous"
                fillColor="#FFFFFF" emptyColor="#000000"
                fillOpacity="1" emptyOpacity="0.25" />
  </definitions>
  <vanillaVisibility>
    <target id="topCenter" visibleWhen="always" />
  </vanillaVisibility>
  <includes>
    <include id="example.fragment" src="faction-display.xml"
             x="0" y="0" anchor="top-left" z="0" />
  </includes>
  <components>
    <group id="example.inline" x="0" y="0"
           width="0" height="0" z="0" />
  </components>
</venworksCUI>
```

`definitions` and `components` are required. `vanillaVisibility` and `includes`
are optional. When present, the elements must remain in the order above.
The final tree must resolve to at least one rendered component; an empty
`components` element is useful only when one or more valid includes supply that
content.

### Root attributes

| Attribute | Required | Contract |
|---|---:|---|
| `schemaVersion` | Yes | Fixed value `1`. |
| `runtimeVersion` | Yes | Fixed value `1`. |
| `designWidth` | Yes | Fixed value `1920`. |
| `designHeight` | Yes | Fixed value `1080`. |
| `safeLeft` | Yes | Non-negative integer left inset; runtime also checks that it is finite. |
| `safeTop` | Yes | Non-negative integer top inset; runtime also checks that it is finite. |
| `safeRight` | Yes | Non-negative integer right inset; runtime also checks that it is finite. |
| `safeBottom` | Yes | Non-negative integer bottom inset; runtime also checks that it is finite. |
| `palette` | No | One safe XML filename directly under `VenworksCUI\palettes`. |

The horizontal safe insets may not total more than 1920, and the vertical
insets may not total more than 1080. The transformed visible rectangle must
retain positive width and height after applying them.

The palette filename must match
`[A-Za-z0-9][A-Za-z0-9._-]{0,59}.xml`. It cannot contain `..`, a slash, a
backslash, a colon, `?`, or `#`.

## Identifiers

Definition, component, include, repeater-item, override-target, and state-option
identifiers use this form:

```text
[A-Za-z][A-Za-z0-9._-]{0,63}
```

They must begin with a letter and may be no longer than 64 characters.

- Definition IDs are unique across meter styles and templates.
- Component IDs are unique in each authored tree and in the final resolved
  layout.
- Include IDs are unique in the root layout.
- A fragment's local IDs are prefixed with `<include-id>.`.
- Template descendant IDs are prefixed with the instance, repeater-item, or
  state ID.
- Composite expansion creates additional IDs such as `<button-id>.label`; the
  generated full ID must still fit the 64-character limit.

Short, semantic IDs leave room for these generated prefixes.

## Coordinates, bounds, transforms, and anchors

The layout uses a fixed 1920-by-1080 design coordinate system. Starfield's
current visible rectangle establishes the root viewport; the root safe insets
are applied inside it.

Without `anchor`, `x` and `y` remain ordinary parent-relative positions. With
an anchor, the engine aligns the same point on the component's transformed
configured bounds to the named point on the parent bounds, then applies `x`
and `y` as signed offsets.

Supported anchors are:

```text
top-left       top-center       top-right
center-left    center           center-right
bottom-left    bottom-center    bottom-right
```

Nested components anchor to their parent group's configured bounds. Root
components and imported-fragment wrappers anchor inside the root safe area.

`rotation`, `scaleX`, and `scaleY` must be finite numbers. The runtime does not
automatically reflow neighboring components after a transform.

## Common component attributes

Unless a later section says otherwise, rendered primitives, specialized live
components, groups, masks, and top-level composites use these attributes:

| Attribute | Required | Value and behavior |
|---|---:|---|
| `id` | Yes | Valid identifier unique in the current tree. |
| `x` | Yes | Finite design-space number. |
| `y` | Yes | Finite design-space number. |
| `width` | Yes | Non-negative integer in the XSD; most visible/specialized components require a positive runtime value. |
| `height` | Yes | Non-negative integer in the XSD; most visible/specialized components require a positive runtime value. |
| `opacity` | No | `0` through `1`; default `1`. |
| `visible` | No | `true` or `false`; default `true`. |
| `visibleWhen` | No | One compiled visibility expression. |
| `rotation` | No | Finite degrees; default `0`. |
| `scaleX` | No | Finite horizontal multiplier; default `1`. |
| `scaleY` | No | Finite vertical multiplier; default `1`. |
| `z` | Yes | Integer sibling draw order. |
| `anchor` | No | One of the nine anchors above. |

Static `visible` and dynamic `visibleWhen` are combined. A component displays
only when `visible` is true and its expression evaluates true. Unknown live
state evaluates as unknown and remains hidden.

Only attributes explicitly declared for an element are accepted. Unknown
attributes fail validation.

## Definitions

`<definitions>` must contain at least one `<meterStyle>` or `<template>`. The
runtime accepts at most 64 templates. Every definition ID is unique across both
definition types.

### Meter styles

A meter instance refers to a meter style by ID:

```xml
<meterStyle id="player.health" renderer="segments"
            fillColor="@palette.colors.meter.health"
            emptyColor="@palette.colors.panel.background"
            fillOpacity="1" emptyOpacity="0.72"
            segmentCount="16" gap="2"
            direction="right" partialSegments="true" />
```

All meter styles require `id`, `renderer`, `fillColor`, `emptyColor`,
`fillOpacity`, and `emptyOpacity`.

| Renderer | Additional attributes | Rejected attributes |
|---|---|---|
| `continuous` | Optional `direction`. | `segmentCount`, `gap`, `partialSegments`, `trianglePattern`, `startAngle`, `sweepAngle`, `clockwise`, `thickness`. |
| `triangles` | Required `segmentCount` and `gap`; optional `direction`, `partialSegments`, and `trianglePattern`. | `startAngle`, `sweepAngle`, `clockwise`, `thickness`. |
| `segments` | Required `segmentCount` and `gap`; optional `direction` and `partialSegments`. | `trianglePattern`, `startAngle`, `sweepAngle`, `clockwise`, `thickness`. |
| `dots` | Required `segmentCount` and `gap`; optional `direction` and `partialSegments`. | `trianglePattern`, `startAngle`, `sweepAngle`, `clockwise`, `thickness`. |
| `radial` | Required `thickness`; optional `startAngle`, `sweepAngle`, and `clockwise`. | `segmentCount`, `gap`, `direction`, `partialSegments`, `trianglePattern`. |

Meter-style value rules:

| Attribute | Contract |
|---|---|
| `fillColor`, `emptyColor` | Literal `#RRGGBB` or compatible color palette reference. |
| `fillOpacity`, `emptyOpacity` | `0` through `1` or compatible opacity palette reference. |
| `segmentCount` | Integer `1` through `64`. |
| `gap` | Non-negative integer; runtime also checks that it is finite. |
| `direction` | `right`, `left`, `down`, or `up`; default renderer behavior applies when omitted. |
| `partialSegments` | `true` or `false`. |
| `trianglePattern` | `uniform` or `alternating`. |
| `startAngle` | `-360` through `360`. |
| `sweepAngle` | Greater than `0` and no more than `360`. |
| `clockwise` | `true` or `false`. |
| `thickness` | Finite number greater than `0`; it may not exceed the smaller bound of a radial meter instance. |

### Templates

A template contains exactly one nonempty root `<group>`:

```xml
<template id="compact.readout">
  <group id="root" x="0" y="0" width="240" height="48"
         opacity="1" visible="true" rotation="0"
         scaleX="1" scaleY="1" z="0">
    <text id="label" x="8" y="8" width="224" height="28"
          opacity="1" visible="true" rotation="0"
          scaleX="1" scaleY="1" z="1"
          value="READY" font="$MAIN_Font_Bold" fontSize="14"
          color="@palette.colors.foreground.primary"
          bold="false" align="left" />
  </group>
</template>
```

Templates may contain only `group`, `text`, `panel`, `shape`, `divider`,
`meter`, `svg`, `path`, `mask`, `icon`, `symbol`, and `providerSymbol`.
Templates cannot contain composites, specialized live renderers, another
template/instance, a repeater, or a state.

## Imported fragments

The optional root `<includes>` element accepts 1 through 16 `<include>` entries:

```xml
<include id="player-status" src="player-status-scanner.xml"
         x="-39" y="11" anchor="bottom-left"
         visible="true" visibleWhen="always" z="100" />
```

### Include attributes

| Attribute | Required | Contract |
|---|---:|---|
| `id` | Yes | Unique valid identifier; becomes the wrapper ID and fragment prefix. |
| `src` | Yes | One safe XML filename directly under `VenworksCUI\components`. |
| `x` | Yes | Finite wrapper position. |
| `y` | Yes | Finite wrapper position. |
| `anchor` | No | Root-safe-area anchor. |
| `visible` | No | Static Boolean; default `true`. |
| `visibleWhen` | No | Visibility expression applied to the wrapper. |
| `z` | Yes | Use an integer; the final wrapper is validated as a component. |

`src` must match `[A-Za-z0-9][A-Za-z0-9._-]{0,59}.xml` and cannot contain
`..`, a slash, a backslash, a colon, `?`, or `#`. Include declarations cannot
contain child elements.

Each loaded component file:

- is limited to 65,536 characters;
- has root `venworksCUIFragment`;
- has exactly `schemaVersion="1"` and `runtimeVersion="1"` and no other root
  attributes;
- contains exactly one `<group>` child; and
- cannot contain `<includes>` or `<include>` at any depth.

The imported group supplies the wrapper `width` and `height`. Its own `x` and
`y` become `0`, its anchor becomes `top-left`, and all local IDs receive the
include prefix. Its authored opacity, visibility, conditions, transforms, and
children remain subject to normal component validation.

## Bethesda HUD visibility adapters

The optional `<vanillaVisibility>` element accepts 1 through 16 `<target>`
entries. Only these normalized IDs are allowlisted:

| Authored ID | Bethesda target |
|---|---|
| `topCenter` | `TopCenterGroup_mc` |
| `bottomLeft` | `BottomLeftGroup_mc` |
| `rightMeters` | `RightMeters_mc` |
| `socialCommandIcons` | `SocialCommandIcons_mc` |
| `floatingQuestMarkers` | `FloatingQuestMarkerBase` |
| `crewBuffWidget` | `CrewBuffWidget_mc` |

IDs are case-insensitive and ignore underscores. A normalized target may appear
only once.

Every target requires `id` and `visibleWhen`. Placement is optional and uses
one of two mutually exclusive forms:

- absolute: `x`, `y`, and `anchor` must all be present; or
- relative: `offsetX` and `offsetY` must both be present.

Relative offsets are added to Bethesda's captured original position. Absolute
placement anchors the target's current bounds in its display-list parent.
Neither form changes scale or rotation.

The adapter preserves Bethesda's current HUD-mode visibility and composes it
with the configured condition. It also follows Bethesda's HUD opacity. A
condition cannot force an element visible when its owning Bethesda HUD mode is
hidden.

## Visibility conditions

Condition names are case-insensitive and ignore underscores. For example,
`inScanner`, `IN_SCANNER`, and `inscanner` normalize to the same condition.

### Boolean conditions

| Condition | Meaning |
|---|---|
| `always` | Constant true. |
| `never` | Constant false. |
| `firstPerson` | Player is in first person. |
| `thirdPerson` | Player is in third person. |
| `inCombat` | Bethesda stealth data reports combat. |
| `inScanner` | Scanner mode is active. |
| `isSneaking` | Bethesda stealth data reports sneaking. |
| `weaponAiming` | Iron-sights/aiming state is active. |
| `weaponHasAmmo` | Current weapon exposes ammunition. |
| `weaponHasExplosive` | Current explosive count/type is available. |
| `weaponExplosiveIsMine` | Current explosive category is a mine. |
| `boostActive` | Jetpack boost is active. |
| `inVehicle` | Player HUD is in the vehicle state. |
| `digipicksAvailable` | Player inventory reports at least one digipick. |
| `hudVisible` | HUD opacity is greater than zero. |
| `criticalHealth` | Known player health is below the runtime's 35-percent threshold. |

For favorite slots `01` through `12`, these Boolean families are available:

```text
favorite01Active       favorite01Populated
favorite01Power        favorite01Weapon
favorite01Item
```

Replace `01` with any two-digit slot through `12`.

### Numeric conditions

`hudOpacityPercentage` is the only numeric condition. It requires a comparison
against a literal value from 0 through 100.

### Grammar and limits

- Keywords: `AND`, `OR`, and `NOT`.
- Precedence: parentheses, `NOT`, `AND`, then `OR`.
- Numeric operators: `=`, `!=`, `<>`, `<`, `<=`, `>`, and `>=`.
- Maximum expression length: 256 characters.
- Maximum tokens: 64.
- Maximum parenthesis nesting: 8 levels.
- Numeric literals: unsigned values from 0 through 100.
- Boolean literals are not supported; use `always` and `never`.

In XML attributes, escape less-than operators:

```xml
visibleWhen="hudOpacityPercentage &lt; 50"
visibleWhen="hudOpacityPercentage &lt;= 75 AND hudVisible"
```

`hasCombatEffect("id")` and `hasEnvironmentEffect("id")` are recognized names
but deliberately unavailable in `hudmenu.gfx`; using either fails validation.
No other functions are accepted.

Unknown runtime state does not become false internally, but the visibility
binding displays only an explicit true result. This fail-hidden behavior avoids
showing state-dependent UI before its provider initializes.

## Live-value sources

Live source names are case-insensitive and ignore underscores. Dots remain part
of the source namespace. Only the following hardcoded sources are accepted.

### String sources

```text
location.name
player.serial
power.key
power.name
quest.objective
weapon.name
weapon.icon
weapon.ammoType
weapon.explosiveLabel
environment.protectionStatus
environment.hazard.airWaterStatus
environment.hazard.thermalStatus
environment.hazard.corrosiveStatus
environment.hazard.radiationStatus
environment.hazard.airWaterShortStatus
environment.hazard.thermalShortStatus
environment.hazard.corrosiveShortStatus
environment.hazard.radiationShortStatus
```

For favorite slots `01` through `12`, these string sources are also available:

```text
favorite.01.name
favorite.01.detail
favorite.01.hotkey
```

Replace `01` with any two-digit slot through `12`.

Diagnostic string sources are:

```text
diagnostic.inventoryProvider
diagnostic.powerNameProvider
diagnostic.environmentProvider
diagnostic.environmentFields
diagnostic.environmentCandidates
diagnostic.localEnvironmentFields
diagnostic.activityOxygen
diagnostic.activityEnvelope
diagnostic.activityProtection
diagnostic.activityLoads
diagnostic.playerFields
diagnostic.playerTargets
diagnostic.playerIdentifiers
diagnostic.playerTimeInventory
diagnostic.effect0
diagnostic.effect1
diagnostic.effect2
diagnostic.effect3
diagnostic.armorResistance
diagnostic.starmapProvider
```

Diagnostic sources expose bounded troubleshooting text and are not stable
player-facing content contracts.

### Boolean sources

```text
power.hasSpell
weapon.displayAmmo
weapon.ammoAsPercent
environment.fullSoakAlertCandidate
```

### Numeric sources

```text
environment.oxygenPercentage
environment.temperature
environment.gravity
environment.localTime
player.universalTime
player.level
player.levelXP
player.nextLevelXP
player.xpPercentage
player.health
player.maxHealth
player.healthPercentage
player.oxygen
player.maxOxygen
player.oxygenPercentage
player.carbonDioxide
player.carbonDioxidePercentage
player.digipicks
power.current
power.maximum
power.percentage
power.cost
power.cooldown
carry.current
carry.maximum
carry.percentage
credits
weapon.clipAmmo
weapon.totalAmmo
weapon.reserveAmmo
weapon.explosiveCount
weapon.explosiveType
boost.charge
boost.percentage
environment.hazard.effectCount
environment.hazard.airWaterLevel
environment.hazard.thermalLevel
environment.hazard.corrosiveLevel
environment.hazard.radiationLevel
environment.hazard.airWaterExposureLevel
environment.hazard.thermalExposureLevel
environment.hazard.corrosiveExposureLevel
environment.hazard.radiationExposureLevel
environment.soakCandidate
environment.protectionLevel
environment.protectionPercentage
```

An allowlisted source can still be unknown until its Bethesda provider publishes
usable data. Text and meter components use their authored fallback while data is
unknown.

## Text formats and value templates

A `<text>` may use either one `source` or one `valueTemplate`, not both.

### Direct source

```xml
<text id="health.percent" x="0" y="0" width="100" height="24"
      opacity="1" visible="true" rotation="0"
      scaleX="1" scaleY="1" z="1"
      value="--" source="player.healthPercentage" format="percent"
      font="$MAIN_Font" fontSize="14" color="#FFFFFF"
      bold="false" align="right" />
```

`value` is required and serves as the fallback until the source is known.

### Value template

```xml
value="HEALTH --/--"
valueTemplate="HEALTH {player.health:integer}/{player.maxHealth:integer}"
```

A template is 1 through 256 characters and must contain 1 through 8 variables.
Each variable is `{source}` or `{source:format}`. A `format` attribute on the
text itself is forbidden when `valueTemplate` is present. If any variable is
unknown, the complete authored `value` fallback is displayed.

### Formats

| Format | Allowed source kind | Output |
|---|---|---|
| `raw` | String, Boolean, or number | ActionScript string conversion. |
| `integer` | Number | Rounded integer. |
| `percent` | Number | Rounded number followed by `%`. |
| `temperature` | Number | Rounded number followed by `°`. |
| `gravity` | Number | Two decimal places followed by `g`. |
| `time24` | Number | Fractional-day value rendered as `HH:MM`. |
| `boolean` | Boolean | `TRUE` or `FALSE`. |

String sources require `raw`. Boolean sources permit `raw` or `boolean`.
Numeric sources reject `boolean`.
`percent` does not multiply by 100; the selected source must already publish a
percentage-scale value.

## Primitive and container components

### `group`

Uses only the common component attributes. It may contain zero or more authored
components. A template's root group must be nonempty; an ordinary group may be
empty.

### `text`

Adds these attributes:

| Attribute | Required | Contract |
|---|---:|---|
| `value` | Yes | Static text or unknown-data fallback. It may be empty only when `source` or `valueTemplate` exists. |
| `source` | No | One allowlisted source; mutually exclusive with `valueTemplate`. |
| `format` | No | One format above; default `raw`; forbidden with `valueTemplate`. |
| `valueTemplate` | No | Bounded multi-source template; mutually exclusive with `source`. |
| `font` | Yes | Nonempty font name. Packaged layouts use `$MAIN_Font` or `$MAIN_Font_Bold`. |
| `fontSize` | Yes | Positive integer or compatible typography palette reference. |
| `color` | Yes | `#RRGGBB` or compatible color/typography palette reference. |
| `bold` | No | Boolean; default `false`; compatible typography field reference is supported. |
| `multiline` | No | Boolean; default `false`. |
| `wordWrap` | No | Boolean; default `false`. |
| `align` | Yes | `left`, `center`, or `right`. |

### `panel`

Adds required `fillColor`, `fillOpacity`, `strokeColor`, `strokeOpacity`, and
`strokeWidth`. Colors use `#RRGGBB`; opacity values use 0 through 1; stroke
width is finite and non-negative.

### `shape`

Adds required `shape`, `fillColor`, `fillOpacity`, `strokeColor`,
`strokeOpacity`, and `strokeWidth`. `shape` is `rectangle` or `ellipse`.

### `divider`

Adds required `color`, `strokeOpacity`, and `strokeWidth`. Stroke width must be
greater than zero. A divider can be horizontal, vertical, or diagonal according
to its configured bounds.

### `mask`

Adds required `shape`, where the value is `rectangle`, `ellipse`, or `path`.
It must contain at least one child.

For a path mask, `data`, `viewBoxX`, `viewBoxY`, `viewBoxWidth`, and
`viewBoxHeight` are required by runtime validation. View-box dimensions must be
positive. Rectangle and ellipse masks must not declare path geometry.

## Meter component

`<meter>` adds:

| Attribute | Required | Contract |
|---|---:|---|
| `style` | Yes | Existing `meterStyle` ID. |
| `value` | Yes | Finite fallback/current value. |
| `max` | Yes | Finite fallback maximum greater than zero. |
| `source` | No | Allowlisted numeric live source. |
| `maxSource` | No | Allowlisted numeric live source; requires `source`. |

Values are clamped by the renderer to the range from zero through the current
maximum. If the live source or maximum is unknown, the authored fallback is
used. A radial style's `thickness` cannot exceed the smaller of the meter's
configured width and height.

## Specialized live components

All specialized components use the common attributes and require positive
width and height.

| Element | Additional required attributes | Runtime limits/behavior |
|---|---|---|
| `contactRadar` | `enemyColor`, `allyColor`, `playerColor` | Displays only the runtime's bounded, validated acquired-contact model. |
| `compassTape` | `fieldOfView`, `tickColor`, `headingColor`, `centerColor`, `fallbackColor` | `fieldOfView` is 30 through 180 degrees. |
| `scannerOverlay` | `fieldOfView`, `maxTargets`, `flickerIntervalMs`, `scanningColor`, `gridColor`, `contactColor`, `hostileColor`, `backgroundColor` | Field of view is 30-180; targets 1-5; interval 50-2000 milliseconds. |
| `threatAlert` | `backgroundColor`, `clearColor`, `cautionColor`, `dangerColor`, `criticalColor` | Uses the bounded player-threat model; it does not replace Bethesda's enemy health or stealth UI. |
| `statusEffectBar` | `maxItems`, `debuffColor`, `sustenanceColor`, `neutralColor`, `backgroundColor` | `maxItems` is 1 through 16. |

Every color accepts `#RRGGBB` or a compatible palette color reference.

## Vector, icon, and symbol components

### `svg`

Loads one local SVG and adds:

| Attribute | Required | Values |
|---|---:|---|
| `src` | Yes | Safe relative `.svg` path under `VenworksCUI\Assets`. |
| `fit` | No | `contain`, `cover`, `stretch`, or `none`; default `contain`. |
| `alignX` | No | `left`, `center`, or `right`; default `center`. |
| `alignY` | No | `top`, `center`, or `bottom`; default `center`. |

The direct `src` form may contain safe subdirectories. It must be 5 through
128 characters, start with an alphanumeric character, use only letters,
numbers, dots, underscores, slashes, and hyphens, and end in `.svg`. Absolute
paths, backslashes, colons, empty segments, `.` segments, and `..` segments are
rejected.

### `path`

Renders inline SVG path geometry and adds required `data`, `viewBoxX`,
`viewBoxY`, `viewBoxWidth`, `viewBoxHeight`, `fillColor`, `fillOpacity`,
`strokeColor`, `strokeOpacity`, and `strokeWidth`.

- `data` is nonempty and at most 8192 characters.
- View-box coordinates are finite; dimensions are positive.
- Stroke width is non-negative; opacity is 0 through 1.
- Supported absolute and relative commands are `M`, `L`, `H`, `V`, `C`, `S`,
  `Q`, `T`, and `Z`.
- Arc command `A` is explicitly rejected.
- The parser allows at most 2048 path tokens and 512 commands.

### `icon`

Creates a same-domain built-in vector icon. It adds required `name` plus
optional `color`, `fit`, `alignX`, and `alignY`.

The 21 allowlisted names are:

```text
health          oxygen        co2             shield
armor           weapon        aiming          ship
vehicle         fuel          cargo           scanner
stealth         warning       objective       jolly-roger
death           poison        burning         electrocution
disease
```

### `symbol`

Creates an allowlisted symbol embedded in the owning Bethesda HUD movie. It
adds required `name` plus optional `color`, `fit`, `alignX`, and `alignY`.

The allowlisted names are:

```text
environment-alert
quest-door-marker
boost-fill
vehicle-exit-prompt
```

Availability is movie-aware. `vehicle-exit-prompt` is presentation-only and
extracts the current controller or keyboard glyph region; it does not own input.

### `providerSymbol`

Loads a symbol named by an approved live provider. It adds required `source`
plus optional `color`, `fit`, `alignX`, and `alignY`.

The only allowlisted provider-symbol source is `weapon.icon`. Unknown, empty,
or failed symbols remain hidden. Provider values beginning with `CCSUP` use
their supplied library; other values use Bethesda's `WeaponIcons` library.

## Composite components

Composites are convenient authored elements that the runtime lowers into
primitive groups before final validation. They use semantic palette roles when
a palette is selected.

### `button`

Uses the common attributes and adds:

| Attribute | Required | Values |
|---|---:|---|
| `label` | Yes | Nonempty text. |
| `icon` | No | Built-in icon key or compatible palette asset reference. |
| `key` | No | Nonempty key-hint text when present. |
| `state` | Yes | `normal`, `selected`, `disabled`, or `warning`. |

The configured bounds must be at least 160 by 48. Generated label space must
remain positive after optional icon and key areas.

### `quickBar`

Uses the common attributes and adds required positive `buttonHeight` and
non-negative `gap`. Bounds must be at least 160 by 48, and `buttonHeight` must
be at least 48.

It contains 1 through 16 child `<button>` entries. A child button accepts:

| Attribute | Required | Values |
|---|---:|---|
| `id` | Yes | Unique local identifier. |
| `label` | Yes | Nonempty text. |
| `icon` | No | Built-in icon key or compatible palette asset. |
| `key` | No | Nonempty key text. |
| `state` | Yes | Button state above. |
| `visible` | No | Static Boolean; default `true`. |
| `visibleWhen` | No | Visibility expression. |

Statically hidden buttons collapse from vertical layout. At least one declared
button and at least one statically visible button are required. The generated
buttons and gaps must fit inside the quick bar's height.

### `informationPanel`

Uses the common attributes and adds required nonempty `title`, optional `icon`,
and optional nonempty `body`. Bounds must be at least 300 by 150.

It accepts up to 20 child items, no more than 12 of which may be rows:

| Child | Attributes |
|---|---|
| `row` | Required `id`, nonempty `label`, nonempty `value`; optional `icon`, `visible`, `visibleWhen`. |
| `meter` | Required `id`, `style`, finite `value`, and positive `max`; optional nonempty `label`, `icon`, `visible`, `visibleWhen`. |
| `divider` | Required `id`; optional `visible`, `visibleWhen`. |

The panel requires body text or at least one child item. Generated content must
fit the configured bounds. Information-panel meters are static composite inputs;
they do not accept `source` or `maxSource`.

### `warning`

Uses the common attributes and adds required `severity`, nonempty `title`, and
nonempty `message`, plus optional `icon`.

`severity` is `info`, `warning`, `danger`, or `critical`. Bounds must be at
least 320 by 100. When `icon` is omitted, informational warnings use `shield`
and the other severities use `warning`.

## Template placement and bounded composition

### `instance`

Creates one template instance. It accepts:

| Attribute | Required | Contract |
|---|---:|---|
| `id` | Yes | Instance ID and generated prefix. |
| `template` | Yes | Existing template ID. |
| `x`, `y` | Yes | Finite placement. |
| `z` | Yes | Integer. |
| `anchor` | No | Supported anchor. |
| `visible` | No | Static Boolean. |
| `visibleWhen` | No | Expression combined with any template-root expression using `AND`. |

It may contain zero or more `<override>` children.

### `repeater`

Creates bounded instances of one template. It accepts:

| Attribute | Required | Contract |
|---|---:|---|
| `id`, `template` | Yes | Repeater ID/prefix and existing template ID. |
| `x`, `y` | Yes | Finite placement. |
| `width`, `height` | Yes | Finite non-negative container bounds. |
| `z` | Yes | Integer. |
| `anchor` | No | Supported anchor. |
| `visible` | No | Static Boolean; default `true`. |
| `visibleWhen` | No | Container visibility expression. |
| `flow` | Yes | `vertical`, `horizontal`, or `grid`. |
| `gapX`, `gapY` | Yes | Finite non-negative spacing. |
| `columns` | Grid only | Integer 1 through 16. Non-grid repeaters may omit it or use `1`. |

It contains 1 through 64 `<item>` children. Each item requires unique `id` and
may use `visible`, `visibleWhen`, and overrides. A statically false item is
omitted and collapses. A conditionally hidden item retains its composed slot.
Every generated item must fit the repeater bounds.

### `state`

Selects one static template option during composition. It accepts required
`id`, `selected`, `x`, `y`, and integer `z`, plus optional `anchor`, `visible`,
and `visibleWhen`.

It contains 1 through 16 `<option>` children. Each option requires a unique
`name` and an existing `template`, and may contain overrides. `selected` must
match one declared option. This is bounded static selection; it does not change
options from a live expression.

### `override`

An override requires `target`, naming a local ID inside the selected template,
and at least one approved modification:

| Attribute | Target requirement | Effect |
|---|---|---|
| `text` | Target is `text`. | Replaces the target's `value` fallback/static text. |
| `meterValue` | Target is `meter`. | Replaces its finite `value`. |
| `visible` | Any target. | Replaces static visibility. |
| `visibleWhen` | Any target. | Replaces the target expression before placement expressions are combined. |

The same target/property pair cannot be overridden twice within one placement.
Overrides cannot change position, bounds, style, source, maximum, transform,
or arbitrary attributes.

## Palette references in layouts

A palette reference must occupy the complete attribute value. Text such as
`prefix-@palette.colors.accent.primary` is rejected.

Compatible forms are:

```text
@palette.colors.<role>
@palette.opacities.<role>
@palette.typography.<role>.font
@palette.typography.<role>.fontSize
@palette.typography.<role>.bold
@palette.typography.<role>.color
@palette.strokes.<role>.color
@palette.strokes.<role>.opacity
@palette.strokes.<role>.width
@palette.assets.<role>
```

Runtime compatibility is attribute-specific:

- color roles may resolve only attributes named `color` or ending in `Color`;
- opacity roles may resolve only `opacity` or attributes ending in `Opacity`;
- typography fields may resolve only the identically named `font`, `fontSize`,
  `bold`, or `color` attribute on `<text>`;
- stroke `color` resolves `strokeColor` or `divider@color`;
- stroke `opacity` resolves `strokeOpacity`;
- stroke `width` resolves `strokeWidth`; and
- an asset role resolves only `svg@src`, `icon@name`, or `symbol@name` when the
  role's declared asset kind matches that element.

The XSD permits the general `@palette.*` token shape in several scalar unions,
but the runtime rejects a category or field used on an incompatible attribute.

## Supported local SVG subset

Every `<svg>` asset is parsed as data; no SVG script or network behavior is
available.

Supported elements are:

```text
svg  g  path  rect  circle  ellipse  line  polyline  polygon
```

The root requires a four-number `viewBox` with positive width and height. It
may also declare `width`, `height`, `fill`, `stroke`, `fill-opacity`,
`stroke-opacity`, `stroke-width`, `opacity`, and `transform`.

Shape elements accept only their geometry attributes plus the common style and
transform attributes. Colors are `#RRGGBB` or `none`. Opacity is 0 through 1;
stroke width is non-negative. Supported transforms are bounded `translate`,
`scale`, and one-angle `rotate` operations.

SVG limits and exclusions:

- at most 256 elements;
- at most 16 nesting levels;
- polyline/polygon `points` contain 2 through 256 coordinate pairs;
- no text content;
- no `text`, `image`, `use`, `defs`, filter, mask, style, script, animation,
  event, external reference, CSS, or network element;
- no unrecognized attributes; and
- no arc path commands.

PNG, JPEG, DDS, and external SWF assets are unsupported.

## Global limits

| Resource | Limit |
|---|---:|
| Root includes | 16 |
| Fragment size | 65,536 characters |
| Selected palette size | 65,536 characters |
| Templates | 64 |
| Resolved components after all expansion | 512 |
| Repeater items | 64 per repeater |
| Grid columns | 16 |
| State options | 16 per state |
| Quick-bar buttons | 16 |
| Information-panel items | 20 |
| Information-panel rows | 12 |
| Status-effect items | 16 |
| Meter segments/dots/triangles | 64 |
| Scanner targets | 5 |
| Text-template variables | 8 |
| Condition expression | 256 characters, 64 tokens, 8 nesting levels |
| Inline path data | 8192 characters, 2048 tokens, 512 commands |
| SVG document | 256 elements, 16 nesting levels |

## Unsupported configuration behavior

Version 1 deliberately does not support:

- arbitrary ActionScript, JavaScript, expressions, method names, or class
  names;
- arbitrary Bethesda provider subscriptions or timeline targets;
- nested fragment imports;
- live palette switching;
- live state-option selection;
- runtime-generated repeater data;
- network or absolute asset paths;
- raster/DDS images or external SWF symbol libraries;
- notification/toast, item/ammo-readout, chevron/notch meter,
  image-masked-meter, or bipolar-meter elements; or
- custom replacement of Bethesda enemy-health, legendary-state, stealth,
  hit-indicator, reticle, or crosshair ownership.

An unsupported element or attribute is an error, not a forward-compatible
extension point.

## Diagnostics and recovery

Configuration errors are categorized as missing, malformed, invalid,
unsupported, security, or asset-load failures. Layout-validation errors may
also identify the current phase, checkpoint, component type, and component ID.

When authoring:

1. change one bounded area at a time;
2. retain the shipped `schemaVersion` and `runtimeVersion`;
3. keep a clean backup;
4. fully restart Starfield after every change;
5. correct the first reported error before interpreting later behavior; and
6. test normal, aiming, scanner, combat, vehicle, large-HUD, and target aspect
   ratio states in game.

Build, schema, or staging success demonstrates artifact consistency but does
not replace current in-game lifecycle and visibility evidence.
