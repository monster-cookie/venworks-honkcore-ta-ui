# Goal 4C Conditions and Vanilla Visibility Adapters

## Scope

Goal 4C adds a bounded, configuration-only visibility expression language to
the player HUD runtime. Conditions can gate authored CUI components and a small
allowlist of independently verified vanilla HUD display groups. The runtime
does not accept ActionScript, arbitrary provider names, display-object paths,
properties, or method calls from configuration.

This goal connects only provider fields confirmed in vanilla `hudmenu.gfx`.
Unproven player values, effect identifiers, and ship-owned values remain
unavailable instead of being inferred from HONKCORE behavior.

## Configuration

Every component and composition placement accepts an optional `visibleWhen`:

```xml
<panel id="combat.panel"
       x="0" y="0" width="420" height="120" z="10"
       visibleWhen="inCombat AND NOT thirdPerson"
       fillColor="#071923" fillOpacity="0.9"
       strokeColor="#35E6E6" strokeOpacity="1" strokeWidth="2" />
```

`visibleWhen` is available on primitive components, groups, instances,
repeaters, repeater items, states, and approved template overrides. Static
`visible="false"`, a false parent, and a false condition all hide the result.

A condition override replaces the selected template component's expression.
The surrounding instance, repeater, item, state, and parent conditions still
gate the resolved component.

Static hidden repeater items continue to collapse before layout. A dynamic
`visibleWhen` on a repeater item reserves the item's configured slot so that
provider changes cannot move unrelated HUD controls during play.

## Expression grammar

The language supports:

- `NOT`, `AND`, and `OR`;
- parentheses;
- `=`, `!=`, `<>`, `<`, `<=`, `>`, and `>=` for numeric conditions;
- percentage thresholds from 0 through 100; and
- the reserved parameterized forms `hasCombatEffect("id")` and
  `hasEnvironmentEffect("id")`.

Precedence is parentheses, comparison/primary values, `NOT`, `AND`, then `OR`.
Identifiers and keywords are case-insensitive. Underscores are ignored when
matching names, so `IN_COMBAT`, `in_combat`, and `inCombat` are equivalent.

Examples:

```text
inCombat AND NOT thirdPerson
hudOpacityPercentage >= 1 AND (firstPerson OR thirdPerson)
isSneaking OR (inCombat AND weaponAiming)
always
never
```

The runtime compiles expressions once when `layout.xml` loads. It limits each
expression to 256 characters, 64 tokens, and eight parenthesis levels. Invalid,
unknown, unavailable, or excessive expressions reject the whole layout before
the configurable component layer renders.

## Confirmed HUD conditions

| Name | Type | Vanilla evidence |
|---|---|---|
| `always` | Boolean | Runtime constant. |
| `never` | Boolean | Runtime constant. |
| `firstPerson` | Boolean | Inverse of confirmed `HudCrosshairData.bIn3rdPerson`. |
| `thirdPerson` | Boolean | `HudCrosshairData.bIn3rdPerson`. |
| `inCombat` | Boolean | `HUDStealthData.bIsInCombat`. |
| `inScanner` | Boolean | `HudCompassData.bIsHandscannerOpen`. |
| `isSneaking` | Boolean | `HUDStealthData.bSneaking`. |
| `weaponAiming` | Boolean | `HudCrosshairData.bIronSights`. |
| `inVehicle` | Boolean | `HUDVehicleData.bInVehicle`. |
| `hudVisible` | Boolean | Confirmed HUD opacity is greater than zero. |
| `hudOpacityPercentage` | Number | `HUDOpacityData.fHUDOpacity`, converted from 0-1 to 0-100. |

Provider updates are cached and reevaluate only affected display bindings; the
runtime does not poll on `ENTER_FRAME`.

Before a confirmed provider sends its first update, its value is `unknown`.
Unknown fails hidden, and `NOT unknown` remains unknown. This prevents a
negated condition from flashing visible while Starfield state is still
initializing.

## Reserved and deferred conditions

The parser reserves `hasCombatEffect("id")` and
`hasEnvironmentEffect("id")`, but `hudmenu.gfx` does not expose enough
independently confirmed provider and identifier information to enable them.
Using either function currently produces a provider-unavailable diagnostic.

The following are also deferred until their real owning movie/provider is
confirmed:

- player health, O2, CO2, and encumbrance percentages;
- weapon drawn and weapon holstered;
- `suitSealed` (spacesuit plus helmet);
- named combat and environment effects; and
- ship presence, cruise mode, fuel, cargo, and captain's-locker percentages.

