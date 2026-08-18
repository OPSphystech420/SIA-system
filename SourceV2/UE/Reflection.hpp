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
    uint8 numParms{};
    uint16 parmsSize{};
    uint16 returnValueOffset{};

    [[nodiscard]] ContractResult<void> Validate(
        std::uint64_t expectedGeneration, EFunctionFlags requiredFlags,
        uint16 expectedParmsSize, uint8 expectedNumParms) const;
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

    ReflectionRegistry(std::uint64_t worldGeneration, FunctionLookup functionLookup,
                       ClassLookup classLookup)
        : worldGeneration_(worldGeneration), functionLookup_(std::move(functionLookup)),
          classLookup_(std::move(classLookup)) {}

    [[nodiscard]] ContractResult<UFunctionDescriptor> FindFunction(const std::string& fullName);
    [[nodiscard]] ContractResult<UClassDescriptor> FindClass(const std::string& fullName);
    void Invalidate(std::uint64_t newWorldGeneration);
    [[nodiscard]] std::uint64_t WorldGeneration() const noexcept { return worldGeneration_; }

private:
    std::uint64_t worldGeneration_{};
    FunctionLookup functionLookup_;
    ClassLookup classLookup_;
    std::unordered_map<std::string, UFunctionDescriptor> functions_;
    std::unordered_map<std::string, UClassDescriptor> classes_;
};

}  // namespace serverhost::v2::ue
