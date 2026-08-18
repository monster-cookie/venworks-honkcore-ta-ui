# Goal 9 helmet compass, threat alert, and active effects

> **Historical implementation evidence:** Current product intent, scope,
> delivery state, and acceptance are maintained in the Codecks `Documentation`
> and `Features` decks. The compass, threat, effect, and provider contracts
> below remain authoritative until deliberately superseded.

**Status: Normal-view layout visually accepted on 2026-08-17; final
combat/proximity threat escalation built and staged, with runtime behavior and
large-variant visual acceptance pending.**

Goal 9 fills the upper helmet cutout with three compact, live HUD surfaces:

1. a horizontal rotating compass tape;
2. a numeric threat alert; and
3. a wrapped two-line personal-effects bar.

The implementation uses only providers available to `HUDMenu`. It adds no
native plugin, SFSE dependency, mock telemetry, persistence, or third-party
dependency.

## Final live-provider contract

Goal 8 established the production `HudCompassData` contract. Goal 9 consumes:

- `fDirection` for the player's current heading;
- `aMarkers` for the Watch-compatible general marker set;
- `aEnemyMarkers` for engine-filtered acquired hostiles;
- marker heading, distance, alpha, handle, icon type, relative height,
  location, and subcategory fields; and
- `EnvironmentEffectsData.aEnvironmentEffects` for environmental compass
  markers and active environmental pressure.

The existing player HUD data context consumes `PlayerData`, whose HUD-lifetime
payload was previously runtime-proven to include `bIsInCombat`. Goal 9 reads
that field directly in the existing `PlayerData` callback for combat
escalation. `CUIConditionContext` retains its separate `HUDStealthData`
subscription for configurable visibility conditions, but that path does not
drive the threat model.

Goal 9 also consumes `PersonalEffectsData.aPersonalEffects` as the live,
persistent personal-effect set. Runtime probing established these relevant
icon identifiers:

- `SUSTENANCE_DRINK_POSITIVE_1` for Hydrated;
- `SUSTENANCE_FOOD_POSITIVE_1` for Fed; and
- `PERSONALEFFECT_*` for active afflictions, including the Dislocated Limb
  record exposed as `PERSONALEFFECT_NERVOUSSYSTEM`.

The Status Menu's richer `PlayerStatusData` is unavailable to `HUDMenu`. Its
update count remained zero both before and after opening Status Effects.
`PersonalAlertsData` is also unsuitable as active state because it contains
only transient presentation events. Both subscriptions were removed from the
production implementation.

Consequently, the HUD can truthfully show the persistent effect icons and safe
generic labels, but it cannot reproduce the Status Menu's localized affliction
title, prognosis, modifier rows, or remaining time. Timed food, drink, and
pharmaceutical bonuses that do not enter `PersonalEffectsData` are likewise
not available without native support.

## Layout

The production fragment is
`Scaleform/shared/fixtures/components/helmet-awareness.xml`. It is included at
the top center of the tactical HUD at `x=0`, `y=22`, and `z=110`. Its
`826 x 132` root preserves the established threat and status positions while
allowing the compass to reach the physical top edge.

| Surface | Bounds within fragment | Screen result at `1920 x 1080` | Purpose |
| --- | --- | --- |
| Compass tape | `x=0`, `y=-58`, `826 x 48` | `x=547..1373`, `y=0..48` | Heading tape and live Watch markers |
| Threat alert | `x=253`, `y=12`, `320 x 24` | Centered inside the existing `320 x 48` threat recess | Numeric score, state label, and accent bar |
| Status effects | `x=53`, `y=76`, `720 x 56` | Existing `x=600`, `y=134` placement retained | At most two visual rows of active effects |

The compass left boundary is 100 logical pixels beyond the contact radar's
right edge (`64 + 155 + 228 = 447`), and the right boundary mirrors it around
the 1920-wide design center. Normal and large HUD variants stage the same
logical layout and rely on the engine's UI scaling at higher resolutions.

The former Goal 9 diagnostic fragment is removed from source and all four
staging roots.

