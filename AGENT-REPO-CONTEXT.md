# Repository Context

Repository-specific context for `Venworks Customizable HUD`. Unconfigured external services affect only work that needs them. These are repository-owned settings, with no global policy discovery or override system.

## Repository and Tool Chain

| Setting | Value |
| --- | --- |
| Project name | `Venworks Customizable HUD` |
| Repository URL | `https://github.com/monster-cookie/venworks-honkcore-ta-ui` |
| Target game | `Starfield` |

Use the current checkout as the repository path. Verify its remote against the configured repository before publishing. Keep machine-specific paths and secrets in protected local configuration, outside the repository.

The repository targets Starfield through five Canvas consumer variants. [Tools/sharedConfig.ps1](Tools/sharedConfig.ps1) owns variant configuration. The unreleased XML runtime and PS5 diagnostic pipeline have been removed. Inspect scripts and their side effects before executing them.

## Build and verification entry points

Use PowerShell 7 from the repository root with configured native inputs. Consumer compilation requires Java, Flex, a compatible Canvas checkout and environment, the Starfield Papyrus compiler, and Spriggit. Archive construction additionally requires Archive2.

| Entry point | Purpose |
| --- | --- |
| [Tools/buildVariant.ps1](Tools/buildVariant.ps1) | Build selected Canvas consumers using configured native tools and inputs. |
| [Tools/verifyVariant.ps1](Tools/verifyVariant.ps1) | Verify selected staged or committed variant artifacts; PreArchiveMutation checks inputs before archive creation. |
| [Tools/createPackages.ps1](Tools/createPackages.ps1) | Build selected PC, Xbox, and PS5 Main archives using Archive2. |
| [Tools/verifyCommittedRelease.ps1](Tools/verifyCommittedRelease.ps1) | Verify all committed release artifacts and repository contracts. |
| [Tools/createReleasePackages.ps1](Tools/createReleasePackages.ps1) | Assemble the five release package shapes for each selected theme. |
| [Tools/checkRepo.ps1](Tools/checkRepo.ps1) | Check five-theme release metadata and selected variant artifacts; Committed avoids live staging destinations. |
| [Tools/setupRepo.ps1](Tools/setupRepo.ps1) | Prepare staging destinations only when explicitly authorized. |

[Build documentation](docs/BUILDSYSTEM.md) describes the existing pipeline. Source checks, native compilation, archive construction, gameplay, and console acceptance are separate evidence. Never substitute a source-pattern check for execution of the production runtime.

## Canvas dependency

