#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/UE/Containers.hpp"
#include "SourceV2/UE/String.hpp"

#include <string>
#include <utility>

namespace serverhost::v2::tests {

void RunContainerStringTests(TestContext& context) {
    using namespace ue;

    int32 values[] = {3, 5, 8};
    auto valid = BorrowedArrayView<int32>::FromLayout({values, 3, 3}, 8);
    V2_EXPECT(context, valid);
    V2_EXPECT(context, valid.Value().Size() == 3);
    V2_EXPECT(context, valid.Value().At(1));
    V2_EXPECT(context, valid.Value().At(1).Value().get() == 5);
    V2_EXPECT(context, !valid.Value().At(3));

    V2_EXPECT(context, BorrowedArrayView<int32>::FromLayout({nullptr, 0, 0}));
    V2_EXPECT(context, !BorrowedArrayView<int32>::FromLayout({values, -1, 3}));
    V2_EXPECT(context, !BorrowedArrayView<int32>::FromLayout({values, 4, 3}));
    V2_EXPECT(context, !BorrowedArrayView<int32>::FromLayout({nullptr, 0, 1}));
    V2_EXPECT(context, !BorrowedArrayView<int32>::FromLayout({values, 1, 9}, 8));

    OwnedFString owned(u"Host \U0001F680");
    V2_EXPECT(context, !owned.CanTransferToEngine());
    auto borrowed = FStringView::FromLayout(owned.BorrowLayout());
    V2_EXPECT(context, borrowed);
    auto utf8 = borrowed.Value().ToUtf8();
    V2_EXPECT(context, utf8);
    V2_EXPECT(context, utf8.Value() == "Host \xF0\x9F\x9A\x80");

    OwnedFString moved(std::move(owned));
    V2_EXPECT(context, moved.View().ToUtf8().Value() == "Host \xF0\x9F\x9A\x80");
    const OwnedFString immutable(u"Read only");
    auto immutableView = FStringView::FromLayout(immutable.BorrowLayout());
    V2_EXPECT(context, immutableView);
    V2_EXPECT(context, immutableView.Value().ToUtf8().Value() == "Read only");

    TCHAR unterminated[] = {u'A'};
    V2_EXPECT(context, !FStringView::FromLayout(FStringLayout{unterminated, 1, 1}));
    TCHAR embeddedNull[] = {u'A', u'\0', u'B', u'\0'};
    V2_EXPECT(context, !FStringView::FromLayout(FStringLayout{embeddedNull, 4, 4}));
    const std::u16string invalidSurrogate(1, static_cast<TCHAR>(0xD800));
    V2_EXPECT(context, !Utf16ToUtf8(invalidSurrogate));
}

}  // namespace serverhost::v2::tests
