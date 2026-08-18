# Goal 1 Scaleform Toolchain Report

> **Historical implementation evidence:** Current product intent, scope,
> delivery state, and acceptance are maintained in the Codecks `Documentation`
> and `Features` decks. The toolchain contract and validation evidence below
> remain authoritative until deliberately superseded.

Date: 2026-08-06

## Outcome

JPEXS Free Flash Decompiler 26.2.1 can parse and surgically rewrite the
vanilla Starfield `hudmenu.gfx` and `hudmenu_lrg.gfx` artifacts. The initial
probe changed the vanilla `Boost` text definition, but in-game testing showed
that Starfield replaces that initial value at runtime. The revised bootstrap
movies instead add an independent, always-visible yellow `VENWORKS CUI TEST`
label at bottom-center.

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

The revised probe starts from the clean vanilla movies and adds exactly three
root tags to each movie:

- a `DefineEditText` using unused character ID 354;
- a matching `CSMSettings` tag;
- a `PlaceObject2` at unused depth 1000.

The text uses `$MAIN_Font_Bold` at 18 pixels, color `#ffff00`, and centered
alignment. Its 300-pixel-wide bounds are placed at `(810, 990)` on the
1920-by-1080 stage, producing an always-visible bottom-center label. No
existing text definition, ActionScript source, bytecode, imported movie,
provider contract, or root class was edited.

## Bootstrap outputs

| Artifact | Size | SHA-256 |
|---|---:|---|
| `Staging-CUI/Interface/hudmenu.gfx` | 262656 | `79858EEEF487CF4E177ACCAF8442FCF39CFBEBAF9020F2A331678525313FACCF` |
| `Staging-CUI/Interface/hudmenu_lrg.gfx` | 262839 | `55F5331CD8003B7CF3161BD895FAEE135E9FA7797C12425B2E13327D17C22698` |

The bootstrap staging path is temporarily a normal repository directory. After
these files are committed, the user will move/copy its contents into the Vortex
mod folder and replace `Staging-CUI` with the normal repository junction.

## Static validation

- JPEXS converted both clean vanilla inputs to XML successfully.
- JPEXS rebuilt, reopened, and re-exported both revised outputs successfully.
- Output headers retained the GFX signature, version, stage, frame count, and
  frame rate.
- The standard tag count changed from 17,183 to 17,186.
- The large tag count changed from 17,175 to 17,178.
- Each output contains exactly one probe text value, character ID 354
  definition, character ID 354 placement, and depth 1000 placement.
- After removing those three probe tags, the re-exported XML is identical to
  vanilla after excluding calculated bit-width and byte-offset metadata.
- JPEXS rendered frame 1 for both outputs without a parser/rendering failure.

The static renderer does not resolve Starfield's imported `fonts_en.swf`
assets, so it cannot render this or the other imported-font HUD text. It does
confirm the bottom-center placement, but in-game testing remains required to
confirm the imported font and final presentation.

## Required in-game validation

Deploy the exact two output hashes above through the Customizable UI Vortex
mod. Test both normal and large UI selection where possible.

1. Start from a clean save/menu transition with no HONKCORE HUD movie active.
2. Confirm the HUD loads without a missing-menu, freeze, or input failure.
3. Load any save; no boost pack or gameplay action is required.
4. Confirm `VENWORKS CUI TEST` remains visible in yellow at bottom-center.
5. Confirm health, oxygen/CO2, weapon/ammunition, the vanilla crosshair,
   compass, vanilla enemy health, scanner, and notifications still update.
6. Test first person, third person, scanner open/close, save load, death/reload,
   ladder use, workbench entry/exit, and ship entry/exit.
7. Report which UI size variant was active and any log or visual anomaly.

## Acceptance rule

Accept JPEXS as the initial runtime editing tool only if both the visible probe
and lifecycle checks pass with the exact artifact hashes. A failure is evidence
against this editing path; do not begin XML-loading work until the cause is
understood and a new plan is approved.
