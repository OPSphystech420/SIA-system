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

## 2026-08-18 — Gate 1.5 diagnostic UI and Sideloadly handoff inserted

The user clarified that manual testing injects a raw dylib through Sideloadly.
The prior Gate 1 artifact had no UI, so absence of a floating icon was expected
and was not runtime-failure evidence. The user explicitly inserted Gate 1.5 and
deferred Gate 2 live discovery.

Gate 1.5 added a UE-free bounded/redacted diagnostic logger and immutable
snapshot, a lifecycle-driven UIKit floating button, and a transparent Metal/
ImGui panel containing only Status, Logs, Copy logs and Close. Runtime refusal
no longer suppresses diagnostics: missing identity, unsupported profile and
Legacy guard refusal still expose the icon while hooks, engine calls and
mutation remain zero. The closed `MTKView` is paused and the render callback
does not tick, schedule, resolve or access engine code.

The canonical device handoff changed to
`packages/v2/injection/<build-id>/ServerHostV2.dylib` with matching dSYM and a
pre-injection manifest. Sideloadly may re-sign the input. The `.deb` remains an
archival/package-inspection artifact; Codex builds and inspects it but does not
install it. Gate 2 was not started, and Legacy source, the root Makefile and
Legacy packages were not changed.

## 2026-08-18 — first Gate 1.5 device test exposed a silent open failure

The user executed `PLAN-G1.5-SIDELOAD-001` with exact pre-injection build
`gate1.5-diagnostic-ui-20260818.1`, dylib SHA-256
`780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b`.
The floating V2 icon appeared, but tapping it produced no visible menu. No
device/OS identity, reproducibility count, logs or screenshot was supplied and
none is inferred.

The result proves only that dylib startup and the UIKit bootstrap progressed far
enough to install the icon. It contradicts visible Status/Logs opening and does
not validate button action delivery, overlay hierarchy, Metal drawable/frame
creation, ImGui rendering, log copying, touch pass-through, or close/pause
behavior. Gate 1.5 moved to `failed-under-investigation`; Gate 2 remains
unstarted.

The presentation contract was strengthened within Gate 1.5: every accepted open
request must revalidate and reorder its hierarchy, explicitly request the first
Metal frame, publish bounded stage diagnostics, and show a small UIKit fallback
with the exact failed stage if Metal/ImGui cannot present. The diagnostic panel
must also use a compact Sishen/Dragon-inspired dark cyan/teal layout with a left
navigation rail and only Status and Logs. This is a correction of the same
diagnostic workflow, not a new feature gate.

## 2026-08-18 — corrected Gate 1.5 became a bounded functional device PASS

The user executed corrected build `gate1.5-diagnostic-ui-20260818.2`, source
`8fb09e654466b07b534a3dd16b2618e789d84777`, raw input SHA-256
`4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32`.
The supplied runtime receipt confirmed button action delivery, hierarchy-verified
open, Metal drawable/render-pass acquisition, ImGui frame submission and first
presentation, Close stopping Metal rendering, reopen and bounded log copy.

This became immutable result `V2-G1.5-SIDELOAD-PASS-002`. It device-verifies the
icon action, visible Metal/ImGui panel, Status, Logs, Copy logs, Close and reopen;
UIKit fallback did not appear; `hooks`, `engine_calls` and `mutation` remained
zero. The earlier `.1` opening failure remains immutable.

The result is deliberately bounded. The user did not separately report the
planned longer menu/map soak or an independent touch check outside the open
window. No seven-minute or ten-minute PASS is inferred. Gate 1.5 moved to
`functional-device-pass; extended-soak-pending`, the missing read-only checks
moved into the next device protocol, and the user explicitly authorized Gate 2.

## 2026-08-18 — Gate 2 split and Gate 2A exact identity boundary started

Gate 2 was split before implementation:

- Gate 2A: Mach-O image identity/profile and checked mapped-memory boundary;
- Gate 2B: FNamePool, GUObjectArray and reflection discovery;
- Gate 2C: Engine/GameViewport/World/NetDriver relationships and
  world-generation invalidation.

Only Gate 2A began. The exact offline ShooterGame and open `110280.i64` agreed
on whole-file SHA-256 `d98d257…a178` and full `__TEXT,__text` SHA-256
`8bfc1fd…bcf8`; UUID is `E52A980C-9C36-34C7-84B0-DD6E846328DC`. The selected
fingerprint excludes load commands and code-signature/linkedit bytes so ASLR,
dylib load-command insertion and ordinary re-signing do not enter the hash.

