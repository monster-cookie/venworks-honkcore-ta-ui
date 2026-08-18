# Documentation authority and navigation

## Source of truth

The Codecks `Documentation` deck is the product and game-design source of
truth for Venworks Customizable UI. Its doc cards own product intent,
player-facing behavior, UI state rules, scope boundaries, design decisions,
and acceptance criteria.

Codecks feature/hero cards own delivery state and connect design documents to
implementation tasks and bugs.

Repository documentation owns technical contracts, provider mappings, build
and staging procedures, diagnostic evidence, known limitations, and historical
implementation findings.

When historical planning prose in this repository conflicts with a current
Codecks Documentation card, the Codecks document controls product intent and
acceptance. Live-tested runtime contracts remain authoritative technical
evidence until deliberately superseded.

## Codecks design documents

The `Documentation` deck contains:

- `GDD Index and Documentation Model`
- `Product Vision and UI Surface Ownership`
- `CUI Runtime, Configuration, and Responsive Layout`
- `Chronomark and Player Data`
- `Environmental Hazards and Scanner Data`
- `GDD: Tactical Equipment Rail`
- `GDD: Contact Radar and Faction Display`
- `Helmet Awareness: Compass, Threat, and Active Effects`
- `Player HUD View States: Normal, Aiming, and Scanner`
- `Palette and Theme System`
- `Packaging, UI Scale, and Release`
- `GDD: Ship UI Configurability`

## Repository technical references

- `BUILDSYSTEM.md` is the build, Scaleform-domain, and staging contract.
- `COMPONENT_CATALOG.md` is the technical component and binding catalog.
- `GOAL_0_DISCOVERY.md` through `GOAL_9_HELMET_COMPASS_THREAT.md` preserve
  discovery, provider evidence, implementation contracts, validation results,
  incidents, limitations, and rollback information.
- `reference/` contains clean-room behavioral and visual reference material;
  it is not implementation source.

The historical `CUSTOM_VUI_IMPLEMENTATION_PLAN.md` is retained as the original
roadmap baseline but is no longer the active product plan.
