# Server-Host V2 roadmap

This roadmap records evidence gates, not dates. Gates are ordered: a later gate
may perform read-only research early, but it may not add runtime behavior until
all earlier exit criteria pass. The legacy target remains buildable; the missing
0.2.11 package survives only as a historical hash/result, while current A/B
artifacts are explicitly scoped investigation controls.

Current summary:

Legacy failure workflows are preserved under `archive/legacy/` and are not an
active interruption. Gate 1 foundation hardening prepares the clean V2 build
and package boundary; Gate 2 read-only discovery is the next workflow. This
does not authorize Gate 3 dispatch, Gate 4 hooks or any later behavior.

| Gate | State | Strongest claim |
|---|---|---|
| 0 — architecture/evidence baseline | complete; documentation refreshed 2026-08-18 | statically analyzed/documented |
| 1 — static typed identity spine | complete 2026-08-18; infrastructure hardening verification in progress | original 56 host-local assertions preserved; current guard assertions and boundary/package audits remain non-live validation |
| 2 — read-only discovery | next ordered V2 workflow; explicitly not begun in the infrastructure task | unverified/not started |
| 3–12 | blocked by ordered predecessors and named ABI/device gates | unverified/not started |

Detailed structure is in [ARCHITECTURE.md](ARCHITECTURE.md), missing contracts
in [ABI_BACKLOG.md](ABI_BACKLOG.md), and immutable results/protocols in
[TEST_MATRIX.md](TEST_MATRIX.md).

Activity labels:

- **Refactor** — separate V2 structure or move a demonstrated concept behind a
  seam, without changing legacy;
- **Static** — host-local compile, assertion, fake or dependency test;
- **IDA** — exact-binary reverse engineering and contract card;
- **Build** — local V2 iOS package/build validation;
- **Device** — user-run iOS/iOS-on-Mac validation with captured artifacts.

## Cross-gate artifact and failure rules

Every build/device gate produces one uniquely versioned artifact with its full
absolute path, build hash, runtime profile and enabled/disabled capability list.
The handoff names exact changes, expected bounded logs in both device console
and ImGui, pass/fail conditions, test sequence and the preserved rollback/control
artifact. “Device verified” is used only after the user supplies passing runtime
evidence; before that the strongest claim is “ready for device test.”

A reported crash, regression, timeout or incorrect state for the exact current
V2 artifact immediately changes that V2 capability to failed/unverified. Record
build, devices, actions, visible state, logs and crash data; isolate or disable
the smallest suspect delta; do not add an unrelated feature; update Evidence,
Status and the relevant test gate before resuming. Legacy failures remain
archival unless the user explicitly selects Legacy investigation. Absence of an
event from a disabled diagnostic is not negative proof.

## Gate 0 — architecture and evidence baseline (complete)

Goal: make the separate architecture implementation-ready without adding V2
runtime code or changing legacy gameplay.

Entry:

- V2 separate architecture selected;
- legacy source and preserved 0.2.11 deb available;
- mandatory documentation rules accepted.

Work:

- **Static/IDA:** map legacy anatomy, current references and exact 1.10280
  GetNetMode semantics/callers;
- **Static:** study Sishen, Dragon and both FreshSDK variants by relevant
  implementation, not as offsets to copy;
- **Refactor design:** define module/dependency/ownership/thread/ABI boundaries;
- **Static design:** define migration, contract backlog and test/device gates.

Exit:

- `ARCHITECTURE.md`, `MIGRATION_MAP.md` and `ABI_BACKLOG.md` are reviewable;
- every near-term behavior has entry/exit evidence and a V2 owner;
- facts, decisions and hypotheses are distinguished;
- no source or legacy behavior changed.

Artifacts: updated `EVIDENCE.md`, `STATUS.md`, this roadmap and unchanged
`HISTORY.md` unless review changes a durable conclusion.

## Gate 1 — static typed identity spine

State: complete and statically validated on 2026-08-18. The immutable execution
record is `V2-G1-STATIC-001` in `TEST_MATRIX.md`; no device/live claim was made.

Goal: create the smallest portable V2 foundation that can describe current UE
objects and contracts without raw feature access.

Entry:

- Gate 0 architecture approved;
- exact proposed files/target from `ARCHITECTURE.md` accepted;
- ABI-001 through ABI-008 cards have owners and evidence locations.

Work:

- **Refactor:** introduce the separate `serverhost_v2_core_tests` target and
  explicit SourceV2 source list; do not link legacy runtime/core;
