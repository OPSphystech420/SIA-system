# Server-Host V2 evidence registry

This index distinguishes observed/current facts from architecture decisions and
unproven explanations. Detailed implementation-time function/layout cards will
live under [`docs/v2/evidence/`](evidence/README.md) and link back here. Keep
this file a bounded registry; do not paste long decompilation or device-log
narratives into it.

Status vocabulary:

- `device-verified` — passed the stated live test;
- `exact-binary` — supported by disassembly/decompilation of the named current
  binary/database;
- `preserved-binary` — supported by strings, symbols or disassembly of the
  preserved artifact, without claiming recovered source;
- `sdk-confirmed` — emitted by both current FreshSDK dumps and compared;
- `source-confirmed` — directly present in local current/reference source;
- `source-pattern` — useful implementation example, not current ABI evidence;
- `closest-engine-source` — engine lifecycle evidence from UE4.17, below the
  current binary in precedence;
- `hypothesis` — plausible but not established;
- `contradicted` — higher evidence disproved a claim;
- `unknown` — not investigated sufficiently.

Artifact/readiness states are separate from evidence-source status:

| State | Required meaning |
|---|---|
| `compiled` | Named build command succeeded for a named artifact. |
| `statically validated` | Named assertions/profile/source/unit checks passed. |
| `ready for device test` | Unique artifact plus exact protocol exists; no pass yet. |
| `device verified` | User supplied a passing result for that exact artifact/environment/protocol. |
| `contradicted` | Higher evidence or a device result disproved the runtime/ABI claim. |
| `unverified` | Evidence is missing, stale, mixed or not transferable to the current V2 claim. |

The registry must state both dimensions when relevant. For example, an artifact
can be compiled while its host behavior remains unverified.

## 1. Established facts and source facts

