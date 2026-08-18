#include "SourceV2/Bindings/Platform/CheckedMemoryReader.hpp"

#include <limits>
#include <utility>

namespace serverhost::v2::bindings::platform {

CheckedMemoryReader::CheckedMemoryReader(
    std::vector<MappedSegment> segments, std::shared_ptr<const IMemorySource> source)
    : segments_(std::move(segments)), source_(std::move(source)) {}

ContractResult<CheckedMemoryReader> CheckedMemoryReader::Create(
    const ExactProfileMatch& match, std::shared_ptr<const IMemorySource> source) {
    if (!match.uniqueExactMatch_ || source == nullptr || match.image_.mappedSegments.empty()) {
        return ContractResult<CheckedMemoryReader>::Failure(
            ContractErrorCategory::UnsupportedProfile,
            "checked reader requires a unique exact-profile proof and memory source");
    }
    return ContractResult<CheckedMemoryReader>::Success(
        CheckedMemoryReader(match.image_.mappedSegments, std::move(source)));
}

ContractResult<std::vector<std::byte>> CheckedMemoryReader::ReadBytes(
    std::uintptr_t address, std::size_t size, MemoryReadKind kind) const {
    if (size == 0) {
        return ContractResult<std::vector<std::byte>>::Failure(
            ContractErrorCategory::InvalidArgument, "zero-length checked read");
    }
    if (size > std::numeric_limits<std::uintptr_t>::max() - address) {
        return ContractResult<std::vector<std::byte>>::Failure(
            ContractErrorCategory::OutOfRange, "checked address plus size overflows");
    }

    const MappedSegment* containing = nullptr;
    for (const MappedSegment& segment : segments_) {
        if (!segment.Contains(address, size))
            continue;
        if (containing != nullptr) {
            return ContractResult<std::vector<std::byte>>::Failure(
                ContractErrorCategory::MalformedLayout,
                "checked read is contained by overlapping segments");
        }
        containing = &segment;
    }
    if (containing == nullptr) {
        return ContractResult<std::vector<std::byte>>::Failure(
            ContractErrorCategory::OutOfRange,
            "checked read is outside one mapped segment or crosses its boundary");
    }
    if (!containing->IsReadable()) {
        return ContractResult<std::vector<std::byte>>::Failure(
            ContractErrorCategory::TypeMismatch, "segment is not readable");
    }
    const bool permissionClassMatches = kind == MemoryReadKind::ExecutableText
        ? containing->IsExecutable()
        : !containing->IsExecutable();
    if (!permissionClassMatches) {
        return ContractResult<std::vector<std::byte>>::Failure(
            ContractErrorCategory::TypeMismatch,
            "requested read kind does not match segment permission class");
    }

    std::vector<std::byte> bytes(size);
    const auto copied = source_->Copy(address, bytes);
    if (!copied) {
        return ContractResult<std::vector<std::byte>>::Failure(
            copied.Error().category, copied.Error().context);
    }
    return ContractResult<std::vector<std::byte>>::Success(std::move(bytes));
}

}  // namespace serverhost::v2::bindings::platform
