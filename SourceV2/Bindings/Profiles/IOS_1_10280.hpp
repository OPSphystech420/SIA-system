#pragma once

#include "SourceV2/Bindings/Profiles/BuildProfile.hpp"

namespace serverhost::v2::bindings::profiles {

inline const BuildProfile kIOS_1_10280{
    .profileId = "ios-shootergame-1.10280-exact-e52a980c",
    .platform = Platform::IOS,
    .product = "ShooterGame",
    .version = "1.10280",
    .expectedArchitecture = ImageArchitecture::Arm64,
    .expectedRole = ImageRole::MainExecutable,
    .expectedImageUuid = std::array<std::uint8_t, 16>{
        0xE5, 0x2A, 0x98, 0x0C, 0x9C, 0x36, 0x34, 0xC7,
        0x84, 0xB0, 0xDD, 0x6E, 0x84, 0x63, 0x28, 0xDC,
    },
    .expectedTextFingerprint =
        "8bfc1fd248a5bf2fc589b85de0afccb57fe872789dff1b0e8c0d7b3db591bcf8",
    .expectedTextFingerprintRange = "__TEXT,__text",
    .expectedTextFingerprintSize = 0x448B030,
    .expectedSegments = {
        {"__PAGEZERO", 0x100000000ULL, 0x0ULL, ImagePermissionNone},
        {"__TEXT", 0x4D9C000ULL, 0x4D9C000ULL,
         ImagePermissionRead | ImagePermissionExecute},
        {"__DATA_CONST", 0xAA0000ULL, 0xAA0000ULL,
         ImagePermissionRead | ImagePermissionWrite},
        {"__DATA", 0x580000ULL, 0x1A0000ULL,
         ImagePermissionRead | ImagePermissionWrite},
        {"__LINKEDIT", 0x3DC000ULL, 0x3D8020ULL, ImagePermissionRead},
    },
    // Bytes before __LINKEDIT. The mutable code-signature/linkedit payload is
    // deliberately outside the stable identity range used after re-signing.
    .expectedStableImagePrefixSize = 94224384,
    .identityEvidenceComplete = true,
};

}  // namespace serverhost::v2::bindings::profiles
