# Build system

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
qualified names, compiles them into a SWC with Apache Flex `compc`, exports the
generated `DoABC2Tag` set through JPEXS, numbers the tags deterministically, and
replaces the checked-in seed. Apache Flex emits independent ABC tags for its
compiled library units; the normal build requires the complete numbered tag set
to survive the import and reopen cycle.
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
