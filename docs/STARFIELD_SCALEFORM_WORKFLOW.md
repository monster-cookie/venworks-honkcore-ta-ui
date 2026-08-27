# Starfield Scaleform Modification Workflow

This repository builds Starfield HUD replacements by modifying clean Bethesda movies while preserving the two movie containers Bethesda ships. It does not claim to reproduce Bethesda's internal authoring toolchain. It matches the observable delivery contract: native GFX files remain GFX, ZLIB-compressed SWF files remain CWS, and both forms are packaged at their own paths.

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

Each movie build manifest identifies its clean input, output filename, vanilla hash, expected generated hash, ABC seed patch, ActionScript tree, document-class patch, and optional variant source profile. GFX and SWF manifests for the same movie intentionally repeat the modification contract while pointing at different clean inputs and expected hashes.

Keep all cooperating `venworks.cui.*` classes in the single generated ABC domain. When the public class inventory changes, regenerate the seed with `Tools/generateScaleformAbcSeed.ps1`; do not add independent per-class ABC tags. Variant-specific behavior is selected through its build profile and exact ActionScript patches, not through copied variant definitions in build scripts.

## 5. Recompile GFX and CWS independently

Build all variants with:

```powershell
.\Tools\buildVariant.ps1 `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -VanillaInterfacePath "Scaleform/.work/vanilla-interface-extracted/interface"
```

Omitting `-VariantKeys` selects every entry in `$Global:ReleaseVariants`. During each compile, JPEXS imports the authored ABC into a temporary copy of the matching clean source, reopens the generated movie, and verifies patch anchors, class inventory, provider contracts, and the one-domain rule. The compiler then requires the output signature to match its source container and compares the result with the manifest's expected hash.

Use `-UpdateExpectedHashes` only for an intentional reviewed source change. A hash update is evidence that output changed, not proof that the movie works in Starfield. Review the source diff and validate in game before accepting it.

## 6. Stage the complete movie set

Each selected variant receives these eight generated movies:

```text
Interface/hudmenu.gfx
Interface/hudmenu.swf
Interface/hudmenu_lrg.gfx
Interface/hudmenu_lrg.swf
Interface/hudmessagesmenu.gfx
Interface/hudmessagesmenu.swf
Interface/hudmessagesmenu_lrg.gfx
Interface/hudmessagesmenu_lrg.swf
```

The normal and large HUD pairs may have profile-specific hashes. The HUD-message pairs are shared while their source profile remains common. Do not create an SWF by changing a GFX extension, changing only its signature, or compressing a generated GFX payload. That produces a different artifact than rebuilding from the clean Bethesda CWS source. The builder writes generated XML and SVG payloads as UTF-8 without a byte-order mark with canonical LF line endings. This keeps the loose staging bytes and BA2 entries deterministic across Windows and Linux checkouts.

## 7. Build platform archives and release packages

Create every selected Windows, Xbox, and PlayStation archive directly from the staged payload:

```powershell
.\Tools\createPackages.ps1
```

No platform receives a movie rewrite. Each Main BA2 must contain the same eight staged movie paths and byte-identical data. Texture archives remain governed by the variant's source inventory and platform filters.

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

- each staged `.gfx` has a GFX signature and each staged `.swf` has a CWS signature with a valid declared length;
- every staged movie matches its profile's expected SHA-256;
- JPEXS can reopen every generated movie and each HUD movie contains exactly one Venworks CUI ABC domain;
- every Main BA2 has the exact staged Interface inventory and every archive entry is byte-identical to its staged source;
- the four themed variants retain their shared hashes when a change is intended only for Minimalist; and
- all 25 release ZIPs have the expected platform/package shape.

Build success is not gameplay acceptance. Test a cold start, save load, normal and large HUD modes, scanner transitions, combat, menu teardown, and platform deployment. When isolating a console crash, change one contract at a time and record both positive and negative results.

## Container rules to preserve

- Never infer movie encoding from the extension alone; validate the signature.
- Never ship CWS bytes under a `.gfx` name or GFX bytes under a `.swf` name.
- Never synthesize one release format by renaming or wrapping the other.
- Always package the canonical generated XML/SVG bytes; do not rebuild archives from platform-converted text files.
- Never edit or commit Bethesda's full decompiled source.
- Never split cooperating Venworks classes across multiple ABC domains.
- Never treat JPEXS reopen, hash equality, PC acceptance, or archive creation as a substitute for testing the target console.
