# Goal 8 upper-left contact radar

**Status: Goal 8B production implementation awaiting runtime acceptance.** Goal
7 is complete and is not reopened by this work.

## Product direction

The upper-left helmet cluster will contain an always-active, heading-relative
contact radar and a theme-owned crest. It is not a terrain minimap. The
Venworks theme will use the owned `venworks-logo.svg`; raster loading remains
retired. The former `SUIT SYSTEMS ONLINE` presentation is omitted because no
Bethesda-owned aggregate has been proven to represent suit, helmet, boost-pack,
and combination-suit readiness truthfully.

The requested production vocabulary is:

- red dot for an aggressive contact;
- blue dot for a defensive contact;
- green dot for a passive contact;
- white dot for a player ally;
- purple square for the player; and
- white square for the player's ship or occupied/nearby vehicle.

A 300-unit radius is the target only if Bethesda exposes a meaningful distance
field and unit in the persistent HUD. None of these disposition, ally,
ship/vehicle, or range meanings may be inferred from appearance or array
membership.

The radar remains present while aiming and while the scanner is open. Scanner-
specific presentation and scanner-owned behavior belong to a later goal.

## Provider classification before runtime

| Concept | Candidate | Classification |
| --- | --- | --- |
| Player heading | `HudCompassData.fDirection` | Confirmed in HUDMenu vanilla code. |
| General contacts | `HudCompassData.aMarkers` | Confirmed in HUDMenu vanilla code. |
| Mission contacts | `HudCompassData.aMissionMarkers` | Confirmed in HUDMenu vanilla code. |
| Enemy contacts | `HudCompassData.aEnemyMarkers` | Confirmed in HUDMenu vanilla code. |
| Contact heading | Marker `fHeading` | Confirmed in HUDMenu vanilla code. |
| Near/far state | Marker `bIsNear` | Confirmed in HUDMenu vanilla code; physical threshold unknown. |
| Relative elevation | Marker `uiRelativeMarkerHeightType` | Confirmed in HUDMenu vanilla code. |
| Marker type and location state | `uiMarkerIconType`, `uMapMarkerType`, `uMapMarkerCategory`, `uLocationMarkerState` | Confirmed in HUDMenu vanilla code. |
| Display distance effects | `fDistanceScale`, `fDistanceAlpha` | Confirmed as presentation inputs; physical distance and unit unknown. |
| Aggressive/defensive/passive disposition | Unknown marker field or array behavior | Unknown. |
| Player ally identity | Unknown marker field or array behavior | Unknown. |
| Ship and vehicle identity | Unknown marker field or marker type | Unknown. |
| Terrain or local-map geometry | Surface Map/menu-owned providers | Confirmed elsewhere only; not assumed HUDMenu-safe. |
| Equipped armor entries | `PlayerInventoryData.aItems[*]`, `bIsEquipped`, `ArmorInfo` | Confirmed in HUD runtime. |
| Suit/helmet/backpack category | Candidate `iFilterFlag` and equipment fields | Confirmed in Bethesda inventory presentation elsewhere; HUD payload presence unknown. |
| Starborn combination-suit semantics | Equipment fields | Unknown. |
| Faction/status payload | `PlayerStatusData` | Status Menu-owned; HUDMenu delivery unknown. Production crest does not depend on it. |
| Environmental protection | `EnvironmentEffectsData.fSoakDamagePct` | Confirmed in HUD, but represents protection reserve rather than equipment completeness. |

## Goal 8A diagnostic

The temporary `contact-radar-diagnostic.xml` surface is a passive, bounded
provider probe. It displays:

- the `HudCompassData` root heading, scanner flag, and up to 24 root field names;
- array counts and root distance/range/radius candidate fields;
- at most four general, four mission, and four enemy records;
- the vanilla-consumed marker fields plus at most twelve named disposition,
  actor, distance, ally, ship, or vehicle candidates per record;
- at most eight equipped armor entries with form/name/filter information and
  bounded equipment-category candidates; and
- `PlayerStatusData` receipt and at most 24 root field names.

Scalar values are sanitized and truncated to 48 characters. Arrays and objects
are reported by type rather than recursively serialized. The probe adds no
buttons, callbacks, mouse handlers, routed input, persistence, native code, or
menu-owned image buffers.

