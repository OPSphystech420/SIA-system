#pragma once

#include "SourceV2/Core/ContractResult.hpp"
#include "SourceV2/UE/Primitives.hpp"

#include <cstddef>
#include <functional>
#include <limits>
#include <span>

namespace serverhost::v2::ue {

template <typename T>
struct TArrayLayout final {
    T* data{};
    int32 num{};
    int32 max{};
};

enum class ArrayValidity {
    Valid,
    NegativeCount,
    CountExceedsCapacity,
    MissingStorage,
    CapacityLimitExceeded,
    ByteSizeOverflow,
};

template <typename T>
class BorrowedArrayView final {
public:
    static ContractResult<BorrowedArrayView> FromLayout(
        const TArrayLayout<T>& layout,
        std::size_t capacityLimit = static_cast<std::size_t>(std::numeric_limits<int32>::max())) {
        const ArrayValidity validity = ValidateLayout(layout, capacityLimit);
        if (validity != ArrayValidity::Valid) {
            return ContractResult<BorrowedArrayView>::Failure(
                ContractErrorCategory::MalformedLayout, ValidityName(validity));
        }
        return ContractResult<BorrowedArrayView>::Success(BorrowedArrayView(layout));
    }

    [[nodiscard]] static ArrayValidity ValidateLayout(
        const TArrayLayout<T>& layout,
        std::size_t capacityLimit = static_cast<std::size_t>(std::numeric_limits<int32>::max())) noexcept {
        if (layout.num < 0 || layout.max < 0) {
            return ArrayValidity::NegativeCount;
        }
        if (layout.num > layout.max) {
            return ArrayValidity::CountExceedsCapacity;
        }
        if (layout.max > 0 && layout.data == nullptr) {
            return ArrayValidity::MissingStorage;
        }
        if (static_cast<std::size_t>(layout.max) > capacityLimit) {
            return ArrayValidity::CapacityLimitExceeded;
        }
        if (layout.max > 0
            && static_cast<std::size_t>(layout.max)
                > std::numeric_limits<std::size_t>::max() / sizeof(T)) {
            return ArrayValidity::ByteSizeOverflow;
        }
        return ArrayValidity::Valid;
    }

    [[nodiscard]] std::size_t Size() const noexcept { return static_cast<std::size_t>(layout_.num); }
    [[nodiscard]] std::size_t Capacity() const noexcept { return static_cast<std::size_t>(layout_.max); }
    [[nodiscard]] bool Empty() const noexcept { return layout_.num == 0; }

    [[nodiscard]] ContractResult<std::reference_wrapper<const T>> At(std::size_t index) const {
        if (index >= Size()) {
            return ContractResult<std::reference_wrapper<const T>>::Failure(
                ContractErrorCategory::OutOfRange, "TArray index is outside Num");
        }
        return ContractResult<std::reference_wrapper<const T>>::Success(std::cref(layout_.data[index]));
    }

    [[nodiscard]] std::span<const T> Span() const noexcept {
        return {layout_.data, Size()};
    }

private:
    explicit BorrowedArrayView(TArrayLayout<T> layout) : layout_(layout) {}

    static const char* ValidityName(ArrayValidity validity) noexcept {
        switch (validity) {
            case ArrayValidity::Valid: return "valid";
            case ArrayValidity::NegativeCount: return "TArray has a negative Num or Max";
            case ArrayValidity::CountExceedsCapacity: return "TArray Num exceeds Max";
            case ArrayValidity::MissingStorage: return "TArray has capacity without storage";
            case ArrayValidity::CapacityLimitExceeded: return "TArray Max exceeds the configured limit";
            case ArrayValidity::ByteSizeOverflow: return "TArray byte size overflows size_t";
        }
        return "unknown TArray validation failure";
    }

    TArrayLayout<T> layout_{};
};

static_assert(sizeof(TArrayLayout<int32>) == 0x10);
static_assert(alignof(TArrayLayout<int32>) == 0x8);
static_assert(offsetof(TArrayLayout<int32>, data) == 0x0);
static_assert(offsetof(TArrayLayout<int32>, num) == 0x8);
static_assert(offsetof(TArrayLayout<int32>, max) == 0xC);

}  // namespace serverhost::v2::ue
