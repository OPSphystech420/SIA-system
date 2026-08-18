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
The user authorized Gate 2, which is split into 2A/2B/2C. Gate 2A positive
exact identity is device-verified. Its death-triggered exit reproduced without
any injection and is now a deferred external baseline limitation; arms B/C were
waived. Gate 2B read-only contracts were packaged as `V2-G2B-BUILD-007`; its
device execution reached the exact profile but deterministically aborted on an
over-restrictive TUObjectArray capacity validator. The `.2` correction then
completed the exact main-menu snapshot, but its TheIsland generation-2 capture
failed closed at a VM-region boundary. A bounded multi-region `.3` correction
was built as `V2-G2B-MULTIREGION-BUILD-009` and passed menu/TheIsland execution
as `V2-G2B-MULTIREGION-DEVICE-PASS-004`. Gate 2B is complete. Gate 2C `.1`
completed its fresh Gate 2B snapshot in TheIsland but aborted fail-closed at an
over-specific Engine UClass index validator. The direct-class correction is
packaged as clean `.2` receipt `V2-G2C-ENGINE-VALIDATOR-FIX-BUILD-011` and
awaits its device repeat; this does
not authorize Gate 3 dispatch, hosting, travel, hooks or later behavior.

| Gate | State | Strongest claim |
|---|---|---|
| 0 — architecture/evidence baseline | complete; documentation refreshed 2026-08-18 | statically analyzed/documented |
| 1 — static typed identity spine | complete 2026-08-18; infrastructure hardening verified in `V2-G1-PREP-003` | original 56 host-local assertions preserved; 61 current host-local assertions plus boundary/package audits passed, all explicitly non-live validation |
| 1.5 — diagnostic UI and Sideloadly artifact | functional-device-pass; extended-soak-pending | `.2` device-verified icon/Metal/ImGui/Status/Logs/Copy/Close/reopen with zero capabilities; long soak/outside touch not separately reported |
| 2A — exact image identity/memory boundary | positive identity device-verified; death exit external baseline reproduced/deferred | exact UUID/fingerprint/segments matched with zero scans/capabilities; injection is not necessary for the reproduced death symptom |
| 2B — name/object/reflection discovery | complete; device verified | `.3` completed menu generation 1 and TheIsland generation 2, invalidated the prior generation, changed object/chunk counts, repeated every validator and retained zero capabilities |
| 2C — Engine/world relationships/invalidation | `.1` device abort; clean `.2` ready | prerequisite snapshot device-proven for the attempt; fixed dump-index assumption removed; all live relationships/world transitions remain unverified |
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
independent outside-window touch pass-through for that artifact, so those are
not retroactively claimed. A later Gate 2A death/respawn signal exit is recorded
as a separate artifact result. The user explicitly authorized progression.

Forbidden: loaded-image/name/object/Engine discovery, UE/Bindings/UI coupling,
hooks, scheduler, resolver, engine calls, mutation, Host/Client/admin controls,
Legacy source or `HostingRuntime`.

## Gate 2A — exact image identity and checked-memory boundary

State: positive exact identity device-verified; death/respawn symptom reproduced
without injection as `V2-G2A-DEATH-BASELINE-002` and deferred.

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
- **Device:** the positive exact match and panel lifecycle are verified. The
  wrong-profile negative remains a non-inferred static/profile follow-up. The
  death/respawn causal control closed after baseline arm A; B/C were waived.

Exit:

- exact product/main role, architecture, UUID, stable segments and fingerprint
  match exactly one loaded image/profile pair;
- malformed, mismatched or ambiguous images expose no match proof and start no
  later discovery;
- checked reads reject overflow, outside/cross-segment and wrong-permission
  access and never return a borrowed pointer;
- diagnostics contain no slide, pointer, RVA or absolute address;
- the positive target receipt is device-proven; unsupported profiles retain
  their statically validated fail-closed contract without an invented device
  PASS;
- the death/respawn stability contradiction is causally classified before any
  2B live discovery. A reproduced baseline game limitation may be recorded as
  external rather than falsely attributed to V2.

Required user device test and artifacts:

`V2-G2A-IDENTITY-PASS-001` completed the positive exact-target identity part of
`PLAN-G2A-SIDELOAD-001`. `PLAN-G2A-DEATH-CAUSAL-001` closed after arm A
reproduced the symptom without injection. B/C are not required by user decision.