| ID | Claim | Status | Evidence / limits |
|---|---|---|---|
| EV-001 | Legacy 0.2.11 allowed a physical iPhone to enter gameplay on an Apple Silicon Mac host. | device-verified | User’s known control and preserved deb. The original matching source snapshot has not been recovered. |
| EV-002 | The missing late-listen client HUD/character flow was restored by a game-owned server-authoritative RPC pair. | device-verified | The control produced HUD, PlayerData, pawn and possession after dispatch of `ClientSetHUDAndInitUIScenes` and `ClientShowCharacterCreationUI(false)`. V2 automation still requires a new device gate. |
| EV-003 | The preserved 0.2.11 arm64 dylib contains symbols/strings for runtime resolution, Listen, GetNetMode and recovery, and disassembly of `RecoverRemotePlayerUI` corroborates validation followed by the two RPCs. | preserved-binary | Deb SHA-256 `54dda1d682bc01f5fbd38a078a33994c23ffbe4ac6d466c978ffa86775ae8dbf`. Extracted using strings/symbols/disassembly. This is a behavior map, not recovered source and not proof of later 0.2.24 features. |
| EV-004 | Both FreshSDK trees describe ShooterGame/UE 4.26.2 and contain the Engine plus ShooterGame generated classes/functions needed for hosting research. | sdk-confirmed | `Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame` and `...-Full-Version`. |
| EV-005 | Relevant container, Basic, CoreUObject, Engine, ShooterGame structs/parameters/functions are byte-identical across the two FreshSDK dumps. The relevant ShooterGame class file differs by removal of `final` on 121 classes in Full-Version. | sdk-confirmed | File comparison. The difference represents Blueprint-derivation usability, not a near-term field/parameter layout conflict. |
| EV-006 | Current V2-candidate legacy `EngineObjects.hpp` contains nominal class tags while `HostingRuntime.mm` performs raw field, vtable, reflection and native access for many unrelated workflows. | source-confirmed | Current local `Source/UnrealEngine/EngineObjects.hpp`, `Source/Hosting/HostingRuntime.h/.mm`; exact count is not used as an architectural contract. |
| EV-007 | Current normal Host UI requests forced dedicated mode. | source-confirmed | `Menu/HostMenu.mm` passes true for the ForceDedicatedMode argument. |
| EV-008 | Current `ResolveNetMode` changes every GetNetMode result for the exact hosted GameNetDriver when forced, with a thread-local original-mode exception during synchronous save. | source-confirmed | `HostingRuntime::ResolveNetMode` and the synchronous-save bypass in the current source. |
| EV-009 | Current runtime uses a bounded 64-command ingress, `FIOSAsyncTask` scheduling, index/serial weak identities, function metadata checks, bounded logs and world-change cache resets. | source-confirmed | Useful concepts in `HostingRuntime`; implementation remains coupled and must be re-derived. |
| EV-010 | Current runtime also contains normal-build-disabled PostLogin/player-flow hooks and developer diagnostics, plus experimental save/admin/login-lock paths. | source-confirmed | Compile switches in Makefile and conditionals/methods in current runtime. Their presence does not prove ABI or behavior. |
| EV-011 | Exact iOS database `Extra_For_Host/110280.i64` is open for ShooterGame 1.10280; the unique GetNetMode body is at `0x103A4DE44`. | exact-binary | The function calls the driver IsServer virtual and returns Dedicated (1) or Listen (2) from engine client state, otherwise Client (3). Address is diagnostic for this image, not a portable binding. |
| EV-012 | The exact binary has 44 direct GetNetMode xrefs in 34 functions, and some callers distinguish Dedicated (1) from Listen (2). | exact-binary | Examples include `0x1011956E4`, `0x1035C832C`, `0x1035C89F8`, `0x1035D2340`, `0x1035D2564`, `0x1035D386C`. The latter group contains broad actor/stasis behavior and an `IgnoreStasisGrid` reference. Unidentified function names remain unknown. |
| EV-013 | Therefore broad forced Dedicated changes more than ordinary “server versus client” replication decisions. | exact-binary | Direct consequence of EV-011/012: exact callers execute different paths for 1 and 2. It does not, by itself, identify which path causes the observed sky/weather issue. |
| EV-014 | `UEngine::NetDriverDefinitions` is at current offset `0xBF8`; `FNetDriverDefinition` is size `0x18`; the exact CreateNetDriver path uses named primary/fallback definitions. | exact-binary + sdk-confirmed | `Reference/NetDriverDefinitions-1.10280.md`, exact iOS analysis and both FreshSDK dumps. Memory ownership for mutation remains unresolved. |
| EV-015 | Current FreshSDK places GameViewport at UEngine `0x780`; UWorld NetDriver at `0x1D8`; and provides current UNetDriver/connection, game mode/state, player controller/state/data layouts used as candidates. | sdk-confirmed | These are not callable/live contracts until runtime class/field validation passes. |
| EV-016 | Current recovery parameters are HUD class pointer size 8 and one bool byte for character-creation UI. | sdk-confirmed | ShooterGame parameters/functions in both FreshSDK dumps. This conflicts with older Dragon wrapper shape, so Dragon cannot supply this ABI. |
| EV-017 | UE4.17 UWorld::Listen creates the named GameNetDriver, associates it with world/level collections, calls InitListen and cleans up on failure; CreateNetDriver uses primary/fallback definitions. | closest-engine-source | `Engine/Private/World.cpp` and `UnrealEngine.cpp`. Exact 1.10280 binary outranks it for callable ABI and ShooterGame overrides. |
| EV-018 | UE4.17 GetNetMode returns Listen versus Dedicated for a server based on engine client state, matching the exact 1.10280 body’s broad semantics. | closest-engine-source + exact-binary | `Engine/Private/NetDriver.cpp` corroborates EV-011; it does not classify ShooterGame-specific callers. |
| EV-019 | UE4.17 GenericPlayerInitialization includes HUD initialization; PostLogin is the first normal point documented as safe for player RPCs, followed by starting-player logic. | closest-engine-source | `Engine/Private/GameModeBase.cpp`. Exact ShooterGame overrides/order still require 1.10280 analysis. |
| EV-020 | UE4.17 `FIOSAsyncTask` uses a synchronized task queue processed on the game thread and can requeue a callback. | closest-engine-source | `Core/Private/IOS/IOSAsyncTask.cpp`. Current 1.10280 entry/lifetime/background behavior needs device validation. |
| EV-021 | Existing hardware-breakpoint/trampoline code has no complete demonstrated contract for exception chaining, new-thread coverage, instruction relocation, reentrancy or uninstall; historical text modification caused an Invalid Page code-signing failure on iOS-on-Mac. | source-confirmed + observed failure | Current Hooks/Memory source, Sishen counterpart and recorded project history. This establishes risk, not that hardware breakpoints are impossible. |
| EV-022 | SEA guide defines useful control-plane states and operations—heartbeat, pending/running/success/failure commands, players, save/restart, backup and audit—but does not establish in-process UE ABI. | source-confirmed | `Extra_For_Host/SEA_host_guide.md`. Exact client-manager protocol is intentionally deferred to its workflow/database. |
| EV-023 | EOS is not required for the proven LAN Mac-host to iPhone gameplay control. | contradicted | EV-001/002 succeeded without Mac-host EOS authorization. Future public discovery/session behavior may have different requirements. |
| EV-024 | Exact Android `LibUE.so`/database path is not recorded in the current tree. | unknown | User reports a symbol-rich database exists. It must be requested when Android becomes active. |
| EV-025 | Exact iOS/SEA databases, both FreshSDK trees, Sishen, Dragon, UE4.17, decrypted 1.10280 app and EOSSDK binary exist at the canonical paths in README. | source-confirmed | Path check on 2026-08-18. Presence does not establish any unexamined ABI or behavior. |
| EV-026 | At the pre-implementation documentation refresh, no SourceV2 directory, V2 package or V2 device result existed. | historical source-confirmed / unverified runtime | Workspace inventory earlier on 2026-08-18. SourceV2 is superseded by EV-028 through EV-032 and package availability by EV-033; no V2 device result exists. |
| EV-027 | Root `STATUS.md` is a legacy 0.2.24 A/B snapshot, not V2 active status or V2 device verification. | source-confirmed | Its claims are preserved as legacy research inputs and require independent V2 gates. |
| EV-028 | Gate 1 now has a separate `SourceV2.mk` host target and curated SourceV2 core; the root legacy Makefile/source list remains unchanged. | source-confirmed + compiled | `make -f SourceV2.mk clean all` and independent `make clean all` succeeded on 2026-08-18. V2 links no legacy object. |
| EV-029 | Current FreshSDK core layouts used by Gate 1 are represented by compile-time size/alignment/used-offset assertions, without including FreshSDK. | sdk-confirmed + statically validated | Both dumps were compared; `Layouts_1_10280.hpp` compiled under `-Werror`. See [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md). No live-layout claim. |
| EV-030 | Gate 1 host tests pass malformed container/string/name/profile cases, const-correct borrowed strings, full index+serial+generation identity, and generation-aware reflection caching. | statically validated | `make -f SourceV2.mk clean all test audit`: 56 assertions, zero failures. Synthetic snapshots are not device/live validation. |
| EV-031 | Current sources expose two GUObjectArray roots: FreshSDK uses direct `TUObjectArray` at `0x5D434E8`; the legacy profile proposes `FUObjectArray` at `0x5D434D8`, whose object-array candidate begins 0x10 later. | source conflict / partial | Gate 1 asserts only the direct FreshSDK `TUObjectArray` shape and uses snapshot serials. Exact binary/live proof remains ABI-006. |
| EV-032 | Current FreshSDK confirms `UFunction` size `0xE0` and `FunctionFlags` at `0xB0`, but does not emit raw `NumParms`, `ParmsSize` or `ReturnValueOffset` members. | sdk-confirmed gap | Gate 1 stores these only in validated descriptors. Raw offsets and invocation remain ABI-007/008 and cannot be inferred from Sishen/legacy. |
| EV-033 | A separately identified inert V2 iOS package now compiles and contains only the curated Gate 1 production sources plus a one-shot fail-closed status entry. | source-confirmed + compiled/statically inspected | Package `com.mhga.serverhost.v2` build `gate1-inert-package-20260818.1`; SHA-256 `4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35`. Package listing, arm64 Mach-O, plist, signature and banned gameplay-symbol/string checks passed. No device execution claim. |
| EV-034 | The recorded legacy 0.2.11 control `.deb` is no longer present in the workspace after the Gate 1 clean legacy rebuild. | missing artifact / historical result retained | Theos clean rules match all packages with the legacy ID. Searches found no recoverable duplicate. The recorded hash and HIST-001 result remain evidence, but the file is not an available rollback artifact. |
| EV-035 | The user reports abnormal host sky/weather/world lighting or effect animation after a later legacy hosting-hook workflow becomes active. | contradicted / device-observed; immutable artifact hash supplied, file missing | The deleted failing package is identified by SHA-256 `217c15cba0f634ee9427b219d30f17a2f917045d9683f35ea8bbc02079cb15f4`. The runtime observation contradicts host visual stability for that artifact/workflow. Package bytes, map, exact transition timing, attempts, logs and crash artifacts remain unavailable, so the hash does not recover its source or prove target, transport, forced-Dedicated policy, host setup or another component caused it. See [failure intake](evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md). |
| EV-036 | A full forced rebuild of current legacy 0.2.24 and an installable current-source forced-policy investigation control succeeded. | compiled + statically inspected; runtime unverified | `packages/com.mhga.serverhost_0.2.24-4+debug_iphoneos-arm.deb`, SHA-256 `2a23ba8c9286085a79dced8ecb07464b48e9be3be32189bea98f1bb3cb64c87c`; staged arm64 dylib hash `07a4dda03d2cc7440b9bf6f1466dfdf29d761fb1661c4a97b2ca6e92a431ac61`. This post-report package is not the failing artifact, a rollback to 0.2.11, or a fix. Linker emitted only `-multiply_defined is obsolete`; Theos also emitted a non-code parallel-build notice. |
| EV-037 | Read-only MCP analysis of the open exact 1.10280 IDA database confirms the current GetNetMode entry/prologue and multiple policy-sensitive world paths. | exact-binary | `UNetDriver_GetNetMode` at `0x103A4DE44` calls virtual slot byte offset `0x3C0` (index 120, behavior consistent with `IsServer`) and returns Client 3, or Listen 2 versus Dedicated 1 from engine client state. The current `+0x10` replay resumes on the virtual call and is straight-line instruction-compatible, while exception/thread lifecycle remains unproved. `0x1035C89F8` takes dedicated-only actor initialization/registration exits; `0x1035D2340` applies a listen/standalone-only distance scale before actor proximity/relevancy checks; `0x1035D2564` and `0x1035D386C` change client exit, grid construction, stasis processing and dedicated-only early returns. These facts justify a policy-only A/B test, not a sky/weather causal or transport-safety claim. |
| EV-038 | A one-variable original-NetMode diagnostic package was built behind a default-off compile-time gate, then repackaged at a monotonic revision after A. | compiled + statically inspected; device protocol suspended | B/diagnostic: `packages/com.mhga.serverhost_0.2.24-7+debug_iphoneos-arm.deb`, SHA-256 `bf566b6ee77e4ef28fee1099314345a9d31e45e46166519004c4df19b4873956`, embedded arm64 dylib SHA-256 `d88a71290c33856b60ae133b29ee94469416cdb7f097f742ac408d3913705d75`. `SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE=1` changes only the normal Host request's force-policy boolean. It is not a fix; EV-041 requires a stable host-started baseline before this comparison. |
| EV-039 | The same gated source was independently rebuilt and packaged with the diagnostic variable default-off as the exact A mate for EV-038; the earlier EV-036 artifact remains a rollback/reference. | compiled + statically inspected; host-started device failure observed | A/forced: `packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb`, SHA-256 `d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e`, embedded arm64 dylib SHA-256 `739b9b994d3f1f4b940f126ff041cc2b426a4db26fe5fb4674537bac9541f439`. Build inspection passed. The same package is stable with ServerHost unopened/unused, but a host-started execution reached EV-041. |
| EV-040 | The initial report that exact A exited without Start was based on an ambiguous intake and was withdrawn after the user clarified that hosting was active. | withdrawn/reclassified, not a runtime result | Retained as an audit correction. It must not be cited as evidence that visible idle UI or constructor-installed hooks alone terminate the game. See the retained [withdrawn intake](evidence/IOS_1.10280_NOHOST_DELAYED_EXIT.md) and corrected EV-041. |
| EV-041 | Exact A `0.2.24-6` is stable while ServerHost remains unopened/unused, but the reported world-open, host-started workflow terminated after Console printed `GASignalHandler entered` in two separate processes (PID 12587 and PID 13001). | reproduced device-observed failure; exact signal/stack missing | Full PID-13001 1,303-line Console capture SHA-256 `5e2a9c96de5eadee767454cebb06539b82b6c983d5d224b910f1aec0bf3a1a08`: signal appears once, 143.743619 seconds after foreground activation; GameAnalytics upload finishes 0.252198 seconds later and the log ends. It contains no `[ServerHost]` transition lines and does not identify panel visibility. Same package/source bytes in control and failure. See [host-started signal-exit intake](evidence/IOS_1.10280_HOST_STARTED_SIGNAL_EXIT.md). |
| EV-042 | Exact IDA shows `GASignalHandler` is a GameAnalytics POSIX signal handler that submits an error event and calls `_Exit(1)`. | exact-binary | Handler `0x100BBA32C`; registration `0x100BBA1EC`; installation path `0x100BB9894`. It covers signals 3–8, 10–14, 24 and 25 but does not record the signal argument, so the Console excerpt proves signal-driven termination but cannot classify it as SIGSEGV, SIGABRT, SIGPIPE, resource signal, etc. |

