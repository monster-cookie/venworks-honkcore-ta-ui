# Goal 7 equipment rail

**Status: Complete.** The production equipment rail is implemented, built, and
staged in all four variants. Runtime visual and behavior acceptance completed
on 2026-08-15 in the available keyboard/mouse test environment. The temporary
full-screen FavoritesData diagnostic and the retired standalone weapon panel
are not present in the production layout or staging payloads. Bethesda's
control-map path structurally retains controller/remapping presentation, but a
controller was not separately exercised and is a non-blocking verification
limitation.

## Product direction

Goal 7 replaces the passive upper-right weapon presentation with one compact,
helmet-integrated tactical loadout ribbon. The 720-by-747 design-unit group
offsets the top-right safe-area anchor by 64 units so its outer edge lands on
the physical right edge. It begins at screen coordinate 72 and terminates at
screen coordinate 819, exactly where Planet Data begins. Its owned curved path
keeps every contact fully over a tightly fitted, 24-percent-maximum translucent
fill; there is no opaque rectangular backing, cyan outer arc, or decorative
guide. The silhouette widens through its middle to contain live contacts 13-15,
then curves inward only at the bottom return to meet the existing 360-unit
Planet Data width. Favorite contacts 1 and 12 share an exact mirrored endpoint,
while both favorite halves step evenly toward the center live-contact group.
The contacts follow the silhouette from beneath the upper helmet brow into
Planet Data while leaving the center field of view clear. The ribbon no longer
extends beneath Planet Data, so the separately authored surfaces meet without a
hidden underlap or horizontal join seam.

The rail contains fifteen passive contacts:

1. contacts 1-12 display the latest bounded `FavoritesData` snapshot with
   Bethesda's current Quickkey glyph/name and compact ammunition or stack
   count when meaningful;
2. contact 13 displays the live weapon icon, name, ammunition type, clip, and
   reserve values;
3. contact 14 displays `NO THROWABLE`, `GRENADE`, or `MINE` from the live
   explosive count/type pair; and
4. contact 15 displays the live active-power name.

The visual order is contacts 1-5, centered live contacts 13-15, then contacts
6-12. Favorite rows use two levels: Bethesda's current hotkey, generic icon,
and item name on the first line, then authoritative ammunition or stack count
on the second line. The live contacts use strong gold outlines and deliberately
have no fake `13`, `14`, or `15` key labels because they describe independently
equipped state rather than favorite inputs.

The contacts are status displays, not buttons. They do not handle input,
replace Favorites Menu ownership, or imply that the player can activate a
contact by clicking it. Bethesda's vehicle-exit prompt remains available in a
separate `inVehicle`-conditioned group centered in the fixed lower helmet seal.

## Provider evidence

### Confirmed in HUDMenu

| Concept | Provider fields | Production use |
| --- | --- | --- |
| Favorite snapshot | `FavoritesData.aFavoriteItems[0..11]` | Contacts 1-12 preserve array order and empty slots. |
| Favorite text/type | `sName`, `bIsPower`, `sAmmoName`, `uAmmoCount`, `uCount` | Bounded name/detail text and generic power/weapon/item icon selection. |
| Favorite hotkeys | `ControlMapData.vMappedEvents`, `Quickkey1..12` resolved by Bethesda's `ButtonKeyHelper` | Current PC/controller/remapped key presentation on contacts 1-12. |
| Active weapon | `WeaponData.sWeaponName`, `sIconLinkageName` | Live contact 13 and exact favorite-name highlighting. |
| Weapon ammunition | `WeaponData.uClipAmmo`, `uTotalAmmo`, `bDisplayAmmo`, `bShowAmmoAsPercent` | Live contact 13 ammunition values. |
| Equipped ammunition name | `PlayerInventoryData.aItems[*].WeaponInfo.sAmmoType` | Live contact 13 ammunition label. |
| Explosive count/type | `WeaponData.uExplosiveCount`, `uExplosiveIndicatorType` | Live contact 14 generic category and count. |
| Active power | `HUDStarbornPowersData.sKey`, `bHasSpell`, `fCost`, `uCooldown` | Mapped live name in contact 15 and exact favorite-name highlighting; Bethesda key `ArtifactPower_ElementalBlast` maps to the displayed `Elemental Pull` name. |

