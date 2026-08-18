# Server-Host V2 status

Last updated: 2026-08-18.

## Current state

```text
phase: exact legacy host-started signal-exit failure intake active; unrelated feature work paused
current task outcome: signal-handler termination is reproduced in two processes (PID 12587 and 13001); the full PID-13001 capture reaches `_Exit(1)` 143.743619 seconds after foreground activation; signal/stack and panel arm remain unknown
active runtime workflow: exactly one — world open + host started, followed by a caught POSIX signal and process exit
next bounded action: same package `-6` and same successful Start, then five minutes panel hidden versus five minutes panel visible, with live Console capture
next workflow authorization: no Gate 2+ implementation or behavior-changing hook is authorized by this failure intake
V2 package artifact: packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb
V2 device-test status: inert package ready for a load/console smoke test; not device verified
legacy default runtime behavior: unchanged; default-off diagnostic selection added and both legacy variants independently rebuilt
failure rollback/reference: packages/com.mhga.serverhost_0.2.24-4+debug_iphoneos-arm.deb; compiled/inspected only, predates diagnostic gate and preserves suspect policy
host-visual diagnostic B: packages/com.mhga.serverhost_0.2.24-7+debug_iphoneos-arm.deb; built but device test suspended
failed host-started A: packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb; exact device FAIL after Start; hidden/no-command control stable
```

## Strongest current claims

| Capability or fact | State | Limit |
|---|---|---|
| Legacy 0.2.11 Mac host -> physical iPhone gameplay after the game-owned recovery pair | device verified historical result | Exact package file is now missing; recorded hash/result remain, but there is no current rollback artifact or matching source snapshot. |
| Gate 0 architecture, migration, backlog and ordered plan | statically analyzed/documented | No device/runtime result. |
| Exact 1.10280 GetNetMode body and dedicated-vs-listen-sensitive callers | exact-binary confirmed through live IDA MCP | Entry/prototype/slot and actor registration, listen distance/relevancy, stasis/grid divergences are confirmed. This still does not prove which path causes sky/weather or validate hook transport. |
| Legacy 0.2.24 save/admin/return/stability statements in root status | unverified for V2 | Legacy A/B source/status evidence; no immutable V2 result row. |
| Host visual stability after the reported later legacy hosting-hook workflow | contradicted for deleted artifact SHA-256 `217c15cba0f634ee9427b219d30f17a2f917045d9683f35ea8bbc02079cb15f4` | Hash identifies the artifact but package bytes/source, timing, logs and control are missing. Causality and transfer to current/V2 builds remain unverified. |
| Legacy hidden/no-command stability for A `0.2.24-6` | device-observed control | User reports the game is stable when ServerHost remains unopened and no control is pressed. This does not validate hosting or visible UI. |
| Legacy host-started stability for A `0.2.24-6` | contradicted/device observed | A world-open, host-started execution reached `GASignalHandler entered`; exact IDA proves the handler submits an error and calls `_Exit(1)`. Exact signal, stack and repeatability remain unknown. |
| Legacy host-visual policy A/B artifacts | suspended | A `0.2.24-6` lacks a stable host-started baseline; B `0.2.24-7` is not a fix and must wait for the post-Start panel-hidden/panel-visible control. |
| Gate 1 typed core | compiled and statically validated | Host-local only: 56 assertions passed and dependency/raw-access audit passed; no live game data was read. |
| Gate 1 inert iOS package | compiled, statically inspected, ready for limited device smoke | Separate package ID; only a one-shot fail-closed console report. It has not been loaded on a device. |
| Any V2 host, client, hook, player-flow, save or administration behavior | unverified/not started | The V2 package contains none of these capabilities. |

## Completed baseline

- Mandatory living documentation, architecture, migration and ABI backlog exist
  under `docs/v2`.
- Current source/build layout, root legacy status and historical package set were
  inventoried without changing them.
- Relevant Sishen and Dragon patterns, both FreshSDK variants,
  NetDriverDefinitions, SEA material, UE4.17 behavior and the preserved 0.2.11
  binary behavior map are recorded.
- Exact iOS analysis established the broad semantic risk of forced Dedicated;
  caller-RVA whitelisting is not approved production architecture.
- `RULES.md` now requires future tasks to read the corresponding Sishen
  implementation before designing UE types/lookups, ProcessEvent wrappers,
  memory facilities, hooks or startup.
- Claim states and immutable failure/result handling are defined consistently.
- `SourceV2.mk` selects a separate C++20 host test target with an explicit V2
  source list and no legacy runtime objects.
