#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/UE/ObjectArray.hpp"

#include <array>

namespace serverhost::v2::tests {

void RunObjectIdentityTests(TestContext& context) {
    struct Dummy final { int value; } dummy{42};
    const std::array<ue::ObjectItemSnapshot, 1> items{{{&dummy, 9, false, false}}};
    const ue::ObjectArrayView objects(items);

    const ObjectIdentity identity{0, 9, 3};
    V2_EXPECT(context, (identity == ObjectIdentity{0, 9, 3}));
    V2_EXPECT(context, (!(identity == ObjectIdentity{0, 10, 3})));
    V2_EXPECT(context, (!(identity == ObjectIdentity{0, 9, 4})));

    ue::ObjectHandle<Dummy> handle(identity);
    auto resolved = handle.Resolve(objects, 3);
    V2_EXPECT(context, resolved);
    V2_EXPECT(context, resolved.Value()->value == 42);
    V2_EXPECT(context, !handle.Resolve(objects, 4));

    const ue::ObjectHandle<Dummy> staleSerial(ObjectIdentity{0, 10, 3});
    V2_EXPECT(context, !staleSerial.Resolve(objects, 3));
    const ue::ObjectHandle<Dummy> invalid(ObjectIdentity{-1, 0, 0});
    V2_EXPECT(context, !invalid.Resolve(objects, 3));

    const std::array<ue::ObjectItemSnapshot, 1> pending{{{&dummy, 9, false, true}}};
    V2_EXPECT(context, !handle.Resolve(ue::ObjectArrayView(pending), 3));
}

}  // namespace serverhost::v2::tests
