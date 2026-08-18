# Server-Host V2 test matrix

This active matrix contains V2 protocols and V2 executions only. The former
matrix, including every Legacy execution/failure row, date, SHA-256 and
clarification, is preserved verbatim at
[`archive/legacy/TEST_MATRIX_2026-08-18.md`](archive/legacy/TEST_MATRIX_2026-08-18.md).

Completed V2 rows are immutable. Append a new row for a new execution; never
rewrite a PASS or FAIL into a later conclusion.

## Claim states

| State | Meaning |
|---|---|
| `compiled` | Named local build succeeded; no runtime claim. |
| `statically validated` | Named host tests/assertions/audits passed; no device claim. |
| `ready for device test` | Unique artifact and exact protocol exist; no pass yet. |
| `device verified` | User supplied a PASS for the exact V2 artifact and protocol. |
| `contradicted` | Exact V2 execution disproved the affected claim. |
| `unverified` | Missing, incomplete or non-transferable evidence. |

## Current V2 protocols

| Protocol ID | Gate | Procedure summary | Exit condition | State |
|---|---|---|---|---|
| PLAN-G1-STATIC-001 | 1 | Clean host build; foundation assertions; boundary audit | Deterministic PASS and fail-closed negative cases | executed historically and rechecked by the preparation workflow |
| PLAN-G1-PACKAGE-001 | 1 | Build from a clean revision; inspect package/control/payload/arm64/signature/strings; emit immutable manifest | Package and dylib hashes recorded; no installation | current infrastructure verification |
| PLAN-G2-READ-001 | 2 | Read-only image identity, profile, name/object/reflection, Engine/World and generation report on Apple Silicon Mac | One exact profile, bounded valid relationships, invalidation, no behavior change | next workflow; no implementation or artifact |

## Immutable V2 execution rows

| Test ID | Date | Artifact / build ID | Environment and procedure | Result | Claim after | Report |
|---|---|---|---|---|---|---|
| V2-G1-STATIC-001 | 2026-08-18 | historical `.build/v2-host/serverhost_v2_core_tests`; SHA-256 `fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5`; `gate1-static-20260818` | Apple Silicon Mac host-local; clean C++20 build, 56 assertions and the then-current raw boundary audit | PASS | Gate 1 statically validated only; no live/device claim | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md) |
| V2-G1-PACKAGE-BUILD-001 | 2026-08-18 | historical `packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb`; SHA-256 `4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35`; `gate1-inert-package-20260818.1` | Local iOS cross-build and content inspection; no game/client execution | PASS | compiled/statically inspected; runtime unverified | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md#inert-ios-packaging-supplement) |
| V2-G1-STATIC-RECHECK-002 | 2026-08-18 | historical Gate 1 host binary, same SHA-256 as `V2-G1-STATIC-001` | 56 host-local assertions and old audit rerun during a Legacy investigation | PASS | static foundation still passed; explicitly not live validation | [Archived context](archive/legacy/TEST_MATRIX_2026-08-18.md) |

The old `.build` paths above are historical and no longer exist in the source
tree. Current outputs use ignored `.artifacts/v2` paths. The current preparation
execution row is appended after its clean-revision package build.

## V2 device failure report template

Use this only after an actual V2 package was executed on a device:

```text
V2 test/protocol ID:
Date/time and timezone:
Package absolute path, SHA-256, build ID and manifest path:
Source revision and enabled capabilities:
Host/client hardware, OS/runtime and exact app build:
Map, starting state and network topology:
Exact numbered actions and timing:
Expected result:
Observed result:
Reproducibility (x/y):
V2 logs, console/crash paths and timestamps:
Affected V2 claim/workflow:
Anything that still worked:
```

A failure in an archived Legacy workflow is recorded in the Legacy archive and
does not change this matrix or block V2 unless the user explicitly selects that
Legacy investigation.