### Runtime discovery results

The temporary Goal 7A probe established that:

- `FavoritesData` is delivered to HUDMenu as a fixed twelve-entry array;
- null/empty contacts are preserved rather than compacted;
- the snapshot refreshes after Favorites Menu closes;
- changing the active weapon, power, grenade, or mine does not independently
  refresh the FavoritesData snapshot;
- `uStartingSelection` did not identify the highlighted or active contact and
  is not a production input;
- `uQuickkeyIndex` and `iFixtureType` were absent in the captured HUD payload;
- `iconImage` was present for populated entries, but its menu-owned image
  buffer was not proven safe or lifetime-valid in HUDMenu; and
- grenade and mine favorites were visible by name, while the live HUD
  provider supplied only a generic explosive category and count.

The probe was deliberately removed after this evidence was accepted. No
production source or staged loose file contains its diagnostic bindings.

## Production behavior

Contacts 1-12 use generic same-domain CUI icons and Bethesda's current
Quickkey presentation. A favorite is classified as a power when `bIsPower` is
true and as a ranged weapon when a nonempty ammunition name is present. An
ammo-less entry remains a generic item until its normalized name exactly
matches the independently live weapon name; at that point it is classified as
the active melee weapon. Missing entries display `EMPTY`. Favorite detail text
occupies a dedicated second line and is intentionally blank unless the entry
has meaningful ammunition or stack quantity, in which case only the compact
count is shown; redundant `ITEM`, `POWER`, and weapon-type wording is omitted.

Favorite weapon and power contacts become active only when their bounded,
trimmed, case-insensitive names exactly match the independently live weapon or
mapped power name. The implementation does not infer active state from
`uStartingSelection`, `bIsEquipped`, menu cursor position, or stale snapshot
state. Item and explosive identity cannot be highlighted from the currently
confirmed live HUD contract. In particular, a grenade or mine favorite remains
neutral even when the corresponding generic live explosive category is active:
the live provider does not identify the exact favorite and the accepted
implementation does not guess from names or stale menu state.

Contacts 13-15 remain live even when the FavoritesData snapshot is stale.
Contact 14 intentionally reports only `NO THROWABLE`, `GRENADE`, or `MINE` plus
the count; exact explosive identity and an independently renderable active
explosive icon remain unproven. This is an accepted bounded fallback and may be
revised after visual runtime review.

## Implementation boundaries

- No SFSE or native dependency is introduced.
- No save data, persistence, schema migration, environment variable, or
  configuration path is added.
- No menu-owned image buffer is loaded into HUDMenu.
- The rail has no button, action, callback, or routed-input element.
- Both normal and large HUD movies use the same production layout contract.
- All four staging variants receive byte-identical loose XML and compiled HUD
  artifacts.

Dynamic text may intentionally declare `value=""` when it also declares a
live `source` or `valueTemplate`. Static text with neither binding still
requires a nonempty value. The initial equipment-rail build exposed that the
runtime parser applied the static rule unconditionally before bindings were
created. The corrected parser and build regression distinguish these cases, so
the twelve favorite-detail fields remain genuinely blank until data publishes
without weakening validation for authored static labels.

## Validation and artifacts

Run:

```powershell
./Tools/checkRepo.ps1
```

```powershell
./Tools/compileScaleform.ps1 `
  -JavaPath "<approved-java-path>" `
  -JpexsJarPath "<approved-ffdec-path>" `
  -VanillaInterfacePath "<approved-vanilla-interface-path>"
