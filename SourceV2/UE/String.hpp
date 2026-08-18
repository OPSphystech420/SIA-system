#pragma once

#include "SourceV2/Core/ContractResult.hpp"
#include "SourceV2/UE/Containers.hpp"

#include <string>
#include <string_view>
#include <vector>

namespace serverhost::v2::ue {

using FStringLayout = TArrayLayout<TCHAR>;
using ConstFStringLayout = TArrayLayout<const TCHAR>;

class FStringView final {
public:
    static ContractResult<FStringView> FromLayout(
        const FStringLayout& layout, std::size_t capacityLimit = 1U << 20);
    static ContractResult<FStringView> FromLayout(
        const ConstFStringLayout& layout, std::size_t capacityLimit = 1U << 20);

    [[nodiscard]] bool Empty() const noexcept { return units_.empty(); }
    [[nodiscard]] std::u16string_view Units() const noexcept { return units_; }
    [[nodiscard]] ContractResult<std::string> ToUtf8() const;

private:
    explicit FStringView(std::u16string_view units) : units_(units) {}
    std::u16string_view units_;
};

// Portable host ownership for Gate 1 tests and immutable values. It is not a
// UE-allocator buffer and cannot be transferred to the game.
class OwnedFString final {
public:
    OwnedFString() = default;
    explicit OwnedFString(std::u16string text);

    OwnedFString(const OwnedFString&) = delete;
    OwnedFString& operator=(const OwnedFString&) = delete;
    OwnedFString(OwnedFString&&) noexcept = default;
    OwnedFString& operator=(OwnedFString&&) noexcept = default;

    [[nodiscard]] FStringLayout BorrowLayout() noexcept;
    [[nodiscard]] ConstFStringLayout BorrowLayout() const noexcept;
    [[nodiscard]] FStringView View() const;
    [[nodiscard]] bool CanTransferToEngine() const noexcept { return false; }

private:
    std::vector<TCHAR> storage_;
};

ContractResult<std::string> Utf16ToUtf8(std::u16string_view input);

}  // namespace serverhost::v2::ue
