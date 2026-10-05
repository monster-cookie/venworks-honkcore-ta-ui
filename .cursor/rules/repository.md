# Repository

Repository-specific context for `Venworks Customizable HUD`. Unconfigured external services affect only work that needs them. These are repository-owned settings, with no global policy discovery or override system.

## Repository and Tool Chain

| Setting | Value |
| --- | --- |
| Project name | `Venworks Customizable HUD` |
| Repository URL | `https://github.com/monster-cookie/venworks-honkcore-ta-ui` |
| Target game | `Starfield` |

Use the current checkout as the repository path. Verify its remote against the configured repository before publishing. Keep machine-specific paths and secrets in protected local configuration, outside the repository.

The repository targets Starfield through five Canvas consumer variants. [Tools/sharedConfig.ps1](../../Tools/sharedConfig.ps1) owns variant configuration. The unreleased XML runtime and PS5 diagnostic pipeline have been removed. Inspect scripts and their side effects before executing them.

## Canvas dependency

[Venworks Canvas](https://github.com/monster-cookie/venworks-canvas) owns the shared HUD host, provider subscriptions, event transport, consumer lifecycle, and HTML/CSS renderer. VWHUD owns its consumer, themes, derived presentation state, status publisher, and packages. Read Canvas's own repository guidance before changing it; resolve its checkout independently rather than recording a machine-specific path here.

The five variants are VWKS, TA, FC, CF, and MIN. Consumer packages must not distribute competing Canvas-owned HUD replacements. The local `CanvasConsumer` source tree is VWHUD-owned and does not contain Canvas framework code. Canvas work belongs to the separate Venworks Canvas (VWCNVS) Linear team.
