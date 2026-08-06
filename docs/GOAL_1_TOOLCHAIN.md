# Goal 1 Scaleform Toolchain Report

Date: 2026-08-06

## Outcome

JPEXS Free Flash Decompiler 26.2.1 can parse and surgically rewrite the
vanilla Starfield `hudmenu.gfx` and `hudmenu_lrg.gfx` artifacts without
changing their normalized tag structure. Two bootstrap test movies replace the
vanilla `Boost` text definition with a yellow `VENWORKS CUI TEST` label.

Static validation passed. In-game validation is pending and remains the release
gate for accepting this toolchain.

## Tools

### Bethesda Archive2

- Installed version: 1.2.0.1 for Genesis.
- Purpose: extract vanilla files from `Starfield - Interface.ba2` into temporary
  research storage.
- The Starfield installation was read only.

### JPEXS Free Flash Decompiler

- Version: 26.2.1.
- Source: official GitHub release `version26.2.1`.
- Portable ZIP SHA-256:
  `0333B56998A55BD83F4E0DEB678A811FCDC45607582B4F5DD438309C8C3AD5CE`.
- Matching source ZIP SHA-256:
  `8A318C9621884B1D3B7675DA0778E2672FACA5804165CC6CE4909853349F2093`.
- License: GPL-3.0-or-later for the application; bundled components retain
  their documented licenses.
- Installation: temporary portable extraction only.

### Eclipse Temurin

- Runtime: Eclipse Temurin OpenJDK JRE 21.0.12+8 LTS, HotSpot, x64 Windows.
- Portable ZIP SHA-256:
  `B8AA18FEF5EDB69BEE8618F99677D66D0873D22CB40D974C15AC9FFCDECF73BA`.
- License files were present in the portable runtime, including GPLv2 and the
  Classpath Exception.
- Installation: temporary portable extraction only; no registry or PATH
  changes.

## Vanilla inputs

| Artifact | Size | SHA-256 |
|---|---:|---|
| `interface/hudmenu.gfx` | 262487 | `8EFFDBCB42A8F3AF54BABD67FC78C78F837556EDD0D729BA789DCC768E551059` |
| `interface/hudmenu_lrg.gfx` | 262670 | `6C5101B06A495BD8C0E2A421E5EAEBB2A9FA34B4D352BFB004E5D766965BBB18` |

JPEXS reported both inputs as:

- SWF/GFX version 12;
- uncompressed GFX;
- 1920 by 1080 stage;
- one frame at 30 frames per second;
- not encrypted.

The standard movie identifies its exporter name as `HUDMenu`; the large movie
identifies it as `HUDMenu_LRG`.

## Modification

Character ID 73 is an existing `DefineEditText` used by the vanilla `Boost`
label. JPEXS's formatted-text importer changed only that definition in each
movie:

- text: `VENWORKS CUI TEST`;
- color: `#ffff00`;
- font class: `$MAIN_Font_Bold`;
- font size: 18;
- expanded text bounds to accommodate the probe label.

No ActionScript source, bytecode, timeline placement, imported movie, provider
contract, or root class was edited.

## Bootstrap outputs

| Artifact | Size | SHA-256 |
|---|---:|---|
| `Staging-CUI/Interface/hudmenu.gfx` | 262501 | `053FC4DC0BD55237F805AACD6D3C72F955A21CA18C76B01335103A48D1672825` |
| `Staging-CUI/Interface/hudmenu_lrg.gfx` | 262684 | `DCE9D29DC7AF390283DDA5B064183F0B1500C369A41E4219F1C7A6C68BC62FDE` |

The bootstrap staging path is temporarily a normal repository directory. After
these files are committed, the user will move/copy its contents into the Vortex
mod folder and replace `Staging-CUI` with the normal repository junction.

## Static validation

- JPEXS opened and dumped both vanilla GFX inputs successfully.
- JPEXS reopened and dumped both outputs successfully.
- Output headers retained GFX version, stage, frame count, and frame rate.
- Formatted-text export from each output returned the expected label, style,
  and bounds.
- The standard normalized tag sequence retained all 4,628 dump entries.
- The large normalized tag sequence retained all 4,620 dump entries.
- Normalized source/output tag differences: zero for both variants.
- JPEXS rendered frame 1 for both outputs without a parser/rendering failure.

The static render does not supply live Starfield providers or menu state, so it
does not display the conditional Boost label and cannot replace the in-game
test.

## Required in-game validation

Deploy the exact two output hashes above through the Customizable UI Vortex
mod. Test both normal and large UI selection where possible.

1. Start from a clean save/menu transition with no HONKCORE HUD movie active.
2. Confirm the HUD loads without a missing-menu, freeze, or input failure.
3. Equip/use a boost pack and trigger the vanilla Boost presentation.
4. Confirm `VENWORKS CUI TEST` appears in yellow where `Boost` normally appears.
5. Confirm health, oxygen/CO2, weapon/ammunition, crosshair, compass, enemy
   health, scanner, and notifications still update.
6. Test first person, third person, scanner open/close, save load, death/reload,
   ladder use, workbench entry/exit, and ship entry/exit.
7. Report which UI size variant was active and any log or visual anomaly.

## Acceptance rule

Accept JPEXS as the initial runtime editing tool only if both the visible probe
and lifecycle checks pass with the exact artifact hashes. A failure is evidence
against this editing path; do not begin XML-loading work until the cause is
understood and a new plan is approved.
