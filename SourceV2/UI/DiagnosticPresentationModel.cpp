#include "SourceV2/UI/DiagnosticPresentationModel.hpp"

#include <utility>

namespace serverhost::v2::ui {

DiagnosticPresentationModel::DiagnosticPresentationModel(
    const diagnostics::DiagnosticSnapshot& snapshot)
    : snapshot_(snapshot) {
    statusRows_.reserve(9);
    statusRows_.push_back({"Build ID", snapshot.buildId});
    statusRows_.push_back({"Source revision", snapshot.sourceRevision});
    statusRows_.push_back({"Startup", snapshot.startupState});
    statusRows_.push_back({"Profile", snapshot.profileState});
    statusRows_.push_back({"Legacy guard", snapshot.legacyGuardState});
    statusRows_.push_back({"Hooks", std::to_string(snapshot.hooks)});
    statusRows_.push_back({"Engine calls", std::to_string(snapshot.engineCalls)});
    statusRows_.push_back({"Mutation", std::to_string(snapshot.mutation)});
    statusRows_.push_back({"Detail", snapshot.detail});
}

bool DiagnosticPresentationModel::ShowsFloatingButton() const noexcept {
    return true;
}

bool DiagnosticPresentationModel::HasRuntimeCapabilityControls() const noexcept {
    return false;
}

std::array<std::string_view, 2> DiagnosticPresentationModel::Tabs() const noexcept {
    return {"Status", "Logs"};
}

const std::vector<DiagnosticStatusRow>& DiagnosticPresentationModel::StatusRows() const noexcept {
    return statusRows_;
}

const diagnostics::LogSnapshot& DiagnosticPresentationModel::Logs() const noexcept {
    return snapshot_.logs;
}

std::string DiagnosticPresentationModel::CopyableLogs() const {
    std::string text;
    for (const diagnostics::LogEntry& entry : snapshot_.logs.entries) {
        text += diagnostics::FormatLogEntry(entry);
        text.push_back('\n');
    }
    if (snapshot_.logs.dropped != 0) {
        text += "dropped=" + std::to_string(snapshot_.logs.dropped) + '\n';
    }
    return text;
}

}  // namespace serverhost::v2::ui
