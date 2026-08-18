#include "SourceV2/Bindings/Validation/ProfileValidator.hpp"

namespace serverhost::v2::bindings {

ContractResult<void> StrictRuntimeProfileValidator::Validate(
    const BuildIdentity& identity, const BuildProfile& profile) const {
    if (identity.platform != profile.platform || identity.product != profile.product
        || identity.version != profile.version) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::UnsupportedProfile, "platform, product, or version does not match");
    }
    if (!profile.identityEvidenceComplete || !profile.expectedImageUuid.has_value()
        || !profile.expectedTextFingerprint.has_value() || profile.expectedImageSize == 0) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MissingEvidence, "profile lacks approved image identity evidence");
    }
    if (!identity.imageUuid.has_value() || !identity.textFingerprint.has_value()
        || identity.imageSize == 0) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MissingEvidence, "runtime identity is incomplete");
    }
    if (identity.imageUuid != profile.expectedImageUuid
        || identity.textFingerprint != profile.expectedTextFingerprint
        || identity.imageSize != profile.expectedImageSize) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::UnsupportedProfile, "loaded image identity does not match the profile");
    }
    return ContractResult<void>::Success();
}

}  // namespace serverhost::v2::bindings
