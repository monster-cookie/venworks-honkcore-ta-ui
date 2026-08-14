# Goal 7 equipment rail

**Status: Goal 7A FavoritesData discovery diagnostic is implemented and awaits
runtime evidence. The selected production rail is not implemented yet.**

## Product direction

Goal 7 replaces the passive upper-right weapon presentation with one compact
helmet-integrated equipment rail. The selected target spans from the lower edge
of the upper helmet brow to the top of the Planet Data region and keeps the
center field of view clear.

The production target reserves:

1. twelve compact favorite-slot contacts, with empty contacts dimmed;
2. contact 13 for the active weapon;
3. contact 14 for the active grenade or mine; and
4. contact 15 for the active power.

Weapon contacts should show the weapon icon, ammunition type, and ammunition
counts. Consumables should show their count. Powers should show icon and name.
The active weapon, explosive, and power may be highlighted simultaneously.
The contacts are passive status displays, not on-screen buttons.

## Provider classification

### Confirmed in HUDMenu

| Concept | Provider fields | Classification |
| --- | --- | --- |
| Active weapon | `WeaponData.sWeaponName`, `sIconLinkageName` | Confirmed in HUD |
| Weapon ammunition | `WeaponData.uClipAmmo`, `uTotalAmmo`, `bDisplayAmmo`, `bShowAmmoAsPercent` | Confirmed in HUD |
| Equipped ammunition name | `PlayerInventoryData.aItems[*].WeaponInfo.sAmmoType` | Confirmed in HUD for the equipped weapon |
| Explosive count/type | `WeaponData.uExplosiveCount`, `uExplosiveIndicatorType` | Confirmed in HUD; identity and icon are not proven |
| Active power | `HUDStarbornPowersData.sKey`, `bHasSpell`, `fCost`, `uCooldown` | Confirmed in HUD; name mapping is available, icon is not proven |

### Confirmed elsewhere or menu-owned

Vanilla `favoritesmenu.swf` subscribes to `FavoritesData`. Its root consumes
`aFavoriteItems` and `uStartingSelection`. Each visible favorite item may expose
`uQuickkeyIndex`, `sName`, `iconImage`, `bIsEquippable`, `bIsPower`,
`sAmmoName`, `uAmmoCount`, `uCount`, and `iFixtureType`. The menu also uses
`ImageFixture`, `LoadImageFixtureFromUIData`, and `FavoritesIconBuffer`.

These contracts prove Favorites Menu ownership only. They do not prove that
`FavoritesData`, its image buffer, or its selection semantics are available or
lifetime-safe in `HUDMenu`.

### Unknown before Goal 7A runtime

- whether `FavoritesData` is delivered before Favorites Menu opens;
- whether it is delivered or refreshed while the HUD remains open;
- whether the favorite array is dense, sparse, or compacted;
- the exact relationship between array index and `uQuickkeyIndex`;
- whether `uStartingSelection` means current menu cursor, equipped favorite, or
  another menu-owned state;
- whether `iconImage` and its underlying image buffer can render in HUDMenu;
- the identity and icon of the active grenade or mine; and
- an active-power icon source.

No production slot, active-state, or icon behavior will be inferred from these
unknowns.

## Goal 7A bounded diagnostic

The diagnostic subscribes to `FavoritesData` from the existing HUD data
context. It is a 1160-by-196 top-center strip shown only while the scanner is
active. It records provider receipt count, at most 32 root field names, the raw
`uStartingSelection` value, favorite-array availability and length, and at most
12 array entries.

Each entry has two bounded lines. The metadata legend is:

```text
S##  diagnostic row
A#   source array index
Q#   raw uQuickkeyIndex
EQ#  bIsEquippable
PW#  bIsPower
FX#  iFixtureType
IMG# iconImage presence only
```

The second line shows a bounded name, ammunition name/count, and item count.
Missing members display `-`. The probe does not render `iconImage`, does not
load the Favorites Menu image buffer, and does not treat `uStartingSelection`
as an equipped or active state.

## Runtime evidence matrix

After the user commits and deploys the built artifacts, capture the diagnostic
in these states:

1. scanner opened immediately after loading a save, before Favorites Menu has
   been opened during that session;
2. Favorites Menu opened and closed without changing a slot;
3. assign, move, and remove favorite entries, then reopen the scanner;
4. switch and fire a favorited weapon;
5. use a favorited consumable;
6. favorite and activate a power;
7. favorite, equip, cycle, and use a grenade or mine; and
8. save, reload, and inspect before reopening Favorites Menu.

For each capture, record whether the provider was received, its update count,
the root selection value, array length, and all affected `A`/`Q` rows. This is
the minimum evidence needed before implementing the production 1-15 rail.

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

The build must compile and reopen normal and large HUD artifacts, validate the
bounded ActionScript and XML contracts, stage the loose diagnostic in all four
variants, and prove byte-identical staged payload hashes across variants.

On 2026-08-14, repository validation and the complete normal/large build
succeeded. The build reopened all 205 seeded and generated classes, passed the
FavoritesData source and staged-layout contracts, and proved byte-identical
payload hashes across the VWKS, CF, FC, and TA staging variants.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 405190 | `6CB4EE1D2BCE7A278A810E2549606AE54E09F4AB7E7F9FB4616876876EC16ABA` |
| `hudmenu_lrg.gfx` | 405373 | `9F581008CE6124065331E6BB23955B99FFCDF1B4F8329C77D3AA0BB667B087F2` |
| `VenworksCUI/layout.xml` | 5746 | `221B8580C5304A08D0C52E73228593087F9C6F44B7B9DEEE856CF015827B4E14` |
| `components/favorites-provider-diagnostic.xml` | 9547 | `6B0B3C6FA43B0941BAC4C1B9B3D20F9F8C9D1FF9592F12A74EE67F7263F5693C` |
| `components/player-status-scanner.xml` | 8643 | `031D4BD34954325A6ADE5A19293EFA831A36C420FF14115F133C82138659876D` |
| `components/environmental-hazard-scanner.xml` | 9411 | `B13E5559452491AB62F0F05990F2553BAFA91BA589E3D103BAC31FF260B10526` |
| `components/weapon-status.xml` | 4455 | `81FF1E81CC4647736A4C360C131BDF68D84D566338268BFF2AEC68D508248894` |

## Risks and rollback

The diagnostic is scanner-gated and bounded, but `FavoritesData` may never be
delivered in HUDMenu. That negative result is useful evidence and leaves the
accepted Goal 6 production panels unchanged. Rollback is surgical: remove the
diagnostic include and fragment plus the FavoritesData subscription and
diagnostic bindings. No save data, native plugin, schema, dependency, or
configuration changes are introduced.