## Runtime matrix

Capture screenshots in a sparse exterior and around a passive civilian,
passive creature, defensive actor, aggressive enemy, follower/allied combatant,
player ship, and ground vehicle. Compare contacts at several known displayed
distances. Exercise ordinary suit/helmet/boost-pack equipment, remove one
component, and equip a Starborn combination suit. Also observe aiming, opening
the scanner, driving, entering/exiting a ship, and opening/closing Status Menu.

Runtime evidence must classify every desired production distinction as
confirmed, inferred, or unavailable. Missing fields are not evidence for a
negative state. `PlayerStatusData` remains menu-owned even if one stale payload
appears; production use would require lifecycle-safe updates.

## Production gate and limitations

Goal 8B requires a separate exact-file plan after Goal 8A evidence is accepted.
It will remove the complete diagnostic and may implement only distinctions
proven lifetime-safe in HUDMenu. If physical distance is unavailable, the radar
will use Bethesda's bounded marker visibility or a documented near/far rule
instead of claiming a 300-unit radius. If disposition or actor relationship is
unavailable, colors will be narrowed rather than guessed.

The production crest is configuration identity, not a claim about the player's
live faction membership. Suit-status text remains omitted regardless of the
contact-radar outcome.

## Runtime evidence and accepted production mapping

The accepted Goal 8A recording contained four nearby actors the player
identified as one aggressive enemy and three defensive enemies. All four were
delivered identically in `aEnemyMarkers` with `uiMarkerIconType=5`, Bethesda's
`MIT_MARKER_ENEMY`. No disposition field distinguished them. Production renders
the complete enemy array red and does not invent blue defensive or green passive
states.

Records that remained at the empty outpost used type 7,
`MIT_MARKER_LOCATIONS`; they are excluded rather than presented as actors.
Bethesda's confirmed type 8 companion marker renders as a white dot, while type
11 parked ship and type 15 vehicle markers render as white squares when present.
The player is an authored purple center square. Mission markers and unknown
general marker types fail closed. Opening the scanner did not change the feed,
so the radar remains always active and scanner-independent.

The payload exposed `bIsNear`, `fDistanceScale`, and `fDistanceAlpha` but no
physical distance with a proven unit. Production follows Bethesda's Watch
near/far radial presentation and makes no 300-unit claim.

While the player wore a Starborn suit, the equipment candidate selected a
weapon, jumpsuit, spacesuit, and grenade through the same broad `ArmorInfo`
test. `PlayerStatusData` was not delivered in HUDMenu. Neither route proves
combination-suit-safe readiness, so `SUIT SYSTEMS ONLINE` remains omitted.

## Build validation and diagnostic artifacts

On 2026-08-15, `Tools/checkRepo.ps1` passed and the complete normal/large
Scaleform build compiled, imported, reopened, and validated all 205 scripts in
both movies. It accepted the bounded 23-binding passive diagnostic, retained
the completed Goal 6 and Goal 7 contracts, and staged byte-identical HUD,
layout, and diagnostic payloads across VWKS, CF, FC, and TA.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 412089 | `28B96E3D761534D8E675ADDFEFD7AD97C34DEF3AC1776BB1CB78BF4A015C0792` |
| `hudmenu_lrg.gfx` | 412272 | `F454FE72DC51829129E48191178216511E72CAE153040CD94F98C910A53D12CE` |
| `VenworksCUI/layout.xml` | 6437 | `07092F40C575835EFB07C7497700CAC5F39071C74174E4913A97850728DE6BAF` |
| `components/contact-radar-diagnostic.xml` | 8764 | `26A004F0075A7BAF969B771CE4C2E2BD3D5653C2C9E8B99606EE16C86F409F13` |

These hashes are retained as Goal 8A diagnostic provenance. Production Goal 8B
hashes are recorded after the final build.

## Goal 8B production artifacts

