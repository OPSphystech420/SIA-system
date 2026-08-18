#pragma once

#include "SourceV2/Bindings/Platform/CheckedMemoryReader.hpp"
#include "SourceV2/Bindings/Profiles/ReadOnlyContracts_1_10280.hpp"
#include "SourceV2/Core/ObjectIdentity.hpp"
#include "SourceV2/Core/ReadOnlyContractReport.hpp"
#include "SourceV2/UE/Name.hpp"
#include "SourceV2/UE/ObjectArray.hpp"
#include "SourceV2/UE/Primitives.hpp"

#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <string>
#include <vector>

namespace serverhost::v2::bindings::ue {

struct DiscoveryGeneration final {
    std::uint64_t value{};
};

struct CaptureLimits final {
    std::size_t maximumCopiedBytes{96U * 1024U * 1024U};
    std::int32_t maximumObjects{350000};
    // MaxElements is reserved index capacity, not the number copied. Keep its
    // default at the representable ABI ceiling; maximumObjects and
    // maximumObjectChunks bound the live work performed by a capture.
    std::int32_t maximumObjectCapacity{std::numeric_limits<std::int32_t>::max()};
    std::int32_t maximumObjectChunks{128};
    std::uint32_t maximumNameBlocks{512};
    std::uint32_t maximumRetries{3};
    std::uint32_t maximumChainDepth{32};
    std::chrono::milliseconds maximumDuration{5000};
};

class FNamePoolSnapshot final : public serverhost::v2::ue::INameResolver {
public:
    FNamePoolSnapshot() = default;
    FNamePoolSnapshot(const FNamePoolSnapshot&) = delete;
    FNamePoolSnapshot& operator=(const FNamePoolSnapshot&) = delete;
    FNamePoolSnapshot(FNamePoolSnapshot&& other) noexcept;
    FNamePoolSnapshot& operator=(FNamePoolSnapshot&& other) noexcept;

    [[nodiscard]] ContractResult<std::string> Resolve(
        serverhost::v2::ue::FName name) const override;
    [[nodiscard]] std::optional<serverhost::v2::ue::FName> Find(
        std::string_view name) const;
    [[nodiscard]] std::uint32_t CurrentBlock() const noexcept;
    [[nodiscard]] std::uint32_t CurrentByteCursor() const noexcept;
    [[nodiscard]] std::uint64_t EntryCount() const noexcept;

private:
    std::vector<std::vector<std::byte>> blocks_;
    std::vector<serverhost::v2::ue::NamePoolBlock> blockViews_;
    std::vector<std::pair<std::string, serverhost::v2::ue::FName>> indexedNames_;
    std::uint32_t currentBlock_{};
    std::uint32_t currentByteCursor_{};
    std::uint64_t entryCount_{};

    void RebuildViews();
    friend class ReadOnlySnapshotCapture;
};

class ObjectArraySnapshot final {
public:
    [[nodiscard]] const std::vector<serverhost::v2::ue::ObjectItemSnapshot>& Items() const noexcept;
    [[nodiscard]] ContractResult<serverhost::v2::ue::ObjectItemSnapshot> Resolve(
        ObjectIdentity identity, DiscoveryGeneration generation) const;
    [[nodiscard]] std::int32_t Num() const noexcept;
    [[nodiscard]] std::int32_t Max() const noexcept;
    [[nodiscard]] std::int32_t NumChunks() const noexcept;
    [[nodiscard]] std::int32_t MaxChunks() const noexcept;

private:
    std::vector<serverhost::v2::ue::ObjectItemSnapshot> items_;
    DiscoveryGeneration generation_;
    std::int32_t num_{};
    std::int32_t max_{};
    std::int32_t numChunks_{};
    std::int32_t maxChunks_{};

    friend class ReadOnlySnapshotCapture;
};

struct ReflectionIdentity final {
    ObjectIdentity identity;
    serverhost::v2::ue::FName name;
    std::string objectName;
    std::string fullName;
    std::string className;
    std::optional<ObjectIdentity> outer;
    std::optional<ObjectIdentity> superStruct;
    std::optional<serverhost::v2::ue::EFunctionFlags> functionFlags;
};

class ReflectionSnapshot final {
public:
    [[nodiscard]] const std::vector<ReflectionIdentity>& KnownObjects() const noexcept;
    [[nodiscard]] ContractResult<ReflectionIdentity> FindByFullName(
        std::string_view fullName, DiscoveryGeneration generation) const;
    [[nodiscard]] ContractResult<ReflectionIdentity> FindClass(
        std::string_view fullName, DiscoveryGeneration generation) const;
    [[nodiscard]] ContractResult<ReflectionIdentity> FindFunction(
        std::string_view fullName, DiscoveryGeneration generation) const;

private:
    DiscoveryGeneration generation_;
    std::vector<ReflectionIdentity> knownObjects_;

    friend class ReadOnlySnapshotCapture;
};

struct ReadOnlyContractSnapshot final {
    DiscoveryGeneration generation;
    FNamePoolSnapshot names;
    ObjectArraySnapshot objects;
    ReflectionSnapshot reflection;
    ReadOnlyContractReport report;
};

class ReadOnlySnapshotCapture final {
public:
    [[nodiscard]] ContractResult<ReadOnlyContractSnapshot> Capture(
        const platform::CheckedMemoryReader& reader,
        const profiles::ReadOnlyContractProfile& profile,
        DiscoveryGeneration generation, const CaptureLimits& limits,
        const std::atomic_bool* cancellation = nullptr) const;
};

}  // namespace serverhost::v2::bindings::ue
