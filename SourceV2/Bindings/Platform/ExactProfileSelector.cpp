#include "SourceV2/Bindings/Platform/ExactProfileSelector.hpp"

#include "SourceV2/Bindings/Validation/ProfileValidator.hpp"

#include <utility>
#include <vector>

namespace serverhost::v2::bindings::platform {
namespace {

bool StableSegmentsMatch(
    const std::vector<ImageSegmentIdentity>& actual,
    const std::vector<ImageSegmentIdentity>& expected) {
    if (actual.size() != expected.size())
        return false;
    for (std::size_t index = 0; index < actual.size(); ++index) {
        if (actual[index].name != expected[index].name
            || actual[index].initialPermissions != expected[index].initialPermissions)
            return false;
        if (actual[index].name != "__LINKEDIT"
            && (actual[index].virtualSize != expected[index].virtualSize
                || actual[index].fileSize != expected[index].fileSize))
            return false;
    }
    return true;
}

std::string IdentityMismatchReason(
    const BuildIdentity& identity, const bindings::BuildProfile& profile) {
    if (identity.architecture != profile.expectedArchitecture)
        return "architecture mismatch";
    if (identity.role != profile.expectedRole)
        return "Mach-O image-role mismatch";
    if (identity.imageUuid != profile.expectedImageUuid)
        return "LC_UUID mismatch";
    if (!StableSegmentsMatch(identity.segments, profile.expectedSegments))
        return "segment set, size, or permission mismatch";
    if (identity.textFingerprintRange != profile.expectedTextFingerprintRange
        || identity.textFingerprintSize != profile.expectedTextFingerprintSize)
        return "executable fingerprint range mismatch";
    if (identity.textFingerprint != profile.expectedTextFingerprint)
        return "__text fingerprint mismatch";
    if (identity.stableImagePrefixSize != profile.expectedStableImagePrefixSize)
        return "stable pre-__LINKEDIT file-span mismatch";
    return "profile identity mismatch";
}

IdentityReceipt ReceiptFor(
    const ResolvedImageIdentity& resolved, const bindings::BuildProfile& profile,
    ProfileMatchState state, std::string reason) {
    return {
        .selectedImage = resolved.imageName,
        .product = resolved.identity.product,
        .architecture = ImageArchitectureName(resolved.identity.architecture),
        .uuid = resolved.identity.imageUuid.has_value()
            ? FormatUuid(*resolved.identity.imageUuid)
            : "missing",
        .segmentSizes = FormatSegmentSizes(resolved.identity.segments),
        .shortenedTextFingerprint = resolved.identity.textFingerprint.has_value()
            ? ShortenFingerprint(*resolved.identity.textFingerprint)
            : "missing",
        .profileId = profile.profileId,
        .profileMatchState = ProfileMatchStateName(state),
        .reason = std::move(reason),
    };
}

}  // namespace

ExactProfileMatch::ExactProfileMatch(ResolvedImageIdentity image, std::string profileId)
    : image_(std::move(image)), profileId_(std::move(profileId)), uniqueExactMatch_(true) {}

const ResolvedImageIdentity& ExactProfileMatch::Image() const noexcept { return image_; }
const std::string& ExactProfileMatch::ProfileId() const noexcept { return profileId_; }

ExactProfileSelection ExactProfileSelector::Select(
    const LoadedImageCatalog& catalog, std::span<const bindings::BuildProfile> profiles,
    const IMemorySource& memory) const {
    ExactProfileSelection outcome;
    outcome.receipt.profileMatchState = ProfileMatchStateName(outcome.state);
    outcome.receipt.reason = "identity inspection did not complete";
    if (profiles.empty()) {
        outcome.receipt.reason = "no exact profiles are configured";
        return outcome;
    }

    struct CandidateMatch final {
        ResolvedImageIdentity resolved;
        const bindings::BuildProfile* profile{};
    };
    std::vector<CandidateMatch> matches;
    bool foundExactProductName = false;
    bool foundMainRoleCandidate = false;
    std::optional<IdentityReceipt> lastMismatch;
    const ImageIdentityResolver resolver;
    const bindings::StrictRuntimeProfileValidator validator;

    for (const LoadedImageRecord& image : catalog.Images()) {
        for (const bindings::BuildProfile& profile : profiles) {
            if (image.imageName != profile.product)
                continue;
            foundExactProductName = true;
            const auto parsed = MachOImageView::Parse(image.headerAndLoadCommands, image.slide);
            if (!parsed) {
                outcome.state = ProfileMatchState::InspectionFailed;
                outcome.receipt.selectedImage = image.imageName;
                outcome.receipt.product = profile.product;
                outcome.receipt.profileId = profile.profileId;
                outcome.receipt.profileMatchState = ProfileMatchStateName(outcome.state);
                outcome.receipt.reason = parsed.Error().context;
                return outcome;
            }
            if (!image.isDyldMainExecutable
                || parsed.Value().Role() != ImageRole::MainExecutable) {
                lastMismatch = IdentityReceipt{
                    .selectedImage = image.imageName,
                    .product = profile.product,
                    .architecture = ImageArchitectureName(parsed.Value().Architecture()),
                    .uuid = FormatUuid(parsed.Value().Uuid()),
                    .profileId = profile.profileId,
                    .profileMatchState = ProfileMatchStateName(ProfileMatchState::Mismatch),
                    .reason = "candidate is not jointly dyld-main and MH_EXECUTE",
                };
                continue;
            }
            foundMainRoleCandidate = true;
            const auto resolved = resolver.Resolve(image, memory, profile.version);
            if (!resolved) {
                outcome.state = ProfileMatchState::InspectionFailed;
                outcome.receipt.selectedImage = image.imageName;
                outcome.receipt.product = profile.product;
                outcome.receipt.profileId = profile.profileId;
                outcome.receipt.profileMatchState = ProfileMatchStateName(outcome.state);
                outcome.receipt.reason = resolved.Error().context;
                return outcome;
            }
            const auto validation = validator.Validate(resolved.Value().identity, profile);
            if (validation) {
                matches.push_back({resolved.Value(), &profile});
            } else {
                lastMismatch = ReceiptFor(
                    resolved.Value(), profile, ProfileMatchState::Mismatch,
                    IdentityMismatchReason(resolved.Value().identity, profile));
            }
        }
    }

    if (matches.size() > 1) {
        outcome.state = ProfileMatchState::Ambiguous;
        outcome.receipt = ReceiptFor(
            matches.front().resolved, *matches.front().profile, outcome.state,
            "more than one loaded image/profile pair matched exactly");
        return outcome;
    }
    if (matches.size() == 1) {
        CandidateMatch& selected = matches.front();
        outcome.state = ProfileMatchState::ExactMatch;
        outcome.receipt = ReceiptFor(
            selected.resolved, *selected.profile, outcome.state,
            "unique exact image/profile match; explicit bounded capture is available");
        outcome.match = ExactProfileMatch(
            std::move(selected.resolved), selected.profile->profileId);
        return outcome;
    }

    outcome.state = ProfileMatchState::Mismatch;
    if (lastMismatch.has_value()) {
        outcome.receipt = std::move(*lastMismatch);
    } else {
        outcome.receipt.profileMatchState = ProfileMatchStateName(outcome.state);
        outcome.receipt.reason = !foundExactProductName
            ? "no exact product/image-name candidate"
            : !foundMainRoleCandidate
                ? "no candidate satisfied dyld-main plus MH_EXECUTE"
                : "no exact image/profile pair matched";
    }
    return outcome;
}

const char* ProfileMatchStateName(ProfileMatchState state) noexcept {
    switch (state) {
        case ProfileMatchState::ExactMatch: return "exact-match";
        case ProfileMatchState::Mismatch: return "mismatch";
        case ProfileMatchState::Ambiguous: return "ambiguous";
        case ProfileMatchState::InspectionFailed: return "inspection-failed";
    }
    return "inspection-failed";
}

}  // namespace serverhost::v2::bindings::platform
