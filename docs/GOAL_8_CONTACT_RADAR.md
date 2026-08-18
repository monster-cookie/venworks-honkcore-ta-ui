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

The radar uses Bethesda's marker `fDistanceToPlayer` field with a fixed
200-provider-unit radius. Contacts are positioned proportionally against range
circles at 50, 100, 150, and 200 units and fail closed beyond the outer circle.
No real-world unit such as meters is claimed. Disposition, ally, and
ship/vehicle meanings are not inferred from appearance or array membership.

Production runtime evidence narrows the enemy presentation to a
**200-provider-unit acquired-threat radar**. It is not a life-form detector:
neutral creatures and harmless critters are not delivered, and potentially
hostile creatures generally do not appear until Bethesda's engine classifies
them as detected or hostile. Once acquired, hostile contacts use their delivered
distance normally and remain visible while retreating until they cross the
radar's 200-unit boundary. The radar does not discover actors, manufacture
positions, or infer hostility from an actor's appearance.

The radar remains present while aiming and while the scanner is open. Scanner-
specific presentation and scanner-owned behavior belong to a later goal.

## Provider classification before runtime

| Concept | Candidate | Classification |
| --- | --- | --- |
| Player heading | `HudCompassData.fDirection` | Confirmed in HUDMenu vanilla code. |
| General contacts | `HudCompassData.aMarkers` | Confirmed in HUDMenu vanilla code. |
| Mission contacts | `HudCompassData.aMissionMarkers` | Confirmed in HUDMenu vanilla code. |
| Enemy contacts | `HudCompassData.aEnemyMarkers` | Confirmed in HUDMenu vanilla code and runtime as an engine-filtered acquired-hostile channel; neutral creatures and harmless critters were not delivered. |
| Contact heading | Marker `fHeading` | Confirmed in HUDMenu vanilla code. |
| Physical/provider distance | Marker `fDistanceToPlayer` | Confirmed as the distance input used by HONKCORE MAPR for general, enemy, and mission records from persistent `HudCompassData`; production runtime acceptance remains required. |
| Near/far state | Marker `bIsNear` | Confirmed in HUDMenu vanilla code but retired from production radar placement because it provides only two nearly identical radii. |
| Relative elevation | Marker `uiRelativeMarkerHeightType` | Confirmed in HUDMenu vanilla code. |
| Marker type and location state | `uiMarkerIconType`, `uMapMarkerType`, `uMapMarkerCategory`, `uLocationMarkerState` | Confirmed in HUDMenu vanilla code. |
| Distance alpha | `fDistanceAlpha` | Confirmed as a presentation input and bounded to `[0,1]`; it is not used as physical range. |
| Marker scale | `fDistanceScale` | Confirmed as a Bethesda presentation input but rejected because unbounded transition values are unsafe for a pooled vector marker. Production scale is fixed at `1.0`; later runtime proved that fixed scale alone did not eliminate the blackout. |
| Aggressive/defensive/passive disposition | Unknown marker field or array behavior | Unknown. |
| Player ally identity | Unknown marker field or array behavior | Unknown. |
| Ship and vehicle identity | `uiMarkerIconType` values 10, 13, and 14 | Type 10 parked-ship and type 13 parked-vehicle-position delivery are runtime-confirmed; formal type 14 vehicle delivery remains unobserved. |
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

Goal 8B removed the complete diagnostic and implements only distinctions proven
lifetime-safe in HUDMenu. The initial near/far fallback was accepted before
`fDistanceToPlayer` was identified in HONKCORE MAPR. The fixed-range correction
uses that existing field without adding a provider. Disposition and actor
relationship remain unavailable, so colors stay narrowed rather than guessed.

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
Bethesda's confirmed type 8 companion marker renders as a white dot. Production
recognizes type 10 parked ships and type 13 parked-vehicle positions, both of
which runtime later confirmed in persistent HUD `aMarkers`; formal type 14
vehicles are also accepted but remain unobserved. The player is an authored
purple center square. Mission markers and unknown general marker types fail
closed. Opening the scanner did not change the feed, so the radar remains always
active and scanner-independent.

The initial probe conclusion recorded `bIsNear`, `fDistanceScale`, and
`fDistanceAlpha` but did not identify a physical-distance field. Later read-only
decompilation of HONKCORE MAPR showed that it reads `fDistanceToPlayer` from the
same persistent `HudCompassData` marker arrays. That evidence supersedes the
near/far fallback while leaving the provider and subscription unchanged.

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

## Provider-local event correction

