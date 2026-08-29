# Build system

## PowerShell static analysis

GitHub Actions runs PSScriptAnalyzer 1.25.0 against the PowerShell sources under `Tools/`. Install the same pinned module version and run the analyzer from the repository root to reproduce the check locally:

```powershell
$ErrorActionPreference = 'Stop'

Install-Module -Name PSScriptAnalyzer -RequiredVersion 1.25.0 -Repository PSGallery -Scope CurrentUser -Force
Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Force
$findings = @(
  Invoke-ScriptAnalyzer `
    -Path ./Tools `
    -Recurse `
    -Settings ./PSScriptAnalyzerSettings.psd1
)
if ($findings.Count -ne 0) {
  $findings | Format-Table RuleName, Severity, ScriptName, Line, Message -Wrap
  throw "PSScriptAnalyzer reported $($findings.Count) finding(s)."
}
```

A clean analysis produces no findings. CI reports each finding's rule, severity, script, line, and message, then fails when the configured Error or Warning severities are present. `PSScriptAnalyzerSettings.psd1` documents the repository-specific reasons for each intentional baseline exclusion.

## Release artifact pipeline

The complete release build is a local Windows process followed by platform-neutral ZIP assembly in GitHub Actions. `Archive2.exe` is not installed or downloaded by the workflow. Before committing a release build, run these steps from the repository root:

1. Run `Tools/buildVariant.ps1` with the validated Java, JPEXS, and vanilla Interface inputs. It compiles each selected movie profile once, then stages every release variant's independent configuration profile unless a subset is selected.
2. Run `Tools/createPackages.ps1` with the same optional variant selection. The script reads `TOOL_PATH_ARCHIVER` from `.env`, validates each variant's root ESM, and runs only that variant's configured platform archive targets.
3. Run `Tools/verifyVariant.ps1` with the same optional variant selection, followed by `Tools/verifyCommittedRelease.ps1`. These checks validate the independent payload profiles, movie hashes, root stub ESMs, generated BA2 files, and the complete committed release inventory.
4. Review and commit the staged loose files, ESMs, and Git LFS-managed BA2 files together. A BA2 must be rebuilt whenever its staged source payload changes.
5. After the change reaches `master`, create the release tag. The Ubuntu release workflow uses `Tools/createReleasePackages.ps1` to assemble the committed artifacts; it never invokes Archive2.

For repository-local regeneration without Vortex Junctions, use the deliberate `-Committed` mode on `buildVariant.ps1` and `createPackages.ps1`. Omitting `-VariantKeys` processes all five entries in `$Global:ReleaseVariants`. Pass a single key, such as `-VariantKeys MIN`, or an array, such as `-VariantKeys @("TA", "MIN")`, to process a subset. `-VariantKey` remains a compatibility alias for the plural parameter:

```powershell
./Tools/buildVariant.ps1 `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -VanillaInterfacePath "Scaleform/.work/vanilla-interface-extracted/interface" `
  -Committed
