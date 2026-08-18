#include "SourceV2/UE/Reflection.hpp"

namespace serverhost::v2::ue {

ContractResult<void> FPropertyDescriptor::Validate() const {
    if (!HasAllFlags(field.castFlags, EClassCastFlags::Property)) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::TypeMismatch, "field does not carry the Property cast flag");
    }
    if (arrayDim <= 0 || elementSize <= 0 || offset < 0) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MalformedLayout, "property dimensions, size, or offset are invalid");
    }
    if (boolMetadata.has_value()) {
        const auto& boolean = *boolMetadata;
        const bool oneBitMask = boolean.byteMask != 0
            && (boolean.byteMask & static_cast<uint8>(boolean.byteMask - 1U)) == 0;
        if (!HasAllFlags(field.castFlags, EClassCastFlags::BoolProperty)
            || boolean.fieldSize == 0 || boolean.byteOffset >= elementSize || !oneBitMask
            || (boolean.fieldMask & boolean.byteMask) == 0) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::MalformedLayout, "bool property mask metadata is inconsistent");
        }
    }
    return ContractResult<void>::Success();
}

ContractResult<void> UFunctionDescriptor::Validate(
    std::uint64_t expectedGeneration, EFunctionFlags requiredFlags,
    uint16 expectedParmsSize, uint8 expectedNumParms) const {
    if (!identity.IsStructurallyValid() || identity.worldGeneration != expectedGeneration) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::WrongGeneration, "function identity is stale for this registry generation");
    }
    if (fullName.empty() || !HasAllFlags(functionFlags, requiredFlags)) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::TypeMismatch, "function name or required flags do not match");
    }
    if (parmsSize != expectedParmsSize || numParms != expectedNumParms) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MalformedLayout, "function parameter metadata does not match its contract");
    }
    return ContractResult<void>::Success();
}

ContractResult<UFunctionDescriptor> ReflectionRegistry::FindFunction(const std::string& fullName) {
    if (auto cached = functions_.find(fullName); cached != functions_.end()) {
        if (cached->second.identity.worldGeneration == worldGeneration_) {
            return ContractResult<UFunctionDescriptor>::Success(cached->second);
        }
        functions_.erase(cached);
    }
    if (!functionLookup_) {
        return ContractResult<UFunctionDescriptor>::Failure(
            ContractErrorCategory::NotFound, "no function lookup source is configured");
    }
    auto result = functionLookup_(fullName);
    if (!result) {
        return result;
    }
    if (result.Value().identity.worldGeneration != worldGeneration_) {
        return ContractResult<UFunctionDescriptor>::Failure(
            ContractErrorCategory::WrongGeneration, "lookup returned a function from another generation");
    }
    functions_.insert_or_assign(fullName, result.Value());
    return result;
}

ContractResult<UClassDescriptor> ReflectionRegistry::FindClass(const std::string& fullName) {
    if (auto cached = classes_.find(fullName); cached != classes_.end()) {
        if (cached->second.identity.worldGeneration == worldGeneration_) {
            return ContractResult<UClassDescriptor>::Success(cached->second);
        }
        classes_.erase(cached);
    }
    if (!classLookup_) {
        return ContractResult<UClassDescriptor>::Failure(
            ContractErrorCategory::NotFound, "no class lookup source is configured");
    }
    auto result = classLookup_(fullName);
    if (!result) {
        return result;
    }
    if (result.Value().identity.worldGeneration != worldGeneration_) {
        return ContractResult<UClassDescriptor>::Failure(
            ContractErrorCategory::WrongGeneration, "lookup returned a class from another generation");
    }
    classes_.insert_or_assign(fullName, result.Value());
    return result;
}

void ReflectionRegistry::Invalidate(std::uint64_t newWorldGeneration) {
    worldGeneration_ = newWorldGeneration;
    functions_.clear();
    classes_.clear();
}

}  // namespace serverhost::v2::ue
