# What the Canvas update means

Version 2.1.0 draws the HUD with Venworks Canvas. The themes are still Venworks, Trackers Alliance, Freestar Collective, Crimson Fleet, and Minimalist. They look like the same tactical helmet display, with a cleaner plate behind each panel and a shorter status area.

You need two other mods, in this order:

1. Venworks Core Utilities 2.1.8 or newer.
2. Venworks Canvas 1.0.4 or newer.

Then enable one theme. The Canvas Example is optional and this HUD does not need it.

Remove an older copy of this HUD before you enable 2.1.0. The new themes no longer replace the vanilla HUD movie. Canvas shares the screen with the game, and each theme keeps its own files.

## What you will see

- Helpful status icons sit on one line. Harmful icons use the two lines under them. A long list rotates on those lines. There is no page number and no buff count next to the threat meter.
- Heat, cold, poison, radiation, bleeding, infection, injury, corrosive damage, and gas each get one icon. Food, drink, and rest still get their own icons. A single chem, such as Fortify Carry Weight, does not get an icon.
- A new or cleared condition shows up within about a second.
- The compass uses the game's own heading marks and location icons. The contact radar is the familiar sweep. Both stay hidden if you hide that panel.
- The wristwatch and the vanilla health and ammo cluster in the lower right stay hidden.
- Health, oxygen, CO2, and boost move by bar segment. The critical-health number still updates while that warning is up.
- The full-screen visor shape is gone. Panels are a dark plate, a soft accent glow, and corner brackets, so the text stays readable over bright ground.

Minimalist keeps the smaller layout: no faction crest and no equipment rail. The other four themes still have the rail. On PC you can hide or remove it. See [Removing the equipment rail](REMOVING_EQUIPRAIL.md).

## Making it yours on PC

Colors, placement, text size, and hidden panels go in `vwhud-overrides.css`. The steps, folder names, and examples are in [Customizing themes](CUSTOMIZING_THEMES.md).

Nexus **Normal** is enough for that style file. **Fully Loose Files** is for people who want to edit the pages and art. Install one package shape, not both.

Xbox and PlayStation use the published theme. Those platforms do not pick up a loose style file.

## If something looks wrong

Quit the game completely before you test again. A disabled plugin can leave old files in charge.

If Canvas shows **UNSUPPORTED CONSUMER PROTOCOL**, the HUD and Canvas on that save are not the pair this release expects. Update Canvas to 1.0.4 or newer, remove duplicate or leftover copies, deploy, and start Starfield again. [Customizing themes](CUSTOMIZING_THEMES.md) has the same recovery in a little more detail.

The radar shows contacts Starfield has already told the HUD about. It does not find new life on its own.

For a quick look at the status icons on PC, open the console and run:

`cgf "Venworks:CustomizableHUD:HudStatusProbe.ApplyGenericSet"`

This applies one sample of each common buff and debuff. Fed and Hydrated wear off on their own. To clear the test spells, run:

`cgf "Venworks:CustomizableHUD:HudStatusProbe.ClearGenericSet"`

This release is still in beta while more people try it on large HUD mode, ultrawide screens, and consoles.
