# Server-Host legacy-to-V2 migration map

This is a disposition map, not a request to move files mechanically. The legacy
target remains buildable and unchanged. “Migrate” below means re-express the
demonstrated behavior behind the V2 contracts in `ARCHITECTURE.md`; it never
means copy `HostingRuntime` into a new directory.

Classification vocabulary:

- **confirmed behavior** — observed on a device or corroborated by the preserved
  0.2.11 binary and current contract evidence;
- **useful infrastructure** — a sound intent or seam that should be rewritten;
- **diagnostic** — bounded research/support behavior, not a gameplay dependency;
- **experimental** — current code exists but its ABI, semantics or device result
  is not sufficient for V2;
- **rejected** — must not enter V2 architecture;
- **unknown** — evidence is insufficient even to select the implementation.

## 1. Current build and dependency anatomy

| Current area | Current responsibility/dependencies | Classification | V2 disposition |
|---|---|---|---|
| `Makefile` | One arm64 iOS Theos tweak; compiles Menu, Overlay, runtime, C guard, memory, hooks, UE core and vendored ImGui. Compile switches disable PostLogin hook and lifecycle autosave by default. | useful infrastructure | Preserved unchanged. Gate 1 added separate `SourceV2.mk` and `serverhost_v2_core_tests`; it shares no legacy runtime object files and does not replace the legacy build. |
| packaging/control files and recorded `packages/com.mhga.serverhost_0.2.11+debug_iphoneos-arm.deb` | Injection/package metadata and known behavioral control identity. The historical `.deb` file is now missing after a Theos clean. | confirmed historical behavior / missing artifact | Preserve the recorded hash/result, but do not claim an available rollback or reconstruct it from nonmatching source. V2 uses isolated `SourceV2/Build/IOS`, package ID `com.mhga.serverhost.v2` and `packages/v2`; Gate 1.5 makes raw `packages/v2/injection/<build-id>/ServerHostV2.dylib` plus dSYM/manifest the canonical Sideloadly handoff. `.deb` is archival/inspection-only. |
| `Menu/HostMenu.hpp/.mm` | ImGui inputs and direct calls into singleton runtime for Host, Client, return, broadcast, save, player/admin/kick/console and logs. Normal Host passes `ForceDedicatedMode=true`; failure investigation adds a default-off `SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE` build gate that changes only that boolean for diagnostic B. | mixed: useful UI; forced policy experimental; original-mode B compiled, device pending | Keep the known control layout only as a UX reference. Rewrite as `HostViewModel` + presentation. Initially expose diagnostics, then only controls whose gate passed. Do not migrate either forced-dedicated default, the temporary legacy compile gate, or direct runtime calls. |
| `MenuLoad/Includes.h` | Broad common/ImGui/STL type aggregation and utility aliases. | rejected dependency style | Use narrow per-file includes and Core fixed-width types. Do not introduce another umbrella header. |
| `MenuLoad/MenuBootstrap.mm` | UIKit/menu setup and runtime initialization. | useful infrastructure | Gate 1.5 adapts scene/window lookup, local SF Symbol fallback and drag behavior to main-thread lifecycle notifications plus bounded retry. UI shows unsupported/missing/Legacy refusal without enabling capabilities. Fixed startup sleep is rejected. |
| `MenuLoad/OverlayView.h/.mm` | Metal render hook, ImGui frame and 30 fps call to runtime Tick. | useful presentation; rejected gameplay scheduler | Gate 1.5 rewrites it as a SourceV2-only transparent snapshot renderer. Closed view is paused; open touch routing is limited to the ImGui window; no Tick, scheduler, resolver or engine access exists. |
| `Source/Hosting/HostingTypes.hpp` | Runtime state/command/snapshot values. | useful infrastructure | Replace with narrow service state enums, typed `Command` variants and immutable snapshots. Preserve the distinction between transport and player readiness. |
| `Source/Hosting/HostingConfig.h` | Signature patterns and hook/native target configuration. | useful evidence with mixed concerns | Split into BuildProfile function/signature cards and HookSpecs, each with current source/provenance/validator. |
| `Source/Hosting/HostingRuntime.h/.mm` | Nearly every engine, workflow, hook, queue, state, reflection, logging and raw-memory responsibility. | mixed; see method map | Do not copy. Split into RuntimeContext, dispatcher, services, diagnostics, typed model and binding layers. |
| `Source/UnrealEngine/GeneratedSDKProfile.hpp` and `Source/Offsets.h` | Current RVAs, offsets, vtable slots/native constants; `Offsets.h` aliases ProcessEvent index. | useful evidence, unsafe organization | Convert each used entry to a provenance-bearing profile/layout/function card. Remove aliases/unused constants. Match exact loaded-image identity and runtime validators before exposure. |
| `Source/UnrealEngine/CommonTypes.hpp`, `Containers.hpp`, `NameTypes.hpp`, `ObjectArray.hpp`, `ScriptCore.h/.mm`, `EngineObjects.hpp`, `Enums.hpp` | Custom UE primitives, container/name/object/reflection support, ProcessEvent, empty class tags and global bindings. Derived partly from Sishen. | useful foundation with correctness/lifetime risks | Re-derive the curated V2 core. Separate owned/borrowed arrays and strings, full weak identity, full-name reflection and scoped views. Empty tags and global mutable bindings are rejected. |
| `Source/Libraries/CGuardMemory/CGPError.h`, `CGPMemory.h/.cpp` | Guarded Mach reads, image/range/protection/signature facilities and error containment. | useful low-level infrastructure with coarse assumptions | Retain only proven checked operations under `Bindings/Platform`; exact mapped segments replace coarse address heuristics. Do not let guarded failure disguise an invalid ABI as a normal branch. |
| `Source/Libraries/HardwareBreakpointHook/HardwareBreakpointHook.h/.c`, `mach_excServer.h/.c` | Mach exception/debug-register interception, generated exception server and replay/original transport. | experimental | Quarantine behind `IHookBackend`; require thread lifecycle, prior-port chaining, relocated-instruction, register, reentrancy, uninstall and soak evidence. Generated MIG transport remains backend detail. |
| `Utilities/Memory.h`, `Utilities/Singleton.h` | Older singleton image/RVA/read/write/call helpers and generic singleton templates; not compiled by the current Makefile. | diagnostic/legacy reference; rejected feature infrastructure | Do not migrate. Useful pitfalls (coarse address range, global image lookup, arbitrary read/write/call) inform negative dependency tests. |
| vendored ImGui | UI rendering. | useful external dependency | Gate 1.5 links existing local core/Metal backend sources explicitly into the V2 iOS target. UI-only; no engine dependency. Keep third-party code outside SourceV2 review scope unless modified. |
| `ServerHost.plist`, `control` | Bundle filter, MobileSubstrate dependency and package identity/version. | useful build/package infrastructure | Preserve legacy values. V2 uses a separately identifiable package/bundle version while targeting the same game only after an explicit build gate. |
| `.theos/` and `packages/` | Local build products and historical deb artifacts. | generated outputs / preserved controls | Never treat `.theos` as source. Preserve historical debs; every V2 artifact gets a unique full path/hash and is not allowed to overwrite the 0.2.11 control. |
| `Reference/LegacySDK/*` | Older aggregate header, objects dump and signatures/offsets. | diagnostic historical input | No direct V2 ABI use; exact binary/current FreshSDK override it. |
| `Reference/FreshSDK/*` | Two generated current SDK dumps. | sdk evidence/tool input | Never compile wholesale into V2. Curate layouts, params and names required by a workflow and validate them. |
| `Reference/NetDriverDefinitions-1.10280.md`, `Extra_For_Host/SEA_host_guide.md`, Sishen, Dragon, UE4.17 | Binary research, control-plane semantics, patterns and engine lifecycle reference. | evidence/pattern sources | Cite in contract cards. Never import reference ABI values by analogy. |
| `docs/v2/*` and root `STATUS.md` | Durable V2 requirements/evidence versus legacy operational status. | requirements/status | V2 tasks update required v2 documents; root status remains the legacy operational reference unless that workflow explicitly changes it. |

