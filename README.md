# Venworks Customizable HUD

Venworks Customizable HUD provides five separately packaged Starfield HUD themes rendered through Venworks Canvas: Venworks, Trackers Alliance, Freestar Collective, Crimson Fleet, and Minimalist. The four full themes share the same tactical composition with different colors and artwork. Minimalist uses a reduced holographic composition without the faction crest or equipment rail.

## Requirements and installation

Install and enable these packages in order:

1. Venworks Core Utilities 2.1.8 or newer.
2. Venworks Canvas 1.0.4 or newer.
3. Exactly one VWHUD theme.

The optional Canvas Example and Component Gallery are not required to play with VWHUD. Remove an earlier standalone VWHUD installation before installing a Canvas-based release. Also remove loose files left by an older Canvas installation before reinstalling Canvas; loose Interface and Script files override current archives even when their associated plugin is disabled.

When changing themes, remove the current VWHUD theme before installing the replacement and confirm that only one VWHUD ESM remains enabled.

## Features

- Compass heading, threat state, and compact status effects with eight entries per page.
- Player health, oxygen, CO2, boost, carry mass, currency, time, and progression information.
- Equipment, weapon, ammunition, explosive, and power information in the four full themes.
- Environment panels for location, time, gravity, suit protection, and active hazards.
- Tracked objective, acquired-contact radar, and forward scanner presentation.
- Bethesda's current vehicle-exit glyph supplied through Canvas.

## Choose a package

Each theme has five release package shapes:

- **Nexus PC - Normal:** the theme ESM and Windows Main BA2. Use this for ordinary play or with a separate CSS override mod.
- **Nexus PC - Fully Loose Files:** the same plugin with loose Scripts and Interface resources for complete PC customization. Do not install it beside the Normal package.
- **Bethesda PC, Xbox, and PS5:** platform-specific ESM and Main BA2 packages with the shipped theme presentation.

Installed Normal and Bethesda packages are archive-only. VWHUD's build process removes its generated loose payload after installing a verified BA2 so those files cannot shadow later Interface changes.

## Customize a theme on PC

Every theme loads `vwhud-overrides.css` after its base layout and palette. The Normal VWHUD package contains an empty copy inside its BA2 and installs no loose VWHUD files. If you want CSS customization, create a separate, later-loading mod that supplies only `vwhud-overrides.css` at the selected consumer path. This intentionally adds one loose user-owned override file without unpacking or shadowing VWHUD's HTML, SWF, scripts, or other resources. Users who do not create an override remain fully archive-only. Use the Fully Loose Files package for changes to HTML composition or SVG artwork.

[Customizing VWHUD themes](docs/CUSTOMIZING_THEMES.md) lists every namespace, stable panel class, editable file, example override, update procedure, and reset procedure. Canvas's Component Gallery remains the authority for supported HTML, CSS, SVG, and Canvas component syntax.

## Canvas and VWHUD ownership

Canvas owns the shared player and ship HUD hosts, provider acquisition, event transport, lifecycle, and bounded HTML/CSS/SVG renderer. VWHUD owns its theme presentation, derived HUD state, status-effect publication, plugins, and packages. The local [CanvasConsumer](CanvasConsumer) directory contains VWHUD consumer code and resources; it does not contain a copy of the Canvas framework or host movies.

Canvas loads each add-on from an isolated directory beneath:

```text
Interface/VenworksCanvas/Consumers/<consumer-namespace>/
```

VWHUD uses `venworks.vwhud.vwks`, `venworks.vwhud.ta`, `venworks.vwhud.fc`, `venworks.vwhud.cf`, and `venworks.vwhud.min`. The directory name describes Canvas's loader contract rather than ownership of the contained files.

## Troubleshooting

- Confirm that Core loads before Canvas and Canvas loads before the selected VWHUD theme.
- Confirm that only one VWHUD theme is installed and enabled.
- Remove old standalone VWHUD files and avoid combining the Normal and Fully Loose package shapes.
- If the Canvas display reports `UNSUPPORTED CONSUMER PROTOCOL`, or the Papyrus log reports that `Venworks:Canvas:Registry.BuildCanvasDatagramBody` is missing, the Canvas code loaded by that game process does not expose the contract VWHUD expects. Fully exit Starfield, verify the deployed Canvas and VWHUD package versions, check for duplicate archives or loose files providing the same paths, redeploy Venworks Canvas 1.0.4 or newer, and restart the game. These messages identify a loaded-contract mismatch; by themselves they do not prove which package or deployment path supplied the conflicting file.
- Disable a custom override mod and restart Starfield to determine whether the base theme loads normally.
- Report the Canvas version, VWHUD theme and version, package source, platform, normal or large HUD mode, and whether the issue remains without overrides.

## Maintainer documentation

[The build system](docs/BUILDSYSTEM.md) documents compilation, archive-only staging, packaging, and verification. [Canvas consumer architecture and acceptance](docs/CANVAS_MIGRATION.md) records ownership, status behavior, and remaining runtime evidence. [Visual references](docs/reference/) preserve clean-room presentation evidence, and [the changelog](CHANGELOG.md) preserves project history.

## Validation status

Source inspection, compilation, archive verification, ZIP verification, and Starfield runtime acceptance are separate evidence. Archive-only PC and PS5 gameplay acceptance remains required for each theme, including normal and large HUD modes, status recovery, vehicle glyphs, ship visibility, menus, save/load, high resolutions, and representative ultrawide layouts.

## License

See [LICENSE](LICENSE).