SourceV2 added a single low-level `Bindings/Platform` boundary for copied dyld
catalogs, bounded Mach-O parsing, unique exact profile selection and match-gated
checked reads. The UI receives only an immutable redacted identity receipt.
Gate 2A starts no scans and enables no hook, engine call or mutation. Sishen was
used only as an organizational comparison; its substring image cache, numeric
address heuristics, globals, offsets, signatures, calls, writes, hooks,
anti-analysis and gameplay code were rejected.

The production UI compatibility request was recorded as a separate future task:
inspect the real ProjDragon ARKFont and self-contained DRGui/Sishen layout blocks
only after ImGui/ownership/license review. The current Gate 1.5 panel remains the
control and was not refactored in Gate 2A.

## 2026-08-18 — Gate 2A static build handoff completed

`V2-G2A-BUILD-006` was built from clean source revision
`17e4e09ce8029bb89b22560da771ddc170e2ad0d`, tagged
`v2-gate2a-exact-identity-20260818.1-source`. The one raw Sideloadly input has
SHA-256 `65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72`;
its Mach-O UUID matches the dSYM at
`0704076C-EAB6-3F25-800D-C0F0B85431E8`. The immutable manifest SHA-256 is
`77329da6d35f49c332c63a39e733d6fc970eaf474f89600b7edd37909ad1c5ca`;
the archival `.deb` SHA-256 is
`19d75c2e4ec8df0bc3e00d33e7337f3f7e981ddfc8308ebd8981007eb0784209`.

The final clean build reran 191 host assertions and the boundary audit, then
passed iOS arm64 compilation, package inspection and injection Legacy/gameplay
isolation. An independent UBSan-only run also passed 191 assertions. The
artifact is ready for `PLAN-G2A-SIDELOAD-001`; no device/runtime exact-match
claim exists yet, and Gate 2B remains unstarted.

## 2026-08-18 — Gate 2A identity passed; death stability failed

