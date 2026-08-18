#include "SourceV2/Bindings/Platform/MemorySource.hpp"

#include <limits>
#include <mach/mach.h>

namespace serverhost::v2::bindings::platform {

ContractResult<void> ProcessMemorySource::Copy(
    std::uintptr_t address, std::span<std::byte> destination) const {
    if (destination.empty()) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::InvalidArgument, "zero-length process-memory read");
    }
    if (destination.size() > std::numeric_limits<std::uintptr_t>::max() - address) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::OutOfRange, "process-memory address plus size overflows");
    }

    vm_address_t regionAddress = static_cast<vm_address_t>(address);
    vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;
    const kern_return_t regionResult = vm_region_64(
        mach_task_self(), &regionAddress, &regionSize, VM_REGION_BASIC_INFO_64,
        reinterpret_cast<vm_region_info_t>(&info), &count, &objectName);
    if (objectName != MACH_PORT_NULL)
        mach_port_deallocate(mach_task_self(), objectName);
    if (regionResult != KERN_SUCCESS || regionAddress > address
        || (info.protection & VM_PROT_READ) == 0
        || regionSize > std::numeric_limits<std::uintptr_t>::max()
        || regionAddress > std::numeric_limits<std::uintptr_t>::max()
        || static_cast<std::uintptr_t>(regionSize)
            > std::numeric_limits<std::uintptr_t>::max()
                - static_cast<std::uintptr_t>(regionAddress)
        || address + destination.size()
            > static_cast<std::uintptr_t>(regionAddress)
                + static_cast<std::uintptr_t>(regionSize)) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::OutOfRange,
            "requested bytes are not contained in one readable VM region");
    }

    vm_size_t copied = 0;
    const kern_return_t readResult = vm_read_overwrite(
        mach_task_self(), static_cast<vm_address_t>(address),
        static_cast<vm_size_t>(destination.size()),
        reinterpret_cast<vm_address_t>(destination.data()), &copied);
    if (readResult != KERN_SUCCESS || copied != destination.size()) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::OutOfRange, "bounded process-memory copy failed");
    }
    return ContractResult<void>::Success();
}

std::shared_ptr<const IMemorySource> MakeProcessMemorySource() {
    return std::make_shared<const ProcessMemorySource>();
}

}  // namespace serverhost::v2::bindings::platform
