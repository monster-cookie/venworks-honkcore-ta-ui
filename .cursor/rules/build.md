# Build

## Build and verification entry points

Use PowerShell 7 from the repository root with configured native inputs. Consumer compilation requires Java, Flex, a compatible Canvas checkout and environment, the Starfield Papyrus compiler, and Spriggit. Archive construction additionally requires Archive2.

| Entry point | Purpose |
| --- | --- |
| [Tools/buildVariant.ps1](../../Tools/buildVariant.ps1) | Build selected Canvas consumers using configured native tools and inputs. |
| [Tools/verifyVariant.ps1](../../Tools/verifyVariant.ps1) | Verify selected staged or committed variant artifacts; PreArchiveMutation checks inputs before archive creation. |
| [Tools/createPackages.ps1](../../Tools/createPackages.ps1) | Build selected PC, Xbox, and PS5 Main archives using Archive2. |
| [Tools/verifyCommittedRelease.ps1](../../Tools/verifyCommittedRelease.ps1) | Verify all committed release artifacts and repository contracts. |
| [Tools/createReleasePackages.ps1](../../Tools/createReleasePackages.ps1) | Assemble the five release package shapes for each selected theme. |
| [Tools/checkRepo.ps1](../../Tools/checkRepo.ps1) | Check five-theme release metadata and selected variant artifacts; Committed avoids live staging destinations. |
| [Tools/setupRepo.ps1](../../Tools/setupRepo.ps1) | Prepare staging destinations only when explicitly authorized. |

[Build documentation](../../docs/BUILDSYSTEM.md) describes the existing pipeline. Source checks, native compilation, archive construction, gameplay, and console acceptance are separate evidence. Never substitute a source-pattern check for execution of the production runtime.

When compiled output, consumer resources, expected hashes, or packages change, run PowerShell 7 from the repository root for `VWKS,TA,FC,CF,MIN`: `Tools/buildVariant.ps1` with `-UpdateExpectedHashes`, `Tools/verifyVariant.ps1 -PreArchiveMutation`, `Tools/createPackages.ps1 -Committed`, `Tools/verifyCommittedRelease.ps1`, `Tools/checkRepo.ps1 -Committed`, and `Tools/createReleasePackages.ps1`. The required inputs are Java, Flex, the Canvas checkout and its environment file, Papyrus, Spriggit, and Archive2. `Tools/setupRepo.ps1` runs only when staging setup is explicitly authorized. `-Committed` uses the tracked `Staging-*` directories. A private Flex compile is not this pipeline. Compilation and packaging are separate from a Starfield playtest.

```powershell
./Tools/buildVariant.ps1 `
  -VariantKeys VWKS,TA,FC,CF,MIN `
  -JavaPath <java.exe> `
  -FlexSdkPath <flex-sdk> `
  -CanvasProjectPath <venworks-canvas> `
  -CanvasEnvironmentPath <venworks-canvas/.env> `
  -UpdateExpectedHashes
```

```powershell
./Tools/verifyVariant.ps1 -VariantKeys VWKS,TA,FC,CF,MIN -PreArchiveMutation
./Tools/createPackages.ps1 -Committed -VariantKeys VWKS,TA,FC,CF,MIN
./Tools/verifyCommittedRelease.ps1
./Tools/checkRepo.ps1 -Committed
./Tools/createReleasePackages.ps1 -VariantKeys VWKS,TA,FC,CF,MIN -OutputDirectory .work/release-candidates
```

`-Committed` on packaging and verification selects the tracked `Staging-*` directories and bypasses local `.env` loading. Without it, packaging and installed-payload verification require the configured staging junctions and operate on their physical mod-manager destinations. Compilation always writes isolated inputs beneath `.work`; it does not place loose files in either destination.