./Tools/createPackages.ps1 -Committed
./Tools/verifyCommittedRelease.ps1
```

Each variant uses one stable package base, such as `Venworks-CustomizableHUD-FreestarCollective`. `Tools/createPackages.ps1` creates these version-independent files from the matching staging root:

```text
<PackageBase>.esm
<PackageBase> - Main.ba2
<PackageBase> - Textures.ba2
<PackageBase> - Main_XBox.ba2
<PackageBase> - Textures_XBox.ba2
<PackageBase> - Main_PS.ba2
<PackageBase> - Textures_PS.ba2
```

The four themed profiles select all six archive targets shown above. Minimalist selects the three Main targets and produces no Textures archives, so its committed root contains its ESM and Windows, Xbox, and PS5 Main BA2s. The Archive2 format, compression, maximum-size, include-filter, and exclude-filter arguments in `Tools/createPackages.ps1` are part of the platform packaging contract. Preserve them exactly. Every archive target selected by a variant must run even when a source category is currently empty. Archive2 does not create a texture BA2 when its include filter matches no files, so each platform package contains its Main BA2 plus a Textures BA2 only when the texture command produces one.

The archive compression matrix follows Bethesda's shipped BA2s: every General Main target uses `None`, while every DDS or XBoxDDS Textures target uses `LZ4`. CWS movie compression remains internal to each SWF and is not changed by the outer BA2 setting. SVG assets currently follow the Main-archive filters. Moving SVGs into a texture archive is deferred until the generated console archives can be tested.

## Variant build profiles

`Tools/compileScaleform.ps1` is the lower-level HUD bootstrap compiler. It validates and writes one normal or large HUD movie declared by a build manifest while preserving that build input's GFX or CWS container and patching only Bethesda's existing ABC. `Tools/compileScaleformAuxiliary.ps1` compiles the complete CUI runtime into a deterministic one-ABC CWS movie. `Tools/sharedScaleformProfiles.ps1` resolves the shared bootstrap build outputs, the explicit nine-path deployment mapping, and each variant's auxiliary source profile. `Tools/buildVariant.ps1` compiles the shared bootstrap and HUD-message movies once, compiles each selected auxiliary profile once, and stages each selected profile from `Scaleform/variants/<KEY>/build.psd1` independently. Normal and large GFX outputs deploy to their `.gfx` paths while independently compiled CWS outputs deploy to their `.swf` paths. A variant profile owns its auxiliary movie profile, layout source, component inventory, assets, palettes, palette mode, and optional stub-ESM source. Adding or removing one component or auxiliary behavior in one profile does not require making the other profiles match.

The four themed profiles currently share the production layout, eight component fragments, six SVG assets, five external palettes, and the shared live-data auxiliary movie profile. Minimalist independently declares six component fragments, its own layout, and the `minimalist-live` auxiliary profile. The four base HUD bootstrap movies and four HUD-message movies are shared across all five variants. Every variant stages those eight Bethesda-path movies plus one profile-selected `venworkscui.swf` and loads external XML through the same complete layout runtime; Minimalist differs only in its reduced provider inventory and visual source patches.

## Minimalist release

The `MIN` variant is a work-in-progress PC, Xbox, and PS5 release profile with  no external SVG, palette, or DDS payload. Configure its ignored module path in `.env` for Junction-based local builds:

```text
MODULE_VARIANT_MIN_PATH=<absolute path to the Minimalist module folder>
```

Create only its staging Junction and build only its artifacts with:

```powershell
.\Tools\setupRepo.ps1 -VariantKeys MIN
.\Tools\buildVariant.ps1 -VariantKeys MIN `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -VanillaInterfacePath "Scaleform/.work/vanilla-interface-extracted/interface"
.\Tools\createPackages.ps1 -VariantKeys MIN
.\Tools\verifyVariant.ps1 -VariantKeys MIN
.\Tools\createReleasePackages.ps1 `
  -VariantKeys MIN `
  -OutputDirectory ".work/release-packages"
```

The shared themed movie profile validates the independent 10-provider condition context and 14-provider value context before and after compilation, including the six intentionally duplicated provider names, transactional startup, callback containment, deferred teardown, and bootstrap diagnostics. Both contexts start immediately when the auxiliary runtime initializes, before external XML, palettes, or assets load. Each guarded subscription primes its provider through `BSUIDataManager.GetDataFromClient()` before attaching the callback so a newly watched provider's synchronous first snapshot is replayed instead of being lost across the asynchronous movie boundary. The Minimalist live profile retains the same guarded lifecycle with exactly seven condition registrations, ten value registrations, and three intentionally duplicated provider names. It removes only `WeaponData`, `HUDStarbornPowersData`, `FavoritesData`, and `ControlMapData`, which serve the equipment rail that Minimalist does not ship.

The Minimalist profile compiles the complete shared ActionScript tree into its standalone one-ABC CUI movie. It does not replace either data context. Its patch removes only the rail-specific subscription statements and applies the Minimalist-specific visual changes. The compiler verifies the exact provider inventory and the full layout, palette, asset, SVG, path, mask, panel, icon, provider-symbol, and composite class inventory after JPEXS reopens the auxiliary movie. The four themed variants share one auxiliary hash; Minimalist's `venworkscui.swf` hash is profile-specific. All five variants use the same thin normal and large bootstrap movie hashes.

Minimalist resolves the `starfield.xml` color roles to literal XML colors, removes the palette selector, faction display, helmet cutout paths, and complete equipment rail, and keeps the contact radar in the former faction-display position. Its six fragments use fitted native rectangle and ellipse backings with a 28-percent dark base and 10-percent pale-blue tint beneath the existing corner brackets and divider strokes. The shipped XML contains no `svg`, `path`, `mask`, `icon`, `panel`, or `providerSymbol` nodes, and the build removes the `Assets` and `palettes` directories. It stages the literal-color `layout.xml` and all six component fragments under `Interface\VenworksCUI`, alongside the nine-movie Interface payload, the renamed stub ESM, and the Windows, Xbox, and PS5 Main BA2s. The selected release-package command creates all five normal package shapes for Minimalist. Omitting `-VariantKeys` selects all five release variants.

