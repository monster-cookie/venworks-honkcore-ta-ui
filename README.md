# Venworks Customizable HUD

Venworks Customizable HUD provides five separately packaged Starfield HUD themes: Venworks, Trackers Alliance, Freestar Collective, Crimson Fleet, and Minimalist. Each theme is a Venworks Canvas HTML/CSS/SVG consumer and retains its own plugin identity, registration quest, effect catalog, status publisher, and release packages.

## Requirements

Install the current compatible versions in this order:

1. Venworks Core Library
2. Venworks Canvas
3. Exactly one VWHUD theme

Canvas owns the shared player and ship HUD hosts, provider acquisition, event transport, lifecycle, and bounded HTML/CSS/SVG renderer. VWHUD owns theme presentation, derived HUD state, effects publication, and its five real ESMs. The separately distributed Canvas Example is not required.

Do not install an earlier standalone VWHUD HUD replacement beside a Canvas consumer package. Loose files can shadow archive contents even when the old plugin is disabled.

## Theme consumers

The four full themes share the same composition and select different CSS and SVG artwork. Minimalist keeps its reduced composition and holographic visual treatment. Theme source lives under [CanvasConsumer](CanvasConsumer), which contains only VWHUD-owned consumer code and resources; Canvas framework source and host movies remain in the Canvas project.

Installed consumer assets use Canvas's current isolated loader contract:

```text
Interface/VenworksCanvas/Consumers/venworks.vwhud.<variant>/
```

That directory contains the theme's consumer SWFs, HTML, CSS, SVG, and local assets. Its name does not indicate that Canvas framework code is copied into VWHUD. Canvas fixes each consumer to one local resource root so relative resources resolve consistently and cannot escape into another consumer's files.

The plugin registration values omit the leading `Interface/` because Starfield resolves UI movie URLs relative to its Interface directory. The files stored in a BA2 or installed loose use the complete `Interface/VenworksCanvas/Consumers/...` path.

## Status effects

Each theme publishes complete `effects.state` snapshots on `venworks.vwhud.<variant>.status`. The compact effects display shows eight entries per page and rotates every six seconds. Snapshot validation, bounded retry, recovery replay, scheduled refresh, save/load revision handling, and pre-ready latest-state retention are owned by VWHUD; Canvas supplies the event transport.

## Packages

Each theme produces three Main BA2 archives and five release ZIP shapes:

- Nexus PC - Normal
- Nexus PC - Fully Loose Files
- Bethesda PC
- Bethesda Xbox
- Bethesda PS5

The repository therefore contains five real ESMs, fifteen platform archives, and a 25-ZIP release matrix. It does not contain the unreleased XML runtime, a generic plugin stub, or the retired PS5 diagnostic variant.

Use [the build system](docs/BUILDSYSTEM.md) for commands and artifact contracts. [Canvas consumer architecture and acceptance](docs/CANVAS_MIGRATION.md) records ownership, status behavior, and remaining runtime evidence. [Visual references](docs/reference/) preserve clean-room presentation evidence, and [the changelog](CHANGELOG.md) preserves project history.

## Validation status

Source inspection, compilation, committed-payload verification, BA2 verification, and ZIP verification are separate from Starfield runtime acceptance. Archive-only PC and PS5 gameplay acceptance remains required for each theme, including normal and large HUD modes, status recovery, vehicle glyphs, ship visibility, menus, save/load, high resolutions, and representative ultrawide layouts.

## License

See [LICENSE](LICENSE).