Forbidden: FNamePool/GUObjectArray scanning, GEngine/GWorld discovery, hooks,
ProcessEvent, native/UObject calls, scheduler, Host/Client/admin UI, NetMode
policy, writes, Legacy linking or continuous rendering after Close.

## Gate 2B — FNamePool, GUObjectArray and reflection discovery

State: complete; device verified by `V2-G2B-MULTIREGION-DEVICE-PASS-004`.

Entry: Gate 2A causal classification permits progression and its exact match
proof/checked reader remain unchanged.

Goal: discover and validate FNamePool, GUObjectArray and the minimum reflection
metadata using only `CheckedMemoryReader` and immutable bounded snapshots.

Work: ABI-005 through ABI-007 were resolved in `110280.i64`. Stable profile RVAs
feed a provenance-gated owned-copy reader. Explicit serial captures double-sample
FName/object headers, copy bounded blocks/chunks, create discovery-generation
identities, validate known names/core classes/function identity and publish only
a bounded immutable report. ABI-008 invocation remains deferred; function
parameter offsets remain unavailable.

Exit: `.3` passed menu and TheIsland captures, generation replacement, every
required validator and zero hooks/engine calls/mutation. Return-to-menu capture
and a longer soak were not reported. `Class Engine.World` remains class metadata,
not a live UWorld, and parameter ABI/native dispatch remain unavailable.

## Gate 2C — Engine/world relationships and generation invalidation

State: `.1` immutable device abort `V2-G2C-ENGINE-VALIDATOR-ABORT-001`;
corrected clean `.2` artifact `V2-G2C-ENGINE-VALIDATOR-FIX-BUILD-011` awaits
device execution.

Entry: Gate 2B read-only discovery passes.

Goal: validate Engine, GameViewport, World and NetDriver relationships and prove
world-generation invalidation without calls or writes.

Work: ABI-009/010 cards are implemented through exact native roots, strict
class/full-name/non-CDO validation, canonical definitions decoding, independent
GWorld/ViewportWorld reads, optional same-snapshot relationships, stability
resampling and a separate world generation. `.1` incorrectly promoted the
FreshSDK ShooterEngine UClass dump index to a runtime invariant. `.2` resolves
that direct UClass in the same fresh snapshot and validates exact
`Class ShooterGame.ShooterEngine` plus GameEngine/Engine ancestry. Every request
still creates a fresh Gate 2B owned snapshot; no pointer, timer or cache crosses
captures.

Exit: build one clean raw artifact; execute menu, TheIsland, repeated same-world
capture and optional natural return-menu capture; confirm relationship state,
world-generation transitions/stability and `hooks=0 engine_calls=0 mutation=0`.
Death/respawn is outside PASS/FAIL. Details are in
`evidence/GATE2C_LIVE_RELATIONSHIPS.md`.

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

## Gate 4 — Host native-contract research

Goal: close only the exact native contracts needed for an original-NetMode IP
Listen. This gate adds no hook and starts no transport.

Entry: Gate 3 passes and the current world can be resolved through a validated
generation-bound handle on the proven game thread.

Work:

- **IDA:** close ABI-012/013/018/022/023 for existing definition selection,
  `UWorld::Listen`, ShooterGame host preparation, login rejection and cleanup;
- **Static:** define narrow typed arguments, ownership, preconditions,
  postconditions, rollback and unsupported-profile failures without calling
  them;
- **Build:** publish contract availability only. `UEngine::Init` and
  `UWorld::BeginPlay` hooks are not prerequisites.

Exit: every planned direct call has an exact 1.10280 type/ownership/lifecycle
card and a fail-closed validator. No listener, driver, hook, ProcessEvent,
GetNetMode policy or mutation is enabled by this research gate.

## Gate 5 — minimal IP Listen with original NetMode

Goal: start one IP GameNetDriver through the closest proven ShooterGame-native
path without a behavior-changing hook.

Entry:

- Gate 4 Host native-contract research passes;
- the current validated world is dispatched through Gate 3;
- an existing validated GameNetDriver definition can be used read-only, or its
  exact ownership-safe construction contract is complete.

Work:

- **Static:** HostService start/idempotence/failure/rollback/generation tests;
- **Build:** make the narrow native preparation and Listen calls on the current
  validated world; GetNetMode returns its original value; no broad Dedicated
  forcing, login flag patch, Init hook or BeginPlay hook;
