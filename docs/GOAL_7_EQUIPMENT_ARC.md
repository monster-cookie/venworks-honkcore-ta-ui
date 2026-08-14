# Goal 7 equipment rail

**Status: The production equipment rail is implemented, built, and staged in
all four variants. Runtime visual and behavior acceptance remains required
before Goal 7 closes. The temporary full-screen FavoritesData diagnostic and
the retired standalone weapon panel are not present in the production layout
or staging payloads.**

## Product direction

Goal 7 replaces the passive upper-right weapon presentation with one compact,
helmet-integrated tactical loadout rail. The 330-by-650 design-unit rail is
anchored at the upper right, spans from beneath the upper helmet brow to above
Planet Data, and leaves the center field of view clear.

The rail contains fifteen passive contacts:

1. contacts 1-12 display the latest bounded `FavoritesData` snapshot;
2. contact 13 displays the live weapon icon, name, ammunition type, clip, and
   reserve values;
3. contact 14 displays the live explosive category as `GRENADE` or `MINE` and
   its count; and
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
| Active power | `HUDStarbornPowersData.sKey`, `bHasSpell`, `fCost`, `uCooldown` | Mapped live name in contact 15 and exact favorite-name highlighting. |

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
power when `bIsPower` is true, as a weapon when a nonempty ammunition name is
present, and otherwise as an item. Missing entries display `EMPTY`.

Favorite weapon and power contacts become active only when their bounded,
trimmed, case-insensitive names exactly match the independently live weapon or
mapped power name. The implementation does not infer active state from
`uStartingSelection`, `bIsEquipped`, menu cursor position, or stale snapshot
state. Item and explosive identity cannot be highlighted from the currently
confirmed live HUD contract.

Contacts 13-15 remain live even when the FavoritesData snapshot is stale.
Contact 14 intentionally says only `GRENADE` or `MINE`; exact explosive identity
and an independently renderable active explosive icon remain unproven. This is
an accepted bounded fallback and may be revised after visual runtime review.

## Implementation boundaries

- No SFSE or native dependency is introduced.
- No save data, persistence, schema migration, environment variable, or
  configuration path is added.
- No menu-owned image buffer is loaded into HUDMenu.
- The rail has no button, action, callback, or routed-input element.
- Both normal and large HUD movies use the same production layout contract.
- All four staging variants receive byte-identical loose XML and compiled HUD
  artifacts.

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

On 2026-08-14, the complete normal/large Scaleform build succeeded. It compiled
and reopened all 205 seeded and generated classes, validated the bounded
ActionScript and XML contracts, rejected retired diagnostic/weapon fragments,
and proved byte-identical payload hashes across VWKS, CF, FC, and TA staging.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 407061 | `CEA7FD6FD462BCFB704F6F129913AFA532105F3735723FAA57B8263F3AAE1677` |
| `hudmenu_lrg.gfx` | 407244 | `A5E6E87E1572770E226AF58EDC667595F9C48FE765493FE9036E87099CA0FC0C` |
| `VenworksCUI/layout.xml` | 5553 | `D7DE6DCD1E3F8AD2E17ECAC7ADEBBEE0C49C96C176B20307634169CE495C3F44` |
| `components/equipment-rail.xml` | 31444 | `9AB149557453E6DE04EA005774F539A5154AFD966080FC6C7122FEF8319CD2E0` |
| `components/player-status-scanner.xml` | 8643 | `031D4BD34954325A6ADE5A19293EFA831A36C420FF14115F133C82138659876D` |
| `components/environmental-hazard-scanner.xml` | 9411 | `B13E5559452491AB62F0F05990F2553BAFA91BA589E3D103BAC31FF260B10526` |

## Runtime acceptance

After the user commits and deploys this exact build, verify:

1. the full-screen diagnostic is absent in scanner and ordinary HUD states;
2. the rail fits between the upper brow and Planet Data without clipping;
3. contacts 1-12 preserve empty slots and refresh after Favorites Menu closes;
4. live weapon and power contacts update without reopening Favorites Menu;
5. exact matching favorite weapon/power contacts receive the active accent;
6. contact 14 switches among no explosive, grenade, and mine with the correct
   live count;
7. vehicle exit remains readable and functional; and
8. normal and large-menu HUD variants remain error-free.

## Risks and rollback

Favorite names can be localized or duplicated, so exact name matching is a
bounded presentation heuristic rather than an inventory identity contract.
Explosive identity remains generic. Rollback is surgical: remove the
`equipment-rail` include and fragment and remove the bounded FavoritesData
adapters. No persistent state or native component needs recovery.
