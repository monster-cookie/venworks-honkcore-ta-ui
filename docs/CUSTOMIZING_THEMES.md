# Customizing VWHUD themes

Venworks Customizable HUD uses local HTML, CSS, and SVG resources rendered by Venworks Canvas. Canvas defines the supported rendering language; VWHUD defines the five shipped themes, their panels, their data model, and the files described here.

## Requirements

Install and enable these dependencies in order:

1. Venworks Core Utilities 2.1.8 or newer.
2. Venworks Canvas 1.0.4 or newer.
3. Exactly one VWHUD theme.

Remove an earlier standalone VWHUD installation before installing a Canvas-based theme. Disabled plugins do not prevent old loose Interface files from shadowing current archives.

## Choose a PC package

The **Normal** Nexus package installs the theme's ESM and Main BA2. Use it for ordinary play and for a small CSS override installed as a separate mod.

The **Fully Loose Files** Nexus package installs the same plugin with loose Scripts and Interface resources. Use it when you need to change HTML composition or SVG artwork as well as CSS. Do not install the Normal and Fully Loose package shapes together.

Bethesda Creations packages are preconfigured archive packages for PC, Xbox, and PlayStation 5. The local-file workflow in this guide is for Nexus PC installations and mod authors.

## Find the selected theme

Canvas loads each theme from its isolated VWHUD-owned resource directory:

| Theme | Resource directory beneath the Starfield Data directory |
| --- | --- |
| Venworks | `Interface/VenworksCanvas/Consumers/venworks.vwhud.vwks/` |
| Trackers Alliance | `Interface/VenworksCanvas/Consumers/venworks.vwhud.ta/` |
| Freestar Collective | `Interface/VenworksCanvas/Consumers/venworks.vwhud.fc/` |
| Crimson Fleet | `Interface/VenworksCanvas/Consumers/venworks.vwhud.cf/` |
| Minimalist | `Interface/VenworksCanvas/Consumers/venworks.vwhud.min/` |

The directory contains VWHUD consumer files. It does not contain a private copy of the Canvas host, renderer, registry, or player HUD movies.

## Create a durable CSS override

Every theme loads `vwhud-overrides.css` after its base layout and palette. With the Normal package, create a separate mod that supplies only this file at the selected theme's exact resource path. Keep the override mod after VWHUD in the mod manager so its loose file wins over the empty copy in the VWHUD BA2.

For example, a Venworks override mod contains:

```text
Interface/
  VenworksCanvas/
    Consumers/
      venworks.vwhud.vwks/
        vwhud-overrides.css
```

This changes the main accent and moves the radar within Canvas's 1920 x 1080 design space:

```css
.color-accent-primary-1 {
  color: #ffcc33;
}

.stroke-accent-primary-1 {
  stroke: #ffcc33;
}

.vwhud-panel-radar {
  left: 40px;
  top: 24px;
}
```

This hides the equipment rail in any of the four full themes:

```css
.vwhud-panel-equipment {
  display: none;
}
```

VWHUD supplies these stable outer-panel classes:

- `.vwhud-panel-faction` and `.vwhud-panel-equipment` in the four full themes.
- `.vwhud-panel-radar`, `.vwhud-panel-objective`, `.vwhud-panel-environment`, `.vwhud-panel-player`, `.vwhud-panel-compass`, `.vwhud-panel-threat`, `.vwhud-panel-effects`, `.vwhud-panel-scanner-hash`, and `.vwhud-panel-scanner-data` in all themes.
- `.vwhud-alert-critical-health` and `.vwhud-prompt-vehicle-exit` for the shared alert and vehicle prompt.
- `.vwhud-theme-venworks`, `.vwhud-theme-trackers-alliance`, `.vwhud-theme-freestar-collective`, `.vwhud-theme-crimson-fleet`, or `.vwhud-theme-minimalist` on the root document.

Generated classes such as `.themed-node-4` and `.minimalist-node-31` describe the shipped layout and may change when the theme is regenerated. Do not use them as long-lived override selectors.

## Edit the complete theme

The Fully Loose Files package exposes the complete presentation. Back up or place your edits in a separate mod-manager project because updating VWHUD can replace files in the VWHUD module.

| File | Purpose |
| --- | --- |
| `vwhud-overrides.css` | User color, placement, size, typography, and visibility overrides loaded last. |
| `venworks.css`, `trackers-alliance.css`, `freestar-collective.css`, `crimson-fleet.css`, or `starfield.css` | Shipped theme palette. |
| `themed-layout.css` or `minimalist-layout.css` | Generated base placement and sizing. Direct edits are upgrade-sensitive. |
| `themed.html` or `minimalist.html` | Top-level composition and Canvas HUD-target suppression. |
| `themed-*.html`, `minimalist-*.html`, and shared content fragments | Individual VWHUD panels and bindings. |
| `assets/*.svg` | Packaged vector artwork and icons. |
| `normal.swf` and `large.swf` | Compiled lifecycle, registration, and view-model bridge. Source changes require a rebuild. |
| ESM and compiled PEX files | Registration quest and status publication. Source changes require a rebuild. |

Do not remove or rename a `data-vw-*` binding unless the VWHUD consumer supplies the replacement data. Do not copy Canvas framework files or host movies into a VWHUD theme.

Canvas supports a bounded subset of HTML, CSS, and SVG rather than browser HTML. Use the [Canvas Component Gallery](https://github.com/monster-cookie/venworks-canvas/blob/master/Documentation/CanvasComponentGallery.md) for supported syntax. Use [Create a Canvas plugin from scratch](https://github.com/monster-cookie/venworks-canvas/blob/master/Documentation/CreatingACanvasPlugin.md) when creating another consumer or changing registration and data ownership instead of customizing an existing VWHUD presentation.

## Apply, update, and reset changes

Exit Starfield completely after changing a theme resource, then start it again. VWHUD does not promise browser-style hot reload.

After updating Canvas or VWHUD, test the selected theme once with the override mod disabled. Re-enable the override after confirming the base theme loads, then review any selectors or properties affected by the update.

To restore the default presentation, disable or remove the separate override mod. For a Fully Loose installation, reinstall the unmodified package. Do not copy default resources out of the Canvas base package; VWHUD's theme resources come from the selected VWHUD package.
