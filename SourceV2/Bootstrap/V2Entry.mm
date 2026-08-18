#include "SourceV2/Bindings/Profiles/IOS_1_10280.hpp"
#include "SourceV2/Bindings/Validation/ProfileValidator.hpp"
#include "SourceV2/Bootstrap/InertInitialization.hpp"
#include "SourceV2/Bootstrap/LegacyRuntimeGuard.hpp"
#include "SourceV2/Diagnostics/DiagnosticSnapshot.hpp"
#include "SourceV2/Diagnostics/Logger.hpp"
#include "SourceV2/UI/DiagnosticUIBootstrap.hpp"

#include <array>
#include <string>
#include <utility>

namespace serverhost::v2::bootstrap {
namespace {

#ifndef SERVERHOST_V2_BUILD_ID
#define SERVERHOST_V2_BUILD_ID "unidentified-v2-build"
#endif

#ifndef SERVERHOST_V2_SOURCE_REVISION
#define SERVERHOST_V2_SOURCE_REVISION "unavailable"
#endif

constexpr const char* kBuildId = SERVERHOST_V2_BUILD_ID;
constexpr const char* kSourceRevision = SERVERHOST_V2_SOURCE_REVISION;

const char* StateName(InertInitializationState state) noexcept {
    switch (state) {
        case InertInitializationState::ProfileValidated: return "profile-validated";
        case InertInitializationState::MissingIdentityEvidence: return "missing-identity-evidence";
        case InertInitializationState::UnsupportedBuild: return "unsupported-build";
    }
    return "unknown";
}

__attribute__((constructor)) void V2Entry() {
    diagnostics::Logger& logger = diagnostics::ProcessLogger();
    diagnostics::DiagnosticState diagnosticState{
        .buildId = kBuildId,
        .sourceRevision = kSourceRevision,
        .startupState = "diagnostic-bootstrap",
        .profileState = "not-evaluated",
        .legacyGuardState = "not-evaluated",
        .detail = "Gate 1.5 diagnostics starting; runtime capabilities remain inert",
    };
    logger.Add(
        diagnostics::LogSeverity::Info,
        diagnostics::LogCategory::Startup,
        std::string("build=") + kBuildId + " source_revision=" + kSourceRevision);

    const LegacyRuntimeStatus legacyStatus = InspectLoadedImagesForLegacyRuntime();
    if (legacyStatus != LegacyRuntimeStatus::Clear) {
        const char* reason = legacyStatus == LegacyRuntimeStatus::LegacyLoaded
            ? "legacy-runtime-loaded"
            : "loaded-image-inspection-failed";
        diagnosticState.startupState = "runtime-refused-diagnostics-available";
        diagnosticState.legacyGuardState = reason;
        diagnosticState.detail =
            "Legacy guard refused UE/runtime capabilities; diagnostic UI remains available";
        logger.Add(
            diagnostics::LogSeverity::Error,
            diagnostics::LogCategory::LegacyGuard,
            std::string("runtime capabilities refused reason=") + reason
                + " hooks=0 engine_calls=0 mutation=0");
        diagnostics::ProcessSnapshotPublisher().Publish(std::move(diagnosticState));
        ui::RequestDiagnosticUIBootstrap();
        return;
    }
    diagnosticState.legacyGuardState = "clear";
    logger.Add(
        diagnostics::LogSeverity::Info,
        diagnostics::LogCategory::LegacyGuard,
        "Legacy runtime guard clear");

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

    diagnosticState.startupState = "runtime-inert-diagnostics-available";
    diagnosticState.profileState = StateName(report.state);
    if (!report.profileId.empty())
        diagnosticState.profileState += std::string(":") + report.profileId;
    diagnosticState.detail = report.detail;

    const diagnostics::LogSeverity severity =
        report.state == InertInitializationState::ProfileValidated
        ? diagnostics::LogSeverity::Info
        : diagnostics::LogSeverity::Warning;
    logger.Add(
        severity,
        diagnostics::LogCategory::Profile,
        std::string("state=") + StateName(report.state)
            + " profile=" + (report.profileId.empty() ? "none" : report.profileId)
            + " hooks=0 engine_calls=0 mutation=0 detail=" + report.detail);
    diagnostics::ProcessSnapshotPublisher().Publish(std::move(diagnosticState));
    ui::RequestDiagnosticUIBootstrap();
}

}  // namespace
}  // namespace serverhost::v2::bootstrap
