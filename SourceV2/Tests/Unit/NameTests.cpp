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

    FNamePoolView invalidCursor(blocks, 0, static_cast<uint32>(bytes.size() + 1));
    V2_EXPECT(context, !invalidCursor.Resolve(FName{1, 0}));

    std::array<std::byte, 16> malformedBytes{};
    const uint16 excessiveHeader = static_cast<uint16>(100U << 6U);
    std::memcpy(malformedBytes.data(), &excessiveHeader, sizeof(excessiveHeader));
    const std::array<NamePoolBlock, 1> malformedBlocks{{{malformedBytes}}};
    V2_EXPECT(context, !FNamePoolView(malformedBlocks, 0, malformedBytes.size())
        .Resolve(FName{0, 0}));

    std::array<std::byte, 4096> oversizedWideBytes{};
    std::u16string oversizedWide(800, static_cast<char16_t>(0x0800));
    WriteWide(oversizedWideBytes, 0, oversizedWide);
    const std::array<NamePoolBlock, 1> oversizedWideBlocks{{{oversizedWideBytes}}};
    const auto oversizedResult = FNamePoolView(
        oversizedWideBlocks, 0, oversizedWideBytes.size()).Resolve(FName{0, 0});
    V2_EXPECT(context, !oversizedResult
        && oversizedResult.Error().category == ContractErrorCategory::LimitExceeded);
}

}  // namespace serverhost::v2::tests
