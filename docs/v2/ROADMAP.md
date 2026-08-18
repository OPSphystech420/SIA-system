# Server-Host V2 roadmap

This roadmap records evidence gates, not dates. Gates are ordered: a later gate
may perform read-only research early, but it may not add runtime behavior until
all earlier exit criteria pass. The legacy target remains buildable; the missing
0.2.11 package survives only as a historical hash/result, while current A/B
artifacts are explicitly scoped investigation controls.

Current summary:

Legacy failure workflows are preserved under `archive/legacy/` and are not an
active interruption. Gate 1 foundation hardening is complete. The explicitly
inserted Gate 1.5 diagnostic UI/raw-injection workflow is
`functional-device-pass; extended-soak-pending`: exact `.1` remains a preserved
opening failure and corrected `.2` passed the bounded functional panel path.
The user authorized Gate 2, which is split into 2A/2B/2C. Only Gate 2A exact
identity/memory-boundary work is active. This does not authorize Gate 2B/2C,
Gate 3 dispatch, Gate 4 hooks or any later behavior.

| Gate | State | Strongest claim |
|---|---|---|
| 0 — architecture/evidence baseline | complete; documentation refreshed 2026-08-18 | statically analyzed/documented |
| 1 — static typed identity spine | complete 2026-08-18; infrastructure hardening verified in `V2-G1-PREP-003` | original 56 host-local assertions preserved; 61 current host-local assertions plus boundary/package audits passed, all explicitly non-live validation |
| 1.5 — diagnostic UI and Sideloadly artifact | functional-device-pass; extended-soak-pending | `.2` device-verified icon/Metal/ImGui/Status/Logs/Copy/Close/reopen with zero capabilities; long soak/outside touch not separately reported |
| 2A — exact image identity/memory boundary | active; statically validated, single artifact ready; device pending | exact offline+IDA profile and synthetic fail-closed boundary; no runtime match claim |
| 2B — name/object/reflection discovery | not started | unverified/not started |
| 2C — Engine/world relationships/invalidation | not started | unverified/not started |
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
For current manual iOS testing the canonical handoff is a raw Sideloadly input
dylib plus matching dSYM and pre-injection manifest; the `.deb` is archival and
Codex only builds/inspects it.
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

State: complete and statically validated on 2026-08-18. Immutable execution
records are `V2-G1-STATIC-001` and `V2-G1-PREP-003` in `TEST_MATRIX.md`; no
device/live claim was made.

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

## Gate 1.5 — diagnostic UI and raw Sideloadly handoff

State: `functional-device-pass; extended-soak-pending` on 2026-08-18.
Immutable `.1` opening failure remains preserved. Corrected artifact
`gate1.5-diagnostic-ui-20260818.2` became device result
`V2-G1.5-SIDELOAD-PASS-002`.

Goal: make Gate 1 refusal reasons visible in the user's real raw-dylib test path
without beginning Gate 2 or coupling UI rendering to runtime work.

Work:

- **Static:** bounded structured/logger ring, severity/category, redaction,
  stderr sink and immutable bounded snapshots with no UE dependency;
- **Build:** lifecycle-driven scene-safe UIKit floating button, transparent
  Metal/ImGui `Status`/`Logs` panel, selective touch routing and a paused closed
  `MTKView`;
- **Build correction:** revalidate/reattach/reorder the overlay hierarchy on
  lifecycle activation and every open request, make tap versus drag explicit,
  request the first frame deterministically, log bounded presentation stages
  and display a UIKit failed-stage fallback instead of a silent no-op;
- **Presentation:** use ordinary ImGui primitives for a compact dark cyan/teal
  left-rail Status/Logs layout; retain only Copy logs and Close;
- **Build:** create the canonical raw injection dylib, matching dSYM and manifest
  from the same final packaged dylib bytes; retain `.deb` only as archive;
- **Device:** inject only V2 into a clean app, inspect Status/Logs, close the menu
  close/reopen, then run the bounded closed-overlay and short stability check.

Exit:

- diagnostic button appears for missing identity, unsupported profile and
  Legacy guard refusal states;
- Status shows build/revision/startup/profile/guard and exact
  `hooks=0`, `engine_calls=0`, `mutation=0`; Logs copy is bounded/redacted;
- closed menu has no continuous overlay draw loop and touches outside the button
  or open panel reach the game;
- no crash or visible behavior regression during the exact device protocol;
- user supplies screenshots and outcome for the exact artifact.

Observed exit evidence: icon action, visible Metal/ImGui, Status, Logs, Copy
logs, Close and reopen passed; UIKit fallback did not appear; capabilities
remained zero. The user did not separately report the longer menu/map soak or
independent outside-window touch pass-through, so those are not claimed and are
carried into Gate 2A. The user explicitly authorized progression.

