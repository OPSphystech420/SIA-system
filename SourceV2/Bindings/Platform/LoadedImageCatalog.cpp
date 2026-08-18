#include "SourceV2/Bindings/Platform/LoadedImageCatalog.hpp"

#include "SourceV2/Bindings/Platform/MachOImageView.hpp"

#include <array>
#include <mach-o/dyld.h>

namespace serverhost::v2::bindings::platform {
namespace {

std::string Basename(std::string_view path) {
    const std::size_t separator = path.find_last_of('/');
    return std::string(separator == std::string_view::npos ? path : path.substr(separator + 1));
}

}  // namespace

LoadedImageCatalog::LoadedImageCatalog(std::vector<LoadedImageRecord> images)
    : images_(std::move(images)) {}

ContractResult<LoadedImageCatalog> LoadedImageCatalog::CaptureRuntime(
    const IMemorySource& memory) {
    const std::uint32_t imageCount = _dyld_image_count();
    if (imageCount == 0) {
        return ContractResult<LoadedImageCatalog>::Failure(
            ContractErrorCategory::MissingEvidence, "dyld reported no loaded images");
    }

    std::vector<LoadedImageRecord> images;
    images.reserve(imageCount);
    for (std::uint32_t index = 0; index < imageCount; ++index) {
        const char* path = _dyld_get_image_name(index);
        const mach_header* header = _dyld_get_image_header(index);
        if (path == nullptr || header == nullptr) {
            return ContractResult<LoadedImageCatalog>::Failure(
                ContractErrorCategory::MissingEvidence, "dyld image record is incomplete");
        }
        const std::uintptr_t headerAddress = reinterpret_cast<std::uintptr_t>(header);
        std::array<std::byte, MachOImageView::kHeader64Size> headerBytes{};
        const auto headerCopy = memory.Copy(headerAddress, headerBytes);
        if (!headerCopy) {
            return ContractResult<LoadedImageCatalog>::Failure(
                headerCopy.Error().category, "could not copy a dyld Mach-O header");
        }
        const auto prefixSize = MachOImageView::RequiredPrefixSize(headerBytes);
        if (!prefixSize) {
            return ContractResult<LoadedImageCatalog>::Failure(
                prefixSize.Error().category, prefixSize.Error().context);
        }
        std::vector<std::byte> prefix(prefixSize.Value());
        const auto prefixCopy = memory.Copy(headerAddress, prefix);
        if (!prefixCopy) {
            return ContractResult<LoadedImageCatalog>::Failure(
                prefixCopy.Error().category, "could not copy dyld Mach-O load commands");
        }
        images.push_back({
            .path = path,
            .imageName = Basename(path),
            .isDyldMainExecutable = index == 0,
            .headerAddress = headerAddress,
            .slide = static_cast<std::intptr_t>(_dyld_get_image_vmaddr_slide(index)),
            .headerAndLoadCommands = std::move(prefix),
        });
    }
    return ContractResult<LoadedImageCatalog>::Success(
        LoadedImageCatalog(std::move(images)));
}

const std::vector<LoadedImageRecord>& LoadedImageCatalog::Images() const noexcept {
    return images_;
}

}  // namespace serverhost::v2::bindings::platform
