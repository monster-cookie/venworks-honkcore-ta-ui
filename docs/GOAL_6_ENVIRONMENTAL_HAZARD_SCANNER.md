# Goal 6 environmental hazard scanner

**Status: The environmental hazard scanner and Planet Data presentation are
runtime accepted. The bounded player-data probe confirmed the final Goal 6
player-tricorder providers, and the storage-free exact-name-derived display
serial is runtime accepted. The production Player Data panel is implemented and
awaits its final in-game layout and behavior check.**

## Product direction

Goal 6 adds an independent helmet-HUD environmental scanner layout. The
selected visual direction is a wide scientific panel with four vertically
stacked sensor channels:

1. air/water toxins;
2. thermal exposure;
3. corrosive atmosphere; and
4. radiation.

The primary direction retains the selected Quad Sensor Channels structure.
Atmospheric composition may appear as a separate band above those channels,
but planetary baseline data must remain conceptually separate from immediate
live suit exposure.

The scanner is a reusable XML fragment rendered by the existing CUI host. This
diagnostic slice does not add a dedicated compiled scanner component. A future
component is justified only if accepted telemetry requires behavior that the
existing text, panels, dividers, icons, conditions, and meters cannot express.

## Roadmap and provider evidence

HONKCORE behavior and implementation may identify visual and provider
candidates. Candidate contracts are checked independently against Bethesda
movie artifacts or CUI runtime behavior before they become production data.

The former HONKCORE CBRN presentation confirms the desired four-channel
roadmap, but its displayed threat index is derived from its own count of active
categories. Its animated bars are synthetic. Neither implementation is
Bethesda environmental-provider evidence, so Goal 6 does not copy either
formula or animation.

### Immediate HUD candidates

| Display concept | Provider and field | Classification before Goal 6 runtime | Use in diagnostic |
| --- | --- | --- | --- |
| Atmospheric oxygen | `LocalEnvironmentData.fOxygenPercent` | Confirmed in HUD runtime by Goal 5 | Live percentage |
| Local temperature | `LocalEnvironmentData.fTemperature` | Confirmed in HUD runtime by Goal 5 | Live temperature; not treated as hazard magnitude |
| Local gravity | `LocalEnvironmentData.fGravity` | Confirmed in HUD runtime by Goal 5 | Context only |
| Planetary local time | `LocalEnvData_Frequent.fLocalPlanetTime` | Confirmed in Bethesda HUD movie and Goal 5 runtime | Live local 24-hour display |
| Galactic Standard Time / UT | `LocalEnvData_Frequent.fGalacticStandardTime` | Clean-room roadmap candidate only; not independently confirmed in Bethesda HUD runtime | Future player-scanner probe; not displayed in Goal 6 |
| Active environmental effects | `EnvironmentEffectsData.aEnvironmentEffects` | Provider is a HONKCORE roadmap candidate; array field is confirmed in Bethesda HUD-related code | Bounded receipt and field probe |
| Hazard category | `aEnvironmentEffects[*].sEffectIcon` | Confirmed in Bethesda `EnvironmentEffectsWidget` and `WatchIconsWidget` contracts | Four categorical activity gates |
| Radiation category | `HazardEffect_Radiation` | Confirmed in Bethesda HUD movie | Detected/clear only |
| Thermal category | `HazardEffect_Thermal` | Confirmed in Bethesda HUD movie | Detected/clear only |
| Airborne category | `HazardEffect_Airborne` | Confirmed in Bethesda HUD movie | Airborne detected/clear; water remains unproven |
| Corrosive category | `HazardEffect_Corrosive` | Confirmed in Bethesda HUD movie | Detected/clear only |
| Suit-soak candidate | `EnvironmentEffectsData.fSoakDamagePct` | HONKCORE roadmap candidate | Raw diagnostic and bounded `0..1` meter candidate only after runtime proves range |
| Full-soak alert candidate | `EnvironmentEffectsData.bShouldPlayAlertAtFullSoak` | HONKCORE roadmap candidate | Raw Boolean diagnostic |
| Bethesda normalized pulse | `EnvironmentEffectsWidget.SetPulseSpeedPct(0..1, flag)` | Confirmed widget input; owning provider and meaning unknown | Search provider fields only; no Threat Index mapping |

