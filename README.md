# Venworks Customizable UI

A Trackers Alliance-themed custom UI built on HONKCORE.

## Documentation

The [Venworks Codecks workspace](https://venworks.codecks.io/) is the single
source of truth for product design, developer planning, feature requirements,
implementation state, and acceptance criteria. Use the `Documentation` deck
for the current design documents and the relevant feature, task, bug, or
testing card for delivery details.

The repository keeps only code-adjacent operational references and material
that is not maintained as feature documentation in Codecks:

- [Component catalog](docs/COMPONENT_CATALOG.md) documents the runtime
  component and binding contracts implemented by the code.
- [Build system](docs/BUILDSYSTEM.md) documents the Scaleform build and staging
  process.
- [Scaleform sources](Scaleform/README.md) explains local requirements and
  build usage.
- [Visual references](docs/reference/) preserve clean-room behavioral and
  visual evidence.
- [Known issues](KnownIssues.md) and the [changelog](CHANGELOG.md) describe
  repository and release history.

The `docs` directory will gradually transition toward user-facing
documentation. Historical implementation plans and Goal reports are available
through Git history but are no longer maintained in the working tree.

Repository-specific automation requirements are documented in
[`AGENT-REPO-CONTEXT.md`](AGENT-REPO-CONTEXT.md).
