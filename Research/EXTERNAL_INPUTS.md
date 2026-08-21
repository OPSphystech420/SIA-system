# Server-Host V2 external inputs

This manifest was generated from the local MHGA workspace on 2026-08-21. It
contains paths and fingerprints only; none of the named external files is
tracked by Server-Host or required by its host-local test build.

Use `<MHGA_ROOT>` below for the directory that contains `Server-Host`. A
standalone clone remains buildable for host-local V2 tests without these inputs.
Reverse engineering, UI-reference review and device packaging require the
applicable files to be restored outside the clone.

## Path mapping

The historical paths in immutable evidence remain unchanged. The current local
workspace has the following mapping:

| Documentation path | Current local path |
|---|---|
| `<MHGA_ROOT>/Sishen/Sishen-main` | `<MHGA_ROOT>/Sishen/Sishen/Sishen-main` |
| `<MHGA_ROOT>/Dragon/ProjDragon/Dragon` | `<MHGA_ROOT>/Dragon/last/ProjDragon/Dragon` |
| `<MHGA_ROOT>/Extra_For_Host` | unchanged |
| `<MHGA_ROOT>/Server-Host/Reference/FreshSDK` | tracked in this repository; no external mapping |

Do not rewrite immutable evidence paths to hide this difference. New work
should cite the actual path it used.

## Sishen reference subset — external only

Purpose codes: `build` = explicit source organization; `ue` = UE types,
containers, names, objects and reflection; `wrapper` = typed function wrappers;
`memory` = image/address/memory organization; `startup` = startup/game-thread
phases; `ui` = presentation/layout lifecycle.

Local root: `<MHGA_ROOT>/Sishen/Sishen/Sishen-main`.

Provenance/license: no `.git` metadata, upstream identifier, `LICENSE`,
`COPYING` or `NOTICE` was found in the restored tree. Redistribution status is
therefore unknown and no Sishen source was copied.

| Relative source path | Purpose | Bytes | SHA-256 |
|---|---|---:|---|
| `Makefile` | build | 6,818 | `7e457e1e5997fa2dd9c8b4146f1ea20ee62cc82dc061ae8434d56dbd06470d5d` |
| `Source/GameStructs.h` | ue | 9,549 | `7fec660fc254c82a95b7655980b56124eb13db73cd5cfa2bd0ef040ea4a3d36a` |
| `Source/StaticClasses.h` | ue | 609,803 | `e23af036a785e0425ab3c70c7bcbe0f31a0bb5a45f4cbb269ece646e0d271d00` |
| `Source/Functions.h` | wrapper | 8,085 | `299aa7beb29a4d6f038a6f8bf719b0ed2fe3794a90099f3aa3d48efe81636b0c` |
| `Source/Functions.mm` | wrapper | 61,192 | `e6f49c325dd2b77e60e06e614c7814c1f07bb97040abd3b102af38e3412b6143` |
| `Source/UnrealEngine/CommonTypes.hpp` | ue | 13,295 | `fa6da398d61398edefd47a0604aa886aaf6ee86d5764f54b897c58bad9c5ad31` |
| `Source/UnrealEngine/Containers.hpp` | ue | 28,055 | `4f1a11680776f386f022d4a095b46f88b9f3f59a444dba4f891b19d4856efd8e` |
| `Source/UnrealEngine/NameTypes.hpp` | ue | 3,041 | `fa102012b5cd67fb43ef415b72159df0a06491aae782479a5d0e0f86945572df` |
| `Source/UnrealEngine/ObjectArray.hpp` | ue | 1,939 | `35544bb548be61384c96b79e0cb4210244a81846d754c334e1a9f8360008b5f8` |
| `Source/UnrealEngine/ScriptCore.h` | ue/wrapper | 7,358 | `0bd8d58814c4d2e7370129413e3fa0529e8c56cb0f83143f047ae757e9f2aeab` |
| `Source/UnrealEngine/ScriptCore.mm` | ue/wrapper | 3,496 | `d58776ca3f598abc4eb367e5cebb9f188ace2517fb6ca643532ea570c4f07f2e` |
| `Utilities/Memory.h` | memory | 4,832 | `59bcf241135492621182d4282aaee78b9c239a896e797e5ebe36da1bcf4b4d23` |
| `Source/Libraries/CGuardMemory/CGPError.h` | memory | 1,443 | `3981d83737659c2d17d52d9c9644e85aa7bad470b0397d2038264db05e351dc7` |
| `Source/Libraries/CGuardMemory/CGPMemory.h` | memory | 4,691 | `7bc05b548b8571d91e465abdd89e8da08979e05ac08fa36d5cbe22a1f4a6939e` |
| `Source/Libraries/CGuardMemory/CGPMemory.cpp` | memory | 20,676 | `cc065cda62818fd9d2ae05bae551354ff93b91ca26e8ac676368f4f0aa05c5df` |
| `Source/Offsets.h` | memory | 324 | `452d37e990c5aa89f36a9bd0c07993ac3c86cea677bf973b6ba3f7feae18f4bb` |
| `Source/SigsAndOffsets.txt` | memory | 1,077 | `7d361e32c94a3a115458c1c4c659a1874832e27c4826cfe069f2625144d38e87` |
| `Source/Main.h` | startup | 28,427 | `06f049c2e42de1c3981e680121980e3738ef33d2134d6a3dcd129886b4ac3844` |
| `Source/Main.mm` | startup | 104,363 | `0b6de00dce430f7dd753bd3f66a9a1785f2c377255a28df0a713d5e92ab45478` |
| `Menu/UserMenu.mm` | ui | 53,629 | `d7c8de0146ed7e1501db7ee33493560f05039f4efba999e20db5fd179b5802a3` |
| `MenuLoad/MenuLoad.mm` | ui | 15,355 | `cefa2599b938ab59a09b24499bf5525c47255eb912cef5601b98ca6550dac0c8` |
| `MenuLoad/ImGuiDrawView.mm` | ui | 12,541 | `226d828d8b83ae2382ad5e1458e4e68fd620f4c37db0283666d8996f6c69280f` |
| `MenuLoad/ProcessFront.mm` | ui/startup | 14,518 | `ccf608bc1fc81dc6581e266e4030c98b7adb2337105a92b6b45d5cecf9f5b8d2` |

