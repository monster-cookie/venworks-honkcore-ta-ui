# HONKCORE Venworks UI visual reference

These captures preserve the last known HONKCORE-based Venworks HUD as a visual
target for the clean-room Customizable UI implementation. They document screen
composition and behavior only. Do not use HONKCORE binaries, decompiled source,
configuration formats, or other protected implementation material as source
for the new UI.

## Captures

### HUD overview 01

![HONKCORE Venworks HUD overview 01](hud-overview-01.png)

Full first-person HUD with the scanner closed. Visible reference elements
include:

- Venworks crest, minimap/radar, suit-status label, and suit meter at top left.
- Thin compass spanning the top center.
- Vertical quick bar along the right edge.
- Equipped-weapon name, icon, magazine, reserve ammo, and ammo-type area above
  the planetary information panel.
- Planetary information panel with location, local time, atmospheric oxygen,
  temperature, gravity, survival status, active power, carry weight, and credits.
- Stacked health, oxygen, and encumbrance meters below the information panel.
- Boost meter and the TACR environmental/status panel at bottom right.
- Vanilla interaction prompt retained independently of the custom HUD.

### HUD overview 02

![HONKCORE Venworks HUD overview 02](hud-overview-02.png)

Second preserved source capture of the same first-person HUD state. This file is
byte-identical to `hud-overview-01.png`; both are retained intentionally to
preserve every supplied reference artifact.

### Scanner overview

![HONKCORE Venworks scanner overview](scanner-overview.png)

Scanner-active reference state. It shows the persistent Venworks HUD together
with scanner-specific presentation:

- Mission objective panel beneath the crest/minimap region.
- Survey completion panel and discovered fauna, flora, and resources at left.
- Scanner heading, reticle, grid, target range, and scan-progress presentation.
- Quick bar, planetary information panel, player meters, and TACR panel remaining
  visible while scanning.
- Scanner command bar across the bottom of the screen.

## Duplication notes

The screenshots are fidelity references, not pixel-perfect specifications. When
the Customizable UI duplicates these elements, their data should come from the
new provider and placeholder system, and their composition should remain driven
by the new modular XML configuration files.