## Compass behavior

The compass presents a bounded 120-degree horizontal view centered on the
player's current heading. The heading strip contains:

- cardinal and intercardinal labels `N`, `NE`, `E`, `SE`, `S`, `SW`, `W`, and
  `NW` every 45 degrees;
- major ticks every 15 degrees;
- minor ticks every 5 degrees; and
- a fixed center reference while the tape and markers rotate beneath it.

The marker layer accepts up to 48 live markers. It reuses Bethesda's
`CompassMarkerWidget` and `MapMarkerUtils` dynamically, including marker icon,
location, elevation, and subcategory state. General compass markers are merged
with environmental-effect markers and deduplicated by handle. A simple vector
fallback remains available if a Bethesda marker widget cannot be constructed.

The compass renderer does not apply a marker-distance cutoff. The contact
radar's 200-unit maximum is isolated to `CUIContactRadar`; a compass marker
supplied by Bethesda remains eligible regardless of distance, subject to the
48-marker limit, engine-provided visibility/alpha, and the current 120-degree
heading window. The threat model's separate 300-unit awareness radius affects
only hostile and physical-hazard pressure, not compass marker presentation.

## Threat alert

The alert is a bounded `0-100%` score. Combat and immediate hostile proximity
take precedence. When neither override applies, four independent components
contribute the following maximum weights:

| Input | Maximum contribution |
| --- | ---: |
| Nearby acquired hostiles | 35% |
| Nearby physical hazards | 15% |
| Active personal debuffs | 35% |
| Active environmental hazards | 15% |

### Combat and immediate-proximity escalation

The final score applies these rules in order:

1. `PlayerData.bIsInCombat == true` forces `100% CRITICAL`, regardless of
   distance, so ranged combat is represented.
2. Otherwise, the nearest valid acquired enemy below 25 units forces
   `100% CRITICAL`.
3. Otherwise, the nearest valid acquired enemy below 50 units floors the
   weighted score at `90% CRITICAL` without lowering a score already above 90.
4. Otherwise, the normal weighted calculation is used.

The boundaries are strict: exactly 25 units enters the 90-percent tier and
exactly 50 units uses the weighted calculation. Proximity considers at most 64
`aEnemyMarkers` entries and rejects null markers, zero/invalid handles,
non-finite distances, and negative distances.

### Nearby-marker pressure

Hostiles come from `aEnemyMarkers`. Physical hazards are general compass
markers whose engine icon type is `12`. Only finite markers within 300 game
distance units contribute.

For either marker category:

```text
pressure = clamp(
    0.60 * min(activeCount / countAtMaximum, 1)
  + 0.40 * (1 - nearestDistance / 300),
  0,
  1)
```

Hostile pressure reaches its count maximum at five contacts. Physical-hazard
pressure reaches its count maximum at three contacts.

### Debuff pressure

Persistent records whose icon begins with `PERSONALEFFECT_` are treated as
active debuffs. The count curve deliberately gives afflictions more urgency:

| Active debuffs | Debuff pressure |
| ---: | ---: |
| 0 | 0% |
| 1 | 50% |
| 2 | 75% |
| 3 or more | 100% |

Known sustenance records contribute zero threat. Unknown persistent records
remain visible in the effects bar but are not assigned an invented polarity or
threat value.

### Environmental pressure

Environmental pressure uses the live modeled exposure values established in
Goal 6. The score combines the number of active environmental categories with
the highest normalized exposure. A critical exposure state forces full
environmental pressure. Clear categories contribute nothing.

### Presentation states

The computed score is rounded to a whole percentage and displayed as
`THREAT N%` with one of four state labels:

| Score | State |
| ---: | --- |
| `0-24%` | `CLEAR` |
| `25-49%` | `CAUTION` |
| `50-74%` | `DANGER` |
| `75-100%` | `CRITICAL` |

The alert includes a thin color-coded fill track. Each input is clamped before
weighting so malformed or unusually large provider values cannot push the
total outside `0-100%`.

