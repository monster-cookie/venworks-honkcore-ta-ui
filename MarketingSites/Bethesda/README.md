# Bethesda Creations Publication Handoff

This directory contains the publication copy for the five Venworks Customizable
HUD Creations. `ListingMetadata.md` contains each listing's title, tagline, and
description source. Each Creation file contains only the description Markdown
so its complete contents can be copied directly into a Bethesda Creation
listing.

## Description renderer contract

Bethesda's current website renderer uses Markdown-it with named links and image
rules disabled. Raw HTML is escaped. The Creation descriptions therefore use
only:

- `#` and `##` headings;
- plain paragraphs;
- `**bold**` emphasis;
- `-` bulleted lists;
- numbered lists;
- backticks for inline code; and
- plain URLs.

Do not use raw HTML, `![image](URL)`, `[label](URL)`, blockquotes, or
angle-bracket autolinks in a Creation description. Remote description images
are unsupported. Upload the overview bar and other release images through
Bethesda's supported preview or gallery image surfaces instead.

Bethesda applies description markup on the website only. The in-game Creation
description may show the Markdown characters as plain text, so the copy keeps
formatting restrained and remains understandable without rendered markup.

## Creation files

| Public Creation title | Description source | Starting palette |
| --- | --- | --- |
| Venworks Customizable HUD - Venworks Theme | `Venworks-Theme.md` | `venworks.xml` |
| Venworks Customizable HUD - Trackers Alliance Theme | `Trackers-Alliance-Theme.md` | `trackers-alliance.xml` |
| Venworks Customizable HUD - Freestar Collective Theme | `Freestar-Collective-Theme.md` | `freestar-collective.xml` |
| Venworks Customizable HUD - Crimson Fleet Theme | `Crimson-Fleet-Theme.md` | `crimson-fleet.xml` |
| Venworks Customizable HUD - Minimalist | `Minimalist.md` | Literal Starfield colors; no palette file |

## Before publication

1. Merge and tag the release, then use that tag as the public version. The copy
   deliberately contains no guessed version number.
2. Confirm that each of the four themed Creations has separate PC, Xbox, and
   PS5 packages. Each package must contain only the root ESM, its
   platform-matching Main BA2, and any generated platform-matching Textures
   BA2. It must select the matching starting palette and include all five
   palettes inside the BA2 payload.
3. Confirm that Minimalist has only its PS5 package. It must contain only the
   root Minimalist ESM and PS5 Main BA2, with no external SVG, palette, DDS, or
   texture-archive content.
4. Supply current, unedited in-game screenshots for all five Creations. The
   `WIP_MinimalistTheme_Normal.png` and
   `WIP_MinimalistTheme_Scanning.png` files are intentional work-in-progress
   placeholders and are not final release evidence. Do not use other legacy
   screenshots under `MarketingSites\Images` as evidence without confirming
   that they show the final build.
5. Upload the overview bar through a supported Bethesda image field; do not try
   to embed its CDN URL in the description.
6. Preview the plain GitHub and Discord URLs on the website before publication.
7. Select PC and every console platform supported by each package. Minimalist
   is PS5-only in this spike.
8. Keep the release marked as beta and request console testing until every
   supported console build has direct runtime evidence.
9. Publish only the matching package to each platform under a listing, and tell
   players to enable only one HUD variant at a time because all five replace
   the same interface files.
10. Recheck every GitHub documentation link after the release reaches the
   default branch.

These files prepare copy only. They do not authorize or perform any Bethesda
upload, listing creation, package publication, or website change.
