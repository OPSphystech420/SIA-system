#pragma once

#include "SourceV2/Bindings/Platform/MemorySource.hpp"
#include "SourceV2/Core/ContractResult.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace serverhost::v2::bindings::platform {

struct LoadedImageRecord final {
    std::string path;
    std::string imageName;
    bool isDyldMainExecutable{};
    std::uintptr_t headerAddress{};
    std::intptr_t slide{};
    std::vector<std::byte> headerAndLoadCommands;
};

class LoadedImageCatalog final {
public:
    explicit LoadedImageCatalog(std::vector<LoadedImageRecord> images);

    [[nodiscard]] static ContractResult<LoadedImageCatalog> CaptureRuntime(
        const IMemorySource& memory);
    [[nodiscard]] const std::vector<LoadedImageRecord>& Images() const noexcept;

private:
    std::vector<LoadedImageRecord> images_;
};

}  // namespace serverhost::v2::bindings::platform
