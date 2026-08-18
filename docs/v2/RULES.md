# Server-Host V2 engineering rules

These rules apply to planning, reverse-engineering, implementation, debugging,
and handoff. A deviation must be written into `EVIDENCE.md` or a decision record
with a concrete reason.

## 1. Sishen must be studied as the primary code-pattern reference

Do not cite Sishen from memory or from this documentation alone. For every V2
subsystem, inspect the corresponding implementation under
`/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main` before designing or
reviewing it. At minimum, depending on the task, inspect:

- `Source/GameStructs.h`;
- `Source/StaticClasses.h`;
- `Source/Functions.h` and `Source/Functions.mm`;
- `Source/UnrealEngine/ScriptCore.h/.mm` and related UE type/container files;
- `Utilities/Memory.h` and relevant hook/memory utilities;
- its offsets/names organization and applicable startup/game-thread patterns.

Prefer Sishen's useful qualities: typed UE values, small wrapper functions,
cached class/function discovery, explicit parameter structures, and separation
between engine primitives and feature code.

Do not copy its old offsets, signatures, vtable slots, full class layouts, or
function prototypes into the current build without independent validation.

Required Sishen routing:

| V2 work | Sishen implementation that must be read first |
|---|---|
| UE scalar/container/string/name/object types | `Source/UnrealEngine/CommonTypes.hpp`, `Containers.hpp`, `NameTypes.hpp`, `ObjectArray.hpp`, plus relevant `Source/GameStructs.h` declarations |
| class/default-object/function/property lookup | `Source/StaticClasses.h` and `Source/UnrealEngine/ScriptCore.h/.mm` |
| ProcessEvent wrapper or parameter record | corresponding implementation in `Source/Functions.h/.mm` and ProcessEvent transport in `Source/UnrealEngine/ScriptCore.h/.mm` |
| image, address or memory facility | `Utilities/Memory.h`, `Source/Libraries/CGuardMemory/*`, `Source/Offsets.h` and `Source/SigsAndOffsets.txt` |
| hook or original-call organization | `Source/Main.h/.mm` and `Utilities/Hook/hook.h/.c`, `mach_excServer.*`, `patch.h` as applicable |
| startup, static initialization or game-thread organization | relevant phases and callbacks in `Source/Main.h/.mm` |

The task must record which corresponding files/functions it read and which
patterns it adopted, adapted or rejected. If the corresponding implementation
cannot be found or read, stop design of that subsystem and report the missing
input rather than merely naming Sishen.

## 2. Exact-build evidence overrides examples

Evidence priority for current behavior:

1. live behavior and logs from the exact current app;
2. iOS ShooterGame 1.10280 binary/decompilation;
3. current FreshSDK and live reflection metadata;
4. matching Android `LibUE.so` symbols/decompilation;
5. cooked app configuration/assets;
6. closest available UE source;
7. Sishen/Dragon as implementation patterns;
8. SEA as product/control-plane behavior.

Conflicts must be recorded. Never silently choose the convenient source.

Sishen is first among code-pattern references. Current FreshSDK, live reflection
and exact current binary analysis remain the source of truth for layouts,
addresses, signatures, vtable indices, prototypes and behavior.

## 3. Reverse-engineer until the contract is clear

Do not stop at the first function whose name or pseudocode seems plausible.
For important native functions and hooks:

- verify all relevant xrefs and representative callers;
- recover parameter and return types from register/data flow;
- identify whether a function is virtual and record byte offset plus index;
- inspect construction/configuration and teardown paths;
- inspect failure paths and side effects;
- compare iOS logic with Android symbols and UE source where useful;
- record prologue bytes or a masked signature only after understanding what may
  relocate or change;
- distinguish an inline implementation, thunk, wrapper, Blueprint event,
  native implementation, and ProcessEvent-dispatched UFunction;
- label uncertainty and request additional IDA access or device logs when needed.

Time spent proving a contract is preferable to a quick patch that adds another
unknown state.

For current iOS work, the required database is
`/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64`. SEA
client-manager work uses `SEAServerManager.dylib.i64` only when that workflow is
active. Android analysis requires the user-supplied exact LibUE database path.
If the wrong database or no database is open, ask for the exact required one;
do not transpose results between databases.

## 4. Typed UE boundary

Use exact-width UE-compatible types and the game's container/string/name types.
Feature code must not use ad-hoc raw C++ representations for UE objects or
parameter blocks.

Required practices:

- `FString`, `FName`, `TArray`, `TWeakObjectPtr`, UE enums and exact-width ints;
- typed classes/views for `UEngine`, `UWorld`, `UNetDriver`, connections,
  controllers, player state, game mode, game state and player data;
- typed parameter structs for ProcessEvent calls;
- compile-time `sizeof`, `alignof` and `offsetof` assertions where a layout is
  compiled into the build;
- reflection-backed accessors for reflected properties when practical;
- a build-profile descriptor for unavoidable hidden/native fields.

Raw pointer arithmetic, RVA conversion, `reinterpret_cast`, Mach memory probes,
and instruction-byte validation belong only in `SourceV2/Bindings`,
`SourceV2/Hooks`, or the lowest UE core layer. Runtime/features/UI consume typed
interfaces.

## 5. No guessed offsets or magical signatures

Every hardcoded offset belongs to one category and must be labeled:

- stable engine ABI for the identified engine version;
- current reflected property verified at runtime;
- current-build hidden/native layout verified in binary analysis;
- vtable byte offset/index verified for a specific class;
- current-build function/global RVA used only as a guarded fallback.