Runtime testing after the independent-Watch correction showed that weapon and
grenade kills could still black the complete Starfield movie while an external
performance overlay remained visible. Console `kill` and `kah` did not trigger
the failure. The blackout also survived disabling damage numbers, disabling
floating markers, and using `tm`; the latter hides menu rendering but does not
stop subscribed ActionScript. Multiple weapons and a grenade reproduced the
same behavior, while vanilla and HONKCORE did not.

Source inspection found a Venworks-specific fan-out. Every provider handled by
`CUIPlayerHudDataContext` dispatched the same generic `Event.CHANGE`, and
`CUIRuntime.onValueChanged()` responded by applying every value binding and
redrawing every contact radar. A player-credited combat kill can publish weapon,
XP, player, and related provider updates together, causing repeated
`Shape.graphics` clearing and reconstruction even when `HudCompassData` did not
change. HONKCORE's MAPR instead updates directly from its compass subscription.
This provider fan-out is therefore the leading source-side cause of the
kill-event render-surface failure; the corrective build still requires runtime
confirmation before the blackout can be declared eliminated.

The correction gives compass delivery a radar-only event and carries normalized
changed-source lookups in Bethesda's existing `Shared.AS3.Events.CustomEvent`
for value and condition updates. Setters suppress unchanged values. Value
bindings match their primary, maximum, and text-template sources; visibility
bindings match the names used by their compiled expressions; vanilla adapters
also depend on HUD opacity. Bethesda HUD-mode updates reapply only the vanilla
adapters they own. Initial construction still performs one complete value,
radar, and visibility application, while live events reach only dependent
controls. The implementation adds no provider, authored class, persistence,
native code, input, or Watch ownership.

On 2026-08-16, `Tools/checkRepo.ps1`, `git diff --check`, and the complete normal/large
Scaleform build passed import, reopen, 207-script, 39-authored-class,
single-domain, unchanged-Watch, and provider-local routing validation. Both
movies staged byte-identically across VWKS, CF, FC, and TA. Runtime kill testing
remains required before treating the source-side correction as confirmed.

| Provider-local routing artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 416323 | `F54F97424CF34F63186D5B0044772084FD61A76D7CFA3DB59468B52D07DFBC95` |
| `hudmenu_lrg.gfx` | 416506 | `346C682452FE11DC2A29A2F9CDD558CF2B97901438829F8A9575A29B5699AFF4` |

Runtime confirmed that provider-local routing removed the general kill blackout
for ordinary weapons but left one reproducible case. A stock Rattler did not
black out; applying the same legendary set to a Rattler or AA-99 did. Replacing
Corrosive with Staggering did not change the result, while replacing
Bloodthirsty with Kismet removed it. Bloodthirsty also reproduced at full
health, so an unchanged displayed health value does not prove that its kill
transaction skipped HUD provider delivery.

The resulting product boundary is permanent: CUI will not replace, suppress,
restyle, or independently render Bethesda's enemy health bars or enemy
legendary/state indicators. HONKCORE demonstrated that customizing those
surfaces can break legendary enemy hit bars, so the vanilla UI remains their
sole lifecycle owner. Contact-radar presentation may consume the approved
compass contact data, but it must not take ownership of enemy health or
legendary-state presentation.

The accepted production hardening removes two remaining re-entrant rendering
paths. Live value, condition, compass, and HUD-mode callbacks now merge only
their domain-specific pending state and schedule one next-frame application.
Value-source and condition-name sets are unioned; compass and HUD-mode work use
the latest authoritative context state. The frame listener clears its scheduled
state before applying the snapshot, so delivery caused during rendering forms a
new batch for the following frame. Initial component construction remains a
direct one-time evaluation, and teardown removes any pending listener.

`CUIContactRadar` also retains all pooled marker geometry. Each of its 32 contact
containers prebuilds one red enemy dot, one white companion dot, and one white
ship/vehicle square. Live compass rendering selects a child style and changes
only bounded visibility, position, alpha, and fixed scale; it no longer clears
or draws vector graphics during an update. The 300-unit range, 10/13/14 mapping,
finite-transform checks, player marker, Watch independence, and layout remain
unchanged. Runtime testing with Bloodthirsty weapons is still required before
this correction can be accepted as eliminating the remaining blackout.

