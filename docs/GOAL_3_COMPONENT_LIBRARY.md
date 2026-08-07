# Goal 3 Component Library Report

Date: 2026-08-06

## Outcome

Implementation and static validation passed. The first in-game pass confirmed
the layout and geometric components. Corrected text rendering awaits retest.

Goal 3 establishes a clean-room, component-first runtime before any real HUD
surface is converted. Both player HUD variants now load
`Interface/VenworksCUI/layout.xml`, validate a strict version 1 subset, and
render a fixed component gallery. A valid document produces no success banner.
Missing, malformed, unsupported, or invalid input displays an error-only panel
at stage position `x=720`, `y=150`, sized 620 by 150 pixels.

The gallery is intentionally not connected to player health or any other live
Starfield value. Its only purpose is to validate composition and reusable meter
renderers without changing vanilla HUD behavior.

## Implemented components

- nested group with transforms, opacity, visibility, and z-order;
- runtime-resolved Starfield-font text;
- filled/stroked rectangular panel;
- rectangle or ellipse shape;
- horizontal, vertical, or diagonal divider;
- shared meter contract using a referenced style;
- continuous bar renderer;
- stacked-triangle renderer with partial final-segment fill;
- hidden-on-success diagnostics panel.

The broader required component inventory is maintained in
`docs/COMPONENT_CATALOG.md`.

## Runtime document

Runtime path:

`Interface/VenworksCUI/layout.xml`

The staged document is byte-for-byte identical to
`Scaleform/shared/fixtures/component-gallery.xml`. It uses a 1920-by-1080 design
space and displays continuous and triangle meters at fixed values, including
triangle states at 0, 50, and 100 percent.

The authoritative developer schema is:

`Schemas/VenworksCUI/layout-v1.xsd`

The ActionScript parser independently enforces the runtime subset because the
game does not run XSD validation. It rejects unknown elements and attributes,
unsupported versions or renderers, duplicate IDs, invalid references, invalid
colors, nonfinite values, negative bounds, and out-of-range opacity.

## Clean-room build design

JPEXS command-line script import can replace an existing ActionScript class but
does not add a new class to a vanilla movie. The build therefore injects one
small Venworks-authored ABC seed containing placeholder definitions for the 13
owned runtime classes. JPEXS then replaces only those placeholders and the
patched vanilla `HUDMenu` document class from temporary source exports.

The committed seed contains only Venworks-owned bytecode. Complete Bethesda
XML exports, decompiled source, vanilla GFX files, JPEXS, and the JDK remain
outside Git. During each build, the script verifies that:

1. the vanilla input hash matches the recorded game artifact;
2. exactly one named Venworks ABC seed is inserted;
3. all 13 authored classes compile and reopen;
4. the class count increases from 167 to 180;
5. every class other than `HUDMenu` and the 13 Venworks classes remains
   textually identical to the vanilla export;
6. the runtime contains the required layout and diagnostic contracts;
7. Goal 2 success-probe strings are absent; and
8. the output hash matches the validation record before it is staged.

## Outputs

| Artifact | Size | SHA-256 |
|---|---:|---|
| `Staging-CUI/Interface/hudmenu.gfx` | 279184 | `2EB3ECD4F109E1C2A89D9B14E14AD1FC7F516BC8204E4CE5F3E38BDBD7F254BF` |
| `Staging-CUI/Interface/hudmenu_lrg.gfx` | 279367 | `E5DBF7FEC83E8BDDEC326B55D48F004E3FFDBCE8EDE4721C969E9E8979C6E635` |
| `Staging-CUI/Interface/VenworksCUI/layout.xml` | 4714 | `06FAB39C4621C194E3407A649C846B0008D7B18719E518B84E3A980AE27CF8EB` |

## First in-game result

The normal-HUD test displayed the gallery at the expected position. The panel,
divider, ellipse, continuous bar, triangle bar, empty segments, full segments,
and partial final-triangle clipping all rendered correctly while the vanilla
HUD remained functional.

The first build displayed gallery text as missing-glyph blocks. Vanilla HUD
text fields reference locale-linked font classes, while the CUI fields are
created dynamically. Setting `embedFonts` to false did not resolve that class
alias and produced the same result in-game. The current build resolves
`$MAIN_Font_Bold` through `getDefinitionByName`, registers the linked class,
and reads its actual locale-specific font name before enabling embedded glyphs.
This preserves Japanese and Simplified Chinese mappings instead of hardcoding
the English `NB Architekt` name. The correction compiled, reopened, preserved
all other vanilla classes, and reproduced the hashes above. Its visible result
remains an in-game gate.

## In-game validation plan

Test without another mod overriding `hudmenu.gfx` or `hudmenu_lrg.gfx`. Fully
restart Starfield between configuration cases.

1. Deploy the staged files and load a save.
2. Confirm the component gallery appears near the middle of the screen, every
   heading and label is readable, and the normal vanilla HUD remains functional.
3. Confirm there is no success message or diagnostics panel after a valid load.
4. Inspect the continuous 65-percent bar and triangle bars at partial, 0, 50,
   and 100 percent. The partial bar should show a clipped final triangle rather
   than rounding to a whole segment.
5. Temporarily deploy each failure fixture as
   `Interface/VenworksCUI/layout.xml` and confirm the upper error panel is clear,
   nonfatal, and does not obscure the bottom-center play area:
   - `layout-malformed.xml` -> `CUI LAYOUT MALFORMED`;
   - `layout-unsupported.xml` -> `CUI LAYOUT UNSUPPORTED`;
   - `layout-unknown-component.xml` -> `CUI LAYOUT INVALID`;
   - `layout-invalid-reference.xml` -> `CUI LAYOUT INVALID`;
   - `layout-duplicate-id.xml` -> `CUI LAYOUT INVALID`;
   - `layout-invalid-bounds.xml` -> `CUI LAYOUT INVALID`.
6. For the missing case, disable deployment or rename `layout.xml` only after
   Vortex deployment is complete, then restart and expect `CUI LAYOUT MISSING`.
7. Restore the staged gallery and confirm a clean valid load again.
8. Exercise health, oxygen/CO2, weapon/ammunition, compass, crosshair,
   notifications, scanner, first/third person, save load, and ship transitions.
9. Test both the normal and large UI selection where possible.

## Acceptance rule

Accept Goal 3 when the gallery and every practical error case render as
described, the vanilla HUD remains functional, and both HUD-size variants load.
Do not connect a component to live health or another provider until the user
reviews the in-game gallery and approves the next goal.
