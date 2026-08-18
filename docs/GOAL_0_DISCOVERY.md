# Goal 0 Discovery Report

> **Historical implementation evidence:** Current product intent, scope,
> delivery state, and acceptance are maintained in the Codecks `Documentation`
> and `Features` decks. The discovery evidence and technical findings below
> remain authoritative until deliberately superseded.

Date: 2026-08-06

## Outcome

Goal 0 establishes a viable direction but does not prove an end-to-end runtime.
Use vanilla Starfield SWF/GFX files, select an approved editor in Goal 1, and
probe adjacent XML loading in Goal 2. XML is recommended over TOML for the
first probe. Product implementation remains blocked on the editing-toolchain
decision and in-game probes.

## Evidence labels

- **Static:** observed in an inspected local file or archive.
- **Repository:** observed in tracked repository content/history.
- **Official documentation:** supported by vendor documentation.
- **Inferred:** a reasoned conclusion that still needs a probe.
- **Unknown:** evidence is not yet sufficient.

## Repository inventory

**Repository:** The repository has no .NET solution, compiler, application,
tests, runtime source, or independent Scaleform artifact. Its product content is
four sets of HONKCORE text configuration under `Staging-CF`, `Staging-FC`,
`Staging-TA`, and `Staging-VWKS`.

**Repository:** Each staging path is a local junction into a corresponding
Vortex mod directory. `Tools/sharedConfig.ps1`, `Tools/setupRepo.ps1`, and
`Tools/checkRepo.ps1` register and validate those junctions.

**Repository:** `.github/workflows/package-release.yml` packages the four
staging directories, attaches four ZIP files to a GitHub release, and optionally
uploads each variant to Nexus Mods.

**Repository:** The worktree was clean before Goal 0 documentation edits.

## Vanilla Starfield evidence

The configured game and Data folders existed. The loose Data interface folder
contained Vortex-deployed overrides and was rejected as vanilla evidence.
Bethesda's installed `Archive2.exe` 1.2.0.1 extracted 426 files from
`Starfield - Interface.ba2` into a system temporary directory without changing
the installation.

### Principal player HUD artifacts

| Artifact | Size | SHA-256 |
|---|---:|---|
| `interface/hudmenu.gfx` | 262487 | `8EFFDBCB42A8F3AF54BABD67FC78C78F837556EDD0D729BA789DCC768E551059` |
| `interface/hudmenu.swf` | 123739 | `4863C8E1426386A4A0FA69DEF7AF8D17B90EA19F32AD28E95527F08C223D6AF4` |
| `interface/hudmenu_lrg.gfx` | 262670 | `6C5101B06A495BD8C0E2A421E5EAEBB2A9FA34B4D352BFB004E5D766965BBB18` |
| `interface/hudmenu_lrg.swf` | 123792 | `0EA685FF49887AF9967EE5FC953F570F2845410ADF0A4B6981E80ED9091BEFE6` |
| `interface/playerhudcomponents.gfx` | 336575 | `936E88BA1F87AD1FDA5F23DEA5086505CDBC50DCA0C91F80E70A8BCC6A077DF4` |
| `interface/playerhudcomponents.swf` | 136947 | `50337DC181EAB672015D1BA8A8962233FBC139247E63946C4698B47333CA205E` |

**Static:** GFX files use the `GFX` signature; SWF files use compressed `CWS`
version 12. In-memory decompression exposed ActionScript 3 class and contract
strings.

**Static:** `hudmenu.swf` loads `PlayerHudComponents.swf`,
`HUDArtifactPowers.swf`, `HUDCrewBuffs.swf`, and HUD rollover movies. It refers
to provider/data contracts including `HudCompassData`, `HudCrosshairData`,
`HudEnemyData`, `HudJetpackData`, `HudStealthData`, `HUDVehicleData`, and
`HUDCrewBuffData`.

**Static:** `playerhudcomponents.swf` exposes observable contracts for player
health, oxygen/CO2, weapon/ammunition, boost, environment alerts/effects,
personal alerts/effects, compass markers, and ship-state flags. These strings
identify candidate contracts; they do not prove every value is available in
every lifecycle state.

### Principal ship UI artifacts

| Artifact | Size | SHA-256 |
|---|---:|---|
| `interface/spaceshiphudmenu.swf` | 193295 | `7061D7928DAA30619EBA926778116F6288177E2D04AEC674546A6A85100F491F` |
| `interface/spaceshiphudmenu_lrg.swf` | 193182 | `D5A2B16B512BE6E4F9C97960F707A599E85ED8476FA20619F69480B597E91505` |
| `interface/providers/shiphuddata.json` | 453 | `B3058CA3786583391F945CABA9389A07C1BEDF97D83386E1B945BDF648FCA092` |

**Static:** Ship scope is split across many movies, including
`spaceshiphudmenu`, `targetpanel`, `powerallocationcomponent`,
`spaceshippowergrid`, `shipreticle`, `shieldthrottlecomponent`,
`gravjumpcomponent`, `hailcomponent`, `shiphudquickcontainer`,
`spaceshipinfomenu`, `spaceshipeditormenu`, and shared assets. One HUD movie
does not own the complete requested ship UI.

