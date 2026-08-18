#include "SourceV2/Bindings/Validation/ProfileValidator.hpp"

namespace serverhost::v2::bindings {
namespace {

bool SegmentIdentityMatches(
    const std::vector<ImageSegmentIdentity>& actual,
    const std::vector<ImageSegmentIdentity>& expected) {
    if (actual.size() != expected.size())
        return false;
    for (std::size_t index = 0; index < actual.size(); ++index) {
        if (actual[index].name != expected[index].name
            || actual[index].initialPermissions != expected[index].initialPermissions) {
            return false;
        }
        // __LINKEDIT contains the code signature rewritten by Sideloadly/codesign.
        // Its presence and permissions are identity-bearing; its sizes are not.
        if (actual[index].name != "__LINKEDIT"
            && (actual[index].virtualSize != expected[index].virtualSize
                || actual[index].fileSize != expected[index].fileSize)) {
            return false;
        }
    }
    return true;
}

}  // namespace

ContractResult<void> StrictRuntimeProfileValidator::Validate(
    const BuildIdentity& identity, const BuildProfile& profile) const {
    if (identity.platform != profile.platform || identity.product != profile.product
        || identity.version != profile.version || identity.architecture != profile.expectedArchitecture
        || identity.role != profile.expectedRole) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::UnsupportedProfile,
            "platform, product, version, architecture, or image role does not match");
    }
    if (!profile.identityEvidenceComplete || !profile.expectedImageUuid.has_value()
        || !profile.expectedTextFingerprint.has_value()
        || profile.expectedTextFingerprintRange.empty()
        || profile.expectedTextFingerprintSize == 0 || profile.expectedSegments.empty()
        || profile.expectedStableImagePrefixSize == 0) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MissingEvidence, "profile lacks approved image identity evidence");
    }
    if (!identity.imageUuid.has_value() || !identity.textFingerprint.has_value()
        || identity.textFingerprintRange.empty() || identity.textFingerprintSize == 0
        || identity.segments.empty() || identity.stableImagePrefixSize == 0) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MissingEvidence, "runtime identity is incomplete");
    }
    if (identity.imageUuid != profile.expectedImageUuid
        || identity.textFingerprint != profile.expectedTextFingerprint
        || identity.textFingerprintRange != profile.expectedTextFingerprintRange
        || identity.textFingerprintSize != profile.expectedTextFingerprintSize
        || !SegmentIdentityMatches(identity.segments, profile.expectedSegments)
        || identity.stableImagePrefixSize != profile.expectedStableImagePrefixSize) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::UnsupportedProfile, "loaded image identity does not match the profile");
    }
    return ContractResult<void>::Success();
}

}  // namespace serverhost::v2::bindings
