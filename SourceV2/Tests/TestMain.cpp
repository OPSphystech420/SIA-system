#include "SourceV2/Tests/TestHarness.hpp"

#include <iostream>

namespace serverhost::v2::tests {
void CompileLayoutAssertions();
void RunContainerStringTests(TestContext&);
void RunNameTests(TestContext&);
void RunObjectIdentityTests(TestContext&);
void RunReflectionTests(TestContext&);
void RunProfileInitializationTests(TestContext&);
void RunLegacyRuntimeGuardTests(TestContext&);
void RunDiagnosticsTests(TestContext&);
void RunPlatformBoundaryTests(TestContext&);
void RunReadOnlySnapshotCaptureTests(TestContext&);
void RunPresentationStateMachineTests(TestContext&);
}  // namespace serverhost::v2::tests

int main() {
    serverhost::v2::tests::TestContext context;
    std::cout << "[v2] layout assertions\n" << std::flush;
    serverhost::v2::tests::CompileLayoutAssertions();
    std::cout << "[v2] containers and strings\n" << std::flush;
    serverhost::v2::tests::RunContainerStringTests(context);
    std::cout << "[v2] names\n" << std::flush;
    serverhost::v2::tests::RunNameTests(context);
    std::cout << "[v2] object identity\n" << std::flush;
    serverhost::v2::tests::RunObjectIdentityTests(context);
    std::cout << "[v2] reflection cache\n" << std::flush;
    serverhost::v2::tests::RunReflectionTests(context);
    std::cout << "[v2] profile and inert initialization\n" << std::flush;
    serverhost::v2::tests::RunProfileInitializationTests(context);
    std::cout << "[v2] legacy runtime isolation\n" << std::flush;
    serverhost::v2::tests::RunLegacyRuntimeGuardTests(context);
    std::cout << "[v2] diagnostics and refusal presentation\n" << std::flush;
    serverhost::v2::tests::RunDiagnosticsTests(context);
    std::cout << "[v2] Gate 2A image identity and checked memory\n" << std::flush;
    serverhost::v2::tests::RunPlatformBoundaryTests(context);
    std::cout << "[v2] Gate 2B owned read-only snapshots\n" << std::flush;
    serverhost::v2::tests::RunReadOnlySnapshotCaptureTests(context);
    std::cout << "[v2] presentation state machine\n" << std::flush;
    serverhost::v2::tests::RunPresentationStateMachineTests(context);

    std::cout << "serverhost_v2_core_tests: " << context.Assertions() << " assertions, "
              << context.Failures() << " failures\n";
    return context.Failures() == 0 ? 0 : 1;
}
