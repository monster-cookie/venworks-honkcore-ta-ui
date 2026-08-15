# Goal 7 equipment rail

**Status: The production equipment rail is implemented, built, and staged in
all four variants. Runtime visual and behavior acceptance remains required
before Goal 7 closes. The temporary full-screen FavoritesData diagnostic and
the retired standalone weapon panel are not present in the production layout
or staging payloads.**

## Product direction

Goal 7 replaces the passive upper-right weapon presentation with one compact,
helmet-integrated tactical loadout ribbon. The 720-by-650 design-unit group is
anchored at the upper right, 25 units from the physical edge and 92 units below
the upper edge. Its owned curved path hugs the right side with a 24-percent
maximum fill opacity; there is no opaque rectangular rail backing. The contacts
follow the curve from beneath the upper helmet brow to above Planet Data while
leaving the center field of view clear.

The rail contains fifteen passive contacts:

1. contacts 1-12 display the latest bounded `FavoritesData` snapshot along the
   curve (visually ordered 12 down to 1);
2. contact 13 displays the live weapon icon, name, ammunition type, clip, and
   reserve values;
3. contact 14 displays `NO THROWABLE`, `GRENADE`, or `MINE` from the live
   explosive count/type pair; and
4. contact 15 displays the live active-power name.

The contacts are status displays, not buttons. They do not handle input,
replace Favorites Menu ownership, or imply that the player can activate a
contact by clicking it. Bethesda's vehicle-exit prompt remains available at
the bottom of the rail.

## Provider evidence

### Confirmed in HUDMenu

| Concept | Provider fields | Production use |
| --- | --- | --- |
| Favorite snapshot | `FavoritesData.aFavoriteItems[0..11]` | Contacts 1-12 preserve array order and empty slots. |
| Favorite text/type | `sName`, `bIsPower`, `sAmmoName`, `uAmmoCount`, `uCount` | Bounded name/detail text and generic power/weapon/item icon selection. |
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

Contacts 1-12 use generic same-domain CUI icons. A favorite is classified as a
power when `bIsPower` is true and as a ranged weapon when a nonempty ammunition
name is present. An ammo-less entry remains a generic item until its normalized
name exactly matches the independently live weapon name; at that point it is
classified and labeled as the active melee weapon. Missing entries display
`EMPTY`.

Favorite weapon and power contacts become active only when their bounded,
trimmed, case-insensitive names exactly match the independently live weapon or
mapped power name. The implementation does not infer active state from
`uStartingSelection`, `bIsEquipped`, menu cursor position, or stale snapshot
state. Item and explosive identity cannot be highlighted from the currently
confirmed live HUD contract.

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

On 2026-08-14, the corrected complete normal/large Scaleform build succeeded.
It compiled and reopened all 205 seeded and generated classes, validated the
bounded ActionScript and XML contracts, accepted the twelve source-bound empty
favorite-detail fallbacks, retained rejection of an empty static-text fixture,
rejected the opaque rail, retired diagnostic/weapon fragments, and input hooks,
and proved byte-identical payload hashes across VWKS, CF, FC, and TA staging.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 408085 | `7479435DFD8D6FF92F51DB7CE1E12F8A68BC72D9CCA11924993F9021D4B534FF` |
| `hudmenu_lrg.gfx` | 408268 | `0800B0028033338F56DFF010FD8345B14A8F478F7082F7469F1F4E766DC65135` |
| `VenworksCUI/layout.xml` | 5553 | `6DD5576D820D7CCD0F7AF38C72D7079040723CCC1B61AF4DE83B06B0EA0E833E` |
| `components/equipment-rail.xml` | 30521 | `DCB53FA5DD908DE3AA5AE5204C944148211177FFF45F1E05EA0B8CC954A7ACB3` |
| `components/player-status-scanner.xml` | 8643 | `031D4BD34954325A6ADE5A19293EFA831A36C420FF14115F133C82138659876D` |
| `components/environmental-hazard-scanner.xml` | 9411 | `B13E5559452491AB62F0F05990F2553BAFA91BA589E3D103BAC31FF260B10526` |

## Runtime acceptance

After the user commits and deploys this exact build, verify:

1. the full-screen diagnostic is absent in scanner and ordinary HUD states;
2. the curved transparent ribbon replaces the opaque rectangular rail, fits
   between the upper brow and Planet Data, and does not clip;
3. contacts 1-12 preserve empty slots and refresh after Favorites Menu closes;
4. Elemental Pull fills contact 15 and its mapped favorite contact receives the
   active accent;
5. an equipped melee weapon fills contact 13 and its exact matching favorite
   contact receives the active weapon icon/accent;
6. contact 14 switches among `NO THROWABLE`, `GRENADE`, and `MINE` with the
   correct live count and never displays `UNKNOWN`;
7. vehicle exit remains readable and functional; and
8. normal and large-menu HUD variants remain error-free.

## Risks and rollback

Favorite names can be localized or duplicated, so exact name matching is a
bounded presentation heuristic rather than an inventory identity contract.
Explosive identity remains generic. One Starfield crash occurred during the
rejected opaque-rail build, but Windows produced no application event, dump, or
relevant log; no causal claim is possible. If a crash repeats during weapon
switching, capture the time and any new log before expanding this scope.
Rollback is surgical: remove the `equipment-rail` include and fragment and
remove the bounded FavoritesData adapters. No persistent state or native
component needs recovery.
