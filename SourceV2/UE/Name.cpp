#include "SourceV2/UE/Name.hpp"

#include "SourceV2/UE/String.hpp"

#include <cstring>
#include <limits>
#include <string_view>

namespace serverhost::v2::ue {

FNameEntryHeader FNamePoolView::DecodeHeader(uint16 raw) noexcept {
    return FNameEntryHeader{
        .isWide = (raw & 0x1U) != 0,
        .length = static_cast<uint16>((raw >> 6U) & kMaxNameLength),
    };
}

ContractResult<std::span<const std::byte>> FNamePoolView::EntryBytes(int32 comparisonIndex) const {
    if (comparisonIndex < 0) {
        return ContractResult<std::span<const std::byte>>::Failure(
            ContractErrorCategory::OutOfRange, "FName comparison index is negative");
    }

    const auto rawIndex = static_cast<uint32>(comparisonIndex);
    const uint32 blockIndex = rawIndex >> kBlockOffsetBits;
    const uint32 offsetUnits = rawIndex & ((1U << kBlockOffsetBits) - 1U);
    if (blockIndex > currentBlock_ || blockIndex >= blocks_.size() || blockIndex >= kMaxBlocks) {
        return ContractResult<std::span<const std::byte>>::Failure(
            ContractErrorCategory::OutOfRange, "FName block index is outside the visible pool");
    }

    const std::size_t byteOffset = static_cast<std::size_t>(offsetUnits) * kEntryStride;
    const std::size_t visibleBytes = blockIndex == currentBlock_
        ? static_cast<std::size_t>(currentByteCursor_)
        : blocks_[blockIndex].bytes.size();
    if (visibleBytes > blocks_[blockIndex].bytes.size() || byteOffset > visibleBytes
        || visibleBytes - byteOffset < sizeof(uint16)) {
        return ContractResult<std::span<const std::byte>>::Failure(
            ContractErrorCategory::MalformedLayout, "FName entry header lies outside visible block bytes");
    }
    return ContractResult<std::span<const std::byte>>::Success(
        blocks_[blockIndex].bytes.subspan(byteOffset, visibleBytes - byteOffset));
}

ContractResult<std::string> FNamePoolView::Resolve(FName name) const {
    auto entryResult = EntryBytes(name.comparisonIndex);
    if (!entryResult) {
        return ContractResult<std::string>::Failure(
            entryResult.Error().category, entryResult.Error().context);
    }

    const auto entry = entryResult.Value();
    uint16 rawHeader{};
    std::memcpy(&rawHeader, entry.data(), sizeof(rawHeader));
    const FNameEntryHeader header = DecodeHeader(rawHeader);
    const std::size_t unitSize = header.isWide ? sizeof(TCHAR) : sizeof(char);
    const std::size_t payloadSize = static_cast<std::size_t>(header.length) * unitSize;
    if (header.length == 0 || payloadSize > entry.size() - sizeof(rawHeader)) {
        return ContractResult<std::string>::Failure(
            ContractErrorCategory::MalformedLayout, "FName entry length exceeds its visible block");
    }

    std::string decoded;
    if (header.isWide) {
        std::u16string wide(header.length, u'\0');
        std::memcpy(wide.data(), entry.subspan(sizeof(rawHeader)).data(), payloadSize);
        auto converted = Utf16ToUtf8(wide);
        if (!converted) {
            return ContractResult<std::string>::Failure(
                converted.Error().category, converted.Error().context);
        }
        decoded = std::move(converted.Value());
    } else {
        decoded.resize(header.length);
        std::memcpy(decoded.data(), entry.subspan(sizeof(rawHeader)).data(), payloadSize);
    }

    if (decoded.size() > kMaxOutputBytes) {
        return ContractResult<std::string>::Failure(
            ContractErrorCategory::LimitExceeded, "decoded FName exceeds output bound");
    }

    if (name.number > 0) {
        if (decoded.size() > kMaxOutputBytes - 16) {
            return ContractResult<std::string>::Failure(
                ContractErrorCategory::LimitExceeded,
                "numbered FName exceeds output bound");
        }
        decoded += "_" + std::to_string(name.number - 1);
    }
    return ContractResult<std::string>::Success(std::move(decoded));
}

}  // namespace serverhost::v2::ue
