#pragma once

#include "SourceV2/Bindings/Platform/ExactProfileSelector.hpp"
#include "SourceV2/Bindings/Platform/MemorySource.hpp"
#include "SourceV2/Core/ContractResult.hpp"

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <memory>
#include <span>
#include <string>
#include <string_view>
#include <type_traits>
#include <vector>

namespace serverhost::v2::bindings::platform {

enum class MemoryReadKind {
    ReadableData,
    ExecutableText,
};

class OwnedMemoryCopy final {
public:
    [[nodiscard]] std::span<const std::byte> Bytes() const noexcept;

    template <typename T>
    [[nodiscard]] ContractResult<T> ValueAt(std::size_t offset) const {
        static_assert(std::is_trivially_copyable_v<T>);
        if (offset > bytes_.size() || sizeof(T) > bytes_.size() - offset) {
            return ContractResult<T>::Failure(
                ContractErrorCategory::OutOfRange, "owned-copy field is out of range");
        }
        T value{};
        std::memcpy(&value, bytes_.data() + offset, sizeof(T));
        return ContractResult<T>::Success(value);
    }

private:
    OwnedMemoryCopy(
        std::vector<std::byte> bytes, std::uintptr_t sourceAddress,
        std::uint64_t readerNonce, std::uint8_t provenanceDepth);

    std::vector<std::byte> bytes_;
    std::uintptr_t sourceAddress_{};
    std::uint64_t readerNonce_{};
    std::uint8_t provenanceDepth_{};

    friend class CheckedMemoryReader;
};

class ImageMemoryToken final {
public:
    ImageMemoryToken() = delete;

private:
    ImageMemoryToken(
        std::uintptr_t address, std::size_t extent, std::uint64_t readerNonce);

    std::uintptr_t address_{};
    std::size_t extent_{};
    std::uint64_t readerNonce_{};

    friend class CheckedMemoryReader;
};

class DerivedMemoryToken final {
public:
    DerivedMemoryToken() = delete;

private:
    DerivedMemoryToken(
        std::uintptr_t address, std::size_t extent, std::uint8_t provenanceDepth,
        std::uint64_t readerNonce, std::string expectedType);

    std::uintptr_t address_{};
    std::size_t extent_{};
    std::uint8_t provenanceDepth_{};
    std::uint64_t readerNonce_{};
    std::string expectedType_;

    friend class CheckedMemoryReader;
};

class CheckedMemoryReader final {
public:
    static constexpr std::uint8_t kMaximumProvenanceDepth = 8;

    [[nodiscard]] static ContractResult<CheckedMemoryReader> Create(
        const ExactProfileMatch& match, std::shared_ptr<const IMemorySource> source);

    [[nodiscard]] ContractResult<ImageMemoryToken> ResolveImageRva(
        std::uint64_t rva, std::size_t extent, MemoryReadKind kind) const;
    [[nodiscard]] ContractResult<OwnedMemoryCopy> Read(
        const ImageMemoryToken& token, std::size_t offset, std::size_t size) const;
    [[nodiscard]] ContractResult<OwnedMemoryCopy> Read(
        const DerivedMemoryToken& token, std::size_t offset, std::size_t size) const;
    [[nodiscard]] ContractResult<DerivedMemoryToken> DerivePointer(
        const OwnedMemoryCopy& parent, std::size_t pointerOffset,
        std::size_t expectedExtent, std::string expectedType) const;
    [[nodiscard]] bool CanUseProfile(std::string_view profileId) const noexcept;

private:
    CheckedMemoryReader(
        std::vector<MappedSegment> segments, std::string profileId,
        std::shared_ptr<const IMemorySource> source);

    [[nodiscard]] ContractResult<OwnedMemoryCopy> CopyBounded(
        std::uintptr_t address, std::size_t extent, std::size_t offset,
        std::size_t size, std::uint8_t depth) const;

    std::vector<MappedSegment> segments_;
    std::shared_ptr<const IMemorySource> source_;
    std::string profileId_;
    std::uint64_t readerNonce_{};
};

}  // namespace serverhost::v2::bindings::platform
