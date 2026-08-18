#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/Bindings/Profiles/IOS_1_10280.hpp"
#include "SourceV2/Bindings/Validation/ProfileValidator.hpp"
#include "SourceV2/Bootstrap/InertInitialization.hpp"

#include <array>

namespace serverhost::v2::tests {

void RunProfileInitializationTests(TestContext& context) {
    using namespace bindings;
    const StrictRuntimeProfileValidator validator;

    BuildIdentity currentCandidate{
        .platform = Platform::IOS,
        .product = "ShooterGame",
        .version = "1.10280",
        .architecture = ImageArchitecture::Arm64,
        .role = ImageRole::MainExecutable,
        .imageUuid = std::nullopt,
        .textFingerprint = std::nullopt,
        .textFingerprintRange = "",
        .textFingerprintSize = 0,
        .segments = {},
        .stableImagePrefixSize = 0,
    };
    const std::array<BuildProfile, 1> pendingProfiles{profiles::kIOS_1_10280};
    auto pending = bootstrap::InitializeInert(currentCandidate, pendingProfiles, validator);
    V2_EXPECT(context, pending.state == bootstrap::InertInitializationState::MissingIdentityEvidence);
    V2_EXPECT(context, !pending.hooksInstalled && !pending.engineCallsEnabled && !pending.mutationEnabled);

    std::array<std::uint8_t, 16> uuid{};
    uuid[0] = 0x42;
    BuildProfile synthetic{
        .profileId = "host-test-complete",
        .platform = Platform::HostTest,
        .product = "SyntheticShooterGame",
        .version = "test-1",
        .expectedArchitecture = ImageArchitecture::Arm64,
        .expectedRole = ImageRole::MainExecutable,
        .expectedImageUuid = uuid,
        .expectedTextFingerprint = "abc123",
        .expectedTextFingerprintRange = "__TEXT,__text",
        .expectedTextFingerprintSize = 128,
        .expectedSegments = {
            {"__TEXT", 4096, 4096, ImagePermissionRead | ImagePermissionExecute},
        },
        .expectedStableImagePrefixSize = 4096,
        .identityEvidenceComplete = true,
    };
    BuildIdentity matching{
        .platform = Platform::HostTest,
        .product = "SyntheticShooterGame",
        .version = "test-1",
        .architecture = ImageArchitecture::Arm64,
        .role = ImageRole::MainExecutable,
        .imageUuid = uuid,
        .textFingerprint = "abc123",
        .textFingerprintRange = "__TEXT,__text",
        .textFingerprintSize = 128,
        .segments = {
            {"__TEXT", 4096, 4096, ImagePermissionRead | ImagePermissionExecute},
        },
        .stableImagePrefixSize = 4096,
    };
    const std::array<BuildProfile, 1> supportedProfiles{synthetic};
    auto supported = bootstrap::InitializeInert(matching, supportedProfiles, validator);
    V2_EXPECT(context, supported.state == bootstrap::InertInitializationState::ProfileValidated);
    V2_EXPECT(context, supported.profileId == "host-test-complete");
    V2_EXPECT(context, !supported.hooksInstalled && !supported.engineCallsEnabled && !supported.mutationEnabled);

    matching.stableImagePrefixSize = 4097;
    auto rejected = bootstrap::InitializeInert(matching, supportedProfiles, validator);
    V2_EXPECT(context, rejected.state == bootstrap::InertInitializationState::UnsupportedBuild);
}

}  // namespace serverhost::v2::tests
