#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/UE/Name.hpp"

#include <array>
#include <cstring>
#include <string>

namespace serverhost::v2::tests {
namespace {

void WriteNarrow(std::span<std::byte> block, std::size_t byteOffset, std::string_view value) {
    const ue::uint16 header = static_cast<ue::uint16>(value.size() << 6U);
    auto entry = block.subspan(byteOffset);
    std::memcpy(entry.data(), &header, sizeof(header));
    std::memcpy(entry.subspan(sizeof(header)).data(), value.data(), value.size());
}

void WriteWide(std::span<std::byte> block, std::size_t byteOffset, std::u16string_view value) {
    const ue::uint16 header = static_cast<ue::uint16>((value.size() << 6U) | 1U);
    auto entry = block.subspan(byteOffset);
    std::memcpy(entry.data(), &header, sizeof(header));
    std::memcpy(entry.subspan(sizeof(header)).data(), value.data(), value.size() * sizeof(char16_t));
}

}  // namespace

void RunNameTests(TestContext& context) {
    using namespace ue;

    V2_EXPECT(context, (FName{7, 2} == FName{7, 2}));
    V2_EXPECT(context, (!(FName{7, 2} == FName{7, 3})));
    const auto decoded = FNamePoolView::DecodeHeader(static_cast<uint16>((5U << 6U) | 1U));
    V2_EXPECT(context, decoded.isWide && decoded.length == 5);

    std::array<std::byte, 128> bytes{};
    WriteNarrow(bytes, 2, "ShooterGame");
    WriteWide(bytes, 40, u"Ark\U0001F995");
    const NamePoolBlock block{bytes};
    const std::array<NamePoolBlock, 1> blocks{block};
    FNamePoolView pool(blocks, 0, static_cast<uint32>(bytes.size()));

    auto narrow = pool.Resolve(FName{1, 2});
    V2_EXPECT(context, narrow);
    V2_EXPECT(context, narrow.Value() == "ShooterGame_1");
    auto wide = pool.Resolve(FName{20, 0});
    V2_EXPECT(context, wide);
    V2_EXPECT(context, wide.Value() == "Ark\xF0\x9F\xA6\x95");
    V2_EXPECT(context, !pool.Resolve(FName{-1, 0}));
    V2_EXPECT(context, !pool.Resolve(FName{1000, 0}));
}

}  // namespace serverhost::v2::tests
