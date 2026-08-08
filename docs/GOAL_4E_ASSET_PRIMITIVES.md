# Goal 4E Asset and Vector Primitives

## Scope

Goal 4E adds packaged transparent PNG images, a restricted local SVG subset,
authored SVG path geometry, nested masks, and allowlisted symbols already
embedded in the owning vanilla movie. These primitives use fixed gallery data;
they do not replace a live HUD surface or introduce network access.

All file-backed assets resolve below `Interface/VenworksCUI/Assets`. A layout
supplies only a relative filename such as `gallery-alpha.png`; absolute paths,
drive-qualified paths, URI schemes, query strings, fragments, and `..` path
segments are rejected. Every referenced PNG and SVG is loaded and validated
before any CUI component renders. A failed preload leaves the normal vanilla
HUD intact and shows the upper red `CUI ASSET LOAD ERROR` diagnostics panel.

## Image contract

`image` loads a packaged transparent PNG. `svg` uses the same placement
contract after parsing the packaged SVG into native Scaleform vector geometry.

```xml
<image id="brand.logo" x="40" y="40" width="320" height="120"
       opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2"
       src="brand-logo.png" fit="contain" alignX="center" alignY="center" />
```

The supported fit modes are:

- `contain`: preserve aspect ratio and fit entirely inside the bounds;
- `cover`: preserve aspect ratio, fill the bounds, and clip overflow;
- `stretch`: scale independently to the configured width and height; and
- `none`: retain intrinsic size and clip to the configured bounds.

Horizontal alignment is `left`, `center`, or `right`. Vertical alignment is
`top`, `center`, or `bottom`.

## Restricted SVG contract

Local SVG files may use `svg`, `g`, `path`, `rect`, `circle`, `ellipse`, `line`,
`polyline`, and `polygon`. The parser accepts a bounded `viewBox`, fill and
stroke styling, opacity, and `translate`, `scale`, or `rotate` transforms. It
rejects text, scripts, external references, animation, filters, CSS, event
handlers, unsupported elements or attributes, and malformed geometry. A file
is limited to 256 elements and 16 levels of nesting.

SVG path data supports absolute and relative `M`, `L`, `H`, `V`, `Q`, `T`,
`C`, `S`, and `Z` commands. Elliptical arc command `A` is intentionally not
supported. A path is bounded to 2,048 tokens and 512 commands; cubic curves
are approximated with 12 deterministic line segments.

## Authored paths

`path` draws configuration-authored geometry without a file asset:

```xml
<path id="accent" x="40" y="200" width="240" height="100"
      opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2"
      data="M 0 50 C 40 0 80 100 120 50 L 120 100 L 0 100 Z"
      viewBoxX="0" viewBoxY="0" viewBoxWidth="120" viewBoxHeight="100"
      fillColor="#35E6E6" fillOpacity="0.8"
      strokeColor="#F7FCFF" strokeOpacity="1" strokeWidth="2" />
```

The same bounded path parser used for packaged SVG validates this geometry
before rendering.

## Masks

`mask` clips one or more child components to `rectangle`, `ellipse`, or
`path` geometry. Path masks require `data` and all four view-box attributes;
rectangle and ellipse masks prohibit path-only attributes. Masks may be nested
and participate in templates, but an empty mask is invalid.

```xml
<mask id="portrait.clip" x="40" y="340" width="180" height="180"
      opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2"
      shape="ellipse">
  <image id="portrait" x="0" y="0" width="180" height="180"
         opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1"
         src="portrait.png" fit="cover" alignX="center" alignY="center" />
</mask>
```

## Embedded symbols

Configuration uses semantic symbol names, never ActionScript class names. The
runtime owns a hardcoded allowlist and resolves only symbols confirmed in both
vanilla HUD movies. Goal 4E permits one initial mapping:

| Configuration name | Vanilla symbol |
|---|---|
| `skill-tech` | `Skill_Tech` |

Unknown names fail the complete layout before rendering. This keeps arbitrary
class lookup out of gamer-authored configuration.

## Fixtures

- `asset-primitives-gallery.xml` exercises PNG transparency and all four fit
  modes, packaged SVG, a cubic authored path, ellipse and nested path masks,
  and the `skill-tech` embedded symbol in two upper panels.
- `layout-invalid-asset-path.xml` attempts path traversal and is rejected by
  both the schema and runtime path guard.
- `layout-missing-asset.xml` references a valid but absent packaged PNG.
- `layout-invalid-svg.xml` loads a packaged SVG containing a prohibited script.
- `layout-invalid-svg-path.xml` uses the unsupported SVG arc command.
- `layout-invalid-mask.xml` omits required path-mask geometry.
- `layout-unknown-symbol.xml` requests a symbol outside the allowlist.

The build stages the positive gallery as `Interface/VenworksCUI/layout.xml`,
copies the Venworks-owned transparent PNG to `Assets/gallery-alpha.png`, and
copies both SVG fixtures to the same asset directory.

## Automated validation

The Goal 4E build must prove:

1. every earlier positive gallery and the asset gallery validate against
   `Schemas/VenworksCUI/layout-v1.xsd`;
2. the traversal fixture fails the schema path restriction;
3. both generated movies contain 31 authored CUI classes and reopen with all
   198 expected ActionScript classes;
4. unrelated vanilla ActionScript remains textually identical;
5. the fixed asset root, supported components, safe-parser limits, diagnostics,
   and semantic symbol mapping survive JPEXS import and reopening; and
6. generated output hashes match the committed validation records before any
   files are copied to `Staging-CUI`.

## Required in-game validation

1. Deploy the positive gallery and confirm both upper panels render while the
   normal player HUD remains usable.
2. Confirm PNG transparency plus `contain`, `cover`, `stretch`, and `none`
   placement; verify the `none` example clips at right/bottom.
3. Confirm the packaged SVG, authored path, both masks, nested mask, and
   `skill-tech` symbol render.
4. Deploy each negative fixture individually and confirm the upper red panel
   reports the intended error with no partial gallery.
5. Restore `asset-primitives-gallery.xml` as `layout.xml` and smoke-test both
   normal and large HUD movie selections.

Goal 4E is accepted only after these in-game checks pass.
