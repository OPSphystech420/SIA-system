#pragma once

#include "SourceV2/Bindings/Profiles/BuildProfile.hpp"

namespace serverhost::v2::bindings::profiles {

inline const BuildProfile kIOS_1_10280{
    .profileId = "ios-shootergame-1.10280-pending-image-identity",
    .platform = Platform::IOS,
    .product = "ShooterGame",
    .version = "1.10280",
    .expectedImageUuid = std::nullopt,
    .expectedTextFingerprint = std::nullopt,
    .expectedImageSize = 0,
    .identityEvidenceComplete = false,
};

}  // namespace serverhost::v2::bindings::profiles
