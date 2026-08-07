# Scaleform Sources

This directory contains only Venworks-authored ActionScript, a minimal owned
ABC seed, patch definitions, XML fixtures, build manifests, hashes, and
validation records. It intentionally does not contain Bethesda GFX/SWF files,
full JPEXS XML exports, decompiled Bethesda ActionScript, or extracted game
assets.

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

The build injects the Venworks-only ABC seed, exports Bethesda ActionScript only
into ignored temporary storage, verifies the authored `HUDMenu` patch anchors,
and imports the patched document class plus the 13 repository-authored CUI
classes. It confirms that every other exported class remains textually
identical and that the reopened output contains the required layout and
diagnostic contracts. Full exported Bethesda classes are never repository
source.

Dynamic CUI text retains Starfield's exported `PromptMessageWidget` symbol and
styles its timeline-created `textField` child. The build verifies that this
vanilla field remains linked to the locale-specific `$MAIN_Font_Bold` outline
font. The repository does not copy or bundle the vanilla symbol or font files.

`decompileScaleform.ps1` is a lower-level helper for producing a temporary
JPEXS XML file during patch development. Its output must not be committed.

Files under `shared/fixtures` are developer test inputs. The Goal 3 component
gallery is the staged `layout.xml`; malformed fixtures are intentionally not
well-formed XML. See `../docs/GOAL_3_COMPONENT_LIBRARY.md` and
`../docs/COMPONENT_CATALOG.md`.