[Venworks Canvas](https://github.com/monster-cookie/venworks-canvas) owns the shared HUD host, provider subscriptions, event transport, consumer lifecycle, and HTML/CSS renderer. VWHUD owns its consumer, themes, derived presentation state, status publisher, and packages. Read Canvas's own repository guidance before changing it; resolve its checkout independently rather than recording a machine-specific path here.

The five variants are VWKS, TA, FC, CF, and MIN. Consumer packages must not distribute competing Canvas-owned HUD replacements. The local `CanvasConsumer` source tree is VWHUD-owned and does not contain Canvas framework code. Canvas work belongs to the separate Venworks Canvas (VWCNVS) Linear team.

## GitHub

The target is the repository URL above, verified against the checkout and task. Configure the actual connector or CLI and one supported authentication method. For a GitHub App installation, use evidence of the expected app/installation and repository access. For a dedicated user account, use that connection's supported account-identity check. A user-login check is not universal across authentication methods.

| Setting | Value |
| --- | --- |
| Tool | GitHub MCP or GitHub CLI |
| Authentication method | The configured local `github-mcp-server` stdio process mints installation tokens internally. The policy-permitted CLI fallback is the installed `Invoke-GitHubAppGh.ps1` wrapper, which mints a fresh installation token, supplies it only to one `gh` child process as `GH_TOKEN` with a dedicated `GH_CONFIG_DIR`, and discards and revokes the token after the command. Explicitly authorized Git transport uses the same wrapper with `-Git`; the Git child receives the installation token and a process-only `gh auth git-credential` helper, with interactive prompting disabled and no persisted Git configuration change. Do not set persistent User or Machine `GH_TOKEN` or `GITHUB_TOKEN` values, modify the user's normal `gh` or Git authentication, invoke `gh` directly for Codex GitHub operations, or run authenticated Git transport outside the wrapper. |
| Expected identity | The GitHub App identified by `GITHUB_APP_ID`, acting through the installation identified by `GITHUB_APP_INSTALLATION_ID`. The installation must have access to the exact GitHub repository resolved by this context and current task. Do not record the resolved numeric IDs, private-key path, token, or other credential material in repository files or public output. |
| Connection / credential source | Environment variable names `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, and `GITHUB_APP_PRIVATE_KEY_PATH`. Resolve their values only inside the consuming process, require the key path to identify an existing PEM file, and never print or persist the resolved values. |
| Verification | An installation token has no GitHub user identity, so do not use `mcp__github__get_me`, `gh api user`, or a display login as verification. Through the same consuming MCP session or wrapped CLI process, perform a read-only installation-repository query and a read-only query of the exact target repository. Require host `github.com`, API endpoint `https://api.github.com`, agreement with this repository target, and repository access attributable to the configured App installation. Before an authenticated Git mutation, perform a read-only Git transport query through the wrapper's `-Git` mode and verify the exact remote destination. Stop on a missing variable, invalid key, token-minting failure, installation mismatch, inaccessible target, transport failure, or ambient-authentication fallback. |
| Fallback | None unless explicitly configured for the same identity and target |
| Commit author and committer | `MonsterCookieAI <venworksai@venworkscreations.com>`; replace with the adopting maintainer's chosen automation identity |

Apply commit attribution only to the individual authorized commit command, preserving persistent Git settings. Verify both author and committer in the resulting commit before pushing. Attribution does not establish transport or API identity; follow the shared [identity](AGENTS.md#external-tools-and-identities) and [Git delivery](AGENTS.md#git-and-github-boundaries) boundaries. Unused GitHub integration fields do not block local work.

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

Use the provider's actual workflow and the user's requested actions. No fixed state transition is required before coding unless the project or task requires it. Resolve real ownership conflicts, but do not treat empty assignments as blockers. Preserve assignee and agent-delegate fields unless changing them is explicitly authorized; connector attribution is separate from ownership. A prepared handoff does not require a status change. Use the shared [external-action boundaries](AGENTS.md#external-tools-and-identities) for comments, updates, and completion, without inventing claims, locks, or substitute tracker state.

### Tracker-derived roadmaps

When requested, select issues using the project's actual statuses, labels, milestones, and the requested criteria; clarify ambiguous selection only when it matters. Preserve scope, dependencies, and meaningful grouping without counting a parent and its children as separate promises for the same outcome. Present a current snapshot, not invented release dates or commitments. Refresh when relevant changes are expected and identify incomplete retrieval. Preparing content does not authorize publication.

## Credential setup

Use each service's connection / credential source entry above to identify its managed connection or selected credential manager. These are non-secret configuration descriptions, not executable login commands or credential values. Keep private credential selectors and authentication state in protected local configuration and follow the shared [identity boundaries](AGENTS.md#external-tools-and-identities). Credential-manager setup is needed only when an authorized operation cannot use an existing verified connection.

For a service using Proton Pass CLI (`pass-cli`), the bootstrap credential is the protected `PROTON_PASS_PERSONAL_ACCESS_TOKEN` environment variable supplied by local setup. It is separate from the downstream service credential and must never be stored as a Proton Pass item or represented by a `pass://` reference. The service's expected identity above names the downstream account or app, not the credential-manager session. Optional token-name metadata is not a prerequisite for a healthy session.

For authorized setup or recovery, consult the installed CLI's help and current provider documentation, such as the [Proton Pass CLI documentation](https://protonpass.github.io/pass-cli/). Use task-owned session state without logging out or changing the user's default session. Detailed login, credential-transfer, and cleanup commands depend on the selected tool and local setup; they are not part of the mod-development workflow.
