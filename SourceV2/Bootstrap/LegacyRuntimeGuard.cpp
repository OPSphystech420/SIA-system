#include "SourceV2/Bootstrap/LegacyRuntimeGuard.hpp"

#include <cstdint>
#include <mach-o/dyld.h>

namespace serverhost::v2::bootstrap {
namespace {

constexpr std::string_view kLegacyDylibName = "ServerHost.dylib";

}  // namespace

bool IsLegacyRuntimeImagePath(std::string_view imagePath) noexcept {
    if (imagePath.empty()) {
        return false;
    }
    const std::size_t separator = imagePath.find_last_of('/');
    const std::string_view basename = separator == std::string_view::npos
        ? imagePath
        : imagePath.substr(separator + 1);
    return basename == kLegacyDylibName;
}

LegacyRuntimeStatus InspectLoadedImagesForLegacyRuntime() noexcept {
    const std::uint32_t imageCount = _dyld_image_count();
    if (imageCount == 0) {
        return LegacyRuntimeStatus::InspectionFailed;
    }
    for (std::uint32_t index = 0; index < imageCount; ++index) {
        const char* imageName = _dyld_get_image_name(index);
        if (imageName == nullptr) {
            return LegacyRuntimeStatus::InspectionFailed;
        }
        if (IsLegacyRuntimeImagePath(imageName)) {
            return LegacyRuntimeStatus::LegacyLoaded;
        }
    }
    return LegacyRuntimeStatus::Clear;
}

}  // namespace serverhost::v2::bootstrap
