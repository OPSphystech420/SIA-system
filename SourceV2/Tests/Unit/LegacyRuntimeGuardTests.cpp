#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/Bootstrap/LegacyRuntimeGuard.hpp"

namespace serverhost::v2::tests {

void RunLegacyRuntimeGuardTests(TestContext& context) {
    using bootstrap::IsLegacyRuntimeImagePath;

    V2_EXPECT(context, IsLegacyRuntimeImagePath("ServerHost.dylib"));
    V2_EXPECT(context, IsLegacyRuntimeImagePath(
        "/Library/MobileSubstrate/DynamicLibraries/ServerHost.dylib"));
    V2_EXPECT(context, !IsLegacyRuntimeImagePath(
        "/Library/MobileSubstrate/DynamicLibraries/ServerHostV2.dylib"));
    V2_EXPECT(context, !IsLegacyRuntimeImagePath("NotServerHost.dylib"));
    V2_EXPECT(context, !IsLegacyRuntimeImagePath("/ServerHost.dylib/Other.dylib"));
}

}  // namespace serverhost::v2::tests
