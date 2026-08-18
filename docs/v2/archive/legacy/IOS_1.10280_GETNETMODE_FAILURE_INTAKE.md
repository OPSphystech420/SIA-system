# ShooterGame 1.10280 host visual-regression failure intake

Report ID: `IOS-1.10280-GETNETMODE-FAILURE-INTAKE-001`  
Workflow / ABI backlog IDs: legacy host sky/weather/world-animation regression;
`ABI-016`, `ABI-017`, `ABI-018`, `ABI-024`  
Date: 2026-08-18  
Author/task: Codex failure-intake workflow  
Current execution status: **SUSPENDED** by exact A host-started signal failure
`LEGACY-HOST-SIGNAL-EXIT-001`; see
[host-started signal-exit intake](IOS_1.10280_HOST_STARTED_SIGNAL_EXIT.md). The
earlier no-host interpretation was withdrawn. The IDA findings remain valid,
but the policy A/B protocol below must not run until A has a stable host-started
baseline.  
Exact platform and build identity: reported Apple Silicon Mac iOS host; deleted
installed legacy package SHA-256
`217c15cba0f634ee9427b219d30f17a2f917045d9683f35ea8bbc02079cb15f4`;
package bytes/build metadata, app UUID shown at runtime, OS version, map and
attempt count were not supplied  
Binary/database absolute path and identity:

- `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64`, SHA-256
  `4088f9d0136ed4ee2e4e9a5d7408fa3182144379f257920844f84a13ba439c4d`;
- `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/com.studiowildcard.arkuse-1.10280-Decrypted/Payload/ShooterGame.app/ShooterGame`,
  SHA-256 `d98d25778e893413ebd6c4da9156e1b74efe2b203bc488393795c3db6c83a178`,
  Mach-O UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC`.

FreshSDK/source paths used: both `Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame*`
trees; current `Menu/HostMenu.mm`, `Source/Hosting/HostingRuntime.h/.mm`,
`Source/Hosting/HostingConfig.h`; UE4.17 `NetDriver.cpp` and `World.cpp`  
Sishen files/functions read for pattern comparison: `Source/Main.h`
`VMTHookManager`, `Source/Main.mm` `InitializeStaticOffsets`,
`InitializeDefaultHooks` and constructor flow, `Utilities/Hook/hook.h/.c`,
`Utilities/Hook/patch.h`, and `Utilities/Memory.h`  
Device artifact/build and log paths: failing package deleted; no logs supplied  
Claim status before: legacy later-build result mixed/unverified; visual regression
known only as a broad historical report  
Claim status after: host visual stability for the reported legacy hosted-hook
workflow is contradicted; target, transport and policy causality remain unverified

## 1. Isolated question

This intake covers exactly one observation: after hosting hooks become active on
the host, sky/weather/world lighting or effect animation changes abnormally.
Administration, save, reconnect persistence and return-to-menu are not part of
this investigation.

The observation is accepted as runtime evidence. It establishes a visible
regression for the hash-identified deleted artifact/workflow. The hash does not
recover the package's bytes/source or establish that hook installation alone
caused the change.

## 2. Expected and observed state transitions

Expected transition:

```text
unmodified local world / original mode
  -> Start requested
  -> validated hosting preparation
  -> UWorld::Listen creates the hosted GameNetDriver
  -> host remains a rendered ListenServer
  -> sky/weather/world animation remains comparable to pre-host state
```

Observed transition reconstructed from the user report:

```text
local world appears usable
  -> hosting hooks are created or hosting becomes active
  -> hosting continues far enough for the host character/world to remain visible
  -> host sky/weather/world light or effects animate abnormally
