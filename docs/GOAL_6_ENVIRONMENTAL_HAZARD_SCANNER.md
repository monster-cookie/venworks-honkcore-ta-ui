# Goal 6 environmental hazard scanner

**Status: Diagnostic implementation, automated build acceptance, and nominal
HUD baseline accepted; hazard-transition runtime acceptance pending.**

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

## Runtime acceptance plan

Build and deploy both normal and large HUD variants after recording their
SHA-256 hashes. Open the hand scanner to display the compact probe, then test
the following without treating a missing provider as a crash-worthy condition:

1. Confirm `EnvironmentEffectsData` receipt in a nominal environment.
2. Record every root field and each effect-entry field in the bounded panel.
3. Exercise radiation, thermal, airborne, and corrosive hazards separately and
   in combinations.
4. Record whether effect icons encode polarity or severity beyond category.
5. Record `fSoakDamagePct` range and direction while protection depletes and
   restores.
6. Record `bShouldPlayAlertAtFullSoak` transitions.
7. Compare any pulse/aggregate candidate with the visible vanilla environmental
   pulse without assigning semantics in advance.
8. Equip and remove spacesuit, helmet, and pack items and record the unaggregated
   resistance fields delivered through `PlayerInventoryData`.
9. Check `StarmapSystemBodyInfoProvider` before opening starmap, while entering
   and leaving it, and after the HUD resumes.
10. Test a breathable location, non-breathable atmosphere, and vacuum. Record
    Local Environment fields; do not derive vacuum from O2 alone.
11. Test water exposure to determine whether Bethesda emits airborne,
    corrosive, a distinct category, or no environment effect.
12. Repeat save/load, death/reload, scanner, ship, vehicle, ladder, workbench,
    and rapid menu transitions to identify stale values or lifecycle failures.

Production channel severity, units, aggregate scoring, planetary-baseline
display, and any history waveform remain out of scope until this diagnostic is
accepted with runtime evidence.

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
staged the compact scanner-gated diagnostic and preserved product scanner with
the accepted Goal 5 fragments.
Expected SHA-256 values are:

| Staged artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `hudmenu.gfx` | 390352 | `8A2E5C27E00D2E8C57C583ECFDE92E7CCEA2FF2E477F8329278BBF069F6A0B7E` |
| `hudmenu_lrg.gfx` | 390535 | `52C12B703236D78A05E0E125B3CDC982B6ED37D556D460D063B4448D73F3311E` |
| `VenworksCUI/layout.xml` | 3280 | `C3ECB63A915391948040A00679996D60279921DCA950B3C0D65FD6867E5DE4C0` |
| `VenworksCUI/components/environmental-hazard-diagnostic-strip.xml` | 4681 | `90691CB5EC0E47E3EF4C8FE75FB50EBB65D8DACF2B0E70DBEEB08B7D5194429C` |
| `VenworksCUI/components/environmental-hazard-scanner.xml` | 13295 | `8C98FEAE29A25CDC62D58F8C7097E4B8427E5145B3A55316A317DC227CD4A0C7` |

The normal and large GFX hashes were reproduced by their individual discovery
builds and by the final complete build. Runtime deployment must use artifacts
from the committed Goal 6 worktree.
