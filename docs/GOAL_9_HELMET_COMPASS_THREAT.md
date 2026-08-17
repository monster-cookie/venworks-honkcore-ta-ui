# Goal 9 helmet compass, threat score, and active effects

**Status: Goal 9A personal-effects provider diagnostic build-validated and
awaiting runtime classification.** The compass and environmental providers are not being
re-probed: Goal 8 already established the complete `HudCompassData` contract
used by the contact radar and former Watch, while Goal 6 established the live
environmental-effect feed.

## Product direction

Goal 9 will fill the upper helmet cutout with a horizontal rotating compass
tape. The player's current heading remains centered while cardinal and
intercardinal labels, minor ticks, and live markers move across the bounded
tape. The final surface must retain the marker coverage of Bethesda's former
Watch ring, including general, mission, enemy, companion, location, ship,
vehicle, and environmental markers supported by the established providers.

Immediately below the compass, a color-coded `0–100%` threat score will combine
four independently bounded inputs. The initial weighting direction is:

| Input | Maximum contribution |
| --- | ---: |
| Nearby acquired hostiles | 35% |
| Nearby physical hazards | 15% |
| Active personal debuffs | 35% |
| Active environmental hazards | 15% |

Personal debuffs receive the same maximum contribution as hostiles because
Starfield afflictions can become lethal. Counts, proximity, and severity may
affect an input only where the owning live provider proves those meanings.
Unavailable severity must fall back to a bounded count contribution rather
than an inferred value.

One large two-line wrapped active-effects region will sit beneath the threat
score. It is not divided into two fixed rows because the number of simultaneous
debuffs may exceed one line. Proven negative effects will receive visual and
ordering priority; proven positive effects will remain distinguishable without
displacing more urgent negative effects.

## Accepted inputs from earlier goals

Goal 8 already confirmed the following `HudCompassData` inputs in HUDMenu:

- `fDirection` for player heading;
- `aMarkers` for general markers;
- `aMissionMarkers` for mission markers;
- `aEnemyMarkers` for engine-filtered acquired hostiles;
- marker `fHeading`, `fDistanceToPlayer`, `fDistanceAlpha`, `uiHandle`,
  `uiMarkerIconType`, `uiRelativeMarkerHeightType`, and applicable
  map/location state fields.

The final compass will reuse the hardened finite-value and lifecycle boundaries
from Goal 8. Goal 9A does not display or inspect those fields again.

Goal 6 already confirmed `EnvironmentEffectsData.aEnvironmentEffects`, the four
environmental categories, protection state, and the modeled per-category
exposure values. Goal 9A does not add an environment diagnostic.

## Goal 9A unresolved provider contract

Bethesda's HUD subscribes to `PersonalEffectsData` and passes
`aPersonalEffects` to `PersonalEffectsWidget`. The vanilla widget consumes only
each record's `sEffectIcon`, shows at most five distinct non-blacklisted icons,
and deliberately excludes the known sustenance icon IDs. That behavior proves
a persistent HUD effect array but does not prove names, positive/negative
polarity, severity, duration, stacks, or a stable effect identifier.

Bethesda's HUD also subscribes to `PersonalAlertsData`. Each alert consumed by
the vanilla HUD has `sEffectIcon`, `sAlertText`, and `sAlertSubText`, but the
payload is handled as a transition animation. It cannot be treated as the
current active-effect set unless runtime evidence establishes a safe lifecycle
relationship with `PersonalEffectsData`.

Goal 9A therefore adds a passive diagnostic for only these two providers.

## Diagnostic behavior

The temporary top-center diagnostic presents:

- `PersonalEffectsData` receipt, root field names, and
  `aPersonalEffects` count;
- up to 16 active-effect records with at most 12 sorted field/value pairs per
  record;
- `PersonalAlertsData` receipt, root field names, and `aPersonalAlerts` count;
- up to eight alert records with at most 12 sorted field/value pairs per
  record.

Diagnostic scalar values replace line-breaking whitespace and truncate after
48 characters. Arrays are represented by their lengths and nested objects by
type rather than recursively serialized. The layout wraps every live binding,
contains no input or callback attributes, and labels all meanings as unproven.

The diagnostic does not cache alerts as active state, modify Bethesda's Watch
classes, add native code, persist data, or subscribe to compass or environment
providers beyond their existing production adapters.

## Runtime matrix

Capture readable screenshots, or transcribe the complete visible records, for
each available case:

1. no personal effects active;
2. one affliction or injury;
3. several simultaneous afflictions or injuries;
4. food and drink positive effects;
5. food and drink negative effects, where supported by the current game mode;
6. pharmaceutical effects;
7. a Starborn power or other timed positive effect;
8. simultaneous positive and negative effects;
9. an effect expiring naturally;
10. an effect being cured or removed early; and
11. loading a save with effects already active.

For each case, compare `PersonalEffectsData` and `PersonalAlertsData` before,
during, and after the transition. Absence of a field in one sample is not proof
that the concept is globally unavailable.

## Production gate

Goal 9B may proceed after runtime evidence answers:

- which persistent record fields, if any, provide localized names or stable
  identifiers;
- whether positive and negative effects can be classified without maintaining
  a handcrafted game-data list;
- whether severity, duration, or stack count is present and stable;
- whether sustenance and other positive effects are present in the persistent
  array despite Bethesda's display blacklist; and
- whether alert text can safely enrich a matching persistent effect without
  making transition events authoritative active state.

Any unproven field remains unavailable in production. The threat score will not
assign the 35% debuff contribution until negative active effects can be counted
truthfully.

## Validation

Source validation requires `Tools/checkRepo.ps1`, the complete normal/large
Scaleform build, and `git diff --check`. The Scaleform build must import and
reopen both HUD movies, retain the bounded provider subscriptions and diagnostic
formatters, schema-validate the component fragment, verify exactly 16 effect
and eight alert bindings, reject interactive diagnostic content, and stage
byte-identical CUI payloads across VWKS, CF, FC, and TA.

Runtime acceptance remains separate from build validation.

On 2026-08-16, `Tools/checkRepo.ps1`, the complete normal/large Scaleform build,
and `git diff --check` passed. Both movies imported and reopened all 207 scripts,
retained the bounded personal-effect and personal-alert subscriptions, and
passed the diagnostic schema, binding-count, wrapping, noninteractive, and
personal-effects-only assertions. The movies, layout, and diagnostic fragment
staged byte-identically across VWKS, CF, FC, and TA.

| Goal 9A artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 419058 | `7FA4AC42ADCBE1E5C79B7F5B549F842DD155A75825FCE5005A3EE43A5B5322CD` |
| `hudmenu_lrg.gfx` | 419241 | `5458C451E0EC046839F7B8EDB8038A719F8C718E6D1CD289071B940FF4F8869A` |
| `VenworksCUI/layout.xml` | 6760 | `543BC7E4B285F047742A128C84971E8B3ABC7333117924B90191A675D0BE9D09` |
| `components/personal-effects-diagnostic.xml` | 10181 | `2D62B6DCD78C005D0CAF4E4CD0545BDCA833C39474B340BC654B1562120C44AA` |

## Rollback

Remove the two temporary provider subscriptions and diagnostic values from
`CUIPlayerHudDataContext`, remove the diagnostic include and component fragment,
and remove the matching build/staging assertions. Goal 8 compass behavior and
Goal 6 environmental behavior remain unchanged.
