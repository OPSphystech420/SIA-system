#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

namespace serverhost::v2::bindings::profiles {

struct LiveRelationshipProfile final {
    std::string_view identityProfileId;
    std::uint64_t gEngineRva;
    std::uint64_t gWorldRva;
    std::size_t engineGameViewportOffset;
    std::size_t engineNetDriverDefinitionsOffset;
    std::size_t netDriverDefinitionBytes;
    std::size_t gameViewportWorldOffset;
    std::size_t worldNetDriverOffset;
    std::size_t worldAuthorityGameModeOffset;
    std::size_t worldGameStateOffset;
    std::int32_t engineClassIndex;
    std::int32_t gameEngineClassIndex;
    std::int32_t gameViewportClientClassIndex;
    std::int32_t worldClassIndex;
    std::int32_t netDriverClassIndex;
    std::int32_t gameModeBaseClassIndex;
    std::int32_t gameStateBaseClassIndex;
};

inline constexpr LiveRelationshipProfile kLiveRelationshipsIOS_1_10280{
    .identityProfileId = "ios-shootergame-1.10280-exact-e52a980c",
    .gEngineRva = 0x5DB8CF0,
    .gWorldRva = 0x5DBA4F0,
    .engineGameViewportOffset = 0x780,
    .engineNetDriverDefinitionsOffset = 0xBF8,
    .netDriverDefinitionBytes = 0x18,
    .gameViewportWorldOffset = 0x70,
    .worldNetDriverOffset = 0x1D8,
    .worldAuthorityGameModeOffset = 0x2B8,
    .worldGameStateOffset = 0x2C0,
    .engineClassIndex = 0x1A8,
    .gameEngineClassIndex = 0x358,
    .gameViewportClientClassIndex = 0x266,
    .worldClassIndex = 0x712,
    .netDriverClassIndex = 0x44,
    .gameModeBaseClassIndex = 0x13D,
    .gameStateBaseClassIndex = 0x1E2,
};

}  // namespace serverhost::v2::bindings::profiles
