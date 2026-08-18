# Gate 1 typed foundation evidence report

Report ID: `GATE1-TYPED-FOUNDATION-2026-08-18`  
Workflow / ABI backlog IDs: Roadmap Gate 1; ABI-001 through ABI-008  
Date: 2026-08-18  
Author/task: first Server-Host V2 implementation workflow  
Exact platform and build identity: host-local arm64 macOS test executable;
ShooterGame iOS 1.10280 is layout input only and was not loaded  
FreshSDK/source paths used: both current `Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame*` trees  
Sishen files/functions read for pattern comparison: listed below  
Device artifact/build and log paths: none; no device test belongs to Gate 1  
Claim status before: unverified/not started  
Claim status after: compiled and statically validated; live/runtime claims remain unverified

## Question and boundary

The workflow asks whether the separate V2 target can express the first UE
identity/reflection contracts without importing the generated SDK or enabling
game behavior. The implemented boundary contains no injection, hook,
`ProcessEvent`, native engine call, host/client/save/admin operation, UI, or
legacy object file. The real iOS profile cannot become available until Gate 2
captures an exact loaded-image identity.

## Sishen patterns studied and disposition

| Source | Actual pattern read | ShooterGame 1.10280 adjustment |
|---|---|---|
| `Source/UnrealEngine/Containers.hpp` (`FMemory`, `TArray`, `TFreedArray`, `FString`) | 16-byte Data/Num/Max shape, iterators and engine realloc ownership intent. | Kept the 16-byte ABI shape; split it into a validated borrowed view and move-only portable `OwnedFString`. Rejected global realloc, shallow ownership, throwing index access and non-owning `FString(const char16_t*)` presented as ownership. |
| `Source/UnrealEngine/NameTypes.hpp` (`FNameEntryHeader`, `FNamePool`, `FName`) | Header/stride/block decoding and a compact comparison-index/number value. | Used current FreshSDK offsets (`CurrentBlock 0xC8`, cursor `0xCC`, blocks `0xD0`), span bounds, UTF-16 validation and equality including `Number`. Rejected global pool state and unchecked block dereference. |
| `Source/UnrealEngine/ObjectArray.hpp` and `ScriptCore.h/.mm` (`FUObjectItem`, `TUObjectArray`, `FWeakObjectPtr`) | Chunked objects plus serial/pending/unreachable validation. | Kept index+serial validation as a snapshot contract and added world generation. Rejected off-by-one chunk/capacity checks, unchecked `Get`, and index-only equality. Live serial extraction remains ABI-006. |
| `ScriptCore.h/.mm` (`UObject`, `UField`, `UStruct`, `UClass`, `UFunction`, `FField`, `FProperty`) | Curated reflection hierarchy, full-name/class-chain lookup, field traversal and function metadata. | Implemented value/snapshot views and descriptors plus static current layouts. No raw live reader, generic member-by-offset API, static raw pointer cache, flag mutation or invocation exists. |
| `Source/StaticClasses.h` (`GetStaticClassImpl` and Engine/World/NetDriver/Shooter/Kismet helpers) | Central cached class discovery. | Replaced forever-static short-name `UClass*` values with a full-name, generation-aware descriptor cache that is invalidated on generation change. |
| `Source/Functions.mm` (`UnlockExplorerNote`, `ServerMultiUse`, `MakeHitResult`, `ExecuteConsoleCommand`, `Conv_StringToName`) | One wrapper, local parameter record, cached `UFunction`, then `ProcessEvent`. | Adopted only the future wrapper shape. Gate 1 implements descriptor validation and zero invocation. Static raw caches, missing metadata checks and `FunctionFlags` mutation were rejected. |
| `Utilities/Memory.h`, `Source/Libraries/CGuardMemory/CGPMemory.h/.cpp`, `Source/Offsets.h`, `Source/SigsAndOffsets.txt` | Central image/RVA, mapped memory, scan and call facilities. | No live facility is implemented in Gate 1. Their separation informed `BuildIdentity`/`BuildProfile`/validator interfaces; coarse address ranges, global base state, first-match scans, writes and arbitrary calls were rejected. |

