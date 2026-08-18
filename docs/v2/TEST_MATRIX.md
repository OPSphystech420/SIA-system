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
| PLAN-G1.5-SIDELOAD-002 | 1.5 | Inject corrected `.2`; verify acknowledged action, visible panel, Status/Logs, Copy, Close/reopen and zero capabilities | Functional panel path passes; missing longer soak/touch checks remain explicit | executed by `V2-G1.5-SIDELOAD-PASS-002`; functional-device-pass, extended-soak-pending |
| PLAN-G2A-SIDELOAD-001 | 2A | Inject the single Gate 2A artifact; verify exact image/profile receipt, zero scans/capabilities, fail-close behavior and rolled-over read-only stability/touches | One exact profile, no address disclosure, no later discovery, panel lifecycle and ordinary menu/local-world stability | partially executed: identity PASS; death-triggered stability FAIL; wrong-profile negative unexecuted |
| PLAN-G2A-DEATH-CAUSAL-001 | 2A | Same-save death baseline without injection; B/C were conditional controls | Classify whether injection is necessary for the symptom | closed after arm A; external baseline reproduced; B/C waived by user |
| PLAN-G2B-DISCOVERY-001 | 2B | Explicit bounded FNamePool, GUObjectArray and reflection capture only through the provenance reader | Owned known-name/object/reflection snapshots; generation invalidation; zero capabilities | active |
| PLAN-G2C-RELATIONSHIPS-001 | 2C | Future Engine/GameViewport/World/NetDriver relationships and world-generation invalidation | Exact relationships and stale-generation refusal | not started; outside current task |

## Immutable V2 execution rows