- **Static:** implement fixed primitives, `ContractResult`, build/profile value
  types, borrowed TArray, owned/borrowed FString, FName value, ObjectIdentity,
  object-array/object/reflection view contracts;
- **Static:** include supporting UField/UStruct/FField/FProperty pieces required
  by UClass/UFunction validation;
- **Static:** add `sizeof`, `alignof`, used `offsetof`, parameter and enum
  assertions plus malformed-layout, stale-serial and wrong-generation fakes;
- **Static:** enforce forbidden raw access/generated includes in Runtime,
  Services and UI.

Forbidden in this gate: iOS injection, hooks, ProcessEvent invocation, native
engine calls, Engine/World mutation, hosting/client UI, broad generated SDK.

Exit:

- host-local tests pass deterministically from a clean build;
- unsupported/malformed profile fixtures fail closed;
- weak equality includes index, serial and world generation;
- string/array ownership is explicit and tested;
- no service or feature file contains a raw pointer/offset/vtable/ProcessEvent
  buffer;
- review confirms every emitted layout member is required by Gate 2 or an
  already-approved near-term contract.

User device test: none. This is deliberately a static gate.

## Gate 2 — read-only build, name, object and Engine discovery

Goal: validate the typed core against the loaded 1.10280 game without hooks or
gameplay mutation.

Entry:

- Gate 1 tests pass;
- iOS 1.10280 profile identity and read-only resolver cards are reviewed;
- diagnostics artifact format and redaction are defined.

Work:

- **IDA:** finish ABI-001, ABI-005 through ABI-010 resolution/validation cards;
- **Build:** add Mach-O image/memory, read-only resolver, FNamePool,
  GUObjectArray, ReflectionRegistry and Engine/World/NetDriver typed views;
- **Build:** produce a bounded ContractReport/Snapshot only; no writes/calls;
- **Device:** observe launch, main menu, map load and return-to-menu if naturally
  available.

Exit:

- loaded UUID/fingerprint matches exactly one profile;
- known FNames round-trip; Engine, GameViewport and World pass full-name/class
  checks; arrays and object serials pass bounds/range validation;
- a world change increments generation and makes old fake/live handles fail;
- an unsupported profile performs no scans beyond identity and exposes no
  callable binding;
- 10-minute menu/map read-only run produces no crash, unbounded log or behavior
  difference from the unmodified control.

Required user device test and artifacts:

1. launch the V2 diagnostics package on the Apple Silicon Mac iOS environment;
2. capture package/build hash, loaded-image UUID, ContractReport and bounded log;
3. enter/leave the same map once if the normal game permits it;
4. capture before/after screenshots and generation/object summaries;
5. report any crash with symbolicated log and breadcrumbs.

## Gate 3 — dispatcher and world lifecycle

Goal: establish the only gameplay scheduling/thread/lifetime path, still without
network or behavior-changing hooks.

Entry:

- Gate 2 read-only contracts pass;
- current FIOSAsyncTask resolution/callback ownership card is reviewed.

Work:

- **IDA:** confirm current scheduler entry and callback lifetime (ABI-015);
- **Static:** fake scheduler, bounded queue, overflow, ordering, shutdown and
  world-generation invalidation tests;
- **Build:** add iOS game-thread scheduler, ThreadToken, CommandDispatcher,
  RuntimeContext and WorldLifecycle;
- **Device:** submit diagnostic no-op commands from UI/render and verify their
  execution thread and lifecycle invalidation.

Exit:

- exactly one bounded drain executes UObject-consistent work on the identified
  game thread;
- full queue and shutdown return explicit failures, never block a hook/render
  thread or capture raw objects;
- launch/map/travel invalidates identities before a service can reuse them;
- 15-minute idle/map run and foreground/background cycle show bounded scheduling
  and no UI/render-thread UE mutation.

Required user device artifacts: thread-ID breadcrumbs for submit/drain,
queue-high-water mark, world-generation timeline, foreground/background result,
crash report if any.

## Gate 4 — inert hook transport and GetNetMode observation

Goal: prove a reversible observer hook and deepen GetNetMode evidence while
returning the exact original behavior.

Entry:

- Gate 3 passes;
- one backend has reviewed install/original/uninstall and exception/reentrancy
  test plan;
- exact target instructions come from `Extra_For_Host/110280.i64`.

Work:

- **IDA:** complete direct/indirect GetNetMode caller ledger and effect-category
  confidence (ABI-016/017);
- **Static:** test HookLease state, overflow, reentrancy guard and fixed observer
  records;
- **Build:** install LifecycleObserver and NetModeObserver only; no return-value
  mutation and no ProcessEvent-wide diagnostic hook;
