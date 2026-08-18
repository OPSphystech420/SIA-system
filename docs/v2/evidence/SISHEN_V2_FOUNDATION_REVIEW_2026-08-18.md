# Sishen pattern review for the V2 foundation workflow

Report ID: `SISHEN-V2-FOUNDATION-2026-08-18`  
Date: 2026-08-18  
Workflow: clean V2 foundation and Gate 2 preparation  
Reference root: `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main`  
ABI authority: none; Sishen is pattern evidence only

## Material read

- `Makefile`, including target/toolchain flags, grouped source variables,
  wildcard use and the final tweak source list;
- `Source/Main.mm` startup at `InitializeStaticOffsets`,
  `InitializeDefaultHooks`, `InitializeUnreflectedOffsets` and constructor
  `Initialize` (approximately lines 4271–4400), plus corresponding declarations
  in `Source/Main.h`;
- `Source/UnrealEngine/CommonTypes.hpp`, `Containers.hpp`, `NameTypes.hpp`,
  `ObjectArray.hpp` and the relevant `ScriptCore.h/.mm` object/reflection access;
- `Utilities/Memory.h`, `Source/Offsets.h` and the referenced signature/offset
  organization.

## Adopted

| Pattern | V2 use |
|---|---|
| Build source categories are visible rather than hidden in an IDE project. | V2 keeps separate explicit production/test/iOS source allowlists. |
| Startup has recognizable responsibilities rather than one anonymous body. | V2 entry performs Legacy isolation, then strict profile validation, then one bounded inert report. |
| UE primitives, containers, names, objects and reflection are separate layers. | V2 retains these module boundaries and exact-width value types. |
| Offset/address concerns are centralized away from feature logic. | Future Gate 2 raw image/memory work is restricted to `Bindings/Platform`; none was added in this task. |

## Adapted

| Sishen pattern | V2 adaptation |
|---|---|
| `TArray` Data/Num/Max and `FString` representation | Preserve only the reviewed layout; validate counts/capacity/termination and distinguish borrowed versus host-owned storage. Engine ownership transfer remains unavailable. |
| `FName` index/number with block-based pool organization | Preserve the compact value and bounded decoding idea; use current curated 1.10280 evidence and span bounds. No global unchecked pool pointer. |
| Chunked object array, serial and pending/unreachable intent | Use snapshots plus full index/serial/world-generation identity. Live root/chunk/serial reading remains Gate 2 evidence. |
| Central cached class/function discovery | Use full-name generation-aware descriptors and invalidation, not permanent raw pointers. |
| Grouped startup phases | Keep ordering, but every phase must return a checked state and fail closed; no delay is treated as readiness proof. |
| Image-base/RVA helper separation | Keep the future platform boundary, but require exact image identity, segment ranges and checked reads before address resolution. |

## Rejected

- Every Sishen offset, signature, vtable index, prototype and concrete class
  layout as a current ABI source.
- Wildcards for the V2 runtime source list; a new file must be intentionally
  admitted to each applicable target.
- The `Memory` singleton's one-value image-base cache, substring-only identity,
  coarse address range heuristic, generic writes and arbitrary address calls.
- Global `FNamePool`/`GUObjectArray` state and unchecked block/chunk dereference;
  object-array boundary conditions are re-derived rather than copied.
- Constructor anti-cheat changes, immediate raw hooks, a two-second delayed
  block, detached infinite cache thread, CDO vtable mutation and partial startup
  after a failed prerequisite.
- Using engine realloc through global function pointers as portable ownership.
- Treating compilation of old structs as proof that a current live object has
  that layout.

## Workflow effect

This review influenced only V2 organization, guard ordering, build allowlists
and the already-curated typed foundation. It did not add live image discovery,
memory reads, UE lookups, hooks, `ProcessEvent`, hosting, travel or mutation.
All current ABI remains governed by the 1.10280 binary, current FreshSDK and
future Gate 2 live evidence.
