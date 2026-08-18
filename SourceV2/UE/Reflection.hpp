#pragma once

#include "SourceV2/Core/ContractResult.hpp"
#include "SourceV2/Core/ObjectIdentity.hpp"
#include "SourceV2/UE/Name.hpp"
#include "SourceV2/UE/Primitives.hpp"

#include <functional>
#include <optional>
#include <string>
#include <unordered_map>

namespace serverhost::v2::ue {

struct FFieldMetadata final {
    FName name;
    EClassCastFlags castFlags{EClassCastFlags::None};
    std::optional<FName> nextName;
};

struct BoolPropertyMetadata final {
    uint8 fieldSize{};
    uint8 byteOffset{};
    uint8 byteMask{};
    uint8 fieldMask{};
};

struct FPropertyDescriptor final {
    FFieldMetadata field;
    int32 arrayDim{};
    int32 elementSize{};
    EPropertyFlags propertyFlags{EPropertyFlags::None};
    int32 offset{};
    std::optional<BoolPropertyMetadata> boolMetadata;

    [[nodiscard]] ContractResult<void> Validate() const;
};

struct UFunctionDescriptor final {
    ObjectIdentity identity;
    std::string fullName;
    EFunctionFlags functionFlags{EFunctionFlags::None};

    [[nodiscard]] ContractResult<void> Validate(
        std::uint64_t expectedGeneration, EFunctionFlags requiredFlags) const;
};

struct UClassDescriptor final {
    ObjectIdentity identity;
    std::string fullName;
    EClassCastFlags castFlags{EClassCastFlags::None};
    std::optional<ObjectIdentity> superClass;
};

class ReflectionRegistry final {
public:
    using FunctionLookup = std::function<ContractResult<UFunctionDescriptor>(const std::string&)>;
    using ClassLookup = std::function<ContractResult<UClassDescriptor>(const std::string&)>;

    ReflectionRegistry(std::uint64_t discoveryGeneration, FunctionLookup functionLookup,
                       ClassLookup classLookup)
        : discoveryGeneration_(discoveryGeneration), functionLookup_(std::move(functionLookup)),
          classLookup_(std::move(classLookup)) {}

    [[nodiscard]] ContractResult<UFunctionDescriptor> FindFunction(const std::string& fullName);
    [[nodiscard]] ContractResult<UClassDescriptor> FindClass(const std::string& fullName);
    void Invalidate(std::uint64_t newDiscoveryGeneration);
    [[nodiscard]] std::uint64_t DiscoveryGeneration() const noexcept {
        return discoveryGeneration_;
    }

private:
    std::uint64_t discoveryGeneration_{};
    FunctionLookup functionLookup_;
    ClassLookup classLookup_;
    std::unordered_map<std::string, UFunctionDescriptor> functions_;
    std::unordered_map<std::string, UClassDescriptor> classes_;
};

}  // namespace serverhost::v2::ue
