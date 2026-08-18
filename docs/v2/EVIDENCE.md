# Server-Host V2 evidence registry

This is the bounded registry for the active V2 workflow. Legacy runtime failure
analysis and execution history are preserved verbatim in
[`archive/legacy/`](archive/legacy/README.md); they are research evidence, not an
active V2 blocker.

## Current V2 claims

| ID | Claim | State | Evidence and limit |
|---|---|---|---|
| V2-EV-001 | V2 has a separate explicit source list and package ID and does not link Legacy runtime sources. | source-confirmed | `SourceV2.mk`, `SourceV2/Build/IOS/Makefile`; boundary audit. No runtime claim. |
| V2-EV-002 | Gate 1 curated types/layouts, borrowed containers/strings, name decoding, object identity, reflection descriptors and strict profile validation have host-local coverage. | statically validated historical baseline | 56 assertions passed in `V2-G1-STATIC-001`; these synthetic host tests are not live validation. |
| V2-EV-003 | The iOS 1.10280 profile intentionally lacks live image identity and fails closed. | source-confirmed | `Bindings/Profiles/IOS_1_10280.hpp`, `ProfileValidator.cpp`, inert initialization tests. Gate 2 must gather the identity. |
| V2-EV-004 | Legacy/V2 co-installation is rejected at package resolution and V2 startup independently refuses an already-loaded exact `ServerHost.dylib`. | source-confirmed; host-local guard tested | Debian `Conflicts` plus `LegacyRuntimeGuard`; no device installation or startup execution. |
| V2-EV-005 | Curated layout assertions belong to both host and iOS target source lists. | source-confirmed | `LayoutTests.cpp` is explicit in both build files; final arm64 compilation result is recorded in `TEST_MATRIX.md`. |
| V2-EV-006 | V2 packaging is revision-bound and produces a read-only SHA-addressed artifact manifest. | source-confirmed | Clean-revision gate and manifest/content-inspection scripts; final hashes are appended only after execution. |
| V2-EV-007 | Gate 2 implementation has not started. | source-confirmed | No `Bindings/Platform` reader, live resolver, hook, invoker, host/client service or mutation path exists. |

## Sishen pattern evidence

Sishen is a primary organization/reference source and never the 1.10280 ABI
authority. The complete review for this infrastructure task is
[`evidence/SISHEN_V2_FOUNDATION_REVIEW_2026-08-18.md`](evidence/SISHEN_V2_FOUNDATION_REVIEW_2026-08-18.md).

| Pattern | Disposition |
|---|---|
| Explicit source grouping and recognizable startup phases | adopted as explicit V2 allowlists and ordered fail-closed bootstrap checks |
| Exact-width UE values plus separate container/name/object layers | adapted into bounded borrowed views, descriptors and curated assertions |
| Central image/address facility | organizational input for future Gate 2 `Bindings/Platform`; no live facility added here |
| Sishen offsets, pool/object globals, address heuristics, delayed constructor work, hooks and ABI | rejected |

## Gate 2 evidence required next

- exact loaded Mach-O UUID, mapped image/segment sizes and text fingerprint;
- reviewed FNamePool and GUObjectArray resolution cards, including the `0x10`
  root conflict;
- bounded known-name/object/class/function/property live checks;
- Engine/World identity and generation-invalidation snapshot;
- one immutable diagnostic artifact and device result row.

Until those exist, every live UE/layout/discovery claim remains unverified.
