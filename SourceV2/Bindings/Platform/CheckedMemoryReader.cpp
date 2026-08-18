#include "SourceV2/Bindings/Platform/CheckedMemoryReader.hpp"

#include <algorithm>
#include <atomic>
#include <limits>
#include <utility>

namespace serverhost::v2::bindings::platform {

namespace {

std::uint64_t NextReaderNonce() {
    static std::atomic_uint64_t next{0x5348563252454144ULL};
    return next.fetch_add(1, std::memory_order_relaxed) + 1;
}

bool AddOverflows(std::uintptr_t base, std::size_t offset) {
    return offset > std::numeric_limits<std::uintptr_t>::max() - base;
}

}  // namespace

OwnedMemoryCopy::OwnedMemoryCopy(
    std::vector<std::byte> bytes, std::uintptr_t sourceAddress,
    std::uint64_t readerNonce, std::uint8_t provenanceDepth)
    : bytes_(std::move(bytes)), sourceAddress_(sourceAddress), readerNonce_(readerNonce),
      provenanceDepth_(provenanceDepth) {}

std::span<const std::byte> OwnedMemoryCopy::Bytes() const noexcept { return bytes_; }

ImageMemoryToken::ImageMemoryToken(
    std::uintptr_t address, std::size_t extent, std::uint64_t readerNonce)
    : address_(address), extent_(extent), readerNonce_(readerNonce) {}

DerivedMemoryToken::DerivedMemoryToken(
    std::uintptr_t address, std::size_t extent, std::uint8_t provenanceDepth,
    std::uint64_t readerNonce, std::string expectedType)
    : address_(address), extent_(extent), provenanceDepth_(provenanceDepth),
      readerNonce_(readerNonce), expectedType_(std::move(expectedType)) {}

CheckedMemoryReader::CheckedMemoryReader(
    std::vector<MappedSegment> segments, std::string profileId,
    std::shared_ptr<const IMemorySource> source)
    : segments_(std::move(segments)), source_(std::move(source)),
      profileId_(std::move(profileId)),
      readerNonce_(NextReaderNonce()) {}

ContractResult<CheckedMemoryReader> CheckedMemoryReader::Create(
    const ExactProfileMatch& match, std::shared_ptr<const IMemorySource> source) {
    if (!match.uniqueExactMatch_ || source == nullptr || match.image_.mappedSegments.empty()) {
        return ContractResult<CheckedMemoryReader>::Failure(
            ContractErrorCategory::UnsupportedProfile,
            "checked reader requires a unique exact-profile proof and memory source");
    }
    return ContractResult<CheckedMemoryReader>::Success(
        CheckedMemoryReader(
            match.image_.mappedSegments, match.profileId_, std::move(source)));
}

bool CheckedMemoryReader::CanUseProfile(std::string_view profileId) const noexcept {
    return !profileId.empty() && profileId == profileId_;
}

ContractResult<ImageMemoryToken> CheckedMemoryReader::ResolveImageRva(
    std::uint64_t rva, std::size_t extent, MemoryReadKind kind) const {
    if (extent == 0) {
        return ContractResult<ImageMemoryToken>::Failure(
            ContractErrorCategory::InvalidArgument, "zero-length image token");
    }
    std::uint64_t imageBase = std::numeric_limits<std::uint64_t>::max();
    for (const MappedSegment& segment : segments_) {
        if (segment.name != "__PAGEZERO")
            imageBase = std::min(imageBase, segment.preferredAddress);
    }
    if (imageBase == std::numeric_limits<std::uint64_t>::max()
        || rva > std::numeric_limits<std::uint64_t>::max() - imageBase) {
        return ContractResult<ImageMemoryToken>::Failure(
            ContractErrorCategory::OutOfRange, "image RVA overflows preferred address");
    }
    const std::uint64_t preferredAddress = imageBase + rva;
    const MappedSegment* containing = nullptr;
    for (const MappedSegment& segment : segments_) {
        if (preferredAddress < segment.preferredAddress
            || segment.virtualSize
                > std::numeric_limits<std::uint64_t>::max() - segment.preferredAddress
            || extent > std::numeric_limits<std::uint64_t>::max() - preferredAddress
            || preferredAddress + extent > segment.preferredAddress + segment.virtualSize)
            continue;
        if (containing != nullptr) {
            return ContractResult<ImageMemoryToken>::Failure(
                ContractErrorCategory::MalformedLayout,
                "image RVA is contained by overlapping segments");
        }
        containing = &segment;
    }
    if (containing == nullptr) {
        return ContractResult<ImageMemoryToken>::Failure(
            ContractErrorCategory::OutOfRange,
            "image RVA is outside one mapped segment or crosses its boundary");
    }
    if (!containing->IsReadable()) {
        return ContractResult<ImageMemoryToken>::Failure(
            ContractErrorCategory::TypeMismatch, "segment is not readable");
    }
    const bool permissionClassMatches = kind == MemoryReadKind::ExecutableText
        ? containing->IsExecutable()
        : !containing->IsExecutable();
    if (!permissionClassMatches) {
        return ContractResult<ImageMemoryToken>::Failure(
            ContractErrorCategory::TypeMismatch,
            "requested read kind does not match segment permission class");
    }
    const std::uint64_t delta = preferredAddress - containing->preferredAddress;
    if (delta > std::numeric_limits<std::uintptr_t>::max()
        || AddOverflows(containing->mappedAddress, static_cast<std::size_t>(delta))) {
        return ContractResult<ImageMemoryToken>::Failure(
            ContractErrorCategory::OutOfRange, "mapped image RVA overflows address space");
    }
    return ContractResult<ImageMemoryToken>::Success(ImageMemoryToken(
        containing->mappedAddress + static_cast<std::size_t>(delta), extent, readerNonce_));
}

ContractResult<OwnedMemoryCopy> CheckedMemoryReader::CopyBounded(
    std::uintptr_t address, std::size_t extent, std::size_t offset,
    std::size_t size, std::uint8_t depth) const {
    if (size == 0 || offset > extent || size > extent - offset
        || AddOverflows(address, offset)) {
        return ContractResult<OwnedMemoryCopy>::Failure(
            ContractErrorCategory::OutOfRange,
            "bounded owned-copy range is invalid or crosses its token scope");
    }
    const std::uintptr_t copyAddress = address + offset;
    if (AddOverflows(copyAddress, size)) {
        return ContractResult<OwnedMemoryCopy>::Failure(
            ContractErrorCategory::OutOfRange, "owned-copy address plus size overflows");
    }
    std::vector<std::byte> bytes(size);
    const auto copied = source_->Copy(copyAddress, bytes);
    if (!copied) {
        return ContractResult<OwnedMemoryCopy>::Failure(
            copied.Error().category, copied.Error().context);
    }
    return ContractResult<OwnedMemoryCopy>::Success(
        OwnedMemoryCopy(std::move(bytes), copyAddress, readerNonce_, depth));
}

ContractResult<OwnedMemoryCopy> CheckedMemoryReader::Read(
    const ImageMemoryToken& token, std::size_t offset, std::size_t size) const {
    if (token.readerNonce_ != readerNonce_) {
        return ContractResult<OwnedMemoryCopy>::Failure(
            ContractErrorCategory::StaleIdentity, "image token belongs to another reader");
    }
    return CopyBounded(token.address_, token.extent_, offset, size, 0);
}

ContractResult<OwnedMemoryCopy> CheckedMemoryReader::Read(
    const DerivedMemoryToken& token, std::size_t offset, std::size_t size) const {
    if (token.readerNonce_ != readerNonce_) {
        return ContractResult<OwnedMemoryCopy>::Failure(
            ContractErrorCategory::StaleIdentity, "derived token belongs to another reader");
    }
    auto copied = CopyBounded(
        token.address_, token.extent_, offset, size, token.provenanceDepth_);
    if (!copied) {
        return ContractResult<OwnedMemoryCopy>::Failure(
            copied.Error().category,
            token.expectedType_ + ": " + copied.Error().context);
    }
    return copied;
}

ContractResult<DerivedMemoryToken> CheckedMemoryReader::DerivePointer(
    const OwnedMemoryCopy& parent, std::size_t pointerOffset,
    std::size_t expectedExtent, std::string expectedType) const {
    if (parent.readerNonce_ != readerNonce_ || parent.sourceAddress_ == 0) {
        return ContractResult<DerivedMemoryToken>::Failure(
            ContractErrorCategory::StaleIdentity, "owned copy belongs to another reader");
    }
    if (expectedExtent == 0 || expectedType.empty()) {
        return ContractResult<DerivedMemoryToken>::Failure(
            ContractErrorCategory::InvalidArgument, "derived type and extent are required");
    }
    if (parent.provenanceDepth_ >= kMaximumProvenanceDepth) {
        return ContractResult<DerivedMemoryToken>::Failure(
            ContractErrorCategory::LimitExceeded, "derived provenance depth exceeded");
    }
    const auto pointer = parent.ValueAt<std::uintptr_t>(pointerOffset);
    if (!pointer || pointer.Value() == 0
        || AddOverflows(pointer.Value(), expectedExtent)) {
        return ContractResult<DerivedMemoryToken>::Failure(
            ContractErrorCategory::OutOfRange, "derived pointer is null or overflows");
    }
    return ContractResult<DerivedMemoryToken>::Success(DerivedMemoryToken(
        pointer.Value(), expectedExtent,
        static_cast<std::uint8_t>(parent.provenanceDepth_ + 1), readerNonce_,
        std::move(expectedType)));
}

}  // namespace serverhost::v2::bindings::platform
