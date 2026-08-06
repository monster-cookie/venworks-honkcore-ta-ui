# Venworks Custom Starfield VUI Implementation Plan

## Purpose

This document is a goal-based implementation brief for Codex running in the
**Venworks Mod - Honkcore UI Themes** project and working against the
**Venworks - Honkcore UI** repository.

The objective is to replace the current dependency on HONKCORE with an
independently implemented, configuration-driven Starfield UI system. Authors
will describe layouts with a restricted HTML-like VUI language, apply
color/palette themes with a constrained CSS language, and compile the result
with a self-contained, cross-platform .NET 10 console application.

The finished game package must remain compatible with Starfield's console-safe
Scaleform asset path. It must not require SFSE, a native DLL, a background
desktop service, or any executable code on the gaming device.

This is an implementation plan, not proof that every desired runtime behavior
is currently available. Treat the feasibility gates below as blocking. Never
convert a hypothesis into a promised feature without the required probe.

## Confirmed product decisions

- The compiler must run on Windows, Linux, and macOS.
- The distributed compiler must be self-contained and must not invoke Java,
  Node.js, Adobe Animate, an AIR/Flex compiler, `gfxexport`, or another external
  executable.
- Layout authoring will use a restricted HTML-like VUI format.
- Color/palette styling will use data-only, injectable theme packages.
- A theme is selected and compiled before Starfield launches.
- Runtime theme switching would be useful, but it is optional and must not
  delay the compile-time theme workflow.
- SVG path rendering is required. PNG is the approved fallback for SVG
  features that the Scaleform runtime cannot reproduce faithfully.
- PNG support is required. JPEG support should be retained because it is useful
  for opaque photographic art and is already part of the broader asset goal.
- Font Awesome Pro+ may be used under the user's redistribution rights.
- Configurable behavioral parity should cover HONKCORE's user-configurable HUD
  features except SPECTR and TACR.
- Ship UI scope includes the cockpit HUD, targeting and weapons, power
  allocation, ship notifications, and relevant ship builder/menu interfaces.
- The likely deployment path is an independent loose
  `Interface/hudmenu.gfx` replacement, matching the kind of integration point
  HONKCORE used without copying HONKCORE's implementation.
- SFSE and native plugins are prohibited because the output must support
  consoles.
- A rear-view camera is excluded. Historical SPECTR configuration decorated
  the normal third-person view; it did not provide a second render-to-texture
  camera. A genuine picture-in-picture rear view is not a deliverable under
  the no-SFSE, console-safe constraint.

### Rear-view camera research conclusion

Do not reopen the rear-view camera as an implementation goal without new
vanilla engine evidence. The available Starfield Papyrus surface can force
first/third person, set the player camera target, play an event camera, and
start or stop the dialogue camera. These operations change the primary player
camera; they do not return a camera image, texture, render target, or second
simultaneous view.

Scaleform can display a dynamic 3D texture only when the host engine integration
provides that texture through a native image-loader callback or substitutes an
engine render target for an exported movie resource. ActionScript cannot create
that engine-side world render by itself. Static inspection found no dialogue
camera, external-texture, or render-target hook in HONKCORE's HUD movie, and the
historical SPECTR configuration contained only ordinary shapes and labels shown
over the main third-person screen.

Reusing the dialogue camera could therefore replace the main forward view, but
it cannot produce the requested live 400-by-400 rear view while the forward view
remains visible. Because SFSE/native code is prohibited, omit this feature and
do not substitute another rear-camera behavior unless the user explicitly
changes the requirement.

## Rules for Codex

1. Read every applicable `AGENTS.md` completely before acting. More specific
   repository instructions override this plan.
2. Inspect the repository, worktree status, existing user changes, project
   files, build configuration, release workflows, and tests before proposing
   edits.
3. Present a surgical task plan before each implementation goal. Do not treat
   this document as authorization for unrelated cleanup or Git operations.
4. Stop and ask the user whenever an unresolved choice could materially change
   file formats, compatibility, licensing, packaging, public APIs, or runtime
   behavior.
5. Do not add a dependency without approval. Prefer .NET 10 base-class-library
   functionality for the first implementation.
6. Do not modify installed Starfield files, Vortex mod files, Creation Kit
   files, or other external deployment targets without explicit approval.
   Generate repository-local staging output instead.
