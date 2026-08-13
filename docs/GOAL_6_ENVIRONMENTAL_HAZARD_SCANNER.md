# Goal 6 environmental hazard scanner

**Status: Hazard-transition runtime acceptance, compact relative-load scanner,
movement-provider discovery, O2/boost activity proxy implementation, and
automated build acceptance are complete. Runtime proxy calibration is
pending.**

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

The active `environmental-hazard-diagnostic-strip.xml` is a semi-transparent
1160-by-196 top-center strip gated by the proven `inScanner` condition. The
calibration strip reports current normalized O2 reserve, normalized jetpack
charge, their downward-drain envelopes, combined activity, suit protection and
depletion, and all four modeled channel loads. It explicitly records that no
walking or vehicle-speed field is available.

Only a downward change greater than `0.0005` activates the corresponding drain
signal. Low but stable O2 or boost charge is not activity, and O2 recovery or
boost recharge is not activity. A detected drain attacks immediately to `1`
and decays by `0.82` every 250 ms until below `0.01`, when it becomes `0` and
the timer may stop if no hazard remains active.

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
an overlength ID or unsupported characters. The active include now uses the
short stable ID `env-hazard-probe`. The layout parser, composition resolver,
and composite resolver separately report missing, overlength, and unsupported-
character failures, including the rejected value and actual length when useful.

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
existing CUI host. It is a 360-by-230 panel anchored at the lower right with a
small inset from the screen and boost strip. It remains visible during ordinary
HUD use; standard HUD opacity and visibility ownership still apply. O2 and
temperature were removed because the independent lower-left environment panel
already displays them.

The compact panel provides:

- a 16-segment shared `SUIT PROTECTION` meter driven directly by clamped
  `fSoakDamagePct`;
- a numeric protection percentage and the bounded states `PROTECTION READY`,
  `PROTECTION PARTIAL`, and `FULL SOAK // HEALTH RISK`;
- four stacked category channels for Air/Water, Thermal, Corrosive, and
  Radiation; and
- independently drifting 16-segment `RELATIVE LOAD` bars whose presence is
  gated only by recognized Bethesda effect icons.

An absent category is exactly `0`. For an active category, the modeled target
is:

```text
depletion = 1 - protection
activity = max(oxygenDrainSignal, boostDrainSignal)
relativeLoad = clamp(
    0.05 + 0.10 * independentRandom + 0.35 * activity + 0.50 * depletion,
    0,
    1
)
```

Random targets are independently selected per category and eased toward at a
bounded 250 ms update cadence. At full protection and idle, active bars range
from 5% to 15%; full O2 or boost activity adds 35 percentage points. Half
protection adds 25 points, and exhausted protection adds 50 points. Higher bars
mean greater relative exposure load and health risk, not more remaining
protection. O2 and boost use are an explicitly modeled activity proxy, not
physical speed or Bethesda per-channel severity. Taking their maximum avoids
double-counting overlapping sprint/boost activity.

The layout does not display CO2, atmospheric pressure, a vacuum state, a raw
per-channel magnitude, a Threat Index formula, or physical units. The separate
HONKCORE combat Threat Index remains a future discovery/design topic and is not
reinterpreted as an environmental aggregate here.

## Production runtime acceptance plan

After both HUD artifacts are built, hashed, and committed, deploy them and
verify:

1. the compact lower-right panel remains readable with the scanner both closed
   and open and does not overlap the boost strip at normal or large HUD scale;
2. the activity calibration diagnostic appears only with the scanner open;
3. while idle, confirm both drain signals decay to zero and stable low reserves
   do not remain active;
4. while sprinting, confirm downward O2 changes attack the O2 signal and raise
   an already active hazard channel, then decay smoothly after stopping;
5. while jetpacking, confirm downward charge changes attack the boost signal,
   recharge does not count as activity, and overlapping O2/boost use is bounded
   by `max()` rather than added;
6. a nominal environment shows four zero-load channels and 100% protection;
7. a brief low-risk hazard activates only the matching category and its bar
   drifts within the healthy-protection range;
8. simultaneous effects produce independent drifting bars;
9. if protection safely drops partway, active bars shift upward while the
   shared protection bar shifts downward; and
10. leaving exposure immediately returns the inactive channel to zero while
   Bethesda restores protection on its own schedule.

The accepted captures already cover the dangerous full-soak transition; no
additional full-soak unsafe-water test is required.

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

The complete build passed on 2026-08-12. Both generated GFX variants compiled,
imported, reopened, passed their build and staged-layout contracts, and were
reproduced from the final source. All four staging variants contain the same
normal/large pair:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 395951 | `C7FC51DBDECDE0CC74089B10D5B252DC9B912C26302130F47FA857B723720654` |
| `hudmenu_lrg.gfx` | 396134 | `2602BC8D77812C6C85D730139BC7DD86BE672B1254037B5D87B9FF0A9258C9AF` |
| `VenworksCUI/layout.xml` | 3734 | `7112EA7DA33DAC0C02AD6A16F2D3086B265EEDF7AE7976F44A84841E28CF4862` |
| `components/environmental-hazard-scanner.xml` | 6860 | `FC822EE57ED481345C43E7460DC2219A2771D16BE1BC3A26C6AB2A6D1F6825BC` |
| `components/environmental-hazard-diagnostic-strip.xml` | 3337 | `96FFDC65D6E19BA0A3E12AE34C0FD6EEFECB3A756D8526C3947307A6F5879141` |

Runtime deployment must use artifacts from the user-committed Goal 6 worktree.