The pulse setter interpolates the widget's minimum and maximum pulse times. A
value of `1` stops the animation at full opacity, while `0` can either stop or
run at the minimum pulse time depending on the second Boolean. Direction,
ownership, and environmental meaning therefore require runtime evidence before
any normalized aggregate can be exposed.

### Protection candidates

Bethesda inventory item cards consume these equipped-item fields:

- `ArmorInfo.fThermalResist`;
- `ArmorInfo.fAirborneResist`;
- `ArmorInfo.fCorrosiveResist`; and
- `ArmorInfo.fRadiationResist`.

Those fields are confirmed in an inventory-menu contract. Goal 5 already
confirmed that `PlayerInventoryData` is live in HUD, but it has not proven that
all equipped armor entries and their `ArmorInfo` objects are present there.
The diagnostic reports up to four equipped armor records without aggregating
them. No suit-total formula is assumed.

### Planetary baseline

`GalaxyStarMapMenu` subscribes to `StarmapSystemBodyInfoProvider` and forwards
the payload to Bethesda's planet information card. The card statically consumes
at least:

- `sGravityDescriptor` and `fGravity`;
- `sTempDescriptor`;
- `sAtmospherePressure`;
- `sAtmosphereType`;
- `sAtmosphereToxicity`;
- `sMagnetosphere`;
- `sWaterDescriptor` and `sWaterQuality`;
- flora and fauna descriptors/probabilities; and
- scan, survey, visit, and entered-system state.

These are confirmed starmap-menu fields, not confirmed HUD fields. The Goal 6
diagnostic subscribes only to determine whether the provider is ever delivered
during the HUD movie lifetime. Receipt does not by itself prove that values
remain current or safe after starmap transitions.

### Player movement candidates

Static inspection does not establish a walking, sprinting, boosting, or ground-
vehicle speed value in `HUDMenu`. The relevant candidates are classified as:

| Candidate | Classification | Evidence and lifetime |
| --- | --- | --- |
| `HUDVehicleData` | Confirmed in HUD | Bethesda's HUD vehicle widget consumes `bInVehicle`; no speed member is statically consumed. |
| `PlayerFrequentData` | Confirmed in HUD | Live player health, oxygen, CO2, and power fields are known; movement fields remain unknown. |
| `HudCrosshairData` | Confirmed in HUD | HUD-owned provider; no speed member is statically proven. |
| `HUDStealthData` | Confirmed in HUD | HUD-owned provider; no speed member is statically proven. |
| `HudJetpackData` | Confirmed in HUD | `fJetpackCharge` is live; charge is not player speed. Other movement fields remain unknown. |
| `StickDataProvider.speed` | Confirmed elsewhere/menu-owned | Bethesda's spaceship HUD consumes this field. Its `SpaceshipHudMenu` ownership does not make it available or lifetime-safe in `HUDMenu`. |
| Walking/sprinting/boosting speed | Not available in tested HUD providers | No inspected `HUDMenu` script names or consumes a suitable field, and runtime enumeration found no speed-named candidate. |

The smallest runtime probe listed bounded field names and searched movement-
related candidate names on the five confirmed HUD providers above. Runtime
testing while stationary, sprinting, jetpacking, and driving found no numeric
walking or ground-vehicle speed. `HUDVehicleData` exposed only `bInVehicle`.
The field-name probe also did not display ordinary values such as O2 reserve or
jetpack charge, so it was replaced after completing its bounded search. The
runtime does not subscribe to a spaceship-menu provider or assume that vehicle
UI injection makes a field globally available.

### Player-tricorder candidates

The accepted environmental layout frees the lower-left surface for a matching
player tricorder. Its requested production fields are classified before the
bounded runtime probe as follows:

| Display concept | Provider and field | Classification before player probe |
| --- | --- | --- |
| Health | `PlayerFrequentData.fHealth` / `fMaxHealth` | Confirmed in HUD runtime |
| Shared O2/CO2 | `PlayerFrequentData.fOxygen`, `fCarbonDioxide`, `fMaxO2CO2` | Confirmed in HUD runtime and Bethesda HUD movie |
| Carry weight | `PlayerInventoryData.fEncumbrance` / `fMaxEncumbrance` | Confirmed in HUD runtime |
| Credits | `PlayerInventoryData.uCoin` | Confirmed in HUD runtime |
| Boost charge | `HudJetpackData.fJetpackCharge` | Confirmed in HUD runtime |
| Character name | `PlayerData.sName` | Confirmed in HUD runtime |
| Player level | `PlayerData.uLevel` | Confirmed in HUD runtime |
| XP progress | `PlayerData.fLevelXP` / `fNextLevelXP` | Confirmed in HUD runtime |
| Universal time | `LocalEnvData_Frequent.fGalacticStandardTime` | Confirmed in HUD runtime and formatted by the production player panel |
| Venworks actor value | `PlayerData.VWKS_PlayerLevel` candidate for Actor Value `000030:Venworks-Core.esm` | Absent from the received HUD payload (`NULL`) |
| Digipick count | `PlayerInventoryData.aItems[*].uCount` for base form `00000A:Starfield.esm` | Confirmed in HUD runtime by exact base form |
| Save/player serial | ID-, serial-, save-, character-, actor-, form-, reference-, or `VWKS`-named `PlayerData` member | No candidate found by bounded HUD runtime enumeration |

Bethesda's HUD movie subscribes to `PlayerData`, but its inspected bottom-left
widget consumes only `bIsInCombat`. Runtime testing independently proved that
the same HUD-lifetime payload includes character name, level, current XP, and
next-level XP. Defining an Actor Value record does not by itself project its
EditorID into that payload: `VWKS_PlayerLevel` was `NULL` even though the
`000030:Venworks-Core.esm` Actor Value exists.

The scanner-only probe enumerated at most 32 `PlayerData` root fields and
reported the five requested exact members separately. The runtime payload
provided `sName`, `uLevel=150`, `fLevelXP=15104.5`, and
`fNextLevelXP=17175`, while its bounded serial-like candidate search returned
none. `LocalEnvData_Frequent` simultaneously provided
`fGalacticStandardTime=2.85866472415698`,
`fLocalPlanetTime=0.623948012487412`, and
`fLocalPlanetHoursPerDay=41`. These values are provider evidence, not yet a
production clock-format decision.

The digipick search inspects at most 256 inventory entries. Runtime matched the
numeric base form `0x00000A` with `uFormID=10`, `uCount=51`, and
`sName=DIGIPICK`; `sEditorID` remained `NULL`. The exact base form is therefore
the production-capable identity, independent of localized display name.

No Bethesda save/player serial is exposed by the tested HUD provider. The first
approved fallback experiment used Flash `SharedObject` storage, but the deployed
HUD reported `Error #1501` when `flush()` attempted to write. That error means the
host has not installed a `SharedObjectManager`; providing one requires native
application-layer loader support and is outside this Scaleform-only, no-SFSE
project.

The replacement derives a display-only serial directly from the exact character
name without storage, randomness, native code, or a new save field. It maps the
case- and whitespace-sensitive name deterministically to 18 uppercase `A-Z0-9`
characters and displays them as `XXXXXXXX-XXXX-XXXXXX`. The same exact name
always produces the same value, including after save reload, game restart, or a
Unity transition because it is recomputed rather than persisted. Renaming changes
the value, and two characters with identical exact names collide by design. The
result is not a Bethesda identifier, save identifier, globally unique identifier,
or security token. Runtime accepted the deterministic 8-4-6 display, including
stable regeneration without a persistence error.

## Unknowns that must not be invented

The inspected Bethesda contracts do not yet prove:

- atmospheric CO2 or inert-gas composition;
- numeric atmospheric pressure;
- an explicit mutually exclusive vacuum/no-atmosphere field;
- distinct airborne and water contamination values;
- per-channel raw magnitude or normalized severity;
- an aggregate environmental exposure or threat value;
- physical toxin, corrosion, or radiation units; or
- a meaningful telemetry sample rate.

The scanner consequently omits ppm, radiation-dose units, corrosion-rate
units, pressure units, a sample-rate claim, and spectrum-like waveforms. Its
relative-load bars are explicitly modeled display values based only on active
category presence and remaining protection; they are not presented as raw
Bethesda measurements. If a normalized Bethesda environmental value is found,
a future history trace may plot actual successive samples and must be labeled
as normalized history, not as a physical spectrum.

## Diagnostic implementation

The packaged `environmental-hazard-scanner.xml` product fragment is independent
from the four accepted Goal 5 Chronomark fragments. Earlier diagnostic builds
bounded environment discovery to 12 root fields, four effect objects, eight
fields per effect, 32 scanned effect entries, four equipped armor items, and 48
characters per scalar value. That probe established the environment evidence
recorded below. The subsequent movement-provider probe has also completed and
is recorded above.

