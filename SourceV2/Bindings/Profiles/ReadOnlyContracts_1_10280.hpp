#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <string_view>

namespace serverhost::v2::bindings::profiles {

struct KnownObjectSeed final {
    std::int32_t index;
    std::string_view expectedFullName;
};

struct ReadOnlyContractProfile final {
    std::string_view identityProfileId;
    std::uint64_t fNamePoolRva;
    std::uint64_t fuObjectArrayRva;
    std::uint64_t directObjectArrayRva;
    std::uint64_t recordedGWorldRva;
    std::uint64_t recordedProcessEventRva;
    std::uint32_t fNameMaximumBlocks;
    std::uint32_t fNameBlockBytes;
    std::uint32_t fNameStride;
    std::uint32_t objectChunkItems;
    std::uint32_t objectItemBytes;
    std::uint32_t unreachableMask;
    std::uint32_t pendingKillMask;
    std::array<KnownObjectSeed, 9> knownObjectSeeds;
};

inline constexpr ReadOnlyContractProfile kReadOnlyContractsIOS_1_10280{
    .identityProfileId = "ios-shootergame-1.10280-exact-e52a980c",
    .fNamePoolRva = 0x5BB5180,
    .fuObjectArrayRva = 0x5D434D8,
    .directObjectArrayRva = 0x5D434E8,
    // Evidence-only Gate 2C / prohibited-call cards. Gate 2B does not resolve,
    // read, or invoke either RVA.
    .recordedGWorldRva = 0x5DBA4F0,
    .recordedProcessEventRva = 0x250147C,
    .fNameMaximumBlocks = 0x2000,
    .fNameBlockBytes = 0x20000,
    .fNameStride = 2,
    .objectChunkItems = 0x10000,
    .objectItemBytes = 0x18,
    .unreachableMask = 0x10000000,
    .pendingKillMask = 0x20000000,
    .knownObjectSeeds = {{
        {0x1, "Class CoreUObject.Object"},
        {0x44, "Class Engine.NetDriver"},
        {0x1A8, "Class Engine.Engine"},
        {0x266, "Class Engine.GameViewportClient"},
        {0x358, "Class Engine.GameEngine"},
        {0x37F, "Class CoreUObject.Class"},
        {0x380, "Class CoreUObject.Function"},
        {0x712, "Class Engine.World"},
        {0x410D, "Function Engine.KismetStringLibrary.Conv_StringToName"},
    }},
};

[[nodiscard]] constexpr std::uint64_t NormalizeDumpAddress(
    std::uint64_t runtimeAddress, std::uint64_t dumpImageBase) noexcept {
    return runtimeAddress >= dumpImageBase ? runtimeAddress - dumpImageBase : UINT64_MAX;
}

}  // namespace serverhost::v2::bindings::profiles