7. Do not copy HONKCORE source, decompiled ActionScript, bytecode, artwork, or
   proprietary assets. Public/user-visible configuration capabilities may be
   inventoried and independently reimplemented.
8. Use vanilla Starfield assets and data contracts as behavioral references,
   while respecting repository and distribution licensing requirements.
9. Keep evidence labels explicit: confirmed by source/static inspection,
   confirmed by automated test, confirmed in Starfield, inferred, or unknown.
10. Do not claim a test or runtime validation passed unless it was actually run
    against the exact artifact and passed.
11. Keep changes surgical and avoid formatting churn. Evaluate decomposition
    when a source file approaches 1,000 lines.
12. All new or modified C# types and members require meaningful XML
    documentation, including behavior, parameters, return values, nullable
    behavior, side effects, and relevant exceptions.
13. Do not create branches, stage, commit, push, publish, or alter Git history
    unless the user explicitly approves those actions in a task-specific plan.
14. After each goal, report validation performed, remaining unknowns, changed
    files, and estimated token usage when exact usage is unavailable.

## Clean-room boundary

The project may reproduce useful capabilities exposed by HONKCORE's text
configuration because those capabilities describe user-observable behavior:
positioning, anchoring, visibility expressions, labels, meters, colors,
shapes, icons, and state-dependent presentation.

Implementation must be independently designed:

- Do not translate or port HONKCORE ActionScript.
- Do not copy parser structures, internal class names, private algorithms, or
  embedded asset data.
- Do not ship HONKCORE's `hudmenu.gfx` as the new runtime.
- Do not use HONKCORE's artwork unless separate permission exists.
- Record the vanilla UI contract, desired behavior, independent design, and
  validation result for each implemented capability.
- Preserve a short `CLEAN_ROOM.md` describing these boundaries and the sources
  used for behavioral requirements.

## Architecture target

The end-user compiler and the game runtime are separate products:

```text
VUI layout + CSS theme + project manifest + source assets
                         |
                         v
         Self-contained .NET 10 VUI compiler
                         |
                         v
       Validated runtime JSON + processed assets
                         |
                         v
       Prebuilt independent Scaleform HUD runtime
                         |
                         v
     Console-safe Interface staging/package directory
```

The compiler must not compile ActionScript or convert SWF to GFX during normal
use. Instead, it packages a versioned, prebuilt Scaleform runtime owned by this
project and compiles authoring files into runtime data that the movie loads.

This distinction is necessary to keep the console compiler self-contained.
Building or updating the Scaleform runtime itself is a developer workflow and
has a separate feasibility gate. Do not quietly introduce an external runtime
compiler into the end-user CLI.

Suggested solution boundaries, subject to the existing repository structure:

```text
src/
  Venworks.Vui.Schema/
  Venworks.Vui.Markup/
  Venworks.Vui.Css/
  Venworks.Vui.Compiler/
  Venworks.Vui.Assets/
  Venworks.Vui.Cli/
runtime/
  scaleform/
examples/
  minimal-hud/
  themes/
tests/
  Venworks.Vui.*.Tests/
docs/
  CLEAN_ROOM.md
  VUI_REFERENCE.md
  CSS_REFERENCE.md
  STARFIELD_BINDINGS.md
  THEME_AUTHORING.md
```

Do not create this structure mechanically if the repository already has a
clearer convention. Propose the exact layout after inspection.

## Goal 0: Repository and toolchain discovery

### Outcome

Produce an evidence-backed discovery report and a task-specific implementation
plan without editing product code.

### Required work

- Identify the actual primary repository root and all governing instructions.
- Inventory tracked UI configuration, build scripts, staging folders, release
  workflows, tests, and existing solution/project files.
- Confirm whether a .NET solution already exists or should be introduced.
- Confirm the target .NET 10 runtime identifiers before release. At minimum,
  evaluate `win-x64`, `linux-x64`, `osx-x64`, and `osx-arm64`.
- Inventory the installed/local Starfield HUD and ship UI movies, but do not
  modify them.
- Identify the exact filename and load precedence for a loose HUD replacement.
- Determine whether `hudmenu.gfx` can load adjacent JSON and image files using
  Starfield's file opener.
- Identify how a project-owned Scaleform runtime can be built, tested, and
  legally redistributed. Keep this separate from the end-user compiler.
