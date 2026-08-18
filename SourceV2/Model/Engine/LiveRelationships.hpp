#pragma once

#include "SourceV2/Core/ContractResult.hpp"
#include "SourceV2/Core/ObjectIdentity.hpp"

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace serverhost::v2::model::engine {

struct WorldBoundIdentity final {
    ObjectIdentity object;
    std::uint64_t worldGeneration{};

    [[nodiscard]] ContractResult<void> Validate(
        std::uint64_t currentDiscoveryGeneration,
        std::uint64_t currentWorldGeneration) const;
};

struct EngineView final {
    ObjectIdentity identity;
    std::string fullName;
    std::string className;
};

struct GameViewportView final {
    WorldBoundIdentity identity;
    std::string fullName;
    std::string className;
};

struct WorldView final {
    WorldBoundIdentity identity;
    std::string fullName;
    std::string className;
    std::string objectName;
};

struct NetDriverView final {
    WorldBoundIdentity identity;
    std::string fullName;
    std::string className;
};

struct OptionalWorldObjectView final {
    WorldBoundIdentity identity;
    std::string fullName;
    std::string className;
};

struct NetDriverDefinitionView final {
    std::string defName;
    std::string driverClassName;
    std::string driverClassNameFallback;
};

struct NetDriverDefinitionsView final {
    bool canonicalEmpty{};
    std::int32_t count{};
    std::int32_t capacity{};
    std::vector<NetDriverDefinitionView> definitions;
};

struct CanonicalArrayHeader final {
    bool dataPresent{};
    std::int32_t count{};
    std::int32_t capacity{};
};

[[nodiscard]] ContractResult<void> ValidateCanonicalArrayHeader(
    CanonicalArrayHeader header, std::int32_t maximumCount,
    std::int32_t maximumCapacity);

struct StableWorldIdentity final {
    std::int32_t objectIndex{-1};
    std::int32_t serialNumber{};
    std::string validatedFingerprint;

    friend bool operator==(const StableWorldIdentity&, const StableWorldIdentity&) = default;
};

struct WorldGenerationObservation final {
    std::uint64_t generation{};
    bool previousWorldInvalidated{};
};

class WorldGenerationTracker final {
public:
    [[nodiscard]] ContractResult<WorldGenerationObservation> Observe(
        std::optional<StableWorldIdentity> world);
    [[nodiscard]] std::uint64_t Generation() const noexcept;

private:
    bool initialized_{};
    std::optional<StableWorldIdentity> current_;
    std::uint64_t generation_{};
};

struct WorldRelationshipSnapshot final {
    std::uint64_t discoveryGeneration{};
    std::uint64_t worldGeneration{};
    bool previousWorldInvalidated{};
    std::string lifecycleState{"unavailable"};
    std::string worldRelationshipState{"not-evaluated"};
    EngineView engine;
    std::optional<GameViewportView> gameViewport;
    std::optional<WorldView> world;
    std::optional<NetDriverView> netDriver;
    std::optional<OptionalWorldObjectView> authorityGameMode;
    std::optional<OptionalWorldObjectView> gameState;
    NetDriverDefinitionsView netDriverDefinitions;
};

}  // namespace serverhost::v2::model::engine