```

On 2026-08-15, the corrected complete normal/large Scaleform build succeeded.
It compiled and reopened all 205 seeded and generated classes, validated the
bounded ActionScript and XML contracts, accepted the twelve source-bound empty
favorite-detail fallbacks, resolved all twelve Quickkeys through Bethesda's
control-map helper, retained rejection of an empty static-text fixture,
rejected the opaque rail, retired diagnostic/weapon fragments and input hooks,
validated the exact `1-5, 13-15, 6-12` visual order, enforced the
physical-right-edge include, exact Planet Data termination, bottom-center
vehicle prompt, single-path containment, a bottom-only Planet Data return,
mirrored and uniformly stepped two-line favorite rows, 20-unit name/detail
fields, magenta active chevrons, and gold live contact outlines, and proved
byte-identical payload hashes across VWKS, CF, FC, and TA staging.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 408518 | `3A6AF5E152ED0BC9146C9BFB05AADD549BB2AFF8C94B81D3BF21478A156A2773` |
| `hudmenu_lrg.gfx` | 408701 | `AC600A04272FE03762B4A17C18B62EB6D3069D2314AADD9884461F1141156C04` |
| `VenworksCUI/layout.xml` | 6279 | `4143B59B71E8009D16B15D926C9BA4F67188FA8336C8135F9F50DDC60617AF2B` |
| `components/equipment-rail.xml` | 29096 | `0ACCCBDBE7963076DF26D11C21FC9AC2B48EE3B270303F44CA5A607AE3819597` |
| `components/player-status-scanner.xml` | 8643 | `031D4BD34954325A6ADE5A19293EFA831A36C420FF14115F133C82138659876D` |
| `components/environmental-hazard-scanner.xml` | 9411 | `B13E5559452491AB62F0F05990F2553BAFA91BA589E3D103BAC31FF260B10526` |

## Runtime acceptance

On 2026-08-15, the user deployed the exact artifact set recorded above and
accepted the final runtime presentation as functional. The supplied final
runtime evidence confirms the following closeout results:

1. the full-screen diagnostic is absent from the production HUD;
2. the tightly fitted transparent ribbon lands on the physical right edge,
   replaces the opaque rectangular rail, contains every contact over its fill,
   omits the former cyan arc/guide, widens through its middle around contacts
   13-15, curves inward only at the bottom to meet Planet Data, terminates at
   the panel top without extending behind it, and does not clip;
3. contacts read top-to-bottom as 1-5, live weapon/explosive/power, and 6-12,
   with mirrored outer endpoints, evenly stepped favorite halves, and every row
   contained by the ribbon;
4. contacts 1-12 preserve empty slots, refresh from Favorites Menu, show the
   current keyboard/mouse Quickkey plus icon/name on line one, show meaningful
   ammunition or stack counts without clipping in the 20-unit second-line
   field, and use a distinct magenta `>` for an exact active weapon or power
   match;
5. Elemental Pull fills contact 15 and its mapped favorite contact receives the
   active accent;
6. ranged and melee weapons fill contact 13, with exact matching favorites
   receiving the weapon presentation and active accent;
7. contact 14 switches among the bounded throwable states with the live count,
   never displays `UNKNOWN`, and leaves favorite explosives intentionally
   neutral because Bethesda does not identify the exact equipped favorite;
8. contacts 13-15 use strong gold outlines without fake hotkey labels;
9. the vehicle-exit presentation remains independently owned by the fixed
   bottom-center helmet seal; and
10. the accepted production HUD remained functional and error-free during the
    final runtime review.

These results close Goal 7. Controller glyph switching remains structurally
owned by Bethesda's control-map helper and is not an incomplete Goal 7
implementation requirement.

## Risks and rollback

Favorite names can be localized or duplicated, so exact name matching is a
bounded presentation heuristic rather than an inventory identity contract.
Explosive identity remains generic, so end-user documentation must state that
favorite grenade/mine rows cannot receive an authoritative active highlight.
One Starfield crash occurred during the
rejected opaque-rail build, but Windows produced no application event, dump, or
relevant log; no causal claim is possible. If a crash repeats during weapon
switching, capture the time and any new log before expanding this scope.
Rollback is surgical: remove the `equipment-rail` include and fragment and
remove the bounded FavoritesData adapters. No persistent state or native
component needs recovery.