The evaluator and provider registry are movie-independent, so later player or
ship adapters can add these names without changing the XML expression grammar.

## Vanilla visibility adapters

An optional root section controls approved vanilla groups:

```xml
<vanillaVisibility>
  <target id="topCenter" visibleWhen="NOT inCombat" />
</vanillaVisibility>
```

The initial player-HUD allowlist is:

- `topCenter`;
- `bottomLeft`;
- `socialCommandIcons`;
- `floatingQuestMarkers`; and
- `crewBuffWidget`.

The adapter uses hardcoded top-level display references. It applies an alpha
presentation gate instead of changing the vanilla object's `visible` property.
This preserves Starfield's own HUD-mode decisions and lets timelines continue
advancing under `Extensions.noInvisibleAdvance`. A condition can make an
allowlisted target transparent, but it cannot force a vanilla-hidden target
visible.

`rightMeters` is a fixed whole-group presentation adapter for `RightMeters_mc`.
It changes only the group's alpha and never changes its `visible` property or
addresses any child. This lets CUI replace the visible health, power, weapon,
explosive, boost, and vehicle-prompt presentation while the untouched vanilla
`HUDVehicle_mc` retains its provider state and vehicle-exit input handling.

The following targets are deliberately unavailable:

- `HUDVehicle` and the exit-vehicle button as direct targets;
- `centerGroup` and the target crosshair;
- the enemy-health holder and enemy-health internals;
- hit, kill, and damage indicators; and
- rollover and quick-container controls.

The vehicle exit control is never a configurable visibility target. The bounded
duplicate prompt extracts only Bethesda's initialized `GetUpButton_mc` child;
the complete duplicate vehicle timeline is not attached or subscribed. The
child is noninteractive presentation only and retains Bethesda's
platform/control-map presentation, while the hidden original remains the sole
input owner. The crosshair requires an isolated crash test. Enemy health requires a legendary
enemy regression test. Hit indicators require animation-lifecycle testing,
and rollover widgets require input testing, before any later allowlist change.

## Fixtures

- `condition-gallery.xml` exercises case and underscore aliases, Boolean
  negation, grouping, a numeric comparison, component and group conditions,
  instances, an override, a state, a repeater, and dynamic repeater items.
- `vanilla-visibility-gallery.xml` leaves four allowlisted targets unchanged
  and hides only `topCenter` for the first isolated adapter test.
- `layout-invalid-condition-syntax.xml` ends after `AND`.
- `layout-unknown-condition.xml` uses an unknown condition name.
- `layout-condition-complexity.xml` exceeds the nesting limit.
- `layout-unavailable-provider.xml` uses the reserved combat-effect function.
- `layout-unsafe-vanilla-target.xml` attempts to target `HUDVehicle`.

## Automated validation

The Goal 4C build must prove:

1. all positive and runtime-negative fixtures are well-formed and validate
   against `Schemas/VenworksCUI/layout-v1.xsd`;
2. all pre-Goal-4C positive fixtures still validate;
3. both vanilla input hashes match the recorded game artifacts;
4. the generated movies contain one Venworks-only ABC seed with 20 authored
   CUI classes;
5. both generated movies reopen with all 187 expected classes;
6. every unrelated vanilla ActionScript class remains textually identical;
7. the generated ActionScript contains the condition limits, provider names,
   diagnostics, and vanilla target allowlist; and
8. both generated output hashes match the committed validation hashes.

## Required in-game validation

1. Deploy the staged condition gallery and confirm exactly one camera card is
   visible after provider initialization.
2. Enter and leave combat, open and close the scanner, sneak and stand, aim and
   lower a weapon, and enter and exit a vehicle. Confirm the corresponding
   card changes without moving unrelated cards.
3. Confirm the compound numeric card becomes true when normal HUD opacity is
   active and the normal vanilla HUD remains functional.
4. Deploy `vanilla-visibility-gallery.xml`. Confirm the top-center group is
   transparent, the other four allowlisted targets behave normally, and all
   vehicle controls—including exit—still work.
5. Deploy each negative fixture and confirm the upper red diagnostics panel
   reports the matching syntax, unknown-name, complexity, unavailable-provider,
   or unsafe-target error with no partial CUI gallery.
6. Restore `condition-gallery.xml` as `layout.xml` and confirm it returns after
   the HUD reloads.
7. Repeat the smoke test for both normal and large HUD selection where the
   game's display configuration permits it.

Goal 4C is accepted only after these in-game checks pass. Adding any currently
blocked vanilla target or deferred provider is a separate reviewed goal.
