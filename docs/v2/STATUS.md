# Server-Host V2 status

Last updated: 2026-08-18.

## Current state

```text
active workflow: V2 Gate 1.5 diagnostic UI and Sideloadly injection artifact
workflow state: failed-under-investigation
next action: preserve failed source/artifact, correct hierarchy/input/first-frame observability and build one new Gate 1.5 artifact
Gate 2 state: not started
device state: user reports icon visible but no visible menu after tap for exact build .1
Legacy state: archived evidence only; it cannot block V2 without an explicit Legacy investigation request
```

## Failure intake `V2-G1.5-SIDELOAD-FAIL-001`

Exact pre-injection identity:

```text
protocol: PLAN-G1.5-SIDELOAD-001
build ID: gate1.5-diagnostic-ui-20260818.1
dylib SHA-256: 780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b
observed: floating V2 icon appears; tapping it opens no visible menu
expected: visible Status/Logs diagnostic panel
```

Established facts are deliberately separate:

- dylib startup/UI bootstrap is live enough to install the icon;
- visible menu opening is contradicted;
- Metal rendering, touch routing, Logs/Copy logs, Close and closed-view pause are
  not validated by this result.

No device model, OS/runtime, reproducibility count, console log or screenshot
was supplied. The failed dylib, manifest, dSYM and archive package remain
preserved at the paths and hashes below. The exact failed source state is to be
recorded as tag `v2-gate1.5-sideload-fail-001` before correction.

Gate 1.5 keeps every UE/runtime capability fail-closed while making the refusal
visible. The scene-safe UIKit button is requested on the main thread from
application/scene/window lifecycle events. Missing windows receive at most 20
quarter-second retries per lifecycle opportunity. Missing identity,
unsupported profile and Legacy guard refusal still present the icon.

The open transparent Metal/ImGui panel renders only an immutable diagnostic
snapshot and contains exactly `Status`, `Logs`, `Copy logs` and `Close`. The
closed `MTKView` is paused with set-needs-display mode, so it has no continuous
30 FPS draw loop. Touches outside the floating button and open ImGui window pass
through. No UI file includes UE, Bindings, Hooks, Runtime, Legacy source or
`HostingRuntime`.

## Static and artifact result

- 96 host-local assertions passed: the prior Gate 1 foundation plus logger
  bounds/redaction/concurrency, immutable snapshot and refusal-presentation
  cases.
- `BoundaryAudit.sh` passed UI include/source isolation and render/runtime
  exclusions.
- iOS arm64 compiled with local ImGui core/Metal backend and declared Apple
  frameworks UIKit, Foundation, QuartzCore, Metal and MetalKit.
- Package and raw injection audits passed; the injection dylib contains no named
  Legacy/gameplay strings or exported symbols.
- Dylib and dSYM UUIDs match.
- Strongest runtime claim for `.1`: bootstrap/icon installed; visible panel
  opening is **contradicted**. The earlier compile/static claims remain valid.

Build ID: `gate1.5-diagnostic-ui-20260818.1`

Git baseline revision: `a8defbc9f37ed17e54f30b88f715a5ea238ff667`

Build source-tree state: `modified` (the task's uncommitted implementation;
artifact bytes are fixed by SHA-256/UUID).

- Canonical injectable dylib:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.1/ServerHostV2.dylib`
- Dylib SHA-256:
  `780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b`
- Mach-O UUID:
  `A4313EC9-3901-3EFC-BC54-5A910DA4F514`
- Matching dSYM:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.1/ServerHostV2.dylib.dSYM`
- Injection manifest:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.1/manifest.txt`
- Manifest SHA-256:
  `9dbd094744753448416a40a8d29c121c9337f05d6a887f5350d2ee84d6c9cbc2`
- Archival `.deb`:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/com.mhga.serverhost.v2_0.1.2~gate1.5.20260818.1_iphoneos-arm.deb`
- Package SHA-256:
  `f5e0503e72e9d027e851884743d3279b8603d4f6732b1a605d5efa2744099348`

The failed raw dylib is byte-identical to the final dylib extracted from the `.deb`.
Sideloadly may re-sign it; the manifest identifies the input before injection.
Codex built and inspected the `.deb` but did not install it.

## Exact next action and exclusions

Create one corrected and instrumented Gate 1.5 build from the recorded failed
source state. The correction must validate/reorder the view hierarchy, separate
tap from drag, explicitly request the first frame, record bounded presentation
stages, provide a visible UIKit failed-stage fallback and use the approved
compact dark cyan/teal Status/Logs layout. It then receives a new bounded device
protocol before any Gate 2 implementation begins.

No loaded-image/FNamePool/GUObjectArray/Engine/World discovery, hook,
`ProcessEvent`, native engine call, host/client flow, scheduler, resolver or
mutation exists in this artifact. Gate 2 remains explicitly unstarted.