On 2026-08-16, `Tools/checkRepo.ps1` passed and the complete normal/large
Scaleform build compiled, imported, reopened, and validated all 207 scripts and
all 39 authored CUI classes in exactly one Venworks ABC linkage domain. Reopened
runtime assertions confirmed next-frame coalescing, provider-domain isolation,
frame-listener teardown, persistent contact styles, fixed marker scale, and the
absence of live radar vector clearing or drawing. Pinned Watch scripts remained
unchanged. Both movies staged byte-identically across VWKS, CF, FC, and TA.

| Frame-coalesced retained-radar artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 418521 | `B4C9CDFB556E62CA645FF6846307FF6A7600D98686DA8D8E3EA4792BCBDF4C34` |
| `hudmenu_lrg.gfx` | 418704 | `D8DF869D8939B0C8C4031A57D8432A0EF5FCADF85F0D41C32FE6F92BBE110FE3` |

Runtime rejected the frame-coalesced artifacts. The supplied 6.57-second
`weirdness.mp4` recording contains a detected black interval from 1.833 to 3.200
seconds, followed by stalled gameplay and delayed pause-menu response. This is
worse than the provider-local baseline and rejects the `ENTER_FRAME` queue as a
production design. Direct changed-source, changed-condition, compass, and
HUD-mode routing is restored from the responsive `c84e6c9` implementation.

The same deployment also disproved the radar as the remaining blackout source:
the black interval survived after all radar marker geometry became persistent
and live radar drawing was removed. Those retained markers remain because they
do not participate in the next isolation step.

Bloodthirsty delivers through `HUDPlayerFrequentData`, where
`player.healthPercentage` feeds exactly the Player Data health text and health
meter. Every production meter style uses `CUISegmentedBar`, which still clears
and reconstructs vector rectangles during accepted value changes. The next
controlled A/B therefore leaves `player-status-scanner.xml` staged but removes
its layout include, preventing construction and binding while retaining every
other HUD component. If the blackout disappears, the scanner is confirmed and
the next production change will restore it with retained segmented-meter
geometry. If the blackout remains, the scanner hypothesis is rejected and the
meter renderer will not be rewritten on that basis.

On 2026-08-16, `Tools/checkRepo.ps1` passed and the complete normal/large
Scaleform build imported, reopened, and validated all 207 scripts and all 39
authored CUI classes in exactly one Venworks ABC linkage domain. Reopened
assertions confirmed responsive direct routing, absence of the rejected
`ENTER_FRAME` queue, retained radar geometry, fixed marker scale, and omission
of the Player Data scanner include. Movies and the temporary layout staged
byte-identically across VWKS, CF, FC, and TA.

| Player Data isolation artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 416925 | `7E6C2A5D63607DD5B2E601079C4A0E408933602A2D9C5BC4EDD11157394ABEAA` |
| `hudmenu_lrg.gfx` | 417108 | `FFF8D3F659ED717DB62BF2C9AA2EFD5B9E54A7B928E5E99138269C5035DF1789` |
| `VenworksCUI/layout.xml` | 6415 | `29DE59E9A16670C9A92B981BD7937C3D92913261796C53E1F400B918F247D47A` |

Runtime rejected the Player Data hypothesis. General movement, aiming, weapon
switching, scanner use, pause response, and stock-Rattler kills had no new lag
or hang, but Bloodthirsty kills still produced the black surface at both full
and reduced health. Returning to the Bloodthirsty Rattler continued to
reproduce it. The Player Data scanner and its segmented health meter are
therefore restored without modification; the remaining blackout investigation
must move outside that rendering path. Responsive direct provider routing
remains accepted.

The same runtime session accepted proportional radar movement and produced a
preliminary estimate that enemy records were not delivered until approximately
150 provider units, based on comparison with a vehicle at that distance. Later
controlled acquisition and retreat tests, recorded below, supersede the simple
provider-culling interpretation. The accepted calibration reduces the radar
maximum to 200 provider units and uses circles at 50, 100, 150, and 200 units.
It does not claim to change Bethesda's acquisition rules or assign a real-world
unit to the provider value.

On 2026-08-16, `Tools/checkRepo.ps1` passed and the complete normal/large
Scaleform build imported, reopened, and validated all 207 scripts and all 39
authored CUI classes in exactly one Venworks ABC linkage domain. Reopened
assertions confirmed direct provider routing, absence of the rejected frame
queue, fixed 200-unit placement, fixed marker scale, the 10/13/14 mapping,
exact 50/100/150/200 rings, absence of a 300-unit ring, and restoration of the
Player Data include. Movies, layouts, and radar fragments staged byte-identically
across VWKS, CF, FC, and TA.

