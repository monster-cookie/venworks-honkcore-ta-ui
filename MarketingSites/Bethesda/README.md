# Bethesda Creations Publication Handoff

This directory contains the publication copy for the four Venworks Customizable
HUD Creations. `ListingMetadata.md` contains each listing's title, tagline, and
description source. Each theme file contains only the description Markdown so
its complete contents can be copied directly into a Bethesda Creation listing.

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

## Before publication

1. Merge and tag the release, then use that tag as the public version. The copy
   deliberately contains no guessed version number.
2. Confirm that every Creation has separate PC, Xbox, and PS5 packages. Each
   package must contain only the root ESM, its platform-matching Main BA2, and
   any generated platform-matching Textures BA2. It must select the matching
   starting palette and include all five palettes inside the BA2 payload.
3. Supply current, unedited in-game screenshots for all four themes. Do not use
   the legacy screenshots under `MarketingSites\Images` as evidence of this
   release without confirming that they show the final build.
4. Upload the overview bar through a supported Bethesda image field; do not try
   to embed its CDN URL in the description.
5. Preview the plain GitHub and Discord URLs on the website before publication.
6. Select PC and every console platform supported by Starfield Creations.
7. Keep the release marked as beta and request console testing until every
   supported console build has direct runtime evidence.
8. Publish only the matching package to each platform under a listing, and tell
   players to enable only one HUD theme at a time because all four replace the
   same interface files.
9. Recheck every GitHub documentation link after the release reaches the
   default branch.

These files prepare copy only. They do not authorize or perform any Bethesda
upload, listing creation, package publication, or website change.
