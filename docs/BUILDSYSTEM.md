# Build system

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
gallery, requires unsupported versions, duplicate roles, invalid values, and
unsafe paths to fail structurally, and keeps unknown-role and incompatible-role
fixtures structurally valid for the runtime semantic gate. It also verifies that
the authored loader remains fixed to `VenworksCUI/palettes`, retains its size
and path bounds, and that the resolver and runtime integration survive the
normal/large movie import and reopen cycle. The production layout remains
literal-only until a separately approved theme migration selects and stages a
palette.

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

After regeneration, run `Tools/checkRepo.ps1` followed by the complete
`Tools/compileScaleform.ps1` command. A successful build must import, reopen, and
validate every authored class in both normal and large HUD movies.

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