## 2. HostingRuntime responsibility split

The current class owns all of the following, which is why a seemingly local
change can affect networking, UI, save and object lifetime together:

- signature/image resolution and global UE binding initialization;
- hardware hooks, original trampolines and hook policy;
- render-to-game-thread scheduling and a bounded command queue;
- Engine/World/NetDriver discovery, raw fields and reflection caches;
- host patching, Listen, GetNetMode policy and Ark login lock bypass;
- client travel/return-to-menu and connection diagnostics;
- remote-player discovery, persistence probes and two-RPC recovery;
- save, stop, broadcast, admin, kick, console and developer calls;
- lifecycle/world invalidation, snapshots, log buffering and error strings.

The following method-level map is exhaustive by responsibility for the current
public/private `HostingRuntime` surface.

| Current method(s) | Current behavior | Classification/evidence | V2 owner and disposition |
|---|---|---|---|
| `Get`, constructor/destructor | Global singleton and storage for all state. | rejected architecture | `RuntimeComposition` owns explicit objects and shutdown order. No gameplay singleton. |
| `Initialize` | Initializes addresses, hooks and state, often from loader/UI lifecycle. | useful intent | `V2Entry` runs explicit Identify -> Resolve -> Validate -> Compose -> Observe phases and fails closed. |
| `ResolveRuntimeAddresses` | Resolves signatures/RVAs, initializes GUObjectArray/FNamePool/realloc/ProcessEvent. | useful infrastructure with raw ABI | `BindingResolver` + `ContractValidator`; unique exact-image contracts only. |
| `InstallHooks`, `InstallTargetedPlayerFlowHooks` | Installs lifecycle/GetNetMode and optional player-flow hooks. | base transport experimental; targeted player flow rejected until proven | `HookManager` installs inert policies only at first. Native PostLogin/HandleNewPlayer/StartNewPlayer hooks remain ABI backlog items. |
| `Tick` | Called by Metal, throttles and schedules engine work. | mixed | Delete as central heartbeat. UI reads snapshots; `IOSGameThread` schedules dispatcher/lifecycle drain. |
| `ScheduleGameThreadTick`, `MarkGameThread`, `IsOnGameThread`, `GameThreadTick` | Bridges through `FIOSAsyncTask`, identifies game thread, then runs lifecycle/workflows. | useful infrastructure; closest UE source corroborates scheduler shape | `IGameThreadScheduler`, `ThreadToken`, `CommandDispatcher`, `WorldLifecycle`. Device-prove thread behavior. |
| `Enqueue`, `DrainCommands` | Fixed 64-entry command queue and switch dispatch. | useful infrastructure | Bounded typed MPSC ingress; explicit overflow result; no raw captures. One game-thread consumer. |
| `RequestHost`, `ExecuteHostRequest` | Stores options, patches definitions, applies login bypass/forced mode and starts Listen. | transport partially evidenced; policy experimental | UI command -> `HostService`. Split native preparation, definition, Listen and postconditions. Do not migrate forced mode/login bypass without proof. |
| `Disable`, `ExecuteDisable` | Alias/older disable path. | diagnostic/legacy compatibility | No duplicate V2 path. One HostService stop transition after its gate. |
| `Join`, `RequestJoin`, `ExecuteJoin` | Builds UTF-16 URL/options and calls `UEngine::SetClientTravel`, refusing an existing connection. | useful, ABI partially evidenced | `ClientService` + `OwnedFString` + `IEngineNative::SetClientTravel`; exact string ownership and device transport gate required. |
| `RequestReturnToMenu`, `ExecuteReturnToMenu` | Finds reflected QuitToMainMenu and dispatches it. | experimental | ClientService cleanup workflow after current function metadata and device proof. |
| `RequestBroadcast`, `ExecuteBroadcast` | Reflected/native broadcast path. | experimental administration | Future `AdministrationService` operation with its own ABI/audit/device gate. |
| `RequestSaveWorld`, `ExecuteSaveWorld` | Synchronous GameMode vtable slot call with thread-local GetNetMode original-mode bypass. | experimental; result/persistence not proven | Future `SaveService`; exact slot/call ABI/mode dependency, completion receipt and restart persistence must be proved. No autosave migration. |
| `RequestSetRuntimeAdmin`, `ExecuteSetRuntimeAdmin` | Attempts runtime admin mutation. | experimental | Future per-command Administration binding; identity, authorization assumption and postcondition required. |
| `RequestAdminCheat`, `ExecuteAdminCheat` | Attempts admin cheat call. | experimental | Deferred; not a generic console substitute. |
| `RequestKick`, `ExecuteKick` | Selects player and invokes kick flow. | experimental and lifetime-sensitive | Future AdministrationService using full identity, reason ownership, audit and observed disconnect. |
| `RequestConsoleCommand`, `ExecuteConsole` | Runs a broad console command. | rejected as early generic API; future constrained operation unknown | No generic V2 binding. Consider an allow-listed command only after bounded administration gates. |
| `RequestDeveloperProcessEventExample`, `ExecuteDeveloperProcessEventExample` | Demonstrates reflected call. | diagnostic | `DeveloperProbe` only, compiled out of release and never a service dependency. |
| `RequestDeveloperHarvestProbe`, `ExecuteDeveloperHarvestProbe` | Reads/dispatches harvest-related research operation. | diagnostic/experimental | Do not migrate with hosting. Re-open only as a separately approved future workflow. |
| `PatchCurrentNetDriver`, `ExecutePatchCurrentNetDriver` | Mutates current NetDriver-related state. | experimental | No generic patch operation. Any required mutation belongs to an evidenced HostService step with typed binding/postcondition. |
| `FindEngine`, `ValidateLiveEngine`, `FindWorld` | Scans objects/reads raw fields and caches Engine/World. | useful but lifetime/raw risks | `EngineView`/`WorldView`, ObjectHandle and RuntimeContext generation. Full-name/class/relationship validation. |
| `MakeName` | Constructs/finds FName through current pool/utilities. | useful foundation | `INameResolver`; creation method must be proven, read lookup may be earlier. |
| `PatchNetDriverDefinitions` | Replaces/injects GameNetDriver definition with IpNetDriver and manages engine TArray/string data. | useful transport experiment; ownership risk | Narrow Host preparation binding after array/string ownership proof. Prefer existing validated definition where possible. Exact 1.10280 binary documents primary/fallback creation. |
| `TryStartHosting` | Calls UWorld::Listen and verifies resulting driver/world. | useful transport path; not complete game-native initialization | `IEngineNative::Listen` invoked by HostService after native preparation contract. Preserve exact postconditions. |
| `ApplyArkLoginLockBypass` | Changes login-lock behavior by reflected/raw flag. | experimental | Do not migrate. Prove actual rejection condition and native setup first. |
| `ResolveNetMode` | Returns Dedicated for all callers on exact hosted driver when forced; samples calls; TLS save bypass. | experimental behavior with exact broad semantic impact | First V2 version is inert observer and original return. Replace only through native initialization or a separately evidenced semantic policy. Never carry over TLS save coupling. |
| `OnEngineInit`, `OnWorldBeginPlay` | Hook callbacks drive/publish lifecycle state. | useful observation, hook transport experimental | `LifecycleObserver` records inert event; WorldLifecycle confirms state on game thread. |
| `RouteHostedPostLogin`, `OnNativeHandleNewPlayer`, `OnNativePostLogin`, `OnNativeRealPostLogin`, `OnNativeStartNewPlayer` | Optional native player-flow interception/routing, including manual RealPostLogin. Compile-time disabled in normal build. | experimental/rejected until exact call chain is proven | No Gate 1–7 migration. PlayerJoin observes native results, then uses confirmed RPC fallback. Add a native binding/hook only from an exact ABI card later. |
| `EnsureProcessEventDiagnosticsHook`, `OnDiagnosticProcessEvent` | Broad ProcessEvent observation for research. | diagnostic with severe hot-path risk | Developer-only bounded probe after hook backend gate; never required for normal hosting. No formatting/reflection inside callback. |
| `MakeWeakIdentity`, `ResolveWeakIdentity`, `SameIdentity` | Index/serial object identity utilities, with narrow serial-zero allowances. | useful infrastructure | `ObjectIdentity` + ObjectHandle; equality includes index, serial and world generation. Remove silent serial-zero exceptions unless a specific contract proves them. |
| `ValidateProcessEventTarget`, `DispatchBaseProcessEvent` | Validates target/function and dispatches raw PE. | useful binding intent | `ScriptInvoker`; thread token, full identity/function metadata, typed params, no flag mutation. |
| `ResolveFunctionCached` | Finds UFunction, validates metadata and caches weakly. | useful infrastructure | `ReflectionRegistry`; cache key includes full name/class and world/build generation. Return descriptor/handle, not raw static pointer. |
| `GetAuthorityGameMode` | Reads world authority mode. | useful typed relationship | `WorldView::AuthorityGameMode` returning identity/typed borrow. |
| `RecoverRemotePlayerUI`, `ExecuteManualRecovery`, `TransitionRecovery`, `DispatchRecoveryRPCs`, `UpdateRecoveryState` | Tracks late-listen player objects and dispatches ClientSetHUDAndInitUIScenes plus ClientShowCharacterCreationUI(false). | confirmed behavior for 0.2.11 control; current automation needs V2 device validation | `PlayerJoinService` state machine + `IPlayerFlowScript`. Preserve once-per-full-identity semantics and all preconditions; recovery remains fallback. |
| `PopulatePlayerOnlineIdentity`, `PopulatePlayerPersistence` | Reads identity/persistence fields to enrich player/recovery tracking. | diagnostic/partially useful; field contracts not all proven | Add only the stable identity/readiness fields required by PlayerJoin. Other persistence reads stay DeveloperProbe/ABI backlog. |
| `LogStasisRegistrationSnapshot`, `LogPlayerPersistenceLookupSnapshot`, `UpdateConnectionDiagnostics` | Bounded but deep state probes for replication/persistence/connections. | diagnostic | Convert only required values into typed ContractReport/Snapshot. Research probes have expiry questions and fixed budgets. |
| `ResetWorldDependentCaches`, `HandleWorldChanged` | Invalidates cached pointers/flags on travel. | useful and essential | `RuntimeContext` generation + WorldLifecycle; services receive invalidation before further work. |
| `ExecuteStop` | Optionally saves, calls DestroyNamedNetDriver and verifies null. | mixed: driver destruction useful; save coupling experimental | HostService stop only after transport gate. Save is a separate explicit command. Exact destroy binding and cleanup postcondition required. |
| `Snapshot`, `AddLog`, `AddLogOnce`, `SetStatus`, `SetError`, `ClearLogs` | UI snapshot, bounded/redacted logging and shared state strings. | useful infrastructure | Immutable typed Snapshot, structured bounded Logger/Breadcrumbs. Services own states/errors; UI cannot clear engine state by clearing logs. |