Excluded Sishen areas include login, UDID, authentication/API, remote download,
crypto/security, hide-record/anti-analysis, package payload, gameplay features,
old offsets/signatures and hook implementations. They are neither copied nor
part of the reference subset above.

## ProjDragon reference subset — external only

Local root: `<MHGA_ROOT>/Dragon/last/ProjDragon/Dragon`.

Recorded Git provenance: `https://github.com/ZarakiDev/ProjDragon.git`, local
repository `HEAD` `106882949089afaa3577751457a96a52c0c97e95`. No `LICENSE`,
`COPYING` or `NOTICE` file was found. Several relevant files are locally
modified relative to that `HEAD`, so provenance of their current bytes is mixed.
No ProjDragon source or ARKFont bytes were copied.

| Relative source path | Purpose | State vs HEAD | Bytes | Local SHA-256 |
|---|---|---|---:|---|
| `FrameTaskManager.h` | typed SDK/game-thread access pattern | modified | 19,234 | `4c1e57b0b912457358879fca3c74cfaf1f8c6f9dda95bd595913cacbe80afdae` |
| `FrameTaskManager.mm` | typed SDK/game-thread access pattern | modified | 164,099 | `a4d67c2a555479d9e2c2bdd2f16e8f1e13c091a1034eb597eed2775329a39d86` |
| `Source/CppSDK/UsedSDK.hpp` | curated generated-SDK inclusion | clean | 363 | `9cb5c64136e2faf785897e66fe1f54fac1e2595fb06f01fe4e4f3ce2a362f3c1` |
| `Source/CppSDK/SDK/Basic.hpp` | UE object/name/weak typed access | clean | 33,952 | `2edafbe466f884795f1af3f559e8545574f8503681986eed9caf878d075f618b` |
| `Source/CppSDK/SDK/Basic.cpp` | UE object/name/weak typed access | clean | 3,568 | `3b75caa415816680223c1fbb4759c511632b38ec5c035dec6acea6e37ec7f6fb` |
| `Menu/UserMenu.mm` | UI composition pattern | modified | 167,068 | `093b2c831de3a0b7607b336888e5371e0e28e89a03002be15ca4aab644f27682` |
| `MenuLoad/MenuLoad.mm` | UI/bootstrap pattern | modified | 18,598 | `ac2fcd2e7589b99bd7aaeb0f6621a5b16faa71ae4116b27f5544f82091872cf9` |
| `MenuLoad/ImGuiDrawView.mm` | ARKFont initialization/render lifecycle | modified | 10,402 | `80a2491f7c24e9fe6ece4c3d2de001d60279cab677038ed612f5da1f70c7a5e2` |
| `Resources/Fonts.h` | ARKFont declaration/ownership | modified | 3,395 | `d89f0bd0a09aa12cac2777803aa8b2bbf068b06865845f2347a4b8dc286b230b` |
| `Resources/Fonts/ark_font.cpp` | embedded ARKFont data | clean | 128,631 | `350e6f2cdf2d1046195176bc77690c41b8b1a077208f6591f1c9149c9f31a323` |
| `ImGui/DRGui/dr_gui.h` | self-contained DRGui API blocks | clean | 4,357 | `0d77432f08adec434af9c3836a84d2955cf905ee48e4174b1488d955dbbea1bb` |
| `ImGui/DRGui/dr_gui.cpp` | self-contained DRGui implementation blocks | clean | 61,709 | `44d331f07b46a39f49e1b16893d7fdca170fd21e6ebbaca66b6ca444cb81bfc7` |