The provider-free v2.0.6 test produced no change in the reported PS5 crash, so Minimalist again retains its required live providers and provider-driven CUI events. Every Bethesda-path movie is built and deployed independently from the matching clean container: native `.gfx` inputs produce validated native GFX outputs, and ZLIB-compressed `.swf` inputs produce validated CWS outputs. The v2.0.10 byte-identical host alias experiment also produced no change in the reported PS5 crash, so the native Bethesda-style container split is restored. The separately authored auxiliary runtime is emitted as compressed CWS version 12. Native rectangle and ellipse fills remain in the fitted holographic backings.

The release workflow produces five ZIP shapes for each of the five variants:

| Package | Contents |
|---|---|
| Nexus PC - Normal | Root ESM, Windows Main BA2, any generated Windows Textures BA2, plus loose `Interface\VenworksCUI\layout.xml` only for an external-configuration profile |
| Nexus PC - Fully Loose Files | Complete loose `Interface` tree, with no ESM or BA2 |
| Bethesda PC | Root ESM, Windows Main BA2, and any generated Windows Textures BA2 only |
| Bethesda Xbox | Root ESM, Xbox Main BA2, and any generated Xbox Textures BA2 only |
| Bethesda PS5 | Root ESM, PS5 Main BA2, and any generated PS5 Textures BA2 only |

Every platform Main archive packages the staged nine-movie inventory directly: native GFX plus independently compiled CWS for the normal, large, and HUD-message movie pairs, and the profile-selected `venworkscui.swf`. Windows, Xbox, and PlayStation use the same source inventory and Bethesda-style storage contract: General Main BA2s are uncompressed and DDS or XBoxDDS Textures BA2s use LZ4. Minimalist's platform packages contain its ESM and matching Main BA2 with no texture archive, while its fully loose Nexus package contains the nine movies plus the reduced external XML tree. Generated XML and SVG payloads use UTF-8 without a byte-order mark and canonical LF line endings so committed BA2 contents remain byte-identical to clean checkouts on Windows and Linux. The complete release matrix contains 25 ZIPs. Every normal Nexus package leaves only `layout.xml` loose so the compiled HUD movies remain protected by the BA2. Users who need to edit component fragments, palettes, or SVG assets must use a fully loose package or provide a separate loose override. The official v2.0.10 release enables the global and every variant-specific Nexus upload switch, making both Nexus package shapes eligible for all five variants while PS5 compatibility remains an independent end-user acceptance gate. Do not install a normal and fully loose package together.

## Persistent BGS reference cache

`Tools/cacheBgsScaleform.ps1` maintains the curated vanilla reference set under the Git-ignored `Scaleform/.work/bgs-decompiled` directory. The checked-in `Scaleform/reference-cache.xml` manifest includes the normal/large on-foot HUD, Watch map-icon library, player HUD components, frequently consulted status, favorites, inventory, and galaxy-starmap consumers, the Ship HUD family, and the available ship/powers provider JSON fixtures. It does not decompile the complete Interface archive.

Each movie cache entry contains stable `movie.xml`, `scripts`, and `cache.json` paths. Cache validity requires the same relative input name, source SHA-256, JPEXS JAR SHA-256, parseable SWF XML, and an exported-script directory. Provider fixtures are copied byte-identically and checked against their source hashes. Changing either a movie or JPEXS invalidates only the affected movie entry; `-ForceRefresh` deliberately regenerates the full manifest.

Run the cache from the repository root with the same external Java, JPEXS, and extracted Interface paths used by the normal build:

```powershell
./Tools/cacheBgsScaleform.ps1 `
  -JavaPath "C:\path\to\java.exe" `
  -JpexsJarPath "C:\path\to\ffdec.jar" `
  -VanillaInterfacePath "C:\path\to\extracted\interface"