- Produce an initial inventory of HONKCORE-configurable behavior from the
  user-owned configuration files. Explicitly exclude SPECTR and TACR.

### Stop conditions

Stop and ask before:

- Adding a .NET solution or relocating existing files.
- Selecting a Scaleform/ActionScript developer toolchain.
- Adding NuGet packages or vendored parsers.
- Committing a vanilla-derived or third-party binary.
- Assuming a loose file path works without a runtime probe.

### Done when

The user has approved the exact repository layout, first implementation slice,
runtime-build approach, and test strategy.

## Goal 1: Define the versioned VUI project model

### Outcome

Define a small, deterministic authoring language that feels familiar to an
HTML/CSS author without claiming browser compatibility.

### Project manifest

Prefer JSON for the initial project and theme manifests because .NET 10
provides `System.Text.Json` and the runtime artifact is already expected to use
JSON. Avoid introducing TOML solely for aesthetics. If the user later requires
hand-edited TOML, stop and propose either a small bounded parser or an approved
dependency.

The project manifest should define at least:

- Schema version.
- Entry VUI document.
- Available and selected palette theme.
- Design resolution and safe area.
- Asset roots.
- Enabled HUD modules.
- Target Starfield UI movie.
- Output/staging path.
- Runtime compatibility version.

### VUI markup

Use strict, well-formed, HTML-like markup that can be parsed with .NET XML
facilities. Give it a project-specific extension such as `.vui` so users do
not expect arbitrary web HTML to work.

Initial element vocabulary:

- `hud`: document/stage root.
- `panel`: positioned and styled container.
- `stack`: horizontal or vertical flow container.
- `text`: plain, bound, or formatted text.
- `image`: compiled bitmap or supported vector asset.
- `shape`: rectangle, rounded rectangle, ellipse, circle, line, polygon, and
  SVG path.
- `meter`: normalized or ranged value display.
- `repeat`: bounded repeated data template.
- `if`: conditional content.
- `component`: reusable local component definition.
- `use`: component instantiation.

Initial attributes and binding concepts:

- `id` and `class`.
- `data-bind` for a value.
- `data-source` for repeated data.
- `data-visible` for a boolean/state expression.
- `data-format` for bounded formatting.
- `data-positive` and `data-negative` for state-derived styling.
- `aria-label` or a VUI-specific accessibility/diagnostic label for tooling.

Do not add arbitrary script tags, inline ActionScript, JavaScript, event code,
network resources, or runtime reflection.

### Expression language

Visibility and value expressions require a small documented grammar. Support
only approved operations such as:

- Boolean literals and properties.
- `NOT`, `AND`, and `OR` with explicit precedence.
- Numeric and string comparisons.
- Parentheses.
- Null-safe property access defined by the schema.

Do not use `eval`, dynamic ActionScript compilation, or arbitrary method calls.

### Schema and compatibility

- Assign an explicit schema version from the first release.
- Reject unknown required elements/properties by default.
- Allow forward-compatible optional metadata only in a defined extension area.
- Produce line-and-column diagnostics.
- Document migrations when the schema changes.

### Done when

- The schema and examples are reviewed.
- Invalid documents produce actionable errors.
- A minimal HUD document parses into a neutral in-memory scene tree.
- The same document serializes deterministically.

## Goal 2: Implement constrained CSS and palette themes

### Outcome

Allow multiple data-only palette packages to style the same VUI layout before
Starfield launches.

### Required CSS profile

Implement only a documented subset:

- Type, class, ID, and selected attribute selectors.
- A bounded descendant selector if required by theme examples.
- CSS custom properties with cycle detection.
- Color, background color, opacity, fill, stroke, and stroke width.
- Font family, font size, font weight, text alignment, and line spacing where
  supported by Scaleform.
- Width, height, minimum/maximum bounds where the VUI layout supports them.
- Margin, padding, and gap.
- Anchor, offsets, and z-order through documented VUI properties.
- Supported translate, scale, rotation, and perspective properties.
- State classes derived by bindings.

Explicitly exclude browser flexbox, grid, floats, pseudo-elements, arbitrary
animations, media queries, remote imports, URLs outside approved asset roots,
and general browser cascade behavior unless separately designed and tested.

### Theme package

A theme package should contain:

```text
theme.json
theme.css
assets/
fonts/
LICENSES/
```

The manifest should include:

- Stable theme ID and display name.
- Theme version.
- Supported VUI schema and runtime versions.
- Optional parent theme.
- Author and licensing metadata.
- CSS entry points.
- Asset and icon overrides.

Theme packages must be data-only. They cannot contain executable plugins,
scripts, native libraries, or arbitrary compiler extensions.

### Injection and precedence

Use an explicit order:

1. Runtime defaults.
2. Base layout styles.
3. Selected palette theme.
4. Project-level user overrides.

Report conflicting IDs, invalid inheritance, missing assets, unsupported
properties, and variable cycles. Never silently discard an invalid theme.

The compiler should compile exactly one selected theme into each output
package for the first release. Console users receive precompiled variants.
Runtime theme switching may be investigated only after the baseline works; it
must not complicate the first runtime.

### Done when

- At least two visually distinct example themes compile against one layout.
- Theme packages can be added without rebuilding the compiler or Scaleform
  runtime.
- The compiler produces deterministic resolved styles.
- Invalid themes fail with precise diagnostics.

## Goal 3: Build the self-contained cross-platform CLI

### Outcome

Deliver a .NET 10 console compiler that validates, compiles, inspects, and
packages VUI projects on Windows, Linux, and macOS without invoking external
executables.

### Suggested commands

```text
vui validate <project>
vui compile <project> --theme <theme-id> --output <directory>
vui inspect <compiled-manifest>
vui list-themes <project>
vui package <project> --theme <theme-id> --output <directory>
```

Use naming consistent with the repository after inspection.

### Compiler behavior

- Resolve all input paths relative to the project file.
- Prevent path traversal outside approved roots.
- Parse markup and CSS into typed models.
- Validate bindings against a versioned Starfield binding catalog.
- Resolve theme inheritance and CSS variables.
- Normalize asset references and deduplicate by content hash.
- Emit stable property ordering and normalized numeric formatting.
- Produce a manifest containing input and output hashes.
- Use nonzero process exit codes for errors.
- Keep human-readable output concise and provide an optional structured JSON
  diagnostic mode.
- Never write outside the requested output directory.
- Never deploy directly into Starfield or Vortex.

### Runtime output

Prefer a compact, versioned JSON scene model containing:

- Runtime/schema versions.
- Stage and safe-area settings.
- Flattened nodes and hierarchy.
- Resolved selected-theme styles.
- Validated bindings and expressions.
- Asset table and hashes.
- Enabled module list.
- Diagnostic/source-map references for development builds.

The output is a runtime contract, not a copy of the source HTML/CSS.

### Publishing

Publish self-contained artifacts for the approved runtime identifiers. Test
single-file publication only if it does not break required data files,
reflection, or native asset processing. Do not enable trimming without tests.

The compiler may package a prebuilt project-owned `hudmenu.gfx`, but it may not
invoke a separate compiler to create that GFX during end-user operation.

### Testing

- Parser and diagnostics tests.
- Golden-file compilation tests.
- Deterministic build tests.
- Path traversal and hostile-input tests.
- Cross-platform path/case tests.
- Theme resolution tests.
- Asset hashing/deduplication tests.
- CLI exit-code and structured-output tests.
- Windows, Linux, and macOS CI.

### Done when

The same example project produces semantically identical and, where practical,
byte-identical compiled output on every supported operating system.

## Goal 4: Implement the image, icon, and vector asset pipeline

### Outcome

Support safe, deterministic UI assets with SVG-path rendering as the required
vector baseline and PNG fallback for unsupported SVG features.

### PNG and JPEG

- Validate signatures instead of trusting extensions.
- Read and report dimensions before processing.
- Preserve PNG alpha.
- Reject unreasonable dimensions and decompression-bomb-like inputs.
- Preserve originals unless an explicitly configured conversion is required.
- Document color-space and premultiplied-alpha behavior.
- Use deterministic output encoding if the compiler transforms an asset.
- Probe Starfield's accepted loose-file paths before choosing runtime loading.

### SVG path support

The required path parser must support:

```text
M m L l H h V v C c S s Q q T t A a Z z
```

It must also support:

- Multiple subpaths.
- Relative and absolute coordinates.
- Repeated coordinate groups.
- `viewBox` scaling.
- Nested transforms required by supported static assets.
- Fill color, opacity, and fill rule.
- Stroke color, width, joins, caps, and opacity where the runtime supports them.
- Elliptical arc conversion to primitives the Scaleform renderer can draw.
- Correct bounds calculation.
- Clear errors for malformed data.

