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
| PLAN-G1-PACKAGE-001 | 1 | Build from a clean revision; inspect package/control/payload/arm64/signature/strings; emit immutable manifest | Package and dylib hashes recorded; no installation | executed by `V2-G1-PREP-003` |
| PLAN-G1.5-SIDELOAD-001 | 1.5 | Inject only manifested raw V2 dylib into a clean app; inspect Status/Logs, close/pause behavior and menu/local-world soak | Icon/refusal visibility, exact zero capabilities, bounded logs, touch/render isolation and stability | executed; FAIL `V2-G1.5-SIDELOAD-FAIL-001` |
| PLAN-G2-READ-001 | 2 | Read-only image identity, profile, name/object/reflection, Engine/World and generation report on Apple Silicon Mac | One exact profile, bounded valid relationships, invalidation, no behavior change | queued after Gate 1.5; no implementation or artifact |

## Immutable V2 execution rows

| Test ID | Date | Artifact / build ID | Environment and procedure | Result | Claim after | Report |
|---|---|---|---|---|---|---|
| V2-G1-STATIC-001 | 2026-08-18 | historical `.build/v2-host/serverhost_v2_core_tests`; SHA-256 `fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5`; `gate1-static-20260818` | Apple Silicon Mac host-local; clean C++20 build, 56 assertions and the then-current raw boundary audit | PASS | Gate 1 statically validated only; no live/device claim | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md) |
| V2-G1-PACKAGE-BUILD-001 | 2026-08-18 | historical `packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb`; SHA-256 `4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35`; `gate1-inert-package-20260818.1` | Local iOS cross-build and content inspection; no game/client execution | PASS | compiled/statically inspected; runtime unverified | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md#inert-ios-packaging-supplement) |
| V2-G1-STATIC-RECHECK-002 | 2026-08-18 | historical Gate 1 host binary, same SHA-256 as `V2-G1-STATIC-001` | 56 host-local assertions and old audit rerun during a Legacy investigation | PASS | static foundation still passed; explicitly not live validation | [Archived context](archive/legacy/TEST_MATRIX_2026-08-18.md) |
| V2-G1-PREP-003 | 2026-08-18 | revision `23da20fe1bbc472bf2476ec6d33a7cd658d7c0d3`; `gate1-foundation-20260818.3`; host binary SHA-256 `d6a841979411c94dabe746afb2c9a64ef6b5b01dd8e0935f47c5e8030c94e6cd`; package SHA-256 `e9d8d187705370270b310a7ee7a05f37909aee12736e261de8b37a204049af29`; dylib SHA-256 `9f06fffb905bbd8a8b97959f2fe32faa49d89528d6668502a0ebb24781b5834a` | Clean V2-only host build; 61 host-local assertions; regex/include-layer boundary audit; iOS arm64 compile including layout assertions; package metadata/payload/Mach-O/signature/build-ID/Legacy-isolation inspection; immutable manifest SHA-256 `91bafa567caf311a597e88f3dd1a24f9e0ef6857cd76a58550fa69c4f75eae78`; no installation | PASS | Gate 1 infrastructure is statically validated and Gate 2 is next; no device/live claim | [Current status](STATUS.md) |
| V2-G1.5-BUILD-004 | 2026-08-18 | Git baseline `a8defbc9f37ed17e54f30b88f715a5ea238ff667`, modified task tree; `gate1.5-diagnostic-ui-20260818.1`; host binary SHA-256 `d1ae694709c4c357b76c215b3f8d3448c851560a74e594632aad511be6ebbc02`; raw dylib SHA-256 `780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b`; Mach-O/dSYM UUID `A4313EC9-3901-3EFC-BC54-5A910DA4F514`; package SHA-256 `f5e0503e72e9d027e851884743d3279b8603d4f6732b1a605d5efa2744099348` | 96 host-local assertions; logger bounds/redaction/concurrency/snapshot/refusal tests; UI/include/render boundary audit; iOS arm64 UIKit/Metal/ImGui build; package and injectable Legacy/gameplay symbol audits; final package dylib copied byte-identically with matching dSYM; manifest SHA-256 `9dbd094744753448416a40a8d29c121c9337f05d6a887f5350d2ee84d6c9cbc2`; no installation/execution | PASS | compiled/statically validated and ready for `PLAN-G1.5-SIDELOAD-001`; runtime UI/stability unverified; Gate 2 not started | [Gate 1.5 review](evidence/GATE1_5_DIAGNOSTIC_UI_REVIEW.md) |
| V2-G1.5-SIDELOAD-FAIL-001 | 2026-08-18 | `gate1.5-diagnostic-ui-20260818.1`; raw pre-injection dylib SHA-256 `780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b` | User manual execution of `PLAN-G1.5-SIDELOAD-001`; floating V2 icon appeared and was tapped. Device/OS, attempt count, logs and screenshot were not supplied. | FAIL: no visible menu opened | Bootstrap/icon installation observed; visible menu opening contradicted; Metal rendering, touch routing, logs and close/pause behavior unverified; Gate 1.5 failed-under-investigation | [Failure intake](evidence/GATE1_5_SIDELOAD_FAILURE_001.md) |