On 2026-08-15, `Tools/checkRepo.ps1` passed and the final normal/large build
compiled, imported, reopened, and validated 207 scripts in both movies. The
inventory includes all 39 authored CUI classes, including both
`CUIContactRadar` and the pre-existing `CUIProviderSymbol`. The production
layout and component payloads staged byte-identically across VWKS, CF, FC, and
TA, and the retired Goal 8A diagnostic payload was removed from every variant.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 434755 | `A1B7217944DB51BF9BAC6CA4BB58A8C8E721D255D391BD7D31A3191EC6809824` |
| `hudmenu_lrg.gfx` | 434938 | `523FF7466E118C0A04B060B9F0800C91773F73837243D3F8C52487D1FB233B37` |
| `VenworksCUI/layout.xml` | 6427 | `BA609EE350472D48C428B1AAADAE5DE4C3AF86BA5E29CBD9A3DE61E27B6C70F7` |
| `components/contact-radar.xml` | 2637 | `BFA1CC6A30B87C21A02BE186B4B558B6D0461F1327F22539B9B51FA4F3D03E61` |

## Goal 8B runtime confirmation and visual refinement

On 2026-08-15, the single-domain production artifacts loaded successfully in
Starfield. The HUD, layout validation, and contact radar appeared operational,
confirming that the split-domain seed was the runtime regression and that the
one-domain correction resolved it.

Runtime review also established that the owned SVG already contains the
Venworks name, making the separate lower text label redundant. The accepted
refinement removes that duplicate and separates the crest panel from the radar
fragment. `faction-display` and `contact-radar` are now independent, always-on
by default layout includes: users may hide the faction display without hiding
the radar. Both move to the physical top edge; the faction panel extends to the
physical left edge and enlarges the SVG, while the radar retains its established
diameter and horizontal screen position. Provider semantics and radar behavior
remain unchanged.

The refinement build passed repository checks and the complete normal/large
Scaleform import, reopen, 207-script, authored-class, and single-domain
validation. Configuration payloads staged byte-identically across VWKS, CF,
FC, and TA. The HUD movies remain byte-identical to the runtime-confirmed
single-domain build because this refinement changes loose layout XML only.

| Visual-refinement artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 412164 | `CB87FE8BE725B5EA8038B0AC84EFFF8626C7E2630DE7B4DE0CE5610264BC9BF4` |
| `hudmenu_lrg.gfx` | 412347 | `645601579D3AB9B15ADD69C38CB46EA7E5CF4A3A7AB51F18D5A5D235B554DA55` |
| `VenworksCUI/layout.xml` | 6583 | `87649033E716119601D6EBD1D9D9C50C048A84D347E6CC59D9472B580D2D915E` |
| `components/contact-radar.xml` | 1898 | `3C4DBD797027CE2CE82BB839B2A88BFB6033EBF50C43686D015B9D42D0F447F5` |
| `components/faction-display.xml` | 889 | `12976D9AD512E0F0761F0CD70325FF0A895C9B9186B48526E96129A5E052B8E4` |

The next deployment passed composition but reported a stripped
`ReferenceError #1065` under the former broad `LAYOUT PARSING` phase. Because
that phase covered parser execution, asset-manager construction, and asset-load
startup, it did not identify the failing operation. A bounded diagnostic update
separates those phases, retains the component type and ID during validation,
and requests a stack trace when the runtime provides one. This changes only
failure reporting; contact selection and rendering remain unchanged.

The diagnostic build passed `Tools/checkRepo.ps1` and the complete normal/large
Scaleform import, reopen, and 207-script validation. Both movies staged
byte-identically across VWKS, CF, FC, and TA.

| Diagnostic artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 435523 | `4D2A691C2C56B6C08230C4B6619A1261CF24525487D824C19F67E86AD8CF5969` |
| `hudmenu_lrg.gfx` | 435706 | `3D821D12CF35C76733CAD905CC74879649311A279E46B52809587AB166B238C2` |

The detailed panel localized `ReferenceError #1065` to validation of the
unchanged `symbol #vehicle.exit.glyph`, where the parser first calls
`CUISymbol.isAllowlisted`. Historical comparison showed that Goal 7 used one
lazy seed ABC, while Goal 8 regeneration produced forty lazy ABC tags and put
`CUISymbol` in the terminal tag. The accepted next probe appends one inert,
seed-only terminator tag after `CUISymbol`. If the error clears or advances, the
result confirms terminal-slot loss; if it remains at the same call, fragmented
cross-ABC linkage remains the production root-cause candidate.

