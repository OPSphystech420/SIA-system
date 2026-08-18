#pragma once

#include <string_view>

namespace serverhost::v2::bootstrap {

enum class LegacyRuntimeStatus {
    Clear,
    LegacyLoaded,
    InspectionFailed,
};

[[nodiscard]] bool IsLegacyRuntimeImagePath(std::string_view imagePath) noexcept;
[[nodiscard]] LegacyRuntimeStatus InspectLoadedImagesForLegacyRuntime() noexcept;

}  // namespace serverhost::v2::bootstrap
