#include "SourceV2/Diagnostics/ContractCapture.hpp"

#include "SourceV2/Bindings/UE/ReadOnlySnapshotCapture.hpp"
#include "SourceV2/Bindings/UE/WorldRelationshipCapture.hpp"
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

struct Gate2COwnedSnapshot final {
    bindings::ue::ReadOnlyContractSnapshot discovery;
    model::engine::WorldRelationshipSnapshot relationships;
};

class Coordinator final {
public:
    void Configure(
        bindings::platform::CheckedMemoryReader reader,
        bindings::profiles::ReadOnlyContractProfile profile,
        bindings::profiles::LiveRelationshipProfile relationshipProfile) {
        std::lock_guard lock(mutex_);
        reader_ = std::move(reader);
        profile_ = std::move(profile);
        relationshipProfile_ = std::move(relationshipProfile);
    }

    ContractCaptureRequestState Request() {
        std::uint64_t generation{};
        {
            std::lock_guard lock(mutex_);
            if (!reader_.has_value() || !profile_.has_value()
                || !relationshipProfile_.has_value())
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
        running.relationshipCaptureState = "waiting-for-fresh-gate2b-snapshot";
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
        std::optional<bindings::profiles::LiveRelationshipProfile> relationshipProfile;
        {
            std::lock_guard lock(mutex_);
            reader = reader_;
            profile = profile_;
            relationshipProfile = relationshipProfile_;
        }
        bindings::ue::ReadOnlySnapshotCapture capture;
        auto result = capture.Capture(
            *reader, *profile, {generation}, {}, &cancellation_);
        if (result) {
            bindings::ue::ReadOnlyContractSnapshot discovery = std::move(result.Value());
            bindings::ue::WorldRelationshipCapture relationshipCapture;
            auto relationships = relationshipCapture.Capture(
                *reader, *relationshipProfile, discovery, worldGenerationTracker_, {},
                &cancellation_);
            if (!relationships) {
                ReadOnlyContractReport report = discovery.report;
                report.captureState = "aborted";
                report.relationshipCaptureState = "aborted";
                report.retryOrAbortReason = relationships.Error().context;
                report.previousGenerationInvalidated = generation > 1;
                {
                    std::lock_guard lock(mutex_);
                    busy_ = false;
                }
                ProcessSnapshotPublisher().PublishContractReport(report);
                ProcessLogger().Add(
                    LogSeverity::Error, LogCategory::Profile,
                    "live relationships aborted generation=" + std::to_string(generation)
                        + " reason=" + relationships.Error().context
                        + " scans_started=1 hooks=0 engine_calls=0 mutation=0");
                return;
            }
            auto relationshipResult = std::move(relationships.Value());
            ReadOnlyContractReport report = discovery.report;
            report.relationshipCaptureState = "complete";
            report.lifecycleState = relationshipResult.snapshot.lifecycleState;
            report.worldRelationshipState =
                relationshipResult.snapshot.worldRelationshipState;
            report.netDriverState = relationshipResult.snapshot.netDriver.has_value()
                ? "present" : "none";
            report.worldGeneration = relationshipResult.snapshot.worldGeneration;
            report.previousWorldInvalidated =
                relationshipResult.snapshot.previousWorldInvalidated;
            report.relationshipCopiedBytes = relationshipResult.copiedBytes;
            report.relationshipDurationMilliseconds =
                relationshipResult.durationMilliseconds;
            report.copiedBytes += relationshipResult.copiedBytes;
            report.durationMilliseconds += relationshipResult.durationMilliseconds;
            report.engineChecks = std::move(relationshipResult.engineChecks);
            report.gameViewportChecks = std::move(
                relationshipResult.gameViewportChecks);
            report.worldChecks = std::move(relationshipResult.worldChecks);
            report.netDriverChecks = std::move(relationshipResult.netDriverChecks);
            report.netDriverDefinitionChecks = std::move(
                relationshipResult.netDriverDefinitionChecks);
            report.generationChecks = std::move(relationshipResult.generationChecks);
            for (const auto& definition
                 : relationshipResult.snapshot.netDriverDefinitions.definitions) {
                report.netDriverDefinitions.push_back({
                    definition.defName, definition.driverClassName,
                    definition.driverClassNameFallback});
            }
            auto owned = std::make_shared<const Gate2COwnedSnapshot>(Gate2COwnedSnapshot{
                std::move(discovery), std::move(relationshipResult.snapshot)});
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
                    + " world_generation=" + std::to_string(report.worldGeneration)
                    + " previous_world_invalidated="
                    + (report.previousWorldInvalidated ? "yes" : "no")
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
    std::optional<bindings::profiles::LiveRelationshipProfile> relationshipProfile_;
    std::shared_ptr<const Gate2COwnedSnapshot> latest_;
    model::engine::WorldGenerationTracker worldGenerationTracker_;
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
    bindings::profiles::ReadOnlyContractProfile profile,
    bindings::profiles::LiveRelationshipProfile relationshipProfile) {
    ProcessCoordinator().Configure(
        std::move(reader), std::move(profile), std::move(relationshipProfile));
}

ContractCaptureRequestState RequestReadOnlyContractCapture() {
    return ProcessCoordinator().Request();
}

}  // namespace serverhost::v2::diagnostics
