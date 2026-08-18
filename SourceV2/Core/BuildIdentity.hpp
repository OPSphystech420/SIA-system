#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace serverhost::v2 {

enum class Platform {
    HostTest,
    IOS,
    Android,
};

enum class ImageArchitecture {
    Unknown,
    Arm64,
    Arm64e,
    X86_64,
};

enum class ImageRole {
    Unknown,
    MainExecutable,
    DynamicLibrary,
};

enum ImagePermission : std::uint8_t {
    ImagePermissionNone = 0,
    ImagePermissionRead = 1U << 0U,
    ImagePermissionWrite = 1U << 1U,
    ImagePermissionExecute = 1U << 2U,
};

struct ImageSegmentIdentity final {
    std::string name;
    std::uint64_t virtualSize{};
    std::uint64_t fileSize{};
    std::uint8_t initialPermissions{};

    friend bool operator==(const ImageSegmentIdentity&, const ImageSegmentIdentity&) = default;
};

struct BuildIdentity final {
    Platform platform{Platform::HostTest};
    std::string product;
    std::string version;
    ImageArchitecture architecture{ImageArchitecture::Unknown};
    ImageRole role{ImageRole::Unknown};
    std::optional<std::array<std::uint8_t, 16>> imageUuid;
    std::optional<std::string> textFingerprint;
    std::string textFingerprintRange;
    std::uint64_t textFingerprintSize{};
    std::vector<ImageSegmentIdentity> segments;
    std::size_t stableImagePrefixSize{};

    friend bool operator==(const BuildIdentity&, const BuildIdentity&) = default;
};

}  // namespace serverhost::v2
