# Canvas theme consumers

The v2 pipeline now builds the five VWHUD themes as Canvas HTML/CSS consumers. These are migration candidates awaiting archive-only PC and PS5 acceptance. The v1 XML pipeline and matching rollback packages remain available; this migration does not establish a new accepted console release.

## Installation and compatibility

Install Venworks Core Library, the matching Canvas build with `VWCANVAS_HTML/3` support, and exactly one VWHUD theme. Load Core before Canvas and Canvas before the theme plugin. The plugin also declares `Starfield.esm` and `sfbgs007.esm` as masters, including the Core dependency's transitive master. The separately distributed Canvas Example is not required.

Keep each theme's existing ESM and archive names together. Do not install old VWHUD HUD replacement movies alongside the consumer package. Remove loose legacy HUD replacements when migrating; loose files can shadow the archives. Preserve your previous complete package and save backup before testing. Roll back the matching plugin and archive together, with the previous dependency versions when required.

Normal release ZIPs contain the plugin and platform archive. Fully loose ZIPs also contain the consumer's Interface tree and compiled scripts and are intended for inspection or controlled testing. The v2 packages do not include Canvas's host movies, Example content, the old XML runtime, or diagnostic fixtures. PS5DBG remains a separate legacy diagnostic variant.

## Source ownership and configuration

| Concern | Source |
| --- | --- |
| Registration, shared-provider inputs, lifecycle and snapshot publication | [VWHudConsumer.as](../Canvas/actionscript/VWHudConsumer.as) |
| Derived values and tactical meaning | [VWHudViewModel.as](../Canvas/actionscript/VWHudViewModel.as), [VWHudTacticalModel.as](../Canvas/actionscript/VWHudTacticalModel.as), [VWHudPresentation.as](../Canvas/actionscript/VWHudPresentation.as) |
| Validated status snapshots and paging | [VWHudEffectsAdapter.as](../Canvas/actionscript/VWHudEffectsAdapter.as) |
| Own registrar and effect publisher | [HudRegistrar.psc](../Papyrus/Venworks/CustomizableHUD/HudRegistrar.psc), [HudEffectsPublisher.psc](../Papyrus/Venworks/CustomizableHUD/HudEffectsPublisher.psc) |
| Theme identity and entry documents | [Canvas/variants](../Canvas/variants) |
| Shared HTML, CSS and SVG artwork | [Canvas/resources](../Canvas/resources) |
| Own plugin records and effect catalogs | [Spriggit](../Spriggit) |

The four full themes share `themed.html`; Minimalist uses `minimalist.html` and its reduced composition. Each variant selects its stylesheet and namespace. Edit the HTML fragments and CSS to change presentation. XML layout and palette settings described in the older configuration references apply to v1 only. Canvas implements a bounded HTML/CSS/SVG subset; it does not execute Vue or JavaScript.

Resources are packaged under `Interface/VenworksCanvas/Consumers/venworks.vwhud.<variant>/`. The SWF publishes data and handles lifecycle; Canvas owns display objects, host access and provider acquisition. The full themes retain 18 unique provider channels and Minimalist retains 14. Removing the old status renderer does not remove environmental or threat inputs used elsewhere.

Artwork uses standard `<svg>`, `<path>`, primitives and SVG attributes. Meter ranges, direction, segments, gaps and partial segments are explicit. Theme positions use Canvas's safe-area anchors and the existing 1920×1080 design coordinates. Native glyph access goes through Canvas's named symbol adapters rather than arbitrary Bethesda display paths.

## Effects display

Each plugin owns its records, labels, catalogs and publisher. Its topic is `venworks.vwhud.<variant>.status`, with `startup: "latest"`. Complete `effects.state` snapshots use schema `1`, `ci-ascii` and the 4,096-character framed-event limit. Whole messages are validated before replacing the previous state.

The compact display uses eight entries per page and a six-second page rotation, with waiting, empty and count states. The publisher carries the Example's application/removal tracking, sustenance precedence, save/load refresh, bounded retries, two-second recovery replay and scheduled 60-second refresh. Event submission is not an acknowledgement that the HUD received it. Example and VWHUD have separate namespaces and registrars while Canvas can share their provider subscriptions.

## Native HUD controls and frequent updates

The theme requests suppression of `player.meters` and `canvas.watch`. Canvas combines requests from all consumers: unloading one theme removes only its requests. Suppression never forces a game-hidden surface to become visible and does not disable game actions or event ingress. The custom watch's `disabled` flag also suspends its drawing and animation work. Vanilla scripts and timelines continue.

For example, a vehicle exit glyph is a named host-owned presentation adapter. VWHUD can display that glyph without moving the original button or taking ownership of its input callback. A placement request is a bounded offset on a semantic target; removing the consumer restores the current native position, not an obsolete startup position. Unknown targets or unsupported symbol access produce a contained diagnostic.

“Frequent updates” means inputs such as changing health, heading and contact positions during play. Under HTML/3, successive data snapshots before the next frame are coalesced. Unchanged panels retain their rendered objects; changed text and meter graphics update in place, and repeated subtrees reconcile when their structure changes. Invalid snapshots retain the last valid display. This is an implementation contract, not a measured frame-rate or latency claim; sustained gameplay measurements remain necessary.

## Build and verification

Use the existing v2 entry points in [BUILDSYSTEM.md](BUILDSYSTEM.md). `buildVariantV2.ps1 -Committed` routes the five consumer variants through `buildCanvasConsumers.ps1`; it accepts `CanvasProjectPath`, `FlexSdkPath` and `CanvasEnvironmentPath` in addition to the existing native-tool arguments. Build configuration is resolved locally and is not embedded in source. Use `-UpdateExpectedHashes` only for an intentional source and artifact refresh.

The consumer builder compiles the SWF and the two Papyrus scripts, assembles each plugin with Spriggit, and copies the reachable HTML/CSS/SVG resources. Publishing to committed staging first preserves the old payload under `.work/canvas-rollback/`. Artifact verification checks the exact payload inventory, source digest, resource bytes, required and forbidden SWF bytecode tokens, archive ownership and byte equality. Those checks do not execute the ActionScript renderer or prove gameplay behavior.

```powershell
./Tools/verifyVariantV2.ps1 -Committed -VariantKeys VWKS,TA,FC,CF,MIN -PreArchiveMutation
./Tools/createPackagesV2.ps1 -Committed -VariantKeys VWKS,TA,FC,CF,MIN
./Tools/verifyCommittedReleaseV2.ps1
./Tools/checkRepoV2.ps1 -Committed
./Tools/createReleasePackagesV2.ps1 -VariantKeys VWKS,TA,FC,CF,MIN -OutputDirectory .work/release-candidates
```

## Acceptance still required

VWHUD-32 (Venworks), VWHUD-33 (Trackers Alliance), VWHUD-34 (Freestar Collective), VWHUD-35 (Crimson Fleet) and VWHUD-36 (Minimalist) each require their own exact-package appearance and runtime evidence. Native compilation and package verification are separate from this acceptance. Do not mark the PS5 startup issue complete from a PC build.

For each theme, test archive-only PC and PS5 installation, normal and large HUDs, aiming/scanner transitions, health/oxygen, compass and radar responsiveness, status application/removal/recovery/paging, vehicle exit input and glyphs, ship visibility, menus, death/reload, save/load, 4K/8K and representative ultrawide placement. Run alongside Example to check namespace separation and shared-provider ownership. Measure object/timer stability and responsiveness during sustained activity. Exercise every Canvas catalog target independently and in groups, with multiple consumers, unload and failure restoration. Keep the prior accepted package until these checks are complete.
