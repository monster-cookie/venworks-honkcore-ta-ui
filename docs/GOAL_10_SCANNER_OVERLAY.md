# Goal 10 scanner overlay

> **Historical implementation evidence:** Current product intent, scope,
> delivery state, and acceptance are maintained in the Codecks `Documentation`
> and `Features` decks. The provider, ownership, and safety contracts below
> remain authoritative until deliberately superseded.

**Status: Implemented and build-validated on 2026-08-18; in-engine normal/large
HUD acceptance pending.**

Goal 10 implements Codecks card `$13z`, **Implement scanner in the new
customizable HUD**. The scanner state adds three passive surfaces:

1. a top `SCANNING` banner with the player's current heading;
2. a flickering 5-by-5 hash grid around the screen center; and
3. a right-side list of up to five validated contacts in front of the player.

The component adds no native plugin, SFSE dependency, persistence, input
handler, mock telemetry, or third-party dependency.

## Ownership and transition contract

Bethesda continues to own the scanner reticle, crosshair, interaction prompts,
scan highlights, and scanner command surfaces. The Venworks component is a
separate visual overlay and does not manipulate those display objects.

The production include is visible only while `inScanner` is true. That existing
condition is derived from `HudCompassData.bIsHandscannerOpen`. Entering scanner
mode therefore reveals one Venworks overlay; leaving scanner mode hides it and
restores the normal HUD without retaining a duplicate panel or mutated normal
state. Its flicker uses a bounded `Timer` that starts when the component enters
the stage and stops and resets when it leaves the stage. No `ENTER_FRAME`
listener is used.

In-engine acceptance must confirm that this composition does not overlap or
obscure Bethesda's scanner-owned controls in first person, third person, normal
HUD scale, and large HUD scale.

## Live-provider contract

The existing `CUIPlayerHudDataContext` already sends `HudCompassData` through
`CUITacticalAwarenessModel`. Goal 10 extends that tactical snapshot with a
`scannerTargets` array rather than adding another provider subscription or
expanding the already large data-context class.

Candidates are read, in precedence order, from:

- `HudCompassData.aEnemyMarkers`;
- `HudCompassData.aMissionMarkers`; and
- `HudCompassData.aMarkers`.

A record is eligible only when all of the following are true:

- `uiHandle` is finite and nonzero;
- `uiMarkerIconType` is finite and is enemy (`5`), companion (`8`), parked ship
  (`10`), parked-vehicle position (`13`), or vehicle (`14`);
- `fHeading` is finite and nonnegative; and
- `fDistanceToPlayer` is finite and nonnegative.

Duplicate nonzero handles are removed across all three arrays. At most 64
validated candidates are projected into the snapshot, bounding provider work
independently of the presentation limit.

## Contact presentation

The production fragment configures a 90-degree field of view. The component
normalizes each candidate's heading relative to `fDirection`, keeps only the
forward half-field, sorts nearest first, and uses handle and marker type as
deterministic tie breakers. `maxTargets` is configurable from 1 through 5; the
production value is 5.

Each row shows:

- a deterministic type/handle codename, such as a hostile `HST-*` identifier;
- `L`, `C`, or `R` relative direction with a bounded degree offset; and
- rounded `fDistanceToPlayer` with no unit suffix.

The codename uses the same two-state deterministic mixing approach established
for the player display serial, but its input is marker type plus handle and its
output is six characters. It does not consume or expose actor, creature,
mission, ship, or location names. Empty scans show `NO VALID CONTACTS`.

The distance remains deliberately unitless. Existing runtime evidence proves
the provider field is suitable for consistent HUD ranging but does not prove a
real-world unit such as meters. The component must not append a unit until that
meaning is established in live testing.

## Layout and configuration

The production fragment is
`Scaleform/shared/fixtures/components/scanner-overlay.xml`. Its `900 x 520`
root is included at `x=0`, `y=0`, anchor `center`, and `z=109`. The fragment
contains exactly one `scannerOverlay` component with:

