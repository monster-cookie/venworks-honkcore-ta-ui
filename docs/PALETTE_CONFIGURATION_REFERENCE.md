# Palette Configuration Reference

This is the complete reference for players who want to create custom colors, text styles, transparency, outlines, and faction artwork. It explains the required palette structure and the settings the HUD accepts.

The structural contract is
[`Schemas/VenworksCUI/palette-v1.xsd`](../Schemas/VenworksCUI/palette-v1.xsd).
The Scaleform/ActionScript resolver adds required-role, allowlist, reference,
and compatibility checks. A palette must satisfy both.

Use the [user configuration guide](USER_CONFIGURATION.md) for simple theme
switching and the [layout configuration reference](LAYOUT_CONFIGURATION_REFERENCE.md)
for all other XML elements. The [component library](COMPONENT_LIBRARY.md)
lists the HUD sections and components that consume these palette values.

## Included palettes and public themes

Each of the four themed release variants packages all five palette XML files under `Interface\VenworksCUI\palettes`. The themed variant controls only the initial `palette` attribute in `layout.xml`. Minimalist packages no palette files; its build resolves the `starfield.xml` color roles to literals before staging its external layout and six component fragments.

| Public appearance | Palette filename |
|---|---|
| Venworks Customizable HUD - Venworks Theme | `venworks.xml` |
| Venworks Customizable HUD - Trackers Alliance Theme | `trackers-alliance.xml` |
| Venworks Customizable HUD - Freestar Collective Theme | `freestar-collective.xml` |
| Venworks Customizable HUD - Crimson Fleet Theme | `crimson-fleet.xml` |
| Included neutral Starfield option | `starfield.xml` |

All five packaged palettes currently resolve their `faction.logo` roles to SVG
files included with the HUD.

## Runtime path and selection

Palette files load only from:

```text
Data\Interface\VenworksCUI\palettes\
```

The root layout selects one palette by filename:

```xml
<venworksCUI schemaVersion="1" runtimeVersion="1"
             designWidth="1920" designHeight="1080"
             safeLeft="64" safeTop="36"
             safeRight="64" safeBottom="36"
             palette="venworks.xml">
```

The filename must:

- begin with an ASCII letter or number;
- contain only letters, numbers, dots, underscores, and hyphens before `.xml`;
- contain no more than 60 characters before the extension under the current
  pattern;
- name one file directly in `VenworksCUI\palettes`; and
- contain no `..`, slash, backslash, colon, query string, or fragment.

The loaded palette is limited to 65,536 characters. There is no live palette
switching. Fully exit and restart Starfield after changing the selection or
palette content.

If the root layout omits `palette`, literal-only version 1 layouts remain
supported. Any `@palette.*` reference without a selected palette is invalid.

## Document structure

A `venworksCUIPalette` document has exactly five sections in this exact order:

```xml
<?xml version="1.0" encoding="utf-8"?>
<venworksCUIPalette schemaVersion="1">
  <colors>
    <color role="foreground.primary" value="#F4FBFF" />
  </colors>
  <typography>
    <style role="body" font="$MAIN_Font" fontSize="16"
           bold="false" color="foreground.primary" />
  </typography>
  <opacities>
    <opacity role="opaque" value="1" />
  </opacities>
  <strokes>
    <stroke role="panel" color="panel.border"
            opacity="muted" width="2" />
  </strokes>
  <assets>
    <asset role="faction.logo" kind="svg"
           value="venworks-logo.svg" />
  </assets>
</venworksCUIPalette>
```

The root requires only `schemaVersion="1"`. Unknown root or section attributes,
extra sections, missing sections, reordered sections, child content inside an
entry, and unknown entry attributes are rejected.

The abbreviated sample above illustrates structure but is not a valid runtime
palette because it omits required roles. Start custom work from a complete
packaged palette or the complete template later in this document.

## Semantic role names

Every entry has a unique `role` within its own category. Roles:

- use lowercase ASCII letters and numbers;
- begin each dot-separated segment with a lowercase letter;
- may contain hyphens inside a segment;
- use dots to express semantic hierarchy; and
- contain at most 64 characters.

The effective pattern is:

```text
[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)*
```

The same role text may exist in different categories because colors,
typography, opacities, strokes, and assets have separate namespaces.

Additional non-required roles are allowed within the category limits and may be
referenced by compatible layout attributes.

## Section counts

| Section | Entry element | Minimum | Maximum |
|---|---|---:|---:|
| `colors` | `color` | 1 | 64 |
| `typography` | `style` | 1 | 16 |
| `opacities` | `opacity` | 1 | 32 |
| `strokes` | `stroke` | 1 | 32 |
| `assets` | `asset` | 1 | 32 |

## Colors

A color entry requires exactly `role` and `value`:

```xml
<color role="accent.primary" value="#19C8FF" />
```

`value` must be six-digit `#RRGGBB`. Three-digit shorthand, eight-digit alpha,
CSS names, functions, and unprefixed hex values are rejected. The runtime
normalizes accepted colors to uppercase when resolving them.

### Required color roles

