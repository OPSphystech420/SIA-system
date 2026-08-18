#include "SourceV2/Diagnostics/DiagnosticSnapshot.hpp"

#include <utility>

namespace serverhost::v2::diagnostics {
namespace {

constexpr std::size_t kStateFieldLimit = 160;
constexpr std::size_t kSegmentFieldLimit = 384;
constexpr std::size_t kIdentityReasonLimit = 256;
constexpr std::size_t kDetailLimit = 512;

std::string SafeStateField(std::string_view value) {
    return RedactDiagnosticText(value, kStateFieldLimit);
}

DiagnosticState SafeState(DiagnosticState state) {
    state.buildId = SafeStateField(state.buildId);
    state.sourceRevision = SafeStateField(state.sourceRevision);
    state.startupState = SafeStateField(state.startupState);
    state.profileState = SafeStateField(state.profileState);
    state.legacyGuardState = SafeStateField(state.legacyGuardState);
    state.selectedImage = SafeStateField(state.selectedImage);
    state.product = SafeStateField(state.product);
    state.architecture = SafeStateField(state.architecture);
    state.imageUuid = SafeStateField(state.imageUuid);
    state.segmentSizes = RedactDiagnosticText(state.segmentSizes, kSegmentFieldLimit);
    state.textFingerprint = SafeStateField(state.textFingerprint);
    state.identityReason = RedactDiagnosticText(state.identityReason, kIdentityReasonLimit);
    state.detail = RedactDiagnosticText(state.detail, kDetailLimit);
    return state;
}

}  // namespace

DiagnosticSnapshotPublisher::DiagnosticSnapshotPublisher(Logger& logger) : logger_(logger) {}

void DiagnosticSnapshotPublisher::Publish(DiagnosticState state) {
    std::lock_guard lock(mutex_);
    state_ = SafeState(std::move(state));
}

std::shared_ptr<const DiagnosticSnapshot> DiagnosticSnapshotPublisher::Capture() const {
    DiagnosticState state;
    {
        std::lock_guard lock(mutex_);
        state = state_;
    }
    auto snapshot = std::make_shared<DiagnosticSnapshot>();
    snapshot->buildId = std::move(state.buildId);
    snapshot->sourceRevision = std::move(state.sourceRevision);
    snapshot->startupState = std::move(state.startupState);
    snapshot->profileState = std::move(state.profileState);
    snapshot->legacyGuardState = std::move(state.legacyGuardState);
    snapshot->selectedImage = std::move(state.selectedImage);
    snapshot->product = std::move(state.product);
    snapshot->architecture = std::move(state.architecture);
    snapshot->imageUuid = std::move(state.imageUuid);
    snapshot->segmentSizes = std::move(state.segmentSizes);
    snapshot->textFingerprint = std::move(state.textFingerprint);
    snapshot->identityReason = std::move(state.identityReason);
    snapshot->detail = std::move(state.detail);
    snapshot->scansStarted = 0;
    snapshot->hooks = 0;
    snapshot->engineCalls = 0;
    snapshot->mutation = 0;
    snapshot->logs = logger_.Snapshot();
    return snapshot;
}

Logger& ProcessLogger() {
    static Logger logger(128, 512);
    return logger;
}

DiagnosticSnapshotPublisher& ProcessSnapshotPublisher() {
    static DiagnosticSnapshotPublisher publisher(ProcessLogger());
    return publisher;
}

std::shared_ptr<const DiagnosticSnapshot> CaptureDiagnosticSnapshot() {
    return ProcessSnapshotPublisher().Capture();
}

}  // namespace serverhost::v2::diagnostics