| Test ID | Date | Artifact / build ID | Environment and procedure | Result | Claim after | Report |
|---|---|---|---|---|---|---|
| V2-G1-STATIC-001 | 2026-08-18 | historical `.build/v2-host/serverhost_v2_core_tests`; SHA-256 `fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5`; `gate1-static-20260818` | Apple Silicon Mac host-local; clean C++20 build, 56 assertions and the then-current raw boundary audit | PASS | Gate 1 statically validated only; no live/device claim | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md) |
| V2-G1-PACKAGE-BUILD-001 | 2026-08-18 | historical `packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb`; SHA-256 `4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35`; `gate1-inert-package-20260818.1` | Local iOS cross-build and content inspection; no game/client execution | PASS | compiled/statically inspected; runtime unverified | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md#inert-ios-packaging-supplement) |
| V2-G1-STATIC-RECHECK-002 | 2026-08-18 | historical Gate 1 host binary, same SHA-256 as `V2-G1-STATIC-001` | 56 host-local assertions and old audit rerun during a Legacy investigation | PASS | static foundation still passed; explicitly not live validation | [Archived context](archive/legacy/TEST_MATRIX_2026-08-18.md) |
| V2-G1-PREP-003 | 2026-08-18 | revision `23da20fe1bbc472bf2476ec6d33a7cd658d7c0d3`; `gate1-foundation-20260818.3`; host binary SHA-256 `d6a841979411c94dabe746afb2c9a64ef6b5b01dd8e0935f47c5e8030c94e6cd`; package SHA-256 `e9d8d187705370270b310a7ee7a05f37909aee12736e261de8b37a204049af29`; dylib SHA-256 `9f06fffb905bbd8a8b97959f2fe32faa49d89528d6668502a0ebb24781b5834a` | Clean V2-only host build; 61 host-local assertions; regex/include-layer boundary audit; iOS arm64 compile including layout assertions; package metadata/payload/Mach-O/signature/build-ID/Legacy-isolation inspection; immutable manifest SHA-256 `91bafa567caf311a597e88f3dd1a24f9e0ef6857cd76a58550fa69c4f75eae78`; no installation | PASS | Gate 1 infrastructure is statically validated and Gate 2 is next; no device/live claim | [Current status](STATUS.md) |
| V2-G1.5-BUILD-004 | 2026-08-18 | Git baseline `a8defbc9f37ed17e54f30b88f715a5ea238ff667`, modified task tree; `gate1.5-diagnostic-ui-20260818.1`; host binary SHA-256 `d1ae694709c4c357b76c215b3f8d3448c851560a74e594632aad511be6ebbc02`; raw dylib SHA-256 `780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b`; Mach-O/dSYM UUID `A4313EC9-3901-3EFC-BC54-5A910DA4F514`; package SHA-256 `f5e0503e72e9d027e851884743d3279b8603d4f6732b1a605d5efa2744099348` | 96 host-local assertions; logger bounds/redaction/concurrency/snapshot/refusal tests; UI/include/render boundary audit; iOS arm64 UIKit/Metal/ImGui build; package and injectable Legacy/gameplay symbol audits; final package dylib copied byte-identically with matching dSYM; manifest SHA-256 `9dbd094744753448416a40a8d29c121c9337f05d6a887f5350d2ee84d6c9cbc2`; no installation/execution | PASS | compiled/statically validated and ready for `PLAN-G1.5-SIDELOAD-001`; runtime UI/stability unverified; Gate 2 not started | [Gate 1.5 review](evidence/GATE1_5_DIAGNOSTIC_UI_REVIEW.md) |
| V2-G1.5-SIDELOAD-FAIL-001 | 2026-08-18 | `gate1.5-diagnostic-ui-20260818.1`; raw pre-injection dylib SHA-256 `780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b` | User manual execution of `PLAN-G1.5-SIDELOAD-001`; floating V2 icon appeared and was tapped. Device/OS, attempt count, logs and screenshot were not supplied. | FAIL: no visible menu opened | Bootstrap/icon installation observed; visible menu opening contradicted; Metal rendering, touch routing, logs and close/pause behavior unverified; Gate 1.5 failed-under-investigation | [Failure intake](evidence/GATE1_5_SIDELOAD_FAILURE_001.md) |
| V2-G1.5-FIX-BUILD-005 | 2026-08-18 | clean revision `8fb09e654466b07b534a3dd16b2618e789d84777`, tag `v2-gate1.5-diagnostic-ui-20260818.2-source`; `gate1.5-diagnostic-ui-20260818.2`; host binary SHA-256 `418ec0df03be3175fea571a177ae0fb21f1c37a92432abf7457fc9f833b6326f`; raw dylib SHA-256 `4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32`; Mach-O/dSYM UUID `4D308F3A-41F6-392C-9C0C-D2384DAFB889`; package SHA-256 `646798a6c880767146d8c32b068a972e39deafb87ecd5c3e0aedabb9602423ee` | 143 host assertions; presentation transition/deadline/fallback/event tests; boundary audit; iOS arm64 UIKit/Metal/ImGui build; package and injection Legacy/gameplay symbol audits; byte-identical package/raw dylib and matching dSYM; immutable manifest SHA-256 `6aea8368b71e74363f9c5e3c4faf95d943c24d744d208dc8d7a9d319f770b9e7`; no installation/execution | PASS | compiled/statically validated and ready for `PLAN-G1.5-SIDELOAD-002`; UIKit/Metal pixels, input, copy, close/reopen and stability remain unverified; Gate 2 not started | [Investigation/correction report](evidence/GATE1_5_UI_FAILURE_INVESTIGATION.md) |
| V2-G1.5-SIDELOAD-PASS-002 | 2026-08-18 | `gate1.5-diagnostic-ui-20260818.2`; source `8fb09e654466b07b534a3dd16b2618e789d84777`; raw input dylib SHA-256 `4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32` | User manual Sideloadly execution. Runtime receipt confirmed button action, open request, verified hierarchy, first frame, Metal drawable/pass, ImGui submission/presentation, stopped Metal on Close, reopen and bounded log copy. | PASS: functional device path | Device-verified icon action, visible Metal/ImGui, Status, Logs, Copy logs, Close/reopen; no UIKit fallback; capabilities remained zero. Longer menu/map soak and independent outside-window touch check were not separately reported and are not claimed; user authorized Gate 2A. | [Gate 1.5 PASS 002](evidence/GATE1_5_SIDELOAD_PASS_002.md) |
| V2-G2A-BUILD-006 | 2026-08-18 | clean revision `17e4e09ce8029bb89b22560da771ddc170e2ad0d`, tag `v2-gate2a-exact-identity-20260818.1-source`; `gate2a-exact-identity-20260818.1`; host binary SHA-256 `89b6e8322857c64cd731fa17897212fd5748fe744bd8c4ccd81c8455d5b67abc`; raw dylib SHA-256 `65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72`; Mach-O/dSYM UUID `0704076C-EAB6-3F25-800D-C0F0B85431E8`; package SHA-256 `19d75c2e4ec8df0bc3e00d33e7337f3f7e981ddfc8308ebd8981007eb0784209` | 191 normal host assertions and 191 UBSan-only assertions; malformed/ambiguous identity and checked-read negative tests; raw boundary audit; iOS arm64 compile; package/control/payload/build-ID and injection Legacy/gameplay isolation audits; byte-identical package/raw dylib, matching dSYM; manifest SHA-256 `77329da6d35f49c332c63a39e733d6fc970eaf474f89600b7edd37909ad1c5ca`; no installation/execution | PASS | statically validated and ready for `PLAN-G2A-SIDELOAD-001`; exact runtime match, wrong-profile refusal and stability/touch behavior remain device-unverified; Gate 2B not started | [Gate 2A report](evidence/GATE2A_EXACT_IMAGE_IDENTITY.md) |
| V2-G2A-IDENTITY-PASS-001 | 2026-08-18 | `gate2a-exact-identity-20260818.1`; source `17e4e09ce8029bb89b22560da771ddc170e2ad0d`; raw input dylib SHA-256 `65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72` | User manual Sideloadly execution on Apple Silicon Mac. Status/Logs showed exact-match UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC`, expected segment card and fingerprint `8bfc1fd248a5...`; open/close/reopen, Copy logs and interaction worked. | PASS: positive exact-target identity sub-contract | Exact image identity is device verified; `scans_started=0`, hooks/engine calls/mutation zero. Wrong-profile negative and extended stability are not included in this PASS. | [Gate 2A device report](evidence/GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md) |
| V2-G2A-DEATH-SIGNAL-EXIT-001 | 2026-08-18 | same exact Gate 2A artifact; Console SHA-256 `0578303bea504af55cf6762d147debe6443e6f915bc9d3a56738608b360c7a8f` | Apple Silicon Mac; local saved world; no EOS; character death and death/respawn transition with panel open. Last V2 open `uptime_ms=120678`, no later close. Console line 7579: `GASignalHandler entered`; subsequent crash-event upload received HTTP 200; no signal number, stack, faulting thread or new 2026-08-18 ShooterGame `.ips`. | FAIL: extended stability contradicted | At intake the cause was unclassified and Gate 2B paused. Subsequent `V2-G2A-DEATH-BASELINE-002` reproduced the symptom without injection and reclassified it as an external baseline limitation. HTTP 200 is upload success, not cause. | [Gate 2A device report](evidence/GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md) |
| V2-G2A-DEATH-BASELINE-002 | 2026-08-18 | ShooterGame 1.10280 without any injected Server-Host dylib | User executed arm A with the same local saved world and character death. The application exited identically; signing in to EOS did not alter the result. | classification: external baseline reproduced | Gate 2A is not a necessary cause. Exact stock-game cause is deferred; B/C waived; death/respawn removed from current V2 stability acceptance; Gate 2B unblocked. | [Gate 2A device report](evidence/GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md) |
| V2-G2B-STATIC-001 | 2026-08-18 | Gate 2B source; synthetic exact image plus sparse owned memory regions | 270 normal + 270 UBSan-only assertions; FreshSDK RVA normalization; provenance/unmap/overflow/scope; FName/object double-sample mutation/retry; malformed bounds/entries/chunks/relationships; flags/serial/generation/cycles; cancellation/time/byte/object limits; report redaction/immutability; boundary audit; iOS arm64 compile. Combined ASan/UBSan compiled but stalled before the first marker and was interrupted. | PASS for normal/UBSan/audit/iOS compile; combined sanitizer runtime unverified | Static/compile claim only. Exact live roots/names/objects remain device-unverified; Gate 2C and hosting not started. | [Gate 2B report](evidence/GATE2B_READ_ONLY_CONTRACTS.md) |

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

## PLAN-G1.5-SIDELOAD-002 exact protocol

Artifact identity before Sideloadly re-signing:

```text
build ID: gate1.5-diagnostic-ui-20260818.2
dylib: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/ServerHostV2.dylib
SHA-256: 4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32
dSYM: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/ServerHostV2.dylib.dSYM
manifest: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/manifest.txt
```

Procedure:

1. Use a clean application with no Legacy dylib or other Server-Host injection;
   inject only the corrected raw V2 dylib through Sideloadly.
2. Launch and confirm the floating V2 icon appears.
3. Tap the icon once; report whether it visibly changes to its accepted/open
   state.
4. Confirm exactly one of these outcomes: the styled dark cyan/teal Status/Logs
   panel appears, or a UIKit fallback visibly names the failed stage.
5. Capture a screenshot of the panel or fallback. A fallback is useful failure
   evidence, never PASS.
6. If the panel opened, switch between Status and Logs, use `Copy logs`, press
   `Close`, and reopen once with a single tap.
7. Only after open/close/reopen passes, leave the panel closed for two minutes
   at the normal menu and confirm touches pass through with no continuing
   visible overlay rendering. Then spend five minutes in a normal local world
   without invoking any V2 runtime capability and note crashes, exits, input or
   visible behavior changes.
8. Return the screenshot, copied logs, button-change result and any fallback
   stage, Console output or crash artifact. Do not infer device/OS details that
   were not captured.

PASS requires every item below:

- the icon appears, acknowledges one accepted tap, and opens the visible styled
  panel rather than the fallback;
- the panel exposes exactly Status and Logs with usable navigation, readable
  diagnostic values, working `Copy logs` and `Close`;
- Status identifies the exact build and keeps `hooks=0`, `engine_calls=0` and
  `mutation=0`; Logs stay bounded/redacted and contain no raw address;
- touches outside the icon/open panel pass through; Close stops continuous
  rendering; one-tap reopen succeeds cleanly;
- the bounded closed-menu and local-world checks complete without crash, exit,
  hang, touch regression or visible game regression.

FAIL is a missing icon, no accepted-action visual change, no visible panel, any
UIKit fallback, wrong/extra controls, broken navigation/copy/close/reopen,
nonzero capability, raw address/secret, touch capture outside allowed regions,
continuing closed overlay rendering, crash/exit/hang or visible regression.

Execution `V2-G1.5-SIDELOAD-PASS-002` satisfied the functional icon/panel/
Status/Logs/Copy/Close/reopen portion and explicitly did not report the longer
step 7 soak or independent outside-window touch check. Those checks were not
inferred; the user authorized Gate 2A and they are carried below.

## PLAN-G2A-SIDELOAD-001 exact protocol

Use only the final raw artifact and manifest under:

```text
build ID: gate2a-exact-identity-20260818.1
dylib: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate2a-exact-identity-20260818.1/ServerHostV2.dylib
dSYM: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate2a-exact-identity-20260818.1/ServerHostV2.dylib.dSYM
manifest: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate2a-exact-identity-20260818.1/manifest.txt
```

Procedure:

1. Start from clean ShooterGame 1.10280 with no Legacy/other Server-Host dylib;
   inject only the manifested raw Gate 2A dylib through Sideloadly.
2. Open Status and capture the selected image/product `ShooterGame`, `arm64`,
   UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC`, the five segment sizes, a
   shortened fingerprint beginning `8bfc1fd248a5`, and `exact-match` profile.
