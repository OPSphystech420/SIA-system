#pragma once

#include "SourceV2/Diagnostics/DiagnosticSnapshot.hpp"

#include <array>
#include <string>
#include <string_view>
#include <vector>

namespace serverhost::v2::ui {

struct DiagnosticStatusRow final {
    std::string label;
    std::string value;
};

class DiagnosticPresentationModel final {
public:
    explicit DiagnosticPresentationModel(const diagnostics::DiagnosticSnapshot& snapshot);

    [[nodiscard]] bool ShowsFloatingButton() const noexcept;
    [[nodiscard]] bool HasRuntimeCapabilityControls() const noexcept;
    [[nodiscard]] std::array<std::string_view, 2> Tabs() const noexcept;
    [[nodiscard]] const std::vector<DiagnosticStatusRow>& StatusRows() const noexcept;
    [[nodiscard]] const diagnostics::LogSnapshot& Logs() const noexcept;
    [[nodiscard]] std::string CopyableLogs() const;

private:
    const diagnostics::DiagnosticSnapshot& snapshot_;
    std::vector<DiagnosticStatusRow> statusRows_;
};

}  // namespace serverhost::v2::ui
