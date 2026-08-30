# Venworks Customizable HUD: Component Library

This page explains the reusable HUD pieces available to the layout system and the display filters that control when they appear. It is a player-friendly companion to the Player Configuration Guide and the Layout Configuration Reference.

The Normal PC package exposes the main layout.xml file loose and keeps reusable files in its BA2 archives. The Fully Loose Files package exposes the complete Interface\VenworksCUI tree. Do not install both package shapes together.

## Reusable HUD sections

Reusable sections are XML fragments placed from the `<includes>` block in `Interface\VenworksCUI\layout.xml`. Each section has its own file under `Interface\VenworksCUI\components`.

| Section ID | File | What it shows |
|---|---|---|
| faction-display | faction-display.xml | The selected theme's faction crest. This is branding, not the player's live faction. The four themed variants include it; Minimalist does not. |
| contact-radar | contact-radar.xml | A passive 360-degree radar for contacts Starfield has already delivered to the HUD. |
| quest-tracker | quest-tracker.xml | The currently tracked objective. |
| environmental-hazard-scanner | environmental-hazard-scanner.xml | Planet, location, local time, protection, and modeled exposure information. |
| player-status-scanner | player-status-scanner.xml | Level, experience, health, oxygen, CO2, boost, carry mass, credits, digipicks, and time. |
| equipment-rail | equipment-rail.xml | Favorite slots plus live weapon, explosive, ammunition, and power information. |
| helmet-awareness | helmet-awareness.xml | Compass heading, threat state, and status effects. The vehicle-exit control is a separate root-level group in `layout.xml`. |
| scanner-overlay | scanner-overlay.xml | A scanner-only forward view with up to five validated contacts. |

The equipment rail is included in the four themed variants and is intentionally omitted from Minimalist. Minimalist also omits the faction display. Ship UI remains outside the current configurable on-foot HUD.

## Placement filters

Every reusable section and most components can use these settings:

| Setting | What it does |
|---|---|
| visible="true" or "false" | `true` allows the item to appear and `false` forces it hidden. When `true`, the item still has to pass its `visibleWhen` condition. |
| visibleWhen="always" | Always allow the item to appear. |
| visibleWhen="never" | Always hide the item. |
| visibleWhen="inScanner" | Show only while the hand scanner is open. |
| visibleWhen="inCombat" | Show only during combat. |
| visibleWhen="weaponAiming" | Show only while aiming a weapon. |
| visibleWhen="firstPerson" | Show only in first-person view. |
| visibleWhen="hudVisible" | Follow the regular HUD-visible state. |
| visibleWhen="hudOpacityPercentage >= 50" | Use a numeric HUD state comparison. |

Conditions can combine states with AND, OR, NOT, parentheses, and numeric comparisons: =, !=, <>, <, <=, >, and >=. Names ignore capitalization and underscores. Unknown values fail closed and remain hidden.

Conditions are limited to 256 characters, 64 tokens, and 8 levels of nesting. Arbitrary scripts, method calls, class names, or unlisted provider values are not supported.

## Basic building blocks

| Component | Use |
|---|---|
| group | Holds children and applies position, size, scale, rotation, opacity, visibility, and draw order. |
| text | Displays fixed text or a supported live value. |
| panel | Draws a rectangular background and outline. |
| shape | Draws supported rectangles and ellipses with fill and outline settings. |
| divider | Draws a horizontal, vertical, or diagonal line. |
| mask | Clips children to a supported rectangle, ellipse, or path. |
| meter | Displays a bounded value such as health, oxygen, CO2, boost, or progress. |
| svg | Displays approved local SVG artwork. |
| path | Displays supported inline vector path data. |
| icon | Displays one of the built-in HUD icons. |
| symbol | Displays an approved Bethesda HUD symbol. |
| providerSymbol | Displays a supported symbol supplied by Starfield. |

