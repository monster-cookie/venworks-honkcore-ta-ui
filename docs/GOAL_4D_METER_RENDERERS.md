# Goal 4D Meter Renderers

## Scope

Goal 4D completes the fixed-data meter renderer library used by later player
and ship HUD surfaces. It adds segmented rectangles, dots/circles, alternating
triangles, directional linear filling, and continuous radial arcs. It does not
connect health, oxygen, ship, or other live Starfield values.

All renderers share the existing component contract: a `meter` supplies
`value`, `max`, bounds, transforms, visibility, z-order, and a meter-style
reference. Values clamp between zero and `max`.

## Renderer contract

The supported `renderer` values are `continuous`, `triangles`, `segments`,
`dots`, and `radial`. Every style requires `fillColor`, `emptyColor`,
`fillOpacity`, and `emptyOpacity`.

### Linear meters

Continuous, triangle, rectangle-segment, and dot meters accept an optional
`direction`: `right`, `left`, `down`, or `up`. The default is `right`.

Segmented renderers require `segmentCount` from 1 through 64 and a nonnegative
`gap`. `partialSegments` defaults to `true`. When false, only complete segments
are filled and the incomplete final segment remains empty.

Triangle styles accept `trianglePattern="uniform"` or
`trianglePattern="alternating"`. Uniform is the default and retains the Goal 3
down-pointing horizontal appearance. Alternating horizontal triangles switch
between up and down; vertical triangles switch between left and right.

```xml
<meterStyle id="health.alternating"
            renderer="triangles"
            trianglePattern="alternating"
            direction="right"
            partialSegments="true"
            segmentCount="14" gap="2"
            fillColor="#FFD800" emptyColor="#4A4215"
            fillOpacity="1" emptyOpacity="0.7" />
```

The fill direction controls both segment order and which side of a partial
segment is filled. This allows a renderer to be changed without changing the
owning HUD binding or meter value.

### Radial meters

Radial meters draw a continuous native-vector arc. They require a positive
`thickness` and accept:

- `startAngle` from -360 through 360, defaulting to -90 (top center);
- `sweepAngle` greater than zero and no more than 360, defaulting to 360; and
- `clockwise`, defaulting to `true`.

The configured thickness cannot exceed the smaller meter bound. Arcs use at
most one line segment for every four degrees, bounding a full ring to 90 steps.
Segmented radial rings are outside Goal 4D.

```xml
<meterStyle id="oxygen.radial"
            renderer="radial"
            startAngle="-90" sweepAngle="270"
            clockwise="true" thickness="10"
            fillColor="#35E6E6" emptyColor="#183B48"
            fillOpacity="1" emptyOpacity="0.7" />
```

## Safety and compatibility

- Existing continuous and triangle styles retain rightward filling and partial
  triangle segments when the new optional attributes are omitted.
- Renderer-specific attributes are rejected on incompatible renderers.
- Unknown renderers and directions fail the entire layout before rendering.
- Segment counts above 64 and radial thickness beyond component bounds fail
  with the upper red diagnostics panel.
- All geometry is Venworks-authored native Scaleform vector drawing. Font
  Awesome and external assets are not required.

## Fixtures

- `meter-renderer-gallery.xml` uses compact upper-left and upper-right panels.
  It exercises continuous, rectangle, dot, uniform-triangle,
  alternating-triangle, reverse, vertical, clockwise, and counterclockwise
  rendering with 0%, partial, 50%, 75%, and 100% examples.
- `layout-invalid-meter-renderer.xml` uses an unsupported renderer.
- `layout-invalid-meter-direction.xml` uses an unsupported direction.
- `layout-invalid-segment-count.xml` exceeds the 64-segment runtime limit.
- `layout-invalid-radial-geometry.xml` makes the stroke thicker than the meter.

## Automated validation

The Goal 4D build must prove:

1. the positive gallery validates against `Schemas/VenworksCUI/layout-v1.xsd`;
2. schema-level and runtime-only negative fixtures fail at their intended gate;
3. all earlier positive fixtures remain schema-valid;
4. both generated movies contain 23 authored CUI classes and reopen with all
   190 expected ActionScript classes;
5. unrelated vanilla ActionScript remains textually identical;
6. required renderer, direction, alternating-pattern, radial, and diagnostic
   contracts survive JPEXS import and reopening; and
7. generated output hashes match the committed validation records.

## Required in-game validation

1. Confirm both compact gallery panels stay in the upper corners and leave the
   center and lower-right vehicle-control region usable.
2. Confirm the yellow alternating triangles match the supplied visual intent.
3. Verify whole and partial rectangle segments and partially filled dots.
4. Verify right, left, down, and up fill directions.
5. Verify empty, partial, and full radial arcs plus clockwise and
   counterclockwise direction.
6. Confirm the normal player HUD remains functional and unchanged.
7. Deploy each negative fixture and confirm the upper red diagnostics panel
   reports the intended error with no partial CUI gallery.
8. Restore `meter-renderer-gallery.xml` as `layout.xml` and repeat the available
   smoke test with the large HUD selection.

Goal 4D is accepted only after these in-game checks pass.
