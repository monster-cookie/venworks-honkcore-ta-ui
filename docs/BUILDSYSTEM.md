# Build system

## Release artifact pipeline

The complete release build is a local Windows process followed by platform-neutral
ZIP assembly in GitHub Actions. `Archive2.exe` is not installed or downloaded by
the workflow. Before committing a release build, run these steps from the
repository root:

1. Run `Tools/buildVariant.ps1` with the validated Java, JPEXS, vanilla
   Interface inputs, and explicit variant keys. It compiles the common GFX once,
   then stages each selected variant's independent configuration profile.
2. Run `Tools/createPackages.ps1` with the same variant keys. The script reads
   `TOOL_PATH_ARCHIVER` from `.env`, validates each variant's root ESM, and runs
   only that variant's configured platform archive targets.
3. Run `Tools/verifyVariant.ps1` with the same variant keys, followed by
   `Tools/verifyCommittedRelease.ps1`. These checks validate the independent
   payload profiles, movie hashes, root stub ESMs, generated BA2 files, and the
   complete committed release inventory.
4. Review and commit the staged loose files, ESMs, and Git LFS-managed BA2 files
   together. A BA2 must be rebuilt whenever its staged source payload changes.
5. After the change reaches `master`, create the release tag. The Ubuntu release
   workflow uses `Tools/createReleasePackages.ps1` to assemble the committed
   artifacts; it never invokes Archive2.

For repository-local regeneration without Vortex Junctions, use the deliberate
`-Committed` mode on `buildVariant.ps1` and `createPackages.ps1`. Omitting
`-VariantKey` continues to select only the four themed release variants; include
`MIN` explicitly when regenerating the complete five-variant release:

```powershell
./Tools/buildVariant.ps1 `
  -VariantKey VWKS,CF,FC,TA,MIN `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -VanillaInterfacePath "Scaleform/.work/vanilla-interface-extracted/interface" `
  -Committed
./Tools/createPackages.ps1 -VariantKey VWKS,CF,FC,TA,MIN -Committed
./Tools/verifyCommittedRelease.ps1
```

Each variant uses one stable package base, such as
`Venworks-CustomizableHUD-FreestarCollective`. `Tools/createPackages.ps1`
creates these version-independent files from the matching staging root:

```text
<PackageBase>.esm
<PackageBase> - Main.ba2
<PackageBase> - Textures.ba2
<PackageBase> - Main_XBox.ba2
<PackageBase> - Textures_XBox.ba2
<PackageBase> - Main_PS.ba2
<PackageBase> - Textures_PS.ba2
```

The four themed profiles select all six archive targets shown above. Minimalist
selects only `Main_PS`, so its committed root contains only its ESM and PS5 Main
BA2. The Archive2 format, compression, maximum-size, include-filter, and
exclude-filter arguments in `Tools/createPackages.ps1` are part of the platform
packaging contract. Preserve them exactly. The Windows, Xbox, and PS5 Main and
Textures commands must all run even when a source category is currently empty.
Archive2 does not create a texture BA2 when its include filter matches no files,
so each platform package contains its Main BA2 plus a Textures BA2 only when the
texture command produces one.
SVG assets currently follow the Main-archive filters. Moving SVGs into a texture
archive is deferred until the generated console archives can be tested.

## Variant build profiles

`Tools/compileScaleform.ps1` is the lower-level common movie compiler. It
validates and writes one set of normal/large HUD and HUD-messages movies; it does
not select palettes, mirror configuration payloads, or invoke Archive2.
`Tools/buildVariant.ps1` consumes that common output and stages each selected
profile from `Scaleform/variants/<KEY>/build.psd1` independently. A profile owns
its layout source, component inventory, assets, palettes, palette mode, and
optional stub-ESM source. Adding or removing one component in one profile does
not require making the other profiles match.

The four themed profiles currently share the production layout, eight component
fragments, six SVG assets, and five external palettes. Minimalist independently
declares seven component fragments and its own layout, omitting only the faction
display while moving the contact radar into the former upper-left slot.

## PS5 Minimalist release

The `MIN` variant is a PS5-only release profile with no external SVG, palette,
or DDS payload. Configure its ignored module path in `.env` for Junction-based
local builds:

```text
MODULE_VARIANT_MIN_PATH=<absolute path to the Minimalist module folder>
```

Create only its staging Junction and build only its artifacts with:

```powershell
.\Tools\setupRepo.ps1 -VariantKey MIN
.\Tools\buildVariant.ps1 -VariantKey MIN `
  -JavaPath ".work/tools/java/bin/java.exe" `
  -JpexsJarPath ".work/tools/jpexs/ffdec.jar" `
  -VanillaInterfacePath "Scaleform/.work/vanilla-interface-extracted/interface"
.\Tools\createPackages.ps1 -VariantKey MIN
.\Tools\verifyVariant.ps1 -VariantKey MIN
.\Tools\createReleasePackages.ps1 `
  -VariantKey MIN `
  -OutputDirectory ".work/release-packages"
```