```

Unknown transition facts: package bytes/build metadata; whether the first bad
frame occurs at hook installation, `Listen`, policy activation, client
connection, or later; map/time-of-day; logs; reproducibility; crash material;
and whether an unmodified same-session control is normal.

## 3. Package and source delta

The last known working behavioral control is legacy `0.2.11`, which reached
physical-iPhone gameplay. Its recorded SHA-256 is
`54dda1d682bc01f5fbd38a078a33994c23ffbe4ac6d466c978ffa86775ae8dbf`, but the
package file and matching source snapshot are missing. There is therefore no
recoverable exact source diff from `0.2.11`.

The failing package itself is deleted but now has the immutable SHA-256
`217c15cba0f634ee9427b219d30f17a2f917045d9683f35ea8bbc02079cb15f4`.
No local package has that hash. Hash identity anchors the failure row but cannot
recover package metadata, its embedded dylib or a source delta.

The current legacy tree identifies itself as `0.2.24`. Its existing
`.theos/packages/com.mhga.serverhost-0.2.24` file is a one-byte Theos version
marker, not an installable package. This intake forced a full current-source
arm64 rebuild and preserved an installable investigation control at
`packages/com.mhga.serverhost_0.2.24-4+debug_iphoneos-arm.deb`, SHA-256
`2a23ba8c9286085a79dced8ecb07464b48e9be3be32189bea98f1bb3cb64c87c`.
Its staged dylib SHA-256 is
`07a4dda03d2cc7440b9bf6f1466dfdf29d761fb1661c4a97b2ca6e92a431ac61`.
This is a reproducible current-source A/control candidate produced after the
report, not the installed failing artifact and not a corrected package.

The smallest inspectable current-source policy chain is:

1. the normal Host button calls `RequestHost(..., true, true)`;
2. `ExecuteHostRequest` stores `DedicatedServerExperimental`;
3. after `Listen` confirms the exact hosted driver, `ResolveNetMode` returns
   `DedicatedServer` for every call on that driver except a synchronous-save TLS
   exception;
4. unrelated drivers retain their original value.

That is the smallest suspect semantic surface, not a proved delta from 0.2.11.
The current install also creates three hooks together (`UEngine::Init`,
`UWorld::BeginPlay`, `UNetDriver::GetNetMode`), so the report cannot yet isolate
one hook or the mode policy from the transport.

The inert V2 Gate 1 package is not a control for this failure: it installs no
hooks and cannot host. Current-source A retains all three hooks and forced mode
policy; it must not be represented as stable or fixed. Diagnostic B is described
in section 9.

## 4. Current type and reflection checks

Both FreshSDK dumps agree on the relevant static shapes:

| Type/relationship | Current SDK shape | Limit |
|---|---|---|
| `UEngine` | size `0xE08`; `GameViewport` `0x780` | no live object/class validation supplied |
| `UGameViewportClient` | size `0x360`; `World` `0x70` | no live relationship validation supplied |
| `UWorld` | size `0x940`; `NetDriver` `0x1D8`; `AuthorityGameMode` `0x2B8`; `GameState` `0x2C0` | static SDK evidence only |
| `UNetDriver` | size `0x748`; `ServerConnection` `0x88`; `ClientConnections` `0x90`; `World` `0x140` | static SDK evidence only |
| `UFunction` | size `0xE0`; `FunctionFlags` `0xB0` | FreshSDK does not emit raw parameter-count/size offsets |

`UNetDriver::GetNetMode` does not appear as a generated reflected `UFunction`.
It is a native method, so its prototype, entry instructions and callers must be
validated from the exact binary, not from runtime `UFunction` metadata. No
reflected function participates in the current `HookUNetDriverGetNetMode ->
ResolveNetMode` path. Live full-name/class/relationship validation remains
pending; static SDK agreement is not a runtime-reflection pass.

## 5. Sishen pattern disposition

Sishen provides organization and call/lifetime lessons only:

| Sishen pattern | Application here | ShooterGame 1.10280 adjustment |
|---|---|---|
| `VMTHookManager<FuncType>` stores a typed original and exposes `InvokeOriginal` | adopt the typed-original concept and explicit reset/ownership intent | use a reviewed `HookLease`; never reuse Sishen slots, CDO vtables or ABI |
| `InitializeStaticOffsets` then `InitializeDefaultHooks` | adopt recognizable resolve/validate/install phases | exact profile and instruction validators must precede install; no delayed constructor race |
| hardware-breakpoint `hook.c` redirects PC through one exception port | useful transport research input | reject as proven transport: it overwrites exception ownership, has no prior-port chaining/uninstall/new-thread contract, and does not replay an original prologue |
| `Memory` centralizes image and calls | adopt a low-level boundary | reject its forever-cached first image, coarse address range, arbitrary write/call API and old offsets |
| policy callbacks call `InvokeOriginal` explicitly | original call order must be visible | policy must be separate and original-preserving before any semantic experiment |

The pattern comparison supports separation of target resolution, hook transport,
original invocation and policy. It supplies no current address, prototype,
vtable slot or return policy.

## 6. Hook target versus hook policy

The open MCP session was verified against input image SHA-256
`d98d25778e893413ebd6c4da9156e1b74efe2b203bc488393795c3db6c83a178`.
Read-only IDA analysis established:

- native shape `ENetMode UNetDriver_GetNetMode(UNetDriver*)` at
  `0x103A4DE44`;
- the function loads vtable byte offset `0x3C0` (slot 120), calls it with the
  driver, then returns Client `3`, or Listen `2` versus Dedicated `1` according
  to engine client state. The virtual behavior is consistent with `IsServer`;
- the 16-byte prefix is `STP X29,X30`, `MOV X29,SP`, `LDR X8,[X0]`,
  `LDR X8,[X8,#0x3C0]`. The current replay executes those instructions and
  resumes at the indirect call at `+0x10`, which is straight-line
  instruction-compatible;
- 44 direct calls occur in 34 functions. Confirmed sensitive examples include
  `0x1035C89F8` (dedicated-only actor initialization/registration exits),
  `0x1035D2340` (Listen/Standalone distance scale before actor proximity or
  relevancy checks), `0x1035D2564` (client exit plus grid/actor construction and
  distance-scale divergence), and `0x1035D386C` (client exit, stasis-grid policy
  and dedicated-only early return). Its wrapper `0x10388CE74` drains a pending
  actor array before invoking that update.

These checks validate the current target semantics and straight-line replay,
not the deleted package's bytes or the exception backend's prior-port,
new-thread, nesting, register-state and uninstall behavior. Hook transport
therefore remains partial.

Policy evidence is separate and stronger: the current source deliberately
turns the original hosted-driver Listen result into Dedicated for all callers.
The exact binary has dedicated-versus-listen-sensitive callers, so even a
perfect interception can alter unrelated behavior. That establishes semantic
reach, not the sky/weather causal chain.

## 7. Competing hypotheses

| Hypothesis | Supporting evidence | Rejecting/limiting evidence | Distinguishing observation |
|---|---|---|---|
| H1: broad forced-Dedicated policy changes a world/actor/stasis path that affects host visuals | current UI enables the policy; current source overrides every hosted-driver caller; exact binary proves different actor initialization, Listen distance/relevancy and stasis/grid paths for 1 versus 2 | generated weather/sky names do not by themselves produce a call path to these native functions; no caller is proved to own the reported visual state and timing is unspecified | same-source A/B with identical hooks, changing only original versus forced return |
| H2: hardware-breakpoint exception/replay transport corrupts state independently of policy | backend lacks complete prior-port, new-thread, nesting, register/replay and uninstall proof | current source validates entry bytes and reports direct calls; no symbolicated crash/register evidence was supplied | original-preserving hook package versus no-hook control, including thread/background soak |
| H3: late-listen preparation or lifecycle hooks leave ShooterGame in an inconsistent native state | current path patches definitions/login state and starts `Listen` after a normally client-rendered world has begun; exact native preparation is unresolved | no state snapshot or exact first-bad transition was supplied | original mode with inert lifecycle observation, then proven native preparation as a third variable |
| H4: base game/map/time-of-day or another installed tweak produced the visual change | no exact control run, map, package list or timestamp exists | user associates the repeatable symptom with hosting hooks; current policy has independently confirmed broad reach | same-session unmodified/control recording and package inventory |

H1 is promoted only to a justified diagnostic variable, not to the cause.

## 8. IDA trace result and remaining limits

The required database was opened and queried deeply enough to justify one
policy-only A/B. The target, prototype, virtual slot behavior, entry replay and
the named state-changing callers above were decompiled; callers/xrefs and
failure/early-return branches were followed. Local UE4.17 corroborates the
Listen-versus-Dedicated return semantics. FreshSDK confirms the static class
shapes in section 4 and that GetNetMode is not a generated reflected UFunction.

Remaining limits are deliberately bounded:

1. all 44 direct callers have not been semantically named or categorized;
2. generated sky/weather/time-of-day strings did not establish a direct native
   call chain to the sensitive functions;
3. no live reflection report, caller counter, first-bad event marker or transport
   exception trace was supplied;
4. no Android comparison is needed to decide this iOS A/B and none is claimed;
5. the deleted failing package cannot be compared byte-for-byte with the current
   source artifacts.

## 9. Intervention decision and bounded test

The exact caller divergences justify disabling only the force policy as a
diagnostic variable. A default-off compile gate was added; this is legacy
failure research, not V2 Gate 2+ implementation and not a proved fix.

- A/control: `packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb`,
  SHA-256
  `d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e`;
  embedded arm64 dylib SHA-256
  `739b9b994d3f1f4b940f126ff041cc2b426a4db26fe5fb4674537bac9541f439`;
  same gated source with `SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE=0`, current
  hook transport and forced Dedicated policy.
- B/diagnostic:
  `packages/com.mhga.serverhost_0.2.24-7+debug_iphoneos-arm.deb`, SHA-256
  `bf566b6ee77e4ef28fee1099314345a9d31e45e46166519004c4df19b4873956`;
  embedded arm64 dylib SHA-256
  `d88a71290c33856b60ae133b29ee94469416cdb7f097f742ac408d3913705d75`.
  `SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE=1` changes only the normal Host
  request's `ForceDedicatedMode` boolean. The same hooks, host path and login
  option remain, and the log must contain `Diagnostic original-NetMode policy
  armed: hook and host path unchanged; return the engine result`.

The earlier `0.2.24-4` forced package remains preserved as a pre-gate
rollback/reference but is not the same-source A mate for B. The earlier `-5`
diagnostic is also preserved; `-7` is the protocol B so A-to-B installation does
not require a package downgrade.

Exact device protocol: on the same host, ShooterGame build, map and save, record
120 seconds before Start; press Start once; do not connect a client or press any
administration/save control; record 15 minutes after the confirmed `Listen` and
capture package/build hash, hook-install lines, original/returned mode counters,
first visual-change timestamp, screen/video and crash report for three A then
three B attempts. H1 is supported only if A reproduces in at least two attempts
and B remains normal in all three while hosting/transport reaches the same
state. If both reproduce, investigate transport/setup; if neither reproduces,
the result is inconclusive. This is a planned protocol, not a run result.

## 10. Current conclusion

Verification actually run during intake:

- `make -B all` completed a full arm64 legacy rebuild. The only compiler/linker
  warning was `ld: warning: -multiply_defined is obsolete`; Theos also printed a
  non-code notice about parallel GNU Make. The first sandboxed attempt failed
  only because Clang could not write its normal user module cache; the approved
  rerun completed.
- `make package` produced the current-source control named above. Its ar/control
  and data members, package metadata, arm64 staged dylib, plist and embedded
  CodeDirectory were inspected. No device execution occurred.
- read-only IDA MCP calls verified the exact input image and produced the target,
  prologue, xref/caller and state-path results in sections 6 and 8.
- `make -B all SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE=1` and matching
  `make package` produced diagnostic B, then the unchanged selection was rebuilt
  and packaged at revision `-7` after A to avoid a downgrade. Debian
  members/metadata/listing, arm64 payload, embedded CodeDirectory and diagnostic
  strings were inspected. A
  separate full default-off `make -B all` and `make package` produced the
  same-gated-source A. Both builds emitted only
  `ld: warning: -multiply_defined is obsolete`; Theos also printed its non-code
  parallel-build notice. After preserving monotonic B `-7`, a final full
  default-off build restored the staged workspace objects to A semantics.
- `make -f SourceV2.mk all test audit` passed 56 assertions with zero failures
  and the dependency/raw-boundary audit.
- a direct SourceV2 scan found zero production `reinterpret_cast` occurrences
  and zero `.data() +` raw pointer arithmetic occurrences. The only production
  byte copies are bounded `std::memcpy` calls in `SourceV2/UE/Name.cpp`, an
  architecture-approved low UE boundary; `ObjectArray.hpp` has one checked
  typed `static_cast<const T*>`, not pointer arithmetic. No Runtime, Services,
  UI or Features raw access was found.

The smallest policy diagnostic gate is implemented, but no “likely fixed” claim
is made. The earlier claim that A exited before Start was withdrawn after the
user clarified that hosting was active. This host-visual protocol remains
suspended until `LEGACY-HOST-SIGNAL-EXIT-001` establishes a stable host-started
baseline through the panel-hidden/panel-visible control. Transport safety
remains unverified. `HISTORY.md` records both the mistaken interpretation and
its correction.
