#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>

namespace serverhost::v2 {

enum class Platform {
    HostTest,
    IOS,
    Android,
};

struct BuildIdentity final {
    Platform platform{Platform::HostTest};
    std::string product;
    std::string version;
    std::optional<std::array<std::uint8_t, 16>> imageUuid;
    std::optional<std::string> textFingerprint;
    std::size_t imageSize{};

    friend bool operator==(const BuildIdentity&, const BuildIdentity&) = default;
};

}  // namespace serverhost::v2