## 3. User-visible behavior map

| User-visible behavior | Current implementation chain | Evidence level | V2 chain / release rule |
|---|---|---|---|
| Open overlay/menu and remain idle | dylib constructor resolves/installs three hooks; always-running MetalOverlay calls Tick; Engine discovery/Init can patch NetDriverDefinitions before any command; visible HostMenu adds rendering/snapshot work | source-confirmed; exact no-host failure claim withdrawn; unopened/unused control stable | ImGuiHostPanel -> immutable HostViewModel. Presentation may ship only with no UE dependency, no constructor hook and no Engine mutation. Gate 2 diagnostics must remain inert while the panel is hidden or visible. |
| Start host | HostMenu forces Dedicated -> RequestHost -> definition patch/login bypass -> Listen -> driver checks | transport pieces binary/source-confirmed; full policy experimental | command -> HostService -> validated native preparation -> `IEngineNative::Listen` -> TransportReady receipt. Hidden until device gate. |
| Join host | UI -> Join -> SetClientTravel URL | source/binary contract partially confirmed | ClientService typed travel and physical-device transport test. |
| Remote player reaches gameplay | connection discovery -> recovery state -> two client RPCs | device-verified in 0.2.11; deb symbols/strings/disassembly corroborate behavior map | PlayerJoin observes native flow, then one bounded typed recovery fallback; new/existing/reconnect each pass. |
| Host process remains alive | Start -> definition/login preparation -> Listen -> hosted-driver publication and active GetNetMode policy; visible menu copies/renders live snapshots | archived Legacy A `-6` host-started signal exit; signal class and stack unknown | historical research only. It does not block Gate 2; V2 host/hook behavior remains unavailable until its later ordered gates. |
| Host sky/weather remains normal | currently broad forced dedicated can alter engine/game callers | archived Legacy failure for deleted artifact SHA-256 `217c15…15f4`; exact policy-sensitive callers confirmed | retain the rejection of broad forced Dedicated as a default. Revisit only in the later V2 replication/hook workflow; no Legacy A/B is a Gate 2 prerequisite. |
| Save world | UI -> vtable save with mode bypass | experimental | hidden until SaveService ABI/completion/restart gate. |
| Stop host | optional save -> DestroyNamedNetDriver | cleanup partly evidenced; full lifecycle unverified | separate Stop state, no implicit save, world/driver null and reconnect tests. |
| Broadcast/admin/kick/console | UI -> monolith raw/reflected/native calls | experimental | future one-operation workflows; typed identity, auth assumption, audit and result. Generic console absent by default. |
| Logs/status | monolith string ring/snapshot | useful | structured bounded events, breadcrumbs, contract report and immutable snapshots. |