Signatures are a resolver mechanism, not proof of ABI. A signature match must be
unique and followed by semantic/runtime validation. If the application updates,
the build profile must fail closed until revalidated.

## 6. Hooks are infrastructure, not business logic

Each hook must document:

- why interception is required instead of a direct call, vtable call,
  ProcessEvent, delegate, or state observation;
- exact target identity and ABI;
- hook backend and platform constraints;
- original-call ordering;
- recursion/reentrancy behavior;
- thread behavior and register preservation;
- lifecycle and failure behavior;
- hot-path performance budget.

No logging, allocation, reflection scan, mutex acquisition, string creation, or
complex feature logic is allowed in a high-frequency hook such as GetNetMode.
The hook may record bounded atomic diagnostics and delegate to a small policy.

## 7. Game-thread and UObject lifetime discipline

All UE mutation and ProcessEvent/native gameplay calls run on the verified game
thread unless binary evidence proves otherwise. Commands from ImGui/UI are
queued and revalidated immediately before execution.

Do not trust a cached UObject pointer across world travel, disconnect, garbage
collection, or long delays. Use object index/serial or another verified weak
identity and validate class, ownership and relationship before each mutation.

## 8. One workflow at a time

A workflow is a single outcome such as "transport listen", "remote player
initialization", "far replication", or "manual world save". Do not combine
several unverified outcomes in one implementation task or package.

Within a workflow:

1. reproduce or define the missing behavior;
2. collect evidence;
3. write the contract;
4. implement the smallest change;
5. build one identifiable artifact;
6. run the agreed device test;
7. update documentation before moving on.

Refactoring and behavior changes should be separate whenever practical.

## 9. Current V2 test failures invalidate V2 status immediately

When the user reports a crash, regression, timeout, incorrect state, or failure
for the exact artifact in the current V2 workflow:

- do not defend the previous implementation based only on static reasoning;
- record the exact build, host/client devices, action sequence, visible state,
  logs and crash data available;
- change the feature status to failed/unverified;
- identify the smallest suspect delta;
- disable or isolate it if a safe diagnostic build is needed;
- work only on that workflow until it is resolved or genuinely blocked;
- update the evidence and tests with the new conclusion.

Do not add an unrelated feature while handling the failure.

A Legacy runtime failure is archival evidence and cannot block, replace or
downgrade the active V2 workflow. Route it to `archive/legacy/` without changing
V2 status unless the user explicitly selects a Legacy investigation. A failure
from another V2 workflow also does not silently replace the workflow the user
selected; first establish that it affects the current artifact/capability.

## 10. Logging and diagnostics

Logs must be bounded, structured and visible in both stderr/device console and
the ImGui log view. Include build ID, runtime profile, workflow transition and a
clear refusal reason. Never log server passwords, tokens or private credentials.

Diagnostics that alter timing or hook hot functions must be compile-time gated.
Absence of a diagnostic observation is not proof that an event did not occur if
the relevant diagnostic hook was disabled.

## 11. Release and test claims

Codex may report:

- compiled: local build succeeded;
- statically validated: assertions/signatures/source checks passed;
- ready for device test: an artifact and protocol are available;
- device verified: only after the user supplies passing runtime evidence;
- contradicted: higher-quality evidence or a device result disproved the claim;
- unverified: the claim lacks sufficient current evidence or has mixed/stale
  evidence.

These states are not synonyms and promotions cannot be skipped. A device
failure immediately removes `device verified` from the affected capability,
even if the build still compiles or its static checks pass.

Every artifact must have a unique version/build identifier and full path. The
handoff must state exactly what changed, what remained disabled, expected logs,
pass/fail conditions, and rollback/control artifact.

## 12. Deferred scope

Android emulator, VPS operation, control panel, heartbeat, backups and public
server management remain long-term requirements in `ROADMAP.md`. They must not
drive near-term abstractions beyond clean platform and binding boundaries.

## 13. Documentation and evidence routing

- Read the living documents in the order in `README.md` at the start of every
  task.
- `HISTORY.md` and completed `TEST_MATRIX.md` result rows are append-only.
  Correct a record with a dated clarification; never erase the earlier belief,
  failure or regression.
- `STATUS.md` is the only detailed V2 active-workflow authority. Root
  `../../STATUS.md` is a short V2 entry point. Legacy statuses, reports and
  execution rows live under `archive/legacy/`.
- Keep `EVIDENCE.md` a bounded claim registry. Put deep per-function xrefs,
  decompilation, caller classification, ABI recovery and device-log analysis in
  `docs/v2/evidence/` and link the report from the registry/backlog.
- Every evidence report names exact binary/profile, database/path, addresses as
  diagnostic metadata, uncertainty, conflicts and the workflow it blocks.
- Cross-check links and local paths before handoff. Missing artifacts remain
  explicitly missing; do not invent paths, source snapshots, logs or results.
- A task that changes a requirement, claim, artifact state, device result or
  next workflow updates the relevant living documents in the same task.

## 14. Planning versus implementation authorization

A documentation, architecture or reverse-engineering task does not authorize
runtime edits. An implementation task changes only the active workflow and
preserves legacy behavior unless the user explicitly scopes a legacy change.
No new V2 workflow starts while the current V2 status is awaiting its device
result or a failure of that exact V2 workflow remains under investigation,
unless the user explicitly changes priority. Archived Legacy failures do not
meet this blocking condition.