Most components support x, y, width, height, anchor, scaleX, scaleY, rotation, opacity, visible, visibleWhen, and z. IDs must be unique, start with a letter, use letters, numbers, dots, underscores, or hyphens, and be no longer than 64 characters.

## Reusable composition components

| Component | What it does |
|---|---|
| definitions and template | Store a bounded reusable component arrangement. Up to 64 templates are allowed. |
| instance | Places a template with supported position, value, meter, and visibility overrides. |
| repeater | Repeats a fixed declared item collection vertically, horizontally, or in a grid. Up to 64 items are allowed. |
| state | Chooses one of up to 16 fixed display choices. |
| override | Changes supported properties on a bounded instance. |
| button | Combines a panel or shape, icon, label, key hint, enabled/selected state, and cooldown or quantity overlay. |
| quickBar | Places up to 16 supported favorite or ability buttons. |
| informationPanel | Displays a title, key/value information, dividers, and optional overflow indicator. |
| warning | Displays severity color, icon, title, detail, and visibility rules. |

These components do not add new game input, persistent state, arbitrary code, or unrestricted data access.

## Meter family

All meter styles use a bounded value and maximum plus size, colors, opacity, style, position, visibility, and draw-order settings. Values are clamped from zero through the maximum.

| Style | Good for |
|---|---|
| Continuous bar | Health, oxygen, boost, enemy health, ship values, and other linear values. |
| Segmented rectangles | Discrete or stepped values. |
| Dots or circles | Compact counters and alternate meter styles. |
| Stacked triangles | Technical segmented meters with directional or alternating segments. |
| Radial or circular arc | Compact gauges, cooldowns, oxygen/CO2, and progress. |

A meter can use up to 64 segments, dots, or triangles. Chevrons/notches, image-masked meters, and bipolar center-origin meters are not supported in the current configurable release.

## Text placeholders and live values

Text can use a fixed value, one supported live source, or a bounded value template. Templates can use 1 through 8 variables and only the formats provided by the runtime. A text element uses either source or valueTemplate, not both. Its value is the fallback shown while live data is unavailable.

Live source names ignore capitalization and underscores. Dots remain part of the name. The complete placeholder list is below.

