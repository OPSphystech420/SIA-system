# Conversation and requirements history

Last updated: 2026-08-18.

This is a factual project history, not an implementation specification. New
user feedback and important test results must be appended with a date; earlier
entries must not be silently rewritten to make later decisions look inevitable.

## Starting complaint: the current Server-Host is structurally unreliable

The user reported that the current Server-Host implementation had become
"crooked" and difficult to trust. The original host replication blocker was
eventually fixed after discovering that the intended `UEngine::Init`,
`UWorld::BeginPlay`, and `UNetDriver::GetNetMode` hooks had not been working.
After that success, multiple unrelated features and patches were added to the
same runtime: administration commands, save behavior, connection recovery,
character persistence, return-to-menu logic, stability work, additional native
hooks, diagnostics, and UI controls.

The new work did not establish reliable end-to-end behavior. Some changes
caused crashes or new regressions. A visible example is abnormal host-side
sky/weather/world lighting or effect animation after the hosting hooks are
active. This might be a hook error, but it might also be a semantic consequence
of making the hosted NetDriver report `DedicatedServer` to every caller. It must
be investigated rather than patched by assumption.

The user cannot realistically review every low-level patch, prototype, offset,
or field access. Therefore the project must make its own reasoning auditable and
must not rely on the user catching implementation mistakes after each build.

## Known successful behavior

Package `packages/com.mhga.serverhost_0.2.11+debug_iphoneos-arm.deb` is the known
behavioral control. In the confirmed test, an Apple Silicon Mac ran the iOS app
as host and a physical iPhone joined and entered gameplay.

Preserved artifact identity:

```text
/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.11+debug_iphoneos-arm.deb
SHA-256 54dda1d682bc01f5fbd38a078a33994c23ffbe4ac6d466c978ffa86775ae8dbf
```

The observed client progression was:

```text
Spectating -> Playing
bPlayerIsWaiting=true -> false
MyHUD=null -> ShooterHudBP_C
Pawn=null -> PlayerPawnTest_Female_C
MyPlayerData=null -> PrimalPlayerDataBP_C on the server
```

The decisive recovery was a server-authoritative pair of the game's own
reliable client RPCs. It restored the missing HUD/character-creation sequence
after late `UWorld::Listen`. The game then created player data, pawn, and
possession itself. This success proves a useful workflow, but it does not prove
that every later persistence, save, admin, stop, or reconnect implementation is
correct.

Only the `0.2.11` binary package is currently preserved as the control; a
matching source snapshot has not been found in the Server-Host tree. It must not
be described as recoverable source. Strings, symbols, and disassembly may be
used to build a behavior map without inventing source code.

## Requested replacement: Server-Host V2

The user chose a V2 implementation rather than continuing to patch the current
monolith. V2 must be structurally separate so the legacy source and known deb
remain available for comparison.

The immediate development platform remains iOS:

- host: the iOS game running on an Apple Silicon Mac;
- client: a physical iPhone running the modified game;
- workflow: build, install, collect in-game/console logs, reproduce one problem,
  reverse-engineer it deeply, then implement and retest one bounded change.

The long-term outcome is a host mod running inside the Android game in an
emulator on a VPS, plus a client mod used to connect to and play on that server.
That is a future direction, not a near-term implementation stage. Android/VPS
work must not distract from producing a stable and understood iOS core.

## Sishen is a primary engineering example

The user explicitly requires Sishen to be treated seriously as an example of
how the code should be written, not as a repository to glance at briefly.

Codex must study and reuse its applicable design patterns, including:

- UE core types and container/name/string representations;
- `UObject`, class lookup, static class helpers, property/function lookup;
- typed `ProcessEvent` parameter structures and wrapper functions;
- clear separation of offsets, structures, functions, memory utilities, and UI;
- use of `FName`, `FString`, `TArray`, UE enums and exact-width integer types;
- memory access and hook organization where relevant to the current platform;
- caching of classes/functions/names without scattering raw operations through
  feature code.

Sishen is the primary code-pattern reference. It is not the ABI authority for
ShooterGame 1.10280 because it targets an older/different build. A pattern copied
from Sishen must be rebound to the current FreshSDK and verified in the current
iOS/Android binaries before it is used.

