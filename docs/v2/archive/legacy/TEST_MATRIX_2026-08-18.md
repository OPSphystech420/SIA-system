# Server-Host V2 test matrix

Completed result rows are immutable. Never delete or edit a PASS/FAIL result
after a fix; append a new row with a new build/test ID and link it to the earlier
row. A dated clarification may be appended below a row when the original record
was incomplete, but the original claim remains visible.

Planned rows with `TBD` are protocols, not results. When an artifact exists,
create a new immutable execution row containing its absolute path, build ID and
hash rather than converting a generic plan into historical evidence.

## State vocabulary

| State | Meaning in this matrix |
|---|---|
| `compiled` | Named build succeeded; procedure not necessarily run. |
| `statically validated` | Named assertions/checks passed; no device claim. |
| `ready for device test` | Unique artifact and exact protocol handed to user. |
| `device verified` | User reported PASS for exact artifact/environment/protocol. |
| `contradicted` | Exact result disproved the affected claim. |
| `unverified` | Not run, missing artifact/evidence, mixed result or not transferable to V2. |

## Artifact controls

| Artifact | Absolute path | SHA-256 | Role |
|---|---|---|---|
| Legacy 0.2.11 control | missing from recorded path `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.11+debug_iphoneos-arm.deb` | historical record: `54dda1d682bc01f5fbd38a078a33994c23ffbe4ac6d466c978ffa86775ae8dbf` | Known historical gameplay result; file and matching source are unavailable, so it is not a current rollback artifact. |
| V2 Gate 1 host test | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/.build/v2-host/serverhost_v2_core_tests` | `fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5` | Host-local arm64 static/unit test executable only; not an iOS package or runtime artifact. |
| V2 Gate 1 inert package | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb` | `4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35` | Installable arm64 package with one fail-closed status entry; no hooks, engine calls, mutation or gameplay capability. |
| Current legacy compile check | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/.theos/obj/debug/arm64/ServerHost.dylib` | forced-rebuild hash `c1c4dbdbf7fb614f2b7de28c8c57243f32ebdffce6b15e2dcb563e16f940cd02` | Independent compile check of the current legacy tree; not the historical 0.2.11 control and not device-tested here. |
| Current-source legacy 0.2.24 forced-policy control | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-4+debug_iphoneos-arm.deb` | `2a23ba8c9286085a79dced8ecb07464b48e9be3be32189bea98f1bb3cb64c87c` | Full forced rebuild produced after `LEGACY-SKY-FAIL-001`; preserves the current three-hook/forced-policy behavior for a future A/B control. Not device-tested, not the reported failing package and not a fix. |

## Historical controls — immutable

These two rows are preserved from the initial V2 documentation.

| Test ID | Build | Host | Client | Workflow | Result | Evidence |
|---|---|---|---|---|---|---|
| HIST-001 | Legacy 0.2.11 | iOS app on Apple Silicon Mac | Physical iPhone | Listen, connect, manual server-authoritative RPC pair, gameplay entry | PASS | Spectating -> Playing; HUD, player data and pawn assigned. |
| HIST-002 | Later legacy builds through current 0.2.24 | iOS app on Apple Silicon Mac | Physical iPhone as applicable | Save/admin/client/stability expansion | MIXED/UNVERIFIED | User reports crashes, non-working functions and host sky/weather/world regression. Individual deltas are not yet isolated. |

Interpretation:

- HIST-001 is `device verified` only for the stated legacy control workflow.
- HIST-002 remains `unverified`; it cannot promote any V2 save/admin/lifecycle
  claim. Root legacy status preserves later implementation beliefs separately.

## Superseded pre-architecture V2 plans — never run

The following rows used the older gate numbering. They had no artifact and were
never run. They are preserved verbatim as planning history and replaced by the
current protocol table below.