| Placeholder | Type | What it shows |
|---|---|---|
| `boost.charge` | Numeric | Current boost charge. |
| `boost.percentage` | Numeric | Boost charge as a percentage. |
| `carry.current` | Numeric | Current carry mass. |
| `carry.maximum` | Numeric | Carry-mass capacity. |
| `carry.percentage` | Numeric | Carry mass as a percentage of capacity. |
| `credits` | Numeric | Player credits. |
| `diagnostic.activityEnvelope` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.activityLoads` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.activityOxygen` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.activityProtection` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.armorResistance` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.effect0` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.effect1` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.effect2` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.effect3` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.environmentCandidates` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.environmentFields` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.environmentProvider` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.inventoryProvider` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.localEnvironmentFields` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.playerFields` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.playerIdentifiers` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.playerTargets` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.playerTimeInventory` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.powerNameProvider` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `diagnostic.starmapProvider` | Diagnostic | Troubleshooting output; not stable player-facing HUD content. |
| `environment.fullSoakAlertCandidate` | Boolean | Whether Bethesda reports a possible full-suit-soak alert. |
| `environment.gravity` | Numeric | Current local gravity. |
| `environment.hazard.airWaterExposureLevel` | Numeric | Modeled air/water exposure after protection, oxygen activity, and interpolation are applied; normally a value from 0 through 1. |
| `environment.hazard.airWaterLevel` | Numeric | Whether this environmental hazard category is active, as 0 or 1. |
| `environment.hazard.airWaterShortStatus` | String | Airborne or water-related hazard status. |
| `environment.hazard.airWaterStatus` | String | Airborne or water-related hazard status. |
| `environment.hazard.corrosiveExposureLevel` | Numeric | Modeled corrosive exposure after protection and interpolation are applied; normally a value from 0 through 1. |
| `environment.hazard.corrosiveLevel` | Numeric | Whether this environmental hazard category is active, as 0 or 1. |
| `environment.hazard.corrosiveShortStatus` | String | Corrosive hazard status. |
| `environment.hazard.corrosiveStatus` | String | Corrosive hazard status. |
| `environment.hazard.effectCount` | Numeric | Number of active environmental hazard effects. |
| `environment.hazard.radiationExposureLevel` | Numeric | Modeled radiation exposure after protection and interpolation are applied; normally a value from 0 through 1. |
| `environment.hazard.radiationLevel` | Numeric | Whether this environmental hazard category is active, as 0 or 1. |
| `environment.hazard.radiationShortStatus` | String | Radiation hazard status. |
| `environment.hazard.radiationStatus` | String | Radiation hazard status. |
| `environment.hazard.thermalExposureLevel` | Numeric | Modeled thermal exposure after protection and interpolation are applied; normally a value from 0 through 1. |
| `environment.hazard.thermalLevel` | Numeric | Whether this environmental hazard category is active, as 0 or 1. |
| `environment.hazard.thermalShortStatus` | String | Thermal hazard status. |
| `environment.hazard.thermalStatus` | String | Thermal hazard status. |
| `environment.localTime` | Numeric | Current local planetary time. |
| `environment.oxygenPercentage` | Numeric | Current environmental oxygen percentage. |
| `environment.protectionLevel` | Numeric | Current suit-protection level. |
| `environment.protectionPercentage` | Numeric | Suit protection as a percentage. |
| `environment.protectionStatus` | String | Suit protection status text. |
| `environment.soakCandidate` | Numeric | Bethesda's raw `fSoakDamagePct` value. This is different from the Boolean `environment.fullSoakAlertCandidate` and from the modeled exposure values. |
| `environment.solarTransitionCountdown` | String | Time remaining until the local solar transition. |
| `environment.temperature` | Numeric | Current local temperature. |
| `favorite.01.detail` | String | Favorite item detail or quantity; replace 01 with slots 01 through 12. |
| `favorite.01.hotkey` | String | Favorite keyboard or controller key; replace 01 with slots 01 through 12. |
| `favorite.01.name` | String | Favorite item display name; replace 01 with slots 01 through 12. |
| `location.name` | String | Current location name. |
| `player.carbonDioxide` | Numeric | Current player CO2 value. |
| `player.carbonDioxidePercentage` | Numeric | Player CO2 as a percentage. |
| `player.digipicks` | Numeric | Number of available digipicks. |
| `player.health` | Numeric | Current player health. |
| `player.healthPercentage` | Numeric | Player health as a percentage. |
| `player.level` | Numeric | Player level. |
| `player.levelXP` | Numeric | Player experience at the current level. |
| `player.maxHealth` | Numeric | Maximum player health. |
| `player.maxOxygen` | Numeric | Maximum player oxygen. |
| `player.nextLevelXP` | Numeric | Experience required for the next level. |
| `player.oxygen` | Numeric | Current player oxygen. |
| `player.oxygenPercentage` | Numeric | Player oxygen as a percentage. |
| `player.serial` | String | The HUD's deterministic player serial. |
| `player.universalTime` | Numeric | Current universal time. |
| `player.xpPercentage` | Numeric | Player experience progress as a percentage. |
| `power.cooldown` | Numeric | Power cooldown. |
| `power.cost` | Numeric | Power cost. |
| `power.current` | Numeric | Current power charge or value. |
| `power.hasSpell` | Boolean | Whether a Starborn power is currently available. |
| `power.key` | String | The current power's key or identifier. |
| `power.maximum` | Numeric | Maximum power charge or value. |
| `power.name` | String | The current Starborn power name. |
| `power.percentage` | Numeric | Power charge as a percentage. |
| `quest.objective` | String | The currently selected tracked objective. |
| `weapon.ammoAsPercent` | Boolean | Whether ammunition is represented as a percentage. |
| `weapon.ammoType` | String | The current weapon's ammunition type. |
| `weapon.clipAmmo` | Numeric | Ammunition in the current weapon's clip. |
| `weapon.displayAmmo` | Boolean | Whether the current weapon has an ammunition display. |
| `weapon.explosiveCount` | Numeric | Current explosive count. |
| `weapon.explosiveLabel` | String | The current explosive category label. |
| `weapon.explosiveType` | Numeric | Current explosive category as a numeric value. |
| `weapon.icon` | String | The current weapon icon source. |
| `weapon.name` | String | The current weapon name. |
| `weapon.reserveAmmo` | Numeric | Reserve ammunition for the current weapon. |
| `weapon.totalAmmo` | Numeric | Total ammunition associated with the current weapon. |

