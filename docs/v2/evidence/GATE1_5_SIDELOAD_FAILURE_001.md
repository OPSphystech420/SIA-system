# Gate 1.5 Sideloadly failure intake 001

Report ID: `V2-G1.5-SIDELOAD-FAIL-001`  
Workflow / ABI backlog IDs: Gate 1.5 / ABI-001, ABI-026  
Date: 2026-08-18  
Author/task: Codex failure intake from exact user report  
Exact platform and build identity: manual Sideloadly execution of ShooterGame; device/OS details not supplied  
Device artifact/build: `gate1.5-diagnostic-ui-20260818.1`  
Input dylib SHA-256: `780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b`  
Claim status before: ready for device test; runtime UI unverified  
Claim status after: icon/bootstrap observed; visible opening contradicted; remaining UI behavior unverified

## Observed and expected

The user reported that the floating V2 icon appears and that pressing/tapping it
does not open any visible menu. The expected result is a visible Status/Logs
diagnostic panel. No device model, OS/runtime version, attempt count, screenshot,
console output or copied V2 log was supplied; this report does not infer them.

## Facts preserved separately

- Dylib startup and UI bootstrap progressed far enough to install the icon.
- Visible menu opening is contradicted for the exact input artifact.
- The result does not validate button action dispatch, overlay parent/window or
  z-order, Metal initialization, drawable/render-pass acquisition, first ImGui
  frame, logs, Copy logs, touch pass-through, Close or closed-view pause.

## Artifact preservation

The failed artifact directory remains immutable:

```text
/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.1
```

It contains the failed raw dylib, matching dSYM and pre-injection manifest. The
manifest SHA-256 is
`9dbd094744753448416a40a8d29c121c9337f05d6a887f5350d2ee84d6c9cbc2` and
the Mach-O/dSYM UUID is `A4313EC9-3901-3EFC-BC54-5A910DA4F514`. The archival
package SHA-256 is
`f5e0503e72e9d027e851884743d3279b8603d4f6732b1a605d5efa2744099348`.
Sideloadly may have re-signed the injected copy; these values identify the input
artifact before injection.

The exact failed implementation source tree will be committed and tagged
`v2-gate1.5-sideload-fail-001` before correction. A later report records its
resolved commit hash; the failed artifact directory must not be overwritten.

## Competing hypotheses to investigate

1. The bootstrap keeps the button at the front but does not revalidate or bring
   the overlay above a game render view added/reordered later. This is the
   primary code hypothesis, not yet a proven device cause.
2. The pan recognizer cancels or obscures the ordinary button action, or a
   primary-action path differs on iOS-on-Mac. The failed build has no bounded
   button-action breadcrumb to distinguish this.
3. The action is accepted but the first Metal drawable/render-pass/ImGui frame
   is unavailable. The failed build returns silently from these frame paths and
   has no visible fallback.
4. More than one condition may apply. Static inspection must not promote any
   single hypothesis to device-proven causality.

## Correction boundary

The correction stays inside the Gate 1.5 presentation layer: hierarchy
validation/reordering, explicit tap-versus-drag behavior, deterministic first
frame, bounded stage logs, a UIKit failed-stage fallback and the requested
compact dark cyan/teal Status/Logs layout. It adds no UE discovery, hooks,
ProcessEvent, native calls, hosting, client travel, gameplay mutation or Gate 2
work.
