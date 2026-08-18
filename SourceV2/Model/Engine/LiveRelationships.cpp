#include "SourceV2/Model/Engine/LiveRelationships.hpp"

#include <limits>

namespace serverhost::v2::model::engine {

ContractResult<void> WorldBoundIdentity::Validate(
    std::uint64_t currentDiscoveryGeneration,
    std::uint64_t currentWorldGeneration) const {
    if (!object.IsStructurallyValid()) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::StaleIdentity,
            "world-bound object identity is structurally invalid");
    }
    if (object.discoveryGeneration != currentDiscoveryGeneration) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::WrongGeneration,
            "world-bound object belongs to another discovery generation");
    }
    if (worldGeneration != currentWorldGeneration) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::WrongGeneration,
            "world-bound object belongs to another world generation");
    }
    return ContractResult<void>::Success();
}

ContractResult<void> ValidateCanonicalArrayHeader(
    CanonicalArrayHeader header, std::int32_t maximumCount,
    std::int32_t maximumCapacity) {
    if (maximumCount < 0 || maximumCapacity < maximumCount) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::InvalidArgument,
            "invalid TArray validation limits");
    }
    if (header.count < 0 || header.capacity < header.count) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MalformedLayout,
            "TArray count/capacity relationship is malformed");
    }
    if (header.count > maximumCount || header.capacity > maximumCapacity) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::LimitExceeded,
            "TArray count or capacity exceeds the bounded relationship profile");
    }
    if (!header.dataPresent) {
        if (header.count != 0 || header.capacity != 0) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::MalformedLayout,
                "null TArray data requires canonical zero count and capacity");
        }
        return ContractResult<void>::Success();
    }
    if (header.capacity == 0) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MalformedLayout,
            "non-null TArray data has zero capacity");
    }
    return ContractResult<void>::Success();
}

ContractResult<WorldGenerationObservation> WorldGenerationTracker::Observe(
    std::optional<StableWorldIdentity> world) {
    if (!initialized_) {
        initialized_ = true;
        current_ = std::move(world);
        if (current_.has_value())
            generation_ = 1;
        return ContractResult<WorldGenerationObservation>::Success({generation_, false});
    }
    if (current_ == world) {
        return ContractResult<WorldGenerationObservation>::Success({generation_, false});
    }
    if (generation_ == std::numeric_limits<std::uint64_t>::max()) {
        return ContractResult<WorldGenerationObservation>::Failure(
            ContractErrorCategory::LimitExceeded,
            "world generation counter exhausted");
    }
    ++generation_;
    current_ = std::move(world);
    return ContractResult<WorldGenerationObservation>::Success({generation_, true});
}

std::uint64_t WorldGenerationTracker::Generation() const noexcept {
    return generation_;
}

}  // namespace serverhost::v2::model::engine