- **Device:** install/uninstall, menu/map/no-host soak, new-thread behavior and
  foreground/background.

Exit:

- observer return matches original for every sampled call;
- no allocation, mutex, reflection, name conversion or formatted logging occurs
  in callback;
- original-call recursion, prior exception handling, new/exiting threads and
  uninstall are proven for the selected backend;
- 15-minute no-host A/B run has no behavior, crash or material hot-path change;
- backend failure disables observation and all dependent later behavior.

Required user artifacts: package/profile hash, install/uninstall breadcrumbs,
per-caller bounded counter table, performance sample, before/after screenshots,
symbolicated failure if present.

Caller RVAs are diagnostic identifiers for this exact profile, not production
policy selectors.

## Gate 5 — typed client travel and cleanup

Goal: prove one typed mutating native binding independently of host creation.

Entry:

- Gates 1–4 pass;
- ABI-004/014 FString and SetClientTravel cards are complete;
- a known control host endpoint and rollback/return path are available.

Work:

- **IDA:** confirm exact SetClientTravel ABI, ownership and connection guards;
- **Static:** ClientService state/error/repeat/cleanup tests with fake binding;
- **Build:** add only typed travel and observed connection/controller readiness;
- **Device:** connect the physical iPhone V2 client to the preserved known host
  topology, then return and repeat.

Exit:

- owned URL/options live for the required call duration and are released by the
  correct allocator;
- transport, controller and gameplay readiness are reported separately;
- repeated Start while active fails clearly; return invalidates all identities;
- two connect/return cycles produce no stale pointer, duplicate command or
  secret-bearing log.

Required user artifacts: server and client timestamps/logs, endpoint-redacted
travel request, connection/controller identity timeline, two-cycle result and
screenshots.

## Gate 6 — game-native host preparation and minimal IP listen

Goal: start one IP GameNetDriver through the closest proven ShooterGame-native
initialization path, without broad GetNetMode forcing.

Entry:

- Gate 5 passes;
- ABI-012/013 NetDriverDefinition and Listen cards are complete;
- ABI-018 native host preparation and ABI-022 login rejection are resolved well
  enough to avoid raw flag patches;
- definition/string/array ownership is proven, or an existing definition can be
  used read-only.

Work:

- **IDA:** trace ShooterGame listen/dedicated state writers and call chain; prove
  lifecycle point, preconditions and rollback;
- **Static:** HostService transition, idempotence, failure and generation tests;
- **Build:** add the narrow native preparation and Listen binding; original
  GetNetMode remains unchanged; no Ark login raw bypass;
- **Device:** start host once, verify bound port and driver/world ownership, then
  connect physical iPhone to transport and stop cleanly.

Exit:

- one GameNetDriver/IpNetDriver is created for the requested world, has no
  ServerConnection, owns the expected world and binds the requested port;
- second Start is rejected and failure cleans partial driver state;
- one physical iPhone creates an observed UNetConnection;
- Stop destroys the named driver without implicit save; a second start/stop
  succeeds;
- no GetNetMode result was modified and no raw login-lock flag was patched.

Required user artifacts: exact profile/contract report, server port/driver/world
receipt, paired server/client transport logs, start/stop/start timeline,
pre/post sky/weather screenshots and symbolicated failure if any.

If the native preparation contract is not proved, this gate remains blocked; a
caller whitelist or broad forced Dedicated is not an exit substitute.

## Gate 7 — replication correctness with native semantics

Goal: make remote/far replication work while preserving host world, rendering,
weather, animation, audio and save preconditions.

Entry:

- Gate 6 transport passes;
- GetNetMode caller ledger and hosted observer data are available;
- a repeatable near/far movement scenario is defined.

Work:

- **IDA:** finish exact state mutations and caller classifications implicated by
  transport/far replication;
- **Build:** adjust only the proven game-native preparation sequence; behavior-
  changing GetNetMode policy requires a separate evidence decision and is not
  presumed necessary;
- **Device:** A/B original Listen/native setup against the 0.2.11 known control
  and current broad-forced reference, using the same map/character/path.

Exit:

- physical client receives near and far relevant actors through repeatable
  movement/idle scenarios;
- host and client sky/weather/render/audio/animation remain comparable to the
  unforced control;
- driver mode/caller counters and game-state snapshots explain the result;
- no dedicated-only caller whitelist is embedded in release code;
- 20-minute hosted run has bounded hook/dispatcher overhead and no crash.

