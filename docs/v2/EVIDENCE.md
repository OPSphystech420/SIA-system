# Server-Host V2 evidence registry

This is the bounded registry for the active V2 workflow. Legacy runtime failure
analysis and execution history are preserved verbatim in
[`archive/legacy/`](archive/legacy/README.md); they are research evidence, not an
active V2 blocker.

## Current V2 claims

| ID | Claim | State | Evidence and limit |
|---|---|---|---|
| V2-EV-001 | V2 has a separate explicit source list and package ID and does not link Legacy runtime sources. | statically validated | `SourceV2.mk`, `SourceV2/Build/IOS/Makefile`; strengthened boundary audit passed in `V2-G1-PREP-003`. No runtime claim. |
| V2-EV-002 | Gate 1 curated types/layouts, borrowed containers/strings, name decoding, object identity, reflection descriptors and strict profile validation have host-local coverage. | statically validated historical baseline | 56 assertions passed in `V2-G1-STATIC-001`; these synthetic host tests are not live validation. |
| V2-EV-003 | The iOS 1.10280 profile intentionally lacks live image identity and fails closed. | source-confirmed | `Bindings/Profiles/IOS_1_10280.hpp`, `ProfileValidator.cpp`, inert initialization tests. Gate 2 must gather the identity. |
| V2-EV-004 | Legacy/V2 co-installation is rejected at package resolution and V2 startup independently refuses an already-loaded exact `ServerHost.dylib`. | statically validated | Inspected Debian `Conflicts` plus five passing host-local `LegacyRuntimeGuard` assertions in `V2-G1-PREP-003`; no device installation or startup execution. |
| V2-EV-005 | Curated layout assertions belong to both host and iOS target source lists. | compiled | `LayoutTests.cpp` compiled cleanly in both host C++20 and iOS arm64 targets in `V2-G1-PREP-003`. |
| V2-EV-006 | V2 packaging is revision-bound and produces a read-only SHA-addressed artifact manifest. | statically validated | Clean revision `23da20fe1bbc472bf2476ec6d33a7cd658d7c0d3`; package/content inspection passed; manifest and artifact hashes are recorded in `TEST_MATRIX.md`. |
| V2-EV-007 | Gate 2 implementation has not started. | source-confirmed | Gate 1.5 adds diagnostics/UI/artifact work only. No `Bindings/Platform` reader, live resolver, hook, invoker, host/client service or mutation path exists. |
| V2-EV-008 | Gate 1.5 has a bounded structured/redacted multi-producer logger and immutable diagnostic snapshot with explicit zero capabilities. | statically validated | `Logger`, `DiagnosticSnapshot` and host tests passed bounds, overflow, redaction, concurrent addition and no-address/refusal snapshot cases in `V2-G1.5-BUILD-004`; no device sink/UI claim. |
| V2-EV-009 | Gate 1.5 UI remains present for missing/unsupported profile and Legacy refusal, renders only Status/Logs snapshots, pauses when closed and has no UE/Bindings/Legacy dependency. | corrected static portions validated; `.1` visible opening contradicted; `.2` device behavior unverified | `.2` state-machine/refusal tests, boundary audit and iOS arm64 build passed in `V2-G1.5-FIX-BUILD-005`. Static tests cannot prove hierarchy, touches, Metal pixels, copy or closed rendering on device. |
| V2-EV-010 | The canonical corrected manual artifact is the final packaged raw dylib with matching dSYM/manifest; it contains no named Legacy/gameplay symbols. | statically validated; ready for device test | Clean revision `8fb09e6…477`; dylib SHA-256 `421211…58c32`, Mach-O/dSYM UUID `4D308F3A-41F6-392C-9C0C-D2384DAFB889`, package SHA-256 `646798…423ee`; package/injection audits passed. Sideloadly may re-sign the input. |
| V2-EV-011 | Exact build `.1` started far enough to install its local V2 icon, but the reported tap produced no visible menu. | device-observed bootstrap; open claim contradicted | User result `V2-G1.5-SIDELOAD-FAIL-001`, exact input SHA-256 `780dee…e48b`. No device/OS, reproducibility, screenshot or logs supplied. This does not validate button dispatch, hierarchy, drawable/frame, ImGui, Logs, Copy, Close or pause behavior. |
| V2-EV-012 | Corrected `.2` implements hierarchy repair/order, unambiguous tap/drag input, explicit first-frame handling, rate-limited frame diagnostics, visible failed-stage fallback and a compact Dragon/Sishen-inspired Status/Logs layout. | source-confirmed and statically validated; device unverified | Clean source `8fb09e6…477`; 143 assertions and boundary/package/injection audits in `V2-G1.5-FIX-BUILD-005`; exact reference dispositions in the failure investigation report. Awaiting `PLAN-G1.5-SIDELOAD-002`. |

## Sishen pattern evidence

Sishen is a primary organization/reference source and never the 1.10280 ABI
authority. The complete review for this infrastructure task is
[`evidence/SISHEN_V2_FOUNDATION_REVIEW_2026-08-18.md`](evidence/SISHEN_V2_FOUNDATION_REVIEW_2026-08-18.md).
The Gate 1.5 UI-specific review is
[`evidence/GATE1_5_DIAGNOSTIC_UI_REVIEW.md`](evidence/GATE1_5_DIAGNOSTIC_UI_REVIEW.md).
The `.1` failure-path and Sishen/Dragon presentation investigation is
[`evidence/GATE1_5_UI_FAILURE_INVESTIGATION.md`](evidence/GATE1_5_UI_FAILURE_INVESTIGATION.md).

| Pattern | Disposition |
|---|---|
| Explicit source grouping and recognizable startup phases | adopted as explicit V2 allowlists and ordered fail-closed bootstrap checks |
| Exact-width UE values plus separate container/name/object layers | adapted into bounded borrowed views, descriptors and curated assertions |
| Central image/address facility | organizational input for future Gate 2 `Bindings/Platform`; no live facility added here |
| Sishen offsets, pool/object globals, address heuristics, delayed constructor work, hooks and ABI | rejected |
| Scene/window lookup, draggable local button, ImGui touch/Metal presentation | adapted to lifecycle notifications, bounded retry, selective touches and a paused closed view |
| Login/UDID/API/security, remote icon, hide-record, auth delay, continuous tick and gameplay UI | rejected |

## Evidence required next

Execute `PLAN-G1.5-SIDELOAD-002` against corrected artifact `.2`. The `.1` icon
bootstrap remains observed and its opening claim contradicted. The corrected
panel, fallback, touch path, Metal frames, copy, close/reopen and closed pause
remain unverified until the user supplies the new device result.

After Gate 1.5 passes, Gate 2 requires:

- exact loaded Mach-O UUID, mapped image/segment sizes and text fingerprint;
- reviewed FNamePool and GUObjectArray resolution cards, including the `0x10`
  root conflict;
- bounded known-name/object/class/function/property live checks;
- Engine/World identity and generation-invalidation snapshot;
- one immutable diagnostic artifact and device result row.

Until those exist, every live UE/layout/discovery claim remains unverified.
