#include "SourceV2/UI/DiagnosticPresentationModel.hpp"

#include <utility>

namespace serverhost::v2::ui {

DiagnosticPresentationModel::DiagnosticPresentationModel(
    const diagnostics::DiagnosticSnapshot& snapshot)
    : logs_(snapshot.logs) {
    statusRows_.reserve(17);
    statusRows_.push_back({"Build ID", snapshot.buildId});
    statusRows_.push_back({"Source revision", snapshot.sourceRevision});
    statusRows_.push_back({"Startup", snapshot.startupState});
    statusRows_.push_back({"Profile", snapshot.profileState});
    statusRows_.push_back({"Legacy guard", snapshot.legacyGuardState});
    statusRows_.push_back({"Selected image", snapshot.selectedImage});
    statusRows_.push_back({"Product", snapshot.product});
    statusRows_.push_back({"Architecture", snapshot.architecture});
    statusRows_.push_back({"UUID", snapshot.imageUuid});
    statusRows_.push_back({"Segments", snapshot.segmentSizes});
    statusRows_.push_back({"Text fingerprint", snapshot.textFingerprint});
    statusRows_.push_back({"Identity reason", snapshot.identityReason});
    statusRows_.push_back({"Scans started", std::to_string(snapshot.scansStarted)});
    statusRows_.push_back({"Hooks", std::to_string(snapshot.hooks)});
    statusRows_.push_back({"Engine calls", std::to_string(snapshot.engineCalls)});
    statusRows_.push_back({"Mutation", std::to_string(snapshot.mutation)});
    statusRows_.push_back({"Detail", snapshot.detail});
    if (!snapshot.contracts.has_value()) {
        contractRows_.push_back({"Capture", "not started"});
        contractRows_.push_back({"Scans started", std::to_string(snapshot.scansStarted)});
        return;
    }
    const ReadOnlyContractReport& report = *snapshot.contracts;
    contractRows_.push_back({"Capture", report.captureState});
    contractRows_.push_back({"Profile roots", report.profileRootState});
    contractRows_.push_back({"Generation", std::to_string(report.discoveryGeneration)});
    contractRows_.push_back({"Previous invalidated",
                             report.previousGenerationInvalidated ? "yes" : "not applicable"});
    contractRows_.push_back({"FName blocks / entries",
                             std::to_string(report.fNameBlocks) + " / "
                                 + std::to_string(report.fNameEntries)});
    contractRows_.push_back({"Objects num / max",
                             std::to_string(report.objectNum) + " / "
                                 + std::to_string(report.objectMax)});
    contractRows_.push_back({"Chunks num / max",
                             std::to_string(report.objectNumChunks) + " / "
                                 + std::to_string(report.objectMaxChunks)});
    contractRows_.push_back({"Valid / null / malformed",
                             std::to_string(report.validObjects) + " / "
                                 + std::to_string(report.nullObjects) + " / "
                                 + std::to_string(report.malformedObjects)});
    contractRows_.push_back({"Pending / unreachable",
                             std::to_string(report.pendingKillObjects) + " / "
                                 + std::to_string(report.unreachableObjects)});
    contractRows_.push_back({"Copied bytes / duration ms",
                             std::to_string(report.copiedBytes) + " / "
                                 + std::to_string(report.durationMilliseconds)});
    contractRows_.push_back({"Retry / abort", report.retryOrAbortReason});
    for (const ContractCheck& check : report.knownNames)
        contractRows_.push_back({"FName " + check.label, check.state + ": " + check.detail});
    for (const ContractCheck& check : report.knownObjects)
        contractRows_.push_back({check.label, check.state + ": " + check.detail});
    for (const ContractCheck& check : report.reflectionChecks)
        contractRows_.push_back({"Reflection " + check.label,
                                 check.state + ": " + check.detail});
    contractRows_.push_back({"Capabilities", "hooks=0 engine_calls=0 mutation=0"});
}

bool DiagnosticPresentationModel::ShowsFloatingButton() const noexcept {
    return true;
}

bool DiagnosticPresentationModel::HasRuntimeCapabilityControls() const noexcept {
    return false;
}

std::array<std::string_view, 3> DiagnosticPresentationModel::Tabs() const noexcept {
    return {"Status", "Contracts", "Logs"};
}

const std::vector<DiagnosticStatusRow>& DiagnosticPresentationModel::ContractRows() const noexcept {
    return contractRows_;
}

const std::vector<DiagnosticStatusRow>& DiagnosticPresentationModel::StatusRows() const noexcept {
    return statusRows_;
}

const diagnostics::LogSnapshot& DiagnosticPresentationModel::Logs() const noexcept {
    return logs_;
}

std::string DiagnosticPresentationModel::CopyableLogs() const {
    std::string text;
    for (const diagnostics::LogEntry& entry : logs_.entries) {
        text += diagnostics::FormatLogEntry(entry);
        text.push_back('\n');
    }
    if (logs_.dropped != 0) {
        text += "dropped=" + std::to_string(logs_.dropped) + '\n';
    }
    return text;
}

std::string DiagnosticPresentationModel::CopyableContractsAndLogs() const {
    std::string text = "Gate 2B read-only contracts\n";
    for (const DiagnosticStatusRow& row : contractRows_)
        text += row.label + "=" + row.value + "\n";
    text += "\nBounded logs\n";
    text += CopyableLogs();
    return text;
}

}  // namespace serverhost::v2::ui
