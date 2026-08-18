#pragma once

#include "SourceV2/Core/ContractResult.hpp"
#include "SourceV2/Core/ObjectIdentity.hpp"
#include "SourceV2/UE/Name.hpp"
#include "SourceV2/UE/Primitives.hpp"

#include <optional>
#include <string>

namespace serverhost::v2::ue {

struct UObjectMetadata final {
    ObjectIdentity identity;
    FName name;
    ObjectIdentity classIdentity;
    std::optional<ObjectIdentity> outerIdentity;
    EObjectFlags flags{EObjectFlags::None};
};

struct UFieldMetadata final {
    UObjectMetadata object;
    std::optional<ObjectIdentity> next;
};

struct UStructMetadata final {
    UFieldMetadata field;
    std::optional<ObjectIdentity> superStruct;
    std::optional<ObjectIdentity> children;
    int32 structureSize{};
    int16 minimumAlignment{};
};

struct UClassMetadata final {
    UStructMetadata structure;
    EClassCastFlags castFlags{EClassCastFlags::None};
    std::optional<ObjectIdentity> classDefaultObject;
};

struct UFunctionMetadata final {
    UStructMetadata structure;
    EFunctionFlags functionFlags{EFunctionFlags::None};
    uint8 numParms{};
    uint16 parmsSize{};
    uint16 returnValueOffset{};
};

class UObjectView final {
public:
    explicit UObjectView(const UObjectMetadata& metadata) : metadata_(metadata) {}

    [[nodiscard]] ObjectIdentity Identity() const noexcept { return metadata_.identity; }
    [[nodiscard]] FName Name() const noexcept { return metadata_.name; }
    [[nodiscard]] bool IsDefaultObject() const noexcept {
        return HasAllFlags(metadata_.flags, EObjectFlags::ClassDefaultObject);
    }

private:
    const UObjectMetadata& metadata_;
};

class UClassView final {
public:
    explicit UClassView(const UClassMetadata& metadata) : metadata_(metadata) {}
    [[nodiscard]] bool HasCastFlags(EClassCastFlags flags) const noexcept {
        return HasAllFlags(metadata_.castFlags, flags);
    }
    [[nodiscard]] const UStructMetadata& Structure() const noexcept { return metadata_.structure; }

private:
    const UClassMetadata& metadata_;
};

class UFunctionView final {
public:
    explicit UFunctionView(const UFunctionMetadata& metadata) : metadata_(metadata) {}
    [[nodiscard]] uint16 ParmsSize() const noexcept { return metadata_.parmsSize; }
    [[nodiscard]] uint8 NumParms() const noexcept { return metadata_.numParms; }
    [[nodiscard]] EFunctionFlags Flags() const noexcept { return metadata_.functionFlags; }

private:
    const UFunctionMetadata& metadata_;
};

}  // namespace serverhost::v2::ue
