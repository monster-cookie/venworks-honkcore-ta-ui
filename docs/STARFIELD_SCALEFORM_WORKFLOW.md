# Starfield Scaleform Modification Workflow

This repository builds Starfield HUD replacements by modifying clean Bethesda movies while validating both movie containers Bethesda ships. It does not claim to reproduce Bethesda's internal authoring toolchain. The build preserves native GFX and ZLIB-compressed CWS outputs as independent validated intermediates. The v2.0.10 PS5 compatibility probe then applies an explicit TACOS-style runtime mapping: normal and large HUD CWS bytes are deployed under both `.gfx` and `.swf` names, while HUD-message paths retain their native GFX/CWS split.

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

Omitting `-VariantKeys` selects every entry in `$Global:ReleaseVariants`. The base compiler patches Bethesda's existing HUD ABC without adding another `DoABC` tag, reopens every native GFX and CWS build output, and verifies the constructor/INIT/COMPLETE loader anchors, direct-child attachment, cached visibility replay, idempotent teardown, readable Starfield diagnostic format, and one-ABC contract. The auxiliary compiler creates a temporary external host SWC with `compc`, compiles the profiled CUI source with `mxmlc`, normalizes the CWS output through JPEXS, and reopens it twice: the first production pass derives the sorted class-inventory fingerprint, while the second embeds that fingerprint plus the current transformed-source fingerprint and proves the definition inventory is unchanged. It also validates CWS version 12, the 1920-by-1080 stage, 30 fps, and one frame. Each compiler compares the result with its manifest's expected hashes. The separate deployment mapping is applied only after these build contracts pass.

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

The four base HUD paths and four HUD-message movies are shared while their bootstrap patches remain common. The standalone CUI movie is shared by the four themed variants and profile-specific for Minimalist. `hudmenu.gfx` and `hudmenu.swf` are exact copies of the independently compiled `hudmenu.swf` CWS output; the large pair follows the same rule. The native host GFX outputs are never converted or signature-wrapped and remain build-only validation evidence. HUD-message `.gfx` files continue to use the native GFX output, and HUD-message `.swf` files continue to use the independently compiled CWS output. The builder writes generated XML and SVG payloads as UTF-8 without a byte-order mark with canonical LF line endings. This keeps the loose staging bytes and BA2 entries deterministic across Windows and Linux checkouts.

## 7. Build platform archives and release packages

Create every selected Windows, Xbox, and PlayStation archive directly from the staged payload:

```powershell
.\Tools\createPackages.ps1
```

No platform receives a movie rewrite. Each Main BA2 must contain the same nine staged movie paths and byte-identical data. Texture archives remain governed by the variant's source inventory and platform filters.

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

- each staged normal/large HUD `.gfx` alias and `.swf` has a CWS signature with a valid declared length, and each alias pair is byte-identical;
- each staged HUD-message `.gfx` retains a GFX signature while each matching `.swf` retains a CWS signature;
- the normal, large, and auxiliary HUD movies retain the observed 1920-by-1080, 30-fps, one-frame metadata, including the non-ultrawide `_lrg` host;
- every staged movie matches its profile's expected SHA-256;
- JPEXS can reopen every generated movie, each base HUD movie contains exactly one Bethesda ABC and no CUI runtime, and each standalone CUI movie contains exactly one complete CUI ABC;
- every auxiliary movie embeds fingerprints recomputed from the current manifest, compiler contract, externs, entrypoint, and transformed ActionScript, and its sorted definition inventory matches the profile's expected class hash;
- every Main BA2 has the exact staged Interface inventory and every archive entry is byte-identical to its staged source;
- the four themed variants retain their shared auxiliary hash while Minimalist retains its profile-specific auxiliary hash; and
- all 25 release ZIPs have the expected platform/package shape.

Build success is not gameplay acceptance. First omit `Interface/venworkscui.swf` deliberately and confirm the bootstrap's Starfield-font load diagnostic is readable. Then install a Bethesda PC package with only its ESM and Main BA2, disable every loose `Interface` override for that variant, and verify that both the auxiliary movie and external configuration resolve from the archive. Test Minimalist and at least one themed variant through cold start, save load, normal and large HUD modes, scanner transitions, combat, menu teardown, and platform deployment. When isolating a console crash, change one contract at a time and record both positive and negative results.

## Container rules to preserve

- Never infer movie encoding from the extension alone; validate the declared deployment signature.
- Deploy CWS bytes under a `.gfx` name only for the explicit normal/large HUD aliases declared by `Tools/sharedScaleformProfiles.ps1`; HUD-message aliases retain the native container split.
- Never synthesize CWS by changing a GFX signature or compressing a generated GFX payload. The host aliases must be byte-for-byte copies of the independently compiled Bethesda CWS-source outputs.
- Always package the canonical generated XML/SVG bytes; do not rebuild archives from platform-converted text files.
- Never edit or commit Bethesda's full decompiled source.
- Never embed the Venworks runtime in a base HUD movie or split cooperating Venworks classes across multiple auxiliary ABC domains.
- Never embed compile-only Bethesda extern definitions in `venworkscui.swf`.
- Never package a marker, stale movie, incomplete inventory, wrong container, or mismatched host alias; `createPackages.ps1` must verify the complete selected deployment mapping before Archive2 mutates an archive.
- Never treat JPEXS reopen, hash equality, PC acceptance, or archive creation as a substitute for testing the target console.
