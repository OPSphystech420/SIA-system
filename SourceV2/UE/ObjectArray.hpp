#pragma once

#include "SourceV2/Core/ContractResult.hpp"
#include "SourceV2/Core/ObjectIdentity.hpp"
#include "SourceV2/UE/Primitives.hpp"

#include <cstddef>
#include <span>

namespace serverhost::v2::ue {

struct ObjectItemSnapshot final {
    int32 objectIndex{-1};
    int32 serialNumber{};
    int32 clusterIndex{};
    bool isNull{};
    bool unreachable{};
    bool pendingKill{};
    bool malformed{};
};

class ObjectArrayView final {
public:
    explicit ObjectArrayView(std::span<const ObjectItemSnapshot> items) : items_(items) {}

    [[nodiscard]] std::size_t Size() const noexcept { return items_.size(); }
    [[nodiscard]] ContractResult<ObjectItemSnapshot> ItemAt(int32 index) const;
    [[nodiscard]] ContractResult<ObjectItemSnapshot> Resolve(
        ObjectIdentity identity, std::uint64_t currentDiscoveryGeneration) const;

private:
    std::span<const ObjectItemSnapshot> items_;
};

template <typename T>
class ObjectHandle final {
public:
    explicit constexpr ObjectHandle(ObjectIdentity identity) : identity_(identity) {}

    [[nodiscard]] constexpr ObjectIdentity Identity() const noexcept { return identity_; }

    [[nodiscard]] ContractResult<ObjectItemSnapshot> Resolve(
        const ObjectArrayView& objects, std::uint64_t currentDiscoveryGeneration) const {
        auto result = objects.Resolve(identity_, currentDiscoveryGeneration);
        if (!result) {
            return ContractResult<ObjectItemSnapshot>::Failure(
                result.Error().category, result.Error().context);
        }
        return result;
    }

private:
    ObjectIdentity identity_;
};

}  // namespace serverhost::v2::ue
