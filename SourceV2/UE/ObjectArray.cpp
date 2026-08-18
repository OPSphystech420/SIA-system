#include "SourceV2/UE/ObjectArray.hpp"

namespace serverhost::v2::ue {

ContractResult<ObjectItemSnapshot> ObjectArrayView::ItemAt(int32 index) const {
    if (index < 0 || static_cast<std::size_t>(index) >= items_.size()) {
        return ContractResult<ObjectItemSnapshot>::Failure(
            ContractErrorCategory::OutOfRange, "object index is outside the object snapshot");
    }
    return ContractResult<ObjectItemSnapshot>::Success(items_[static_cast<std::size_t>(index)]);
}

ContractResult<ObjectItemSnapshot> ObjectArrayView::Resolve(
    ObjectIdentity identity, std::uint64_t currentDiscoveryGeneration) const {
    if (!identity.IsStructurallyValid()) {
        return ContractResult<ObjectItemSnapshot>::Failure(
            ContractErrorCategory::StaleIdentity, "object identity has an invalid index, serial, or generation");
    }
    if (identity.discoveryGeneration != currentDiscoveryGeneration) {
        return ContractResult<ObjectItemSnapshot>::Failure(
            ContractErrorCategory::WrongGeneration,
            "object identity belongs to another discovery generation");
    }

    auto itemResult = ItemAt(identity.objectIndex);
    if (!itemResult) {
        return ContractResult<ObjectItemSnapshot>::Failure(
            itemResult.Error().category, itemResult.Error().context);
    }
    const ObjectItemSnapshot item = itemResult.Value();
    if (item.serialNumber != identity.serialNumber || item.isNull || item.malformed) {
        return ContractResult<ObjectItemSnapshot>::Failure(
            ContractErrorCategory::StaleIdentity, "object serial no longer identifies the stored object");
    }
    if (item.unreachable || item.pendingKill) {
        return ContractResult<ObjectItemSnapshot>::Failure(
            ContractErrorCategory::StaleIdentity, "object is unreachable or pending kill");
    }
    return ContractResult<ObjectItemSnapshot>::Success(item);
}

}  // namespace serverhost::v2::ue