Failure-intake clarification: `LEGACY-SKY-FAIL-001` strengthens the rejection of
broad forced Dedicated as a V2 default, but does not change the migration
contract or prove an alternative. Hook target, transport, policy and native host
preparation remain separate contracts. No legacy primitive was migrated or
reclassified by this intake.

## 4. Raw-memory, hot-path and lifetime disposition

| Current boundary | Thread transition / lifetime risk | V2 migration rule |
|---|---|---|
| Metal `Tick` invokes scheduling | render thread owns cadence; runtime state is shared with game work | Render thread only submits typed command/reads snapshot. Game scheduling is platform-owned. |
| `FIOSAsyncTask` callback | queued object identities may expire before execution | Commands carry values/full identities; resolve after obtaining game-thread token and current generation. |
| Mach exception/GetNetMode hook | executes on arbitrary hooked thread at high frequency; reentrancy and exception ownership | fixed counters/POD breadcrumbs only; call original; never store raw UObject or reflect/log. |
| object-array scans and weak pointers | GC/reuse/travel can make raw pointer or index-only identity stale | index+serial+world generation; one-scope borrow; revalidate class/relationship on use. |
| Engine arrays and FString | allocator ownership, shallow copies and lifetime transfer are ambiguous | explicit borrowed/owned types; allocator provenance; one-time transfer; no feature ownership guessing. |
| static `UClass*`/`UFunction*` caches | raw addresses may survive world/object generation change | handles/descriptors cached by build/world generation and re-resolved. |
| vtable/native calls | wrong slot/prologue/calling convention can corrupt state | ABI card, exact image check, typed function type, local validator, game-thread precondition and observable receipt. |

