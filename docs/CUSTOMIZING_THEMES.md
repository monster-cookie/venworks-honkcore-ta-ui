# Customizing themes

You can recolor, move, or hide parts of Venworks Customizable HUD on PC. The five themes are Venworks, Trackers Alliance, Freestar Collective, Crimson Fleet, and Minimalist.

Xbox and PlayStation play the theme as it was published. The steps below are for a PC install from Nexus Mods.

## What to install first

Enable these in this order:

1. Venworks Core Utilities 2.1.8 or newer.
2. Venworks Canvas 1.0.4 or newer.
3. One HUD theme.

Turn off any older copy of this HUD before you enable the new one. If an old copy left loose files behind, remove those too. A disabled plugin can still leave old files in the way.

You do not need the Canvas Example.

## Which Nexus download to use

**Normal** is the one most people want. It installs the theme plugin and one archive. Use it for playing, and for color and layout changes that live in a small style file.

**Fully Loose Files** unpacks the theme's pictures and pages into normal folders. Use it when you want to change the art or the page layout itself. Install Normal or Fully Loose, not both.

## Where your theme lives

| Theme | Folder under the game's `Data` directory |
| --- | --- |
| Venworks | `Interface/VenworksCanvas/Consumers/venworks.vwhud.vwks/` |
| Trackers Alliance | `Interface/VenworksCanvas/Consumers/venworks.vwhud.ta/` |
| Freestar Collective | `Interface/VenworksCanvas/Consumers/venworks.vwhud.fc/` |
| Crimson Fleet | `Interface/VenworksCanvas/Consumers/venworks.vwhud.cf/` |
| Minimalist | `Interface/VenworksCanvas/Consumers/venworks.vwhud.min/` |

## Change colors, size, and placement

Every theme reads a file named `vwhud-overrides.css` last. The Normal download keeps a blank copy inside the archive.

Make a separate mod that contains only your copy of that file, and load the mod after the HUD. A Venworks example looks like this:

```text
Interface/
  VenworksCanvas/
    Consumers/
      venworks.vwhud.vwks/
        vwhud-overrides.css
```

This example turns the main accent gold and nudges the radar. Positions use a 1920 by 1080 layout. The game scales that layout to your screen.

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

To hide the equipment rail, use [Removing the equipment rail](REMOVING_EQUIPRAIL.md). The short version is:

```css
.vwhud-panel-equipment {
  display: none;
}
```

These names are safe to keep using after updates:

- `.vwhud-panel-faction` and `.vwhud-panel-equipment` on the four full themes.
- `.vwhud-panel-radar`, `.vwhud-panel-objective`, `.vwhud-panel-environment`, `.vwhud-panel-player`, `.vwhud-panel-compass`, `.vwhud-panel-threat`, `.vwhud-panel-effects`, `.vwhud-panel-scanner-hash`, and `.vwhud-panel-scanner-data` on every theme.
- `.vwhud-alert-critical-health` and `.vwhud-prompt-vehicle-exit`.
- `.vwhud-theme-venworks`, `.vwhud-theme-trackers-alliance`, `.vwhud-theme-freestar-collective`, `.vwhud-theme-crimson-fleet`, or `.vwhud-theme-minimalist` on the whole page.

Names such as `.themed-node-4` belong to the generated layout. They can change when the theme is rebuilt. Use the `vwhud-panel` names in a style you want to keep.

## Change the art or the page

The Fully Loose download is the one to edit for that. Keep your edits in their own mod when you can. Updating the HUD can replace files that sit in the HUD's own folder.

| File | What it is |
| --- | --- |
| `vwhud-overrides.css` | Your colors, placement, text size, and hidden panels. Loaded last. |
| `venworks.css`, `trackers-alliance.css`, `freestar-collective.css`, `crimson-fleet.css`, or `starfield.css` | The theme's colors. |
| `themed-layout.css` or `minimalist-layout.css` | The shipped sizes and positions. Edits here are easy to lose on update. |
| `themed.html` or `minimalist.html` | The main page. |
| `themed-*.html` and `minimalist-*.html` | Each panel. |
| `assets/*.svg` | Icons and logos. |
| `normal.swf` and `large.swf` | The theme program. Changing those means a full rebuild. |
| The plugin and script files | Same. Leave them unless you are rebuilding the mod. |

Leave `data-vw-*` names in place. Those names are how the page receives health, location, and the rest of the live info.

Canvas draws a simpler page than a web browser. A few habits keep a custom page on screen:

- Start every page, including each panel file, with `<!doctype html>` in lowercase letters.
- Write tag names in lowercase.
- Write `currentcolor` in lowercase.
- Give the page body `position: relative` so the panels have a box to sit in.

The [Canvas Component Gallery](https://github.com/monster-cookie/venworks-canvas/blob/master/Documentation/CanvasComponentGallery.md) shows which tags and styles work. [Create a Canvas plugin from scratch](https://github.com/monster-cookie/venworks-canvas/blob/master/Documentation/CreatingACanvasPlugin.md) is for a brand-new Canvas mod, not for recoloring this HUD.

## See the change, or go back

Quit Starfield completely, then start it again. The HUD reads these files at startup.

After you update Canvas or the HUD, start once with your override mod turned off. When the plain theme looks right, turn the override back on and check anything you moved or recolored.

To restore the default look, disable or delete the override mod. On a Fully Loose install, reinstall the clean package. The theme files come from the HUD download, not from the Canvas download.

## If the HUD says the versions do not match

You may see **UNSUPPORTED CONSUMER PROTOCOL** on the Canvas screen. The Papyrus log may also say `Venworks:Canvas:Registry.BuildCanvasDatagramBody` does not exist.

Quit Starfield completely. In your mod manager, check that Canvas is 1.0.4 or newer, this HUD is the current theme, and you do not have two copies of either mod. Look for leftover loose files under `Interface` and `Scripts` from an older install. Deploy again, then start the game fresh.
