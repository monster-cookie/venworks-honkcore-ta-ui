# Goal 4B Fixed-Data Composition

> **Historical implementation evidence:** Current product intent, scope,
> delivery state, and acceptance are maintained in the Codecks `Documentation`
> and `Features` decks. The composition contract and evidence below remain
> authoritative until deliberately superseded.

Date: 2026-08-07

## Scope

Goal 4B adds reusable, fixed-data composition to the configuration-only CUI
runtime. A layout author can define a primitive component tree once, place it
multiple times, generate bounded lists, and choose one declared state. This
goal does not read live Starfield data, evaluate conditions, hide vanilla HUD
elements, load assets, or add meter renderers.

Existing Goal 3 and Goal 4A layouts remain valid. `schemaVersion` and
`runtimeVersion` remain `1` because all new elements are optional.

## Templates and instances

A template belongs in `definitions`, has exactly one root `group`, and may use
only the implemented primitives: group, text, panel, shape, divider, and meter.
Template-local component IDs may be reused by another template.

```xml
<definitions>
  <meterStyle id="health.continuous" renderer="continuous"
              fillColor="#35E6E6" emptyColor="#183B48"
              fillOpacity="1" emptyOpacity="0.7" />
  <template id="health.card">
    <group id="root" x="0" y="0" width="360" height="116"
           opacity="1" visible="true" rotation="0"
           scaleX="1" scaleY="1" z="0">
      <text id="title" x="18" y="13" width="324" height="30"
            opacity="1" visible="true" rotation="0"
            scaleX="1" scaleY="1" z="1"
            value="HEALTH" font="$MAIN_Font_Bold" fontSize="18"
            color="#F7FCFF" bold="false" align="left" />
      <meter id="meter" x="18" y="58" width="324" height="18"
             opacity="1" visible="true" rotation="0"
             scaleX="1" scaleY="1" z="1"
             style="health.continuous" value="50" max="100" />
    </group>
  </template>
</definitions>
<components>
  <instance id="player.health" template="health.card"
            x="-24" y="-24" anchor="bottom-right" z="100">
    <override target="title" text="PLAYER HEALTH" />
    <override target="meter" meterValue="75" />
  </instance>
</components>
```

An instance supplies its own `id`, `x`, `y`, optional `anchor`, optional
`visible`, and `z`. The template retains its declared dimensions, appearance,
and child layout. Descendant IDs are automatically prefixed with the instance
ID, so the example resolves `title` as `player.health.title`.

The intentionally small override surface is:

- `text` for a text component;
- `meterValue` for a meter component; and
- `visible` for any target component.

An override must name a component in the selected template and must match the
target type. Arbitrary attributes, interpolation, scripts, expressions, and
method calls are rejected.

## Repeaters

A repeater creates multiple instances of one template. Supported flows are
`vertical`, `horizontal`, and `grid`.

```xml
<repeater id="status.rows" template="status.row"
          x="24" y="0" width="236" height="180"
          anchor="center-left" visible="true" z="100"
          flow="vertical" gapX="0" gapY="12" columns="1">
  <item id="hunger">
    <override target="label" text="HUNGER" />
  </item>
  <item id="unused" visible="false">
    <override target="label" text="HIDDEN" />
  </item>
  <item id="thirst">
    <override target="label" text="THIRST" />
  </item>
</repeater>
```

An item with `visible="false"` is not rendered and does not reserve a slot.
The following visible item collapses into its place. The runtime accepts at
most 64 declared items and rejects output that does not fit inside the
repeater's configured `width` and `height`. Grid repeaters require one through
16 columns; non-grid repeaters use `columns="1"` when the attribute is present.

## Static state selection

A state declares up to 16 named options and selects exactly one by name. Every
option is validated, including options that are not selected.

```xml
<state id="status.mode" selected="warning"
       x="0" y="24" anchor="top-center" z="100">
  <option name="normal" template="status.normal" />
  <option name="warning" template="status.warning">
    <override target="label" text="WARNING SELECTED" />
  </option>
</state>
```

Selection is fixed configuration in Goal 4B. Conditions and live game state
are not accepted yet.

## Safety limits

- At most 64 templates per layout.
- At most 64 items per repeater.
- At most 16 options per state.
- At most 512 resolved components in the final tree.
- Templates contain primitives only and cannot recursively instantiate other
  templates.
- IDs, template references, overrides, item bounds, and selected options are
  validated before the component layer renders.
- A failure leaves the configurable component layer empty and uses the
  independent upper diagnostics panel.

## Fixtures

- `Scaleform/shared/fixtures/composition-gallery.xml` exercises two instances,
  all three repeater flows, a collapsed hidden item, every approved override,
  and one selected state. It is the staged Goal 4B layout.
- `layout-unknown-template.xml` is rejected by the XML schema.
- `layout-invalid-override.xml` is schema-valid but rejected by the runtime
  because a panel receives a text-only override.
- `layout-repeater-overflow.xml` is schema-valid but rejected because the
  visible items exceed the declared repeater bounds.
- `layout-invalid-state.xml` is schema-valid but rejected because the selected
  option is not declared.

## Automated evidence

- The existing absolute gallery, anchor gallery, staged layout, and Goal 4B
  composition gallery validate against `Schemas/VenworksCUI/layout-v1.xsd`.
- The unknown-template fixture is rejected by the schema key reference.
- Both vanilla-derived HUD movies compile, reopen, and retain 182 expected
  ActionScript classes, including 15 Venworks-authored CUI classes.
- The build verifies that unrelated vanilla ActionScript remains unchanged and
  that the reopened movies contain the composition resolver and its failure
  contracts.

## Required in-game validation

1. Deploy the staged CUI package and verify the left and right template cards,
   warning state, vertical list, center grid, and bottom horizontal list render.
2. Confirm the right card has no circular badge and that its meter differs from
   the left card.
3. Confirm the vertical list shows `ALPHA`, `BETA`, and `GAMMA` with no blank
   slot for the hidden item.
4. Replace staged `layout.xml` with each runtime-negative fixture in turn and
   verify the upper red panel reports an invalid layout with no partial gallery.
5. Restore `composition-gallery.xml` as `layout.xml` and verify the gallery
   returns after the HUD reloads.

Goal 4B is accepted only after these runtime checks pass. The immediate next
goal is conditions plus allowlisted vanilla visibility adapters, so a layout
can safely control which verified default HUD pieces remain visible.
