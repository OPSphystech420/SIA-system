#include "SourceV2/Bindings/Profiles/IOS_1_10280.hpp"
#include "SourceV2/Bindings/Profiles/ReadOnlyContracts_1_10280.hpp"
#include "SourceV2/Bindings/Profiles/LiveRelationships_1_10280.hpp"
#include "SourceV2/Bindings/Platform/CheckedMemoryReader.hpp"
#include "SourceV2/Bindings/Platform/ExactProfileSelector.hpp"
#include "SourceV2/Bindings/Platform/LoadedImageCatalog.hpp"
#include "SourceV2/Bindings/Platform/MemorySource.hpp"
#include "SourceV2/Bootstrap/LegacyRuntimeGuard.hpp"
#include "SourceV2/Diagnostics/DiagnosticSnapshot.hpp"
#include "SourceV2/Diagnostics/ContractCaptureInternal.hpp"
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

__attribute__((constructor)) void V2Entry() {
    diagnostics::Logger& logger = diagnostics::ProcessLogger();
    diagnostics::DiagnosticState diagnosticState{
        .buildId = kBuildId,
        .sourceRevision = kSourceRevision,
        .startupState = "diagnostic-bootstrap",
        .profileState = "not-evaluated",
        .legacyGuardState = "not-evaluated",
        .detail = "Gate 2C exact identity starting; capture remains explicit and read-only",
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
                + " scans_started=0 hooks=0 engine_calls=0 mutation=0");
        diagnostics::ProcessSnapshotPublisher().Publish(std::move(diagnosticState));
        ui::RequestDiagnosticUIBootstrap();
        return;
    }
    diagnosticState.legacyGuardState = "clear";
    logger.Add(
        diagnostics::LogSeverity::Info,
        diagnostics::LogCategory::LegacyGuard,
        "Legacy runtime guard clear");

    const std::array<bindings::BuildProfile, 1> profiles{
        bindings::profiles::kIOS_1_10280,
    };
    const std::shared_ptr<const bindings::platform::IMemorySource> memory =
        bindings::platform::MakeProcessMemorySource();
    const auto catalog = bindings::platform::LoadedImageCatalog::CaptureRuntime(*memory);
    bindings::platform::ExactProfileSelection selection;
    if (catalog) {
        const bindings::platform::ExactProfileSelector selector;
        selection = selector.Select(catalog.Value(), profiles, *memory);
    } else {
        selection.state = bindings::platform::ProfileMatchState::InspectionFailed;
        selection.receipt.profileMatchState =
            bindings::platform::ProfileMatchStateName(selection.state);
        selection.receipt.reason = catalog.Error().context;
    }

    const bindings::platform::IdentityReceipt& receipt = selection.receipt;
    diagnosticState.startupState = selection.state
            == bindings::platform::ProfileMatchState::ExactMatch
        ? "gate2c-live-relationship-capture-available"
        : "runtime-refused-diagnostics-available";
    diagnosticState.profileState = receipt.profileMatchState;
    if (!receipt.profileId.empty())
        diagnosticState.profileState += std::string(":") + receipt.profileId;
    diagnosticState.selectedImage = receipt.selectedImage;
    diagnosticState.product = receipt.product;
    diagnosticState.architecture = receipt.architecture;
    diagnosticState.imageUuid = receipt.uuid;
    diagnosticState.segmentSizes = receipt.segmentSizes;
    diagnosticState.textFingerprint = receipt.shortenedTextFingerprint;
    diagnosticState.identityReason = receipt.reason;
    diagnosticState.detail = selection.state == bindings::platform::ProfileMatchState::ExactMatch
        ? "Unique exact profile matched; press Capture for fresh owned objects and live relationships"
        : "Identity mismatch or ambiguity refused all later discovery";

    if (selection.match.has_value()) {
        const auto reader = bindings::platform::CheckedMemoryReader::Create(
            *selection.match, memory);
        if (reader) {
            diagnostics::ConfigureReadOnlyContractCapture(
                reader.Value(), bindings::profiles::kReadOnlyContractsIOS_1_10280,
                bindings::profiles::kLiveRelationshipsIOS_1_10280);
        } else {
            diagnosticState.startupState = "runtime-refused-diagnostics-available";
            diagnosticState.detail = "Exact identity matched but checked capture boundary refused initialization";
            diagnosticState.identityReason = reader.Error().context;
        }
    }

    const diagnostics::LogSeverity severity = selection.state
            == bindings::platform::ProfileMatchState::ExactMatch
        ? diagnostics::LogSeverity::Info
        : diagnostics::LogSeverity::Error;
    logger.Add(
        severity,
        diagnostics::LogCategory::Profile,
        std::string("identity_state=") + receipt.profileMatchState
            + " scans_started=0 hooks=0 engine_calls=0 mutation=0"
            + " image=" + (receipt.selectedImage.empty() ? "none" : receipt.selectedImage)
            + " product=" + (receipt.product.empty() ? "none" : receipt.product)
            + " architecture=" + (receipt.architecture.empty() ? "unknown" : receipt.architecture)
            + " uuid=" + (receipt.uuid.empty() ? "missing" : receipt.uuid)
            + " segments=" + (receipt.segmentSizes.empty() ? "missing" : receipt.segmentSizes)
            + " text_fingerprint="
            + (receipt.shortenedTextFingerprint.empty()
                   ? "missing" : receipt.shortenedTextFingerprint)
            + " profile=" + (receipt.profileId.empty() ? "none" : receipt.profileId)
            + " reason=" + receipt.reason);
    diagnostics::ProcessSnapshotPublisher().Publish(std::move(diagnosticState));
    ui::RequestDiagnosticUIBootstrap();
}

}  // namespace
}  // namespace serverhost::v2::bootstrap