The hosted threat text field disables automatic sizing, retains the full
component width, and reapplies centered formatting after every score update.
This keeps every state string centered within the existing recessed panel
rather than allowing Bethesda's hosted field defaults to shrink it toward the
left edge.

## Active-effects bar

The status region uses one shared wrapped surface rather than dedicated buff
and debuff rows. It shows up to 16 entries in an eight-column by two-row grid.
When more than 16 records are active, the sixteenth slot becomes an overflow
indicator for the undisplayed count.

Ordering is:

1. proven `PERSONALEFFECT_*` debuffs;
2. unclassified persistent records; and
3. `SUSTENANCE_*` records.

The renderer reuses Bethesda's personal-effect icon art where available but
does not inherit the vanilla widget's sustenance blacklist. Thus Fed and
Hydrated remain visible even though they contribute zero threat. Safe display
labels are derived only from proven identifiers:

- the exact positive stage-one sustenance records display `FED` and
  `HYDRATED`;
- other food or drink sustenance stages use a bounded food/drink label with
  their exposed sign and stage;
- personal effects display `AFFLICTION`; and
- unknown records display `EFFECT`.

The bar intentionally does not invent localized names, remaining times,
severity, stacks, or persistence semantics that the live HUD provider does not
expose.

## Implementation map

| Responsibility | Source |
| --- | --- |
| Provider normalization and threat model | `Scaleform/shared/actionscript/venworks/cui/CUITacticalAwarenessModel.as` |
| Compass tape renderer | `Scaleform/shared/actionscript/venworks/cui/components/CUICompassTape.as` |
| Threat renderer | `Scaleform/shared/actionscript/venworks/cui/components/CUIThreatAlert.as` |
| Status renderer | `Scaleform/shared/actionscript/venworks/cui/components/CUIStatusEffectBar.as` |
| Live provider adapter | `Scaleform/shared/actionscript/venworks/cui/CUIPlayerHudDataContext.as` |
| Runtime registration and updates | `Scaleform/shared/actionscript/venworks/cui/CUIRuntime.as` |
| Component registration | `CUICompositionResolver.as`, `CUILayoutParser.as`, and `Schemas/VenworksCUI/layout-v1.xsd` |
| Production layout | `Scaleform/shared/fixtures/components/helmet-awareness.xml` |
| Build and staging assertions | `Tools/compileScaleform.ps1` |

## Build validation

The corrected Goal 9 implementation completed the normal and large Scaleform
build on 2026-08-17 using the repository-pinned vanilla HUD inputs. Both output
movies:

- imported and reopened all 210 scripts;
- contained all 43 authored Venworks classes in one application domain;
- passed the production Goal 9 source and renderer assertions;
- retained direct `PlayerData.bIsInCombat` threat-model updates and kept
  `HUDStealthData` limited to the condition context after reopen;
- retained the strict 25/50-unit proximity thresholds, 90-percent floor, and
  100-percent combat/critical override after reopen;
- retained a fixed-width, non-auto-sized, centered threat field after reopen;
- schema-validated the new fragment and root layout;
- rejected the removed diagnostic subscriptions and fragment;
- staged the same CUI payload across VWKS, CF, FC, and TA; and
- reopened successfully after final patching.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 439834 | `EECCD61EE7C7A658E3B38344AC65B631BF3960825999C39FB4CAAA24216A22BD` |
| `hudmenu_lrg.gfx` | 440017 | `3068F825CAA1CDD7017DCA258933CB722991524D6444AC6DB841493B636A87E0` |

The authored ABC seed was regenerated with the retained JPEXS seed generator
and passed the build's import, single-domain, class-count, and reopen checks.

The corrected fragment passes the layout XSD and direct coordinate invariants:
the radar ends at logical `x=447`, the compass spans `x=547..1373` at `y=0`,
the threat component is centered in the existing recess, its text field keeps
the complete 320-unit width with centered formatting, and the status bar
retains its `x=600`, `y=134`, `720 x 56` screen bounds. The complete build
staged byte-identical `hudmenu.gfx`,
`hudmenu_lrg.gfx`, `layout.xml`, assets, and component fragments across the
VWKS, CF, FC, and TA module templates.

