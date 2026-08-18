#include "SourceV2/Bindings/Profiles/IOS_1_10280.hpp"
#include "SourceV2/Bindings/Validation/ProfileValidator.hpp"
#include "SourceV2/Bootstrap/InertInitialization.hpp"
#include "SourceV2/Bootstrap/LegacyRuntimeGuard.hpp"

#include <array>
#include <cstdio>

namespace serverhost::v2::bootstrap {
namespace {

#ifndef SERVERHOST_V2_BUILD_ID
#define SERVERHOST_V2_BUILD_ID "unidentified-v2-build"
#endif

constexpr const char* kBuildId = SERVERHOST_V2_BUILD_ID;

const char* StateName(InertInitializationState state) noexcept {
    switch (state) {
        case InertInitializationState::ProfileValidated: return "profile-validated";
        case InertInitializationState::MissingIdentityEvidence: return "missing-identity-evidence";
        case InertInitializationState::UnsupportedBuild: return "unsupported-build";
    }
    return "unknown";
}

__attribute__((constructor)) void V2Entry() {
    const LegacyRuntimeStatus legacyStatus = InspectLoadedImagesForLegacyRuntime();
    if (legacyStatus != LegacyRuntimeStatus::Clear) {
        const char* reason = legacyStatus == LegacyRuntimeStatus::LegacyLoaded
            ? "legacy-runtime-loaded"
            : "loaded-image-inspection-failed";
        std::fprintf(
            stderr,
            "[ServerHostV2] build=%s startup=refused reason=%s hooks=0 engine_calls=0 mutation=0\n",
            kBuildId,
            reason);
        return;
    }

    const BuildIdentity identityCandidate{
        .platform = Platform::IOS,
        .product = "ShooterGame",
        .version = "1.10280",
        .imageUuid = std::nullopt,
        .textFingerprint = std::nullopt,
        .imageSize = 0,
    };
    const std::array<bindings::BuildProfile, 1> profiles{
        bindings::profiles::kIOS_1_10280,
    };
    const bindings::StrictRuntimeProfileValidator validator;
    const InertInitializationReport report = InitializeInert(identityCandidate, profiles, validator);

    std::fprintf(
        stderr,
        "[ServerHostV2] build=%s state=%s profile=%s hooks=%d engine_calls=%d mutation=%d detail=%s\n",
        kBuildId,
        StateName(report.state),
        report.profileId.empty() ? "none" : report.profileId.c_str(),
        report.hooksInstalled ? 1 : 0,
        report.engineCallsEnabled ? 1 : 0,
        report.mutationEnabled ? 1 : 0,
        report.detail.c_str());
}

}  // namespace
}  // namespace serverhost::v2::bootstrap