```

`Tools/compileScaleform.ps1` requires its normal and large HUD inputs in this manifest and copies their cached vanilla XML into the build's GUID work directory. It still exports the patched timeline and reopened generated movie on every build because those exports enforce the patch-integrity, authored class, script-count, and single-domain contracts. Those validation directories remain temporary and are removed after a successful build unless `-KeepWork` is selected.

Cache refreshes stage output below the resolved cache root and validate target paths before removing a stale, regenerable entry. Neither the cache nor its metadata records machine-specific absolute paths. Bethesda binaries, decompiled ActionScript, XML, and provider fixtures must remain ignored local references and must never be staged or committed.

## Palette contract validation

`Schemas/VenworksCUI/palette-v1.xsd` is the structural contract for palette files. `Schemas/VenworksCUI/layout-v1.xsd` permits a root layout to select one safe palette filename and permits the bounded `@palette.*` token form in attributes whose literal types would otherwise reject a reference. Runtime resolution remains the semantic gate for role existence, field/category compatibility, required roles, and asset allowlists.

The normal build validates the positive palette contract and palette-layout unsafe paths to fail structurally, and keeps unknown-role and incompatible-role fixtures structurally valid for the runtime semantic gate. The runtime lowers bounded composites, templates, repeaters, and states on a copy of the fully imported layout, inserts the complete selected palette at the head of that runtime tree, and resolves semantic values only when the parser, asset manager, or components consume an attribute. No palette step rewrites or reparses the layout XML. The palette-composite fixture covers buttons, quick bars, information panels, warnings, palette-backed composite icons, every button state, and every warning severity. The build also verifies that the authored loader remains fixed to `VenworksCUI/palettes`, retains its size and path bounds, and that the ordering and semantic composite output survive the normal/large movie import and reopen cycle. The production layout selects `venworks.xml` by default. The build validates and stages `venworks.xml`, `crimson-fleet.xml`, `freestar-collective.xml`, and `trackers-alliance.xml`, plus the neutral `starfield.xml`, under `Interface/VenworksCUI/palettes` in all four themed release variants. Minimalist uses literal Starfield colors and stages no palette directory. Repository checks enforce the exact five release-variant names, their corresponding selected palette filenames, the Venworks default selector, and byte-identical source and staged copies of all five user-selectable palette files.

## Auxiliary movie domain boundary

All cooperating Venworks CUI classes live in exactly one `DoABC` linkage domain inside `Interface\venworkscui.swf`. The normal and large Bethesda HUD movies retain exactly one Bethesda ABC apiece and contain only the guarded loader patch; they must not contain an injected CUI seed or any `venworks.cui.*` implementation. The loader uses the default child application domain, allowing the auxiliary runtime to resolve Bethesda definitions from its parent without explicitly selecting an `ApplicationDomain` or using `LoaderContext`. The normal and large hosts are compiled and validated from Bethesda's separate GFX and CWS inputs, but the current deployment contract deliberately uses the CWS host bytes for both runtime aliases. All four deployed host paths plus the auxiliary retain the observed 1920-by-1080, 30-fps, one-frame stage contract; `_lrg` is not authored as an ultrawide stage.

The bootstrap retains one loader and one untyped bridge per HUD instance. The HUD constructor starts the request, `Event.INIT` resolves and initializes the child bridge against the host HUD, and `Event.COMPLETE` attaches the loaded auxiliary root directly to the HUD before reapplying placement and replaying any cached HUD-mode visibility. The runtime keeps the host owner used for lifecycle events and vanilla lookups separate from the auxiliary display owner used for custom layers. The bootstrap guards duplicate startup, contains initialization, complete, I/O, security, placement, visibility, and teardown failures, tolerates removal while loading, removes both lifecycle listeners, and disposes, detaches, and unloads idempotently. Its marker and load-error fields apply Starfield's embedded `$MAIN_Font_Bold` format rather than relying on an unavailable default font. The auxiliary root exposes only `initialize(owner)`, `reapplyVanillaPlacements()`, `updateVanillaHudModeVisibility(values)`, and `dispose()` to that bridge.

This boundary is a mandatory build contract. Verification requires one ABC in each base HUD movie, no CUI runtime tokens in those base movies, one ABC in the auxiliary movie, the complete expected CUI/provider inventory in that auxiliary ABC, readable diagnostic formatting, current transformed-source and class-inventory fingerprints, and no release marker payload.

Provider startup and live callback faults are terminal for the current auxiliary runtime instance. The runtime marks itself failed before scheduling deferred component teardown, cancels the layout, palette, and asset loaders, removes their listeners, and ignores any callback that arrives after cancellation. A synchronous provider failure also stops the remaining provider context and XML-loading stages instead of allowing partially initialized UI to continue.

## Standalone CUI compiler

`Tools/compileScaleformAuxiliary.ps1` uses Apache Flex `compc.jar` to create a temporary external-library SWC from six compile-only Bethesda stubs under `Scaleform/venworkscui/externs` plus a generated `scaleform.gfx.Extensions` stub. It then uses `mxmlc.jar` to compile `VenworksCUIEntrypoint` and the selected profiled CUI source tree. The host SWC is external-only: none of its stub definitions may be embedded in the output.

The compiler emits compressed CWS version 12 with manifest-validated 1920-by-1080 stage dimensions, a 30-fps frame rate, and one frame, removes nondeterministic Flex metadata and product tags through a JPEXS XML normalization pass, reopens the result, and requires exactly one ABC with the expected bridge, runtime classes, provider names, and profile restrictions. Production compilation uses two passes: the first derives the sorted compiled-definition fingerprint, while the second embeds that fingerprint and the current transformed-source fingerprint in the entrypoint and proves the definition inventory did not change. Each auxiliary manifest owns both an expected movie hash and an expected class-inventory hash. The four themed variants use `Scaleform/venworkscui/build.xml` and share those contracts. Minimalist uses `Scaleform/variants/MIN/movies/venworkscui.build.xml` and its own contracts.

All SDKs, JARs, SWCs, decompiled data, and temporary compiler inputs remain ignored under `.work` or an ephemeral build directory. Do not commit `playerglobal.swc`, the generated host extern SWC, Bethesda binaries, or machine-specific paths.

`buildVariant.ps1 -AuxiliaryMarkerProbe` is a local-only loader check. It is accepted only with `-VariantKeys MIN`, cannot be combined with `-Committed` or `-UpdateExpectedHashes`, and emits a temporary one-ABC auxiliary movie containing `VENWORKS AUX LOADED`. Never package or commit the probe. A normal build overwrites it, release verification rejects the marker string, and `createPackages.ps1` rejects any inventory, hash, signature, or host-alias mismatch before any archive mutation.

After any bootstrap, entrypoint, CUI class, provider profile, or extern change, run the complete five-variant `Tools/buildVariant.ps1` command, `Tools/createPackages.ps1`, and `Tools/verifyCommittedRelease.ps1`. A successful build must reopen and validate all generated movies and regenerate every platform Main archive from the exact nine-movie staging inventory. Before release, force one missing-auxiliary load to confirm the diagnostic is readable, then test at least Minimalist and one themed variant from an archive-only PC install containing only the selected ESM and Main BA2 with no loose Interface shadow. Rollback for this probe restores the independently compiled native GFX host files at the two `.gfx` paths and rebuilds the previous nine-movie Main archives; the standalone auxiliary architecture and `.swf` files remain unchanged.

## Component registration contract

Components loaded from an included fragment pass through three independent runtime gates: `CUICompositionResolver` must accept the XML element, `CUILayoutParser` must validate its attributes, and `CUIRuntime` must construct the display component. Registering a component in only the parser and runtime is insufficient. The composition resolver processes included fragments first and reports the element as unknown before layout parsing can reach its branch.

Goal 8B initially shipped `contactRadar` without adding it to the composition resolver's leaf-component list. Both deployed HUD movies contained the new parser and runtime code, but the included `contact-radar.xml` fragment failed at composition. The build now requires `contactRadar` registration to survive the movie import/reopen cycle in all three gates. Future included-fragment component types must extend this validation contract at the same time they are added.

Starfield's Scaleform runtime can reduce `ReferenceError #1065` to its numeric identifier without naming the unresolved variable or class. The runtime therefore distinguishes layout validation, asset-manager initialization, and asset collection, while the parser retains the component type and ID currently being validated. Reopened-movie validation requires these checkpoint strings and the optional stack-trace request to survive compilation.

## Goal 8 split-domain regression

Goal 8 runtime diagnostics localized `ReferenceError #1065` to the first call to `CUISymbol.isAllowlisted`. The authored vehicle-exit symbol and `CUISymbol` implementation were unchanged, but Goal 8 seed regeneration replaced Goal 7's single lazy ABC with forty independent lazy ABC tags. A controlled terminal sentinel moved `CUISymbol` away from the final record; the same error remained with matching deployed hashes. That disproved terminal-record loss and confirmed that padding cannot repair the violated one-domain architecture.

The first production correction restored one generated ABC containing the entire dynamic class inventory inside each base HUD movie. The current architecture preserves that one-domain rule while moving the single CUI ABC into `venworkscui.swf`. `compc` is now used only to produce a temporary external host-library SWC; do not embed that SWC, emit independent per-class ABC tags, add sentinel slots, or split cooperating CUI classes across domains.
