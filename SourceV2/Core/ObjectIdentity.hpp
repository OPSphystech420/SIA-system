#pragma once

#include <cstdint>

namespace serverhost::v2 {

struct ObjectIdentity final {
    std::int32_t objectIndex{-1};
    std::int32_t serialNumber{};
    std::uint64_t discoveryGeneration{};

    [[nodiscard]] constexpr bool IsStructurallyValid() const noexcept {
        return objectIndex >= 0 && serialNumber >= 0 && discoveryGeneration > 0;
    }

    friend constexpr bool operator==(const ObjectIdentity&, const ObjectIdentity&) = default;
};

}  // namespace serverhost::v2
