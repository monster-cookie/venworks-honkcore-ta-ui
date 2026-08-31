# Starfield Scaleform Modification Workflow

This repository builds Starfield HUD replacements by modifying clean Bethesda movies while validating both movie containers Bethesda ships. It does not claim to reproduce Bethesda's internal authoring toolchain. The build preserves and deploys native GFX and ZLIB-compressed CWS outputs independently, matching Bethesda's extension and container split.

## Required local tools and inputs

- A legally installed copy of Starfield.
- Archive2 for extracting and rebuilding BA2 archives.
- Java 21 and JPEXS Free Flash Decompiler 26.2.1.
- A clean extraction of `Starfield - Interface.ba2` containing both `.gfx` and `.swf` forms of `hudmenu`, `hudmenu_lrg`, `hudmessagesmenu`, and `hudmessagesmenu_lrg`.

Keep Bethesda binaries, decompiled XML, exported ActionScript, provider fixtures, SDKs, JARs, and machine-specific paths outside tracked source. The repository stores only Venworks-authored source, bounded patch definitions, manifests, hashes, validation metadata, and generated release artifacts.

## 1. Prepare and verify the environment

From the repository root:

```powershell
.\Tools\Setup-ScaleformEnvironment.ps1
.\Tools\Verify-ScaleformEnvironment.ps1
```

The setup uses ignored `.work` paths. Supply explicit tool paths to later build commands when automatic discovery is unavailable.

## 2. Extract clean Bethesda movies

Use Archive2 to extract the Interface archive without changing filenames or contents. The build expects these eight source files below the selected `interface` directory:

```text
hudmenu.gfx
hudmenu.swf
hudmenu_lrg.gfx
hudmenu_lrg.swf
hudmessagesmenu.gfx
hudmessagesmenu.swf
hudmessagesmenu_lrg.gfx
hudmessagesmenu_lrg.swf
```

Treat `.gfx` and `.swf` as independent source movies. A filename extension is not sufficient evidence of the container. The repository validates the first three bytes and requires `GFX` for `.gfx` inputs and `CWS` for `.swf` inputs. The CWS declared uncompressed length is also validated.

Record a new clean input only after confirming its game version and SHA-256. The `vanilla.sha256` and `vanilla-swf.sha256` files protect each manifest from silently building against the wrong Starfield revision.

## 3. Decompile for investigation

Create a one-off ignored JPEXS XML export with:

```powershell
.\Tools\decompileScaleform.ps1 `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -InputPath "Scaleform/.work/vanilla-interface-extracted/interface/hudmenu.gfx" `
  -OutputPath "Scaleform/.work/hudmenu.xml"
```

Use the export to locate stable patch anchors and understand the vanilla timeline. Do not commit the exported XML or Bethesda ActionScript. Authored behavior belongs under `Scaleform/shared/actionscript`; bounded changes to Bethesda document classes belong in repository patch definitions.

For repeated investigation, populate the curated ignored reference cache:

```powershell
.\Tools\cacheBgsScaleform.ps1 `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -VanillaInterfacePath "Scaleform/.work/vanilla-interface-extracted/interface"
```

`Scaleform/reference-cache.xml` is the source-of-truth inventory for that cache.

## 4. Author a bounded modification

Each base HUD build manifest identifies its clean input, output filename, vanilla hash, expected generated hash, and bounded document-class bootstrap patch. GFX and SWF manifests for the same movie intentionally repeat that modification contract while pointing at different clean inputs and expected hashes. An auxiliary manifest separately identifies the standalone CUI entrypoint, shared ActionScript tree, compile-only host externs, optional variant source profile, 1920-by-1080 stage, 30-fps frame rate, expected compiled class-inventory hash, and expected `venworkscui.swf` hash.

Keep all cooperating `venworks.cui.*` classes in the single ABC domain compiled into `venworkscui.swf`. The base HUD movies retain their one Bethesda ABC and load the child movie through an untyped bridge. Start that loader from the HUD constructor, initialize the bridge at `Event.INIT`, attach the auxiliary root directly to the host at `Event.COMPLETE`, and keep the host lifecycle owner separate from the auxiliary display owner. Variant-specific behavior is selected through its auxiliary build profile and exact ActionScript patches, not through copied variant definitions in build scripts.

## 5. Recompile GFX and CWS independently

Build all variants with:

```powershell
.\Tools\buildVariant.ps1 `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -VanillaInterfacePath "Scaleform/.work/vanilla-interface-extracted/interface"
```