- The first typed UE foundation, strict profile validator and inert status-only
  initialization path are implemented under `SourceV2`.
- Current FreshSDK core sizes/alignments/used offsets are asserted without
  importing the generated SDK; exact provenance is recorded in the Gate 1
  evidence report.
- `SourceV2/Build/IOS` provides an isolated Theos project with package ID
  `com.mhga.serverhost.v2` and an explicit source list. Its entry runs the
  strict missing-evidence path once and installs no hook or callable binding.

## Available evidence paths

| Artifact | State |
|---|---|
| `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64` | present; exact current iOS database |
| `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/SEAServerManager.dylib.i64` | present; deferred SEA client-manager database |
| `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/SEA_host_guide.md` | present |
| `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/com.studiowildcard.arkuse-1.10280-Decrypted` | present; includes ShooterGame and EOSSDK binaries |
| both `Server-Host/Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame*` trees | present |
| `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main` | present; primary pattern source |
| `/Users/grimreaper31/Desktop/Dev/MHGA/Dragon/ProjDragon/Dragon` | present; secondary pattern source |
| `/Users/grimreaper31/Desktop/Dev/extra/engines/UE4.17` | present |
| legacy 0.2.11 deb | missing; historical SHA-256 `54dda1d682bc01f5fbd38a078a33994c23ffbe4ac6d466c978ffa86775ae8dbf`; no recoverable local copy found |
| Gate 1 host test executable | present; `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/.build/v2-host/serverhost_v2_core_tests`; SHA-256 `fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5` |
| Gate 1 inert V2 package | present; `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb`; SHA-256 `4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35` |
| current default-off signed legacy dylib | present; `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/.theos/obj/debug/ServerHost.dylib`; final-restored-build SHA-256 `a05deb9db71a4835a2202026970bd7ca6ec55d174ca76803c60caa111c91987b`; selection matches A semantics, while package A has its immutable payload hash |
| host-started failure Console capture | present; `/Users/grimreaper31/.codex/attachments/9991530b-8a5a-4cfc-9e4f-8b2568ad77f0/pasted-text.txt`; SHA-256 `5e2a9c96de5eadee767454cebb06539b82b6c983d5d224b910f1aec0bf3a1a08`; 1,303 lines; signal confirmed, panel arm/signal number/stack absent |
| pre-gate legacy 0.2.24 rollback/reference | present; `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-4+debug_iphoneos-arm.deb`; SHA-256 `2a23ba8c9286085a79dced8ecb07464b48e9be3be32189bea98f1bb3cb64c87c`; compiled/inspected, not device-run and not a fix |
| earlier original-NetMode diagnostic | present; `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-5+debug_iphoneos-arm.deb`; SHA-256 `dfae573863c86146e51d72dd5cb9f039708f342b63badf0229b39531ff3bdb7d`; preserved but not the protocol B because it would downgrade after A |
| failed same-gated-source forced-policy A | present; `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb`; SHA-256 `d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e`; hidden/no-command control stable, host-started execution failed by signal-driven `_Exit(1)` |
| suspended original-NetMode diagnostic B | present; `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-7+debug_iphoneos-arm.deb`; SHA-256 `bf566b6ee77e4ef28fee1099314345a9d31e45e46166519004c4df19b4873956`; embedded dylib SHA-256 `d88a71290c33856b60ae133b29ee94469416cdb7f097f742ac408d3913705d75`; built but not a valid visual-test/fix artifact while A lacks a stable host-started baseline |

## Missing artifact paths

- legacy 0.2.11 `.deb` and matching source snapshot — not found; do not claim
  recovery or an available rollback artifact;
- deleted failing legacy `.deb` SHA-256
  `217c15cba0f634ee9427b219d30f17a2f917045d9683f35ea8bbc02079cb15f4`
  — identity supplied, bytes/source/build metadata not recoverable locally;
- exact Android `LibUE.so` and IDA database path — not recorded; request only
  after iOS stability/when Android becomes active;
- Gate 2+ live contract reports and V2 device logs — none exist yet.

## Important unproven claims

- the exact ShooterGame-native late-listen host initialization path;
- the cause of host sky/weather/FPS regression;
- the exact package/source delta that produced `LEGACY-SKY-FAIL-001`;
- a reversible production-safe iOS hook backend;
- far replication with original GetNetMode/native semantics;
- current V2 ProcessEvent and recovery behavior on a physical client;
- string/array ownership for NetDriverDefinition mutation and travel;
- client cleanup/reconnect, character restoration, save durability and every
  administration operation;
- Android ABI and VPS/control-plane behavior.

