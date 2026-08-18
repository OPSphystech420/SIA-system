# Production UI compatibility transfer — deferred task

State: recorded future workflow; not active in Gate 2A.

The working Gate 1.5 diagnostic panel remains the control until a separate UI
workflow is selected. Production UI must use real compatible Sishen/ProjDragon
building blocks rather than an approximate visual imitation.

## Mandatory reference files

- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/MenuLoad/ImGuiDrawView.mm`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/Resources/Fonts.h`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/Resources/Fonts/ark_font.cpp`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/ImGui/DRGui/dr_gui.h`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/ImGui/DRGui/dr_gui.cpp`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Menu/UserMenu.mm`

## Required work in that future workflow

1. Inspect and transfer the embedded `ARKFont` plus its initialization, including
   glyph ranges, merge order, atlas ownership and `FontDataOwnedByAtlas` rules.
2. Inspect the `DRGui` namespace and port only compatible, self-contained
   widgets/layout blocks.
3. Preserve useful Sishen menu/style patterns such as the sidebar/content
   hierarchy, compact style tokens and self-contained navigation composition.
4. Before transfer, verify the exact Dear ImGui version and internal/public API
   compatibility, font-data ownership/lifetime, and licensing/provenance for
   every source and embedded asset.
5. Compare against the unchanged Gate 1.5 control for open/close/touch/render
   lifecycle behavior.

## Explicit exclusions

Do not transfer login, UDID, API/authentication, crypto/security, remote
downloads/images, hide-record/anti-analysis behavior, gameplay features, hooks,
old offsets or signatures. This task is presentation-only and cannot broaden an
active runtime gate.
