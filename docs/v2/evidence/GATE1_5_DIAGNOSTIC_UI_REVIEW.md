# Gate 1.5 diagnostic UI pattern review

Report ID: `V2-G1.5-UI-REVIEW-001`  
Workflow: Gate 1.5 diagnostic UI and Sideloadly injection artifact  
Date: 2026-08-18  
Exact platform/build scope: iOS arm64 injected dylib; ShooterGame 1.10280 remains
unidentified at runtime because Gate 2 identity discovery is not part of this
workflow.

## Bounded outcome and pass/fail contract

Gate 1.5 adds a UE-free diagnostic surface to the inert Gate 1 dylib. The
floating diagnostic button must remain visible when profile validation or the
Legacy guard refuses runtime capabilities. Opening the panel may render only an
immutable diagnostic snapshot; closing it must pause the `MTKView` and stop its
continuous draw loop. Hooks, engine calls and mutation remain exactly zero.

Static PASS requires logger bound/redaction/snapshot/refusal tests, UI dependency
and source-list audits, an arm64 build, an injectable-dylib symbol audit, matching
dylib/dSYM UUIDs and an immutable artifact manifest. Device PASS is deliberately
separate and requires the exact user protocol recorded in `TEST_MATRIX.md`.

## Files read

- Sishen `MenuLoad/MenuLoad.mm`: menu loader, floating/touch buttons, drag
  handling, remote image, fixed-delay authentication and hide-record container.
- Sishen `MenuLoad/ImGuiDrawView.mm`: Metal/ImGui setup, touch-to-ImGui events,
  transparent render pass, continuous tick and background/auth behavior.
- Sishen `MenuLoad/ProcessFront.mm`: UDID/API, crypto, remote authentication and
  network response handling.
- Legacy `MenuLoad/MenuBootstrap.mm`: scene/window search, SF Symbol fallback,
  draggable button, fixed-delay startup and retry.
- Legacy `MenuLoad/OverlayView.mm`: transparent Metal backend, ImGui touch
  forwarding, always-running 30 FPS loop and render-thread `HostingRuntime::Tick`.
- Legacy `Menu/HostMenu.mm`: snapshot rendering/log colors/copy behavior plus
  direct Host/Client/administration/gameplay commands.

These sources are pattern evidence only. No Sishen or Legacy ABI, source file or
runtime dependency enters `SourceV2`.

## Adopted

- Scene-aware search through connected `UIWindowScene` instances, preferring a
  key window.
- A local UIKit floating button with an SF Symbol and a text fallback.
- Bounded drag movement clamped inside its parent view.
- Transparent `MTKView`, Dear ImGui core and the existing local Metal backend.
- UIKit touch events translated into ImGui mouse-source, position and button
  events.
- Structured severity colors and a clipboard action fed by a copied log
  snapshot.

## Adapted

- Startup is driven by application/scene/window lifecycle notifications on the
  main thread. A short bounded retry handles a temporarily missing window; it is
  not a fixed two- or three-second startup sleep.
- The full-screen overlay uses a pass-through `MTKView`: it accepts touches only
  inside the currently open ImGui window. The floating button remains a separate
  UIKit control.
- The open menu may render at a bounded UI cadence, but the closed menu sets
  `paused=YES` and `enableSetNeedsDisplay=YES`; no hidden 30 FPS loop remains.
- The render callback reads only a newly captured immutable diagnostic snapshot.
  It does not tick, schedule, resolve, inspect or mutate engine state.
- The legacy menu's status/log presentation is reduced to exactly `Status` and
  `Logs`, with only `Copy logs` and `Close` actions.

## Rejected

- Sishen login, keys, UDID collection, API calls, crypto/security gates, remote
  icon downloads, hide-record/secure-textfield behavior, delayed authentication
  and gameplay logic.
- Fixed startup sleeps, unbounded missing-window retries and direct dependence on
  `UIApplication.windows[0]`.
- Always-running Metal rendering, render-driven `Tick`, scheduling or any UE
  access.
- Legacy `HostingRuntime`, Legacy Menu/MenuLoad sources, umbrella includes and
  any Host, Client, save, administration, kick, console or disabled fake control.
- Hiding diagnostics because profile identity is missing, the build is
  unsupported or the Legacy guard refuses runtime capabilities. Fail-closed
  applies to UE/runtime capability exposure, not to diagnostic visibility.

## Scope boundary

Gate 2 is not started. The snapshot contains no loaded-image identity, object,
name, Engine/World discovery, raw pointer or address. `hooks=0`,
`engine_calls=0` and `mutation=0` are invariant presentation values for this
workflow.