The common movie compiler validates the independent 10-provider condition
context and 14-provider value context before and after compilation, including
the six intentionally duplicated provider names, transactional startup,
callback containment, deferred teardown, and bootstrap diagnostics. It does
not combine providers into a shared subscription or broker. All five variants
therefore use the same hardened movie hashes. If a later PS5 investigation must
compile out SVG-capable ActionScript, add a distinct movie profile rather than
changing Minimalist's independent XML payload contract.

The Minimalist profile uses the common production HUD movies, resolves the
`starfield.xml` color roles to literal XML colors, removes the palette selector
and faction display, and moves the contact radar to the former faction-display
position. It then removes the `Assets` and `palettes` directories. The result
contains the renamed stub ESM, four GFX files, the reduced loose CUI
configuration, and only `<PackageBase> - Main_PS.ba2`.
The selected release-package command creates one Bethesda PS5 ZIP containing
only the root Minimalist ESM and its PS5 Main BA2. Omitting `-VariantKey` keeps
the normal four-theme selection unchanged; the release workflows explicitly
select all five variants.

The shared GFX still contains unused SVG-capable runtime code. A successful PS5
test therefore narrows the crash investigation to external SVG or palette/faction
loading; it does not independently prove which removed behavior caused the
crash. DDS substitution remains a separate follow-up experiment.

The release workflow produces five ZIP shapes for each of the four themes:

| Package | Contents |
|---|---|
| Nexus PC - Normal | Root ESM, Windows Main BA2, any generated Windows Textures BA2, and loose `Interface\VenworksCUI\layout.xml` |
| Nexus PC - Fully Loose Files | Complete loose `Interface` tree, with no ESM or BA2 |
| Bethesda PC | Root ESM, Windows Main BA2, and any generated Windows Textures BA2 only |
| Bethesda Xbox | Root ESM, Xbox Main BA2, and any generated Xbox Textures BA2 only |
| Bethesda PS5 | Root ESM, PS5 Main BA2, and any generated PS5 Textures BA2 only |

Minimalist adds one Bethesda PS5 ZIP containing only its ESM and PS5 Main BA2,
for 21 release ZIPs total. The normal Nexus package leaves only `layout.xml`
loose so the compiled HUD movies remain protected by the BA2. Users who need to
edit component fragments, palettes, or SVG assets must use the fully loose
package or provide a separate loose override. Do not install the normal and
fully loose packages together.

## Persistent BGS reference cache

`Tools/cacheBgsScaleform.ps1` maintains the curated vanilla reference set under
the Git-ignored `Scaleform/.work/bgs-decompiled` directory. The checked-in
`Scaleform/reference-cache.xml` manifest includes the normal/large on-foot HUD,
Watch map-icon library, player HUD components, frequently consulted status,
favorites, inventory, and galaxy-starmap consumers, the Ship HUD family, and
the available ship/powers provider JSON fixtures. It does not decompile the
complete Interface archive.

Each movie cache entry contains stable `movie.xml`, `scripts`, and `cache.json`
paths. Cache validity requires the same relative input name, source SHA-256,
JPEXS JAR SHA-256, parseable SWF XML, and an exported-script directory. Provider
fixtures are copied byte-identically and checked against their source hashes.
Changing either a movie or JPEXS invalidates only the affected movie entry;
`-ForceRefresh` deliberately regenerates the full manifest.

