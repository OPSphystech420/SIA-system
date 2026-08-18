#pragma once

#include "SourceV2/Diagnostics/Logger.hpp"
#include "SourceV2/Core/ReadOnlyContractReport.hpp"

#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <string>

namespace serverhost::v2::diagnostics {

struct DiagnosticState final {
    std::string buildId;
    std::string sourceRevision;
    std::string startupState;
    std::string profileState;
    std::string legacyGuardState;
    std::string selectedImage;
    std::string product;
    std::string architecture;
    std::string imageUuid;
    std::string segmentSizes;
    std::string textFingerprint;
    std::string identityReason;
    std::string detail;
    std::uint32_t scansStarted{};
    std::optional<ReadOnlyContractReport> contracts;
};

struct DiagnosticSnapshot final {
    std::string buildId;
    std::string sourceRevision;
    std::string startupState;
    std::string profileState;
    std::string legacyGuardState;
    std::string selectedImage;
    std::string product;
    std::string architecture;
    std::string imageUuid;
    std::string segmentSizes;
    std::string textFingerprint;
    std::string identityReason;
    std::string detail;
    std::uint32_t scansStarted{};
    std::uint32_t hooks{};
    std::uint32_t engineCalls{};
    std::uint32_t mutation{};
    std::optional<ReadOnlyContractReport> contracts;
    LogSnapshot logs;
};

class DiagnosticSnapshotPublisher final {
public:
    explicit DiagnosticSnapshotPublisher(Logger& logger);

    void Publish(DiagnosticState state);
    void PublishContractReport(ReadOnlyContractReport report);
    [[nodiscard]] std::shared_ptr<const DiagnosticSnapshot> Capture() const;

private:
    Logger& logger_;
    mutable std::mutex mutex_;
    DiagnosticState state_;
};

Logger& ProcessLogger();
DiagnosticSnapshotPublisher& ProcessSnapshotPublisher();
[[nodiscard]] std::shared_ptr<const DiagnosticSnapshot> CaptureDiagnosticSnapshot();

}  // namespace serverhost::v2::diagnostics