Exact proving databases/logs/device tests are in [ABI_BACKLOG.md](ABI_BACKLOG.md).

## Active failure intake

`LEGACY-HOST-SIGNAL-EXIT-001` is the active isolated failure. The earlier
no-host classification is withdrawn: the user clarified that a world was open
and hosting had started. Exact A `-6` is stable while ServerHost is unopened and
unused, but the host-started run reached `GASignalHandler entered`.

Exact IDA recovery shows one GameAnalytics handler covers thirteen POSIX
signals, submits a backtrace error event and calls `_Exit(1)`. It does not retain
the signal number, so the current excerpt cannot distinguish memory fault,
abort, pipe/resource signal or another registered signal. Package/source delta
between control and failure is zero; host activation and visible rendering
changed together. The smallest remaining control keeps Start fixed and compares
the panel hidden versus visible for five minutes. See the
[host-started signal-exit intake](evidence/IOS_1.10280_HOST_STARTED_SIGNAL_EXIT.md).

Build verification remains valid only as compilation evidence: full legacy
arm64 A and B builds and package selections passed; the default-off selection
was rebuilt independently.
The only code-toolchain warning was the obsolete linker option
`-multiply_defined`; Theos also printed its ordinary non-code parallel-build
notice. Gate 1 host tests were rerun: 56 assertions, zero failures, raw-boundary
audit PASS. No device/live claim follows from either result.

## Consistency audit

| Tension or apparent conflict | Resolution |
|---|---|
| Root `STATUS.md` calls some legacy 0.2.24 paths “confirmed,” while V2 marks them unverified. | Root status records the legacy A/B branch. V2 requires its own exact artifact and immutable user result before promotion. Both records are preserved. |
| Sishen is the primary reference, but its ABI differs. | Sishen governs code patterns and organization; exact 1.10280 binary, current FreshSDK and live reflection govern ABI/addresses. |
| Legacy forced Dedicated helped far replication but may damage host behavior. | Preserve both observations. Investigate native initialization and inert caller evidence; do not bless the workaround or infer sky causality. |
| V2 should reuse proven behavior but remain separate. | Re-express validated behaviors through typed V2 seams; never link/copy the monolith or delete the control. |
| Android/VPS is a desired outcome while current work is iOS-only. | Android/VPS remains a short deferred direction and cannot enlarge Gate 1 APIs. |
| Documentation previously called the 0.2.11 control package present, but the file is missing. | Preserve its recorded hash/device result as history, mark rollback unavailable, and isolate V2 package output by ID/directory. Do not recreate the control from nonmatching source. |

No irreconcilable requirement was found. The unresolved items above are evidence
gaps, not permission to invent a contract.

## V2 package smoke (paused by active failure workflow)

The inert package is ready only for this bounded smoke:

1. install package ID `com.mhga.serverhost.v2` on the Apple Silicon Mac iOS
   environment;
2. launch ShooterGame 1.10280 once without selecting Host/Client behavior;
3. confirm exactly one `[ServerHostV2]` console line reports build
   `gate1-inert-package-20260818.1`, `missing-identity-evidence`, and
   `hooks=0 engine_calls=0 mutation=0`;
4. confirm normal menu/game behavior is unchanged and return the console line or
   crash report.

This does not test Gate 2 or any gameplay feature.

After the active A/B failure workflow resolves, Roadmap Gate 2 remains read-only
build, name, object and Engine discovery only.

Required scope:

1. prove and capture the exact loaded Mach-O UUID, image/segment sizes and text
   fingerprint for the 1.10280 profile;
2. resolve FNamePool and GUObjectArray through reviewed read-only cards,
   explicitly resolving the current 0x10 root conflict;
3. add checked low-level memory/image readers under `Bindings/Platform` and
   typed name/object/reflection/Engine/World views above them;
4. emit only a bounded, redacted ContractReport/Snapshot and validate world
   generation invalidation;
5. build a uniquely identified diagnostics package and run the Gate 2 device
   protocol before promoting any live claim.

Explicit exclusions: Engine mutation, hooks, native calls, `ProcessEvent`, host,
connect, player-flow, save, administration and legacy behavior changes. The
architecture explicitly puts this read-only gate before lifecycle dispatch or
inert hook observation.

## Packaging handoff

The root legacy Makefile and Host request were minimally edited only to add the
default-off `SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE` selection and diagnostic
log; the normal/default forced policy is unchanged. The V2 package remains
isolated by project, package ID and output directory and contains no legacy
object. No device state was changed. `HISTORY.md` records that the prior clean
legacy build removed the historical 0.2.11 package file; its old device result
remains historical evidence, not an available rollback.