The terminal-slot probe passed `Tools/checkRepo.ps1` and the complete
normal/large Scaleform build. Both movies imported, reopened, and validated 208
scripts: the prior 207-script inventory plus the inert terminator. Reopened
movie structure confirms `CUISymbol` is penultimate and `CUISeedTerminator` is
the unique final seed tag. All four variants staged byte-identical artifacts.

| Terminal-slot probe artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 436030 | `0E41C1FA63CAEF9746D5C2C1EF4A12DD1E8D2D732919397B71C351D0CF1B15C5` |
| `hudmenu_lrg.gfx` | 436213 | `6B69CFC9011A744AD10A80A567F8866F99B4B2BF134800A297FC252D778A7683` |
| `cui-component-abc-seed.xml` | 209702 | `74B5D75F1E679DFA83A0C2C8EF0D52CCF1FF58A3E844B5B65DE27CDA23BEE057` |

Deployment hashes matched the terminal-slot probe, but runtime produced the
same `CUISymbol.isAllowlisted` `ReferenceError #1065`. The sentinel hypothesis
is therefore disproven. The regression is the Goal 8 generator's replacement
of the previously established single Venworks ABC domain with independent
per-class ABC units. The accepted production correction restores exactly one
Venworks seed ABC containing every dynamically discovered authored class. No
vehicle-exit, symbol, radar, layout, or provider behavior changes are required.

The corrected generator uses one synthetic root to make `mxmlc` compile all 39
authored CUI classes into one seed `DoABC2Tag`. The complete normal/large build
then passed import, reopen, single-domain, authored-class, and 207-script
validation. All four variants received byte-identical movies. These artifacts
supersede the terminal-slot probe:

| Single-domain production artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 412164 | `CB87FE8BE725B5EA8038B0AC84EFFF8626C7E2630DE7B4DE0CE5610264BC9BF4` |
| `hudmenu_lrg.gfx` | 412347 | `645601579D3AB9B15ADD69C38CB46EA7E5CF4A3A7AB51F18D5A5D235B554DA55` |
| `cui-component-abc-seed.xml` | 108599 | `CC18451CD585EDEAEA097DF52027DA5A2503B98C659322A7F39EE0A0A06DD561` |

Runtime confirmation remains required on the Starfield-capable system. The
expected result is that layout validation passes the unchanged
`#vehicle.exit.glyph` lookup and the contact radar reaches normal HUD startup.

## Rollback

Remove the `contact-radar` layout include and production fragment, unregister
the `contactRadar` component, and remove its bounded compass adapter. No
persistent data, schema migration, or native component requires recovery.

## Goal 8B runtime correction

The first production deployment displayed `CUI LAYOUT INVALID` with an unknown
`contactRadar` component during layout parsing. Hash comparison proved that the
deployed normal and large HUD movies were the intended Goal 8B artifacts. The
failure was not a Vortex conflict or stale deployment: `contactRadar` had been
registered in `CUILayoutParser` and `CUIRuntime` but omitted from
`CUICompositionResolver`'s leaf-component list. Because the radar is delivered
through an included fragment, composition rejected it before layout validation.

The correction registers `contactRadar` with the composition resolver and adds
a reopened-movie build assertion covering all three registration gates. Updated
artifact hashes supersede the initial Goal 8B table after the corrective build.

On 2026-08-15, `Tools/checkRepo.ps1` passed and the corrective normal/large
Scaleform build compiled, imported, reopened, and validated all 207 scripts in
both movies. The corrected movies and unchanged layout payload staged
byte-identically across VWKS, CF, FC, and TA.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 434779 | `BF5CA20615F292FDDE404465B04D4A8AA6D3D170B7FA355F48399D81565D16E6` |
| `hudmenu_lrg.gfx` | 434962 | `EC8A4295A459F8025C43A36671446AF088923C758847224297413EA2E4E5BA2A` |
| `VenworksCUI/layout.xml` | 6427 | `BA609EE350472D48C428B1AAADAE5DE4C3AF86BA5E29CBD9A3DE61E27B6C70F7` |
| `components/contact-radar.xml` | 2637 | `BFA1CC6A30B87C21A02BE186B4B558B6D0461F1327F22539B9B51FA4F3D03E61` |
