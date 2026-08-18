# Server-Host V2 status

Last updated: 2026-08-18.

## Current state

```text
active workflow: V2 Gate 1.5 diagnostic UI and Sideloadly injection artifact
workflow state: failed-under-investigation
next action: execute PLAN-G1.5-SIDELOAD-002 against the corrected immutable artifact
Gate 2 state: not started
device state: .1 opening failed; corrected .2 is ready for device test and is not device-verified
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
preserved at the paths and hashes below. Its exact source state is commit
`97a3cbd3a2c3a19f46a633db72d540837ea8d30c`, tagged
`v2-gate1.5-sideload-fail-001`.

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

## Corrected static and artifact result

- 143 host-local assertions passed, including logger bounds/redaction,
  immutable snapshot/refusal presentation and the bounded presentation state
  machine/timeout/fallback transitions.
- `BoundaryAudit.sh` passed UI include/source isolation and render/runtime
  exclusions.
- iOS arm64 compiled with local ImGui core/Metal backend and declared Apple
  frameworks UIKit, Foundation, QuartzCore, Metal and MetalKit.
- Package and raw injection audits passed; the injection dylib contains no named
  Legacy/gameplay strings or exported symbols.
- Dylib and dSYM UUIDs match.
- The corrected source revalidates/reattaches/reorders overlay then button,
  separates taps from drags, explicitly drives the first frame, records bounded
  frame stages, and shows a UIKit failed-stage fallback.
- Strongest claim for `.2`: compiled/statically validated and ready for device
  test. No UIKit/Metal/device success is claimed.

Build ID: `gate1.5-diagnostic-ui-20260818.2`

Clean source revision: `8fb09e654466b07b534a3dd16b2618e789d84777`

Source tag: `v2-gate1.5-diagnostic-ui-20260818.2-source`

- Canonical injectable dylib:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/ServerHostV2.dylib`
- Dylib SHA-256:
  `4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32`
- Mach-O/dSYM UUID:
  `4D308F3A-41F6-392C-9C0C-D2384DAFB889`
- Matching dSYM:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/ServerHostV2.dylib.dSYM`
- Injection manifest:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/manifest.txt`
- Manifest SHA-256:
  `6aea8368b71e74363f9c5e3c4faf95d943c24d744d208dc8d7a9d319f770b9e7`
- Archival `.deb`:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/com.mhga.serverhost.v2_0.1.3~gate1.5.20260818.2_iphoneos-arm.deb`
- Package SHA-256:
  `646798a6c880767146d8c32b068a972e39deafb87ecd5c3e0aedabb9602423ee`

The raw dylib is byte-identical to the inspected package payload. The manifest
identifies the clean input bytes before any Sideloadly re-signing. Codex built
and inspected the `.deb` but did not install it.

## Preserved failed artifact `.1`

Strongest runtime claim for `.1`: bootstrap/icon installed; visible panel
opening is **contradicted**. Its earlier compile/static claims remain valid.

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

Execute `PLAN-G1.5-SIDELOAD-002` with only corrected build `.2`. A visible UIKit
fallback is useful failed-stage evidence but is not PASS. Gate 1.5 remains
`failed-under-investigation` until the styled panel, touch/navigation/copy,
close/reopen and closed-render behavior pass on the user's device.

No loaded-image/FNamePool/GUObjectArray/Engine/World discovery, hook,
`ProcessEvent`, native engine call, host/client flow, scheduler, resolver or
mutation exists in this artifact. Gate 2 remains explicitly unstarted.