| Test ID | Gate | Artifact | Required environment | Procedure | Expected | Status |
|---|---|---|---|---|---|---|
| V2-G2-001 | Inert hooks | TBD | Apple Silicon Mac local world | Install observer-only Init/BeginPlay/GetNetMode hooks; play 15 minutes without hosting | Counters increment; no visual/FPS/weather regression | NOT RUN |
| V2-G3-001 | IP transport | TBD | Mac host + physical iPhone | Start one listen session; connect by LAN IP/UDP port | Bound port and valid remote UNetConnection | NOT RUN |
| V2-G4-001 | Replication | TBD | Mac host + physical iPhone | Connect, move client far from host, interact/harvest; observe host visuals | Required remote replication; normal host sky/weather/FPS | NOT RUN |
| V2-G5-001 | New player | TBD | Mac host + fresh client identity/character state | Connect and follow character creation | Gameplay-ready pawn/HUD/player data exactly once | NOT RUN |
| V2-G5-002 | Returning player | TBD | Mac host + previously saved client identity | Disconnect/reconnect/full restart as specified | Existing character/player data restored | NOT RUN |
| V2-G6-001 | Client return | TBD | Connected physical iPhone | Invoke validated return-to-menu path | Transport detaches; MainMenu world; no stale state | NOT RUN |
| V2-G7-001 | Manual save | TBD | Active host and returning client | Explicit save, full app restart, reconnect | Save completion observed and world/player state restored | NOT RUN |

All are `unverified` and must not be reused as execution IDs.

## Current V2 gate protocols

| Protocol ID | Roadmap gate | Required artifact/environment | Procedure summary | Exit observation | Current state |
|---|---|---|---|---|---|
| PLAN-G1-STATIC-001 | 1 — typed identity spine | host-local test target | Clean build; layout/ownership/identity/reflection negative tests; forbidden dependency/raw-access audit | Deterministic tests pass and unsupported/malformed profiles fail closed | executed as `V2-G1-STATIC-001`; statically validated |
| PLAN-G1-PACKAGE-001 | 1 — inert packaging supplement | `com.mhga.serverhost.v2` package on Apple Silicon Mac iOS environment | Install; launch ShooterGame 1.10280 once; capture the single V2 console line; observe menu/game without invoking any feature | Build ID and missing-evidence state shown; `hooks=0 engine_calls=0 mutation=0`; no behavior change | ready for device test; no result yet |
| PLAN-G2-READ-001 | 2 — read-only discovery | V2 diagnostics package on Apple Silicon Mac | Launch; capture UUID/profile/name/object/Engine/World report; natural map enter/leave; 10-minute observation | Exact one-profile match, valid live relationships/generation invalidation, no behavior change | unverified/no artifact |
| PLAN-G3-DISPATCH-001 | 3 — dispatcher/lifecycle | same current profile, diagnostic no-op commands | Submit from UI/render; verify game-thread drain, overflow/shutdown and world-generation timeline; background/foreground | One bounded game-thread path, no UI UE mutation or stale identity | unverified/no artifact |
| PLAN-G4-HOOK-001 | 4 — inert hooks | diagnostics package, selected reviewed backend | Install/original/uninstall; no-host 15-minute A/B; thread lifecycle and foreground/background | Exact original return, reversible transport, bounded counters, no visual/performance regression | unverified/no artifact |
| PLAN-G5-CLIENT-001 | 5 — typed client travel | physical iPhone V2 client + known control host | Connect/return twice; capture travel/connection/controller identity timeline | Transport/controller/gameplay states separated; cleanup invalidates identities; no secret logs | unverified/no artifact |
| PLAN-G6-HOST-001 | 6 — native host + IP listen | Apple Silicon Mac host + physical iPhone | Native preparation; one Listen; verify port/driver/world; connect; stop; start again | One owned GameNetDriver/IpNetDriver, remote connection and clean start/stop/start without mode forcing | unverified/no artifact |
| PLAN-G7-REPL-001 | 7 — replication | same map/path/characters for A/B/C | Near/far movement and interaction; original/native setup vs legacy control/current forced reference; 20-minute hosted run | Far replication plus normal host sky/weather/render/audio/animation and explanatory counters | unverified/no artifact |
| PLAN-G8-NEW-001 | 8 — remote gameplay/new | fresh client identity/character state | Join twice through character creation; record full player identity/state timeline and RPC count | HUD, PlayerData, pawn, possession and controllable gameplay exactly once per session | unverified/no artifact |
| PLAN-G8-RETURN-001 | 8 — remote gameplay/existing | previously established character identity | Join twice without recreating character; record native/fallback flow | Existing character reaches controllable gameplay without duplicate recovery | unverified/no artifact |
| PLAN-G8-RECONNECT-001 | 8 — remote gameplay/reconnect | connected physical iPhone | Disconnect and reconnect within same host session; 30-minute gameplay soak | New valid identity/session, no stale dispatch, stable visuals/replication/logs | unverified/no artifact |
| PLAN-G9-LIFECYCLE-001 | 9 — repeated sessions | Mac host + physical client | Three leave/rejoin sessions including one network loss | Cleanup observed; no stale state/duplicate recovery; subsequent reconnect succeeds | unverified/no artifact |
| PLAN-G10-SAVE-001 | 10 — manual save | stable active host/client | Explicit save; observe completion; fully terminate; restart/reload | Expected world/player state persists; no GetNetMode policy exception | unverified/no artifact |
| PLAN-G12-SOAK-001 | 12 — iOS stability | release-candidate exact build | 60-minute host soak plus new/existing/reconnect, near/far, world/background/network cycles | All preceding device-verified claims hold with bounded resources/logs | unverified/no artifact |

