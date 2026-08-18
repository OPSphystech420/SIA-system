#pragma once

#include "SourceV2/Core/ContractResult.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <span>

namespace serverhost::v2::bindings::platform {

class IMemorySource {
public:
    virtual ~IMemorySource() = default;
    [[nodiscard]] virtual ContractResult<void> Copy(
        std::uintptr_t address, std::span<std::byte> destination) const = 0;
};

class ProcessMemorySource final : public IMemorySource {
public:
    [[nodiscard]] ContractResult<void> Copy(
        std::uintptr_t address, std::span<std::byte> destination) const override;
};

[[nodiscard]] std::shared_ptr<const IMemorySource> MakeProcessMemorySource();

}  // namespace serverhost::v2::bindings::platform
