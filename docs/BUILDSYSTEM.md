# Build system

The repository builds five VWHUD Canvas consumers: `VWKS`, `TA`, `FC`, `CF`, and `MIN`. [Tools/sharedConfig.ps1](../Tools/sharedConfig.ps1) is the release-variant authority. Each variant owns one real ESM assembled from [Spriggit](../Spriggit), two identical consumer movie aliases, reachable HTML/CSS/SVG resources, and the two VWHUD Papyrus scripts.

## Toolchain

The consumer build requires:

- Java and an Apache Flex SDK with the Flash Player 11.1 library;
- a compatible Venworks Canvas checkout, used for the Registry Papyrus source dependency;
- the Starfield Papyrus compiler, flags, source path, and game data path;
- Spriggit CLI for ESM assembly; and
- Archive2 for platform BA2 construction.

Machine-specific paths remain in ignored environment configuration. `buildCanvasConsumers.ps1` reads only the Papyrus, Spriggit, and Starfield data settings it needs from the selected Canvas environment file.

## Source and runtime ownership

[CanvasConsumer](../CanvasConsumer) contains VWHUD-owned ActionScript, HTML, CSS, SVG, per-theme entry documents, expected build evidence, and the lifecycle diagnostic. It does not contain Canvas host, registry, renderer, or Example implementation files.

Canvas's current loader contract fixes a consumer namespace to `Interface/VenworksCanvas/Consumers/<namespace>/`. Registration properties use the same path without `Interface/`; BA2 and loose-file inventories include it. For VWHUD the namespaces are `venworks.vwhud.vwks`, `venworks.vwhud.ta`, `venworks.vwhud.fc`, `venworks.vwhud.cf`, and `venworks.vwhud.min`.

## Entry points

| Command | Purpose |
| --- | --- |
| `Tools/buildVariant.ps1` | Compile selected consumers and Papyrus scripts, assemble their ESMs, and publish validated payloads. |
| `Tools/verifyVariant.ps1` | Verify exact source evidence, staged files, SWF contracts, resources, and optionally BA2 contents. |
| `Tools/createPackages.ps1` | Create the PC, Xbox, and PS5 uncompressed General BA2 archives after pre-archive verification. |
| `Tools/createReleasePackages.ps1` | Create five release ZIP shapes per selected theme. |
| `Tools/verifyCommittedRelease.ps1` | Validate scripts, repository contracts, resources, all five payloads, and all fifteen archives. |
| `Tools/checkRepo.ps1` | Validate the five-theme configuration and selected payloads. |
| `Tools/setupRepo.ps1` | Create local staging junctions for configured mod-manager destinations. |

`-Committed` selects the tracked `Staging-*` directories and bypasses local `.env` loading. Without it, build and packaging commands require the configured staging junctions and operate on their physical mod-manager destinations.

## Build consumers

```powershell
./Tools/buildVariant.ps1 `
  -Committed `
  -VariantKeys VWKS,TA,FC,CF,MIN `
  -JavaPath <java.exe> `
  -FlexSdkPath <flex-sdk> `
  -CanvasProjectPath <venworks-canvas> `
  -CanvasEnvironmentPath <venworks-canvas/.env> `
  -UpdateExpectedHashes
```

`-UpdateExpectedHashes` is required only when intentionally accepting newly built bytes or a changed source digest. The build uses a fresh directory beneath `.work/canvas-consumers`, validates the complete candidate, preserves the previous destination beneath `.work/canvas-rollback`, and then publishes the complete replacement.

## Verify and package

```powershell
./Tools/verifyVariant.ps1 -Committed -VariantKeys VWKS,TA,FC,CF,MIN -PreArchiveMutation
./Tools/createPackages.ps1 -Committed -VariantKeys VWKS,TA,FC,CF,MIN
./Tools/verifyCommittedRelease.ps1
./Tools/checkRepo.ps1 -Committed
./Tools/createReleasePackages.ps1 -VariantKeys VWKS,TA,FC,CF,MIN -OutputDirectory .work/release-candidates
```

The committed release contains three BA2 files per theme: `Main`, `Main_XBox`, and `Main_PS`. All are uncompressed General archives and contain the consumer Interface tree plus the two compiled VWHUD scripts. The real ESM remains beside the archive. The full matrix contains 15 BA2 files and 25 ZIP files.

## Evidence boundaries

The verifiers establish exact file inventory, resource bytes, source digest, SWF encoding and bytecode tokens, platform archive ownership, archive entry bytes, and ZIP composition. Compilation proves that the selected source and toolchain can produce the candidate. Neither proves that Starfield mounted the consumer, delivered provider data, displayed the intended theme, or behaved correctly on PC or PS5.