Omitting `-VariantKeys` selects every entry in `$Global:ReleaseVariants`. The base compiler patches Bethesda's existing HUD ABC without adding another `DoABC` tag, reopens every native GFX and CWS build output, and verifies the constructor/INIT/COMPLETE loader anchors, direct-child attachment, cached visibility replay, idempotent teardown, readable Starfield diagnostic format, and one-ABC contract. The auxiliary compiler creates a temporary external host SWC with `compc` when required, compiles the selected auxiliary source with `mxmlc`, normalizes the CWS output through JPEXS, and reopens it twice: the first pass derives the sorted class-inventory fingerprint, while the second embeds that fingerprint, additionally embeds the transformed-source fingerprint for runtime bridges, and proves the definition inventory is unchanged. It also validates CWS version 12, the 1920-by-1080 stage, 30 fps, and one frame. Each compiler compares the result with its manifest's expected hashes. The separate deployment mapping is applied only after these build contracts pass.

Use `-UpdateExpectedHashes` only for an intentional reviewed source change. A hash update is evidence that output changed, not proof that the movie works in Starfield. Review the source diff and validate in game before accepting it.

## 6. Stage the complete movie set

Each selected variant receives these nine generated movies:

```text
Interface/hudmenu.gfx
Interface/hudmenu.swf
Interface/hudmenu_lrg.gfx
Interface/hudmenu_lrg.swf
Interface/hudmessagesmenu.gfx
Interface/hudmessagesmenu.swf
Interface/hudmessagesmenu_lrg.gfx
Interface/hudmessagesmenu_lrg.swf
Interface/venworkscui.swf
```

The four base HUD paths and four HUD-message movies are shared while their bootstrap patches remain common. The standalone CUI movie is shared by the four themed variants and profile-specific for Minimalist. Each `.gfx` path receives the independently compiled native GFX output and each `.swf` path receives the independently compiled CWS output from its matching clean Bethesda source. The builder writes generated XML and SVG payloads as UTF-8 without a byte-order mark with canonical LF line endings. This keeps the loose staging bytes and BA2 entries deterministic across Windows and Linux checkouts.

### Build an isolated auxiliary-loader diagnostic

Use the PS5 Debug build profile when the purpose is to advance the console isolation test one boundary at a time: the v2.0.14 provider-free one-class child is now reported loading successfully on PS5, so this successor tests one dynamically resolved `PlayerData` subscription before any production Venworks runtime or configuration is introduced:

```powershell
.\Tools\buildVariant.ps1 `
  -VariantKeys PS5DBG `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -VanillaInterfacePath "Scaleform/.work/vanilla-interface-extracted/interface" `
  -Committed
.\Tools\createPackages.ps1 -VariantKeys PS5DBG -Committed
.\Tools\verifyVariant.ps1 -VariantKeys PS5DBG -Committed
```

The `-Committed` build, package, and verification path operates directly on the tracked staging directory and does not require a junction. For Vortex deployment, first confirm that the selected tracked staging directory contains no work that must be preserved, delete that directory, run `.\Tools\setupRepo.ps1 -VariantKeys PS5DBG` to create the correctly targeted local module junction, and restore the deleted tracked files from the current commit through Git so the payload is written through the junction into the module folder. `setupRepo.ps1` never deletes or replaces tracked staging data. Once the junction is populated, omit `-Committed` from the remaining commands. This manual delete, junction, and restore workflow applies to every variant.

The PS5 Debug manifests select the same lower-level compiler and existing shared loader used by the player-facing host movies. Ordered patches add the lifecycle pane, shared loader, and a small observer that reports the loader's existing phases; they modify only the existing `HUDMenu` class in Bethesda's existing ABC and do not add another `DoABC` tag or custom host document class. The output contains the four normal/large Bethesda HUD movie paths, one diagnostic `venworkscui.swf`, and the uniquely named PS5 Debug plugin. The child movie contains only `VenworksCUIDiagnosticEntrypoint`, its embedded class-inventory fingerprint, its four untyped bridge methods, and a Starfield-font pane. The pane first identifies `venworkscui.swf loaded`, then the next frame resolves `Shared.AS3.Data.BSUIDataManager` by name, primes and subscribes only `PlayerData`, and displays sanitized, bounded `sName` text or a contained error. Do not add HUD-message movies, XML, SVG, palettes, assets, production provider contexts, other providers, the production CUI runtime, Xbox archives, or Nexus package shapes to this diagnostic. The generic archive builder retains a Windows Main BA2 for the PC gate and a PS5 Main BA2 for Creations; the release-package matrix exposes only the Bethesda PS5 ZIP.

Interpret the top-center pane by the last visible phase: `PS5DBG-01 CONSTRUCTED` proves the document-class constructor ran, `PS5DBG-02 ADDED TO STAGE` proves the HUD instance joined the display list, `PS5DBG-03 AUX LOAD STARTED` proves the shared loader issued its request, `PS5DBG-04 AUX INITIALIZED` proves the child bridge initialized, and `PS5DBG-OK AUX COMPLETE` proves the child root completed and attached. The end-user report that v2.0.14 loads successfully on PS5 establishes the provider-free child baseline. In the successor, `PS5DBG-05 PLAYERDATA NEXT FRAME` preserves that child-ready boundary, `PS5DBG-06 PLAYERDATA REQUEST` identifies provider resolution/registration, `PS5DBG-07 PLAYERDATA WAITING` proves registration returned, `PS5DBG-OK PLAYERDATA | <name>` proves a callback supplied `sName`, and `PS5DBG-ERR PLAYERDATA` contains a caught resolution, registration, or callback fault. Top-pane `PS5DBG-ERR` still records a contained host or loader failure and its phase. Once auxiliary completion is recorded, the top pane suppresses older non-error host lifecycle updates; an error may still replace completion. Once an error is recorded, the top pane suppresses every later non-error update so it cannot report false success. Absence of either pane does not prove the movie was absent; it means the failure occurred before the relevant diagnostic could render and must be correlated with deployment hashes and the unique ESM/BA2 inventory.

## 7. Build platform archives and release packages

Create every selected Windows, Xbox, and PlayStation archive directly from the staged payload:

```powershell
.\Tools\createPackages.ps1
```

No platform receives a movie rewrite. Each Main BA2 must contain the same nine staged movie paths and byte-identical data. Texture archives remain governed by the variant's source inventory and platform filters. General Main archives use Archive2 `compression=None`, while DDS and XBoxDDS Textures archives use `compression=LZ4`; CWS movie compression remains internal to each SWF.

Create the five release ZIP shapes per variant with:

```powershell
.\Tools\createReleasePackages.ps1 `
  -OutputDirectory ".work/release-packages"
```

