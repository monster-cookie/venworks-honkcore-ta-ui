# Goal 9 helmet compass, threat score, and active effects

**Status: Goal 9A.2 direct-field personal-effects diagnostic build-validated
and awaiting runtime classification.** The compass and environmental
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

Goal 9A therefore adds a passive diagnostic for only these two providers.

## Initial runtime evidence and provider boundary

On 2026-08-16, the Status Menu showed one negative effect, `Dislocated Limb`,
and four positive effects: the ordinary `Fed` and `Hydrated` sustenance states,
an Alien Kebabs food effect, and an Alien Energy Drink effect. During the same
state, the Goal 9A HUD diagnostic reported three `aPersonalEffects` records and
one `aPersonalAlerts` record. Each persistent record exposed only `fHeading=0`
through ActionScript enumeration. The single alert exposed
`bIsPositive=true`; it therefore was not a count or representation of the
active negative effect.

The three persistent records align numerically with two sustenance states plus
one affliction, but that mapping remains an inference until direct
`sEffectIcon` reads and controlled expiration/removal tests identify each
record. The timed food and drink bonuses may be absent from the HUD provider.

Bethesda's Status Menu obtains its complete presentation from the separate
`PlayerStatusData.aEffectGroups[*].aEffects` model. That model supplies names,
descriptions, buff/debuff polarity, permanence, and remaining time. Goal 8's
runtime probe established that `PlayerStatusData` was not delivered in
HUDMenu, so the Status Menu list cannot be treated as a live HUD source. If the
refined diagnostic confirms that consumable bonuses are absent, the complete
active-effects requirement will need a native provider bridge; a HUD-only
implementation would knowingly omit effects.

## Diagnostic behavior

The temporary top-center diagnostic presents:

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
contains no input or callback attributes, and explicitly distinguishes
persistent records from transient events without assigning gameplay meaning.

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

## Rollback

Remove the two temporary provider subscriptions and diagnostic values from
`CUIPlayerHudDataContext`, remove the diagnostic include and component fragment,
and remove the matching build/staging assertions. Goal 8 compass behavior and
Goal 6 environmental behavior remain unchanged.
