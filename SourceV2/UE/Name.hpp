#pragma once

#include "SourceV2/Core/ContractResult.hpp"
#include "SourceV2/UE/Primitives.hpp"

#include <cstddef>
#include <span>
#include <string>
#include <vector>

namespace serverhost::v2::ue {

struct FName final {
    int32 comparisonIndex{};
    uint32 number{};

    [[nodiscard]] constexpr bool IsNone() const noexcept {
        return comparisonIndex == 0 && number == 0;
    }

    friend constexpr bool operator==(const FName&, const FName&) = default;
};

struct FNameEntryHeader final {
    bool isWide{};
    uint16 length{};
};

struct NamePoolBlock final {
    std::span<const std::byte> bytes;
};

class FNamePoolView final {
public:
    static constexpr uint32 kEntryStride = 2;
    static constexpr uint32 kBlockOffsetBits = 16;
    static constexpr uint32 kMaxBlocks = 0x2000;
    static constexpr uint16 kMaxNameLength = 0x3FF;

    FNamePoolView(std::span<const NamePoolBlock> blocks, uint32 currentBlock,
                  uint32 currentByteCursor)
        : blocks_(blocks), currentBlock_(currentBlock), currentByteCursor_(currentByteCursor) {}

    [[nodiscard]] static FNameEntryHeader DecodeHeader(uint16 raw) noexcept;
    [[nodiscard]] ContractResult<std::string> Resolve(FName name) const;

private:
    [[nodiscard]] ContractResult<std::span<const std::byte>> EntryBytes(int32 comparisonIndex) const;

    std::span<const NamePoolBlock> blocks_;
    uint32 currentBlock_{};
    uint32 currentByteCursor_{};
};

class INameResolver {
public:
    virtual ~INameResolver() = default;
    [[nodiscard]] virtual ContractResult<std::string> Resolve(FName name) const = 0;
};

class SnapshotNameResolver final : public INameResolver {
public:
    explicit SnapshotNameResolver(FNamePoolView pool) : pool_(pool) {}
    [[nodiscard]] ContractResult<std::string> Resolve(FName name) const override {
        return pool_.Resolve(name);
    }

private:
    FNamePoolView pool_;
};

static_assert(sizeof(FName) == 0x8);
static_assert(alignof(FName) == 0x4);
static_assert(offsetof(FName, comparisonIndex) == 0x0);
static_assert(offsetof(FName, number) == 0x4);

}  // namespace serverhost::v2::ue