This produces Nexus normal, Nexus fully loose, Bethesda PC, Bethesda Xbox, and Bethesda PlayStation packages for each release variant.

## 8. Validate before release

Run the complete repository contract:

```powershell
.\Tools\verifyVariant.ps1
.\Tools\verifyCommittedRelease.ps1
.\Tools\checkRepo.ps1 -Committed
actionlint .github/workflows/ci.yml .github/workflows/package-release.yml
git diff --check
```

Validation must confirm:

- each staged normal/large HUD `.gfx` has a native GFX signature while each matching `.swf` has a CWS signature with a valid declared length;
- each staged HUD-message `.gfx` retains a GFX signature while each matching `.swf` retains a CWS signature;
- the normal, large, and auxiliary HUD movies retain the observed 1920-by-1080, 30-fps, one-frame metadata, including the non-ultrawide `_lrg` host;
- every staged movie matches its profile's expected SHA-256;
- JPEXS can reopen every generated movie, each base HUD movie contains exactly one Bethesda ABC and no CUI runtime, and each standalone CUI movie contains exactly one complete CUI ABC;
- every runtime-bridge auxiliary embeds fingerprints recomputed from the current manifest, compiler contract, externs, entrypoint, and transformed ActionScript, while every diagnostic bridge embeds a fingerprint bound to its exact staged one-class inventory and expected class hash;
- every Main BA2 has the exact staged Interface inventory, stores every entry without BA2 compression, and remains byte-identical to its staged source;
- the four themed variants retain their shared auxiliary hash while Minimalist retains its profile-specific auxiliary hash; and
- all 26 release ZIPs have the expected platform/package shape: five shapes for each player-facing variant and one Bethesda PS5 shape for PS5 Debug.

Build success is not gameplay acceptance. First omit `Interface/venworkscui.swf` deliberately and confirm the bootstrap's Starfield-font load diagnostic is readable. Then install a Bethesda PC package with only its ESM and Main BA2, disable every loose `Interface` override for that variant, and verify that both the auxiliary movie and external configuration resolve from the archive. Test Minimalist and at least one themed variant through cold start, save load, normal and large HUD modes, scanner transitions, combat, menu teardown, and platform deployment. When isolating a console crash, change one contract at a time and record both positive and negative results. In particular, retain the v2.0.14 provider-free console result as the prerequisite baseline and do not treat a deterministic provider-probe build as permission to publish the next PS5 package.

## Container rules to preserve

- Never infer movie encoding from the extension alone; validate the declared deployment signature.
- Preserve Bethesda's native container split: deploy independently compiled GFX output only to `.gfx` paths and independently compiled CWS output only to `.swf` paths.
- Never synthesize one container by changing another container's signature or by copying bytes under a different extension.
- Always package the canonical generated XML/SVG bytes; do not rebuild archives from platform-converted text files.
- Never edit or commit Bethesda's full decompiled source.
- Never embed the Venworks runtime in a base HUD movie or split cooperating Venworks classes across multiple auxiliary ABC domains.
- Never embed compile-only Bethesda extern definitions in `venworkscui.swf`.
- Never package a marker, stale movie, incomplete inventory, or wrong container; `createPackages.ps1` must verify the complete selected deployment mapping before Archive2 mutates an archive.
- Never treat JPEXS reopen, hash equality, PC acceptance, or archive creation as a substitute for testing the target console.
