#include "SourceV2/Bindings/Platform/ImageIdentityResolver.hpp"

#include <CommonCrypto/CommonDigest.h>

#include <array>
#include <iomanip>
#include <limits>
#include <sstream>

namespace serverhost::v2::bindings::platform {
namespace {

constexpr std::string_view kFingerprintSegment = "__TEXT";
constexpr std::string_view kFingerprintSection = "__text";
constexpr std::string_view kFingerprintRange = "__TEXT,__text";
constexpr std::size_t kHashChunkSize = 64U * 1024U;

ContractResult<std::string> HashMappedRange(
    const IMemorySource& memory, std::uintptr_t address, std::uint64_t size) {
    if (size == 0 || size > std::numeric_limits<std::size_t>::max()) {
        return ContractResult<std::string>::Failure(
            ContractErrorCategory::OutOfRange, "fingerprint range has invalid size");
    }
    CC_SHA256_CTX context{};
    if (CC_SHA256_Init(&context) != 1) {
        return ContractResult<std::string>::Failure(
            ContractErrorCategory::MissingEvidence, "SHA-256 initialization failed");
    }
    std::array<std::byte, kHashChunkSize> buffer{};
    std::size_t remaining = static_cast<std::size_t>(size);
    std::uintptr_t cursor = address;
    while (remaining != 0) {
        const std::size_t chunkSize = std::min(remaining, buffer.size());
        const auto copied = memory.Copy(cursor, std::span<std::byte>(buffer).first(chunkSize));
        if (!copied) {
            return ContractResult<std::string>::Failure(
                copied.Error().category, "bounded __text fingerprint read failed");
        }
        if (CC_SHA256_Update(&context, buffer.data(), static_cast<CC_LONG>(chunkSize)) != 1) {
            return ContractResult<std::string>::Failure(
                ContractErrorCategory::MissingEvidence, "SHA-256 update failed");
        }
        if (chunkSize > std::numeric_limits<std::uintptr_t>::max() - cursor) {
            return ContractResult<std::string>::Failure(
                ContractErrorCategory::OutOfRange, "fingerprint cursor overflow");
        }
        cursor += chunkSize;
        remaining -= chunkSize;
    }
    std::array<unsigned char, CC_SHA256_DIGEST_LENGTH> digest{};
    if (CC_SHA256_Final(digest.data(), &context) != 1) {
        return ContractResult<std::string>::Failure(
            ContractErrorCategory::MissingEvidence, "SHA-256 finalization failed");
    }
    std::ostringstream stream;
    stream << std::hex << std::setfill('0');
    for (const unsigned char byte : digest)
        stream << std::setw(2) << static_cast<unsigned int>(byte);
    return ContractResult<std::string>::Success(stream.str());
}

}  // namespace

ContractResult<ResolvedImageIdentity> ImageIdentityResolver::Resolve(
    const LoadedImageRecord& image, const IMemorySource& memory,
    std::string versionLabel) const {
    const auto parsed = MachOImageView::Parse(image.headerAndLoadCommands, image.slide);
    if (!parsed) {
        return ContractResult<ResolvedImageIdentity>::Failure(
            parsed.Error().category, parsed.Error().context);
    }
    const MachOSection* text = parsed.Value().FindSection(
        kFingerprintSegment, kFingerprintSection);
    if (text == nullptr || text->size == 0) {
        return ContractResult<ResolvedImageIdentity>::Failure(
            ContractErrorCategory::MissingEvidence, "unique __TEXT,__text section is missing");
    }
    const MappedSegment* textSegment = nullptr;
    for (const MappedSegment& segment : parsed.Value().Segments()) {
        if (segment.name == kFingerprintSegment) {
            if (textSegment != nullptr) {
                return ContractResult<ResolvedImageIdentity>::Failure(
                    ContractErrorCategory::MalformedLayout, "duplicate __TEXT segment");
            }
            textSegment = &segment;
        }
    }
    if (textSegment == nullptr || !textSegment->IsReadable() || !textSegment->IsExecutable()
        || text->size > std::numeric_limits<std::size_t>::max()
        || !textSegment->Contains(text->mappedAddress, static_cast<std::size_t>(text->size))) {
        return ContractResult<ResolvedImageIdentity>::Failure(
            ContractErrorCategory::MalformedLayout,
            "__text is not bounded by one readable executable segment");
    }
    const auto fingerprint = HashMappedRange(memory, text->mappedAddress, text->size);
    if (!fingerprint) {
        return ContractResult<ResolvedImageIdentity>::Failure(
            fingerprint.Error().category, fingerprint.Error().context);
    }

    std::vector<ImageSegmentIdentity> segmentIdentity;
    segmentIdentity.reserve(parsed.Value().Segments().size());
    for (const MappedSegment& segment : parsed.Value().Segments()) {
        segmentIdentity.push_back({
            .name = segment.name,
            .virtualSize = segment.virtualSize,
            .fileSize = segment.fileSize,
            .initialPermissions = segment.initialPermissions,
        });
    }

    BuildIdentity identity{
        .platform = Platform::IOS,
        .product = image.imageName,
        .version = std::move(versionLabel),
        .architecture = parsed.Value().Architecture(),
        .role = parsed.Value().Role(),
        .imageUuid = parsed.Value().Uuid(),
        .textFingerprint = fingerprint.Value(),
        .textFingerprintRange = std::string(kFingerprintRange),
        .textFingerprintSize = text->size,
        .segments = std::move(segmentIdentity),
        .stableImagePrefixSize = parsed.Value().StableFilePrefixSize(),
    };
    return ContractResult<ResolvedImageIdentity>::Success({
        .identity = std::move(identity),
        .imageName = image.imageName,
        .mappedSegments = parsed.Value().Segments(),
    });
}

std::string ShortenFingerprint(std::string_view fingerprint) {
    constexpr std::size_t kVisibleCharacters = 12;
    if (fingerprint.size() <= kVisibleCharacters)
        return std::string(fingerprint);
    return std::string(fingerprint.substr(0, kVisibleCharacters)) + "...";
}

}  // namespace serverhost::v2::bindings::platform
