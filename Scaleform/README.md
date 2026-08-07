# Scaleform Sources

This directory contains only Venworks-authored Scaleform patch definitions,
build manifests, hashes, and validation records. It intentionally does not
contain Bethesda GFX/SWF files, full JPEXS XML exports, decompiled Bethesda
ActionScript, or extracted game assets.

The developer scripts in `../Tools` operate on files extracted from a locally
installed copy of Starfield. Temporary XML is written to `Scaleform/.work`,
which is ignored by Git.

## Requirements

- Eclipse Temurin Java 21 (or a compatible Java 21 runtime)
- JPEXS Free Flash Decompiler 26.2.1
- Clean `hudmenu.gfx` and `hudmenu_lrg.gfx` files extracted from
  `Starfield - Interface.ba2`

## Build

From the repository root:

```powershell
./Tools/compileScaleform.ps1 `
  -JavaPath "C:\path\to\java.exe" `
  -JpexsJarPath "C:\path\to\ffdec.jar" `
  -VanillaInterfacePath "C:\path\to\extracted\interface"
```

By default, validated outputs are copied to `Staging-CUI/Interface`. Use
`-OutputDirectory` to select a different destination. The script refuses to
build from unrecognized vanilla inputs or publish outputs whose hashes differ
from the validation records.

`decompileScaleform.ps1` is a lower-level helper for producing a temporary
JPEXS XML file during patch development. Its output must not be committed.