Sishen `CommonTypes.hpp`, `Enums.hpp` and the relevant declarations in
`GameStructs.h` were also compared for exact-width types and enum/type usage;
no old field offset, signature, vtable index or function ABI was copied.

## FreshSDK exact comparison

The following standard/Full-Version files compared byte-identically:

- `UnrealContainers.hpp`;
- `SDK/Basic.hpp` and `SDK/Basic.cpp`;
- `SDK/CoreUObject_classes.hpp` and `SDK/CoreUObject_functions.cpp`;
- `SDK/Engine_classes.hpp` and `SDK/Engine_structs.hpp`;
- `SDK/ShooterGame_parameters.hpp` and `SDK/ShooterGame_functions.cpp`.

`SDK/ShooterGame_classes.hpp` differs through removal of `final` qualifiers in
the Full-Version tree; the compared fields and function declarations do not
change. Standard-tree SHA-256 inputs used for the review:

| File | SHA-256 |
|---|---|
| `UnrealContainers.hpp` | `2e295d0c13e5eda9ece8a59567e01039b03348bd1fc47e8a2591474093a0194a` |
| `SDK/Basic.hpp` | `3499179545180229e1d693b914a9b1ec1cd41d5fdd594661238c5e86f7bcd54d` |
| `SDK/CoreUObject_classes.hpp` | `555907af289485be0643a6389af9f99937e3f666c07604189ed9a35f61aca561` |
| `SDK/Engine_classes.hpp` | `5105979cabe7cf517fd10f63a71a03cd7ecf538f5b6535884b44768c7415015c` |
| `SDK/ShooterGame_classes.hpp` | `07166455d2d6069a8701d9e0be60c45a00bb3d06909f7a70155bb4e2c19242b0` |

The current Engine/Shooter headers were inspected at the exact declarations for
`UEngine` (`GameViewport 0x780`, `NetDriverDefinitions 0xBF8`), `UWorld`
(`NetDriver 0x1D8`, authority mode `0x2B8`, game state `0x2C0`),
`UGameViewportClient` (`World 0x70`), `UNetConnection`, the core player types,
and the Shooter game mode/state/controller/state/player-data classes. These
members are not emitted into Gate 1 model views. Current recovery parameters
remain size 8 for `ClientSetHUDAndInitUIScenes` and size 1 with a bool for
`ClientShowCharacterCreationUI`; no wrapper was implemented.

## Dragon/ProjDragon comparison

| Source | Pattern observed | V2 adjustment |
|---|---|---|
| `Source/CppSDK/UsedSDK.hpp` and Makefile `SOURCE_BASE` | A generated SDK was narrowed to selected Engine/Shooter compilation units. | V2 uses an explicit source list and further reduces generated input to one reviewed assertion header; no generated header enters feature code. |
| generated `Basic.hpp/.cpp`, CoreUObject classes/functions | Typed fields, static classes and a serial-checking `GetSafe`. | Kept typed readability and serial intent; fixed index-only equality, added generation, removed stale raw caches and fail-open access. |
| `FrameTaskManager.h/.mm` | Direct `World->PersistentLevel`, `NetDriver->ServerConnection`, generated class access and unbounded `std::function` queues. | Used only as evidence that typed feature code is readable. Public generated fields, raw captures, unbounded queues and CDO vtable changes were rejected. |
| generated Shooter wrappers | Zero-initialized parameter records followed by `ProcessEvent`. The older `ClientShowCharacterCreationUI` has no bool. | Wrapper style is deferred; current FreshSDK's bool parameter wins. Gate 1 performs no dispatch. |

## Curated layouts and explicit gaps