Build conformance fixtures for every command, transform order, arc flags,
negative values, scientific notation, and compound paths.

### Broader SVG input

Do not promise the full SVG specification. Define a supported static profile
after inspecting actual desired assets.

- Render supported paths and basic shapes as vectors.
- Flatten supported transforms during compilation where useful.
- Convert unsupported static visual features to PNG when a faithful,
  self-contained conversion can be implemented.
- Otherwise fail with a diagnostic that names the unsupported feature and
  directs the author to provide a PNG fallback.
- Reject scripts, animation, network resources, embedded HTML, external files
  outside asset roots, and unsafe references.

Because the CLI cannot invoke an external SVG renderer, do not claim automatic
full-SVG rasterization until a managed, redistributable approach is approved
and tested on all platforms. Manual PNG fallback is acceptable.

### Font Awesome Pro+

- Ask the user for the approved Font Awesome Pro+ version, source location, and
  redistribution notice before importing assets.
- Do not commit the complete licensed package by default.
- Import only icons referenced by the project.
- Prefer converting an icon's SVG path data into the VUI vector representation.
- Allow PNG fallback for icons outside the supported SVG profile.
- Preserve required attribution and licensing files in generated packages.
- Permit theme packages to override icons without changing component layouts.
- Verify Starfield/Scaleform font embedding separately before relying on the
  Font Awesome font file. Do not treat executable strings as runtime proof.

### Done when

- All SVG path commands pass conformance tests.
- Representative alpha PNG, opaque JPEG, compound SVG path, and Font Awesome
  icon assets compile deterministically.
- Each unsupported SVG feature produces an actionable fallback diagnostic.
- The exact compiled assets are validated in the Starfield runtime probe.

## Goal 5: Prove and build the independent Scaleform runtime

### Outcome

Create a project-owned HUD movie that loads compiled VUI data and renders a
minimal themed panel in Starfield without HONKCORE or SFSE.

### Blocking toolchain distinction

The end-user CLI is self-contained; the developer runtime build may still need
an ActionScript/SWF/GFX authoring tool. Codex must inventory legal and locally
available options, explain their licensing and reproducibility, and ask before
adopting one.

If no acceptable runtime build path exists, stop. Do not attempt to solve that
silently by copying or patching HONKCORE's binary.

### Minimal runtime responsibilities

- Load the compiled JSON scene through Starfield's file opener.
- Validate the runtime format version.
- Build `Sprite`, `Shape`, `TextField`, bitmap, and supported vector-path nodes.
- Apply already-resolved styles.
- Implement anchors, absolute positioning, horizontal/vertical stacks,
  padding, margin, gap, bounds, and explicit layering.
- Evaluate the bounded visibility expression language.
- Subscribe to approved Starfield data providers.
- Update bound values without rebuilding unrelated nodes.
- Handle HUD/menu construction and destruction safely.
- Display bounded development diagnostics instead of failing invisibly.

### Deployment strategy

Target a loose `Interface/hudmenu.gfx` replacement unless Goal 0 proves that a
different vanilla-supported, console-safe path is materially safer.

Why this is the current target:

- It gives the project ownership of the full HUD runtime.
- It supports external configuration without requiring an SFSE movie loader.
- It matches the broad integration route proven by existing HUD replacements.
- It is compatible with normal mod packaging rather than runtime DLL injection.

The cost is that the replacement must preserve every required vanilla HUD
contract and coexistence behavior. Treat missing vanilla functionality as a
release blocker.

### Required probe order

1. Load a minimal independent movie in the HUD slot.
2. Display static text and a vector rectangle.
3. Load adjacent runtime JSON.
4. Render a scene from that JSON.
5. Load and display PNG and JPEG assets.
6. Render every supported SVG path category.
7. Bind one value from a proven always-loaded HUD provider.
8. Test initialization, save loading, menu transitions, death/reload, first and
   third person, scanner, combat, ship entry/exit, ladders, and workbenches.
9. Package the same artifact through the repository-local staging structure.

Pause and report after steps 3, 6, and 8. Do not expand into feature parity
until these gates pass.

### Done when

A clean Starfield launch displays a repository-built, themeable VUI panel from
compiled JSON, survives the lifecycle matrix, and does not require HONKCORE or
SFSE.

