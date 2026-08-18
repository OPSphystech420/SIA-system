#pragma once

#include "SourceV2/Core/BuildIdentity.hpp"

#include <array>
#include <cstdint>
#include <optional>
#include <string>

namespace serverhost::v2::bindings {

struct BuildProfile final {
    std::string profileId;
    Platform platform{Platform::HostTest};
    std::string product;
    std::string version;
    std::optional<std::array<std::uint8_t, 16>> expectedImageUuid;
    std::optional<std::string> expectedTextFingerprint;
    std::size_t expectedImageSize{};
    bool identityEvidenceComplete{};
};

}  // namespace serverhost::v2::bindings