Run the cache from the repository root with the same external Java, JPEXS, and
extracted Interface paths used by the normal build:

```powershell
./Tools/cacheBgsScaleform.ps1 `
  -JavaPath "C:\path\to\java.exe" `
  -JpexsJarPath "C:\path\to\ffdec.jar" `
  -VanillaInterfacePath "C:\path\to\extracted\interface"
```

`Tools/compileScaleform.ps1` requires its normal and large HUD inputs in this
manifest and copies their cached vanilla XML into the build's GUID work
directory. It still exports the patched timeline and reopened generated movie
on every build because those exports enforce the patch-integrity, authored
class, script-count, and single-domain contracts. Those validation directories
remain temporary and are removed after a successful build unless `-KeepWork` is
selected.

Cache refreshes stage output below the resolved cache root and validate target
paths before removing a stale, regenerable entry. Neither the cache nor its
metadata records machine-specific absolute paths. Bethesda binaries,
decompiled ActionScript, XML, and provider fixtures must remain ignored local
references and must never be staged or committed.

## Palette contract validation

`Schemas/VenworksCUI/palette-v1.xsd` is the structural contract for palette
files. `Schemas/VenworksCUI/layout-v1.xsd` permits a root layout to select one
safe palette filename and permits the bounded `@palette.*` token form in
attributes whose literal types would otherwise reject a reference. Runtime
resolution remains the semantic gate for role existence, field/category
compatibility, required roles, and asset allowlists.

The normal build validates the positive palette contract and palette-layout
unsafe paths to fail structurally, and keeps unknown-role and incompatible-role
fixtures structurally valid for the runtime semantic gate. The runtime lowers
bounded composites, templates, repeaters, and states on a copy of the fully
imported layout, inserts the complete selected palette at the head of that
runtime tree, and resolves semantic values only when the parser, asset manager,
or components consume an attribute. No palette step rewrites or reparses the
layout XML. The palette-composite fixture covers
buttons, quick bars, information panels, warnings, palette-backed composite
icons, every button state, and every warning severity. The build also verifies
that the authored loader remains fixed to `VenworksCUI/palettes`, retains its
size and path bounds, and that the ordering and semantic composite output
survive the normal/large movie import and reopen cycle. The production layout
selects `venworks.xml` by default. The build validates and stages
`venworks.xml`, `crimson-fleet.xml`, `freestar-collective.xml`, and
`trackers-alliance.xml`, plus the neutral `starfield.xml`, under
`Interface/VenworksCUI/palettes` in all four release variants. Repository checks
enforce the exact four release-variant names, their corresponding selected
palette filenames, the Venworks default selector, and byte-identical source and
staged copies of all five user-selectable palette files.

## One-domain Scaleform rule

All cooperating Venworks CUI classes must live in exactly one injected
`DoABC2Tag` linkage domain. Do not split Venworks classes across multiple ABC
tags, even when JPEXS can reopen and decompile every class. Starfield's
Scaleform runtime cannot reliably resolve classes or resources across those
injected boundaries. Package names such as `venworks.cui.*` do not make
separate ABC units one runtime domain.

This is a mandatory architecture rule enforced by the build: the checked seed
and each reopened normal/large HUD movie must contain exactly one
`venworks.cui.components.seed.000` tag. Every dynamically discovered authored
CUI class must be present inside that one ABC. This rule has regressed more than
once; decompiled class presence, total script counts, padding records, and
matching deployment hashes are not substitutes for the one-domain assertion.

## Scaleform ActionScript seed

`Tools/compileScaleform.ps1` imports the authored CUI ActionScript into Bethesda's
HUD movies with JPEXS. JPEXS can replace classes represented by an AVM2 seed but
does not grow the seed reliably during `-importScript`. The repository therefore
stores a generated seed at
`Scaleform/shared/patches/cui-component-abc-seed.xml`.

The former build asserted exactly 38 authored CUI files and exactly 205 total
classes. Those numbers were repository implementation details, not Starfield,
Scaleform, or AVM2 limits. Goal 8 added `CUIContactRadar` as the thirty-ninth
authored class. Raising only the file-count assertion caused JPEXS to displace
`CUIProviderSymbol`, proving that source inventory and seed capacity are separate
concerns. The build now discovers the authored inventory dynamically, requires
every authored class after reopening each movie, and requires the complete class
inventory to remain stable across import.

Regenerate the seed whenever an authored `.as` class is added or removed:

```powershell
.\Tools\generateScaleformAbcSeed.ps1 `
  -FlexSdkPath "<apache-flex-sdk-path>" `
  -PlayerGlobalPath "<playerglobal.swc-path>" `
  -JavaPath "<java.exe-path>" `
  -JpexsJarPath "<ffdec.jar-path>"
