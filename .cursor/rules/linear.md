# Linear

## Linear Project Management and Issue Tracker

| Setting | Value |
| --- | --- |
| Provider | Linear |
| Workspace / organization | Venworks |
| Team / repository scope | Venworks Customizable HUD (VWHUD) |
| Project scope | Not Applicable |
| Tool | Linear MCP |
| Connection / credential source | Not Applicable |
| Authentication method | Reuse the configured `mcp__linear_codex__*` connection only after verifying its actual app user. Do not assume a shell environment change, browser login, GitKraken connection, or Proton Pass session changes that connection. Credential setup or renewal requires its own authorized workflow; defer dependent operations if the correct connection is unavailable. |
| Expected identity | The active `Venworks AI Agent User` authenticated by the configured `mcp__linear_codex__*` OAuth connection for the Venworks workspace. Resolve provider identifiers through that connection when needed; do not record them in this file or infer this identity from another application's session. |
| Verification | Through the same Linear connection that will perform the operation, call `get_user` with `query="me"` and confirm the account is active and named `Venworks AI Agent User`. Call `get_workspace` and confirm `Venworks`; call `get_team` with `query="VWHUD"` and confirm `Venworks Customizable HUD`. Verify that each target issue or document belongs to that team before a dependent action. Stop the affected action if the account or target differs or cannot be established. Check assignment eligibility separately when assigning work. |
| Fallback | None unless explicitly configured for the same identity and target |

Use stable identifiers or canonical URLs and only the scopes required by the selected provider. Do not assume UUIDs, a parent/child hierarchy, or specific MCP names or endpoints. For no tracker, set provider and tool to `none` and the remaining configurable tracker fields to `not applicable`.

When an issue governs the task, verify that it belongs to the intended scope and read its requirements, acceptance criteria, relevant discussion, and dependencies. The issue supplies current task requirements; repository source and documentation supply technical contracts and recorded evidence. Resolve material conflicts before dependent work, and refresh issue information when relevant changes may affect the result. A fully specified local request needs no invented issue or tracker bookkeeping.

Use the provider's actual workflow and the user's requested actions. No fixed state transition is required before coding unless the project or task requires it. Resolve real ownership conflicts, but do not treat empty assignments as blockers. Preserve assignee and agent-delegate fields unless changing them is explicitly authorized; connector attribution is separate from ownership. A prepared handoff does not require a status change. Use the shared [external-action boundaries](../../AGENTS.md#external-tools-and-identities) for comments, updates, and completion, without inventing claims, locks, or substitute tracker state.

### Tracker-derived roadmaps

When requested, select issues using the project's actual statuses, labels, milestones, and the requested criteria; clarify ambiguous selection only when it matters. Preserve scope, dependencies, and meaningful grouping without counting a parent and its children as separate promises for the same outcome. Present a current snapshot, not invented release dates or commitments. Refresh when relevant changes are expected and identify incomplete retrieval. Preparing content does not authorize publication.
