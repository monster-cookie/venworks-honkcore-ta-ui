# Goal 9 helmet compass, threat score, and active effects

**Status: Goal 9A.3 PlayerStatusData lifecycle diagnostic build-validated and
awaiting runtime lifecycle classification.** The compass and environmental
providers are not being re-probed: Goal 8 already established the complete
`HudCompassData` contract used by the contact radar and former Watch, while
Goal 6 established the live environmental-effect feed.

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

Goal 9A.2 therefore added a passive diagnostic for only these two providers.

## Initial runtime evidence and provider boundary

On 2026-08-16, the Status Menu showed one negative effect, `Dislocated Limb`,
and four positive effects: the ordinary `Fed` and `Hydrated` sustenance states,
an Alien Kebabs food effect, and an Alien Energy Drink effect. During the same
state, the Goal 9A.2 HUD diagnostic reported three `aPersonalEffects` records:
`SUSTENANCE_DRINK_POSITIVE_1`, `SUSTENANCE_FOOD_POSITIVE_1`, and
`PERSONALEFFECT_NERVOUSSYSTEM`. `PersonalAlertsData` reported one transient
`PERSONALEFFECT_NERVOUSSYSTEM` event. This identifies the persistent records as
Hydrated, Fed, and Dislocated Limb respectively; it also proves that the alert
was a transition for the affliction rather than authoritative active state.

Alien Kebabs and Alien Energy Drink were absent from both HUD provider arrays
despite being present and timed in the Status Menu. `PersonalEffectsData` is
therefore useful for identifying the two sustenance states and an affliction,
but it is not a complete source for active consumable effects.

Bethesda's Status Menu obtains its complete presentation from
`PlayerStatusData.aEffectGroups[*].aEffects`. The vanilla menu reads group
`sName`, icon, polarity summary, timer, and nested-effect array fields. Its
effect-group renderer reads `sName`, `sEffectIcon`, `bHasBuffs`, `bHasDebuffs`,
`bShowTimer`, `fTimeRemaining`, and `bIsPositiveEffect`. Its nested effect
renderer reads `sName`, `sDescription`, `bHideName`, `bIsBuff`, `bPermanent`,
and `fTimeRemaining`. This is the model that renders both the localized group
title and the prognosis/weakness or timed-modifier rows visible in Status.

Goal 8's early HUD probe did not receive `PlayerStatusData`, but that test only
reported provider receipt and root field names. Goal 9A.3 repeats the
subscription after the later provider work, directly traverses the known
nested fields, and counts deliveries so a menu-triggered snapshot can be
distinguished from a continuously live HUD feed. The provider remains
diagnostic-only until runtime evidence passes that lifecycle gate.

## Diagnostic behavior

The expanded temporary top-center diagnostic presents:

- `PlayerStatusData` receipt and an incrementing update count;
- the root `aEffectGroups` count and root field names;
- up to 12 groups with direct reads of the exact vanilla group fields;
- up to 24 flattened nested effects, each retaining its owning group index and
  directly reading the exact vanilla effect fields;

- `PersonalEffectsData` receipt, root field names, and
  `aPersonalEffects` persistent-record count;
- up to 16 persistent records with direct `sEffectIcon` and `fHeading` reads,
  defined polarity/name/lifecycle candidates, and remaining enumerable fields,
  bounded to at most 12 field/value pairs per record;
- `PersonalAlertsData` receipt, root field names, and transient
  `aPersonalAlerts` count;
- up to eight transient records with direct `sEffectIcon`, `sAlertText`,
  `sAlertSubText`, and `bIsPositive` reads, defined lifecycle candidates, and
  remaining enumerable fields, bounded to at most 12 field/value pairs per
  record.

Diagnostic scalar values replace line-breaking whitespace and truncate after
48 characters. Arrays are represented by their lengths and nested objects by
type rather than recursively serialized. Core direct fields display
`UNDEFINED` when they are not exposed. The layout wraps every live binding,
contains no input or callback attributes, and keeps Status presentation,
persistent HUD records, and transient HUD events visibly separate without
assigning unproven gameplay meaning.

The diagnostic does not cache alerts or Status snapshots as active state,
modify Bethesda's Watch classes, add native code, persist data, or subscribe to
compass or environment providers beyond their existing production adapters.

## Runtime matrix

First perform the lifecycle test in this exact order:

1. load a save and capture the diagnostic without opening Status;
2. open Status Effects, return to gameplay, and capture the diagnostic again;
3. remain in gameplay and determine whether the update count advances and
   remaining-time fields change without reopening Status; and