## 5. Preserved controls and 0.2.11 comparison

The 0.2.11 deb is a preserved behavior map, not recovered source. Its arm64
binary is symbol-rich enough to identify HostingRuntime-style resolution,
hosting, GetNetMode and recovery routines. Strings and disassembly of
`RecoverRemotePlayerUI` corroborate the validation sequence and the two client
RPC names. Combined with the user’s device result, this makes “Mac host ->
physical iPhone gameplay after the RPC pair” the strongest control.

It does **not** establish source equivalence with the current 0.2.24 tree, nor
does it validate later save, administration, lifecycle, reconnect or broad
forced-dedicated changes. V2 device gates preserve:

- the 0.2.11 deb and its checksum/package metadata;
- the exact host/client topology and character scenario used for the control;
- the two RPC recovery sequence and its preconditions as a compatibility path;
- pre/post host screenshots/logs for gameplay and sky/weather;
- current legacy source as a regression reference, never a linked dependency.

## 6. Explicitly rejected migrations

- copying or renaming `HostingRuntime` into SourceV2;
- importing the full FreshSDK or Sishen/Dragon SDK as the feature API;
- hardcoded old offsets/signatures/ABI, first-match scans, or silent RVA fallbacks;
- global mutable UObject/function caches or raw pointers retained across frames;
- generated FunctionFlags mutation around ProcessEvent;
- CDO/class vtable swapping as normal startup;
- in-place text patching that violates iOS-on-Mac signing;
- Metal/render callbacks as a gameplay thread;
- broad forced Dedicated mode, a TLS save exception, or caller-RVA whitelist as
  the default GetNetMode architecture;
