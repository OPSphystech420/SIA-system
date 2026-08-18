#pragma once

#include "SourceV2/Bindings/Platform/LoadedImageCatalog.hpp"
#include "SourceV2/Bindings/Platform/MachOImageView.hpp"
#include "SourceV2/Core/BuildIdentity.hpp"
#include "SourceV2/Core/ContractResult.hpp"

#include <string>
#include <vector>

namespace serverhost::v2::bindings::platform {

struct ResolvedImageIdentity final {
    BuildIdentity identity;
    std::string imageName;
    std::vector<MappedSegment> mappedSegments;
};

class ImageIdentityResolver final {
public:
    [[nodiscard]] ContractResult<ResolvedImageIdentity> Resolve(
        const LoadedImageRecord& image, const IMemorySource& memory,
        std::string versionLabel) const;
};

[[nodiscard]] std::string ShortenFingerprint(std::string_view fingerprint);

}  // namespace serverhost::v2::bindings::platform
