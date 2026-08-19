# Server-Host V2 project

## Purpose

Server-Host V2 is a separate, evidence-backed in-process hosting and client
integration layer for the mobile ShooterGame application. It uses validated
Unreal Engine and ShooterGame paths to turn a locally loaded world into an IP
listen host and allow another modified client to connect and reach gameplay.

It does not emulate Unreal networking or reimplement the game server protocol.
It should restore or invoke game-owned initialization, replication, login,
player-flow, travel and later persistence operations through typed, validated
bindings.

## Current goal and active stage

The near-term platform is iOS:

- host: the iOS game running on an Apple Silicon Mac;
- client: a physical iPhone running the compatible modified game;
- build under study: ShooterGame 1.10280 / UE 4.26.2;
- completed workflow: Roadmap Gate 1, the host-local static typed identity spine;
- Gate 1.5 state: corrected `.2` has a bounded functional device PASS for icon,
  Metal/ImGui, Status/Logs/Copy/Close/reopen; longer soak and independent
  outside-window touch verification were not separately reported;
- Gate 2A exact ShooterGame image/profile identity is device-verified, with
  `scans_started=0` and every capability counter at zero;
- death/respawn exit reproduced without any injected dylib and is deferred as
  an external baseline limitation; B/C were waived by user decision;
- Gate 2B read-only FNamePool/GUObjectArray/reflection snapshots are complete
  for the scoped main-menu/TheIsland protocol; optional return-menu capture and
  longer soak were not reported;
- active workflow: Gate 2C read-only Engine/world relationships. `.1` and `.2`
  aborted fail-closed at distinct Engine identity predicates with zero
  capabilities; exact `.3` passed its first TheIsland Engine/Viewport/World/
  definitions capture with world generation 1 and zero capabilities, but its
  public receipt omitted optional GameMode/GameState presence. Clean `.4`
  device-publishes both as present/class-validated. Continuous `.4` result `.6`
  proves discovery invalidation, validated map-world replacement and a fresh
  unchanged-world repeat with zero capabilities. Partial `.7` independently
  reproduces the same continuous generation/relationship behavior, but the
  submitted transcript does not label its visible capture states/actions and
  every runtime lifecycle remains `map`. Menu lifecycle/menu-map transition
  context and an explicit visible-regression observation remain pending. Gate 3
  has not started.

The stable-iOS milestone requires all of the following, in ordered gates:

- exact build/profile and typed UE discovery;
- verified game-thread dispatch and world/object invalidation;
- inert, reversible observation infrastructure where hooks are necessary;
- typed client travel and cleanup;
- game-native host preparation and one IP listen driver without broad forced
  Dedicated semantics;
- near/far replication without host sky/weather/render/audio/animation damage;
- new, existing and reconnecting remote players reaching gameplay;
- repeated lifecycle stability;
- manual save only after gameplay stability.

Transport success alone is not gameplay success, and gameplay success alone is
not persistence or stability verification.

## User-facing outcome

The eventual normal UI may expose Host, Client, proven administration controls
and Logs. A control appears only after its workflow and regression gate passes.
Developer probes remain compile-time gated and separate from release controls.

Logs must make build/profile identity, workflow transitions, refusal reasons and
postconditions understandable without exposing passwords, tokens or private
credentials.

The current canonical manual device-test path is a raw `ServerHostV2.dylib`
injected through Sideloadly into a clean application. The `.deb` remains an
archival/package-inspection artifact that Codex builds and inspects but does not
install.

For Gate 1.5, diagnostics must never degrade into a visible no-op: an accepted
icon action presents the styled diagnostics panel, or a bounded UIKit fallback
names the failed presentation stage. The panel uses ordinary ImGui primitives,
a compact dark cyan/teal palette, a left Status/Contracts/Logs rail and a right content
area. It contains no Host, Client, administration, authentication, remote image
or placeholder controls.

## Technical strategy

The approved structure is defined in [ARCHITECTURE.md](ARCHITECTURE.md):

1. portable Core values and strict object/thread identities;
2. minimal UE primitives, owned/borrowed containers/strings, names, object array
   and reflection views;
3. typed Engine and ShooterGame model views;
4. exact-build Profiles, Resolver, Generated slices, Native/Script bindings,
   Validation and platform facilities under the raw Bindings boundary;
5. isolated Hook transport with small observer/policy layers;
6. bounded game-thread Runtime context and dispatcher;
7. one stateful Service per user outcome;
8. bounded Diagnostics and a UE-free UI adapter.

The typed surface grows from workflow demand. A new type/field/function requires
current evidence, static assertions where applicable, runtime validation and a
device gate. Feature code cannot add arbitrary offsets or generated public
fields.

## Evidence strategy

Sishen is the primary code-pattern authority for UE mod organization, core
types, lookups, wrappers, memory and hooks. Future tasks must read the relevant
Sishen implementation before designing the corresponding V2 subsystem.

Current ABI and addresses come from the exact 1.10280 binary, both current
FreshSDK dumps and live reflection/device evidence. Dragon is a secondary typed
generated-SDK pattern. UE4.17 provides lower-priority engine behavior context.
SEA informs deferred control-plane behavior. None of those lower-priority
examples can override exact-build evidence.

## Existing legacy implementation

`Source`, `Menu`, `MenuLoad`, the legacy Makefile and historical packages are
research/regression sources. They include valuable behaviors and experiments,
but also a coupled HostingRuntime, raw ABI access and mixed verification state.
Their disposition is recorded in [MIGRATION_MAP.md](MIGRATION_MAP.md).

Known control identity and historical result (artifact file currently missing):

```text
/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.11+debug_iphoneos-arm.deb
SHA-256 54dda1d682bc01f5fbd38a078a33994c23ffbe4ac6d466c978ffa86775ae8dbf
```

The matching 0.2.11 source snapshot is missing. Strings, symbols and disassembly
may establish a behavior map but must never be presented as recovered source.
The `.deb` itself was removed by a later Theos clean and no duplicate was found,
so this path is a historical record rather than an available rollback.

## In scope now

- iOS V2 typed core, binding/profile validation and host-local tests;
- UE-free diagnostic UI, redacted identity receipt and raw-injection handoff;
- Gate 2A exact Mach-O identity/profile and checked read-only platform boundary;
- exact current iOS binary/FreshSDK analysis needed by the active gate;
- later, one ordered iOS runtime/device workflow at a time;
- preservation of legacy/control artifacts and living documentation.

## Out of scope now

- changing or deleting legacy gameplay behavior;
- compiling the full FreshSDK into V2;
- speculative save, administration, generic console or broad ProcessEvent APIs;
- a production caller-RVA GetNetMode whitelist;
- Android implementation, emulator/VPS supervision, public server directory,
  web panel, heartbeat, backups or external command service;
- EOS work unless a bounded workflow produces evidence that EOS is its blocker.

## Long-term direction

After the iOS stability gate, obtain the exact Android `LibUE.so`/IDA path and
add an Android build profile plus platform/hook backend while reusing only the
portable typed/runtime/service layers. An Android emulator may later run on a
VPS under a separate control plane providing heartbeat, start/stop/restart,
save, configuration, administration, audit and backup behavior. These wishes
must not enlarge the near-term typed API.

## Claim model

The project distinguishes `compiled`, `statically validated`, `ready for device
test`, `device verified`, `contradicted` and `unverified` exactly as defined in
[README.md](README.md). A function is not device verified merely because it is
found in source, matches a signature, returns success or does not crash.