3. Confirm Status and copied Logs contain no ASLR slide, pointer, RVA or absolute
   address and show `scans_started=0`, `hooks=0`, `engine_calls=0`, `mutation=0`.
4. Close and reopen once. While the panel is open, operate one ordinary game
   control outside its window and confirm the game receives the touch; Close
   must again stop Metal rendering.
5. With the panel closed, remain at the normal menu for two minutes, then enter
   an ordinary local world for five minutes. Do not invoke any V2 runtime
   capability. Record crash, exit, hang, input/audio/visual or gameplay change.
6. Wrong-profile negative: use the same single dylib against a known non-1.10280
   ShooterGame build. It must report mismatch/refusal with no scan or capability;
   do not substitute a second Gate 2A dylib variant.
7. Return target and mismatch screenshots, copied bounded logs, exact app build/
   device/OS details and any Console/crash artifact.

PASS requires exact profile match on the named target; UUID/fingerprint/segments
visible without addresses; `scans_started=0` and all capability counters zero;
the wrong build fail-closes; panel open/close/reopen and outside-window touch
pass-through work; and the two-minute menu plus five-minute local-world checks
complete without crash or visible game regression.

No Gate 2B name/object scan or Gate 2C relationship is part of this protocol.

Execution produced `V2-G2A-IDENTITY-PASS-001` for the positive exact-target
identity sub-contract and `V2-G2A-DEATH-SIGNAL-EXIT-001` for extended stability.
It did not execute the wrong-profile negative. The signal exit is handled by
the causal protocol below before any Gate 2B work.