The production UI compatibility workflow must re-check Dear ImGui API
compatibility, ARKFont provenance and font-atlas ownership before using any of
these patterns. Login/authentication, UDID, API, crypto/security, remote images,
hide-record, gameplay, old offsets and package payload remain excluded.

## SEA guide — external only

Expected local path: `<MHGA_ROOT>/Extra_For_Host/SEA_host_guide.md`.

Purpose: deferred control-plane research for heartbeat and pending/running/
success/failure command, player, save/restart, backup and audit semantics. It is
not an Unreal Engine hosting ABI source.

Size: 14,536 bytes. SHA-256:
`fab3150fb600dcaf2b2d379f0ed8a9dc775f3bef8262f9bdda1e35f8af38a27d`.
No repository provenance or license grant was found, so the guide was not
copied.

## Excluded binary and IDA inputs

Place these only under `<MHGA_ROOT>/Extra_For_Host` when the corresponding
research workflow is active. They must never be staged, committed, uploaded or
replaced with Git LFS.

| Expected local input | Purpose/status | Bytes | Local SHA-256 / known identity |
|---|---|---:|---|
| `110280.i64` | Current exact iOS ShooterGame 1.10280 IDA database | 1,429,882,055 | `f4aaf290c62d3d5761afbdd034b1ecb2222bcafcb1b43c5176d6b455398dd74e`; stored input UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC` |
| `110280` | Exact ShooterGame executable copy; external binary only | 98,254,880 | `d98d25778e893413ebd6c4da9156e1b74efe2b203bc488393795c3db6c83a178`; `__TEXT,__text` SHA-256 `8bfc1fd248a5bf2fc589b85de0afccb57fe872789dff1b0e8c0d7b3db591bcf8` |
| `110280.so` | Proprietary binary; not a current V2 source/build input | 232,311,120 | `c98183158e150e7b0b461833d57a752f8ee0cb9ee48add69f51a5b1c908c3c07` |
| `110280.so.i64` | External IDA database; not recorded as current Android authority | 2,770,171,969 | `cf11c14fa990cd81d74a63e3d878ffdacc4a501357924b3b1b96428ede94720e` |
| `SEAServerManager.dylib` | Deferred SEA client-manager binary | 10,751,832 | `e5e26ea50e1c537111a9ee32642d3173466e17f5b3e547f3e0a3a13bacfc3115` |
| `SEAServerManager.dylib.i64` | Deferred SEA client-manager IDA database | 82,498,257 | `82950fab08f3fea811c2cbe80b22bdf3faf47d3be027c7d175dadbea401e3a20` |
| `com.studiowildcard.arkuse-1.10280-Decrypted/Payload/ShooterGame.app/ShooterGame` | Exact decrypted app executable evidence | 98,254,880 | `d98d25778e893413ebd6c4da9156e1b74efe2b203bc488393795c3db6c83a178`; UUID/text fingerprint as above |
| `com.studiowildcard.arkuse-1.10280-Decrypted/Payload/ShooterGame.app/Frameworks/EOSSDK.framework/EOSSDK` | EOS evidence only when a bounded workflow requires it | 11,811,008 | `1fa32fb05565dadb9fa388e2935b35c31689535ab2c4203159595bb390b40afb` |

The exact Android `LibUE.so`/IDA authority remains missing from the durable V2
record. Do not infer that `110280.so.i64` is that authority; request and record
the exact path, build identity and provenance when Android becomes active.

## Repository boundary

`SourceV2.mk`, the root Legacy `Makefile`, plist/control metadata, SourceV2
tests, audits and runtime source do not reference `Research/` or any path above.
Absolute paths that remain in historical evidence identify the original local
analysis context; they are not build inputs and are intentionally not rewritten.