Dragon/ProjDragon is another valuable example, especially for direct use of a
generated SDK and typed object access. It has the same version-boundary caveat.

## Evidence requested by the user

Fresh implementation and fixes must be checked aggressively rather than merely
made plausible. Codex may spend as long as necessary in IDA to follow xrefs,
call graphs, virtual dispatch, state changes, callers, and return values until
the behavior and ABI are reliable.

Available sources include:

- `Extra_For_Host/110280.i64`: iOS ShooterGame 1.10280 IDA database;
- Android `LibUE.so` decompilation with visible symbols (exact local path still
  needs to be supplied or recorded);
- `Extra_For_Host/SEAServerManager.dylib.i64`;
- `Extra_For_Host/SEA_host_guide.md` and the SEA administration panel;
- `Server-Host/Reference/FreshSDK`, including the Full-Version dump;
- `/Users/grimreaper31/Desktop/Dev/extra/engines/UE4.17`;
- Sishen and Dragon/ProjDragon sources;
- the decrypted app and its `EOSSDK.framework`, not yet decompiled;
- official UE source/documentation and relevant primary technical sources.

The SEA client library and panel are useful for control-plane concepts such as
heartbeat, command states, administration, configuration, and logging. They are
not assumed to contain the in-process NetDriver hosting implementation.

EOS should be investigated when evidence shows it is blocking authentication or
session behavior. The successful LAN test means it must not automatically be
blamed for unrelated replication or player-flow bugs.

## Required collaboration behavior

When the user reports that a tested function does not work or causes a crash,
Codex must treat the report as new project evidence. In the same task it should:

1. append the report and exact build/test conditions to this history or the test
   matrix;
2. update `STATUS.md` so the feature is no longer represented as verified;
3. update or invalidate the associated entry in `EVIDENCE.md`;
4. isolate one failing workflow and work on it deeply;
5. avoid adding another feature while the current workflow is unresolved;
6. record the conclusion, implementation delta, package path, and next test.

Documentation updates must not replace technical work. They preserve the facts
needed for Codex to continue the same workflow over multiple chats without
repeating failed assumptions.

## 2026-08-18 — separate architecture and evidence reset

The user explicitly selected a separate V2 architecture. The current source
stopped being the structure to extend and became a research/regression source.
The user required a complete architecture, migration map, ABI backlog and gated
iOS plan before implementation.

The resulting analysis established these new facts without rewriting the older
story:

- exact 1.10280 analysis found the GetNetMode body at `0x103A4DE44` and 44
  direct xrefs in 34 functions;
- several exact callers distinguish Dedicated from Listen and enter broad
  actor/stasis/platform paths, so the current forced-Dedicated workaround has
  semantic reach beyond a simple replication server/client branch;
- this strengthens the suspicion around host sky/weather regression but does
  not prove its cause; an observer-led A/B device test is still required;
- both FreshSDK dumps agree on the relevant near-term UE/Engine/parameter
  declarations; the Full-Version ShooterGame class file mainly removes `final`
  from 121 classes;
- the preserved 0.2.11 binary corroborates the recovery behavior through
  strings, symbols and disassembly, but its source was not recovered;
- Sishen remains the primary code-pattern authority and Dragon a secondary
  generated-SDK pattern; neither supplies current ABI;
- broad forced Dedicated, CDO vtable swaps, raw feature offsets, generic
  ProcessEvent access and caller-RVA whitelisting were not approved as V2
  production architecture.

This was a change in architectural direction, not a claim that the earlier
experiments were unreasonable or that their failures had always been
understood.

## Legacy 0.2.24 snapshot retained as history

At this documentation refresh, the root `STATUS.md` described the legacy
0.2.24 A/B package as using three hardware hooks, forced Dedicated for the
hosted GameNetDriver, the reflected recovery pair, synchronous native save, an
authority GameMode broadcast, kick/save coupling and a long return-to-menu
timeout. It also described character restoration and the sky/FPS cause as
unproven.

Those statements remain useful records of what the legacy branch believed and
what it intended to test. They are not automatically promoted to V2 device
verification. In particular, source labels such as “confirmed” in the legacy
status do not replace an immutable user result row for an exact V2 artifact.

## 2026-08-18 — living documentation refresh