Gate 11 administration receives a separate protocol ID for each operation only
when that operation becomes active; no generic administration row is pre-blessed.

## Immutable execution-row format

Append one row per actual artifact/protocol execution:

| Test ID | Date | Artifact path / SHA-256 / build ID | Host and client environment | Protocol | Result | Claim state after | Evidence/report |
|---|---|---|---|---|---|---|---|
| V2-G1-STATIC-001 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/.build/v2-host/serverhost_v2_core_tests` / `fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5` / `gate1-static-20260818` | Apple Silicon Mac, arm64 macOS host-local; no game/client | `PLAN-G1-STATIC-001`: clean C++20 `-Werror` build, 56 assertions, dependency/raw-access audit; independent legacy build | PASS | Gate 1 compiled and statically validated only; all live/runtime/device claims remain unverified | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md) |
| V2-G1-PACKAGE-BUILD-001 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb` / `4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35` / `gate1-inert-package-20260818.1` | Apple Silicon Mac local cross-build; no game/client execution | `make -f SourceV2.mk ios-package`; rerun 56 assertions/audit; inspect Debian metadata/listing, arm64 Mach-O, plist, signature, staged bytes and banned gameplay symbols/strings | PASS | Package compiled and statically inspected; ready only for `PLAN-G1-PACKAGE-001`; runtime remains unverified | [Gate 1 packaging supplement](evidence/GATE1_TYPED_FOUNDATION.md#inert-ios-packaging-supplement) |
| LEGACY-SKY-FAIL-001 | 2026-08-18 | Deleted installed legacy `.deb`; supplied SHA-256 `217c15cba0f634ee9427b219d30f17a2f917045d9683f35ea8bbc02079cb15f4`; bytes/build metadata unavailable | Apple Silicon Mac iOS host; OS/app UUID, map, client, attempt count and package inventory not supplied | User reports that after this later legacy hosting-hook workflow becomes active, host sky/weather/world light or effect animation changes abnormally | FAIL | Host visual stability for the hash-identified reported artifact/workflow is contradicted. Hash identity does not recover source; exact cause and transfer to V2 remain unverified. | [Failure intake](evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md) |
| LEGACY-0.2.24-CONTROL-BUILD-001 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-4+debug_iphoneos-arm.deb` / `2a23ba8c9286085a79dced8ecb07464b48e9be3be32189bea98f1bb3cb64c87c` / `0.2.24-4+debug` | Apple Silicon Mac local cross-build; no game/client execution | `make -B all`, then `make package`; inspect ar/control/data members, metadata, arm64 staged dylib and embedded CodeDirectory | PASS | Current source compiled and package was statically inspected only. Host behavior, hook transport and visual stability remain unverified/contradicted as recorded by `LEGACY-SKY-FAIL-001`. | [Failure intake](evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md) |
| V2-G1-STATIC-RECHECK-002 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/.build/v2-host/serverhost_v2_core_tests` / `fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5` / unchanged Gate 1 core | Apple Silicon Mac host-local; no game/client execution | `make -f SourceV2.mk all test audit`; direct `reinterpret_cast`, `.data() +` and raw-access inventory scan | PASS | 56 assertions and dependency audit still pass; zero production `reinterpret_cast`/raw pointer arithmetic found. This does not validate any live hook, layout, reflection or device behavior. | [Failure intake](evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md) |
| LEGACY-0.2.24-ORIGINAL-NETMODE-BUILD-001 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-5+debug_iphoneos-arm.deb` / `dfae573863c86146e51d72dd5cb9f039708f342b63badf0229b39531ff3bdb7d` / `0.2.24-5+debug`; embedded dylib `5210b435a65fd46a46186b89d14475fcdaeef89ec4db0d290e8dbf3f5dbeb55e` | Apple Silicon Mac local cross-build; no game/client execution | Read-only IDA MCP trace, then `make -B all SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE=1` and matching package; inspect Debian members/metadata/listing, arm64 dylib, embedded CodeDirectory and diagnostic strings; rebuild default-off legacy selection; rerun V2 56 assertions/audit | PASS (build only) | B/diagnostic is ready for exactly the bounded A/B protocol in the failure report. It preserves hook/host path and returns original NetMode. No visual, hosting, replication or transport claim is promoted until device results are supplied. | [Failure intake](evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md) |
| LEGACY-0.2.24-FORCED-MATE-BUILD-001 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb` / `d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e` / `0.2.24-6+debug`; embedded dylib `739b9b994d3f1f4b940f126ff041cc2b426a4db26fe5fb4674537bac9541f439` | Apple Silicon Mac local cross-build; no game/client execution | Package independently rebuilt default-off (`SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE=0`) from the same gated source as diagnostic B; inspect Debian members/metadata/listing, arm64 payload and embedded CodeDirectory | PASS (build only) | This is the exact same-source A/forced selection for the bounded protocol. The older `-4` package remains rollback/reference only. No runtime claim is promoted. | [Failure intake](evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md) |
| LEGACY-0.2.24-ORIGINAL-NETMODE-BUILD-002 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-7+debug_iphoneos-arm.deb` / `bf566b6ee77e4ef28fee1099314345a9d31e45e46166519004c4df19b4873956` / `0.2.24-7+debug`; embedded dylib `d88a71290c33856b60ae133b29ee94469416cdb7f097f742ac408d3913705d75` | Apple Silicon Mac local cross-build; no game/client execution | Rebuild unchanged `SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE=1` selection after A and package at a monotonic revision; inspect metadata and arm64 payload | PASS (build only) | This is the protocol B/original artifact to install after A `-6` without downgrade. Earlier B `-5` remains preserved but is not the protocol artifact. No runtime claim is promoted. | [Failure intake](evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md) |
| LEGACY-NOHOST-EXIT-001 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb` / `d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e` / `0.2.24-6+debug` | Apple Silicon Mac iOS host; exact macOS/app UUID/map/tweak inventory not supplied | Open ServerHost UI; do not press Start or invoke another command; application closes after approximately 1–2 minutes; no log/crash artifact retained | FAIL | No-host stability for A is contradicted. The host-visual A/B is suspended. Forced-NetMode policy is not implicated by this pre-Start result; UI visibility, constructor hooks, continuous Tick and unconditional pre-host NetDriverDefinitions mutation remain competing active variables. | [No-host delayed-exit intake](evidence/IOS_1.10280_NOHOST_DELAYED_EXIT.md) |

Current clarification: the earlier build-only rows remain accurate compilation
results. `LEGACY-NOHOST-EXIT-001` is withdrawn by the user's clarification: a
world was open and hosting had started. Do not use that row as a no-host result.

| LEGACY-HOST-SIGNAL-EXIT-001 | 2026-08-18 | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb` / `d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e` / `0.2.24-6+debug` | Apple Silicon Mac iOS host; world open and host started; exact world/macOS/app UUID/tweak inventory and signal stack not supplied | User clarification plus macOS Console excerpt: unopened/unused ServerHost is stable; host-started execution prints `GASignalHandler entered`, submits an error event, then closes | FAIL / READY FOR BOUNDED DEVICE TEST | Exact IDA proves GameAnalytics catches one of signals 3–8, 10–14, 24 or 25 and calls `_Exit(1)`, but discards the signal number. Same package means source/package delta is zero; host activation and panel visibility changed together. Next test: same A and successful Start, then panel hidden versus visible for five minutes. | [Corrected host-started signal intake](evidence/IOS_1.10280_HOST_STARTED_SIGNAL_EXIT.md) |
| LEGACY-HOST-SIGNAL-CONSOLE-001 | 2026-08-18 | Console file `/Users/grimreaper31/.codex/attachments/9991530b-8a5a-4cfc-9e4f-8b2568ad77f0/pasted-text.txt`; SHA-256 `5e2a9c96de5eadee767454cebb06539b82b6c983d5d224b910f1aec0bf3a1a08`; exact A package identified by parent result | Apple Silicon Mac iOS host PID 13001; panel hidden/visible arm not supplied; earlier separate failure PID 12587 | Inspect all 1,303 lines; locate foreground activation, ordinary lifecycle/network events, unique signal marker and following error upload; compare to exact IDA handler and earlier PID-12587 excerpt | FAIL REPRODUCED / ARM UNCLASSIFIED | `GASignalHandler entered` occurs once at 15:17:21.531409, 143.743619 seconds after foreground activation. Error upload finishes 0.252198 seconds later and is the final line. PID 12587 independently reached the same marker. Zero `[ServerHost]` logs, no signal number and no stack; cannot select a patch or classify arm H/V. | [Corrected host-started signal intake](evidence/IOS_1.10280_HOST_STARTED_SIGNAL_EXIT.md) |

The original-NetMode visual A/B remains suspended until the exact `-6`
post-Start hidden-versus-visible control establishes a stable hosted baseline.

Append future executions below this row and never reuse an ID.

Optional `V2_SANITIZERS=1` execution is pending. The local ASan runtime did not
reach the test entry point, so it is not included in the PASS above and no
sanitizer validation is claimed.

PASS can promote only the exact tested claim. FAIL or MIXED immediately marks
the affected runtime claim `contradicted` or `unverified` and triggers the
failure-intake workflow; compile/static states may remain true.

## User failure-report template

```text
Test ID / Roadmap gate:
Date/time and timezone:
Package absolute path:
Package SHA-256 and build ID/version:
Enabled and disabled experimental capabilities:
Runtime build/profile/UUID shown by the mod:

Host hardware, OS/runtime, app build:
Client hardware, OS/runtime, app build:
Map, endpoint and network topology:
Character/account scenario (redact private IDs):
Control package/result used for comparison:

Starting state:
Exact numbered actions and timing:
Expected result:
Observed result:
Last correct and first incorrect visible state:
Reproducibility (x/y attempts):

In-game/ImGui log excerpt or file path:
macOS/iOS console log path:
Crash report/symbolication path:
Screenshots/video path and timestamps:
Other artifacts:

Affected claim/workflow:
Anything that still worked:
```

On receipt, append an execution row, downgrade Status/Evidence immediately,
preserve the earlier conclusion in History, isolate one failing workflow and do
not add another feature. After the cause and next package are known, update the
same living documents again and assign the next test a new ID.