4. consume a new aid item, where practical, and determine whether a new group
   arrives without reopening Status.

Then capture readable screenshots, or transcribe the complete visible records,
for each available case:

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

For each case, compare all three providers before, during, and after the
transition. Absence of a field in one sample is not proof that the concept is
globally unavailable.

## Production gate

Goal 9B may proceed after runtime evidence answers:

- whether `PlayerStatusData` is delivered before Status is opened;
- whether it continues updating after Status closes and while gameplay changes;
- whether its group and nested fields match the localized Status presentation;
- which persistent record fields, if any, provide localized names or stable
  identifiers;
- whether positive and negative effects can be classified without maintaining
  a handcrafted game-data list;
- whether severity, duration, or stack count is present and stable;
- whether sustenance and other positive effects are present in the persistent
  array despite Bethesda's display blacklist; and
- whether alert text can safely enrich a matching persistent effect without
  making transition events authoritative active state.

If `PlayerStatusData` appears only after opening Status or remains a frozen
snapshot, it is rejected as production active state. Any other unproven field
remains unavailable in production. The threat score will not assign the 35%
debuff contribution until negative active effects can be counted truthfully.

## Validation

Source validation requires `Tools/checkRepo.ps1`, the complete normal/large
Scaleform build, and `git diff --check`. The Scaleform build must import and
reopen both HUD movies, retain the bounded provider subscriptions and diagnostic
formatters, schema-validate the component fragment, verify exactly 12 Status
group, 24 nested Status effect, 16 persistent effect, and eight transient alert
bindings, reject interactive diagnostic content, and stage byte-identical CUI
payloads across VWKS, CF, FC, and TA.

Runtime acceptance remains separate from build validation.

On 2026-08-16, `Tools/checkRepo.ps1`, the complete normal/large Scaleform build,
and `git diff --check` passed for Goal 9A.2. Both movies imported and reopened
all 207 scripts, retained the bounded personal-effect and personal-alert
subscriptions, required direct reads of the known effect and alert fields, and
passed the diagnostic schema, binding-count, wrapping, noninteractive,
persistent/transient-label, and personal-effects-only assertions. The movies,
layout, and diagnostic fragment staged byte-identically across VWKS, CF, FC,
and TA.

| Goal 9A.2 artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 420152 | `241FFB860D61BBD858A03114B75BDE783DC092F650B5DC42C8E3AF6EC9D3AF45` |
| `hudmenu_lrg.gfx` | 420335 | `06718CC46FD0D668FF1CBAB09BEDAAC49FE779FAACE405B820523798B762F6C3` |
| `VenworksCUI/layout.xml` | 6760 | `543BC7E4B285F047742A128C84971E8B3ABC7333117924B90191A675D0BE9D09` |
| `components/personal-effects-diagnostic.xml` | 10270 | `49EE7E2F6D3E3741BCCBC7478C46769BD5A85D90C3BAE6E01F3569EDFB80073C` |

On 2026-08-16, `Tools/checkRepo.ps1`, the complete normal/large Scaleform build,
and `git diff --check` passed for Goal 9A.3. Both movies imported and reopened
all 207 scripts, retained all three bounded provider subscriptions, required
direct traversal of `aEffectGroups` and nested `aEffects`, and passed the
diagnostic schema, 12-group, 24-Status-effect, 16-persistent-effect,
eight-transient-alert, wrapping, noninteractive, lifecycle-label, and provider-
isolation assertions. The movies, layout, and diagnostic fragment staged byte-
identically across VWKS, CF, FC, and TA.

| Goal 9A.3 artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 422194 | `D2EB62D1FCF537BA1F6369BBB90C12AAF000C7D434E1F13DF67F8A67C35D97D7` |
| `hudmenu_lrg.gfx` | 422377 | `B798772556AAA68ECD63DFC447958E2F084817011D3BDA40D486B91E783ABD79` |
| `VenworksCUI/layout.xml` | 6854 | `F02E07278513C54A8068D9FC3589741B8AACC09866730DDB6F9C69C2DEC88DDB` |
| `components/personal-effects-diagnostic.xml` | 23353 | `85F98733FC4F90271DD73338F54B847609410CB39415BB81400746EB45A38BA4` |

## Rollback

Remove the three temporary provider subscriptions and diagnostic values from
`CUIPlayerHudDataContext`, remove the diagnostic include and component fragment,
and remove the matching build/staging assertions. Goal 8 compass behavior and
Goal 6 environmental behavior remain unchanged.
