#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace serverhost::v2 {

struct ContractCheck final {
    std::string label;
    std::string state;
    std::string detail;
};

struct ReadOnlyContractReport final {
    std::string captureState{"not-started"};
    std::string profileRootState{"not-evaluated"};
    std::string retryOrAbortReason{"none"};
    std::uint64_t discoveryGeneration{};
    std::uint32_t scansStarted{};
    std::uint32_t fNameBlocks{};
    std::uint64_t fNameEntries{};
    std::int32_t objectNum{};
    std::int32_t objectMax{};
    std::int32_t objectNumChunks{};
    std::int32_t objectMaxChunks{};
    std::uint64_t validObjects{};
    std::uint64_t nullObjects{};
    std::uint64_t pendingKillObjects{};
    std::uint64_t unreachableObjects{};
    std::uint64_t malformedObjects{};
    std::uint64_t copiedBytes{};
    std::uint64_t durationMilliseconds{};
    bool previousGenerationInvalidated{};
    std::vector<ContractCheck> knownNames;
    std::vector<ContractCheck> knownObjects;
    std::vector<ContractCheck> reflectionChecks;
    std::uint32_t hooks{};
    std::uint32_t engineCalls{};
    std::uint32_t mutation{};
};

}  // namespace serverhost::v2
