#pragma once

#include "SourceV2/Core/BuildIdentity.hpp"

#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace serverhost::v2::bindings {

struct BuildProfile final {
    std::string profileId;
    Platform platform{Platform::HostTest};
    std::string product;
    std::string version;
    ImageArchitecture expectedArchitecture{ImageArchitecture::Unknown};
    ImageRole expectedRole{ImageRole::Unknown};
    std::optional<std::array<std::uint8_t, 16>> expectedImageUuid;
    std::optional<std::string> expectedTextFingerprint;
    std::string expectedTextFingerprintRange;
    std::uint64_t expectedTextFingerprintSize{};
    std::vector<ImageSegmentIdentity> expectedSegments;
    std::size_t expectedStableImagePrefixSize{};
    bool identityEvidenceComplete{};
};

}  // namespace serverhost::v2::bindings