| Attribute | Production value | Valid range or meaning |
| --- | ---: | --- |
| `fieldOfView` | `90` | 30 through 180 degrees |
| `maxTargets` | `5` | 1 through 5 rows |
| `flickerIntervalMs` | `140` | 50 through 2000 milliseconds |
| `scanningColor` | `#62DDF2` | Heading and scanner state |
| `gridColor` | `#FFB51B` | 5-by-5 center grid |
| `contactColor` | `#F2F7F9` | Non-hostile contacts |
| `hostileColor` | `#FF5A5A` | Enemy contacts |
| `backgroundColor` | `#020B10` | Bounded panel backing |

The center grid deliberately leaves its middle hash empty so Bethesda's
reticle remains visually owned and unobscured.

## Implementation map

- `CUITacticalAwarenessModel.as` validates, deduplicates, bounds, and codenames
  scanner candidates.
- `CUIScannerOverlay.as` renders heading, grid, contacts, and timer-driven
  flicker.
- `CUIRuntime.as`, `CUILayoutParser.as`, and `CUICompositionResolver.as`
  register and route the component.
- `layout-v1.xsd` defines its bounded configuration contract.
- `scanner-overlay.xml` and `chronomark-provider-probe.xml` compose the
  scanner-only production layout.
- `compileScaleform.ps1` validates schema rejection, ActionScript retention,
  production composition, noninteractive/provider-free XML, four-variant
  staging, and byte-identical loose payloads.

## Validation plan

Build validation completed on 2026-08-18:

- the modified PowerShell build script parsed successfully;
- the production layout and scanner fragment passed XSD validation while the
  invalid `maxTargets="6"` fixture was rejected;
- `Tools/checkRepo.ps1` passed its environment and four-variant junction checks;
- the regenerated seed retained one numbered ABC linkage domain containing
  every authored class, including `CUIScannerOverlay`;
- the normal and large HUD movies compiled, reopened, and passed the scanner
  registration, data-safety, timer-lifecycle, schema, and artifact assertions;
  and
- the layout, scanner fragment, other production fragments, and both HUD movies
  staged successfully for VWKS, CF, FC, and TA with byte-identical loose CUI
  payloads.

| Artifact | SHA-256 |
| --- | --- |
| `hudmenu.gfx` | `CFD823ED456B41B216285835B138CB2076BDAAD4B743349FCC9745275631D928` |
| `hudmenu_lrg.gfx` | `6A7B9577FDA08CAA33F0EECA75E098F225FA059BF6CEBBADB27B5B26B356F728` |

The remaining validation is the in-engine acceptance matrix below.

Static/build validation:

1. Regenerate `Scaleform/shared/patches/cui-component-abc-seed.xml` from the
   complete ActionScript source set.
2. Run `Tools/checkRepo.ps1`.
3. Run `Tools/compileScaleform.ps1` with the approved Java, JPEXS, vanilla
   interface, work, and four staging paths.
4. Confirm the invalid six-target fixture fails schema validation.
5. Confirm both HUD artifacts match committed SHA-256 records and every loose
   scanner fixture is byte-identical across VWKS, CF, FC, and TA staging.

In-engine acceptance:

1. Enter and leave scanner mode repeatedly; confirm exactly one overlay appears
   and the normal HUD restores exactly.
2. Confirm the heading tracks the player's facing direction through north and
   the `359 -> 0` wrap.
3. Confirm all 24 noncentral hashes remain visible and flicker without a dark or
   full-screen frame.
4. Confirm every listed contact corresponds to a valid forward provider record,
   nearest-first ordering is stable, and empty scans show `NO VALID CONTACTS`.
5. Confirm Bethesda's reticle, interaction prompts, highlights, and scanner
   command bar remain usable and unobscured.
6. Repeat in first person, third person, normal HUD, large HUD, after save/load,
   after death/reload, on ladders, at workbenches, and across ship transitions.

## Risks and rollback

The main remaining risk is provider semantics: mission or general marker
delivery can vary by game state, and formal vehicle type `14` has not been
observed in prior runtime testing. The implementation fails closed on malformed
records, shows only the established type allowlist, and never fabricates a
contact.

The overlay's fixed logical bounds may require layout tuning after normal and
large HUD screenshots. Such tuning must preserve the centered reticle opening
and scanner-owned Bethesda surfaces.

Rollback is isolated: remove the `scanner-overlay` include and staged fragment,
then remove `scannerOverlay` registration and its tactical snapshot projection.
No save data, schema migration, external configuration, or native component
must be reverted.
