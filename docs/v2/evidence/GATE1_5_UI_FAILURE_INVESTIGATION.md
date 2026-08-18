# Gate 1.5 UI failure investigation and presentation pattern review

Report ID: `V2-G1.5-UI-INVESTIGATION-002`  
Workflow / ABI backlog IDs: Gate 1.5 / ABI-001, ABI-026  
Date: 2026-08-18  
Failed source snapshot: commit
`97a3cbd3a2c3a19f46a633db72d540837ea8d30c`, tag
`v2-gate1.5-sideload-fail-001`  
Failed artifact: `gate1.5-diagnostic-ui-20260818.1`, SHA-256
`780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b`  
Claim before: icon observed; visible menu opening contradicted  
Claim after static investigation: hierarchy, input and first-frame defects
identified; device causality remains unverified until the corrected artifact is
tested

## Exact files read

Current V2 and Metal backend:

- `SourceV2/UI/DiagnosticUIBootstrap.mm`
- `SourceV2/UI/DiagnosticPresentationModel.hpp/.cpp`
- `ImGui/imgui_impl_metal.mm`

Legacy Server-Host presentation reference:

- `MenuLoad/MenuBootstrap.mm`
- `MenuLoad/OverlayView.mm`
- `Menu/HostMenu.mm`

Sishen presentation reference:

- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/MenuLoad/MenuLoad.mm`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/MenuLoad/ImGuiDrawView.mm`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/MenuLoad/ProcessFront.mm`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Menu/UserMenu.mm`

Dragon/ProjDragon presentation reference:

- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/MenuLoad/ImGuiDrawView.mm`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/MenuLoad/MenuLoad.mm`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/Menu/UserMenu.mm`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/ImGui/DRGui/dr_gui.h`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon/ImGui/DRGui/dr_gui.cpp`

No reference file is linked into SourceV2. The review is limited to presentation
and lifecycle patterns; gameplay code is neither interpreted as a Gate 1.5
requirement nor copied.

## Failed-code findings

### Hierarchy and z-order

`attemptInstall` returns early when the previously recorded root and button
superview still exist. That branch brings only the floating button to the front.
`toggleMenu` also changes overlay visibility and then brings only the button to
the front. Neither path validates `overlay.parentViewController`,
`overlay.view.superview`, `overlay.view.window`, the current root identity, or
places the overlay above a render view installed/reordered later.

This verifies a presentation correctness defect and supports the user's primary
hypothesis: ShooterGame can leave the button above its content while the overlay
is below it. The specific device z-order at the failed tap was not captured, so
this remains the leading causal hypothesis rather than a device-proven fact.

### Input ambiguity

The failed button listens only for `UIControlEventTouchUpInside`. Its attached
pan recognizer retains the default cancellation behavior and the code does not
distinguish a drag from a tap. There is no primary-action route for iOS-on-Mac,
no accepted-action visual state and no breadcrumb proving that the reported tap
reached `toggleMenu`.

### Silent first-frame failure

Opening switches the `MTKView` directly into continuous rendering and only calls
`setNeedsDisplay`; it does not explicitly drive the first frame after hierarchy
and layout updates. `drawInMTKView` silently returns when the render-pass
descriptor, drawable, command buffer or encoder is unavailable. No bounded
stage log or UIKit fallback distinguishes a hierarchy failure from a Metal or
ImGui failure. The local Metal backend expects a valid render-pass descriptor
for `ImGui_ImplMetal_NewFrame` and uses the command buffer device to build the
pipeline, so those prerequisites must be checked before the call.

## Adopted patterns

- From Sishen and Dragon: a transparent local `MTKView`, touch events translated
  into ImGui pointer events, and explicit separation of the floating UIKit
  control from the ImGui content surface.
- From Sishen `UserMenu::LoadOnce`: compact, readable padding and small rounding
  values instead of an untouched default ImGui style.
- From Dragon `UserMenu`: the dark cyan/teal palette family (`0x011518`,
  `0x091822`, `0x20DADA`, pale cyan text) and the visual hierarchy of a narrow
  navigation rail beside a main content child.
- From both references: active navigation needs a visibly distinct accent state.

## Adapted patterns

- The reference sidebars become two ordinary ImGui `Selectable` rows—Status and
  Logs—inside a fixed left child, with a right content child. No DRGui widget
  code is imported.
- Dragon's palette is made more opaque and restrained for diagnostic
  readability; Sishen's compact spacing/rounding is used with the existing local
  default font rather than bundled or remotely fetched fonts.
- The reference point-inside logic is reduced to one immutable current panel
  rectangle. When closed, the overlay accepts no touch; when open, only the
  visible panel accepts touch.
- Continuous Metal rendering is permitted only after a successful explicit
  first frame and only while open. Close returns to a hidden, paused,
  set-needs-display view with no render loop.
- The button accepts both touch-up and primary actions with deduplication, while
  a non-cancelling pan uses a movement threshold and suppresses the corresponding
  release action after a drag.

## Rejected patterns

- Sishen/Dragon fixed three-second startup, direct `windows[0]` ownership,
  unbounded assumptions about the root view, and always-running draw loops.
- Sishen/Dragon login, key/UDID/API, crypto/security, hide-record/secure-textfield,
  delayed authentication, network access and remote icon/logo/font downloads.
- Sishen/Dragon gameplay rendering, maps, crosshairs, switches, frame task
  managers, UE work and any render-driven scheduler/tick.
- Dragon's complete DRGui custom-widget/animation framework, composite polygon
  window, glow passes and gameplay navigation. The Gate 1.5 design uses ordinary
  ImGui primitives and only the high-level palette/layout ideas.
- Legacy `HostingRuntime::Tick`, Host/Client/administration controls, fake
  disabled controls, and every Legacy Menu/MenuLoad source dependency.

## Corrected state contract

The portable presentation state machine must cover:

```text
Detached
  -> AttachedClosed
  -> OpenRequested
  -> FirstFramePresented
  -> Open
  -> Closing
  -> AttachedClosed

OpenRequested/FirstFramePresented -> FailedWithVisibleFallback
any attached state -> Detached
```

Static tests can validate legal/illegal transitions, a bounded first-frame
deadline, fallback-stage selection and bounded diagnostic events. They cannot
claim UIKit hierarchy, button delivery, Metal drawable or rendered pixels on a
device.

## Scope and uncertainty

The correction is one Gate 1.5 presentation artifact, not speculative A/B
packages. It does not start Gate 2 and adds no UE discovery, binding, hook,
ProcessEvent, scheduler, native call, hosting, travel or mutation. A corrected
device PASS still requires visible styled pixels, working input/navigation/copy,
clean close/reopen and the bounded stability protocol.

## Corrected implementation and artifact

The one correction artifact was produced from clean commit
`8fb09e654466b07b534a3dd16b2618e789d84777`, tagged
`v2-gate1.5-diagnostic-ui-20260818.2-source`. It implements the hierarchy,
input, first-frame, diagnostic, fallback and restrained Dragon/Sishen-inspired
layout decisions above without importing reference sources.

`V2-G1.5-FIX-BUILD-005` passed 143 host assertions, the strengthened boundary
audit, iOS arm64 compile/package inspection and injectable Legacy/gameplay
symbol audit. The raw dylib SHA-256 is
`4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32`;
its Mach-O and dSYM UUID are both
`4D308F3A-41F6-392C-9C0C-D2384DAFB889`. This is compile/static/artifact
evidence only. No device hierarchy, input delivery, rendered pixel, fallback,
copy, pause or stability claim is made before `PLAN-G1.5-SIDELOAD-002`.
