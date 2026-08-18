#include "SourceV2/UE/ObjectArray.hpp"

namespace serverhost::v2::ue {

ContractResult<ObjectItemSnapshot> ObjectArrayView::ItemAt(int32 index) const {
    if (index < 0 || static_cast<std::size_t>(index) >= items_.size()) {
        return ContractResult<ObjectItemSnapshot>::Failure(
            ContractErrorCategory::OutOfRange, "object index is outside the object snapshot");
    }
    return ContractResult<ObjectItemSnapshot>::Success(items_[static_cast<std::size_t>(index)]);
}

ContractResult<const void*> ObjectArrayView::Resolve(
    ObjectIdentity identity, std::uint64_t currentWorldGeneration) const {
    if (!identity.IsStructurallyValid()) {
        return ContractResult<const void*>::Failure(
            ContractErrorCategory::StaleIdentity, "object identity has an invalid index, serial, or generation");
    }
    if (identity.worldGeneration != currentWorldGeneration) {
        return ContractResult<const void*>::Failure(
            ContractErrorCategory::WrongGeneration, "object identity belongs to another world generation");
    }

    auto itemResult = ItemAt(identity.objectIndex);
    if (!itemResult) {
        return ContractResult<const void*>::Failure(itemResult.Error().category, itemResult.Error().context);
    }
    const ObjectItemSnapshot item = itemResult.Value();
    if (item.serialNumber != identity.serialNumber || item.object == nullptr) {
        return ContractResult<const void*>::Failure(
            ContractErrorCategory::StaleIdentity, "object serial no longer identifies the stored object");
    }
    if (item.unreachable || item.pendingKill) {
        return ContractResult<const void*>::Failure(
            ContractErrorCategory::StaleIdentity, "object is unreachable or pending kill");
    }
    return ContractResult<const void*>::Success(item.object);
}

}  // namespace serverhost::v2::ue
