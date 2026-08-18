#pragma once

#include "SourceV2/Bindings/Platform/ImageIdentityResolver.hpp"
#include "SourceV2/Bindings/Profiles/BuildProfile.hpp"

#include <optional>
#include <span>
#include <string>

namespace serverhost::v2::bindings::platform {

enum class ProfileMatchState {
    ExactMatch,
    Mismatch,
    Ambiguous,
    InspectionFailed,
};

struct IdentityReceipt final {
    std::string selectedImage;
    std::string product;
    std::string architecture;
    std::string uuid;
    std::string segmentSizes;
    std::string shortenedTextFingerprint;
    std::string profileId;
    std::string profileMatchState;
    std::string reason;
    std::uint32_t scansStarted{};
    std::uint32_t hooks{};
    std::uint32_t engineCalls{};
    std::uint32_t mutation{};
};

class CheckedMemoryReader;

class ExactProfileMatch final {
public:
    [[nodiscard]] const ResolvedImageIdentity& Image() const noexcept;
    [[nodiscard]] const std::string& ProfileId() const noexcept;

private:
    ExactProfileMatch(ResolvedImageIdentity image, std::string profileId);

    ResolvedImageIdentity image_;
    std::string profileId_;
    bool uniqueExactMatch_{};

    friend class ExactProfileSelector;
    friend class CheckedMemoryReader;
};

struct ExactProfileSelection final {
    ProfileMatchState state{ProfileMatchState::InspectionFailed};
    IdentityReceipt receipt;
    std::optional<ExactProfileMatch> match;
};

class ExactProfileSelector final {
public:
    [[nodiscard]] ExactProfileSelection Select(
        const LoadedImageCatalog& catalog, std::span<const bindings::BuildProfile> profiles,
        const IMemorySource& memory) const;
};

[[nodiscard]] const char* ProfileMatchStateName(ProfileMatchState state) noexcept;

}  // namespace serverhost::v2::bindings::platform
