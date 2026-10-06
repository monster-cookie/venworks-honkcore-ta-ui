# Build system

The repository builds five VWHUD Canvas consumers: `VWKS`, `TA`, `FC`, `CF`, and `MIN`. [Tools/sharedConfig.ps1](../Tools/sharedConfig.ps1) is the release-variant authority. Each variant owns one real ESM assembled from [Spriggit](../Spriggit), two identical consumer movie aliases, reachable HTML/CSS/SVG resources, and the three VWHUD Papyrus scripts.

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
| `Tools/buildVariant.ps1` | Compile selected consumers and Papyrus scripts, assemble their ESMs, and write validated package inputs beneath `.work/canvas-payloads`. |
| `Tools/verifyVariant.ps1` | Verify isolated pre-archive inputs or archive-only installed and committed payloads. |
| `Tools/createPackages.ps1` | Transactionally create and install the PC, Xbox, and PS5 Main and Textures BA2 archives, then remove exact archive-shadowing loose files. |
| `Tools/createReleasePackages.ps1` | Create five release ZIP shapes per selected theme, extracting the Fully Loose payload from the verified Windows Main and Textures archives. |
| `Tools/verifyCommittedRelease.ps1` | Validate scripts, repository contracts, resources, all five archive-only payloads, and all thirty archives. |
| `Tools/checkRepo.ps1` | Validate the five-theme configuration and selected payloads. |
| `Tools/setupRepo.ps1` | Create local staging junctions for configured mod-manager destinations. |

`-Committed` on packaging and verification selects the tracked `Staging-*` directories and bypasses local `.env` loading. Without it, packaging and installed-payload verification require the configured staging junctions and operate on their physical mod-manager destinations. Compilation always writes isolated inputs beneath `.work`; it does not place loose files in either destination.

## Build consumers

```powershell
./Tools/buildVariant.ps1 `
  -VariantKeys VWKS,TA,FC,CF,MIN `
  -JavaPath <java.exe> `
  -FlexSdkPath <flex-sdk> `
  -CanvasProjectPath <venworks-canvas> `
  -CanvasEnvironmentPath <venworks-canvas/.env> `
  -UpdateExpectedHashes
```

`-UpdateExpectedHashes` is required only when intentionally accepting newly built bytes or a changed source digest. Before compilation, the build verifies that the selected Canvas checkout exposes `VWCANVAS_CONSUMER/3`, `VWCANVAS_HTML/2`, `Registry.BuildCanvasDatagramBody`, and `Registry.TryPublishCanvasDatagram`. The build then uses a fresh directory beneath `.work/canvas-consumers`, validates the complete candidate, records accepted evidence, and publishes the selected complete package inputs beneath `.work/canvas-payloads`. It does not mutate installed or committed staging.

## Verify and package

```powershell
./Tools/verifyVariant.ps1 -VariantKeys VWKS,TA,FC,CF,MIN -PreArchiveMutation
./Tools/createPackages.ps1 -Committed -VariantKeys VWKS,TA,FC,CF,MIN
./Tools/verifyCommittedRelease.ps1
./Tools/checkRepo.ps1 -Committed
./Tools/createReleasePackages.ps1 -VariantKeys VWKS,TA,FC,CF,MIN -OutputDirectory .work/release-candidates
```

`createPackages.ps1` creates and verifies every archive candidate before installation. It backs up existing managed artifacts and exact loose payload targets, installs the verified ESM and archives, removes only the loose files represented in the archives, and verifies that none remain. A failed transaction restores the prior managed and loose files and retains recovery material beneath `.work/package-transactions`; another package run stops until that retained transaction is inspected and removed. A successful transaction removes its isolated inputs and transaction directory.

The committed release contains six BA2 files per theme: uncompressed General `Main`, `Main_XBox`, and `Main_PS`, plus `Textures`, `Textures_XBox`, and `Textures_PS`. The smoke plate is stored twice. The General archives keep `Interface/VenworksCanvas/Consumers/<namespace>/panel-smoke.dds` as the original DDS file, which is the copy the HUD reads. The texture archives keep `Textures/Interface/VenworksCanvas/Consumers/<namespace>/panel-smoke.dds`. The other consumer Interface files and the compiled VWHUD scripts stay in the General archives. The real ESM remains beside the archives, and no matching Interface or Script payload remains loose in `Staging-*`. `createReleasePackages.ps1` reads the verified Windows Main entries and the source DDS bytes checked against the Windows Textures archive when producing the Nexus Fully Loose Files ZIP, so release assembly does not require loose staging files. The full matrix contains 30 BA2 files and 25 ZIP files.

## Evidence boundaries

The verifiers establish exact file inventory, resource bytes, source digest, SWF encoding and bytecode tokens, platform archive ownership, archive entry bytes, and ZIP composition. Compilation proves that the selected source and toolchain can produce the candidate. Neither proves that Starfield mounted the consumer, delivered provider data, displayed the intended theme, or behaved correctly on PC or PS5.
