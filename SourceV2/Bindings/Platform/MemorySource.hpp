#pragma once

#include "SourceV2/Core/ContractResult.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <span>

namespace serverhost::v2::bindings::platform {

struct VirtualMemoryRegion final {
    std::uintptr_t base{};
    std::size_t size{};
    bool readable{};
};

class IVirtualMemoryAccess {
public:
    virtual ~IVirtualMemoryAccess() = default;
    [[nodiscard]] virtual ContractResult<VirtualMemoryRegion> QueryRegion(
        std::uintptr_t address) const = 0;
    [[nodiscard]] virtual ContractResult<void> CopyFromRegion(
        std::uintptr_t address, std::span<std::byte> destination) const = 0;
};

class IMemorySource {
public:
    virtual ~IMemorySource() = default;
    [[nodiscard]] virtual ContractResult<void> Copy(
        std::uintptr_t address, std::span<std::byte> destination) const = 0;
};

class ProcessMemorySource final : public IMemorySource {
public:
    ProcessMemorySource();
    explicit ProcessMemorySource(std::shared_ptr<const IVirtualMemoryAccess> access);

    [[nodiscard]] ContractResult<void> Copy(
        std::uintptr_t address, std::span<std::byte> destination) const override;

private:
    std::shared_ptr<const IVirtualMemoryAccess> access_;
};

[[nodiscard]] std::shared_ptr<const IMemorySource> MakeProcessMemorySource();

}  // namespace serverhost::v2::bindings::platform