The retired `environmental-hazard-diagnostic-strip.xml` was a semi-transparent
1160-by-196 top-center strip gated by the proven `inScanner` condition. It
reported current normalized player-O2 reserve, downward-drain detection, the
gradual O2 activity envelope, suit protection and depletion, and all four
modeled channel loads. It explicitly distinguished the pink player-O2 reserve
from atmospheric O2 and recorded that boost is excluded. Runtime acceptance
completed its purpose, so neither the source fixture, staged component, nor
layout include remains in the final production package. The diagnostic data
adapter stays bounded in ActionScript for future layouts without rendering an
overlay.

The subsequent `player-data-diagnostic-strip.xml` was likewise scanner-gated
and bounded. It confirmed player name, level, XP, Galactic Standard Time, the
exact Digipick base form, and the deterministic serial. Its source fixture,
staged component, and layout include are retired now that those values feed the
production Player Data panel.

A downward player-O2 change greater than `0.0005` marks the next 250 ms update
as active drain. Each active tick adds `0.08` to the bounded O2 activity
envelope; each tick without detected drain subtracts `0.10`. Sustained running
therefore builds to full activity in approximately 3.25 seconds and releases
in approximately 2.5 seconds. Low but stable player O2 and O2 recovery are not
activity. Boost does not contribute to environmental load.

## Nominal HUD runtime evidence

The first Goal 6 runtime capture in a nominal outdoor environment established:

- `EnvironmentEffectsData` is delivered during ordinary `HUDMenu` lifetime;
- its root contains `aEnvironmentEffects`, `fSoakDamagePct`,
  `bShouldPlayAlertAtFullSoak`, `uEnvIconPulseMinMS`, and
  `uEnvIconPulseMaxMS`;
- the nominal sample reported `fSoakDamagePct=1`,
  `bShouldPlayAlertAtFullSoak=false`, `uEnvIconPulseMinMS=200`, and
  `uEnvIconPulseMaxMS=2000`;
- all four bounded effect rows were unused in that nominal sample;
- live O2 and temperature agreed with the accepted Goal 5 Chronomark display;
- equipped armor entries delivered unaggregated thermal, airborne, corrosive,
  and radiation resistance values; and
- `StarmapSystemBodyInfoProvider` was not received during the observed ordinary
  HUD lifetime.

This single safe sample does not establish whether `fSoakDamagePct` changes,
which direction it moves, or whether it owns Bethesda's normalized pulse input.
The 200 and 2000 millisecond values are confirmed timing bounds, not a current
threat score. Starmap non-receipt in this sample also does not prove that the
provider can never appear during menu transitions.

## Compact-probe validation incident

The first compact-probe deployment was rejected safely by the live CUI error
panel during layout parsing. Include resolution prefixes each fragment-local
component ID with the include ID. The original 38-character
`environmental-hazard-diagnostic-strip.` prefix expanded two otherwise valid
local text IDs beyond the runtime's 64-character component-ID limit:

- `diagnostic.environment.candidates` resolved to 71 characters; and
- `diagnostic.environment.fields` resolved to 67 characters.

The runtime correctly refused the invalid layout, but its generic
`Invalid or missing id on text` message did not distinguish an absent ID from
an overlength ID or unsupported characters. The corrected diagnostic used the
short stable ID `env-hazard-probe` until its runtime work completed. The layout
parser, composition resolver, and composite resolver separately report missing,
overlength, and unsupported-character failures, including the rejected value
and actual length when useful.

The build now evaluates every component ID after applying its include prefix
and contains a regression check for the known 71-character failure. It also
verifies that all three actionable error categories survive GFX compilation and
reopen. A future GUI builder should enforce this same composed-ID contract
before export, while live runtime validation remains authoritative for hand-
edited XML, package drift, and builder/runtime version mismatches.

## Hazard-transition runtime evidence

The compact diagnostic was exercised across safe environments, local flora,
unsafe biological water, extreme heat and cold, corrosive atmosphere,
radiation, multi-effect planets, and no-atmosphere moons. Runtime established:

- `HazardEffect_Airborne`, `HazardEffect_Thermal`,
  `HazardEffect_Corrosive`, and `HazardEffect_Radiation` all reach HUDMenu in
  `aEnvironmentEffects`;