| 200-unit calibration artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 416925 | `0495A774042240E76B2AB93081DB5E6952BF66E56617C8781E10059019D1B108` |
| `hudmenu_lrg.gfx` | 417108 | `A1837FDF2E0D601970963502D738FED930DD2AB1922417A12370C12CA3394A97` |
| `VenworksCUI/layout.xml` | 6583 | `87649033E716119601D6EBD1D9D9C50C048A84D347E6CC59D9472B580D2D915E` |
| `components/contact-radar.xml` | 2433 | `49D6317ED00747D6F2074BB7658E5D4F9BC7A17D723650432299267230059F1D` |

### Enemy acquisition, retention, and Game Setting evidence

Controlled runtime testing established that initial enemy acquisition and radar
ranging are separate behaviors. Potentially hostile creatures first entered
`HudCompassData.aEnemyMarkers` when they detected or engaged the player, near
the 100-unit circle in the tested encounters. Once acquired, their red contacts
moved proportionally toward the player marker and remained delivered while the
player retreated; production rendering then hid them only after
`fDistanceToPlayer` crossed the radar's fixed 200-provider-unit boundary.
Neutral creatures and harmless critters did not appear. Attacking a neutral
creature is expected to make it eligible after its hostility state changes, but
that specific neutral-to-hostile transition has not been runtime-confirmed.

The live defaults were `fPerceptionCompassBase = 10000` and
`fPerceptionCompassMult = 3`, with the tested player reporting `Perception = 7`.
Changing the base to `10` delayed enemy presentation until effectively
point-blank range, proving that the setting can restrict compass eligibility.
Increasing it to `14000` or `200000` did not reveal unaware actors earlier, and
`10000` and `20000` produced the same retention behavior after hostility was
established. The setting therefore does not replace Bethesda's upstream
detection/hostility gate, and no non-default Game Setting override is justified
for the production radar.

The only additional result from the console's compass-name search was the AVIF
`MapMarkerMaxCompassDistanceMult`. That value belongs to ordinary map-marker
behavior used for locations, quests, and related map/radiant presentation; it is
not evidence of another `aEnemyMarkers` range control and must not be changed for
the contact radar. No other compass-named candidate was exposed by that search.

Eventual player-facing minimap/compass documentation must describe this surface
as a **200-provider-unit acquired-threat radar**, not a 200-unit life-form
detector. It must explain that neutral actors are absent, initial appearance is
controlled by Bethesda's detection/hostility classification, and the range
circles position only records that HUDMenu actually receives.

## Kill-event blackout hardening and provider evidence

A user-supplied runtime recording confirmed that killing an enemy obscured
gameplay with a black surface for approximately 1.5–2 seconds while other HUD
overlays remained active. The blackout cleared when the dying enemy marker
finished transitioning out, ruling out loss of video output and an ordinary
Starfield fade.

`CUIContactRadar.renderContact()` initially applied Bethesda's `fDistanceScale`
directly to the pooled vector marker. Its former guard rejected `NaN` and
non-positive values but allowed infinity and extreme finite values, making scale
one plausible path to an invalid Scaleform surface during enemy removal. The
first correction removed `fDistanceScale` from production rendering and assigned
both marker axes a fixed scale of `1.0`.

Runtime of the later fixed-range build confirmed that proportional
`fDistanceToPlayer` placement worked for enemies, the parked ship, and the
parked vehicle, but the exact same 1.5–2-second kill-event blackout returned.
Reopening the deployed movie confirmed that fixed scale and distance validation
survived compilation, so fixed scale was insufficient rather than regressed.
The remaining source-side failure path converted `fHeading` and root
`fDirection`, calculated trigonometric coordinates, and assigned them directly
to the pooled `Shape` without proving that the complete transform was finite.
The runtime evidence does not identify which transition field becomes invalid.

The accepted hardening hides the selected pooled marker before evaluation and
requires finite distance, heading, direction, intermediate vectors, radius,
final X/Y coordinates, and alpha before assigning display properties. Invalid
death/removal records fail closed for that update. Fixed scale, contact color and
shape, bounded alpha, the fixed purple player marker, and valid heading/range
placement remain unchanged.

The same recording showed no ship or vehicle square while the player approached
and stood directly beside a parked ship. The first correction placed a compact
line beside the radar, but runtime screenshot review showed that the narrow field
clipped the type list and was not part of the radar presentation. The accepted
follow-up removed diagnostic presentation from `CUIContactRadar` and temporarily
placed the complete marker count and unique numeric types in one wrapped
800-by-78 design-unit panel at the top center.

