#include "SourceV2/Bindings/Platform/MemorySource.hpp"

#include <algorithm>
#include <limits>
#include <mach/mach.h>
#include <utility>

namespace serverhost::v2::bindings::platform {

namespace {

class MachVirtualMemoryAccess final : public IVirtualMemoryAccess {
public:
    ContractResult<VirtualMemoryRegion> QueryRegion(
        std::uintptr_t address) const override {
        vm_address_t regionAddress = static_cast<vm_address_t>(address);
        vm_size_t regionSize = 0;
        vm_region_basic_info_data_64_t info{};
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t objectName = MACH_PORT_NULL;
        const kern_return_t result = vm_region_64(
            mach_task_self(), &regionAddress, &regionSize, VM_REGION_BASIC_INFO_64,
            reinterpret_cast<vm_region_info_t>(&info), &count, &objectName);
        if (objectName != MACH_PORT_NULL)
            mach_port_deallocate(mach_task_self(), objectName);
        if (result != KERN_SUCCESS) {
            return ContractResult<VirtualMemoryRegion>::Failure(
                ContractErrorCategory::OutOfRange, "VM region query failed");
        }
        if (regionAddress > std::numeric_limits<std::uintptr_t>::max()
            || regionSize > std::numeric_limits<std::size_t>::max()) {
            return ContractResult<VirtualMemoryRegion>::Failure(
                ContractErrorCategory::OutOfRange, "VM region extent is not representable");
        }
        return ContractResult<VirtualMemoryRegion>::Success({
            static_cast<std::uintptr_t>(regionAddress),
            static_cast<std::size_t>(regionSize),
            (info.protection & VM_PROT_READ) != 0,
        });
    }

    ContractResult<void> CopyFromRegion(
        std::uintptr_t address, std::span<std::byte> destination) const override {
        vm_size_t copied = 0;
        const kern_return_t result = vm_read_overwrite(
            mach_task_self(), static_cast<vm_address_t>(address),
            static_cast<vm_size_t>(destination.size()),
            reinterpret_cast<vm_address_t>(destination.data()), &copied);
        if (result != KERN_SUCCESS || copied != destination.size()) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange,
                "bounded process-memory region copy failed");
        }
        return ContractResult<void>::Success();
    }
};

}  // namespace

ProcessMemorySource::ProcessMemorySource()
    : access_(std::make_shared<const MachVirtualMemoryAccess>()) {}

ProcessMemorySource::ProcessMemorySource(
    std::shared_ptr<const IVirtualMemoryAccess> access)
    : access_(std::move(access)) {}

ContractResult<void> ProcessMemorySource::Copy(
    std::uintptr_t address, std::span<std::byte> destination) const {
    if (destination.empty() || access_ == nullptr) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::InvalidArgument,
            "process-memory access and non-empty destination are required");
    }
    if (destination.size() > std::numeric_limits<std::uintptr_t>::max() - address) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::OutOfRange, "process-memory address plus size overflows");
    }

    std::uintptr_t cursor = address;
    std::size_t destinationOffset = 0;
    while (destinationOffset < destination.size()) {
        const auto queried = access_->QueryRegion(cursor);
        if (!queried)
            return ContractResult<void>::Failure(
                queried.Error().category, queried.Error().context);
        const VirtualMemoryRegion region = queried.Value();
        if (region.base > cursor) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange,
                "requested bytes encounter an unmapped VM gap");
        }
        if (region.size == 0
            || region.size > std::numeric_limits<std::uintptr_t>::max() - region.base) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange, "VM region extent is invalid");
        }
        const std::uintptr_t regionEnd = region.base + region.size;
        if (cursor >= regionEnd) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange,
                "VM region query made no forward progress");
        }
        if (!region.readable) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange,
                "requested bytes encounter a non-readable VM region");
        }
        const std::size_t remaining = destination.size() - destinationOffset;
        const std::size_t available = static_cast<std::size_t>(regionEnd - cursor);
        const std::size_t chunkSize = std::min(remaining, available);
        const auto copied = access_->CopyFromRegion(
            cursor, destination.subspan(destinationOffset, chunkSize));
        if (!copied)
            return ContractResult<void>::Failure(
                copied.Error().category, copied.Error().context);
        destinationOffset += chunkSize;
        cursor += chunkSize;
    }
    return ContractResult<void>::Success();
}

std::shared_ptr<const IMemorySource> MakeProcessMemorySource() {
    return std::make_shared<const ProcessMemorySource>();
}

}  // namespace serverhost::v2::bindings::platform
