# Prompt: first bounded V2 implementation workflow

Run this only after the architecture task has produced and the user has accepted
`docs/v2/ARCHITECTURE.md`.

```text
Begin the first implementation workflow for Server-Host V2 in:
/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host

Read all documents listed in docs/v2/README.md, including the approved
ARCHITECTURE.md, MIGRATION_MAP.md and ABI_BACKLOG.md. If those architecture
outputs do not exist or remain internally inconsistent, do not invent a design;
finish the architecture workflow first and report that clearly.

This workflow is limited to establishing the separate V2 build target and the
first typed UE foundation. It must not host, connect, install behavior-changing
hooks, send RPCs, save, administer players, or modify legacy runtime behavior.

Before implementation, deeply study the relevant Sishen code:
- its fundamental UE integer/enums and containers;
- FName/FString implementation and ownership;
- UObject/UClass/UFunction/field reflection;
- FindObject/FindClass/static class caches;
- typed Functions.mm ProcessEvent wrapper pattern;
- relevant Memory utilities.

Also compare the exact FreshSDK Basic/core files and generated Engine/ShooterGame
headers. Use Dragon/ProjDragon to understand successful generated-SDK usage.
Record exactly which pattern came from which source and how it was adjusted for
ShooterGame 1.10280.

Implementation outcomes:

1. Create the approved SourceV2 directory/module skeleton and a distinct build
   target or build selection. Preserve all legacy files and the legacy build.
2. Implement only the foundational types approved for the first slice, normally:
   - exact-width types and required UE enums;
   - TArray base/view semantics and validity rules;
   - FString/FName/FNamePool representation and safe non-owning/owning behavior;
   - FUObjectArray/object item and verified weak object identity;
   - UObject, UField/FField, FProperty, UClass and UFunction metadata needed for
     lookup and later typed dispatch;
   - build-profile and runtime-validation interfaces, without feature bindings.
3. Add compile-time size/alignment/offset assertions from the current FreshSDK.
4. Keep all raw memory/image/profile access inside the architecture-approved
   low-level modules. No raw access in future Runtime/Features/UI interfaces.
5. Add small static/local tests where possible for container invariants, name
   decoding, cached lookup behavior and weak identity validation. Do not claim
   live validation from synthetic tests.
6. Provide an inert initialization path that can report build/profile status but
   does not hook or mutate the game.
7. Ensure both legacy and V2-selected builds compile independently.

Do not copy the entire FreshSDK into SourceV2. Implement a curated foundation
whose growth process is defined by the architecture.

During the task update:
- EVIDENCE.md for layouts actually confirmed;
- ABI_BACKLOG.md for anything still missing;
- MIGRATION_MAP.md for legacy primitives replaced or intentionally retained;
- STATUS.md with exact implementation/build state;
- TEST_MATRIX.md only with tests actually run or a clearly marked pending test;
- HISTORY.md only if an important prior assumption is disproved.

Before finishing, audit SourceV2 for reinterpret_cast/raw pointer arithmetic and
show that every occurrence is confined to an approved low-level boundary.
Build the artifact, report warnings, full path and exact limitations. The next
workflow should be the smallest inert lifecycle/hook-observation slice, not host
functionality unless the architecture explicitly establishes a different order.
```

