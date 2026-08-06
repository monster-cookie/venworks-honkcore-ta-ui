# Clean-Room Development Boundary

## Purpose

This project independently implements a configurable Starfield UI using
vanilla Starfield assets and contracts. HONKCORE is a behavioral reference only
where the user has supplied or owns configuration expressing visible outcomes.

## Permitted sources

- Vanilla Starfield SWF/GFX files extracted from the user's licensed game.
- Vanilla Starfield data-provider names, movie roots, lifecycle behavior,
  visual behavior, and loose-file/package behavior established by inspection
  and runtime tests.
- Bethesda Creation Kit and Archive2 tooling under their applicable terms.
- Autodesk Scaleform documentation.
- Public SWF/ActionScript specifications and independently licensed tools.
- User-authored configuration values describing colors, labels, coordinates,
  dimensions, visibility intent, and desired visual behavior.
- Project-owned artwork and properly licensed third-party assets with notices.

## Prohibited sources and actions

- HONKCORE SWF/GFX files, ActionScript, decompiled code, bytecode, artwork,
  private algorithms, parser design, target implementations, or file format.
- Translating HONKCORE classes, routines, configuration grammar, or internal
  names into a new language or schema.
- Patching HONKCORE binaries.
- Claiming a HONKCORE-named target is a vanilla provider without independent
  vanilla evidence.
- Shipping HONKCORE files or requiring HONKCORE at runtime.
- SFSE/native-plugin fallbacks for required console-safe behavior.

## Behavioral-requirement procedure

For each migrated capability, record:

1. the desired user-visible behavior;
2. the permitted source of that requirement;
3. the independently discovered vanilla movie/provider contract;
4. the independent schema and runtime design;
5. static, automated, and in-game validation status;
6. known lifecycle or platform limitations.

If the vanilla contract is unknown, mark the capability unknown and probe it.
Do not infer implementation from HONKCORE behavior.

## Artifact handling

- Extract vanilla files to temporary or explicitly approved research paths.
- Do not treat Vortex-deployed loose overrides as vanilla evidence.
- Record source game version, artifact path, size, and hash for modified bases.
- Do not commit vanilla-derived binaries until the user approves the exact
  artifact and goal-specific plan.
- Keep generated staging output repository-local; never write directly into
  Starfield or Vortex during implementation without separate approval.
- Include required third-party notices and keep licensed asset imports bounded
  to the files actually used.

## Evidence vocabulary

- **Confirmed by static inspection:** directly observed in a permitted file.
- **Confirmed by automated check:** reproduced by a named passing check.
- **Confirmed in Starfield:** reproduced with the exact packaged artifact.
- **Inferred:** supported by evidence but not yet directly proven.
- **Unknown:** insufficient evidence; implementation must not depend on it.

## Explicit exclusions

- SPECTR.
- TACR as a dedicated component.
- Rear-view or secondary-camera rendering.
- HONKCORE compatibility or configuration parsing.
- SFSE or native DLL requirements.
- An end-user compiler or GUI editor in this repository.