```

The generator inventories public classes beneath
`Scaleform/shared/actionscript`, creates temporary empty stubs with the same
qualified names, and creates a synthetic root that references every discovered
class. Apache Flex `mxmlc` compiles that root and all stubs into one SWF ABC.
JPEXS exports that single `DoABC2Tag`, and the generator replaces the checked-in
seed only after confirming that every authored class is present in the same
ABC.
Temporary compiler inputs are created under the operating-system temporary
directory and removed in a `finally` block. Dependencies must remain outside the
repository and `Scaleform/.work`; do not commit SDKs, JARs, SWCs, or machine paths.

The Goal 8 regeneration used Apache Flex SDK 4.16.1. Its official Windows archive
was verified against Apache's published MD5 value
`8841C64BD5E32F8575EBA86E2574873A`. Apache no longer distributes older Adobe
Player API libraries; the generator used Adobe `playerglobal32_0.swc` with
SHA-256 `7D4D6168D27603CFB3B750302448E354E0BBC1BDD58F5D101C3DCF6891E9BB65`
as an external compile-time API. The generated seed contains names and empty AVM2
slots only; production implementations still come exclusively from the authored
repository sources during the normal build.

After regeneration, run the complete five-variant `Tools/buildVariant.ps1`
command, `Tools/createPackages.ps1`, and then
`Tools/verifyCommittedRelease.ps1`. A successful build
must import, reopen, and validate every authored class in both normal and large
HUD movies and regenerate all platform archives from those staged movies.

## Component registration contract

Components loaded from an included fragment pass through three independent
runtime gates: `CUICompositionResolver` must accept the XML element,
`CUILayoutParser` must validate its attributes, and `CUIRuntime` must construct
the display component. Registering a component in only the parser and runtime
is insufficient. The composition resolver processes included fragments first
and reports the element as unknown before layout parsing can reach its branch.

Goal 8B initially shipped `contactRadar` without adding it to the composition
resolver's leaf-component list. Both deployed HUD movies contained the new
parser and runtime code, but the included `contact-radar.xml` fragment failed at
composition. The build now requires `contactRadar` registration to survive the
movie import/reopen cycle in all three gates. Future included-fragment component
types must extend this validation contract at the same time they are added.

Starfield's Scaleform runtime can reduce `ReferenceError #1065` to its numeric
identifier without naming the unresolved variable or class. The runtime
therefore distinguishes layout validation, asset-manager initialization, and
asset collection, while the parser retains the component type and ID currently
being validated. Reopened-movie validation requires these checkpoint strings
and the optional stack-trace request to survive compilation.

## Goal 8 split-domain regression

Goal 8 runtime diagnostics localized `ReferenceError #1065` to the first call
to `CUISymbol.isAllowlisted`. The authored vehicle-exit symbol and `CUISymbol`
implementation were unchanged, but Goal 8 seed regeneration replaced Goal 7's
single lazy ABC with forty independent lazy ABC tags. A controlled terminal
sentinel moved `CUISymbol` away from the final record; the same error remained
with matching deployed hashes. That disproved terminal-record loss and
confirmed that padding cannot repair the violated one-domain architecture.

The production correction restores one generated ABC containing the entire
dynamic class inventory. Do not reintroduce `compc` library output, independent
per-class ABC tags, sentinel slots, or cross-domain resource assumptions.
