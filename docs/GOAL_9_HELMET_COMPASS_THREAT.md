# Goal 9 helmet compass, threat alert, and active effects

**Status: Corrected top-edge layout source-validated on 2026-08-17; complete
normal/large Scaleform rebuild and in-engine runtime/visual acceptance remain
pending.**

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

## Threat alert

The alert is a bounded `0-100%` score. Four independent components contribute
the following maximum weights:

| Input | Maximum contribution |
| --- | ---: |
| Nearby acquired hostiles | 35% |
| Nearby physical hazards | 15% |
| Active personal debuffs | 35% |
| Active environmental hazards | 15% |

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

## Prior build validation

The Goal 9 implementation immediately preceding the top-edge layout correction
completed the normal and large Scaleform build on 2026-08-17 using the
repository-pinned vanilla HUD inputs. Both output movies:

- imported and reopened all 210 scripts;
- contained all 43 authored Venworks classes in one application domain;
- passed the production Goal 9 source and renderer assertions;
- schema-validated the new fragment and root layout;
- rejected the removed diagnostic subscriptions and fragment;
- staged the same CUI payload across VWKS, CF, FC, and TA; and
- reopened successfully after final patching.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 438840 | `5CE0D0A6130E8F63730B297951C9E379891769A85D0C6402B5BD117F7D395A0C` |
| `hudmenu_lrg.gfx` | 439023 | `786EB3BAF6DCB5A2507277AEFE395318CC7709756D30FF98611649285146D6D1` |

The authored ABC seed was regenerated with the retained JPEXS seed generator
and passed the build's import, single-domain, class-count, and reopen checks.
These artifact hashes describe the preceding layout and do not validate the
corrected compass and threat placement.

The corrected fragment passes the layout XSD and direct coordinate invariants:
the radar ends at logical `x=447`, the compass spans `x=547..1373` at `y=0`,
the threat alert is centered in the existing recess, and the status bar retains
its `x=600`, `y=134`, `720 x 56` screen bounds. `Tools/checkRepo.ps1` also
passes. A complete rebuild remains pending because the current workspace does
not contain Java, JPEXS, Flex, or extracted vanilla interface inputs.

## In-engine acceptance checklist

Build validation cannot prove Bethesda runtime provider behavior or final
helmet fit. Test both normal and large HUD variants in gameplay:

1. Rotate through 360 degrees and confirm the current heading remains centered,
   labels wrap across north, and ticks move smoothly.
2. Confirm quest, location, NPC, enemy, ship, vehicle, and environmental
   markers appear when their corresponding Watch markers would appear.
3. Approach and leave enemies; verify the hostile portion raises and clears
   the score without stale contacts.
4. Approach a physical hazard marker and verify its contribution remains
   bounded independently from hostiles.
5. Enter and leave each available environmental hazard; confirm active
   exposure raises the score and clear conditions remove it.
6. With Dislocated Limb active, confirm `AFFLICTION` appears before sustenance
   entries and materially raises threat.
7. Confirm `FED` and `HYDRATED` appear in the status bar but do not raise the
   score.
8. Add enough persistent effects to wrap into the second row and verify the
   HUD remains inside the 720 by 56 region.
9. Compare normal and large HUD placement at the supported resolutions and
   check for clipping against the helmet cutout.
10. Save/load or change cells with live effects and contacts; verify no stale
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

## Rollback

Remove the `helmet-awareness.xml` include, the three Goal 9 leaf renderers, the
tactical-awareness model and data-context event, and their parser, schema,
runtime, build, seed, and staging registrations. Goal 8 compass provider work
and Goal 6 environmental modeling remain independently intact.