| Role | Intended semantic use |
|---|---|
| `foreground.primary` | Primary readable text and foreground artwork. |
| `foreground.muted` | Secondary labels and de-emphasized foregrounds. |
| `accent.primary` | Main theme accent and focus color. |
| `accent.secondary` | Supporting accent. |
| `panel.background` | Panel and recess backgrounds. |
| `panel.border` | Panel outlines and dividers. |
| `state.normal` | Normal interactive/composite foreground state. |
| `state.selected` | Selected or active state. |
| `state.disabled` | Disabled or unavailable state. |
| `state.clear` | Clear/safe status. |
| `state.caution` | Caution status. |
| `state.danger` | Danger status. |
| `state.critical` | Critical/hostile status. |
| `meter.health` | Player health meter. |
| `meter.oxygen` | Oxygen meter. |
| `meter.carbondioxide` | CO2 meter. |
| `meter.boost` | Boost meter. |
| `marker.player` | Player marker. |
| `marker.ally` | Ally/friendly marker. |
| `marker.hostile` | Hostile marker. |
| `marker.objective` | Objective marker. |

All 21 roles are required even if a particular custom layout does not visibly
consume every role.

## Typography

A typography entry requires exactly `role`, `font`, `fontSize`, `bold`, and
`color`:

```xml
<style role="heading" font="$MAIN_Font_Bold" fontSize="22"
       bold="true" color="foreground.primary" />
```

| Attribute | Contract |
|---|---|
| `font` | Exactly `$MAIN_Font` or `$MAIN_Font_Bold`. |
| `fontSize` | Integer 1 through 128. |
| `bold` | Exactly `true` or `false`. |
| `color` | Name of an existing color role in the same palette, without `@palette.colors.`. |

Required typography roles are `body`, `label`, and `heading`.

Typography references expose resolved fields individually:

```text
@palette.typography.heading.font
@palette.typography.heading.fontSize
@palette.typography.heading.bold
@palette.typography.heading.color
```

Each field may be used only on the identically named attribute of a `<text>`
element. A typography role cannot be applied to a component as a single style
object.

## Opacities

An opacity entry requires exactly `role` and `value`:

```xml
<opacity role="panel" value="0.94" />
```

The value must be a plain decimal from `0` through `1`. Scientific notation,
negative values, and values over 1 are rejected.

Required opacity roles are:

| Role | Intended semantic use |
|---|---|
| `opaque` | Fully visible generated content. |
| `panel` | Standard panel opacity. |
| `muted` | De-emphasized fills, strokes, or empty meters. |

An opacity reference may resolve only an attribute named `opacity` or ending in
`Opacity`.

## Strokes

A stroke entry requires exactly `role`, `color`, `opacity`, and `width`:

```xml
<stroke role="panel" color="panel.border"
        opacity="muted" width="2" />
```

| Attribute | Contract |
|---|---|
| `color` | Existing color role in the same palette. |
| `opacity` | Existing opacity role in the same palette. |
| `width` | Integer 0 through 64. |

The required stroke role is `panel`.

Stroke fields resolve separately:

```text
@palette.strokes.panel.color
@palette.strokes.panel.opacity
@palette.strokes.panel.width
```

- `color` is compatible with `strokeColor` and `divider@color`.
- `opacity` is compatible with `strokeOpacity`.
- `width` is compatible with `strokeWidth`.

## Assets

An asset entry requires exactly `role`, `kind`, and `value`:

```xml
<asset role="faction.logo" kind="svg" value="venworks-logo.svg" />
```

The required asset role is `faction.logo`.

### SVG asset kind

`kind="svg"` requires one packaged filename matching this shape:

```text
[A-Za-z0-9][A-Za-z0-9._-]{0,59}.svg
```

Palette SVG assets must be single files directly under
`Interface\VenworksCUI\Assets`; subdirectories and `..` are rejected.

The production faction-display fragment consumes `faction.logo` through
`<svg src="@palette.assets.faction.logo">`. Therefore a palette used with the
production layout must declare `faction.logo` as `kind="svg"`, even though the
general palette schema permits the other asset kinds.

### Built-in icon asset kind

`kind="icon"` requires one of these allowlisted same-domain icons:

```text
health          oxygen        co2             shield
armor           weapon        aiming          ship
vehicle         fuel          cargo           scanner
stealth         warning       objective       jolly-roger
death           poison        burning         electrocution
disease
```

An icon asset reference is compatible only with `icon@name`.

### Embedded symbol asset kind

`kind="symbol"` requires one allowlisted Bethesda HUD symbol:

```text
environment-alert
quest-door-marker
boost-fill
vehicle-exit-prompt
```

A symbol asset reference is compatible only with `symbol@name`. Symbol
availability remains specific to the owning normal or large HUD movie.

## Reference syntax and compatibility

References must occupy the complete layout attribute value. They are not string
interpolation.