- automatic save, save-on-kick/stop, generic console, or speculative PostLogin
  routing before their independent evidence/device gates.

## 7. Migration order

Only the current roadmap gate may be re-expressed. Gate 1 consumes no legacy
gameplay code: it establishes value types, identities, read-only views, profile
cards and static/fake tests. Later gates port one observable behavior through
the new seams. Legacy remains the A/B control until V2 stable-gameplay exit; it
is never deleted as part of this plan.

## 8. Gate 1 implementation disposition

Gate 1 re-expressed only the approved foundation. The legacy implementation is
still compiled solely by the root `Makefile`; V2 is selected explicitly with
`make -f SourceV2.mk`.

| Legacy/reference primitive | Gate 1 disposition | V2 replacement or retained boundary |
|---|---|---|
| `Source/UnrealEngine/CommonTypes.hpp` and `Enums.hpp` | retained for legacy only | `SourceV2/UE/Primitives.hpp` provides only the exact-width aliases and curated enum values asserted for this slice. |
| `Source/UnrealEngine/Containers.hpp` | retained for legacy only | `SourceV2/UE/Containers.hpp` provides validated borrowed array views; `SourceV2/UE/String.hpp` separates borrowed engine text from move-only host-owned text. No engine allocator transfer exists. |
| `Source/UnrealEngine/NameTypes.hpp` | retained for legacy only | `SourceV2/UE/Name.hpp` provides value semantics and bounded span-backed decoding. There is no global live name-pool binding. |
| `Source/UnrealEngine/ObjectArray.hpp` and weak-pointer helpers in `ScriptCore` | retained for legacy only | `SourceV2/UE/ObjectArray.hpp` and `Core/ObjectIdentity.hpp` require index, serial and world generation. The live root/serial reader remains unavailable pending ABI-006. |
| `ScriptCore` object/reflection classes and lookup caches | retained for legacy only | `SourceV2/UE/Object.hpp` and `Reflection.hpp` provide snapshot metadata, validated descriptors and generation-aware full-name caches. There is no `ProcessEvent` invocation or raw static object cache. |
| `GeneratedSDKProfile.hpp` and `Offsets.h` | retained for legacy only | `SourceV2/Bindings/Profiles` defines strict profile values and an intentionally incomplete 1.10280 profile that fails closed. No legacy RVA/signature fallback is linked. |
| FreshSDK generated core/Engine/ShooterGame headers | evidence input only | `Bindings/Generated/Layouts_1_10280.hpp` is a curated assertion-only slice. No FreshSDK header is included and no Engine/Shooter feature view was added. |
| `HostingRuntime`, Menu/Overlay, hooks, memory writers and gameplay bindings | intentionally retained and untouched in legacy | Not present in the V2 target. Gate 1 contains no host, connect, RPC, save, administration, hook, UI or legacy initialization path. |
| legacy package project entry/startup | retained for legacy only | `SourceV2/Bootstrap/V2Entry.mm` is the separate inert package entry. It performs one strict missing-evidence report and does not delay, scan, spawn a thread, hook or compose gameplay services. |

The historical 0.2.11 result and recorded hash remain the immutable behavior
control record, but its package file is unavailable. The independently rebuilt
legacy debug dylib is a compile check for the current legacy tree, not a
replacement for that control or evidence of runtime parity.
