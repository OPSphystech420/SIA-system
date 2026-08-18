#pragma once

#include <cstdint>
#include "../UnrealEngine/GeneratedSDKProfile.hpp"

namespace ServerHost::Config
{
    inline constexpr const char* ImageName = "ShooterGame";

    // ShooterGame build analysed on 2026-08-14. Every pattern below was
    // required to have exactly one match in the complete __TEXT segment.
    // Relocation-bearing ADRP/ADD and BL instructions are wildcarded where
    // possible; the remaining bytes describe the current implementation.
    inline constexpr const char* GUObjectArraySignature =
        "? ? ? ? ? ? ? ? 17 03 80 52 05 00 00 14 E0 23 00 91 "
        "? ? ? ? E8 B3 40 39 E8 FB 07 37 F4 1F 40 F9 74 FF FF B4 "
        "88 0E 40 B9 09 01 15 0B 1F 01 00 71 29 B1 88 1A "
        "2A 7D 10 13 29 3D 10 12";
    inline constexpr const char* NamePoolSignature =
        "? ? ? ? ? ? ? ? ? ? ? 97 E8 03 00 2A 68 02 00 F9 "
        "E0 03 13 AA FD 7B 42 A9 F4 4F 41 A9 F6 57 C3 A8 C0 03 5F D6";
    inline constexpr const char* EngineReallocSignature =
        "FF C3 00 D1 FD 7B 02 A9 FD 83 00 91 E3 03 02 AA "
        "E2 03 01 AA E1 03 00 AA ? ? ? ? ? ? ? ? 00 01 40 F9 C0 00 00 B4";
    inline constexpr const char* SetClientTravelSignature =
        "F8 5F BC A9 F6 57 01 A9 F4 4F 02 A9 FD 7B 03 A9 "
        "FD C3 00 91 F3 03 03 AA F4 03 02 AA 09 38 8C B9 "
        "49 01 00 34 08 18 46 F9 29 F1 7D D3";

    inline constexpr const char* UEngineInitSignature =
        "FF C3 03 D1 FC 6F 09 A9 FA 67 0A A9 F8 5F 0B A9 "
        "F6 57 0C A9 F4 4F 0D A9 FD 7B 0E A9 FD 83 03 91 "
        "F4 03 01 AA FC 03 00 AA";
    inline constexpr const char* UWorldBeginPlaySignature =
        "F8 5F BC A9 F6 57 01 A9 F4 4F 02 A9 FD 7B 03 A9 "
        "FD C3 00 91 F3 03 00 AA 00 5C 41 F9 20 01 00 B4 "
        "08 00 40 F9 08 CD 45 F9 00 01 3F D6 60 66 41 F9";
    inline constexpr const char* UWorldListenSignature =
        "FF 43 01 D1 F8 5F 01 A9 F6 57 02 A9 F4 4F 03 A9 "
        "FD 7B 04 A9 FD 03 01 91 F3 03 00 AA 02 EC 40 F9";
    inline constexpr const char* UNetDriverGetNetModeSignature =
        "FD 7B BF A9 FD 03 00 91 08 00 40 F9 08 E1 41 F9 "
        "00 01 3F D6 ? ? ? ? ? ? ? ? 08 01 40 39 1F 01 00 72 "
        "28 00 80 52 08 05 88 1A 1F 00 00 71 69 00 80 52 "
        "00 11 89 1A FD 7B C1 A8 C0 03 5F D6";
    // UEngine::DestroyNamedNetDriver(UEngine*, UWorld*, FName). The wrapper
    // resolves the owning world context, calls SetWorld(nullptr), Shutdown and
    // LowLevelDestroy, then removes the driver from both engine and world
    // collections. Confirmed unique in the complete 1.10280 image.
    inline constexpr const char* DestroyNamedNetDriverSignature =
        "F4 4F BE A9 FD 7B 01 A9 FD 43 00 91 F3 03 02 AA "
        "09 38 8C B9 49 01 00 34 08 18 46 F9 29 F1 7D D3 "
        "00 01 40 F9 0A 40 41 F9 5F 01 01 EB 00 01 00 54 "
        "08 21 00 91 29 21 00 F1 41 FF FF 54 "
        "? ? ? ? ? ? ? ? 01 00 80 52 ? ? ? ? "
        "E1 03 13 AA FD 7B 41 A9 F4 4F C2 A8 ? ? ? ?";

    // Confirmed for the analysed build and retained only as explicit fallback
    // diagnostics. Signature resolution remains the default.
    inline constexpr uintptr_t KnownGUObjectArrayOffset = SDKProfile::KnownBuild::FUObjectArray;
    inline constexpr uintptr_t KnownNetDriverDefinitionsOffset =
        SDKProfile::KnownBuild::UEngineNetDriverDefinitions;
    inline constexpr bool AllowKnownGUObjectArrayOffset = false;
    inline constexpr bool AllowKnownNetDriverDefinitionsOffset = false;

    // This profile fallback is enabled only after every native signature for
    // the analysed 1.10280 executable resolves uniquely. It supplies member
    // offsets that the generated SDK recovered when UE reflection is not yet
    // usable (for example, while GUObjectArray still reports zero objects).
    inline constexpr bool AllowKnownSDKProfileFallback = true;

    // NamePrivate in the legacy UObject layout. Prefer NamePrivate directly
    // once the refreshed SDK layout has been confirmed.
    inline constexpr uintptr_t UObjectNameOffset = SDKProfile::Layout::UObjectName;
}
