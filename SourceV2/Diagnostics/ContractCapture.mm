#include "SourceV2/Diagnostics/ContractCapture.hpp"

#include "SourceV2/Bindings/UE/ReadOnlySnapshotCapture.hpp"
#include "SourceV2/Diagnostics/ContractCaptureInternal.hpp"
#include "SourceV2/Diagnostics/DiagnosticSnapshot.hpp"
#include "SourceV2/Diagnostics/Logger.hpp"

#include <dispatch/dispatch.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <utility>

namespace serverhost::v2::diagnostics {
namespace {

class Coordinator final {
public:
    void Configure(
        bindings::platform::CheckedMemoryReader reader,
        bindings::profiles::ReadOnlyContractProfile profile) {
        std::lock_guard lock(mutex_);
        reader_ = std::move(reader);
        profile_ = std::move(profile);
    }

    ContractCaptureRequestState Request() {
        std::uint64_t generation{};
        {
            std::lock_guard lock(mutex_);
            if (!reader_.has_value() || !profile_.has_value())
                return ContractCaptureRequestState::Unavailable;
            if (busy_)
                return ContractCaptureRequestState::Busy;
            busy_ = true;
            cancellation_.store(false, std::memory_order_relaxed);
            generation = ++nextGeneration_;
            latest_.reset();
        }

        ReadOnlyContractReport running;
        running.captureState = "running";
        running.profileRootState = "exact-profile-rva-roots";
        running.discoveryGeneration = generation;
        running.scansStarted = 1;
        running.previousGenerationInvalidated = generation > 1;
        ProcessSnapshotPublisher().PublishContractReport(std::move(running));
        ProcessLogger().Add(
            LogSeverity::Info, LogCategory::Profile,
            "read-only contract capture requested generation="
                + std::to_string(generation)
                + " scans_started=1 hooks=0 engine_calls=0 mutation=0");

        dispatch_async(queue_, ^{
            Run(generation);
        });
        return ContractCaptureRequestState::Started;
    }

private:
    void Run(std::uint64_t generation) {
        std::optional<bindings::platform::CheckedMemoryReader> reader;
        std::optional<bindings::profiles::ReadOnlyContractProfile> profile;
        {
            std::lock_guard lock(mutex_);
            reader = reader_;
            profile = profile_;
        }
        bindings::ue::ReadOnlySnapshotCapture capture;
        auto result = capture.Capture(
            *reader, *profile, {generation}, {}, &cancellation_);
        if (result) {
            auto owned = std::make_shared<const bindings::ue::ReadOnlyContractSnapshot>(
                std::move(result.Value()));
            ReadOnlyContractReport report = owned->report;
            report.previousGenerationInvalidated = generation > 1;
            {
                std::lock_guard lock(mutex_);
                latest_ = std::move(owned);
                busy_ = false;
            }
            ProcessSnapshotPublisher().PublishContractReport(report);
            ProcessLogger().Add(
                LogSeverity::Info, LogCategory::Profile,
                "read-only contracts complete generation=" + std::to_string(generation)
                    + " copied_bytes=" + std::to_string(report.copiedBytes)
                    + " objects=" + std::to_string(report.objectNum)
                    + " scans_started=1 hooks=0 engine_calls=0 mutation=0");
            return;
        }

        ReadOnlyContractReport report;
        report.captureState = "aborted";
        report.profileRootState = "exact-profile-rva-roots";
        report.retryOrAbortReason = result.Error().context;
        report.discoveryGeneration = generation;
        report.scansStarted = 1;
        report.previousGenerationInvalidated = generation > 1;
        {
            std::lock_guard lock(mutex_);
            busy_ = false;
        }
        ProcessSnapshotPublisher().PublishContractReport(report);
        ProcessLogger().Add(
            LogSeverity::Error, LogCategory::Profile,
            "read-only contracts aborted generation=" + std::to_string(generation)
                + " reason=" + result.Error().context
                + " scans_started=1 hooks=0 engine_calls=0 mutation=0");
    }

    std::mutex mutex_;
    std::optional<bindings::platform::CheckedMemoryReader> reader_;
    std::optional<bindings::profiles::ReadOnlyContractProfile> profile_;
    std::shared_ptr<const bindings::ue::ReadOnlyContractSnapshot> latest_;
    std::atomic_bool cancellation_{false};
    std::uint64_t nextGeneration_{};
    bool busy_{};
    dispatch_queue_t queue_{dispatch_queue_create(
        "com.mhga.serverhost.v2.contract-capture", DISPATCH_QUEUE_SERIAL)};
};

Coordinator& ProcessCoordinator() {
    static Coordinator coordinator;
    return coordinator;
}

}  // namespace

void ConfigureReadOnlyContractCapture(
    bindings::platform::CheckedMemoryReader reader,
    bindings::profiles::ReadOnlyContractProfile profile) {
    ProcessCoordinator().Configure(std::move(reader), std::move(profile));
}

ContractCaptureRequestState RequestReadOnlyContractCapture() {
    return ProcessCoordinator().Request();
}

}  // namespace serverhost::v2::diagnostics