| Category | Syntax | Compatible destination |
|---|---|---|
| Color | `@palette.colors.<role>` | `color` or an attribute ending in `Color`. |
| Opacity | `@palette.opacities.<role>` | `opacity` or an attribute ending in `Opacity`. |
| Typography | `@palette.typography.<role>.<field>` | Identically named `font`, `fontSize`, `bold`, or `color` on `<text>`. |
| Stroke | `@palette.strokes.<role>.<field>` | `strokeColor`/`divider@color`, `strokeOpacity`, or `strokeWidth` according to field. |
| Asset | `@palette.assets.<role>` | `svg@src`, `icon@name`, or `symbol@name` matching the asset kind. |

Examples:

```xml
color="@palette.colors.foreground.primary"
fillOpacity="@palette.opacities.panel"
font="@palette.typography.heading.font"
fontSize="@palette.typography.heading.fontSize"
bold="@palette.typography.heading.bold"
strokeWidth="@palette.strokes.panel.width"
src="@palette.assets.faction.logo"
```

Invalid examples include:

```xml
value="Color: @palette.colors.accent.primary"
width="@palette.colors.accent.primary"
visible="@palette.opacities.opaque"
src="@palette.assets.some-icon"
```

The last form is invalid when `some-icon` is declared as `kind="icon"`, because
an icon asset can resolve only `icon@name`, not `svg@src`.

## Complete custom-palette starter

This template contains every required role. Save a customized copy under a new
safe filename instead of overwriting a packaged palette.

```xml
<?xml version="1.0" encoding="utf-8"?>
<venworksCUIPalette schemaVersion="1">
  <colors>
    <color role="foreground.primary" value="#F4FBFF" />
    <color role="foreground.muted" value="#8EB9D0" />
    <color role="accent.primary" value="#19C8FF" />
    <color role="accent.secondary" value="#6BE7FF" />
    <color role="panel.background" value="#061722" />
    <color role="panel.border" value="#2DCBFF" />
    <color role="state.normal" value="#F4FBFF" />
    <color role="state.selected" value="#19C8FF" />
    <color role="state.disabled" value="#536D7A" />
    <color role="state.clear" value="#64E572" />
    <color role="state.caution" value="#FFD800" />
    <color role="state.danger" value="#FF7B21" />
    <color role="state.critical" value="#FF3C54" />
    <color role="meter.health" value="#D34A5B" />
    <color role="meter.oxygen" value="#35E6E6" />
    <color role="meter.carbondioxide" value="#FFB51B" />
    <color role="meter.boost" value="#6D8CFF" />
    <color role="marker.player" value="#F4FBFF" />
    <color role="marker.ally" value="#64E572" />
    <color role="marker.hostile" value="#FF3C54" />
    <color role="marker.objective" value="#19C8FF" />
  </colors>
  <typography>
    <style role="body" font="$MAIN_Font" fontSize="16"
           bold="false" color="foreground.primary" />
    <style role="label" font="$MAIN_Font" fontSize="14"
           bold="false" color="foreground.muted" />
    <style role="heading" font="$MAIN_Font_Bold" fontSize="22"
           bold="true" color="foreground.primary" />
  </typography>
  <opacities>
    <opacity role="opaque" value="1" />
    <opacity role="panel" value="0.94" />
    <opacity role="muted" value="0.7" />
  </opacities>
  <strokes>
    <stroke role="panel" color="panel.border"
            opacity="muted" width="2" />
  </strokes>
  <assets>
    <asset role="faction.logo" kind="svg"
           value="venworks-logo.svg" />
  </assets>
</venworksCUIPalette>
```

## Custom-palette workflow

1. Fully exit Starfield.
2. Copy one complete palette, preferably the closest visual starting point.
3. Rename the copy with a safe unique filename such as `my-hud.xml`.
4. Keep all required roles and the five required sections in their original
   order.
5. Change semantic values rather than renaming roles consumed by the production
   layout.
6. If changing `faction.logo`, place a supported SVG directly under
   `Interface\VenworksCUI\Assets` and use its filename only.
7. Set `layout.xml` to `palette="my-hud.xml"`.
8. Restart Starfield and test normal, aiming, scanner, combat, low-health,
   vehicle, large-HUD, and target-aspect-ratio states.
9. Keep the custom palette and any custom SVG in a personal override mod so a
   release update does not overwrite them.

When changing status colors, preserve clear differentiation among clear,
caution, danger, and critical states. When changing typography, test the longest
localized strings and both normal and large HUD movies.

## Failure behavior

Palette failures use categorized diagnostics:

| Diagnostic | Typical cause |
|---|---|
| `CUI PALETTE MISSING` | Selected filename is not deployed under `palettes`. |
| `CUI PALETTE MALFORMED` | XML is not well formed. |
| `CUI PALETTE UNSUPPORTED` | `schemaVersion` is not `1`. |
| `CUI PALETTE INVALID` | Missing/duplicate role, wrong section order, bad value, unknown reference, or incompatible reference destination. |
| `CUI PALETTE SECURITY ERROR` | Unsafe filename/path or unsafe SVG asset value. |
| `CUI ASSET LOAD ERROR` | A resolved SVG is absent, unreadable, or outside the supported SVG subset. |

Because loading is atomic, a palette error prevents the full configurable HUD
layer from displaying. Correct the first diagnostic, restart Starfield, and
verify the result in game.
