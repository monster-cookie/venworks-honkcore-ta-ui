# Nexus Mods Listing Metadata

## Public listing

- Title: `Venworks Customizable HUD`
- Summary: `A from-scratch, XML-customizable Starfield HUD with tactical player, equipment, environment, scanner, objective, and contact-radar displays.`
- Category: `User Interface`
- Release status: `Beta`
- Version: Set only after the release branch is merged and tagged.

## Requirements and compatibility metadata

- Required mods: None.
- Remove the obsolete HONKCORE hard requirement.
- Remove the obsolete HUD Info Widget soft requirement.
- State that HONKCORE and other mods replacing `hudmenu.gfx` or
  `hudmenu_lrg.gfx` are incompatible unless a purpose-built patch combines the
  changes.
- Retain the old HONKCORE theme downloads in the Files section as legacy files.
  Do not mark them as files for the new customizable HUD, and do not tell users
  to install a legacy HONKCORE file alongside a new theme.

## New-release file display names

Each theme publishes two Nexus files:

1. `<Theme display name> - Nexus PC - Normal`
2. `<Theme display name> - Nexus PC - Fully Loose Files`

The four theme display names are:

1. `Venworks Customizable HUD - Venworks Theme`
2. `Venworks Customizable HUD - Trackers Alliance Theme`
3. `Venworks Customizable HUD - Freestar Collective Theme`
4. `Venworks Customizable HUD - Crimson Fleet Theme`

Every new-release file must select the matching starting palette and contain
all five supported palette XML files, either inside the Normal package's BA2 or
as files in the Fully Loose Files package. Assign file versions only after the
release tag exists.

## Publication prerequisites

- Confirm the eight Nexus PC archives produced by the release system: Normal
  and Fully Loose Files for each of the four themes.
- Supply current, unedited in-game screenshots that show the final build and
  correctly identify each theme.
- Confirm the release tag and use it consistently for the listing and eight new
  files.
- Keep the release labeled as beta.
- Do not remove the old HONKCORE files from the Files section.

This file is a publication handoff. It does not authorize or perform a Nexus
Mods website change, upload, or release action.
