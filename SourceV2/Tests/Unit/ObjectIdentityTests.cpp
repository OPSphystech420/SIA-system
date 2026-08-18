#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/UE/ObjectArray.hpp"

#include <array>

namespace serverhost::v2::tests {

void RunObjectIdentityTests(TestContext& context) {
    struct Dummy final {};
    const std::array<ue::ObjectItemSnapshot, 1> items{{{
        .objectIndex = 0, .serialNumber = 9, .clusterIndex = 0,
        .isNull = false, .unreachable = false, .pendingKill = false,
        .malformed = false,
    }}};
    const ue::ObjectArrayView objects(items);

    const ObjectIdentity identity{0, 9, 3};
    V2_EXPECT(context, (identity == ObjectIdentity{0, 9, 3}));
    V2_EXPECT(context, (!(identity == ObjectIdentity{0, 10, 3})));
    V2_EXPECT(context, (!(identity == ObjectIdentity{0, 9, 4})));

    ue::ObjectHandle<Dummy> handle(identity);
    auto resolved = handle.Resolve(objects, 3);
    V2_EXPECT(context, resolved);
    V2_EXPECT(context, resolved.Value().objectIndex == 0);
    V2_EXPECT(context, !handle.Resolve(objects, 4));

    const ue::ObjectHandle<Dummy> staleSerial(ObjectIdentity{0, 10, 3});
    V2_EXPECT(context, !staleSerial.Resolve(objects, 3));
    const ue::ObjectHandle<Dummy> invalid(ObjectIdentity{-1, 0, 0});
    V2_EXPECT(context, !invalid.Resolve(objects, 3));

    const std::array<ue::ObjectItemSnapshot, 1> pending{{{
        .objectIndex = 0, .serialNumber = 9, .clusterIndex = 0,
        .isNull = false, .unreachable = false, .pendingKill = true,
        .malformed = false,
    }}};
    V2_EXPECT(context, !handle.Resolve(ue::ObjectArrayView(pending), 3));

    const ue::ObjectHandle<Dummy> serialZero(ObjectIdentity{0, 0, 3});
    const std::array<ue::ObjectItemSnapshot, 1> zeroSerial{{{
        .objectIndex = 0, .serialNumber = 0, .clusterIndex = 0,
        .isNull = false, .unreachable = false, .pendingKill = false,
        .malformed = false,
    }}};
    V2_EXPECT(context, serialZero.Resolve(ue::ObjectArrayView(zeroSerial), 3));
}

}  // namespace serverhost::v2::tests