## PLAN-G2A-DEATH-CAUSAL-001 exact protocol

Status: closed after arm A. `V2-G2A-DEATH-BASELINE-002` reproduced the symptom
without injection. Arms B/C below are retained only as the immutable original
plan and are not required by user decision.

Purpose: classify the death/respawn signal exit using the existing application
and exact Gate 2A dylib only. Build no replacement, A/B or diagnostic package.
Use the same ShooterGame 1.10280 save/map and character in all arms. Do not log
into EOS and do not run hosting, client travel or any other mod.

### A — baseline without injection

1. Remove every injected ServerHost dylib and fully launch the application.
2. Bring the same character to death.
3. Record whether respawn UI appears, whether the process exits, wall-clock
   time, approximate process uptime, Console tail and any new `.ips`.

### B — exact Gate 2A with UI closed

1. Inject only the existing raw artifact:
   `packages/v2/injection/gate2a-exact-identity-20260818.1/ServerHostV2.dylib`.
2. Open the panel once, verify build ID
   `gate2a-exact-identity-20260818.1`, then close it.
3. Wait at least 30 seconds with the panel closed.
4. Bring the same character to death and capture the same evidence as A.

### C — exact Gate 2A with UI open

1. Fully restart the application with the same Gate 2A dylib injected.
2. Leave the panel open and bring the same character to death.
3. Capture the same evidence as A and B.

