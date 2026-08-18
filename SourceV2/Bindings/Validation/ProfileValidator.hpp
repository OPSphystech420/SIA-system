#pragma once

#include "SourceV2/Bindings/Profiles/BuildProfile.hpp"
#include "SourceV2/Core/ContractResult.hpp"

namespace serverhost::v2::bindings {

class IRuntimeProfileValidator {
public:
    virtual ~IRuntimeProfileValidator() = default;
    [[nodiscard]] virtual ContractResult<void> Validate(
        const BuildIdentity& identity, const BuildProfile& profile) const = 0;
};

class StrictRuntimeProfileValidator final : public IRuntimeProfileValidator {
public:
    [[nodiscard]] ContractResult<void> Validate(
        const BuildIdentity& identity, const BuildProfile& profile) const override;
};

}  // namespace serverhost::v2::bindings
