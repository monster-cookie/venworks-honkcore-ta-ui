# Goal 4A Responsive Layout

Date: 2026-08-07

## Scope

Goal 4A adds responsive composition to the existing configuration-only CUI
runtime. It does not bind a component to live Starfield data and does not add
templates, repeaters, state selection, assets, palettes, or new meter
renderers.

The layout remains a fixed 1920-by-1080 design space. Starfield and Scaleform
own screen mapping. Venworks does not apply independent horizontal and
vertical scale factors, so configured geometry is not stretched on wider or
taller viewports.

## Placement contract

Every component continues to require `x` and `y`. When `anchor` is omitted,
those values are absolute coordinates relative to the component's parent,
which preserves all Goal 3 layouts.

When `anchor` is present, `x` and `y` are signed offsets from one of nine
allowed points:

- `top-left`, `top-center`, `top-right`;
- `center-left`, `center`, `center-right`; and
- `bottom-left`, `bottom-center`, `bottom-right`.

The matching point on the component's configured rectangle is aligned to the
selected parent point, then the offsets are applied. The configured rectangle
is transformed by the component's scale and rotation before alignment. This
also gives an otherwise empty group deterministic bounds.

Example:

```xml
<panel id="bottom-right-panel"
       anchor="bottom-right"
       x="-32" y="-24"
       width="420" height="160"
       opacity="1" visible="true"
       rotation="0" scaleX="1" scaleY="1" z="10"
       fillColor="#102630" fillOpacity="0.9"
       strokeColor="#38DDE1" strokeOpacity="1" strokeWidth="2" />
```

Root components anchor to Starfield's `scaleform.gfx.Extensions.visibleRect`
after applying the root `safeLeft`, `safeTop`, `safeRight`, and `safeBottom`
insets. This is the same visible-rectangle contract used by vanilla Starfield
HUD code. Nested components anchor to the configured width and height of their
parent group.

If Scaleform does not expose a usable visible rectangle, the runtime falls
back to the declared 1920-by-1080 design rectangle. A safe area that leaves no
usable width or height fails before component rendering and displays the
existing error panel.

## Compatibility and safety

- `schemaVersion` and `runtimeVersion` remain `1` because `anchor` is optional.
- Unknown anchor names fail validation; they are never treated as absolute
  positions.
- No expressions, methods, provider names, or executable values are accepted.
- Existing absolute layouts remain valid without modification.
- The diagnostics panel remains independent of the configurable component
  layer.

## Fixtures

- `Scaleform/shared/fixtures/component-gallery.xml` is the unchanged absolute
  positioning compatibility fixture.
- `Scaleform/shared/fixtures/layout-anchor-gallery.xml` exercises all nine root
  anchors, nested group anchors, safe-area offsets, and one absolute control.
- `Scaleform/shared/fixtures/layout-invalid-anchor.xml` must be rejected by the
  schema and runtime parser.
- `Staging-CUI/Interface/VenworksCUI/layout.xml` contains the anchor gallery for
  the Goal 4A in-game acceptance test.

## Automated evidence

- The absolute gallery, anchor gallery, and staged layout validate against
  `Schemas/VenworksCUI/layout-v1.xsd`.
- The invalid-anchor fixture is rejected by the schema.
- Both vanilla-derived HUD movies compile, reopen, and retain 181 expected
  ActionScript classes, including 14 Venworks-authored CUI classes.
- The build continues to verify that unrelated vanilla ActionScript is
  unchanged.

## Required in-game validation

1. At 16:9, verify all nine labeled groups align inside the configured safe
   area.
2. Verify the four small panels inside the center group align to that group,
   not the screen.
3. Verify the orange `ABSOLUTE X=78 Y=150` control remains at the declared
   absolute coordinates.
4. At an ultrawide or other available aspect ratio, verify centered anchors
   remain centered, edge anchors follow the visible rectangle, and shapes do
   not stretch.
5. Replace the staged layout with `layout-invalid-anchor.xml`; verify the red
   upper diagnostics panel appears and no gallery is rendered.
6. Restore the staged anchor gallery and verify the error clears after the HUD
   reloads.

Goal 4A is accepted only after these runtime checks pass. Pause before starting
the remaining Goal 4 composition and asset primitives.
