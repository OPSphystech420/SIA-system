#include "SourceV2/UE/String.hpp"

#include <cstdint>

namespace serverhost::v2::ue {
namespace {

template <typename Character>
ContractResult<std::u16string_view> ValidateFStringLayout(
    const TArrayLayout<Character>& layout, std::size_t capacityLimit) {
    auto array = BorrowedArrayView<Character>::FromLayout(layout, capacityLimit);
    if (!array) {
        return ContractResult<std::u16string_view>::Failure(
            array.Error().category, array.Error().context);
    }
    if (layout.num == 0) {
        return ContractResult<std::u16string_view>::Success({});
    }
    if (layout.data[layout.num - 1] != u'\0') {
        return ContractResult<std::u16string_view>::Failure(
            ContractErrorCategory::MalformedLayout, "FString is not null terminated at Num - 1");
    }
    for (int32 index = 0; index < layout.num - 1; ++index) {
        if (layout.data[index] == u'\0') {
            return ContractResult<std::u16string_view>::Failure(
                ContractErrorCategory::MalformedLayout, "FString contains an embedded null");
        }
    }
    return ContractResult<std::u16string_view>::Success(
        std::u16string_view(layout.data, static_cast<std::size_t>(layout.num - 1)));
}

void AppendUtf8(std::string& output, std::uint32_t codePoint) {
    if (codePoint <= 0x7F) {
        output.push_back(static_cast<char>(codePoint));
    } else if (codePoint <= 0x7FF) {
        output.push_back(static_cast<char>(0xC0 | (codePoint >> 6)));
        output.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    } else if (codePoint <= 0xFFFF) {
        output.push_back(static_cast<char>(0xE0 | (codePoint >> 12)));
        output.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F)));
        output.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    } else {
        output.push_back(static_cast<char>(0xF0 | (codePoint >> 18)));
        output.push_back(static_cast<char>(0x80 | ((codePoint >> 12) & 0x3F)));
        output.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F)));
        output.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    }
}

}  // namespace

ContractResult<FStringView> FStringView::FromLayout(
    const FStringLayout& layout, std::size_t capacityLimit) {
    auto units = ValidateFStringLayout(layout, capacityLimit);
    if (!units) {
        return ContractResult<FStringView>::Failure(units.Error().category, units.Error().context);
    }
    return ContractResult<FStringView>::Success(FStringView(units.Value()));
}

ContractResult<FStringView> FStringView::FromLayout(
    const ConstFStringLayout& layout, std::size_t capacityLimit) {
    auto units = ValidateFStringLayout(layout, capacityLimit);
    if (!units) {
        return ContractResult<FStringView>::Failure(units.Error().category, units.Error().context);
    }
    return ContractResult<FStringView>::Success(FStringView(units.Value()));
}

ContractResult<std::string> FStringView::ToUtf8() const {
    return Utf16ToUtf8(units_);
}

OwnedFString::OwnedFString(std::u16string text) {
    if (!text.empty()) {
        storage_.assign(text.begin(), text.end());
        storage_.push_back(u'\0');
    }
}

FStringLayout OwnedFString::BorrowLayout() noexcept {
    return {storage_.empty() ? nullptr : storage_.data(),
            static_cast<int32>(storage_.size()), static_cast<int32>(storage_.size())};
}

ConstFStringLayout OwnedFString::BorrowLayout() const noexcept {
    return {storage_.empty() ? nullptr : storage_.data(),
            static_cast<int32>(storage_.size()), static_cast<int32>(storage_.size())};
}

FStringView OwnedFString::View() const {
    const auto result = FStringView::FromLayout(BorrowLayout());
    return result.Value();
}

ContractResult<std::string> Utf16ToUtf8(std::u16string_view input) {
    std::string output;
    output.reserve(input.size());
    for (std::size_t index = 0; index < input.size(); ++index) {
        std::uint32_t codePoint = input[index];
        if (codePoint >= 0xD800 && codePoint <= 0xDBFF) {
            if (index + 1 >= input.size()) {
                return ContractResult<std::string>::Failure(
                    ContractErrorCategory::MalformedLayout, "UTF-16 ends with an unpaired high surrogate");
            }
            const std::uint32_t low = input[++index];
            if (low < 0xDC00 || low > 0xDFFF) {
                return ContractResult<std::string>::Failure(
                    ContractErrorCategory::MalformedLayout, "UTF-16 high surrogate is not followed by a low surrogate");
            }
            codePoint = 0x10000 + ((codePoint - 0xD800) << 10) + (low - 0xDC00);
        } else if (codePoint >= 0xDC00 && codePoint <= 0xDFFF) {
            return ContractResult<std::string>::Failure(
                ContractErrorCategory::MalformedLayout, "UTF-16 contains an unpaired low surrogate");
        }
        AppendUtf8(output, codePoint);
    }
    return ContractResult<std::string>::Success(std::move(output));
}

}  // namespace serverhost::v2::ue