## Goal 6: Reimplement approved HUD configurability

### Outcome

Provide independently implemented equivalents for the configurable HONKCORE
HUD capabilities, excluding SPECTR and TACR.

### Feature inventory first

Before implementation, produce a reviewable table from user-facing config and
vanilla UI behavior. Include at least:

- Default component visibility and repositioning.
- Boot sequence and suit-state presentation.
- Health, oxygen/CO2, inventory/carry, boost, and other meters.
- Weapon, ammunition, explosive, and holstered/drawn states.
- HUD information widget placement/integration behavior where independently
  supportable.
- Player status effects, alerts, and environmental information, excluding the
  TACR presentation component itself.
- Scanner presentation and scanner-state warnings.
- Enemy health/name and combat warnings.
- Hit, sneak, crosshair, quest, and quick-access components.
- Vignette and threshold warnings.
- Labels, shapes, lines, circles, paths, colors, opacity, anchors, perspective,
  visibility expressions, blink, flicker, glitch, and bounded animations.
- Aspect-ratio, ultrawide, safe-area, and accessibility scaling behavior.

Do not assume a named HONKCORE target maps directly to a vanilla provider.
Document the actual vanilla movie clip/provider contract.

### Implementation order

1. Static labels, shapes, anchors, and visibility expressions.
2. Always-loaded player meters and weapon/ammo values.
3. Warnings and state transitions.
4. Scanner components.
5. Enemy/combat components.
6. Repeated status-effect UI after its separate runtime gate.
7. Bounded visual effects and animations.
8. Remaining approved components from the inventory.

Each component needs:

- VUI schema representation.
- Documented binding and source provider.
- Default layout.
- Theme hooks.
- Unit/golden tests.
- Starfield lifecycle test cases.
- Explicit validation status.

### Status-effect gate

Detailed `PlayerStatusData` exists, but its availability in an always-loaded
HUD context is not yet proven. Build the smallest diagnostic subscription
before promising named persistent effects.

Test:

- A save loaded without opening Status.
- A timed chem buff.
- Bleeding or another injury.
- Poison or infection.
- Before and after opening/closing Status.
- Effect updates/expiration while Status remains closed.

If detailed data is unavailable, use only the reduced console-safe HUD feeds
that are actually delivered. SFSE is not an allowed fallback.

### Explicit exclusions

- SPECTR.
- TACR as a dedicated component.
- Rear-view or secondary camera rendering.
- Native hooks or SFSE bridges.
- Browser HTML/JavaScript.

### Done when

Every approved inventory row is either implemented and validated or explicitly
documented as unavailable through console-safe vanilla Scaleform contracts.

## Goal 7: Make the complete ship UI customizable

### Outcome

Apply the same VUI, theme, asset, and compiler model to the approved ship UI
scope without destabilizing the player HUD.

### Discovery gate

Inventory the actual vanilla movies and providers for:

- Cockpit HUD.
- Hull, shield, speed, boost, and mobility presentation.
- Ship weapons and ammunition/cooldowns.
- Target selection, lock, range, and target information.
- Power allocation and subsystem states.
- Navigation, docking, landing, grav jump, and interaction prompts.
- Ship warnings and notifications.
- Relevant ship builder and ship-management menus.

Do not guess filenames or assume that one HUD movie owns all of these. Record
each movie's load path, lifecycle, provider subscriptions, inputs, and required
root contracts.

### Design requirements

- Reuse the VUI schema and palette packages.
- Define ship-specific components rather than embedding ship semantics into
  generic layout nodes.
- Allow position, visibility, size, colors, icons, typography, and supported
  animations to be configured.
- Preserve controller and keyboard/mouse navigation in interactive menus.
- Preserve vanilla warning priority and critical information.
- Keep player HUD and ship UI packages independently testable.
- Allow a palette theme to cover both player and ship UI through scoped CSS.

### Implementation sequence

1. Noninteractive cockpit presentation.
2. Target and weapon displays.
3. Power allocation.
4. Ship notifications and warnings.
5. Interactive ship menu surfaces.
6. Ship builder/management surfaces after input/navigation tests exist.

Pause for user review between the noninteractive HUD and interactive menu
phases. Interactive menu replacement has a much higher compatibility risk.

### Done when

