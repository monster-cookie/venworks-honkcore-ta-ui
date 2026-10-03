# Canvas theme consumers

The five VWHUD themes are implemented as Canvas HTML/CSS/SVG consumers on `VWCANVAS_HTML/2`. The standalone XML/Scaleform runtime and PS5 diagnostic variant were unreleased development paths and have been removed. Every shipped theme now has one architecture and one release pipeline.

## Ownership

| Concern | Owner and source |
| --- | --- |
| Consumer registration, lifecycle, snapshots, and provider-derived presentation | [VWHudConsumer.as](../CanvasConsumer/actionscript/VWHudConsumer.as) and related classes under [CanvasConsumer/actionscript](../CanvasConsumer/actionscript) |
| Effect discovery, catalogs, retry, refresh, and publication | [HudEffectsPublisher.psc](../Papyrus/Venworks/CustomizableHUD/HudEffectsPublisher.psc) |
| Start-game registration quest and UI-load reconciliation | [HudRegistrar.psc](../Papyrus/Venworks/CustomizableHUD/HudRegistrar.psc) |
| Playtest console probe that applies one generic buff or debuff per class | [HudStatusProbe.psc](../Papyrus/Venworks/CustomizableHUD/HudStatusProbe.psc) |
| Theme entry documents and identity | [CanvasConsumer/variants](../CanvasConsumer/variants) |
| Shared HTML, CSS, SVG, and artwork | [CanvasConsumer/resources](../CanvasConsumer/resources) |
| Real theme plugin records | [Spriggit](../Spriggit) |
| Shared hosts, provider acquisition, event transport, HUD targets, and rendering | External Venworks Canvas dependency |

The local `CanvasConsumer` directory contains only VWHUD-owned consumer implementation. It does not copy Canvas's host, HTML parser, renderer, registry, Example content, ESM, or player/ship HUD replacements.

## Runtime asset root

Canvas currently requires every consumer to install beneath an isolated directory:

```text
Interface/VenworksCanvas/Consumers/<consumer-namespace>/
```

VWHUD uses `venworks.vwhud.<variant>`. The ESM's `NormalMoviePath` and `LargeMoviePath` omit the leading `Interface/` because the host resolves those URLs relative to Starfield's Interface directory. The BA2 and loose packages use the complete path.

This prefix is an enforced Canvas loader contract rather than an indication of file ownership. Each namespace directory contains the add-on's own SWFs, HTML, CSS, SVG, and local assets. The isolated root makes relative resource resolution deterministic and prevents a document from escaping into another consumer's files. A different root would require a coordinated Canvas contract change; it cannot be selected by a VWHUD package alone.

## Presentation and data

The four full themes share `themed.html`; Minimalist uses `minimalist.html` and its reduced composition. Standard SVG elements and attributes define vector artwork. Canvas owns display objects and provider acquisition. VWHUD owns tactical meaning, theme selection, compact status pages, and the snapshots supplied to Canvas.

Each entry document loads `vwhud-overrides.css` last and exposes stable `vwhud-panel-*` classes on its outer panels. [Customizing VWHUD themes](CUSTOMIZING_THEMES.md) documents the supported PC override surface and keeps Canvas's Component Gallery authoritative for the renderer's HTML, CSS, and SVG subset.

The full themes retain 18 unique provider channels and Minimalist retains 14. Removing the earlier status renderer does not remove inputs still used for environment or threat calculations.

## Status effects

Each theme publishes complete `effects.state` snapshots to `venworks.vwhud.<variant>.status` using schema `1`, `ci-ascii`, `startup: "latest"`, and Canvas's 4,096-character framed-event limit. The display puts buffs on one line and debuffs on the next two lines, eighteen icons to a line, and rotates a longer list every six seconds. Waiting and empty states stay explicit. A page indicator appears only when a line has more than one page.

Candidate effect entries and source references remain separate from the submitted snapshot. Only `EVENT_SUBMITTED` commits the entries, references, signature, and timestamp. Missing prerequisites, invalid or oversized datagrams, and rejected sends retain the last submitted state and use a bounded half-second retry budget. An independent 60-second refresh remains armed even if no send succeeds. Save/load revisions reject stale scans and publish completions.

The consumer retains the newest complete valid status event before its HTML bridge is ready and reapplies it after readiness or bridge replacement. Malformed and foreign-topic events do not clear the last valid state. Final unload clears state and timers and ignores late events until a new lifecycle begins. `EVENT_SUBMITTED` proves registry acceptance only; it is not a delivery acknowledgement from the SWF.

## HUD controls and updates

Themes declaratively suppress the Canvas HUD targets they replace. Canvas combines requests from multiple consumers, releases only the departing consumer's requests, follows engine-hidden state, and leaves game actions and shared event ingress active. Named native symbols, including the vehicle-exit glyph, remain host-owned adapters rather than copied controls.

Frequent updates are ordinary changing inputs such as health, heading, and contact positions. Canvas validates each complete snapshot, retains existing display objects where possible, updates affected bindings in place, and reconciles repeated subtrees when their structure changes. Rejected data preserves the last valid display. These are implementation contracts, not measured latency or frame-rate claims.

## Verification and acceptance

The build compiles five consumer SWFs, three Papyrus scripts, and five real ESMs into isolated package inputs. Transactional packaging produces 15 Main BA2 archives, installs archive-only staging, and removes exact loose Interface and Script targets after successful verification. The Fully Loose Nexus ZIP is reconstructed from the verified Windows Main BA2 rather than loose staging. Verification checks exact inventories, source evidence, resource bytes, SWF contracts, archive bytes, and ZIP contents. The lifecycle diagnostic under [CanvasConsumer/diagnostics](../CanvasConsumer/diagnostics) compiles separately and is excluded from packages.

Runtime acceptance remains separate. Each exact candidate package requires archive-only PC and PS5 testing for normal and large HUD modes, aiming and scanner transitions, health and oxygen, compass and radar response, status application/removal/recovery/paging, vehicle input and glyphs, ship visibility controls, menus, death/reload, save/load, 4K/8K, and representative ultrawide placement. Sustained activity must also confirm stable object and timer behavior. VWHUD-32 through VWHUD-36 track per-theme acceptance.

VWHUD requires Canvas's `VWCANVAS_CONSUMER/3` host support and the Registry's `BuildCanvasDatagramBody` and `TryPublishCanvasDatagram` methods while continuing to render through `VWCANVAS_HTML/2`. The consumer build now rejects a Canvas source checkout missing any of those contracts. At runtime, the combination of `UNSUPPORTED CONSUMER PROTOCOL` in the Canvas display and a missing `BuildCanvasDatagramBody` Papyrus method establishes that the Canvas code loaded by that game process does not expose VWHUD's expected contract. It does not, without evidence from the affected installation, distinguish mixed package versions, overriding archives or loose files, or code retained by a process that was not restarted. Fully stop the game, verify the deployed Canvas and VWHUD bytes and their providers, redeploy Canvas 1.0.4 or newer, and restart before retesting. Downgrading the VWHUD consumer protocol would bypass required event and rendering behavior and is not a compatible repair.
