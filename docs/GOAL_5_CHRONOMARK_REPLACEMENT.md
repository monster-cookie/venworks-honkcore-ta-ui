# Goal 5 Chronomark replacement

> **Historical implementation evidence:** Current product intent, scope,
> delivery state, and acceptance are maintained in the Codecks `Documentation`
> and `Features` decks. The provider contracts, implementation map, and runtime
> evidence below remain authoritative until deliberately superseded.

**Status: Complete.** Runtime acceptance is complete for the available
keyboard/mouse test environment. Controller glyph presentation remains a
non-blocking verification limitation because no controller was available; the
same Bethesda hold-button control structurally retains controller switching.

## Scope

Goal 5 is the first live-data player-HUD surface. The approved probe replaces
the complete vanilla bottom-left Chronomark presentation with a Venworks panel
that is always present while `hudmenu.gfx` is active. Scanner state does not
hide it. The existing `bottomLeft` vanilla-visibility adapter performs the
hide; no display path or method name comes from configuration.

This work began as a provider probe and concluded with runtime acceptance of the
replacement surface. Its layout approximates the old HONKCORE panel while using
the clean-room CUI component system and the confirmed live-data contracts below.

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
| `weapon.explosiveCount` / `weapon.explosiveType` | `WeaponData.uExplosiveCount` / `uExplosiveIndicatorType` | number | Confirmed in HUD runtime |
| `boost.charge` | `HudJetpackData.fJetpackCharge`, clamped to `0..1` | number | Confirmed in HUD runtime |
| `carry.current` / `carry.maximum` | `PlayerInventoryData.fEncumbrance` / `fMaxEncumbrance` | number | Confirmed in HUD runtime, including value-change refresh |
| `credits` | `PlayerInventoryData.uCoin` | number | Confirmed in HUD runtime, including value-change refresh |
| `power.name` | Bounded canonical-English mapping from `HUDStarbornPowersData.sKey` | string | Confirmed in HUD runtime across power changes |

Identifiers are case-insensitive and underscores are ignored. Configuration
never supplies provider names or field names; each public CUI source maps to a
hardcoded adapter entry.

Carry and credits are published by the already-proven `PlayerInventoryData`
provider through fields consumed by vanilla InventoryMenu. HUD runtime confirms
that both values populate before Inventory opens, and that direct and templated
forms agree. Runtime changes to carried weight and credits also refresh both
forms, completing their provider acceptance.

`PowersMenuData` exposes player-facing names to the vanilla Powers menu, but HUD
runtime did not receive that menu-owned provider before or after opening and
closing Powers. That cross-provider candidate is rejected. The next bounded
probe checks `sName`, `sPowerName`, and `sDisplayName` directly on the already-live
`HUDStarbornPowersData`; runtime confirmed that none is present. The accepted
interim route maps the provider's 24 known keys to the canonical English names
exposed by Bethesda's Powers-menu data contract. Empty and unknown keys retain
the complete static fallback. This mapping is intentionally English-only until
a HUD-safe localized record-name source is discovered; the raw `sKey` remains
diagnostic evidence only.

No candidate becomes a production source until its owner, lifetime, field
contract, and transition safety are separately proven.

The provider-symbol runtime screenshots verify the layout, weapon icon/name,
ammunition row, environment values, meters, and receipt of inventory data. They
also drove replacement of the unfinished body rows: the lower panel now uses
the mapped power name and accepted carry/credits templates. The top discovery
gallery was removed after the mapped name and live carry/credits values passed
runtime acceptance.

## Multi-file Chronomark configuration

The accepted surface is split into four reusable component fragments under
`VenworksCUI/components`: `weapon-status.xml`, `environment-status.xml`,
`player-meters.xml`, and `mobility-status.xml`. Root `layout.xml` owns their placement through bounded
`include` declarations. Each fragment contains exactly one local root group;
the loader prefixes local IDs with the include ID and resolves every file before
the parser, asset manager, or renderer can create a partial HUD.

Includes are limited to 16 direct XML files beneath the fixed components root.
Absolute paths, traversal, subdirectories, URLs, query strings, fragments,
duplicate include IDs, oversized fragments, and nested imports are rejected.
Single-file layouts without imports remain supported.

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
<meter id="health" x="8" y="286" width="344" height="26"
       opacity="1" visible="true" rotation="0" scaleX="1" scaleY="1" z="1"
       style="probe.health" value="100" max="100"
       source="player.health" maxSource="player.maxHealth" />