The user required the V2 documentation to become the entry point for future
Codex tasks and to preserve failures, regressions and changes of direction.
The documentation now uses explicit artifact states—compiled, statically
validated, ready for device test, device verified, contradicted and
unverified—and an append-only failure/result policy.

The current exact iOS/SEA databases, both FreshSDK dumps, Sishen, Dragon,
UE4.17, decrypted 1.10280 application and EOSSDK binary were path-checked. The
matching 0.2.11 source snapshot and exact Android LibUE/IDA path remain missing.
No SourceV2 runtime artifact existed and no runtime code changed during this
documentation refresh.

## 2026-08-18 — historical 0.2.11 package file lost during clean build

The Gate 1 legacy compile check used `make clean all`. The Theos clean rule
removes every `.deb` matching the legacy package ID, not only the current
version, and the recorded
`packages/com.mhga.serverhost_0.2.11+debug_iphoneos-arm.deb` file is no longer
present. A workspace, Spotlight, Trash, temporary-directory and home-directory
filename search found no duplicate; no usable local Time Machine snapshot was
available through the current environment.

The historical device result and recorded SHA-256 remain valid evidence of what
was tested, but the file can no longer be offered as a rollback artifact. It
cannot be recreated from the current source without falsely claiming byte or
behavior equivalence. Future V2 packages use a separate package ID and isolated
`packages/v2` output so V2 clean rules cannot remove legacy-ID artifacts.

## 2026-08-18 — current A failed before host and invalidated the visual A/B prerequisite

The user tested exact package SHA-256
`d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e`.
After opening the ServerHost UI and pressing no Start/Join/save/administration
control, ShooterGame closed after approximately one to two minutes. No retained
ServerHost log or crash report was available.

This disproved the important working assumption that the current A package had
a stable, behaviorally idle pre-host baseline suitable for the planned
forced-versus-original NetMode visual comparison. Source reconstruction showed
that “before Start” is not inert in legacy: the constructor installs three
hardware hooks, the transparent Metal overlay continuously schedules runtime
ticks, and both Engine Init observation and idle discovery can mutate
`UEngine::NetDriverDefinitions` while role is Disabled. Forced-NetMode host
policy itself is not active at that point.

The host-visual A/B is therefore suspended. The smallest next control keeps the
exact package fixed and compares five minutes with the ServerHost UI never
opened against five minutes with it visible. No hook or mutation patch is
selected until that control distinguishes the visible UI path from the
always-active pre-host paths.

## 2026-08-18 — correction: the reported exit occurred after hosting started

The user clarified that the preceding intake reconstructed the runtime state
incorrectly: a world was open and ServerHost had started hosting. ShooterGame is
stable when the ServerHost floating control is not opened and no ServerHost
command is pressed. The earlier no-host device conclusion is therefore
withdrawn, while the source-only conclusion that legacy pre-command startup is
not inert remains true.

The supplied Console excerpt adds a new exact fact. At `14:43:45.372951` the
process entered `GASignalHandler`; exact 1.10280 IDA decompilation shows that
this GameAnalytics callback captures a backtrace, submits an error event and
calls `_Exit(1)`. One callback is registered for thirteen POSIX signals and
does not preserve the signal argument, so the log proves signal-driven
termination but not SIGSEGV, SIGABRT, SIGPIPE or any other specific cause.

This changes the isolation boundary again: package and source are identical
between the stable hidden/no-command control and failure, while host activation
and panel visibility changed together. The smallest next test starts the same
host in both arms and changes only whether the panel is hidden or visible for
five minutes. The original-NetMode A/B remains suspended until that produces a
stable hosted baseline.

## 2026-08-18 — V2 workflow restored; Legacy failures archived

The user explicitly returned priority to the separate V2 workflow and excluded
Legacy runtime investigation from the current task. Legacy failure reports,
execution rows, hashes and historical conclusions were moved verbatim to
`docs/v2/archive/legacy/`. From this point only a failure of the exact current
V2 workflow blocks V2; a Legacy failure is archival evidence unless the user
explicitly selects a Legacy investigation.

The active infrastructure task prepares the existing Gate 1 SourceV2 for Gate 2
without beginning live discovery. It adds build isolation/reproducibility,
package/runtime Legacy exclusion and iOS layout compilation, while leaving
hooks, `ProcessEvent`, hosting, travel and mutation out of scope.
