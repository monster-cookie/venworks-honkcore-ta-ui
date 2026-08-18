# Goal 2 External XML Loading Report

> **Historical implementation evidence:** Current product intent, scope,
> delivery state, and acceptance are maintained in the Codecks `Documentation`
> and `Features` decks. The XML-loading contract and validation evidence below
> remain authoritative until deliberately superseded.

Date: 2026-08-06

## Outcome

Static and in-game validation passed.

Both player HUD variants now retain the Goal 1 bottom-center probe and add a
small loader to their `HUDMenu` document class. The loader requests the
relative path `VenworksCUI/probe.xml`, parses it with native ActionScript 3
`XML`, and renders its configured label. Loader, parser, and version failures
are caught and displayed without intentionally changing the vanilla HUD
lifecycle or provider subscriptions.

The probe proved that Starfield can load adjacent XML through the relative
`Interface/VenworksCUI` path. Goal 3 has superseded the provisional probe with
`layout.xml` and an error-only component runtime.

## Clean-room implementation

The implementation was derived from vanilla Starfield only. Static inspection
confirmed that vanilla `HUDMenu` already loads `SkillPatches.swf` with a
relative `URLRequest`, and that its ABC contains `URLLoader` support.

The repository contains only a Venworks-authored patch specification. During a
build, `Tools/compileScaleform.ps1`:

1. verifies the vanilla GFX hash;
2. adds the existing Goal 1 timeline probe;
3. exports ActionScript into ignored temporary storage;
4. verifies that every approved `HUDMenu` patch anchor occurs exactly once;
5. imports only the patched `HUDMenu` class;
6. reopens and validates the output before publishing it;
7. removes the temporary Bethesda XML and ActionScript.

No complete Bethesda ActionScript source or XML export is committed.

## Provisional probe document

Runtime path:

`Interface/VenworksCUI/probe.xml`

Valid document:

```xml
<?xml version="1.0" encoding="utf-8"?>
<venworksCUIProbe schemaVersion="1">
  <label>VENWORKS XML LOADED</label>
</venworksCUIProbe>
```

The root name, schema version, and exactly one nonempty `label` are required.

## Diagnostic behavior

| Condition | Bottom-center result | Color |
|---|---|---|
| Load pending | `CUI XML LOADING` | Yellow |
| Valid version 1 document | Configured `label` value | Yellow |
| Missing/unreadable file | `CUI XML MISSING` | Red |
| Invalid XML, root, or label | `CUI XML MALFORMED` | Red |
| Schema version other than 1 | `CUI XML UNSUPPORTED` | Red |
| Scaleform security rejection | `CUI XML SECURITY ERROR` | Red |
| Synchronous loader failure | `CUI XML LOAD ERROR` | Red |

All loader event listeners are removed after completion or failure. Repeated
HUD lifecycle callbacks do not create duplicate loaders.

## Goal 2 outputs

These are the historical artifacts used for Goal 2 validation. The staging
folder now contains the newer Goal 3 component-library artifacts.

| Artifact | Size | SHA-256 |
|---|---:|---|
| `Staging-CUI/Interface/hudmenu.gfx` | 264567 | `977404538C82BF82B6CD3D7E3B3590789E04C245161C8175457BD18F8C6788EF` |
| `Staging-CUI/Interface/hudmenu_lrg.gfx` | 264750 | `72D9749218B38D441C527051BF9D0D518EE330C00C485C91F8D06EBC5536993B` |
| `Staging-CUI/Interface/VenworksCUI/probe.xml` | 133 | runtime configuration input |

## Validation

- JPEXS 26.2.1 compiled and imported the patched class for both movies.
- Both generated files reopened and exported successfully.
- Both outputs retain the GFX signature and Goal 1 probe placement.
- Each movie has 167 exported classes before and after the import.
- `HUDMenu.as` is the only changed exported class in either movie; the other
  166 exported classes are textually identical.
- Both reopened `HUDMenu` classes contain the loader path, lifecycle call,
  field name, and all required diagnostic strings.
- Repeated clean builds reproduced the exact hashes above.
- Per-build temporary XML and ActionScript directories were removed
  automatically.

User-provided in-game screenshots confirmed all Goal 2 acceptance cases on the
normal player HUD:

| Case | Confirmed result |
|---|---|
| Valid XML | Configured `VENWORKS XML LOADED` label rendered. |
| Missing XML | Red `CUI XML MISSING` diagnostic rendered; HUD remained functional. |
| Malformed XML | Red `CUI XML MALFORMED` diagnostic rendered; HUD remained functional. |
| Unsupported schema | Red `CUI XML UNSUPPORTED` diagnostic rendered; HUD remained functional. |
| Restored valid XML | Configured success label rendered again. |

The deployed file was also confirmed at
`Data/Interface/VenworksCUI/probe.xml`, establishing the relative-path
resolution used by Goal 3.

## Acceptance rule

Accepted. XML is the runtime configuration foundation because the configured
value loaded through Starfield's file opener and the tested failures remained
diagnostic and nonfatal.
