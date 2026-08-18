#include "SourceV2/Bootstrap/InertInitialization.hpp"

namespace serverhost::v2::bootstrap {

InertInitializationReport InitializeInert(
    const BuildIdentity& identity, std::span<const bindings::BuildProfile> profiles,
    const bindings::IRuntimeProfileValidator& validator) {
    InertInitializationReport report{};
    bool foundCandidateWithMissingEvidence = false;

    for (const auto& profile : profiles) {
        const auto result = validator.Validate(identity, profile);
        if (result) {
            report.state = InertInitializationState::ProfileValidated;
            report.profileId = profile.profileId;
            report.detail = "profile identity validated; runtime capabilities remain inert";
            return report;
        }
        if (identity.platform == profile.platform && identity.product == profile.product
            && identity.version == profile.version
            && result.Error().category == ContractErrorCategory::MissingEvidence) {
            foundCandidateWithMissingEvidence = true;
            report.profileId = profile.profileId;
            report.detail = result.Error().context;
        }
    }

    if (foundCandidateWithMissingEvidence) {
        report.state = InertInitializationState::MissingIdentityEvidence;
    } else {
        report.state = InertInitializationState::UnsupportedBuild;
        report.detail = "no exact validated build profile matched";
    }
    return report;
}

}  // namespace serverhost::v2::bootstrap
