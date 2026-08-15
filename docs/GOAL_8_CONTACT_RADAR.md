# Goal 8 upper-left contact radar

**Status: Goal 8A diagnostic implementation.** Production rendering remains
gated on runtime evidence. Goal 7 is complete and is not reopened by this work.

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

These hashes identify the diagnostic build to commit before deployment. They
are not production Goal 8B hashes and must be replaced after the temporary
probe is removed.

## Rollback

Remove the `radar-probe` layout include and diagnostic fragment, the bounded
diagnostic subscriptions and sources, and the matching build/staging checks.
No persistent data, schema migration, or native component requires recovery.