The old `.build` paths above are historical and no longer exist in the source
tree. Current outputs use ignored `.artifacts/v2` paths.

## PLAN-G1.5-SIDELOAD-001 exact protocol

Artifact identity before Sideloadly re-signing:

```text
build ID: gate1.5-diagnostic-ui-20260818.1
dylib: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.1/ServerHostV2.dylib
SHA-256: 780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b
dSYM: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.1/ServerHostV2.dylib.dSYM
```

Procedure:

1. Start from a clean application containing no Legacy `ServerHost.dylib` or
   other Server-Host injection. In Sideloadly inject only the exact raw V2 dylib
   above; Sideloadly may re-sign it.
2. Launch the app and wait up to 10 seconds after the first active game window
   for the local V2 diagnostic button.
3. Open `Status`. Capture a screenshot showing build ID, source revision,
   startup/profile/Legacy states and `Hooks 0`, `Engine calls 0`, `Mutation 0`.
4. Open `Logs`, use `Copy logs`, retain the copied text and capture a screenshot.
5. Press `Close`. Confirm the game receives touches outside the now-closed UI
   and that the overlay has no continuing visible/Metal rendering activity.
6. Reopen Logs once to confirm the panel can reopen normally, then close it.
7. Leave the unmodified game at its normal menu for 10 minutes. Enter a normal
   local world without invoking any V2 capability and leave it for 10 minutes.
   Record crashes, exits, visual/audio/input changes or unusual resource use.

PASS requires all of the following:

- one draggable local icon appears and opens the two-tab diagnostic window;
- Status identifies the exact build and shows the expected missing-identity or
  other explicit refusal reason with all three capability counters equal to 0;
- Logs are bounded, structured, copyable and contain no secret or raw address;
- no Host, Client, administration or disabled placeholder control exists;
- touches outside the icon/open panel pass through, and closing the panel stops
  continuous overlay rendering;
- both 10-minute menu and local-world intervals complete without crash/exit or
  visible game behavior regression.

FAIL is any missing icon after the bounded wait, blank/unopenable Status/Logs,
nonzero capability, raw address/secret, extra gameplay control, touch capture
outside the allowed regions, continuing closed overlay rendering, unbounded log,
crash/exit/hang, or visible game regression. Return both screenshots, copied
logs and any Console/crash artifact. Do not start Gate 2 on failure.

## V2 device failure report template

Use this only after an actual V2 raw dylib was executed on a device:

```text
V2 test/protocol ID:
Date/time and timezone:
Input dylib absolute path, pre-injection SHA-256, build ID, dSYM and manifest path:
Archival package path/SHA-256, if present:
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