The compile-time report asserts exact current FreshSDK sizes/alignments/used
offsets for `TArray`, `FString`, `FName`, `FNamePool`, `FUObjectItem`, the direct
`TUObjectArray`/GObjects view, `UObject`, `UField`, `FStructBaseChain`, `UStruct`,
`UFunction` outer size/`FunctionFlags`, `UClass`, `FFieldClass`, `FFieldVariant`,
`FField`, `FProperty`, `FBoolProperty` and every emitted enum value.

Two contracts deliberately remain unavailable:

1. FreshSDK points `GObjects` at `0x5D434E8` as a direct `TUObjectArray`, while
   the legacy profile proposes `0x5D434D8` and an `FUObjectArray` prefix whose
   object array begins 0x10 bytes later. Gate 1 models the exact FreshSDK direct
   view and does not assert the legacy prefix or serial offset.
2. FreshSDK confirms `UFunction` size `0xE0` and `FunctionFlags` at `0xB0`, but
   does not emit raw `NumParms`, `ParmsSize` or `ReturnValueOffset` members. V2
   models them as descriptor values for negative/static tests only. Gate 2 must
   prove the live offsets before a raw reader is added.

## Static execution result

Command:

```text
make -f SourceV2.mk clean all test audit
```

Result: PASS, 56 assertions, 0 failures. Compilation used C++20 with
`-Wall -Wextra -Wpedantic -Werror`; no compiler warnings were emitted. Tests
cover malformed TArray layouts, FString termination/embedded-null/UTF-16 rules,
narrow and wide FName decoding/number suffixes, index+serial+generation identity,
pending-kill rejection, generation-aware function/class caches, malformed
property/function metadata, unsupported/malformed profiles and inert status.

Artifact:

```text
/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/.build/v2-host/serverhost_v2_core_tests
SHA-256 fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5
Mach-O 64-bit executable arm64
```

The boundary audit found zero `reinterpret_cast` occurrences and zero direct
`.data() + offset` occurrences in `SourceV2`; Runtime, Services, UI and Features
do not exist yet and therefore contain no raw access. Layout pointer members are
confined to `Bindings/Generated`; safe name-byte traversal is confined to the
lowest `UE` span implementation.

No device, live process, Mach-O profile, object array, name pool, class,
function, property, hook or gameplay behavior was tested. Synthetic tests are
not live validation.

## Inert iOS packaging supplement

The user subsequently requested an installable V2 package. The selected target
`make -f SourceV2.mk ios-package` first reran all 56 host assertions and the
dependency/raw-access audit, then built only the current Gate 1 production
sources plus `Bootstrap/V2Entry.mm`. The package has its own ID and output
directory:

```text
/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb
SHA-256 4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35
build ID gate1-inert-package-20260818.1
```

The packaged arm64 `ServerHostV2.dylib` SHA-256 is
`5e86253a9b5008ea1d22cc07db8ddbdfb1d77223e099ec403f697caa06acd60d`.
Package metadata, file listing, plist syntax, Mach-O architecture, linkage,
signature and staged/package byte equality were inspected. Banned gameplay
symbols/strings were absent. The linker emitted only Theos' inherited
`-multiply_defined is obsolete` warning; Xcode cache/FSEvents and Theos
parallelism notices were non-fatal.

For startup pattern review, Sishen `Source/Main.mm` `Initialize`,
`InitializeStaticOffsets` and `InitializeDefaultHooks`, plus its Makefile and
plist/control files, were read. V2 adopted the recognizable explicit package
entry and source-list organization. It rejected Sishen's delayed block,
detached thread, scanning, global binding initialization, anti-cheat changes and
hook installation. V2Entry calls only the already-tested strict validator with
missing live identity and emits one bounded console line:

```text
[ServerHostV2] build=gate1-inert-package-20260818.1 state=missing-identity-evidence profile=ios-shootergame-1.10280-pending-image-identity hooks=0 engine_calls=0 mutation=0 detail=profile lacks approved image identity evidence
```

The constructor and log line are runtime startup, but they do not begin Gate 2:
there is no image reader, resolver, object/name access, Engine discovery, hook,
call or mutation. Device loading and the exact console line remain unverified.
