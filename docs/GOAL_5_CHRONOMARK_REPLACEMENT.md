# Goal 5 Chronomark replacement

## Scope

Goal 5 is the first live-data player-HUD surface. The approved probe replaces
the complete vanilla bottom-left Chronomark presentation with a Venworks panel
that is always present while `hudmenu.gfx` is active. Scanner state does not
hide it. The existing `bottomLeft` vanilla-visibility adapter performs the
hide; no display path or method name comes from configuration.

This is a provider probe, not final visual acceptance. Its layout approximates
the old HONKCORE panel so the live fields can be verified in context. Styling
and spacing will be refined only after provider acceptance.

## Clean-room provider contract

The contract was derived from locally extracted vanilla Starfield interface
scripts and Bethesda data channels. HONKCORE was inspected only to identify
candidate Bethesda fields; no HONKCORE source, format, or implementation is
copied into CUI.

| CUI source | Vanilla provider and field | Kind | Status |
| --- | --- | --- | --- |
| `location.name` | `LocalEnvironmentData.sLocationName` | string | Confirmed in movie |
| `environment.oxygenPercentage` | `LocalEnvironmentData.fOxygenPercent` | number | Confirmed in movie |
| `environment.temperature` | `LocalEnvironmentData.fTemperature` | number | Confirmed in movie |
| `environment.gravity` | `LocalEnvironmentData.fGravity` | number | Confirmed in movie |
| `environment.localTime` | `LocalEnvData_Frequent.fLocalPlanetTime` | number | Confirmed in movie |
| `player.health` / `player.maxHealth` | `PlayerFrequentData.fHealth` / `fMaxHealth` | number | Confirmed in movie |
| `player.healthPercentage` | Derived from confirmed health fields | number | Confirmed derivation |
| `player.oxygen` / `player.maxOxygen` | `PlayerFrequentData.fOxygen` / `fMaxO2CO2` | number | Confirmed in movie |
| `player.oxygenPercentage` | Derived from confirmed oxygen fields | number | Confirmed derivation |
| `player.carbonDioxide` | `PlayerFrequentData.fCarbonDioxide` | number | Confirmed in movie |
| `power.current` / `power.maximum` | `PlayerFrequentData.fStarPower` / `fMaxStarPower` | number | Confirmed in movie |
| `power.percentage` | Derived from confirmed power fields | number | Confirmed derivation |
| `power.key` / `power.hasSpell` / `power.cost` / `power.cooldown` | `HUDStarbornPowersData` fields | mixed | Confirmed in movie |
| `weapon.clipAmmo` / `weapon.totalAmmo` | `WeaponData.uClipAmmo` / `uTotalAmmo` | number | Confirmed in movie |
| `weapon.reserveAmmo` | Total minus clip, clamped at zero | number | Confirmed derivation |
| `weapon.displayAmmo` / `weapon.ammoAsPercent` | `WeaponData` Boolean fields | Boolean | Confirmed in movie |
| `weapon.name` | `WeaponData.sWeaponName` | string | Confirmed in HUD runtime |
| `weapon.icon` | `WeaponData.sIconLinkageName` | string | Confirmed in vanilla HUD; rendered through the bounded provider-symbol adapter |
| `weapon.ammoType` | Equipped `PlayerInventoryData.aItems[*].WeaponInfo.sAmmoType` | string | Confirmed in HUD runtime for ranged weapons and the Cutter |
| `carry.current` / `carry.maximum` | `PlayerInventoryData.fEncumbrance` / `fMaxEncumbrance` | number | Confirmed in HUD runtime; value-change refresh pending |
| `credits` | `PlayerInventoryData.uCoin` | number | Confirmed in HUD runtime; value-change refresh pending |
| `power.name` | Bounded name-field probe on `HUDStarbornPowersData` | string | Candidate only; HUD field probe pending |

Identifiers are case-insensitive and underscores are ignored. Configuration
never supplies provider names or field names; each public CUI source maps to a
hardcoded adapter entry.

Carry and credits are published by the already-proven `PlayerInventoryData`
provider through fields consumed by vanilla InventoryMenu. HUD runtime confirms
that both values populate before Inventory opens, and that direct and templated
forms agree. Refresh after an actual inventory-weight or credit change remains
unverified.

`PowersMenuData` exposes player-facing names to the vanilla Powers menu, but HUD
runtime did not receive that menu-owned provider before or after opening and
closing Powers. That cross-provider candidate is rejected. The next bounded
probe checks `sName`, `sPowerName`, and `sDisplayName` directly on the already-live
`HUDStarbornPowersData`; the raw `sKey` remains diagnostic evidence only.

No candidate becomes a production source until its owner, lifetime, field
contract, and transition safety are separately proven.

The provider-symbol runtime screenshot verifies the layout, weapon icon/name,
ammunition row, environment values, meters, and receipt of inventory data. It
also proves that the body remains unfinished: `power.key` renders a timeline
symbol key, carry and credits are literal provider placeholders, and the
inventory status line is diagnostic instrumentation. None of those three body
rows is accepted as final behavior.

## Ammo-type provider diagnostic

Vanilla `inventorymenu.swf` consumes `PlayerInventoryData.aItems` and displays
`WeaponInfo.sAmmoType`. Inventory entries also expose `bIsEquipped`, providing a
bounded candidate route to the equipped weapon. The Goal 5 diagnostic subscribes
to the same provider from `HUDMenu`, adds `weapon.ammoType`, and reports whether
the provider was received, whether an equipped weapon candidate was found, and
whether that candidate supplied a valid string. It clears a previously resolved
ammo type when a later update does not contain one.