```

The configured renderer owns both its empty and filled visuals and redraws
itself when a bound current or maximum value changes. One meter therefore
replaces each former layered empty/fill pair while preserving the shared meter
renderer library and avoiding provider-specific components.

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
13. Grenade/mine type and count update after equipping and consuming explosives.
14. The boost meter appears only during partial charge, drains and refills, and
    does not interfere with ordinary HUD transitions.
15. Entering a vehicle shows the CUI exit prompt; repeated keyboard/controller
    hold-to-exit actions work because the untouched vanilla `HUDVehicle_mc`
    continues processing the real `VehicleExit` event.

Runtime has accepted the four imported fragments, scanner persistence,
health/O2 updates (including health reaching zero through fall damage and the
subsequent death/reload), weapon changes, mapped power names, and live
carry/credits changes. It has also accepted the consolidated meters, explosive
presentation, boost updates, whole-group vanilla suppression, and functional
vehicle exit through the hidden original control. Keyboard runtime rejected
fitting a complete second `HUDVehicle` timeline into the CUI
prompt box: the full timeline bounds reduced the intended control to a clipped
fragment. The replacement now extracts only the initialized `GetUpButton_mc`
child before fitting. Keyboard runtime confirms that child displays the mapped
key glyph, remains readable through repeated vehicle transitions, and preserves
functional hold-to-exit input through the hidden original control. Controller
presentation is structurally supported by the Bethesda hold-button control but
remains runtime-unverified because no controller was available.

HONKCORE did not supply a localization handler for this prompt. Its HUD patch
registered the original `RightMeters_mc.HUDVehicle_mc` as a separately
configurable default target and preserved Bethesda's input object; its custom
text widgets otherwise assigned configured or hardcoded strings directly. CUI
therefore uses a temporary six-candidate `$`-token gallery to discover the
Bethesda vehicle-exit localization key. The available English client can prove
that a token resolves instead of rendering raw, but cannot independently verify
the wording in another installed language.

The first localization pass rendered all six vehicle candidates literally,
including their leading `$`. Because that pass lacked a known-valid control, a
second diagnostic adds `$Unknown Location`, `$MASS`, and `$VALUE`, all observed
in Bethesda's extracted interface scripts. Runtime confirmed all three controls
translate, proving the CUI text path invokes Bethesda localization and the six
vehicle guesses were wrong. Read-only inspection of the installed
`translate_*.txt` tables identifies `$EXIT HOLD` as Bethesda's complete
language-safe phrase: `HOLD TO EXIT` in English, with entries in all nine
installed UI languages. The temporary gallery is removed; the weapon fragment
now composes `$EXIT HOLD` with the confirmed live mapped glyph above the weapon
row.

The first composed runtime prompt passed localization, mapped-key presentation,
and vehicle-exit behavior, but both the label and especially the key glyph were
too small for final readability. Increasing the outer glyph box proved that the
wide hold-button label bounds still dominated `contain` fitting. The follow-up
bounds the initialized hold button to the union of its live keyboard and
controller glyph children. Runtime confirmed that the helper became readable,
but also exposed that `mobility-status.xml` remained rooted at bottom-right.
The final placement pass transfers the horizontal pair to the bottom-left
weapon fragment, positions it above and left-aligned with the weapon row, and
reduces the readable but oversized key box from 68 to 52 pixels beside the
accepted 21-pixel label. Runtime accepted the upper-left placement and reduced
key size.

Runtime accepted the upper-left ownership and reduced key size, then identified
excess spacing and a small optical baseline mismatch. The refinement narrows the
label box, places the unchanged 52-pixel mapped glyph approximately 10 pixels
after the label, and lifts the glyph three pixels to compensate for whitespace
inside Bethesda's button artwork. Keyboard runtime accepted the final spacing,
alignment, readability, and repeated hold-to-exit behavior. Controller
alignment remains structurally supported but runtime-unverified because the
current test environment has no controller.

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

Goal 5 did not end when provider probing finished. Its completed exit checklist
is:

- [x] replace the layered empty/fill bar pairs with single live `meter` controls;
- [x] runtime-accept the bounded multi-file layout and its four root-placed
  Chronomark fragments;
- [x] runtime-accept the new grenade/mine count and live boost presentation;
- [x] runtime-accept the mapped, noninteractive CUI vehicle prompt while the hidden vanilla
  `HUDVehicle_mc` remains alive and exclusively owns vehicle-exit input;
- [x] pass the complete provider, live-update, and transition acceptance list above
  in the available keyboard/mouse runtime environment.

Controller-only glyph presentation remains recorded as unverified hardware
coverage, not an incomplete Goal 5 implementation requirement.

The complete vanilla `RightMeters_mc` presentation is alpha-gated as one fixed
target. The adapter never changes its `visible` property and never addresses
`HUDVehicle_mc`. Consequently the vehicle child retains its provider-driven
`visible` state and `ProcessUserEvent` path even though CUI supplies the visible
exit prompt. That prompt uses only the initialized `GetUpButton_mc` child
extracted from a temporary Bethesda vehicle-control instance. The complete
duplicate timeline is never attached or subscribed, avoiding its HUD-sized
bounds while retaining the Bethesda hold button's keyboard/controller
presentation. A clipped wrapper uses the union of `PCButton_mc` and
`ConsoleButton_mc` as the fitted region, excluding the hold-button label area
without reimplementing device switching. Mouse interaction and user-event
routing are disabled on the extracted child, and configuration cannot bind
actions or callbacks to it.

## Risks and rollback

An unavailable provider value retains its static fallback. Unknown sources,
non-numeric meter sources, and incompatible formats fail the entire CUI layer
with an actionable diagnostic while leaving vanilla UI lifecycle code intact.
Rollback is the user-performed revert of the Goal 5 files plus rebuilding the
previous accepted Goal 4G layout. No repository history operation is performed
by the agent.