The user executed exact build `gate2a-exact-identity-20260818.1`, source
`17e4e09ce8029bb89b22560da771ddc170e2ad0d`, raw input SHA-256
`65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72`.
Runtime matched UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC`, the profile segment
card and fingerprint `8bfc1fd248a5...`; scans, hooks, engine calls and mutation
remained zero. UI open/close/reopen, Copy logs and interaction also worked.
This became positive identity sub-contract result
`V2-G2A-IDENTITY-PASS-001`.

In the same artifact workflow, ShooterGame exited during character death and
the death/respawn transition in a local saved no-EOS world while the panel was
open. Console capture SHA-256
`0578303bea504af55cf6762d147debe6443e6f915bc9d3a56738608b360c7a8f`
contains `GASignalHandler entered` at line 7579, followed by an HTTP 200 crash-
event upload. The response is not treated as cause. No signal number, stack,
faulting thread or new ShooterGame `.ips` was available. This became immutable
failure `V2-G2A-DEATH-SIGNAL-EXIT-001` and contradicted extended stability only.

Source audit found no Gate 2A Pawn/HUD/World/UObject acquisition and no
production discovery-reader creation, so a V2 dangling UE pointer is
incompatible with this path. Base death behavior, open-overlay interaction and
another latent injection/startup/UI defect remain candidates. Gate 2B is blocked
pending the single no-build `PLAN-G2A-DEATH-CAUSAL-001` A/B/C protocol.

## 2026-08-18 — death exit reproduced without injection; Gate 2B unblocked

The user executed arm A of `PLAN-G2A-DEATH-CAUSAL-001` with ShooterGame,
the same local save and no injected Server-Host dylib. Character death caused
the identical application exit, and EOS login did not change the outcome.

Immutable result `V2-G2A-DEATH-BASELINE-002` is classified `external baseline
reproduced`. Gate 2A is not a necessary cause of the symptom. The exact stock
cause—save damage, base death/respawn behavior, or iOS-on-Apple-Silicon
behavior—is deferred outside this workflow. This does not claim V2 can never
influence that path. By explicit user decision arms B/C are not required,
death/respawn is removed from current V2 stability acceptance, Gate 2A exact
identity remains device verified, and Gate 2B becomes active.

## 2026-08-18 — Gate 2B read-only contracts implemented

The required Sishen name/object/reflection implementations and both FreshSDK
trees were reviewed. IDA MCP on exact `110280.i64` proved the inline FNamePool
root at RVA `0x5BB5180`, resolved enclosing `FUObjectArray 0x5D434D8` versus
direct `ObjObjects 0x5D434E8`, and established the current item, UObject and
FunctionFlags fields used by Gate 2B. FreshSDK absolute values were normalized
to stable RVAs; GWorld/ProcessEvent are recorded but not consumed.

SourceV2 gained a profile-bound provenance reader for derived heap copies,
double-sampled owned FName/object snapshots, discovery-generation identities,
bounded class/function/full-name checks and an explicit serial Contracts capture.
The UI consumes only an immutable redacted report. Before capture scans remain
zero; after a request scans=1 while hooks, engine calls and mutation remain zero.
Synthetic host tests, the strict boundary audit and an iOS arm64 compile passed.
No Gate 2C relationship, native call, hook, hosting control or death workaround
was added. Device verification remains pending.

## 2026-08-18 — Gate 2B immutable handoff built

`V2-G2B-BUILD-007` was produced from clean revision
`ff9637b34b308117208555482c5a8a872c8b94c9` and source tag
`v2-gate2b-readonly-contracts-20260818.1-source`. The single raw Sideloadly
dylib SHA-256 is `e7f6c3c932c2af759547d69b46359b2e1004c51dbd5f2f5a7c9fbd25729afb79`;
its Mach-O and dSYM UUID is `0D2DBE64-7258-34CC-B9F0-A3DFFB80516D`.
The manifest SHA-256 is `956d912aeb15aee671661ca96a5abee0eb0a166229d13bb2138b81b7bba88d78`
and the archival package SHA-256 is
`bff134a2ec73fac33b8cff6fa9cd3e7dc9f426efb2e6ce21241423a816cb7232`.
Tests and static/package/injection audits pass; device capture remains pending.

During the first package invocation, stale iOS control metadata caused the
ignored historical Gate 2A `.deb` path to be regenerated. The path was restored
to its original control and exact raw dylib payload and passes inspection, but
the rebuilt container SHA is `46264cbf9471acb4eef9c28a35c25ac74972b91f50ae1dd8761bad514a4194db`
rather than the immutable historical SHA `19d75c2e…784209`. The unchanged Gate
2A raw injection dylib and manifest still match their receipts. This archive
integrity deviation is preserved explicitly; the new Gate 2B artifact was then
built only after correcting control metadata and committing a clean source tag.

## 2026-08-18 — Gate 2B `.1` capture aborted fail-closed

The user executed the exact `.1` artifact. Image identity, Status, panel
open/close/reopen, Metal stop on Close and Copy logs worked. Three explicit
captures at generations 1–3 aborted deterministically with the same
`invalid TUObjectArray num/max/chunk relationship`; scans became one while
hooks, engine calls and mutation stayed zero. Result
`V2-G2B-CAPTURE-ABORT-001` therefore contradicts a completed live Gate 2B
snapshot but confirms fail-closed behavior.

Exact IDA/FreshSDK recheck preserved the direct root and field offsets. Source
audit found that the `.1` validator wrongly treated reserved `MaxElements` and
`MaxChunks` as operational copy limits. The correction keeps bounded work on
live Num fields/bytes/time, validates reserve capacity through typed semantic
relationships and emits safe integer counters on any future rejection. Gate 2C
and hosting remain unstarted.

The correction passed 280 normal and 280 UBSan-only host assertions, the strict
boundary audit and an iOS arm64 compile before clean artifact packaging.

## 2026-08-18 — Gate 2B capacity correction handoff built

`V2-G2B-CAPACITY-FIX-BUILD-008` was built from clean revision
`739f274c5b01c29703bbc9b34b40ad6a167c24af` and tag
`v2-gate2b-readonly-contracts-20260818.2-source`. The raw dylib SHA-256 is
`56e9ebb0d4453b90e4d63ccfa5431a142d8d94bc42b043b0e45b24e819203a6c`;
Mach-O/dSYM UUID is `F02EC54E-DEB7-35AA-B91C-C868547BCD03`; manifest SHA is
`88c29c99dafb6522caedcef27c4538dcb1df43bd06385dc82519658ae3ea17cc`;
the archival `.deb` SHA is
`ceffbde6f34f3323459a3e2754cf18ce09e6d353336564caee01e401a44bad83`.
The replacement awaits one menu capture before the world-stage protocol.

## 2026-08-18 — Gate 2B menu snapshot device-verified

`V2-G2B-MENU-CAPTURE-PASS-003` executed the exact `.2` artifact and completed
generation 1 in the main menu. It copied 24,675,046 bytes in 49 ms, owned 178
FName blocks/390585 entries and 61171 object items, accepted reserve capacity
25231360/385, and passed all ten names, nine core objects/functions and bounded
reflection validators. Hooks, engine calls and mutation remained zero.

The same process produced immutable `V2-G2B-WORLD-VM-REGION-ABORT-002` after
entering TheIsland. Generation 2 invalidated generation 1 but aborted in 37 ms
because one logical copy was required to fit one readable VM region. No crash
or generation-2 snapshot is claimed.

The low boundary now composes a token-bounded owned result across consecutive
readable regions while keeping every `vm_read_overwrite` inside its queried
region. Gaps, permissions and unmap/copy failures remain fail-closed; derived
errors add only a redacted type label. Normal and UBSan-only suites each pass
290 assertions and the boundary audit passes. Gate 2C remains unstarted.

## 2026-08-18 — Gate 2B multi-region replacement built

`V2-G2B-MULTIREGION-BUILD-009` was produced from clean revision
`852e260d353c9a67a18e5763f358f1242b6e7947` and source tag
`v2-gate2b-readonly-contracts-20260818.3-source`. Raw dylib SHA-256 is
`b5e5f0edf47ebb5b71c0c08d947bd6d186538ea2a9f9bc9722c4076ee0e07829`;
Mach-O/dSYM UUID is `48EB7BC3-7222-3F27-8A09-4224B980EF8C`; manifest SHA is
`29eaa59a1fbe428213c8f75b1b0a6453ab062467ae929f364915857b45cff89e`;
the archival `.deb` SHA is
`e1147e8fee5f7fa64bf1fe90d4e109448da1949e202117287f3deee363b7c8f8`.
All V2-only build and injection inspections passed; device repeat is pending.

## 2026-08-18 — Gate 2B device-verified and closed

`V2-G2B-MULTIREGION-DEVICE-PASS-004` executed the exact `.3` artifact. Menu
generation 1 completed in 32 ms with 61,177 objects in one chunk. TheIsland
generation 2 completed in 44 ms with 107,275 objects in two chunks, marked the
previous generation invalidated and repeated every known-name, core-object and
reflection validator successfully. The earlier `.2` VM-region abort remains
immutable; `.3` device-verifies its bounded multi-region correction.

Both captures retained zero hooks, engine calls and mutation. The optional
return-menu third capture and longer soak were not reported. Gate 2B is complete
for its scoped read-only snapshot contract; Gate 2C is unblocked but remains
not started.

## 2026-08-18 — Gate 2C `.1` Engine validator aborted fail-closed

`V2-G2C-ENGINE-VALIDATOR-ABORT-001` executed the exact `.1` artifact during a
local TheIsland world. Its fresh Gate 2B generation completed in 37 ms with
110,906 objects/two chunks and every required FName, object/function and
reflection validator passing. The relationship phase then aborted before its
first accepted byte on the combined exact ShooterEngine identity validator.
Hooks, engine calls and mutation remained zero; no live relationship or world-
generation value is claimed.

Source audit found that `.1` compared the live direct UClass object-array index
with FreshSDK dump index `0x359`. The dump proves the class full name but not a
stable process-independent index. Corrected `.2` dynamically resolves the
direct UClass in the same fresh snapshot, requires exact
`Class ShooterGame.ShooterEngine`, separately checks live class/full-name/CDO,
and preserves the independent GameEngine/Engine chain. A relocated-UClass
positive and wrong-package negative pass 387 normal and UBSan-only assertions;
the boundary audit retains zero hooks/calls/mutation. Gate 3 and hosting remain
closed.

## 2026-08-18 — Gate 2C Engine-validator replacement built

`V2-G2C-ENGINE-VALIDATOR-FIX-BUILD-011` was produced from clean revision
`4a53ab940e8085c2e13c00489b4ab6ab9e95764c` and annotated source tag
`v2-gate2c-live-relationships-20260818.2-source`. Raw dylib SHA-256 is
`ee6f6d9014fa98171a105fa009750e4d078a099a8ecf4a969dce98c704b60cae`;
Mach-O/dSYM UUID is `E70F89CA-A7DE-3AEA-8CA1-D23AEF07AD8F`; manifest SHA is
`832ace6c517a56f319847131e1297b46ede67100adad8bb38ba1febd59fe10e7`;
the archival `.deb` SHA is
`7bc9607751fb630c38ee18aa56be3c187320765f1e95cfa92aee1ca51aaa61fe`.
All SourceV2-only tests, boundary, arm64, package and injection audits pass. The
corrected live behavior awaits the bounded Gate 2C device repeat.

## 2026-08-18 — Gate 2C `.2` isolated Engine full-name abort

`V2-G2C-ENGINE-FULLNAME-ABORT-002` executed the exact `.2` artifact in a local
TheIsland world. Its fresh Gate 2B generation completed in 46 ms with 107,279
objects/two chunks and every required FName, object/function and reflection
validator passing. The relationship phase accepted zero bytes and failed the
split strict instance full-name predicate. Runtime class `ShooterEngine` was
therefore reached, but `.2` ordering did not reach CDO, exact direct-UClass,
ancestry or any Engine/World relationship field. World generation stayed zero;
hooks, engine calls and mutation remained zero.

Exact FreshSDK records `Package Transient` and
`ShooterEngine Transient.ShooterEngine_2147482613`; closest UE source creates
the transient package as `/Engine/Transient`. The `.3` correction canonicalizes
only that exact owner alias, retains the numbered instance full-name and all
class validators, moves full-name validation after direct-class/ancestry checks
and adds bounded printable address-free observed-name diagnostics. A canonical-
alias positive and unnumbered negative bring both normal and UBSan-only suites
to 393 assertions; boundary audit passes. Clean artifact packaging remains
next. Gate 3 and hosting remain closed.

## 2026-08-19 — Gate 2C full-name correction built

`V2-G2C-ENGINE-FULLNAME-FIX-BUILD-012` was produced from clean revision
`f4598395efeadcd882af5f257b1e6d72a78de6d3` and annotated source tag
`v2-gate2c-live-relationships-20260818.3-source`. Raw dylib SHA-256 is
`4b7ddd7cf68cd089c69ca632415ec0a56594e49f60be0dccabc438dd471e2ae3`;
Mach-O/dSYM UUID is `78EAF0B0-9C08-39BE-B37B-25E4A8EC7629`; manifest SHA is
`a821b4a88a8228b1f3b81d4c00da063b7103aa2ca35854ec24f95d369bc6749b`;
the archival `.deb` SHA is
`18d4dd6dab7d02325d4e2ce3f513cf1cbe0403d7263424669b2a5bcae674e8f6`.
Both 393-assertion SourceV2 suites and all boundary, arm64, package, manifest,
dSYM and injection-isolation audits pass. The exact `.3` runtime behavior
awaits the bounded Gate 2C device repeat.

## 2026-08-19 — Gate 2C `.3` first TheIsland relationship PASS

`V2-G2C-MAP-RELATIONSHIPS-PASS-003` executed the exact `.3` input in an already
loaded local TheIsland world. The fresh prerequisite snapshot completed in
45 ms with 180/399,305 FName blocks/entries, 106,725 valid objects in two chunks
and every required validator passing. The relationship phase completed in 2 ms
and 10,240 bytes. Native Engine ownership, exact non-CDO ShooterEngine direct
class and GameEngine/Engine ancestry, GameViewport, live World and the
independent GWorld/ViewportWorld identity comparison all passed. The populated
definitions array decoded one `GameNetDriver` with EOS primary and IpNetDriver
fallback; the expected pre-host NetDriver state was `none`.

Discovery/world generation was `1/1`; there was no previous accepted world to
invalidate. Hooks, engine calls and mutation stayed zero, and the user reported
no errors. This device-verifies the map relationship subset without rewriting
the immutable `.1/.2` aborts. Gate 2C remains open for repeated same-world
generation stability, menu lifecycle and transition invalidation. Gate 3 and
hosting remain closed.

## 2026-08-19 — Gate 2C optional relationship receipt corrected

The `.3` device report proved the map relationship subset but did not publish
AuthorityGameMode/GameState presence, despite the capture already validating
both optional fields against the fresh snapshot when non-null. `.4` adds two
bounded redacted presentation fields sourced from those owned optional views;
it performs no new memory read or ABI resolution. Present values explicitly say
that the GameModeBase/GameStateBase class was validated; absent World reports
not-applicable.

`V2-G2C-OPTIONAL-RELATIONSHIP-RECEIPT-BUILD-013` was produced from clean source
`4db2599d25350b1eadd9d704afcba2fe76743473` and tag
`v2-gate2c-live-relationships-20260819.4-source`. Raw dylib SHA-256 is
`95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677`;
Mach-O/dSYM UUID is `7CB1B073-D9A5-39E0-BDD3-2638B0618B28`; manifest SHA is
`0a7cd36e23430cc616cfb91608964f60267ca2e1e75f69f9d17c5d677bb99387`;
the archive SHA is
`190ffbb9addb5e1b3a388d5e5cda168042e0df7738c34e1203f4b8259f78bbcb`.
Both 399-assertion SourceV2 suites and every boundary, arm64, package, dSYM and
injection-isolation audit pass. The full `.4` device sequence remains pending;
Gate 3 and hosting remain closed.

## 2026-08-19 — Gate 2C `.4` optional relationships map PASS

`V2-G2C-OPTIONAL-RELATIONSHIPS-MAP-PASS-004` executed the exact `.4` input in
an already loaded ordinary TheIsland world. Fresh discovery generation 1
completed in 43 ms with 180/399,305 FName blocks/entries, 106,725 valid objects
in two chunks and every prerequisite validator passing. The relationship phase
completed in 2 ms/10,240 bytes. Engine/Viewport/World/GWorld/definitions and the
normal null NetDriver state passed. The new receipt explicitly showed
AuthorityGameMode and GameState present with validated GameModeBase and
GameStateBase relationships. Hooks, engine calls and mutation remained zero;
the supplied bounded logs contain no error entry.

This proves the `.4` positive optional-publication map path. It is still the
first accepted `.4` world (`discovery/world=1/1`), so same-world stability,
menu lifecycle and transition invalidation remain open. Gate 3 and hosting are
not started.

## 2026-08-19 — Gate 2C `.4` independent map relationships reproduced

`V2-G2C-INDEPENDENT-MAP-REPRODUCIBILITY-PASS-005` executed the same exact `.4`
input and completed another positive map capture in 38 ms plus 2 ms/10,240
relationship bytes. The fresh snapshot contained 180/399,628 FName
blocks/entries and 109,440 valid objects in two chunks. Engine, GameViewport,
World, independent GWorld match, definitions, present/class-validated
AuthorityGameMode and GameState, and normal pre-host `net_driver=none` all
passed. Hooks, engine calls and mutation remained zero; the bounded logs contain
no error or raw address.

The generation receipt was again discovery/world `1/1` with top-level previous
discovery `not applicable`. This proves independent positive map
reproducibility, not a repeated capture in the same tracker state. Discovery
increment, same-world stability, stale-handle invalidation and lifecycle
transition remain open. Gate 2C is not closed; Gate 3 remains blocked and not
started. No SourceV2 or artifact correction is justified by this result.

## 2026-08-19 — Gate 2C continuous map generations passed; menu lifecycle remains

`V2-G2C-CONTINUOUS-MAP-GENERATIONS-PARTIAL-006` processed three exact `.4`
captures from one continuous process. Cumulative sequence numbers and monotonic
uptime prove one tracker session. Discovery advanced `1->2->3`; the second
capture advanced world generation `1->2` and invalidated the prior world-bound
identities; the third used another fresh discovery snapshot but retained world
generation 2 and did not invalidate the unchanged current World. Engine,
GameViewport, World/GWorld match, canonical definitions, present/class-
validated AuthorityGameMode and GameState, normal pre-host `net_driver=none`
and zero hooks/engine calls/mutation passed throughout. No bounded-log error or
raw address was present.

All three captures reported lifecycle `map`. The validated map-world
replacement proves the generic world-generation transition mechanism but does
not establish menu lifecycle or a natural menu/map transition. The user also
did not supply a separate visible gameplay/input/audio regression observation.
Under the current `.5` exit record, Gate 2C therefore remains open for one
natural menu capture in the same still-running process, or a new continuous
menu-to-TheIsland-to-same-TheIsland run if that process ended. Gate 3 remains
blocked and not started. No SourceV2, Legacy, build configuration or artifact
change is justified, and no build was run.