That probe completed its purpose. Beside the parked ship and vehicle it reported
`G:8 TYPES:4,7,10,13`. After the vehicle was driven away from the ship, the list
contained only types 4 and 7 while the player occupied the vehicle; type 13
appeared after the player exited. Bethesda's decompiled `MapMarkerUtils` maps
type 10 to `MIT_MARKER_SHIP_PARKED`, type 13 to `MIT_MARKER_POSITION`, and type
14 to `MIT_MARKER_VEHICLE`; `WatchIconsWidget` passes `uiMarkerIconType` directly
to that mapping. The evidence therefore confirms that persistent HUD
`aMarkers` delivers the parked ship as type 10 and correlates the type-13
position marker with the player's parked vehicle. Formal type 14 delivery has
not been observed.

The production radar accepts types 10, 13, and 14 as square contacts. The former
type-11 parked-ship and type-15 vehicle constants were incorrect: Bethesda maps
11 to `MIT_MARKER_OUTPOST` and defines no type 15 in this enum. The completed
probe removes the top-center group, its `diagnostic.compassmarkers` value, and
the count/type formatting routine. The existing `HudCompassData` subscription
and complete `currentCompassData` payload remain the radar's sole data path.

Subsequent runtime testing found that enemies, the parked ship, and the parked
vehicle stayed near the radar perimeter both at point-blank range and hundreds
of units away. The source cause was the production `bIsNear` placement, which
selected only `0.43` or `0.39` of the contact-area size and therefore represented
bearing without useful range. The existing heading calculation is algebraically
equivalent to HONKCORE's `fHeading - fDirection` calculation and remains valid.

HONKCORE MAPR normalizes each general, enemy, and mission marker as
`fDistanceToPlayer / currentRange`. The accepted Venworks refinement uses the
same marker field without copying MAPR's adaptive zoom or edge pinning. Venworks
instead fixes the range at 300 provider units, maps distance linearly from the
player center to the outer circle, and hides missing, invalid, negative, or
over-range contacts. The unchanged panel now has subdued circles at 100, 200,
and 300 units; 50-unit rings and range labels are omitted to avoid clutter.

On 2026-08-16, `Tools/checkRepo.ps1`, the complete normal/large Scaleform build,
and `git diff --check` passed. Both movies imported and reopened all 207 scripts,
retained all 39 authored classes in exactly one Venworks ABC linkage domain, and
passed the fixed-range, fixed-scale, 10/13/14 mapping, diagnostic-removal, and
100/200/300-unit staged-ring assertions. The movies and radar fragment staged
byte-identically across VWKS, CF, FC, and TA.

| Fixed-range production artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 412316 | `6D095FA99B4E81CFA672A6DD344ABC8A386150949DF87B3BBE908C9788ACB851` |
| `hudmenu_lrg.gfx` | 412499 | `25639CF8A5C8BD100E03B2ACC029B88ABE7DF56B4B494742F1D640560CEFD4D8` |
| `components/contact-radar.xml` | 2197 | `7348367E6DB247CBD4DF53876701DBC71CBC41BF5A8A7498130E8744922223E8` |

Runtime accepted the fixed ranging and ring behavior from this build but
rejected its kill-transition behavior because the blackout returned. These
artifact hashes remain the fixed-range baseline rather than final blackout
acceptance.

On 2026-08-16, the complete transform-hardening build passed
`Tools/checkRepo.ps1`, normal/large Scaleform import and reopening, all 207-script
and 39-authored-class checks, the single-domain rule, and `git diff --check`.
Reopened ActionScript retained finite validation for distance, heading, player
direction, intermediate vectors, final X/Y coordinates, and alpha before display
assignment. The normal and large movies staged byte-identically across VWKS,
CF, FC, and TA; no CUI XML payload changed.

| Transform-hardening artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 412630 | `E11CE98CDC5F324B99AE0F8C6F97A8066047EBB4E6BFBAD6A157211C5E332D43` |
| `hudmenu_lrg.gfx` | 412813 | `28C4068CCC2BE5CAABB3388FB284282175B4BC08D1B77F2DFEFF5EEB616900E2` |

Runtime acceptance requires repeated individual and rapid enemy kills without
the black surface while fixed 300-unit ranging remains correct.

Runtime subsequently rejected the transform-hardening artifact: the exact same
kill-event black surface remained even though the reopened custom radar proved
that every marker scale and coordinate assignment was finite and bounded. The
observation that an enemy first appeared near the 200-unit radar circle did not
provide a distance calibration because Bethesda's compass exposes no numeric
world range; the fixed 300-provider-unit mapping therefore remains unchanged.