- hot and cold environments both use `HazardEffect_Thermal`; the live local
  temperature supplies polarity and context but is not a channel magnitude;
- Venus produced Thermal and Corrosive entries concurrently;
- other tested surfaces produced Thermal and Radiation concurrently, proving
  the bounded array can represent simultaneous category activity;
- Akila's unsafe biological water produced `HazardEffect_Airborne`, the same
  category used by hazardous plant mist; no confirmed field distinguishes air
  from water after it reaches HUDMenu;
- active categories can be present while `fSoakDamagePct` remains `1`, so the
  field is not category presence or per-channel severity;
- during sustained unsafe-water exposure, `fSoakDamagePct` moved from `1`
  through `0.902703...` to `0`;
- at `0`, `bShouldPlayAlertAtFullSoak` became `true`, remained true for at least
  another three to five seconds, and direct health damage followed;
- the visible environmental alarm could already appear full while the field
  was approximately `0.813664` and the full-soak Boolean was false, so neither
  field is a direct representation of the vanilla alarm graphic;
- leaving the water cleared the effect and restored the value toward `1`
  almost immediately; and
- both no-atmosphere moons and Venus reported O2 `0%`. Oxygen therefore cannot
  distinguish vacuum from a non-oxygen atmosphere.

This evidence supports treating clamped `fSoakDamagePct` as Bethesda's
normalized remaining suit-protection reserve: `1` is ready, intermediate
values are partial reserve, and `0` with the full-soak flag is health-risk
exposure. It does not support a Threat Index, physical units, independent
channel magnitudes, or an atmospheric-pressure/vacuum inference.

## Compact production implementation

The production scanner remains an independent XML fragment rendered by the
existing CUI host. It is a 360-by-312 stacked panel anchored at the lower right.
The root layout's 64-unit right and 36-unit bottom safe insets combine with
approved include offsets `x=39`, `y=11` to place the outer border 25 design
units from the physical right and bottom edges while retaining responsive
`visibleRect` anchoring. It remains visible during ordinary HUD use; standard
HUD opacity and visibility ownership still apply.

The compact panel provides:

- a distinct `PLANET DATA` section above the suit readout containing the
  confirmed location/body label, planetary local time, atmospheric O2,
  temperature, and gravity;
- a 16-segment shared `SUIT PROTECTION` meter driven directly by clamped
  `fSoakDamagePct`;
- a numeric protection percentage and the bounded states `PROTECTION READY`,
  `PROTECTION PARTIAL`, and `PROTECTION DEPLETED`;
- four stacked category channels for Air/Water, Thermal, Corrosive, and
  Radiation; and
- independently drifting 16-segment load bars whose presence is gated only by
  recognized Bethesda effect icons. The ambiguous `RELATIVE LOAD` header is
  not displayed.

The production lower-left `PLAYER DATA` fragment replaces the former environment,
meter, and mobility fragments. Its identity band displays the deterministic
serial, level, Galactic Standard Time, current/max carry weight, credits, and
the exact-form Digipick count when the inventory array is available. Five
normalized tracks show XP to level, health, shared O2/CO2, boost charge, and
encumbrance. O2 drains in magenta and CO2 grows in red on the same visual track.
Encumbrance is clamped to a full bar at or above capacity. Active power moves
temporarily to the upper-right weapon fragment; the next goal may revise that
weapon presentation.

An absent category is exactly `0`. For an active category, the modeled target
is:

```text
depletion = 1 - protection
activity = gradual player-O2 drain envelope
relativeLoad = clamp(
    0.05 + 0.10 * independentRandom + 0.25 * activity + 0.70 * depletion,
    0,
    1
)
```

Random targets are independently selected per category and eased toward at a
bounded 250 ms update cadence. At full protection and idle, active bars range
from 5% to 15%; sustained player-O2 drain adds up to 25 percentage points.
Half protection adds 35 points, and exhausted protection adds 70 points. Idle
load with no protection is therefore 75% to 85%; sustained running can bring it
to 100%. Higher bars mean greater relative exposure load and health
risk, not more remaining protection. Player-O2 use is an explicitly modeled
activity proxy, not physical speed or Bethesda per-channel severity. Boost was
removed after a runtime tap drove the binary proxy immediately to full activity.

