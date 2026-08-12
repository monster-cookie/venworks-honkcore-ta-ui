# Goal 6 environmental hazard scanner

**Status: Diagnostic discovery, hazard-transition runtime acceptance, compact
production scanner implementation, and automated build acceptance complete;
production layout runtime acceptance pending.**

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

The diagnostic consequently omits ppm, radiation-dose units, corrosion-rate
units, pressure units, a sample-rate claim, and spectrum-like waveforms. If a
normalized Bethesda environmental value is found, a future history trace may
plot actual successive samples and must be labeled as normalized history, not
as a physical spectrum.

## Diagnostic implementation

The packaged `environmental-hazard-scanner.xml` product fragment is independent
from the four accepted Goal 5 Chronomark fragments. It provides:

- a live O2 and temperature atmosphere band;
- explicit unproven placeholders for CO2/inert composition, pressure, and
  vacuum/no-atmosphere state;
- four binary category-activity meters driven only by recognized Bethesda
  effect-icon categories;
- bounded enumeration of the environment-provider root and four effect
  entries;
- a focused search for pulse, speed, threat, severity, exposure, and soak
  candidate fields;
- raw suit-soak and full-alert candidates;
- unaggregated equipped armor resistance candidates; and
- starmap-provider receipt/lifetime evidence.

Diagnostic enumeration is bounded to 12 root fields, four effect objects,
eight fields per effect, 32 scanned effect entries, four equipped armor items,
and 48 characters per scalar value. Arrays are reported by length and nested
objects are not recursively serialized.

The full 1530-by-520 product fragment remains packaged but inactive during the
hazard-transition probe. The active `environmental-hazard-diagnostic-strip.xml`
fragment is a semi-transparent 1160-by-196 top-center strip gated by the proven
`inScanner` condition. It retains provider receipt, the raw soak/full-alert
candidates, the bounded environment root and candidate lists, and four
full-width effect-object rows. Local-environment, armor, and starmap baseline
diagnostics remain available in the provider context and are recorded below;
they do not consume navigation space during repeated hazard tests.

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
existing CUI host. It is a 510-by-342 center-right panel gated by the proven
`inScanner` condition. The accepted diagnostic fragment remains packaged for
future provider investigation but is no longer included by the active layout.

The compact panel provides:

- live O2 percentage and temperature;
- a 20-segment shared `SUIT PROTECTION` meter driven directly by clamped
  `fSoakDamagePct`;
- a numeric protection percentage and the bounded states `PROTECTION READY`,
  `PROTECTION PARTIAL`, and `FULL SOAK // HEALTH RISK`;
- four stacked category channels for Air/Water, Thermal, Corrosive, and
  Radiation; and
- full/empty categorical channel bars driven only by recognized Bethesda
  effect icons.

The Air/Water channel explicitly notes that unsafe water and airborne exposure
share Bethesda's Airborne category. The layout does not display CO2,
atmospheric pressure, a vacuum state, per-channel magnitude, a threat formula,
physical units, or synthetic telemetry.

## Production runtime acceptance plan

After both HUD artifacts are built, hashed, and committed, deploy them and
verify:

1. the panel is absent with the scanner closed;
2. the compact center-right panel appears with the scanner open and does not
   obstruct navigation at normal and large HUD scale;
3. a nominal environment shows four clear channels and 100% protection;
4. a brief low-risk hazard activates the matching categorical channel and
   moves protection in Bethesda's reported direction;
5. simultaneous effects activate their corresponding channels; and
6. leaving exposure clears the channel and restores protection without an
   artificial delay.

The accepted captures already cover the dangerous full-soak transition; no
additional full-soak unsafe-water test is required.

## Automated validation and expected artifacts

The repository validation and complete two-variant Scaleform build passed:

```powershell
./Tools/checkRepo.ps1
```

```powershell
./Tools/compileScaleform.ps1 `
  -JavaPath "<approved-java-path>" `
  -JpexsJarPath "<approved-ffdec-path>" `
  -VanillaInterfacePath "<approved-vanilla-interface-path>"
```

The build compiled, imported, reopened, and validated both GFX variants, then
staged the compact scanner-gated production meter, retained the inactive
diagnostic fragment, and preserved the accepted Goal 5 fragments.
Expected SHA-256 values are:

| Staged artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 390719 | `A37998F1A81D84A41D72FE9759A60DA7ACCE733B78477A4F1D51B927614C16EA` |
| `hudmenu_lrg.gfx` | 390902 | `4BB40384FA6E6D48AAB65CC8FDD067D39CB7D126DFC9208CB11AB08AD096B22C` |
| `VenworksCUI/layout.xml` | 3546 | `3BAE1696A2CB0B6C98A61AF96BC6DF9498BFAE9064AA1839F98EB4DFE033704C` |
| `VenworksCUI/components/environmental-hazard-diagnostic-strip.xml` | 4681 | `90691CB5EC0E47E3EF4C8FE75FB50EBB65D8DACF2B0E70DBEEB08B7D5194429C` |
| `VenworksCUI/components/environmental-hazard-scanner.xml` | 8162 | `40152E268FCB1B3298D24A773ADF3694D5E8B39EC8C02A824174C3DAA9CAA120` |

The normal and large GFX hashes were reproduced by their individual discovery
builds and by the final complete build. Runtime deployment must use artifacts
from the committed Goal 6 worktree.