A read-only comparison against HONKCORE 1.0.2 then disproved patching Bethesda's
Watch as the compatibility-safe correction. HONKCORE's decompiled
`WatchIconsWidget.as` is byte-identical to vanilla and retains the direct
`fDistanceScale` presentation path. HONKCORE MAPR is instead an independent
fixed-size `Shape` renderer driven by `fDistanceToPlayer`, while HONKCORE's
`visible=never` wrapper sets the original Watch display object's `visible`
property to `false`. Venworks had only assigned alpha zero, leaving the complete
transparent Watch render tree active.

The corrective visibility design keeps `WatchIconsWidget` and
`CompassMarkerWidget` unchanged. Each allowlisted vanilla target combines its
configured `visibleWhen` result with Bethesda's current `HudModeData` result and
assigns the target's real `visible` property. The HUDMenu bootstrap reapplies
that composed state after Bethesda updates its mode visibility. With the
production `bottomLeft visibleWhen="never"`, the Watch is removed from rendering;
changing it to `always` restores the original Watch under Bethesda mode control,
including compatibility with faction-logo replacements. The separately authored
contact radar remains on `VenworksCUIComponentLayer`, consumes the same provider
independently, and does not reference or reparent any Watch class.

On 2026-08-16, the complete corrective visibility build passed
`Tools/checkRepo.ps1`, normal/large Scaleform import and reopening, all
207-script and 39-authored-class checks, the single-domain rule, and
`git diff --check`. Build assertions also proved that the reopened
`WatchIconsWidget.as` and `CompassMarkerWidget.as` remained byte-identical to
their pinned vanilla sources. The normal and large movies staged
byte-identically across VWKS, CF, FC, and TA.

| Corrective visibility artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 413880 | `EC8F139BC5C52AC1D9FEE31A3CC9413CA47CAB5F1877CA16AA70FBEB22390E71` |
| `hudmenu_lrg.gfx` | 414063 | `D66B5FDFE189396B0F137E4631A59C6422754F4785219025F539A478751671C6` |

Runtime acceptance still requires repeated kill testing with the stock Watch
genuinely hidden and, where available, intentionally enabled.

On 2026-08-15, `Tools/checkRepo.ps1` passed and the complete normal/large
Scaleform build imported, reopened, and validated all 207 scripts and all 39
authored CUI classes in the single Venworks ABC linkage domain. The movies and
layout staged byte-identically across VWKS, CF, FC, and TA.

| Temporary top-center diagnostic artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 412769 | `435E1C07DB163128B166CDF33A319609382DD67E034E4A268D704D883EE2B34D` |
| `hudmenu_lrg.gfx` | 412952 | `A3A6F44EF2F53EB3C36DD8697C48121D954E6E4888BD587A21323D76D6B20A70` |
| `VenworksCUI/layout.xml` | 7444 | `B26644F0719D7184C6E034A3E40A5D9425E6979B8D270B72F80BAB30BD08D490` |

On 2026-08-16, the final radar-mapping and diagnostic-removal build passed
`Tools/checkRepo.ps1` and the complete normal/large Scaleform import, reopen,
207-script, 39-authored-class, and single-domain validation. The build assertions
confirmed the 10/13/14 mapping, fixed marker scale, absence of `fDistanceScale`,
continued compass delivery, and complete removal of the temporary diagnostic.
Movies and layouts staged byte-identically across VWKS, CF, FC, and TA.

| Final production artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 412184 | `E8DF143AFF9FCCD86EC3BB60837DD084C9401AFDDAAEA471BCC2F2CF33B75EB7` |
| `hudmenu_lrg.gfx` | 412367 | `6974FE83DA3F3842A98052543A5676034F2EF240F2402597B98FB8C1AB343FFA` |
| `VenworksCUI/layout.xml` | 6583 | `87649033E716119601D6EBD1D9D9C50C048A84D347E6CC59D9472B580D2D915E` |

Final runtime acceptance requires the debug panel to be absent, type-10 parked
ships and the type-13 parked-vehicle position to render as white squares, and no
unrelated position marker to produce a false contact. Enemy, ship, and vehicle
contacts must move continuously against the 100/200/300-unit circles and
disappear beyond 300 units. Enemy and companion dots, the fixed player marker,
and fixed contact scale must remain unchanged. Absence of kill-event blackouts
requires renewed runtime confirmation with the stock Watch both genuinely hidden
and, when available, intentionally enabled.

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
