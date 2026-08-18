# Server-Host V2 evidence registry

This bounded registry covers the active SourceV2 workflow. Legacy runtime
material remains under [`archive/legacy/`](archive/legacy/README.md) and is not
an active blocker.

## Current V2 claims

| ID | Claim | State | Evidence and limit |
|---|---|---|---|
| V2-EV-001 | V2 has an explicit source list/package ID and does not link Legacy runtime sources. | statically validated | `SourceV2.mk`, iOS V2 Makefile and boundary/package audits. Legacy build is not run. |
| V2-EV-002 | Gate 1 curated types/layouts, borrowed containers/strings, names, object identity and reflection descriptors have synthetic host coverage. | statically validated historical baseline | Gate 1 reports/tests; not live UE validation. |
| V2-EV-003 | The iOS 1.10280 profile now contains an exact offline Mach-O identity card. | exact offline + IDA validated; device unverified | ShooterGame whole-file SHA `d98d257…a178`, UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC`, full `__text` SHA `8bfc1fd…bcf8`; offline file and open `110280.i64` agree. Runtime match awaits Gate 2A device execution. |
| V2-EV-004 | Legacy/V2 co-installation is rejected and V2 startup independently refuses exact loaded `ServerHost.dylib`. | statically validated | Debian `Conflicts` and LegacyRuntimeGuard tests; no co-install device claim. |
| V2-EV-005 | Curated layout assertions compile in host and iOS targets. | compiled | Gate 1/1.5 build receipts. |
| V2-EV-006 | V2 packaging is revision-bound and emits a read-only manifest, raw dylib and matching dSYM. | statically validated | `V2-G2A-BUILD-006`: clean source `17e4e09…ad0d`, dylib/dSYM UUID `0704076C-EAB6-3F25-800D-C0F0B85431E8`, manifest SHA `77329da…c5ca`. |
| V2-EV-007 | Gate 2 is split; only 2A image/profile/memory-boundary work has started. | source-confirmed | `Bindings/Platform` contains no FNamePool/GUObjectArray/Engine/World discovery. Gate 2B/2C are unstarted. |
| V2-EV-008 | Diagnostics are bounded/redacted and publish immutable snapshots with exact zero capabilities. | statically validated | Logger/DiagnosticSnapshot tests cover bounds, concurrency, secrets/addresses, identity fields and immutability. |
| V2-EV-009 | Corrected Gate 1.5 presentation opens, renders Metal/ImGui, navigates Status/Logs, copies logs, closes and reopens. | device verified functional; extended soak pending | `V2-G1.5-SIDELOAD-PASS-002`. UIKit fallback did not appear. No unreported long soak or independent outside-window touch PASS is inferred. |
| V2-EV-010 | Gate 1.5 device-tested artifact is exact `.2` input SHA `421211…58c32`, source `8fb09e6…477`. | device verified for bounded functions | Manifest/dSYM plus user runtime receipt. Sideloadly re-signs after input identity. |
| V2-EV-011 | Exact `.1` installed its icon but produced no visible panel. | contradicted opening claim | Immutable `V2-G1.5-SIDELOAD-FAIL-001`; preserved despite later `.2` PASS. |
| V2-EV-012 | Gate 2A selects by exact name, joint dyld-main/`MH_EXECUTE`, architecture, UUID, stable segments/fingerprint and unique candidate count. | statically validated; ready for device test | [Gate 2A report](evidence/GATE2A_EXACT_IMAGE_IDENTITY.md); runtime loaded-image receipt remains unverified. |
| V2-EV-013 | `CheckedMemoryReader` is match-gated, segment-bounded, overflow-checked, permission-typed and returns owned results. | statically validated | Synthetic source tests cover overflow, outside/crossing and forbidden permission cases. Runtime does not instantiate it in Gate 2A. |
| V2-EV-014 | Raw address/ASLR/Mach-O/process-memory operations remain in `Bindings/Platform` and never enter UI/features. | boundary-audit validated | Strengthened `BoundaryAudit.sh`; tests are the only synthetic exception. |
| V2-EV-015 | Production UI compatibility transfer is a separate deferred workflow. | recorded debt | [UI design debt](UI_DESIGN_DEBT.md); current Gate 1.5 panel remains the control. |
| V2-EV-016 | One raw Gate 2A Sideloadly input was built from a clean tagged revision and passed package/injection isolation checks. | ready for device test | `V2-G2A-BUILD-006`; dylib SHA `65bb097…9ef72`, package SHA `19d75c2…84209`; no device/runtime claim. |

## Immutable device result

`V2-G1.5-SIDELOAD-PASS-002` is the authoritative functional Gate 1.5 result:

- icon action and visible Metal/ImGui frame: device verified;
- Status, Logs, Copy logs, Close and reopen: device verified;
- UIKit fallback: not observed;
- `hooks=0`, `engine_calls=0`, `mutation=0`: retained;
- longer menu/map soak and independent touch pass-through outside the open
  window: not separately reported and not claimed.

The remaining read-only stability/touch checks are carried into
`PLAN-G2A-SIDELOAD-001` with explicit user authorization to proceed.

## Sishen pattern evidence

Sishen is an organization/reference source, never the iOS 1.10280 ABI
authority. Gate 2A read `Memory.h`, `Offsets.h`, `SigsAndOffsets.txt`, `Main.h`
and `Main.mm`. It accepted the idea of one image/memory boundary and ordered
startup phases; adapted dyld/image access into exact copied/parsed identity; and
rejected substring selection, singleton base caching, address heuristics,
unchecked globals, copied offsets/signatures, writes, calls, hooks, anti-analysis
and gameplay code.

Detailed reviews:

- [Sishen V2 foundation](evidence/SISHEN_V2_FOUNDATION_REVIEW_2026-08-18.md)
- [Gate 1.5 UI review](evidence/GATE1_5_DIAGNOSTIC_UI_REVIEW.md)
- [Gate 1.5 failure correction](evidence/GATE1_5_UI_FAILURE_INVESTIGATION.md)
- [Gate 2A identity](evidence/GATE2A_EXACT_IMAGE_IDENTITY.md)

## Evidence required next

Gate 2A device execution must show the exact match receipt with UUID, stable
segment sizes and shortened fingerprint but no addresses; `scans_started=0` and
all capabilities zero; mismatched builds must refuse later discovery; panel
close/reopen and the rolled-over menu/local-world stability/touch checks must
complete without crash or regression.

Gate 2B and 2C evidence is not requested or claimed in this workflow.
