#pragma once

#include "SourceV2/Bindings/Profiles/LiveRelationships_1_10280.hpp"
#include "SourceV2/Bindings/UE/ReadOnlySnapshotCapture.hpp"
#include "SourceV2/Model/Engine/LiveRelationships.hpp"

#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace serverhost::v2::bindings::ue {

struct RelationshipCaptureLimits final {
    std::size_t maximumCopiedBytes{4U * 1024U * 1024U};
    std::int32_t maximumDefinitions{64};
    std::int32_t maximumDefinitionCapacity{256};
    std::uint32_t maximumChainDepth{32};
    std::chrono::milliseconds maximumDuration{1500};
};

struct WorldRelationshipCaptureResult final {
    model::engine::WorldRelationshipSnapshot snapshot;
    std::uint64_t copiedBytes{};
    std::uint64_t durationMilliseconds{};
    std::vector<ContractCheck> engineChecks;
    std::vector<ContractCheck> gameViewportChecks;
    std::vector<ContractCheck> worldChecks;
    std::vector<ContractCheck> netDriverChecks;
    std::vector<ContractCheck> netDriverDefinitionChecks;
    std::vector<ContractCheck> generationChecks;
};

class WorldRelationshipCapture final {
public:
    [[nodiscard]] ContractResult<WorldRelationshipCaptureResult> Capture(
        const platform::CheckedMemoryReader& reader,
        const profiles::LiveRelationshipProfile& profile,
        const ReadOnlyContractSnapshot& freshSnapshot,
        model::engine::WorldGenerationTracker& generationTracker,
        const RelationshipCaptureLimits& limits = {},
        const std::atomic_bool* cancellation = nullptr) const;
};

}  // namespace serverhost::v2::bindings::ue
