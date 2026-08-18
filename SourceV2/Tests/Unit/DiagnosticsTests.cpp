#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/Diagnostics/DiagnosticSnapshot.hpp"
#include "SourceV2/Diagnostics/Logger.hpp"
#include "SourceV2/UI/DiagnosticPresentationModel.hpp"

#include <algorithm>
#include <string>
#include <thread>
#include <vector>

namespace serverhost::v2::tests {
namespace {

bool ContainsStatusValue(const ui::DiagnosticPresentationModel& model,
                         std::string_view expected) {
    return std::any_of(model.StatusRows().begin(), model.StatusRows().end(),
        [expected](const ui::DiagnosticStatusRow& row) {
            return row.value.find(expected) != std::string::npos;
        });
}

bool ContainsContractLabel(
    const ui::DiagnosticPresentationModel& model, std::string_view expected) {
    return std::any_of(model.ContractRows().begin(), model.ContractRows().end(),
        [expected](const ui::DiagnosticStatusRow& row) {
            return row.label == expected;
        });
}

bool ContainsContractRow(const ui::DiagnosticPresentationModel& model,
                         std::string_view label, std::string_view value) {
    return std::any_of(model.ContractRows().begin(), model.ContractRows().end(),
        [label, value](const ui::DiagnosticStatusRow& row) {
            return row.label == label && row.value == value;
        });
}

}  // namespace

void RunDiagnosticsTests(TestContext& context) {
    using diagnostics::LogCategory;
    using diagnostics::LogSeverity;

    diagnostics::Logger boundedLogger(3, 64);
    boundedLogger.Add(LogSeverity::Info, LogCategory::Startup, "one");
    boundedLogger.Add(LogSeverity::Warning, LogCategory::Profile, "two");
    boundedLogger.Add(LogSeverity::Error, LogCategory::LegacyGuard, "three");
    boundedLogger.Add(LogSeverity::Debug, LogCategory::UI,
                      "four with a deliberately long message that must stay bounded at the sink");
    const diagnostics::LogSnapshot bounded = boundedLogger.Snapshot();
    V2_EXPECT(context, bounded.capacity == 3);
    V2_EXPECT(context, bounded.entries.size() == 3);
    V2_EXPECT(context, bounded.dropped == 1);
    V2_EXPECT(context, bounded.entries.front().sequence == 2);
    V2_EXPECT(context, bounded.entries.back().sequence == 4);
    V2_EXPECT(context, bounded.entries.back().message.size() <= 64);

    const std::string redacted = diagnostics::RedactDiagnosticText(
        "password=hunter2 token=abc123 UDID:\"device-id\" "
        "authorization=Bearer auth-value, pointer=0x1234567890\nnext");
    V2_EXPECT(context, redacted.find("hunter2") == std::string::npos);
    V2_EXPECT(context, redacted.find("abc123") == std::string::npos);
    V2_EXPECT(context, redacted.find("device-id") == std::string::npos);
    V2_EXPECT(context, redacted.find("auth-value") == std::string::npos);
    V2_EXPECT(context, redacted.find("1234567890") == std::string::npos);
    V2_EXPECT(context, redacted.find("<redacted>") != std::string::npos);
    V2_EXPECT(context, redacted.find("<address>") != std::string::npos);
    V2_EXPECT(context, redacted.find('\n') == std::string::npos);

    diagnostics::Logger concurrentLogger(64, 96);
    std::vector<std::thread> producers;
    for (int producer = 0; producer < 4; ++producer) {
        producers.emplace_back([producer, &concurrentLogger]() {
            for (int entry = 0; entry < 8; ++entry) {
                concurrentLogger.Add(LogSeverity::Info, LogCategory::UI,
                    "producer=" + std::to_string(producer)
                        + " entry=" + std::to_string(entry));
            }
        });
    }
    for (std::thread& producer : producers)
        producer.join();
    const diagnostics::LogSnapshot concurrent = concurrentLogger.Snapshot();
    V2_EXPECT(context, concurrent.entries.size() == 32);
    V2_EXPECT(context, concurrent.dropped == 0);
    bool increasing = true;
    for (std::size_t index = 1; index < concurrent.entries.size(); ++index) {
        increasing = increasing
            && concurrent.entries[index - 1].sequence < concurrent.entries[index].sequence;
    }
    V2_EXPECT(context, increasing);

    diagnostics::Logger snapshotLogger(4, 128);
    snapshotLogger.Add(LogSeverity::Error, LogCategory::LegacyGuard,
                       "refused password=do-not-copy address=0xabcdef1234");
    diagnostics::DiagnosticSnapshotPublisher publisher(snapshotLogger);
    publisher.Publish({
        .buildId = "gate1.5-test",
        .sourceRevision = "revision-test",
        .startupState = "runtime-refused-diagnostics-available",
        .profileState = "not-evaluated",
        .legacyGuardState = "legacy-runtime-loaded",
        .selectedImage = "ShooterGame pointer=0x1234567890",
        .product = "ShooterGame",
        .architecture = "arm64",
        .imageUuid = "E52A980C-9C36-34C7-84B0-DD6E846328DC",
        .segmentSizes = "__TEXT vm=81379328B pointer=0x22222222",
        .textFingerprint = "8bfc1fd248a5...",
        .identityReason = "token=identity-secret mismatch",
        .detail = "refusal pointer=0x11111111 token=private-token",
    });
    const std::shared_ptr<const diagnostics::DiagnosticSnapshot> snapshot = publisher.Capture();
    V2_EXPECT(context, snapshot->hooks == 0);
    V2_EXPECT(context, snapshot->engineCalls == 0);
    V2_EXPECT(context, snapshot->mutation == 0);
    V2_EXPECT(context, snapshot->scansStarted == 0);
    V2_EXPECT(context, snapshot->logs.entries.size() == 1);
    V2_EXPECT(context, snapshot->detail.find("11111111") == std::string::npos);
    V2_EXPECT(context, snapshot->detail.find("private-token") == std::string::npos);
    V2_EXPECT(context, snapshot->selectedImage.find("1234567890") == std::string::npos);
    V2_EXPECT(context, snapshot->segmentSizes.find("22222222") == std::string::npos);
    V2_EXPECT(context, snapshot->identityReason.find("identity-secret") == std::string::npos);

    const ui::DiagnosticPresentationModel refusedModel(*snapshot);
    const auto tabs = refusedModel.Tabs();
    V2_EXPECT(context, refusedModel.ShowsFloatingButton());
    V2_EXPECT(context, !refusedModel.HasRuntimeCapabilityControls());
    V2_EXPECT(context, tabs[0] == "Status" && tabs[1] == "Contracts"
        && tabs[2] == "Logs");
    V2_EXPECT(context, ContainsStatusValue(refusedModel, "runtime-refused"));
    V2_EXPECT(context, ContainsStatusValue(refusedModel, "legacy-runtime-loaded"));
    V2_EXPECT(context, ContainsStatusValue(refusedModel, "E52A980C-9C36"));
    V2_EXPECT(context, ContainsStatusValue(refusedModel, "8bfc1fd248a5"));
    V2_EXPECT(context, refusedModel.CopyableLogs().find("do-not-copy") == std::string::npos);

    ReadOnlyContractReport unsafeReport;
    unsafeReport.captureState = "complete pointer=0x1234567890";
    unsafeReport.profileRootState = "token=private-root";
    unsafeReport.retryOrAbortReason = "address=0xabcdef1234";
    unsafeReport.relationshipCaptureState = "complete pointer=0x9999999999";
    unsafeReport.lifecycleState = "map token=private-lifecycle";
    unsafeReport.worldRelationshipState = "match address=0x8888888888";
    unsafeReport.netDriverState = "none token=private-driver";
    unsafeReport.authorityGameModeState =
        "present: GameModeBase class validated token=private-gamemode";
    unsafeReport.gameStateState =
        "present: GameStateBase class validated address=0x5555555555";
    unsafeReport.discoveryGeneration = 2;
    unsafeReport.scansStarted = 1;
    unsafeReport.hooks = 99;
    unsafeReport.engineCalls = 99;
    unsafeReport.mutation = 99;
    for (int index = 0; index < 30; ++index) {
        unsafeReport.knownNames.push_back({
            "name" + std::to_string(index), "pass",
            "pointer=0x1111111111 token=secret"});
        unsafeReport.engineChecks.push_back({
            "engine" + std::to_string(index), "pass",
            "pointer=0x7777777777 token=engine-secret"});
        unsafeReport.netDriverDefinitions.push_back({
            "definition" + std::to_string(index),
            "token=primary-secret", "address=0x6666666666"});
    }
    publisher.PublishContractReport(std::move(unsafeReport));
    const auto contractSnapshot = publisher.Capture();
    V2_EXPECT(context, contractSnapshot->scansStarted == 1);
    V2_EXPECT(context, contractSnapshot->contracts.has_value());
    V2_EXPECT(context, contractSnapshot->contracts->knownNames.size() <= 24);
    V2_EXPECT(context, contractSnapshot->contracts->engineChecks.size() <= 24);
    V2_EXPECT(context, contractSnapshot->contracts->netDriverDefinitions.size() <= 24);
    V2_EXPECT(context, contractSnapshot->contracts->hooks == 0);
    V2_EXPECT(context, contractSnapshot->contracts->engineCalls == 0);
    V2_EXPECT(context, contractSnapshot->contracts->mutation == 0);
    const ui::DiagnosticPresentationModel contractModel(*contractSnapshot);
    const std::string copiedContract = contractModel.CopyableContractsAndLogs();
    V2_EXPECT(context, copiedContract.find("1234567890") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("abcdef1234") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("private-root") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("9999999999") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("private-lifecycle") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("engine-secret") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("primary-secret") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("6666666666") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("private-gamemode") == std::string::npos);
    V2_EXPECT(context, copiedContract.find("5555555555") == std::string::npos);
    V2_EXPECT(context, copiedContract.size() < 20000);
    V2_EXPECT(context, ContainsContractLabel(contractModel, "Engine"));
    V2_EXPECT(context, ContainsContractLabel(contractModel, "GameViewport"));
    V2_EXPECT(context, ContainsContractLabel(contractModel, "World"));
    V2_EXPECT(context, ContainsContractLabel(contractModel, "  AuthorityGameMode"));
    V2_EXPECT(context, ContainsContractLabel(contractModel, "  GameState"));
    V2_EXPECT(context, ContainsContractLabel(contractModel, "NetDriver"));
    V2_EXPECT(context, ContainsContractLabel(contractModel, "NetDriverDefinitions"));
    V2_EXPECT(context, ContainsContractLabel(contractModel, "Generation"));

    ReadOnlyContractReport relationshipPresenceReport;
    relationshipPresenceReport.captureState = "complete";
    relationshipPresenceReport.relationshipCaptureState = "complete";
    relationshipPresenceReport.authorityGameModeState =
        "present: GameModeBase class validated";
    relationshipPresenceReport.gameStateState = "none";
    publisher.PublishContractReport(std::move(relationshipPresenceReport));
    const ui::DiagnosticPresentationModel relationshipPresenceModel(*publisher.Capture());
    V2_EXPECT(context, ContainsContractRow(
        relationshipPresenceModel, "  AuthorityGameMode",
        "present: GameModeBase class validated"));
    V2_EXPECT(context, ContainsContractRow(
        relationshipPresenceModel, "  GameState", "none"));

    snapshotLogger.Add(LogSeverity::Info, LogCategory::Profile, "later snapshot mutation");
    publisher.Publish({
        .buildId = "changed-build",
        .sourceRevision = "changed-revision",
        .startupState = "changed-state",
        .profileState = "changed-profile",
        .legacyGuardState = "changed-guard",
        .detail = "changed-detail",
    });
    V2_EXPECT(context, snapshot->buildId == "gate1.5-test");
    V2_EXPECT(context, snapshot->logs.entries.size() == 1);

    publisher.Publish({
        .buildId = "gate1.5-test",
        .sourceRevision = "revision-test",
        .startupState = "runtime-inert-diagnostics-available",
        .profileState = "missing-identity-evidence:ios-shootergame-1.10280",
        .legacyGuardState = "clear",
        .detail = "loaded image identity is intentionally unavailable before Gate 2",
    });
    const std::shared_ptr<const diagnostics::DiagnosticSnapshot> missingIdentity =
        publisher.Capture();
    const ui::DiagnosticPresentationModel missingIdentityModel(*missingIdentity);
    V2_EXPECT(context, missingIdentityModel.ShowsFloatingButton());
    V2_EXPECT(context, !missingIdentityModel.HasRuntimeCapabilityControls());
    V2_EXPECT(context, ContainsStatusValue(missingIdentityModel, "missing-identity-evidence"));

    publisher.Publish({
        .buildId = "gate1.5-test",
        .sourceRevision = "revision-test",
        .startupState = "runtime-inert-diagnostics-available",
        .profileState = "unsupported-build",
        .legacyGuardState = "clear",
        .detail = "no exact validated build profile matched",
    });
    const ui::DiagnosticPresentationModel unsupportedModel(*publisher.Capture());
    V2_EXPECT(context, unsupportedModel.ShowsFloatingButton());
    V2_EXPECT(context, !unsupportedModel.HasRuntimeCapabilityControls());
    V2_EXPECT(context, ContainsStatusValue(unsupportedModel, "unsupported-build"));
}

}  // namespace serverhost::v2::tests