Required user artifacts: timestamped A/B/C video or screenshots, near/far
milestones, per-caller counters, game/world/driver snapshots, network logs and
crash/performance report.

## Gate 8 — remote player gameplay

Goal: move new and returning remote clients from transport to stable gameplay,
preferring observed native flow and using the evidenced RPC pair only as a
bounded compatibility fallback.

Entry:

- Gate 7 replication passes;
- ABI-008/019/020/021 ProcessEvent, player initialization, recovery functions
  and minimum identity fields are complete;
- exact eligibility and once-per-session rules are reviewed.

Work:

- **IDA:** trace exact Shooter player initialization overrides and late-listen
  omissions;
- **Static:** PlayerJoin state machine tests for stale serial, generation,
  duplicate, reconnect, native success and fallback failure;
- **Build:** typed read-only transition observation and the two narrow recovery
  wrappers; no speculative PostLogin/native hook;
- **Device:** new character, existing character and disconnect/reconnect on a
  physical iPhone.

Exit:

- each scenario reaches HUD, PlayerData, pawn, possession and controllable
  gameplay with one coherent identity timeline;
- native success dispatches no recovery; fallback dispatches each RPC at most
  once for the full identity/session;
- stale/world-changed objects cannot dispatch;
- two repeated joins per scenario complete without manual unsafe steps;
- 30-minute gameplay has stable host visuals, far replication and bounded logs.

Required user artifacts: paired logs and video/screenshots for new/existing/
reconnect, function contract report, identity/recovery state timeline, RPC count,
30-minute soak result and symbolicated crash if any.

This is the first “stable gameplay” gate. Passing transport alone is not a
release claim.

## Gate 9 — client lifecycle and repeated sessions

Goal: prove normal leave, cleanup and reconnect without persistence loss or
stale state.

Entry: Gate 8 passes and exact QuitToMainMenu/driver cleanup contracts are
complete.

Work: **IDA/Static/Build/Device** one normal return path, connection cleanup,
world invalidation and three repeated host/client sessions including one network
loss.

Exit: no stale handle or duplicate recovery; driver/connection cleanup is
observed; the same existing character returns; network loss produces bounded
failure and a successful subsequent reconnect.

Required user artifacts: three-cycle state timeline, server/client logs,
character identity/persistence summary and network-loss recovery video.

## Gate 10 — manual save

Goal: one explicit proven save, independent of Stop, kick or autosave.

Entry: Gate 9 passes; ABI-027 exact call/mode/completion contract is complete.

Work: **IDA** trace target/callers and durability; **Static** SaveService state
tests; **Build** one typed game-thread call; **Device** save, terminate fully,
restart and reload.

Exit: completion is observed, the expected state survives a full restart, and
original GetNetMode semantics remain intact. Autosave/lifecycle save remain off.

Required user artifacts: pre/save/post timestamps, bounded logs, relevant file
metadata or state receipt without secrets, termination/reload video and state
comparison.

## Gate 11 — bounded administration

After Gate 10, add one independently gated operation in this order: read-only
players, broadcast, kick, runtime admin, then a constrained allow-listed console
if still required. Each operation requires exact ABI, identity/lifetime,
authorization assumption, idempotent command ID, redacted audit and physical
device success/failure tests. Generic reflection/native call access is never an
AdministrationService API.

## Gate 12 — iOS stability release

Repeat new/existing/reconnect, near/far replication, idle and 60-minute hosted
soak, start/stop cycles, network loss, world changes and foreground/background.
Capture build/profile/contract reports, bounded logs, resource/performance
measurements and symbolicated crashes. Only controls with passed gates appear in
the normal UI.

## Deferred direction: Android and VPS

After Gate 12, request the exact Android `LibUE.so`/IDA database path and create
a separate build profile plus Bindings/Platform/Hook backend while reusing only portable
typed/runtime/service layers. Emulator/device gates follow the same contract
process. VPS supervision, UDP exposure, heartbeat/command service, backups and
external administration are separate control-plane work; SEA semantics may
inform them, not the in-process UE ABI.

## Exact next implementation workflow

Gate 1 is complete. Its optional installable supplement is a separately
identified inert package that only reports missing profile evidence; the
limited device smoke protocol is `PLAN-G1-PACKAGE-001`.

The next implementation workflow is **Gate 2 only: read-only build, name,
object and Engine discovery**. It must complete ABI-001 and ABI-005 through
ABI-010, add checked iOS image/memory readers and emit a bounded contract report.
It still may not install hooks, invoke `ProcessEvent` or native calls, host,
connect, save, administer or mutate Engine/game state.