This route is accepted only if it is live before InventoryMenu is opened and
continues to update when weapons change through Favorites. A provider that is
menu-owned, delayed until InventoryMenu opens, or stale after weapon changes is
not a production HUD provider.

Runtime testing confirmed that the provider is live before InventoryMenu opens,
updates through Favorites, and resolves conventional ammunition plus the
Cutter's continuous ammunition. Melee weapons intentionally have no ammunition
type; their entire ammunition row is hidden by the `weaponHasAmmo` condition
derived from `WeaponData.bDisplayAmmo`.

## XML contract

Dynamic text keeps a static fallback and selects one bounded formatter:

```xml
<text id="location" x="16" y="78" width="286" height="34"
      opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2"
      value="LOCATION WAITING FOR PROVIDER"
      source="location.name" format="raw"
      font="$MAIN_Font_Bold" fontSize="22" color="#00E8EC"
      bold="false" align="left" />
```

Supported formats are `raw`, `integer`, `percent`, `temperature`, `gravity`,
`time24`, and `boolean`. Source kind and format must be compatible.

Text may alternatively use a bounded `valueTemplate`. Variables use
`{allowlisted.source}` or `{allowlisted.source:format}`. Direct `source` and
`valueTemplate` are mutually exclusive, templates are limited to 256
characters and eight variables, and the static `value` replaces the complete
template until every referenced value is available. Provider/member names,
expressions, nesting, and scripts remain unavailable.

Dynamic meters keep static fallbacks and may use a live maximum:

```xml
<meter id="health.live" x="8" y="286" width="344" height="26"
       opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="2"
       style="probe.health.live" value="100" max="100"
       source="player.health" maxSource="player.maxHealth" />
```

The runtime clips the configured renderer to the resolved ratio. A separate
ordinary empty/background meter supplies the unfilled visual. This preserves
the shared meter renderer library and avoids provider-specific components.

Active Bethesda weapon icons use the bounded provider-symbol component:

```xml
<providerSymbol id="weapon.icon" x="8" y="0" width="54" height="54"
                opacity="1" visible="true" rotation="0"
                scaleX="1" scaleY="1" z="1"
                source="weapon.icon" color="#F2F7F9"
                fit="contain" alignX="left" alignY="center" />
```

Configuration cannot select a SWF or library. Ordinary Bethesda linkage names
resolve only through `WeaponIcons`; linkage names beginning with `CCSUP` resolve
through Bethesda's linkage-named Creation Club library convention. Empty or
unavailable linkages unload and hide the icon without affecting the weapon name.

## Probe acceptance

### Provider-symbol composition compatibility

The first deployed provider-symbol probe failed layout parsing because the
composition resolver's leaf-component allowlist had not been extended for
`providerSymbol`. The resolver rejected the node before parser validation or
runtime construction. The allowlist now preserves provider-symbol nodes during
composition, and reopen validation confirms the compiled resolver retains that
behavior before an artifact can be accepted.

Build and deploy the Venworks variant, then verify:

1. The complete vanilla bottom-left Chronomark is hidden.
2. The replacement remains visible in first and third person and while the
   scanner opens and closes.
3. Location, local time, atmospheric O2, temperature, and gravity populate.
4. Health and O2 labels/meters respond to real value changes.
5. Clip and reserve ammo populate and update after firing/reloading.
6. Before opening Inventory, the diagnostic reports `PlayerInventoryData`
   received and shows the ammo type for the equipped weapon.
7. The ammo type changes when switching between weapons through Favorites and
   remains correct after opening and closing Inventory.
8. The active-power field displays a useful player-facing name from a provider
   proven live in HUD; the raw timeline key is diagnostic evidence only.
9. Carry current/max and credits populate before Inventory opens, direct and
   templated forms agree, and values update after inventory/credit changes.
10. Save load, death/reload, ladder, workbench, vehicle, and ship transitions do
   not crash and do not permanently suppress the panel.
11. Ranged weapons and the Cutter show their icon, name, ammunition counts, and
    ammunition type; melee weapons show only their icon and name.
12. Rapid Favorites switching does not leave a stale icon or stale ammunition
    row, and unarmed state clears the icon without an error.

Report the displayed values and transition behavior before judging styling.
The final replacement must not proceed until the confirmed fields and lifecycle
behavior are accepted.

## Final-layout target after probe acceptance

The intended surface matches the old panel as closely as the clean-room
component system allows:

- weapon name above the panel;
- `clip / reserve (ammo type)` beneath it;
- location and local time at the top of the panel;
- environmental O2, temperature, and gravity on one row;
- active power, carry current/max, and credits in the body;
- teal alternating-triangle health, pink O2, and green encumbrance meters;
- all former Chronomark markers moved to the future compass surface.

## Goal 5 exit requirements

Goal 5 is not complete when provider probing ends. Before Goal 6 begins:

- replace the layered empty/fill bar pairs with single live `meter` controls;
- add bounded multi-file layout composition in which root `layout.xml` imports
  reusable fragments and owns their placement;
- split the Chronomark surface into `components/weapon-status.xml`,
  `components/environment-status.xml`, and `components/player-meters.xml` (or
  equivalently scoped names accepted during that slice); and
- pass the complete provider, live-update, and transition acceptance list above.

## Risks and rollback

An unavailable provider value retains its static fallback. Unknown sources,
non-numeric meter sources, and incompatible formats fail the entire CUI layer
with an actionable diagnostic while leaving vanilla UI lifecycle code intact.
Rollback is the user-performed revert of the Goal 5 files plus rebuilding the
previous accepted Goal 4G layout. No repository history operation is performed
by the agent.