## Normal-view runtime acceptance

The supplied 2026-08-17 normal-view evidence confirms that the compass works
in its final top-edge position, the threat text is centered in the recessed
panel, the status icons retain their accepted placement, and equipment slots
13-15 have matching bounds. That evidence exposed the former 34-percent score
during active close combat and directly motivated the final escalation rules
above. Runtime testing subsequently confirmed that the distance path raises
the threat score to 90 percent below 50 units, but the indirect
`HUDStealthData` combat bridge did not raise it to 100 percent. The corrected
implementation therefore consumes the previously proven
`PlayerData.bIsInCombat` field directly; that combat path still requires
runtime exercise.

## In-engine acceptance checklist

Build validation cannot prove Bethesda runtime provider behavior or final
helmet fit. Test both normal and large HUD variants in gameplay:

1. Rotate through 360 degrees and confirm the current heading remains centered,
   labels wrap across north, and ticks move smoothly.
2. Confirm quest, location, NPC, enemy, ship, vehicle, and environmental
   markers appear when their corresponding Watch markers would appear.
3. Enter ranged combat beyond 100 units and confirm
   `PlayerData.bIsInCombat` raises the score to `100% CRITICAL`, then verify
   leaving combat immediately releases the override with no cooldown.
4. Outside combat, cross from exactly 50 to below 50 units from an acquired
   enemy and confirm the score gains a 90-percent floor only below 50.
5. Outside combat, cross from exactly 25 to below 25 units and confirm the
   score changes from the 90-percent tier to `100% CRITICAL` only below 25.
6. Confirm compass markers supplied beyond 200 units remain eligible while the
   contact radar continues to reject contacts beyond its 200-unit range.
7. Approach and leave enemies; verify the hostile portion raises and clears
   the score without stale contacts.
8. Approach a physical hazard marker and verify its contribution remains
   bounded independently from hostiles.
9. Enter and leave each available environmental hazard; confirm active
   exposure raises the score and clear conditions remove it.
10. With Dislocated Limb active, confirm `AFFLICTION` appears before sustenance
   entries and materially raises threat.
11. Confirm `FED` and `HYDRATED` appear in the status bar but do not raise the
   score.
12. Add enough persistent effects to wrap into the second row and verify the
   HUD remains inside the 720 by 56 region.
13. Compare normal and large HUD placement at the supported resolutions and
   check for clipping against the helmet cutout.
14. Save/load or change cells with live effects and contacts; verify no stale
    marker or status entries survive provider updates.

If a case cannot be constructed without waiting for Survival-mode recovery,
record that case as not exercised rather than treating it as passed.

## Known limitations

- The Status Menu's localized title, detailed modifier text, prognosis, and
  remaining time are not exposed to `HUDMenu` through the tested providers.
- Timed consumable bonuses absent from `PersonalEffectsData` cannot appear in
  this bar without native integration.
- `PERSONALEFFECT_NERVOUSSYSTEM` is Bethesda's exposed icon identifier for the
  tested Dislocated Limb state; the HUD deliberately presents the generic
  `AFFLICTION` label instead of treating that identifier as player-facing text.
- Marker type `12` is the established physical-hazard classification used by
  this first production pass and should be revisited only if runtime evidence
  proves additional hazard types.
- Bethesda's `bIsInCombat` is broader than a direct damage event, so the
  intended 100-percent override remains active for as long as the engine
  reports combat, including ranged or temporarily obstructed engagements. The
  threat model adds no cooldown after `PlayerData.bIsInCombat` becomes false.

## Rollback

Remove the `helmet-awareness.xml` include, the three Goal 9 leaf renderers, the
tactical-awareness model and data-context event, and their parser, schema,
runtime, build, seed, and staging registrations. Goal 8 compass provider work
and Goal 6 environmental modeling remain independently intact.
