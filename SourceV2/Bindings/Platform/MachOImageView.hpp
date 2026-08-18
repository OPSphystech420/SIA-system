#pragma once

#include "SourceV2/Core/BuildIdentity.hpp"
#include "SourceV2/Core/ContractResult.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <string>
#include <vector>

namespace serverhost::v2::bindings::platform {

struct MappedSegment final {
    std::string name;
    std::uint64_t preferredAddress{};
    std::uintptr_t mappedAddress{};
    std::uint64_t virtualSize{};
    std::uint64_t fileOffset{};
    std::uint64_t fileSize{};
    std::uint8_t initialPermissions{};

    [[nodiscard]] bool IsReadable() const noexcept;
    [[nodiscard]] bool IsExecutable() const noexcept;
    [[nodiscard]] bool Contains(std::uintptr_t address, std::size_t size) const noexcept;
};

struct MachOSection final {
    std::string segmentName;
    std::string sectionName;
    std::uintptr_t mappedAddress{};
    std::uint64_t size{};
    std::uint32_t fileOffset{};
};

class MachOImageView final {
public:
    static constexpr std::size_t kHeader64Size = 32;
    static constexpr std::size_t kMaximumLoadCommandBytes = 1024U * 1024U;

    [[nodiscard]] static ContractResult<std::size_t> RequiredPrefixSize(
        std::span<const std::byte> headerBytes);
    [[nodiscard]] static ContractResult<MachOImageView> Parse(
        std::span<const std::byte> bytes, std::intptr_t slide);

    [[nodiscard]] ImageArchitecture Architecture() const noexcept;
    [[nodiscard]] ImageRole Role() const noexcept;
    [[nodiscard]] const std::array<std::uint8_t, 16>& Uuid() const noexcept;
    [[nodiscard]] bool HasUuid() const noexcept;
    [[nodiscard]] const std::vector<MappedSegment>& Segments() const noexcept;
    [[nodiscard]] const MachOSection* FindSection(
        std::string_view segmentName, std::string_view sectionName) const noexcept;
    [[nodiscard]] std::size_t FileSpanSize() const noexcept;
    [[nodiscard]] std::size_t StableFilePrefixSize() const noexcept;

private:
    ImageArchitecture architecture_{ImageArchitecture::Unknown};
    ImageRole role_{ImageRole::Unknown};
    std::array<std::uint8_t, 16> uuid_{};
    bool hasUuid_{};
    std::vector<MappedSegment> segments_;
    std::vector<MachOSection> sections_;
    std::size_t fileSpanSize_{};
    std::size_t stableFilePrefixSize_{};
};

[[nodiscard]] std::string ImageArchitectureName(ImageArchitecture architecture);
[[nodiscard]] std::string FormatUuid(const std::array<std::uint8_t, 16>& uuid);
[[nodiscard]] std::string FormatSegmentSizes(
    std::span<const ImageSegmentIdentity> segments);

}  // namespace serverhost::v2::bindings::platform
