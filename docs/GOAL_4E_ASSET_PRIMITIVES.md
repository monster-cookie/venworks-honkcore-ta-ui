# Goal 4E Asset and Vector Primitives

> **Historical implementation evidence:** Current product intent, scope,
> delivery state, and acceptance are maintained in the Codecks `Documentation`
> and `Features` decks. The asset contracts and validation evidence below
> remain authoritative until deliberately superseded.

## Scope

Goal 4E provides restricted loose SVG assets, authored SVG path geometry,
nested masks, 21 generated built-in icons, and allowlisted Bethesda symbols
embedded in the owning vanilla movie. These primitives use fixed gallery data;
they do not replace a live HUD surface or introduce network access.

Loose SVG files resolve below `Interface/VenworksCUI/Assets`. Layouts supply
only bounded relative SVG filenames or lowercase semantic icon/symbol names.
Absolute paths, URI schemes, arbitrary ActionScript class names, traversal,
scripts, and network resources are rejected. Referenced SVG assets load
atomically before any CUI component renders.

Direct PNG, JPEG, and DDS loading was tested through Starfield Scaleform and
rejected at runtime. Supplemental SWF libraries were retired after repeated
Error #1034 incompatibilities. `CUIImage` remains an internal fit, alignment,
clipping, and tint base for renderable SVG, icon, and Bethesda symbol
components.

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

Runtime SVG path data supports absolute and relative `M`, `L`, `H`, `V`, `Q`,
`T`, `C`, `S`, and `Z` commands. Elliptical arc command `A` is intentionally
not supported at runtime. Paths are bounded to 2,048 tokens and 512 commands.

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

## Built-in icons

`icon` references a generated same-domain vector by semantic name:

```xml
<icon id="health.icon" x="40" y="40" width="72" height="72" z="2"
      name="health" color="#35E6E6"
      fit="contain" alignX="center" alignY="center" />
```

The approved names are:

- `health`, `oxygen`, `co2`, `shield`, `armor`, `weapon`, and `aiming`;
- `ship`, `vehicle`, `fuel`, `cargo`, `scanner`, `stealth`, and `objective`;
- `warning`, `jolly-roger`, `death`, `poison`, `burning`, `electrocution`, and
  `disease`.

`Tools/generateIconLibrary.ps1` reads this curated Font Awesome Pro subset from
an explicitly supplied developer root and writes
`Scaleform/shared/actionscript/venworks/cui/CUIIconLibrary.as`. It converts SVG
arcs to bounded cubic Bézier segments, rejects unsupported content, and emits
deterministic ActionScript. Font Awesome source files and developer paths are
not committed. Normal Scaleform builds consume the committed generated class
and do not require Font Awesome or open icon files at runtime.

The Venworks logo is intentionally excluded from the icon library and remains
the directly loaded Venworks-owned `venworks-logo.svg` asset.

## Bethesda symbols

`symbol` uses semantic names, never ActionScript class names, and resolves only
the hardcoded movie-aware vanilla allowlist:

| Name | Normal HUD class | Large HUD class |
|---|---|---|
| `environment-alert` | `HUDMenu_fla.envAlertIcon_174` | `HUDMenu_LRG_fla.envAlertIcon_174` |
| `quest-door-marker` | `QuestDoorMarker` | `QuestDoorMarker` |
| `boost-fill` | `HUDMenu_fla.BoostBarFill_mc_139` | `HUDMenu_LRG_fla.BoostBarFill_mc_139` |

```xml
<symbol id="environment.icon" x="40" y="40" width="72" height="72" z="2"
        name="environment-alert" color="#FFD800"
        fit="contain" alignX="center" alignY="center" />
```

Optional `color` applies a solid tint to icons and symbols.

## Fixtures and staging

- `asset-primitives-gallery.xml` displays all 21 built-in icons and continues
  to exercise loose SVG, the Venworks logo, authored paths, nested masks, and
  all three embedded Bethesda symbols.
- `layout-unknown-icon.xml` requests an unrecognized built-in icon.
- `layout-invalid-asset-path.xml` attempts SVG traversal.
- `layout-missing-asset.xml` references an absent loose SVG.
- Existing invalid SVG, path, mask, and embedded-symbol fixtures remain active.

The build stages the gallery as `Interface/VenworksCUI/layout.xml` and loose
SVGs under `Interface/VenworksCUI/Assets`. It stages no supplemental library.

## Validation

Automated validation must prove schema acceptance/rejection, all authored CUI
classes in both generated HUD movies, unchanged unrelated vanilla ActionScript,
the same-domain generated icon factory, absence of supplemental SWF loading,
the 21-name icon allowlist, fixed SVG roots, and committed output hashes before
staging.

Required in-game checks are:

1. deploy the positive gallery and confirm all 21 tinted icons render;
2. confirm the Venworks SVG, packaged SVG, authored paths, masks, and all three
   embedded Bethesda symbols;
3. deploy `layout-unknown-icon.xml` and confirm the upper red diagnostic names
   the unknown icon with no partial CUI layer; and
4. restore the positive gallery and smoke-test normal and large HUD movies.

Goal 4E.3 is accepted only after these in-game checks pass.