Diagnostic placeholders are intended for troubleshooting rather than stable player-facing HUD content. An allowlisted source can still be unknown until Starfield publishes usable data.

## Icons, symbols, and artwork

Built-in icons include health, oxygen, CO2, shield, armor, weapon, aiming, ship, vehicle, fuel, cargo, scanner, stealth, warning, objective, jolly-roger, death, poison, burning, electrocution, and disease.

Approved Bethesda symbols include environment-alert, quest-door-marker, boost-fill, and vehicle-exit-prompt. Availability can depend on the normal or large HUD movie.

Local SVG artwork is restricted to svg, g, path, rect, circle, ellipse, line, polyline, and polygon. SVGs allow up to 256 elements and 16 nesting levels. Text, images, CSS, scripts, animation, filters, masks, network access, external references, and arc path commands are unsupported. PNG, JPEG, DDS, and external SWF files are not supported.

## Bethesda display filters

The optional `<vanillaVisibility>` block can control only these whole Bethesda HUD groups:

| Target ID | Bethesda display |
|---|---|
| topCenter | Top-center HUD group |
| bottomLeft | Watch/environment group |
| rightMeters | Right-side meters |
| socialCommandIcons | Social command icons |
| floatingQuestMarkers | Floating quest markers |
| crewBuffWidget | Crew buff widget |

Use visibleWhen="never" to hide one:

~~~xml
<vanillaVisibility>
  <target id="bottomLeft" visibleWhen="never" />
  <target id="rightMeters" visibleWhen="never" />
</vanillaVisibility>
~~~

To move one relative to its Bethesda position, use offsetX and offsetY together. To place it absolutely, use x, y, and anchor together. Do not mix those placement styles.

These filters respect Starfield's own HUD mode and opacity. They cannot make an engine-hidden display appear. They also do not replace Bethesda-owned enemy health, legendary-state, stealth, hit-indicator, reticle, or crosshair behavior.

## Global limits

| Resource | Limit |
|---|---:|
| Root includes | 16 |
| Fragment or palette size | 65,536 characters |
| Templates | 64 |
| Resolved components | 512 |
| Repeater items | 64 |
| Grid columns | 16 |
| State choices | 16 |
| Quick-bar buttons | 16 |
| Information-panel items | 20 |
| Information-panel rows | 12 |
| Status-effect items | 16 |
| Meter parts | 64 |
| Scanner targets | 5 |
| Text-template variables | 8 |
| Inline path data | 8,192 characters |

## Troubleshooting

The configurable HUD loads as one complete layer. An invalid component, filter, reference, source, or asset prevents a partial load and produces a categorized diagnostic.

Fix the first reported problem, fully restart Starfield, and test normal, aiming, scanner, combat, vehicle, large-HUD, and target-aspect-ratio states. Keep schemaVersion="1" and runtimeVersion="1" unchanged.

If a change needs a component or data source not listed here, it is outside the supported configuration contract and requires a purpose-built runtime change rather than a layout edit.
