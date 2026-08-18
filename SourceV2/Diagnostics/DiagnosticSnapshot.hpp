#pragma once

#include "SourceV2/Diagnostics/Logger.hpp"

#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

namespace serverhost::v2::diagnostics {

struct DiagnosticState final {
    std::string buildId;
    std::string sourceRevision;
    std::string startupState;
    std::string profileState;
    std::string legacyGuardState;
    std::string detail;
};

struct DiagnosticSnapshot final {
    std::string buildId;
    std::string sourceRevision;
    std::string startupState;
    std::string profileState;
    std::string legacyGuardState;
    std::string detail;
    std::uint32_t hooks{};
    std::uint32_t engineCalls{};
    std::uint32_t mutation{};
    LogSnapshot logs;
};

class DiagnosticSnapshotPublisher final {
public:
    explicit DiagnosticSnapshotPublisher(Logger& logger);

    void Publish(DiagnosticState state);
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