## 2. Deep evidence index

- [Evidence report index and template](evidence/README.md)
- [NetDriverDefinitions 1.10280 report](../../Reference/NetDriverDefinitions-1.10280.md)
- [Architecture GetNetMode analysis and investigation boundary](ARCHITECTURE.md#9-hook-design-and-getnetmode-investigation)
- [ABI contract backlog](ABI_BACKLOG.md)
- [Gate 1 typed foundation evidence report](evidence/GATE1_TYPED_FOUNDATION.md)
- [ShooterGame 1.10280 GetNetMode host visual-regression failure intake](evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md)
- [ShooterGame 1.10280 host-started signal-exit failure intake](evidence/IOS_1.10280_HOST_STARTED_SIGNAL_EXIT.md)

Future exact function/caller/layout reports receive stable filenames under
`evidence/`, a summary row here and a corresponding ABI backlog update. Report
files may grow; this registry should remain quick to read.

## 3. Pattern evidence: Sishen

Sishen is the primary UE mod organization/wrapper authority, but all listed
examples are `source-pattern`, never current ABI proof.

| ID | Example studied | Established pattern / limitation |
|---|---|---|
| PAT-S01 | Sishen Makefile, SDK offsets/signatures and Memory source | Categorized build and centralized resolution are good organization. Recursive globs, global/singleton state, old fixed values and coarse pointer heuristics are not V2 contracts. |
| PAT-S02 | `GameStructs` and StaticClasses helpers for NetDriver/IpNetDriver, NetConnection, ShooterGameMode, PlayerController/ShooterPC, Engine, PrimalPlayerData, Kismet classes and World | Curated types and centralized class/default-object access are useful. Massive catalogs, ambiguous short-name lookup and forever-static raw UClass pointers are rejected. |
| PAT-S03 | Function wrappers including ServerMultiUse, MakeHitResult, ExecuteConsoleCommand, server RPCs, SetCheatPlayer, RespawnPlayer, GetPathName, Conv_StringToName and WorldSettings helpers | One wrapper with a local parameter record is the adopted style. Missing current metadata validation, FunctionFlags mutation, stale raw caches, ambiguous FString ownership and broad speculative wrappers are rejected. |
| PAT-S04 | `VMTHookManager`, `InitializeStaticOffsets`, `InitializeDefaultHooks`, constructor and tick/hook startup | Explicit recognizable phases and typed original calls are useful. Delayed constructor work, unvalidated writable CDO vtables, global hook managers and hot ProcessEvent logging are rejected. |
| PAT-S05 | Sishen hardware-breakpoint utility | It is a transport research input only and shares the current backend’s exception/thread/replay questions. Old target addresses/instructions are irrelevant to 1.10280. |

## 4. Pattern evidence: Dragon

| ID | Example studied | Established pattern / limitation |
|---|---|---|
| PAT-D01 | `Source/CppSDK/UsedSDK.hpp` and Makefile | Dragon generated broadly but compiled a small Engine/Shooter subset. V2 adopts explicit curation and further reduces it to reviewed layout/parameter slices. |
| PAT-D02 | generated Basic/CoreUObject/Engine/ShooterGame code | Typed fields and zero-initialized params improve readability. Old ABI, off-by-one object bounds, index-only weak equality, raw static caches and FunctionFlags mutation are rejected. |
| PAT-D03 | `FrameTaskManager.mm/.h` | Direct typed field/RPC use demonstrates desired feature readability. Public generated fields, an unbounded std::function queue and captured raw objects do not meet V2 ownership/thread rules. |
| PAT-D04 | Dragon entry/VMT hook setup | Delayed detached startup and CDO vtable swapping are not adopted. The source only shows why startup, binding and hook ownership need separate phases. |
| PAT-D05 | Dragon `FWeakObjectPtr::GetSafe`, `UsedSDK.hpp`, generated Shooter wrappers and `FrameTaskManager` queues/direct fields | Serial checking, explicit selected generated units and zeroed params informed the Gate 1 API. Index-only equality, stale caches, old no-bool recovery ABI, public generated fields and unbounded raw-capturing queues were rejected. |

## 5. Architecture decisions (not facts)

| ID | Decision | Fact basis |
|---|---|---|
| DEC-001 | Build V2 as a separate target and preserve legacy/control artifacts. | User selection, EV-001/003/006-010. |
| DEC-002 | Permit raw ABI only in UE low views, Bindings (including `Bindings/Platform`) and low Hooks; expose typed views/handles elsewhere. | EV-006/009/015/021 plus Sishen/Dragon pattern review and the explicit RULES.md directory boundary. |
| DEC-003 | Store index+serial+world generation; resolve a scoped borrow on game thread. | Current reuse/lifecycle risks, EV-009 and Dragon weak-pointer limitations. |
| DEC-004 | Curate FreshSDK per workflow rather than link it wholesale. | EV-004/005/015/016 and cross-build Dragon conflict. |
| DEC-005 | First hooks are inert observers; transport and policy are separate. | EV-011-013/021. |
| DEC-006 | Broad forced Dedicated and a caller-RVA whitelist are not production architecture. Prefer exact game-native host initialization. | EV-007/008/011-013. |
| DEC-007 | Keep recovery RPC pair as bounded compatibility fallback, not a substitute for investigating native player initialization. | EV-001-003/016/019. |
| DEC-008 | Save and administration are future narrow services, not methods on HostService. | Current experimental coupling, EV-010/022. |

## 6. Active hypotheses

| ID | Hypothesis | Current support | Falsifying/confirming action |
|---|---|---|---|
| HYP-001 | Abnormal host sky/weather is caused partly or wholly by broad forced Dedicated semantics. | EV-007/008, exact policy-sensitive actor/relevancy/stasis paths EV-011-013/037, and the hash-identified but byte-missing runtime failure EV-035. | Suspended: first establish a stable host-started baseline through EV-041's post-Start hidden/visible control, then run EV-039 A versus EV-038 B. |
| HYP-005 | The current hardware-breakpoint exception/replay transport causes the host-started signal exit or visual regression independently of GetNetMode policy. | Transport lifecycle/replay gaps in EV-021/ABI-024; EV-037 validates straight-line replay but not exception lifecycle; host activation increases GetNetMode traffic. | First run EV-041's same-package post-Start hidden/visible control. If both arms exit, use the final ServerHost transition/stack to select one transport or host-path diagnostic. |
| HYP-002 | Far-replication failure after late Listen results from skipped ShooterGame-native listen/dedicated initialization, not a need for every caller to see Dedicated. | Exact sensitive callers and closest-engine lifecycle make it plausible. | Trace all relevant state writes/callers in `110280.i64`, invoke only the proven native path, then run near/far device test with original GetNetMode. |
| HYP-003 | Native player initialization can eventually remove or narrow the recovery pair. | Closest engine source describes normal RPC-ready/HUD flow; control proves only the compatibility repair. | Exact Shooter override/caller analysis plus inert new/existing player timeline; compare native-success and fallback counts. |
| HYP-004 | An existing validated NetDriverDefinition may avoid V2-owned injection buffers. | Exact definition array/primary-fallback behavior is known. | Read-only live definition report followed by exact CreateNetDriver class/result; if unsuitable, prove mutation ownership separately. |

## 7. Conflicts and resolution

| Conflict | Resolution |
|---|---|
| Dragon’s older recovery wrapper shape versus current FreshSDK bool parameter | Current FreshSDK/current binary workflow wins. Dragon supplies style only. |
| Sishen/Dragon offsets, vtables and signatures versus 1.10280 | Exact iOS binary wins; old values are rejected without reuse. |
| Generated SDK public layouts versus feature safety | Layout declarations are evidence input; V2 exposes curated validated accessors, not public fields. |
| UE4.17 engine behavior versus 4.26.2 ShooterGame | UE4.17 provides lifecycle hypotheses/corroboration. Exact 1.10280 decompile and device outcome decide. |
| 0.2.11 symbols/disassembly versus absent source | Claim only observed/corroborated behavior. Do not reconstruct or attribute source implementation beyond binary evidence. |
| Current broad forced mode fixes some replication versus dedicated-sensitive unrelated callers | Preserve both facts. Investigate native initialization; do not canonize the workaround. |
| SEA operational guide versus injected host internals | Use SEA for future control-plane states/audit only; never use it as UE ABI evidence. |

## 8. Evidence records required by the next gate

- loaded Mach-O identity/profile card;
- FNamePool and GUObjectArray resolution/layout cards;
- current UE core curated layout comparison against both FreshSDK dumps;
- UClass/UFunction/FProperty live validation schema;
- static assertion report and negative profile/object fixtures;
- dependency/raw-access audit for the new host-local target.

Gate 1 produced those static artifacts in EV-028 through EV-032. The loaded
Mach-O identity, live name/object/reflection report and every device observation
remain Gate 2 work; the host tests do not satisfy them.

Later GetNetMode, native host, recovery, hook, save and administration evidence is
ordered explicitly in `ABI_BACKLOG.md` and may not be pulled into Gate 1 as a
speculative API.
