# Goal 4E Asset and Vector Primitives

## Scope

Goal 4E provides restricted loose SVG assets, authored SVG path geometry,
nested masks, allowlisted symbols embedded in the owning vanilla movie, and
compiled supplemental SWF symbol libraries. These primitives use fixed gallery
data; they do not replace a live HUD surface or introduce network access.

Loose SVG files resolve below `Interface/VenworksCUI/Assets`. Supplemental
libraries resolve below `Interface/VenworksCUI/Libraries`. Layouts supply only
bounded relative SVG filenames or lowercase semantic library/name keys.
Absolute paths, URI schemes, arbitrary ActionScript class names, traversal,
scripts, and network resources are rejected. All referenced assets and
libraries load atomically before any CUI component renders.

Direct PNG, JPEG, and DDS loading was tested through Starfield Scaleform and
rejected at runtime. The public `image` component is therefore retired.
`CUIImage` remains an internal fit, alignment, clipping, and tint base for
renderable SVG and symbol components.

## Loose SVG contract

`svg` loads a gamer-supplied local file through the fixed assets root:

```xml
<svg id="brand.logo" x="40" y="40" width="320" height="120"
     opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2"
     src="brand-logo.svg" fit="contain" alignX="center" alignY="center" />
```

Supported fit modes are `contain`, `cover`, `stretch`, and `none`. Horizontal
alignment is `left`, `center`, or `right`; vertical alignment is `top`,
`center`, or `bottom`.

Local SVG files may use `svg`, `g`, `path`, `rect`, `circle`, `ellipse`, `line`,
`polyline`, and `polygon`. The parser accepts a bounded `viewBox`, fill and
stroke styling, opacity, and `translate`, `scale`, or `rotate` transforms. It
rejects text, scripts, external references, animation, filters, CSS, event
handlers, unsupported elements or attributes, and malformed geometry. A file
is limited to 256 elements and 16 levels of nesting.

SVG path data supports absolute and relative `M`, `L`, `H`, `V`, `Q`, `T`,
`C`, `S`, and `Z` commands. Elliptical arc command `A` is intentionally not
supported. Paths are bounded to 2,048 tokens and 512 commands.

## Authored paths and masks

`path` draws configuration-authored geometry without a file asset. `mask`
clips one or more children to `rectangle`, `ellipse`, or `path` geometry. Path
masks require path data and all four view-box attributes. Masks may be nested,
but an empty mask is invalid.

```xml
<path id="accent" x="40" y="200" width="240" height="100" z="2"
      data="M 0 50 C 40 0 80 100 120 50 L 120 100 L 0 100 Z"
      viewBoxX="0" viewBoxY="0" viewBoxWidth="120" viewBoxHeight="100"
      fillColor="#35E6E6" fillOpacity="0.8"
      strokeColor="#F7FCFF" strokeOpacity="1" strokeWidth="2" />
```

## Symbols

Configuration always uses semantic names, never ActionScript class names.
Without `library`, the runtime resolves only the hardcoded movie-aware vanilla
allowlist:

| Name | Normal HUD class | Large HUD class |
|---|---|---|
| `environment-alert` | `HUDMenu_fla.envAlertIcon_174` | `HUDMenu_LRG_fla.envAlertIcon_174` |
| `quest-door-marker` | `QuestDoorMarker` | `QuestDoorMarker` |
| `boost-fill` | `HUDMenu_fla.BoostBarFill_mc_139` | `HUDMenu_LRG_fla.BoostBarFill_mc_139` |

With `library`, the runtime loads the fixed-root SWF into an isolated child
`ApplicationDomain` for each configured symbol instance and verifies the
requested export through the completed loader's own domain before rendering:

```xml
<symbol id="health.icon" x="40" y="40" width="72" height="72" z="2"
        library="venworks-icons" name="health" color="#35E6E6"
        fit="contain" alignX="center" alignY="center" />
```

Library and symbol keys are lowercase letters, digits, and hyphens. The runtime
constructs a private namespaced linkage name; configuration cannot provide a
class or path. Optional `color` applies a solid tint.

The compiled `venworks-icons` library exports:

- `health`, `oxygen`, `co2`, `shield`, `armor`, `weapon`, and `aiming`;
- `ship`, `vehicle`, `fuel`, `cargo`, `scanner`, `stealth`, and `objective`;
- `warning`, `jolly-roger`, `death`, `poison`, `burning`, `electrocution`, and
  `disease`; and
- the Venworks-owned `venworks-logo`.

The Font Awesome Pro source SVGs are developer inputs and are not committed.
Only the compiled subset SWF is distributed. `Tools/compileSymbolLibrary.ps1`
requires explicit Java, JPEXS, and Font Awesome root paths and validates the
result against `Scaleform/shared/libraries/validation/expected.sha256`.
Each exported ActionScript class extends `MovieClip` and places exactly one imported
shape in an identity-matrix wrapper. This preserves the SVG geometry while giving
Scaleform the timeline-compatible display-object container and runtime dimensions
required by Starfield's linked symbols. A root `VenworksCUI_SymbolLibrary`
controller reads the allowlisted semantic symbol name from the loader request and
constructs that linkage class entirely inside the child SWF domain. The owning HUD
movie checks `ApplicationDomain.hasDefinition`, but never extracts or coerces the
child instance. It fits and tints only the parent-domain `Loader` wrapper. Global
lookup remains limited to the hardcoded Bethesda embedded-symbol allowlist.

Runtime failures use the upper diagnostic panel and report the active phase,
component type and ID, library and symbol keys when applicable, the complete
exception text, and a nonzero ActionScript error ID. This context applies to
layout parsing, asset and library loading, component creation and placement,
vanilla adapters, and initial or live visibility evaluation.

## Fixtures and staging

- `asset-primitives-gallery.xml` currently isolates the supplemental `disease`
  symbol as the loader-wrapper compatibility proof while continuing to exercise
  tint, fit/alignment behavior, loose SVG, authored paths, nested masks, and
  embedded vanilla symbols.
- `layout-invalid-asset-path.xml` attempts SVG traversal.
- `layout-missing-asset.xml` references an absent loose SVG.
- `layout-missing-symbol-library.xml` references an absent library.
- `layout-unknown-library-symbol.xml` requests a missing export from the valid
  library.
- Existing invalid SVG, path, mask, and embedded-symbol fixtures remain active.

The build stages the gallery as `Interface/VenworksCUI/layout.xml`, loose SVGs
under `Interface/VenworksCUI/Assets`, and `venworks-icons.swf` under
`Interface/VenworksCUI/Libraries`.

## Validation

Automated validation must prove schema acceptance/rejection, 31 authored CUI
classes in both generated HUD movies, unchanged unrelated vanilla
ActionScript, fixed roots and loader-wrapper handling in reopened ActionScript,
the 22 expected SWF shapes with positive dimensions, their 22 one-shape timeline
wrappers, 22 decompiled `MovieClip` linkage classes, the 22 one-to-one linkage
exports, the root loader-parameter controller, and committed output hashes before
staging.

Required in-game checks are:

1. deploy the positive gallery and confirm the tinted yellow `disease` symbol
   renders from the supplemental SWF while the normal HUD remains usable;
2. confirm loose SVGs, authored paths, masks, and all three embedded symbols;
3. deploy the missing-library and unknown-export fixtures individually and
   confirm the upper red diagnostic appears with no partial CUI layer; and
4. restore the positive gallery and smoke-test normal and large HUD movies.

Goal 4E.2 is accepted only after these in-game checks pass.