**Static:** Candidate ship contracts include throttle, hull/shield health,
power allocation, target health/shield/range, weapons/ammunition, docking,
landing, grav jump, hailing, contraband scanning, cruise mode, repair, and
targeted-ship information. Interactive surfaces require separate input tests.

## External configuration format

### XML

**Official documentation:** Scaleform implements XML loading and DOM support.
Its file access is mediated by the host application's file opener. Scaleform's
ActionScript support table lists XML loading support.

**Static:** The vanilla HUD is ActionScript 3. The ship HUD contains Flash XML
class strings, but static strings do not prove Starfield enabled arbitrary
adjacent XML reads for this menu.

**Recommendation:** Use strict XML for the first probe because it avoids a
custom TOML parser and aligns with native Scaleform facilities. Keep layout and
palette in separate versioned documents.

### TOML

**Static:** No TOML parser or TOML configuration was found in the repository,
installed tools, or inspected vanilla Interface archive.

**Inferred:** TOML would require independently implementing and maintaining a
bounded parser inside ActionScript or preprocessing files. That conflicts with
the no-end-user-compiler direction and adds avoidable runtime complexity.

### JSON

**Static:** Vanilla HUD movies contain `com.adobe.serialization.json` decoder
classes, and the Interface archive contains provider test JSON. This proves JSON
parsing code and JSON test data exist, not that arbitrary adjacent JSON files
are loadable by the live HUD.

**Decision:** Retain JSON only as a fallback candidate if the XML probe fails.

## Runtime-build toolchain

**Static:** Bethesda Archive2 is installed and successfully extracts the
Starfield Interface archive.

**Static:** No `gfxexport`, GFx player, JPEXS/FFDec, SWF dump utility, Java, or
Node executable was found in the inspected command/path locations. .NET is
installed but is not part of the product architecture.

**External project evidence:** JPEXS Free Flash Decompiler documents AS1/2,
AS3, SWF, and GFX support and is GPL-3.0-or-later. Its own FAQ warns that direct
ActionScript editing is experimental. It is a candidate inspection/editor tool,
not an approved dependency or proven Starfield build path.

**Official documentation:** Autodesk documents GFxExport/GFxExport2 as the
official SWF-to-GFX preprocessing tools. Those tools were not found locally.

**Unknown:** Whether JPEXS can safely modify and save Starfield's version-12
SWF/GFX artifacts while preserving Bethesda extensions and all required
contracts.

**Goal 1 stop condition:** Obtain approval before installing or adopting a
tool. The first accepted tool must reproduce a loadable artifact and a minimal
visible change before schema/runtime work begins.

## Existing theme behavior inventory

Mechanical parsing found 38–57 configured blocks per variant and 22 distinct
target names. Thirty-five IDs are present in all four themes. Common behavior
includes defaults, boot sequence, health/O2/inventory meters, weapon/ammunition,
HUD information, heading/markers, radar-like presentation, boost, warnings,
scanner presentation, suit power, vignette, and quick-access UI.

The existing files also contain SPECTR/TACR-era targets. TACR is present in all
four and is explicitly excluded. No existing identifier or target name is
automatically a vanilla contract.

**Clean-room migration rule:** Record desired positions, dimensions, labels,
colors, opacity, shapes, and observable conditions. Re-express them in the new
schema only after mapping them to independently inspected vanilla contracts.
Do not translate HONKCORE parsing behavior or target implementations.

### Proposed example palettes

1. Venworks: navy, arctic white, ice/signal blue, amber, critical coral.
2. Freestar Collective: warm brown/black, amber/gold, pale foreground, red.
3. Crimson Fleet: black/deep red, crimson, pale foreground, muted teal.
4. Trackers Alliance: charcoal, red, pale foreground, muted steel blue.

The customizable base should include all four unless package-size or licensing
evidence later requires fewer. Palette files contain data only; layout remains
shared where behavioral differences do not require separate nodes.

## Proposed repository layout

```text
docs/
  CLEAN_ROOM.md
  CUSTOM_VUI_IMPLEMENTATION_PLAN.md
  GOAL_0_DISCOVERY.md
runtime/
  scaleform-source-or-workfiles/   # only after toolchain approval
schemas/
  layout/
  palette/
examples/
  Palettes/
Staging-CUI/
  Interface/
    hudmenu.gfx
    VenworksCUI/
      layout.xml
      Palettes/
      Assets/
```

Only the three documentation files are in Goal 0. All other paths are proposals
requiring later approval. Large-display (`_lrg`) and component/ship files must
be included when static/runtime evidence shows the modified root depends on
them.

## Required probes and unresolved questions

1. Approve and install/select an SWF/GFX editor or official exporter workflow.
2. Confirm a harmless vanilla-derived HUD modification loads from loose files.
3. Confirm load precedence between loose GFX/SWF and the Interface archive.
4. Confirm adjacent XML loads through Starfield's file opener.
5. Confirm relative path and filename-case behavior on PC and console package.
6. Confirm malformed/missing configuration fails safely.
7. Confirm SVG/PNG/JPEG loading/rendering paths.
8. Confirm every provider across the lifecycle matrix.
9. Inventory the exact owner movie for each ship surface before modification.

## Goal 0 decision

Proceed to Goal 1 only after the user approves a toolchain-evaluation plan.
Do not implement schemas, staging folders, or release workflow changes yet.