An active category bypasses randomness and interpolation and snaps to `100%`
when protection is `0` and Bethesda's `bShouldPlayAlertAtFullSoak` is true. It
remains fixed at `100%` while those environmental conditions remain true, then
snaps back to the normal model when the flag or exhausted-protection condition
clears. Generic player-health loss is not inspected because HUDMenu exposes no
proven field attributing an individual damage event to the environment.

The layout does not display CO2, atmospheric pressure, a vacuum state, a raw
per-channel magnitude, a Threat Index formula, or physical units. The separate
HONKCORE combat Threat Index remains a future discovery/design topic and is not
reinterpreted as an environmental aggregate here.

## Production runtime acceptance plan

After both HUD artifacts are built, hashed, and committed, deploy them and
verify:

1. the combined lower-right border sits approximately 25 design units from the
   physical right and bottom edges at normal and large HUD scale;
2. `PLANET DATA` appears above `ENVIRONMENTAL HAZARDS` and shows the live
   location/body label, local time, atmospheric O2, temperature, and gravity;
3. those five values no longer appear in the lower-left panel, while the
   consolidated Player Data panel remains functional;
4. `RELATIVE LOAD` and `FULL SOAK // HEALTH RISK` are absent, and exhausted
   protection reads `PROTECTION DEPLETED`;
5. opening the scanner does not render the retired diagnostic strip;
6. nominal environments still show four empty channels and ready protection;
7. active and simultaneous categories still use independent drifting bars;
8. zero protection before the full-soak flag remains within the accepted idle
   range, and the full-soak critical state still snaps active categories to
   100%; and
9. leaving exposure immediately returns inactive channels to zero while
   Bethesda restores protection on its own schedule.

The accepted captures already cover the dangerous full-soak transition; no
additional full-soak unsafe-water test is required.

## Player Data production runtime acceptance plan

The deterministic serial diagnostic is accepted and removed. The final Goal 6
runtime pass verifies the production presentation:

1. the 360-design-unit Player Data panel sits approximately 25 units from the
   physical left and bottom edges at normal and large HUD scale;
2. serial, level, universal time, carry weight, credits, and Digipicks match the
   proven provider values, and the Digipick field hides if the inventory array
   is unavailable;
3. XP and health tracks follow their normalized provider ratios;
4. the shared O2/CO2 track drains magenta O2, then grows red CO2;
5. boost charge drains and refills, while encumbrance becomes full at or above
   carrying capacity;
6. weapon, ammunition, explosives, vehicle exit, and the temporary active-power
   readout remain functional in the upper-right; and
7. neither retired diagnostic strip renders when the scanner opens.

The user commits the generated build before deployment.

## Automated validation and expected artifacts

Run repository validation and the complete two-variant Scaleform build:

```powershell
./Tools/checkRepo.ps1
```

```powershell
./Tools/compileScaleform.ps1 `
  -JavaPath "<approved-java-path>" `
  -JpexsJarPath "<approved-ffdec-path>" `
  -VanillaInterfacePath "<approved-vanilla-interface-path>"
```

The earlier SharedObject diagnostic passed automated build validation but was
rejected by runtime Error #1501 because the Scaleform host does not install a
`SharedObjectManager`. The deterministic replacement removes the rejected
storage path. On 2026-08-13 the production Player Data build compiled, imported,
reopened, passed its source and staged-layout contracts, and reproduced the
normal/large pair across all four staging variants:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 400628 | `543B21D698B8356F8F00DCD2522754A84343ECCE486F2D75A94E67D797C624F6` |
| `hudmenu_lrg.gfx` | 400811 | `975EDB52FDF3082B1874411B66392A85B7010C86A889EC875407EBACF26C94B7` |
| `VenworksCUI/layout.xml` | 3736 | `51D2128ABA3E0154D210DD061A095A2D20602255D059FFEB0F93786DB923443C` |
| `components/player-status-scanner.xml` | 8819 | `60D28CBEFB55DE21316571BA2224EB7429054FA3DE2AA3F8CA3B250F3121E94C` |
| `components/environmental-hazard-scanner.xml` | 9856 | `055A9A7D51EF8016AAD3EAEC533885C430FD05888CCB5C76AC01FEE5A14BECA8` |
| `components/weapon-status.xml` | 4455 | `81FF1E81CC4647736A4C360C131BDF68D84D566338268BFF2AEC68D508248894` |

Runtime deployment must use artifacts from the user-committed Goal 6 worktree.