The approved ship UI surfaces can be themed and configured through VUI while
preserving their vanilla information, input behavior, and menu lifecycle.

## Goal 8: Packaging, console safety, and releases

### Outcome

Produce predictable PC staging output and console-safe content suitable for the
repository's release workflow and later official console publishing steps.

### Requirements

- Generate a complete staging tree; never deploy directly from the compiler.
- Include only data, Scaleform movies, permitted fonts, and permitted assets.
- Include schema/runtime/compiler version metadata.
- Include third-party notices and Font Awesome redistribution notices.
- Validate that package paths use the correct case and separators.
- Produce one package per selected palette theme for the first release.
- Ensure no HONKCORE dependency or files are included.
- Ensure no SFSE/native binary is included.
- Verify archives contain the contents at the expected root, not a staging
  folder wrapper.
- Keep official Bethesda/console publishing tooling outside the compiler if it
  cannot be legally or technically embedded. The compiler's job is to produce
  console-safe source content for that publishing step.

### Compatibility matrix

At minimum, test:

- Windows compiler output.
- Linux compiler output.
- macOS Intel and Apple Silicon compiler output when approved.
- Clean Starfield installation with only the generated UI package.
- Common mod-manager deployment on PC.
- Controller-only navigation.
- 16:9, 16:10, 21:9, and 32:9 presentation.
- First person, third person, scanner, combat, ship transitions, ladders,
  workbenches, death/reload, and save load.
- Each shipped palette theme.

### Done when

Release artifacts are reproducible, independently licensed, console-safe, and
validated against the documented runtime matrix.

## Recommended first milestone

Do not begin with the full HUD or ship UI.

The first milestone is complete only when this pipeline works end to end:

```text
minimal.vui + trackers.css + one PNG + one SVG path
                            |
                            v
             self-contained .NET 10 CLI
                            |
                            v
              validated runtime JSON/assets
                            |
                            v
          independent prebuilt hudmenu.gfx runtime
                            |
                            v
                 one panel inside Starfield
```

The panel must demonstrate:

- One static shape.
- One SVG path.
- One transparent PNG.
- One text field bound to a proven HUD provider.
- One conditionally visible element.
- Two separately injectable palette packages compiled one at a time.
- Correct behavior across a HUD reload and a save load.

After this milestone, stop and obtain user approval before implementing the
complete HUD feature inventory.

## Recommended task breakdown for Sol in high mode

Use one Codex task per goal or bounded sub-goal. Do not ask one task to implement
the entire system.

1. Repository/toolchain discovery and clean-room feature inventory.
2. VUI schema, parser, diagnostics, and examples.
3. CSS subset, theme manifests, cascade, and theme tests.
4. Cross-platform CLI compilation and deterministic runtime JSON.
5. PNG/JPEG and SVG-path asset pipeline.
6. Scaleform runtime toolchain decision and minimal independent movie.
7. JSON-loading and rendering runtime probe.
8. Minimal in-game milestone validation.
9. HUD component group implementations in the ordered batches above.
10. Detailed status-effect runtime probe and bounded implementation.
11. Ship UI discovery and noninteractive cockpit HUD.
12. Interactive ship UI phases after explicit approval.
13. Packaging, cross-platform CI, console-safety audit, and documentation.

For each task, Codex should begin with repository inspection, present a plan,
identify blocking questions, implement only the approved slice, run proportionate
validation, and leave unresolved runtime claims explicit.

## Final acceptance criteria

The project is complete when:

- A self-contained .NET 10 CLI is published for Windows, Linux, and macOS.
- VUI markup and constrained CSS compile deterministically.
- Data-only palette packages are injectable and at least two examples ship.
- The compiler invokes no external executables.
- SVG path commands are supported and PNG fallback is documented.
- PNG, JPEG, and approved Font Awesome icons render through the validated asset
  path.
- The independent HUD runtime requires neither HONKCORE nor SFSE.
- Approved HUD capabilities, excluding SPECTR and TACR, are implemented or
  explicitly documented as unavailable through vanilla console-safe contracts.
- Approved player status information is shown only to the level proven
  available in HUD context.
- The complete approved ship UI scope is configurable without breaking input
  or critical information.
- Rear-view camera rendering is not included.
- PC staging and console-safe release content are reproducible.
- Documentation covers authoring, themes, bindings, assets, clean-room
  boundaries, validation status, and known limitations.
