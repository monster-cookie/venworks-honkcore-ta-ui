# Removing the equipment rail

The equipment rail is the tall panel on the right of the four full themes. It shows your favorites, weapon, ammo, explosives, and powers. Minimalist does not include this panel.

This is a PC change. Xbox and PlayStation use the theme as it was published.

Quit Starfield all the way, including the launcher, before you add or remove the file. Start the game again when you are done. A reload inside the game will not pick up the new file.

## Hide it with a small style file

This is the easiest way. The rest of the theme stays in the archive you installed.

1. Create a new empty mod in Vortex or Mod Organizer 2, and load it after Venworks Customizable HUD.
2. Inside that mod, create the folder for the theme you play. The folders are listed in [Customizing themes](CUSTOMIZING_THEMES.md).
3. In that folder, add a text file named `vwhud-overrides.css` with these lines:

```css
.vwhud-panel-equipment {
  display: none;
}
```

4. Deploy the mod and start Starfield. The rail is hidden. Delete the file, or disable the mod, to bring it back.

## Take the panel out of the theme file

Use this when you want the theme to stop loading the rail.

1. Open the theme page on GitHub and save the file:

https://github.com/monster-cookie/venworks-honkcore-ta-ui/blob/master/CanvasConsumer/resources/themed.html

Use **Download raw file**, or open **Raw** and save the page as `themed.html`. Keep that exact name.

2. Open `themed.html` in Notepad. Delete this whole line, and leave the lines around it:

```html
<vw-include src="themed-equipment-rail.html"></vw-include>
```

3. Save the file. Put only this `themed.html` in your theme folder, in a mod that loads after Venworks Customizable HUD:

| Theme | Folder under the game's `Data` directory |
| --- | --- |
| Venworks | `Interface/VenworksCanvas/Consumers/venworks.vwhud.vwks/` |
| Trackers Alliance | `Interface/VenworksCanvas/Consumers/venworks.vwhud.ta/` |
| Freestar Collective | `Interface/VenworksCanvas/Consumers/venworks.vwhud.fc/` |
| Crimson Fleet | `Interface/VenworksCanvas/Consumers/venworks.vwhud.cf/` |

If you already installed the **Fully Loose Files** package, edit the `themed.html` that package placed in that same folder. You can skip the GitHub download.

4. Start Starfield. The right-side loadout panel is gone. Compass, player, planet, mission, radar, and status icons stay.

After a HUD update, download `themed.html` again and remove that same line. An old copy can miss new panels from the update.

To restore the rail, delete your loose `themed.html` and start the game again. The installed theme supplies the original page.