Run each arm once. Do not change artifact, save, map, EOS state or other mods
between arms. For each arm report respawn UI yes/no, exit yes/no, exact times,
`GASignalHandler entered` yes/no, Console tail and `.ips` path if one appears.

Interpret exactly as follows:

- A exits at death: strong base-game/EOS/save-path evidence; repeat A once. If
  reproduced, record an external baseline limitation and Gate 2B may continue.
- A and B stable, C exits: open Metal/ImGui presentation path is implicated;
  Gate 2B stays blocked until the UI is fixed.
- A stable, B and C exit: V2 injection/bootstrap/identity delta is implicated;
  define a Gate 1.5 `.2` versus Gate 2A control only after this result.
- A and B exit: ambiguous; repeat baseline A before attribution.
- All three stable: intermittent result; do not patch code without a second
  reproduction.

## PLAN-G2B-DISCOVERY-001 exact protocol

Use only the single manifested raw artifact under
`packages/v2/injection/gate2b-readonly-contracts-20260818.1/`. Do not inject
Legacy or another mod and do not start hosting, client travel or death/respawn.

1. Launch ShooterGame 1.10280 and open Status in the main menu.
2. Confirm exact profile, UUID/fingerprint/segments, `scans_started=0` and zero
   hooks/engine calls/mutation.
3. Open Contracts and press **Capture read-only contracts** once.
4. Wait for `complete`, copy report/logs and confirm ten known FNames plus nine
   exact core object/function validators pass without any displayed address.
5. Enter an ordinary TheIsland local world and capture again.
6. Confirm discovery generation changed, previous generation is invalidated,
   object count is reported, and hooks/engine calls/mutation remain zero.
7. Return to menu naturally if possible and perform a third capture.
8. Report any retry, timeout, malformed relationship, crash or UI regression
   with the bounded output and Console tail.

Death/respawn is not a Gate 2B PASS/FAIL condition because the same exit is a
reproduced no-injection baseline limitation. PASS does not authorize Gate 2C or
hosting; it closes only the read-only name/object/reflection snapshot contract.
