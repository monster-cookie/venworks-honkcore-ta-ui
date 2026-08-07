# Goal 2 External XML Loading Report

Date: 2026-08-06

## Outcome

Static implementation and validation passed. In-game validation is pending.

Both player HUD variants now retain the Goal 1 bottom-center probe and add a
small loader to their `HUDMenu` document class. The loader requests the
relative path `VenworksCUI/probe.xml`, parses it with native ActionScript 3
`XML`, and renders its configured label. Loader, parser, and version failures
are caught and displayed without intentionally changing the vanilla HUD
lifecycle or provider subscriptions.

The probe format and path are provisional. They prove or reject external XML
loading only; they do not define the Goal 3 layout and palette schemas.

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

## Outputs

| Artifact | Size | SHA-256 |
|---|---:|---|
| `Staging-CUI/Interface/hudmenu.gfx` | 264567 | `977404538C82BF82B6CD3D7E3B3590789E04C245161C8175457BD18F8C6788EF` |
| `Staging-CUI/Interface/hudmenu_lrg.gfx` | 264750 | `72D9749218B38D441C527051BF9D0D518EE330C00C485C91F8D06EBC5536993B` |
| `Staging-CUI/Interface/VenworksCUI/probe.xml` | 133 | runtime configuration input |

## Static validation

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

Static validation cannot prove that Starfield permits the XML request or how
it resolves the relative path. In-game testing remains the acceptance gate.

## Required in-game validation

Test with no HONKCORE HUD movie active. Fully restart Starfield between cases
so the one-shot HUD loader is recreated.

1. Deploy the staged GFX files and valid `probe.xml`.
2. Load a save and confirm yellow `VENWORKS XML LOADED` appears.
3. Remove the deployed `probe.xml`, restart, and confirm red
   `CUI XML MISSING` appears while the HUD remains functional.
4. Deploy `Scaleform/shared/fixtures/probe-malformed.xml` as
   `Interface/VenworksCUI/probe.xml`, restart, and confirm red
   `CUI XML MALFORMED` appears.
5. Deploy `Scaleform/shared/fixtures/probe-unsupported.xml` as
   `Interface/VenworksCUI/probe.xml`, restart, and confirm red
   `CUI XML UNSUPPORTED` appears.
6. Restore the valid staged document and confirm successful loading again.
7. Exercise health, oxygen/CO2, weapon/ammunition, compass, crosshair,
   notifications, scanner, first/third person, save load, and ship transitions.
8. Test the normal and large UI selection where possible.

## Acceptance rule

Accept XML as the runtime configuration foundation only if the configured
value loads through Starfield's file opener and every tested failure remains
diagnostic and nonfatal. If XML loading or relative-path resolution fails,
stop before implementing Goal 3 and prepare a separately approved fallback
comparison.
