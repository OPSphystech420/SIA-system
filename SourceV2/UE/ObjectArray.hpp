#pragma once

#include "SourceV2/Core/ContractResult.hpp"
#include "SourceV2/Core/ObjectIdentity.hpp"
#include "SourceV2/UE/Primitives.hpp"

#include <cstddef>
#include <span>

namespace serverhost::v2::ue {

struct ObjectItemSnapshot final {
    const void* object{};
    int32 serialNumber{};
    bool unreachable{};
    bool pendingKill{};
};

class ObjectArrayView final {
public:
    explicit ObjectArrayView(std::span<const ObjectItemSnapshot> items) : items_(items) {}

    [[nodiscard]] std::size_t Size() const noexcept { return items_.size(); }
    [[nodiscard]] ContractResult<ObjectItemSnapshot> ItemAt(int32 index) const;
    [[nodiscard]] ContractResult<const void*> Resolve(
        ObjectIdentity identity, std::uint64_t currentWorldGeneration) const;

private:
    std::span<const ObjectItemSnapshot> items_;
};

template <typename T>
class ObjectHandle final {
public:
    explicit constexpr ObjectHandle(ObjectIdentity identity) : identity_(identity) {}

    [[nodiscard]] constexpr ObjectIdentity Identity() const noexcept { return identity_; }

    [[nodiscard]] ContractResult<const T*> Resolve(
        const ObjectArrayView& objects, std::uint64_t currentWorldGeneration) const {
        auto result = objects.Resolve(identity_, currentWorldGeneration);
        if (!result) {
            return ContractResult<const T*>::Failure(result.Error().category, result.Error().context);
        }
        // Gate 1 handles are identity/lifetime checks only. Type/class validation is
        // a separate callback at the reflection boundary and is mandatory for live use.
        return ContractResult<const T*>::Success(static_cast<const T*>(result.Value()));
    }

private:
    ObjectIdentity identity_;
};

}  // namespace serverhost::v2::ue