- **Device:** start once, verify the driver/world/port receipt, connect one
  physical client at transport level, stop cleanly, then start/stop again.

Exit:

- one GameNetDriver/IpNetDriver belongs to the requested world, has no
  ServerConnection and binds the requested port;
- one physical client creates an observed UNetConnection; gameplay is not yet
  claimed;
- duplicate Start is rejected and partial failure/Stop clean the named driver;
- original GetNetMode is unchanged and all hooks remain absent.

Required user artifacts: exact contract report, server port/driver/world
receipt, paired transport logs, start/stop/start timeline and pre/post host
world screenshots.

## Gate 6 — typed client travel and cleanup

Goal: prove the typed client travel path against the Gate 5 listener.

Entry:

- Gate 5 transport passes;
- ABI-004/014 FString and SetClientTravel cards are complete;
- a rollback/return path is available.

Work:

- **IDA:** confirm exact SetClientTravel ABI, string ownership and connection
  guards;
- **Static:** ClientService state/error/repeat/cleanup tests;
- **Build:** add only typed travel and observed connection/controller readiness;
- **Device:** connect, return naturally where possible, and repeat.

Exit:

- URL/options survive exactly the call duration and use the correct ownership;
- transport, controller and gameplay readiness remain separate receipts;
- return invalidates identities and two cycles show no duplicate or stale use;
- GetNetMode remains original and no hook is introduced.

Required user artifacts: endpoint-redacted travel request, paired timestamps,
connection/controller timeline, two-cycle result and screenshots.

## Gate 7 — replication correctness with native semantics

Goal: make remote/far replication work while preserving host world, rendering,
weather, animation, audio and save preconditions.

Entry:

- Gate 6 transport passes;
- a repeatable near/far movement scenario is defined.

Work:

- **IDA:** finish exact state mutations implicated by transport/far replication;
- **Build:** adjust only the proven game-native preparation sequence; behavior-
  changing GetNetMode policy and hook transport remain absent;
- **Device:** A/B original Listen/native setup against the 0.2.11 known control
  and current broad-forced reference, using the same map/character/path.

Exit:

- physical client receives near and far relevant actors through repeatable
  movement/idle scenarios;
- host and client sky/weather/render/audio/animation remain comparable to the
  unforced control;
- driver and game-state snapshots explain the result or identify a concrete
  unresolved replication gap;
- no dedicated-only caller whitelist is embedded in release code;
- 20-minute hosted run has bounded dispatcher overhead and no crash.

Required user artifacts: timestamped A/B/C video or screenshots, near/far
milestones, game/world/driver snapshots, network logs and crash/performance
report.

## Gate 8 — optional inert hooks or narrow policy, only if required

State: conditional. Skip this gate entirely when Gate 7 replication passes with
read-only observation and direct calls.

Entry: original-NetMode Gate 5 transport passed and Gate 7 produced a concrete,
repeatable replication gap that cannot be explained or fixed through the proven
native preparation/direct-call contracts.

Work/exit: first prove a reversible inert observer returning the exact original
value, including install/original/uninstall, exception chaining, recursion,
thread lifecycle and soak. Only its bounded evidence may justify a separately
reviewed narrow policy. Broad Dedicated forcing is forbidden; caller RVAs are
diagnostic identifiers, not an automatic release whitelist. A behavior change
must close the named replication gap without changing unrelated world/weather/
render/audio behavior, and must fail closed if transport or policy validation
is unavailable.

This conditional gate implements `DEC-V2-NO-HOOK-FIRST-HOST`: hooks are evidence
infrastructure of last resort, not dependencies of first Listen.

## Gate 9 — remote player gameplay

Goal: move new and returning remote clients from transport to stable gameplay,
preferring observed native flow and using the evidenced RPC pair only as a
bounded compatibility fallback.

Entry:

- Gate 7 replication passes, with Gate 8 either skipped or narrowly passed;
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

### Gate 9 completion — client lifecycle and repeated sessions

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

Build and run only the named Gate 2C raw artifact under the protocol in
`evidence/GATE2C_LIVE_RELATIONSHIPS.md`. Capture menu, TheIsland, repeated same
world and optional natural return-menu relationships. Do not use death/respawn
as PASS/FAIL.

Do not start Gate 3, Host research, hosting or travel in this workflow. Hooks,
`ProcessEvent`, engine calls, NetMode policy, save, administration and mutation
remain forbidden.