Forbidden: loaded-image/name/object/Engine discovery, UE/Bindings/UI coupling,
hooks, scheduler, resolver, engine calls, mutation, Host/Client/admin controls,
Legacy source or `HostingRuntime`.

## Gate 2A — exact image identity and checked-memory boundary

State: active. Source/static implementation and clean artifact are complete;
device receipt pending.

Goal: prove that the dylib selected exactly the profiled ShooterGame image and
create the sole safe read-only mechanism available to Gate 2B.

Entry:

- Gate 1 static contracts pass;
- Gate 1.5 functional UI path is device-verified and user authorized Gate 2;
- exact decrypted ShooterGame and `110280.i64` are available.

Work:

- **Static/IDA:** establish UUID, architecture, role, segment card, stable
  pre-linkedit span and full `__TEXT,__text` fingerprint for exact 1.10280;
- **Build:** add copied loaded-image catalog, bounded Mach-O view, identity
  resolver, unique exact-profile selector and checked reader only under
  `Bindings/Platform`;
- **Diagnostics:** publish only immutable redacted identity receipt and exact
  `scans_started=0`, `hooks=0`, `engine_calls=0`, `mutation=0`;
- **Device:** verify exact match, wrong-profile fail-close, panel lifecycle and
  the rolled-over two-minute menu/five-minute local-world/touch checks.

Exit:

- exact product/main role, architecture, UUID, stable segments and fingerprint
  match exactly one loaded image/profile pair;
- malformed, mismatched or ambiguous images expose no match proof and start no
  later discovery;
- checked reads reject overflow, outside/cross-segment and wrong-permission
  access and never return a borrowed pointer;
- diagnostics contain no slide, pointer, RVA or absolute address;
- target and wrong-profile device receipts plus rolled-over stability/touch
  checks pass without crash or ordinary-game regression.

Required user device test and artifacts:

Use `PLAN-G2A-SIDELOAD-001` exactly. No name/object scan, Engine relationship,
hook, call or mutation is an exit requirement.

Forbidden: FNamePool/GUObjectArray scanning, GEngine/GWorld discovery, hooks,
ProcessEvent, native/UObject calls, scheduler, Host/Client/admin UI, NetMode
policy, writes, Legacy linking or continuous rendering after Close.

## Gate 2B — FNamePool, GUObjectArray and reflection discovery

State: not started; explicitly outside the Gate 2A workflow.

Entry: Gate 2A device protocol passes and its exact match proof/checked reader
remain unchanged.

Goal: discover and validate FNamePool, GUObjectArray and the minimum reflection
metadata using only `CheckedMemoryReader` and immutable bounded snapshots.

Work/exit: resolve ABI-005 through ABI-008 in `110280.i64`; validate bounded
known-name round trips, object index/serial/class/full-name relationships and
required function/property metadata; unsupported/stale inputs fail closed. No
Engine/World relationship, call, hook or mutation is part of 2B.

## Gate 2C — Engine/world relationships and generation invalidation

State: not started; explicitly outside the Gate 2A workflow.

Entry: Gate 2B read-only discovery passes.

Goal: validate Engine, GameViewport, World and NetDriver relationships and prove
world-generation invalidation without calls or writes.

Work/exit: resolve ABI-009/010; check exact classes/full names/ownership across
menu and local-world transitions; increment generation and reject stale handles
on world change; publish only bounded immutable summaries. Hooks, calls and
mutation remain forbidden.

## Deferred production UI compatibility workflow

The current Gate 1.5 panel remains the control. A separate selected workflow
must port the real compatible ProjDragon `ARKFont` initialization and suitable
self-contained `DRGui`/Sishen layout patterns after Dear ImGui API, font
ownership and licensing/provenance review. Login/UDID/API/crypto/security,
remote downloads, hide-record, gameplay features and old offsets are excluded.
See `UI_DESIGN_DEBT.md`.

## Gate 3 — dispatcher and world lifecycle

Goal: establish the only gameplay scheduling/thread/lifetime path, still without
network or behavior-changing hooks.

Entry:

- Gate 2C read-only contracts pass;
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

## Exact next action

Device-test **Gate 2A only** with the one raw artifact. The exact target
must match; a wrong build must fail close; the receipt must expose no addresses
and retain zero scans/capabilities. Complete the rolled-over panel lifecycle,
outside-window touch and short menu/local-world stability checks.

Do not start Gate 2B or 2C in the same workflow. Hooks, `ProcessEvent`, native
calls, hosting, client travel, save, administration and mutation remain
forbidden.
