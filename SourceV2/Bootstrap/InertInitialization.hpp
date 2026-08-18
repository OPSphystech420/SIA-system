#pragma once

#include "SourceV2/Bindings/Profiles/BuildProfile.hpp"
#include "SourceV2/Bindings/Validation/ProfileValidator.hpp"
#include "SourceV2/Core/BuildIdentity.hpp"

#include <span>
#include <string>

namespace serverhost::v2::bootstrap {

enum class InertInitializationState {
    ProfileValidated,
    MissingIdentityEvidence,
    UnsupportedBuild,
};

struct InertInitializationReport final {
    InertInitializationState state{InertInitializationState::UnsupportedBuild};
    std::string profileId;
    std::string detail;
    bool hooksInstalled{};
    bool engineCallsEnabled{};
    bool mutationEnabled{};
};

[[nodiscard]] InertInitializationReport InitializeInert(
    const BuildIdentity& identity, std::span<const bindings::BuildProfile> profiles,
    const bindings::IRuntimeProfileValidator& validator);

}  // namespace serverhost::v2::bootstrap
