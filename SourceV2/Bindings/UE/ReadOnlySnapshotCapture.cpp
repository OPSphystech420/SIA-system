#include "SourceV2/Bindings/UE/ReadOnlySnapshotCapture.hpp"

#include "SourceV2/Bindings/Generated/Layouts_1_10280.hpp"

#include <algorithm>
#include <cstring>
#include <limits>
#include <span>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <utility>

namespace serverhost::v2::bindings::ue {
namespace {

using namespace generated::ios_1_10280;
using platform::DerivedMemoryToken;
using platform::ImageMemoryToken;
using platform::MemoryReadKind;
using platform::OwnedMemoryCopy;
using serverhost::v2::ue::FName;

constexpr std::array<std::string_view, 10> kKnownNames{
    "None", "Object", "Class", "Function", "World", "Engine", "GameEngine",
    "GameViewportClient", "NetDriver", "GameNetDriver",
};

struct CaptureBudget final {
    const CaptureLimits& limits;
    const std::atomic_bool* cancellation;
    std::chrono::steady_clock::time_point started{std::chrono::steady_clock::now()};
    std::uint64_t copiedBytes{};

    ContractResult<void> BeforeCopy(std::size_t bytes) {
        if (cancellation != nullptr && cancellation->load(std::memory_order_relaxed)) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::Cancelled, "capture cancelled");
        }
        if (std::chrono::steady_clock::now() - started > limits.maximumDuration) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::LimitExceeded, "capture time limit exceeded");
        }
        if (bytes > limits.maximumCopiedBytes
            || copiedBytes > limits.maximumCopiedBytes - bytes) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::LimitExceeded, "capture byte limit exceeded");
        }
        copiedBytes += bytes;
        return ContractResult<void>::Success();
    }
};

template <typename Token>
ContractResult<OwnedMemoryCopy> BudgetedRead(
    const platform::CheckedMemoryReader& reader, const Token& token,
    std::size_t offset, std::size_t size, CaptureBudget& budget) {
    const auto allowed = budget.BeforeCopy(size);
    if (!allowed) {
        return ContractResult<OwnedMemoryCopy>::Failure(
            allowed.Error().category, allowed.Error().context);
    }
    return reader.Read(token, offset, size);
}

bool SameBytes(const OwnedMemoryCopy& lhs, const OwnedMemoryCopy& rhs) {
    return lhs.Bytes().size() == rhs.Bytes().size()
        && std::equal(lhs.Bytes().begin(), lhs.Bytes().end(), rhs.Bytes().begin());
}

std::size_t AlignTwo(std::size_t value) { return (value + 1U) & ~std::size_t{1}; }

std::string NormalizePackageName(std::string name) {
    constexpr std::string_view prefix = "/Script/";
    if (name.starts_with(prefix))
        name.erase(0, prefix.size());
    return name;
}

struct ObjectHeader final {
    std::uint64_t objectsWord{};
    std::int32_t maxElements{};
    std::int32_t numElements{};
    std::int32_t maxChunks{};
    std::int32_t numChunks{};

    friend bool operator==(const ObjectHeader&, const ObjectHeader&) = default;
};

ContractResult<ObjectHeader> ParseObjectHeader(const OwnedMemoryCopy& copy) {
    const auto objects = copy.ValueAt<std::uint64_t>(0x0);
    const auto maxElements = copy.ValueAt<std::int32_t>(0x10);
    const auto numElements = copy.ValueAt<std::int32_t>(0x14);
    const auto maxChunks = copy.ValueAt<std::int32_t>(0x18);
    const auto numChunks = copy.ValueAt<std::int32_t>(0x1C);
    if (!objects || !maxElements || !numElements || !maxChunks || !numChunks) {
        return ContractResult<ObjectHeader>::Failure(
            ContractErrorCategory::MalformedLayout, "truncated TUObjectArray header");
    }
    return ContractResult<ObjectHeader>::Success({
        objects.Value(), maxElements.Value(), numElements.Value(),
        maxChunks.Value(), numChunks.Value(),
    });
}

ContractResult<void> ValidateObjectHeader(
    const ObjectHeader& header, const profiles::ReadOnlyContractProfile& profile,
    const CaptureLimits& limits) {
    if (header.numElements < 0 || header.maxElements < header.numElements
        || header.numElements > limits.maximumObjects
        || header.maxElements > limits.maximumObjectCapacity
        || header.numChunks < 0 || header.maxChunks < 0
        || header.numChunks > limits.maximumObjectChunks
        || header.maxChunks > limits.maximumObjectChunks
        || header.maxChunks < header.numChunks || header.objectsWord == 0) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MalformedLayout,
            "invalid TUObjectArray num/max/chunk relationship");
    }
    const std::int64_t required = header.numElements == 0 ? 0
        : (static_cast<std::int64_t>(header.numElements)
            + profile.objectChunkItems - 1) / profile.objectChunkItems;
    if (required > header.numChunks || header.numChunks > header.maxChunks) {
        return ContractResult<void>::Failure(
            ContractErrorCategory::MalformedLayout,
            "TUObjectArray lacks required chunks");
    }
    return ContractResult<void>::Success();
}

struct PrivateItem final {
    std::uint64_t objectWord{};
    serverhost::v2::ue::ObjectItemSnapshot publicItem;
    std::size_t chunkIndex{};
    std::size_t itemOffset{};
};

struct PrivateMetadata final {
    std::int32_t index{-1};
    std::int32_t serial{};
    FName name;
    std::uint64_t classWord{};
    std::uint64_t outerWord{};
};

}  // namespace

FNamePoolSnapshot::FNamePoolSnapshot(FNamePoolSnapshot&& other) noexcept
    : blocks_(std::move(other.blocks_)), indexedNames_(std::move(other.indexedNames_)),
      currentBlock_(other.currentBlock_), currentByteCursor_(other.currentByteCursor_),
      entryCount_(other.entryCount_) {
    RebuildViews();
}

FNamePoolSnapshot& FNamePoolSnapshot::operator=(FNamePoolSnapshot&& other) noexcept {
    if (this == &other)
        return *this;
    blocks_ = std::move(other.blocks_);
    indexedNames_ = std::move(other.indexedNames_);
    currentBlock_ = other.currentBlock_;
    currentByteCursor_ = other.currentByteCursor_;
    entryCount_ = other.entryCount_;
    RebuildViews();
    return *this;
}

void FNamePoolSnapshot::RebuildViews() {
    blockViews_.clear();
    blockViews_.reserve(blocks_.size());
    for (const auto& block : blocks_)
        blockViews_.push_back({block});
}

ContractResult<std::string> FNamePoolSnapshot::Resolve(FName name) const {
    const serverhost::v2::ue::FNamePoolView view(
        blockViews_, currentBlock_, currentByteCursor_);
    return view.Resolve(name);
}

std::optional<FName> FNamePoolSnapshot::Find(std::string_view name) const {
    const auto iterator = std::find_if(
        indexedNames_.begin(), indexedNames_.end(),
        [name](const auto& pair) { return pair.first == name; });
    return iterator == indexedNames_.end() ? std::nullopt
                                           : std::optional<FName>(iterator->second);
}

std::uint32_t FNamePoolSnapshot::CurrentBlock() const noexcept { return currentBlock_; }
std::uint32_t FNamePoolSnapshot::CurrentByteCursor() const noexcept {
    return currentByteCursor_;
}
std::uint64_t FNamePoolSnapshot::EntryCount() const noexcept { return entryCount_; }

const std::vector<serverhost::v2::ue::ObjectItemSnapshot>&
ObjectArraySnapshot::Items() const noexcept {
    return items_;
}

ContractResult<serverhost::v2::ue::ObjectItemSnapshot> ObjectArraySnapshot::Resolve(
    ObjectIdentity identity, DiscoveryGeneration generation) const {
    if (generation.value != generation_.value) {
        return ContractResult<serverhost::v2::ue::ObjectItemSnapshot>::Failure(
            ContractErrorCategory::WrongGeneration,
            "snapshot belongs to another discovery generation");
    }
    return serverhost::v2::ue::ObjectArrayView(items_).Resolve(identity, generation.value);
}

std::int32_t ObjectArraySnapshot::Num() const noexcept { return num_; }
std::int32_t ObjectArraySnapshot::Max() const noexcept { return max_; }
std::int32_t ObjectArraySnapshot::NumChunks() const noexcept { return numChunks_; }
std::int32_t ObjectArraySnapshot::MaxChunks() const noexcept { return maxChunks_; }

const std::vector<ReflectionIdentity>& ReflectionSnapshot::KnownObjects() const noexcept {
    return knownObjects_;
}

ContractResult<ReflectionIdentity> ReflectionSnapshot::FindByFullName(
    std::string_view fullName, DiscoveryGeneration generation) const {
    if (generation.value != generation_.value) {
        return ContractResult<ReflectionIdentity>::Failure(
            ContractErrorCategory::WrongGeneration,
            "reflection snapshot belongs to another discovery generation");
    }
    const auto iterator = std::find_if(
        knownObjects_.begin(), knownObjects_.end(),
        [fullName](const ReflectionIdentity& value) { return value.fullName == fullName; });
    if (iterator == knownObjects_.end()) {
        return ContractResult<ReflectionIdentity>::Failure(
            ContractErrorCategory::NotFound, "full name is absent from bounded reflection snapshot");
    }
    return ContractResult<ReflectionIdentity>::Success(*iterator);
}

ContractResult<ReflectionIdentity> ReflectionSnapshot::FindClass(
    std::string_view fullName, DiscoveryGeneration generation) const {
    const auto result = FindByFullName(fullName, generation);
    if (!result)
        return result;
    if (result.Value().className != "Class") {
        return ContractResult<ReflectionIdentity>::Failure(
            ContractErrorCategory::TypeMismatch,
            "full-name lookup did not resolve a UClass identity");
    }
    return result;
}

ContractResult<ReflectionIdentity> ReflectionSnapshot::FindFunction(
    std::string_view fullName, DiscoveryGeneration generation) const {
    const auto result = FindByFullName(fullName, generation);
    if (!result)
        return result;
    if (result.Value().className != "Function" || !result.Value().functionFlags.has_value()) {
        return ContractResult<ReflectionIdentity>::Failure(
            ContractErrorCategory::TypeMismatch,
            "full-name lookup did not resolve a UFunction identity");
    }
    return result;
}

ContractResult<ReadOnlyContractSnapshot> ReadOnlySnapshotCapture::Capture(
    const platform::CheckedMemoryReader& reader,
    const profiles::ReadOnlyContractProfile& profile,
    DiscoveryGeneration generation, const CaptureLimits& limits,
    const std::atomic_bool* cancellation) const {
    if (generation.value == 0 || limits.maximumRetries == 0
        || limits.maximumNameBlocks == 0 || limits.maximumObjects <= 0) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            ContractErrorCategory::InvalidArgument, "invalid Gate 2B capture configuration");
    }
    if (!reader.CanUseProfile(profile.identityProfileId)) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            ContractErrorCategory::UnsupportedProfile,
            "checked reader and Gate 2B resolver profile do not match");
    }
    CaptureBudget budget{limits, cancellation};
    ReadOnlyContractSnapshot output;
    output.generation = generation;
    output.report.discoveryGeneration = generation.value;
    output.report.scansStarted = 1;
    output.report.profileRootState = "exact-profile-rva-roots";

    const auto nameRoot = reader.ResolveImageRva(
        profile.fNamePoolRva, sizeof(FNamePoolLayout), MemoryReadKind::ReadableData);
    const auto enclosingRoot = reader.ResolveImageRva(
        profile.fuObjectArrayRva, sizeof(FUObjectArrayLayout), MemoryReadKind::ReadableData);
    const auto objectRoot = reader.ResolveImageRva(
        profile.directObjectArrayRva, sizeof(TUObjectArrayLayout), MemoryReadKind::ReadableData);
    if (!nameRoot || !enclosingRoot || !objectRoot) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            ContractErrorCategory::OutOfRange,
            "one or more exact-profile Gate 2B RVAs failed image-boundary validation");
    }
    const auto enclosing = BudgetedRead(
        reader, enclosingRoot.Value(), 0, sizeof(FUObjectArrayLayout), budget);
    if (!enclosing) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            enclosing.Error().category, enclosing.Error().context);
    }
    const auto nested = enclosing.Value().ValueAt<TUObjectArrayLayout>(0x10);
    const auto direct = BudgetedRead(
        reader, objectRoot.Value(), 0, sizeof(TUObjectArrayLayout), budget);
    if (!nested) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            nested.Error().category, nested.Error().context);
    }
    if (!direct) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            direct.Error().category, direct.Error().context);
    }
    if (std::memcmp(
            &nested.Value(), direct.Value().Bytes().data(), sizeof(TUObjectArrayLayout)) != 0) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            ContractErrorCategory::MalformedLayout,
            "FUObjectArray +0x10 does not equal direct TUObjectArray root");
    }

    bool namesCaptured = false;
    for (std::uint32_t attempt = 0; attempt < limits.maximumRetries; ++attempt) {
        const auto firstHeader = BudgetedRead(
            reader, nameRoot.Value(), 0xC8, 8, budget);
        if (!firstHeader)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                firstHeader.Error().category, firstHeader.Error().context);
        const auto currentBlock = firstHeader.Value().ValueAt<std::uint32_t>(0);
        const auto cursor = firstHeader.Value().ValueAt<std::uint32_t>(4);
        if (!currentBlock || !cursor || currentBlock.Value() >= profile.fNameMaximumBlocks
            || currentBlock.Value() >= limits.maximumNameBlocks
            || cursor.Value() > profile.fNameBlockBytes
            || (cursor.Value() % profile.fNameStride) != 0) {
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                ContractErrorCategory::MalformedLayout,
                "FNamePool current block or cursor is outside bounded capacity");
        }
        FNamePoolSnapshot candidate;
        candidate.currentBlock_ = currentBlock.Value();
        candidate.currentByteCursor_ = cursor.Value();
        candidate.blocks_.reserve(static_cast<std::size_t>(currentBlock.Value()) + 1U);
        const std::size_t pointerBytes =
            (static_cast<std::size_t>(currentBlock.Value()) + 1U) * sizeof(std::uint64_t);
        const auto firstPointers = BudgetedRead(
            reader, nameRoot.Value(), 0xD0, pointerBytes, budget);
        if (!firstPointers)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                firstPointers.Error().category, firstPointers.Error().context);
        for (std::uint32_t block = 0; block <= currentBlock.Value(); ++block) {
            const std::size_t used = block == currentBlock.Value()
                ? cursor.Value() : profile.fNameBlockBytes;
            if (used == 0) {
                candidate.blocks_.emplace_back();
                continue;
            }
            const auto token = reader.DerivePointer(
                firstPointers.Value(), static_cast<std::size_t>(block) * sizeof(std::uint64_t),
                used, "FNamePool block");
            if (!token)
                return ContractResult<ReadOnlyContractSnapshot>::Failure(
                    token.Error().category, token.Error().context);
            const auto copied = BudgetedRead(reader, token.Value(), 0, used, budget);
            if (!copied)
                return ContractResult<ReadOnlyContractSnapshot>::Failure(
                    copied.Error().category, copied.Error().context);
            candidate.blocks_.emplace_back(
                copied.Value().Bytes().begin(), copied.Value().Bytes().end());
        }
        const auto secondHeader = BudgetedRead(
            reader, nameRoot.Value(), 0xC8, 8, budget);
        const auto secondPointers = BudgetedRead(
            reader, nameRoot.Value(), 0xD0, pointerBytes, budget);
        if (!secondHeader || !secondPointers)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                ContractErrorCategory::OutOfRange,
                "FNamePool stability resample failed");
        if (!SameBytes(firstHeader.Value(), secondHeader.Value())
            || !SameBytes(firstPointers.Value(), secondPointers.Value())) {
            output.report.retryOrAbortReason = "FNamePool header changed; bounded retry";
            continue;
        }
        candidate.RebuildViews();
        for (std::uint32_t block = 0; block <= candidate.currentBlock_; ++block) {
            const auto& bytes = candidate.blocks_[block];
            std::size_t offset = 0;
            while (offset + sizeof(std::uint16_t) <= bytes.size()) {
                std::uint16_t raw{};
                std::memcpy(&raw, bytes.data() + offset, sizeof(raw));
                const auto header = serverhost::v2::ue::FNamePoolView::DecodeHeader(raw);
                if (header.length == 0)
                    break;
                const std::size_t payload = static_cast<std::size_t>(header.length)
                    * (header.isWide ? sizeof(char16_t) : sizeof(char));
                const std::size_t entryBytes = AlignTwo(sizeof(raw) + payload);
                if (entryBytes > bytes.size() - offset)
                    break;
                const FName name{
                    static_cast<std::int32_t>((block << 16U) | (offset / 2U)), 0};
                const auto decoded = candidate.Resolve(name);
                if (decoded && std::find(kKnownNames.begin(), kKnownNames.end(), decoded.Value())
                        != kKnownNames.end()) {
                    candidate.indexedNames_.push_back({decoded.Value(), name});
                }
                ++candidate.entryCount_;
                offset += entryBytes;
            }
        }
        output.names = std::move(candidate);
        output.names.RebuildViews();
        namesCaptured = true;
        break;
    }
    if (!namesCaptured) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            ContractErrorCategory::ChangedDuringCapture,
            "FNamePool changed across every bounded retry");
    }

    std::vector<OwnedMemoryCopy> itemChunkCopies;
    std::vector<PrivateItem> privateItems;
    ObjectHeader acceptedHeader;
    bool objectsCaptured = false;
    for (std::uint32_t attempt = 0; attempt < limits.maximumRetries; ++attempt) {
        const auto first = BudgetedRead(
            reader, objectRoot.Value(), 0, sizeof(TUObjectArrayLayout), budget);
        if (!first)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                first.Error().category, first.Error().context);
        const auto parsed = ParseObjectHeader(first.Value());
        if (!parsed)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                parsed.Error().category, parsed.Error().context);
        const auto valid = ValidateObjectHeader(parsed.Value(), profile, limits);
        if (!valid)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                valid.Error().category, valid.Error().context);
        const std::size_t requiredChunks = parsed.Value().numElements == 0 ? 0
            : (static_cast<std::size_t>(parsed.Value().numElements)
                + profile.objectChunkItems - 1U) / profile.objectChunkItems;
        if (requiredChunks == 0) {
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                ContractErrorCategory::MalformedLayout,
                "exact build unexpectedly exposes an empty object array");
        }
        const std::size_t tableBytes = static_cast<std::size_t>(parsed.Value().numChunks)
            * sizeof(std::uint64_t);
        const auto tableToken = reader.DerivePointer(
            first.Value(), 0, tableBytes, "TUObjectArray chunk-pointer table");
        if (!tableToken)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                tableToken.Error().category, tableToken.Error().context);
        const auto table = BudgetedRead(reader, tableToken.Value(), 0, tableBytes, budget);
        if (!table)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                table.Error().category, table.Error().context);

        std::vector<OwnedMemoryCopy> candidateChunks;
        std::vector<PrivateItem> candidateItems;
        candidateChunks.reserve(requiredChunks);
        candidateItems.reserve(static_cast<std::size_t>(parsed.Value().numElements));
        for (std::size_t chunk = 0; chunk < requiredChunks; ++chunk) {
            const std::size_t firstIndex = chunk * profile.objectChunkItems;
            const std::size_t itemCount = std::min<std::size_t>(
                profile.objectChunkItems,
                static_cast<std::size_t>(parsed.Value().numElements) - firstIndex);
            const std::size_t chunkBytes = itemCount * profile.objectItemBytes;
            const auto chunkToken = reader.DerivePointer(
                table.Value(), chunk * sizeof(std::uint64_t), chunkBytes,
                "FUObjectItem chunk");
            if (!chunkToken)
                return ContractResult<ReadOnlyContractSnapshot>::Failure(
                    chunkToken.Error().category, chunkToken.Error().context);
            auto chunkCopy = BudgetedRead(reader, chunkToken.Value(), 0, chunkBytes, budget);
            if (!chunkCopy)
                return ContractResult<ReadOnlyContractSnapshot>::Failure(
                    chunkCopy.Error().category, chunkCopy.Error().context);
            for (std::size_t item = 0; item < itemCount; ++item) {
                const std::size_t offset = item * profile.objectItemBytes;
                const auto wire = chunkCopy.Value().ValueAt<FUObjectItemLayout>(offset);
                if (!wire)
                    return ContractResult<ReadOnlyContractSnapshot>::Failure(
                        wire.Error().category, wire.Error().context);
                const std::int32_t index = static_cast<std::int32_t>(firstIndex + item);
                candidateItems.push_back({
                    .objectWord = wire.Value().objectWord,
                    .publicItem = {
                        .objectIndex = index,
                        .serialNumber = wire.Value().serialNumber,
                        .clusterIndex = wire.Value().clusterIndex,
                        .isNull = wire.Value().objectWord == 0,
                        .unreachable = (wire.Value().flags & profile.unreachableMask) != 0,
                        .pendingKill = (wire.Value().flags & profile.pendingKillMask) != 0,
                        .malformed = wire.Value().serialNumber < 0,
                    },
                    .chunkIndex = chunk,
                    .itemOffset = offset,
                });
            }
            candidateChunks.push_back(std::move(chunkCopy.Value()));
        }
        const auto secondHeaderCopy = BudgetedRead(
            reader, objectRoot.Value(), 0, sizeof(TUObjectArrayLayout), budget);
        const auto secondTable = BudgetedRead(reader, tableToken.Value(), 0, tableBytes, budget);
        if (!secondHeaderCopy || !secondTable)
            return ContractResult<ReadOnlyContractSnapshot>::Failure(
                ContractErrorCategory::OutOfRange,
                "TUObjectArray stability resample failed");
        const auto secondHeader = ParseObjectHeader(secondHeaderCopy.Value());
        if (!secondHeader || secondHeader.Value() != parsed.Value()
            || !SameBytes(table.Value(), secondTable.Value())) {
            output.report.retryOrAbortReason = "TUObjectArray changed; bounded retry";
            continue;
        }
        acceptedHeader = parsed.Value();
        itemChunkCopies = std::move(candidateChunks);
        privateItems = std::move(candidateItems);
        objectsCaptured = true;
        break;
    }
    if (!objectsCaptured) {
        return ContractResult<ReadOnlyContractSnapshot>::Failure(
            ContractErrorCategory::ChangedDuringCapture,
            "TUObjectArray changed across every bounded retry");
    }

    output.objects.generation_ = generation;
    output.objects.num_ = acceptedHeader.numElements;
    output.objects.max_ = acceptedHeader.maxElements;
    output.objects.numChunks_ = acceptedHeader.numChunks;
    output.objects.maxChunks_ = acceptedHeader.maxChunks;
    output.objects.items_.reserve(privateItems.size());
    std::unordered_map<std::uint64_t, std::int32_t> indexByObjectWord;
    indexByObjectWord.reserve(privateItems.size());
    for (const PrivateItem& item : privateItems) {
        output.objects.items_.push_back(item.publicItem);
        if (item.publicItem.isNull) {
            ++output.report.nullObjects;
        } else if (item.publicItem.malformed) {
            ++output.report.malformedObjects;
        } else {
            ++output.report.validObjects;
            indexByObjectWord.insert_or_assign(item.objectWord, item.publicItem.objectIndex);
        }
        if (item.publicItem.pendingKill)
            ++output.report.pendingKillObjects;
        if (item.publicItem.unreachable)
            ++output.report.unreachableObjects;
    }

    std::unordered_map<std::int32_t, PrivateMetadata> metadata;
    const auto readMetadata = [&](std::int32_t index) -> ContractResult<PrivateMetadata> {
        if (const auto cached = metadata.find(index); cached != metadata.end())
            return ContractResult<PrivateMetadata>::Success(cached->second);
        if (index < 0 || static_cast<std::size_t>(index) >= privateItems.size()) {
            return ContractResult<PrivateMetadata>::Failure(
                ContractErrorCategory::OutOfRange, "metadata object index is out of range");
        }
        const PrivateItem& item = privateItems[static_cast<std::size_t>(index)];
        if (item.publicItem.isNull || item.publicItem.malformed) {
            return ContractResult<PrivateMetadata>::Failure(
                ContractErrorCategory::MalformedLayout, "metadata object item is null or malformed");
        }
        const auto objectToken = reader.DerivePointer(
            itemChunkCopies[item.chunkIndex], item.itemOffset, sizeof(UObjectLayout),
            "UObject metadata");
        if (!objectToken)
            return ContractResult<PrivateMetadata>::Failure(
                objectToken.Error().category, objectToken.Error().context);
        const auto objectCopy = BudgetedRead(
            reader, objectToken.Value(), 0, sizeof(UObjectLayout), budget);
        if (!objectCopy)
            return ContractResult<PrivateMetadata>::Failure(
                objectCopy.Error().category, objectCopy.Error().context);
        const auto wire = objectCopy.Value().ValueAt<UObjectLayout>(0);
        if (!wire || wire.Value().index != index || wire.Value().classObjectWord == 0) {
            return ContractResult<PrivateMetadata>::Failure(
                ContractErrorCategory::MalformedLayout,
                "UObject internal index or class relationship is invalid");
        }
        PrivateMetadata value{
            index, item.publicItem.serialNumber, wire.Value().name,
            wire.Value().classObjectWord, wire.Value().outerWord,
        };
        metadata.insert_or_assign(index, value);
        return ContractResult<PrivateMetadata>::Success(value);
    };

    const auto identityForWord = [&](std::uint64_t word) -> std::optional<ObjectIdentity> {
        if (word == 0)
            return std::nullopt;
        const auto found = indexByObjectWord.find(word);
        if (found == indexByObjectWord.end())
            return std::nullopt;
        const auto& item = privateItems[static_cast<std::size_t>(found->second)].publicItem;
        return ObjectIdentity{item.objectIndex, item.serialNumber, generation.value};
    };

    const auto buildOuterPath = [&](const PrivateMetadata& start)
        -> ContractResult<std::string> {
        std::vector<std::string> components;
        std::unordered_set<std::int32_t> visited;
        std::uint64_t nextWord = start.outerWord;
        while (nextWord != 0) {
            if (components.size() >= limits.maximumChainDepth) {
                return ContractResult<std::string>::Failure(
                    ContractErrorCategory::LimitExceeded, "outer chain depth exceeded");
            }
            const auto found = indexByObjectWord.find(nextWord);
            if (found == indexByObjectWord.end() || !visited.insert(found->second).second) {
                return ContractResult<std::string>::Failure(
                    ContractErrorCategory::MalformedLayout,
                    "outer chain has an unknown pointer or cycle");
            }
            const auto outerMetadata = readMetadata(found->second);
            if (!outerMetadata)
                return ContractResult<std::string>::Failure(
                    outerMetadata.Error().category, outerMetadata.Error().context);
            const auto outerName = output.names.Resolve(outerMetadata.Value().name);
            if (!outerName)
                return ContractResult<std::string>::Failure(
                    outerName.Error().category, outerName.Error().context);
            components.push_back(NormalizePackageName(outerName.Value()));
            nextWord = outerMetadata.Value().outerWord;
        }
        std::reverse(components.begin(), components.end());
        std::string path;
        for (const std::string& component : components) {
            if (!path.empty())
                path.push_back('.');
            path += component;
        }
        return ContractResult<std::string>::Success(std::move(path));
    };

    output.reflection.generation_ = generation;
    for (const profiles::KnownObjectSeed& seed : profile.knownObjectSeeds) {
        ContractCheck check{std::string(seed.expectedFullName), "fail", "not evaluated"};
        const auto target = readMetadata(seed.index);
        if (!target) {
            check.detail = target.Error().context;
            output.report.knownObjects.push_back(std::move(check));
            continue;
        }
        const auto objectName = output.names.Resolve(target.Value().name);
        const auto classIdentity = identityForWord(target.Value().classWord);
        const auto outerPath = buildOuterPath(target.Value());
        if (!objectName || !classIdentity || !outerPath) {
            check.detail = !objectName ? objectName.Error().context
                : !classIdentity ? "class pointer is absent from object snapshot"
                                 : outerPath.Error().context;
            output.report.knownObjects.push_back(std::move(check));
            continue;
        }
        const auto classMetadata = readMetadata(classIdentity->objectIndex);
        const auto className = classMetadata
            ? output.names.Resolve(classMetadata.Value().name)
            : ContractResult<std::string>::Failure(
                ContractErrorCategory::MalformedLayout, "class metadata is unavailable");
        if (!className) {
            check.detail = className.Error().context;
            output.report.knownObjects.push_back(std::move(check));
            continue;
        }
        std::string fullName = className.Value() + " ";
        if (!outerPath.Value().empty())
            fullName += outerPath.Value() + ".";
        fullName += objectName.Value();
        ReflectionIdentity reflected{
            .identity = {seed.index, target.Value().serial, generation.value},
            .name = target.Value().name,
            .objectName = objectName.Value(),
            .fullName = fullName,
            .className = className.Value(),
            .outer = identityForWord(target.Value().outerWord),
        };
        const PrivateItem& item = privateItems[static_cast<std::size_t>(seed.index)];
        const bool isFunction = className.Value() == "Function";
        const bool isClass = className.Value() == "Class";
        std::string relationshipError;
        if (isFunction || isClass) {
            const std::size_t extent = isFunction ? 0xB4 : 0x48;
            const auto extendedToken = reader.DerivePointer(
                itemChunkCopies[item.chunkIndex], item.itemOffset, extent,
                isFunction ? "UFunction flags" : "UStruct super");
            if (extendedToken) {
                const auto extended = BudgetedRead(reader, extendedToken.Value(), 0, extent, budget);
                if (extended && isFunction) {
                    const auto flags = extended.Value().ValueAt<std::uint32_t>(0xB0);
                    if (flags)
                        reflected.functionFlags = static_cast<serverhost::v2::ue::EFunctionFlags>(flags.Value());
                } else if (extended && isClass) {
                    const auto superWord = extended.Value().ValueAt<std::uint64_t>(0x40);
                    if (superWord) {
                        reflected.superStruct = identityForWord(superWord.Value());
                        std::uint64_t nextSuper = superWord.Value();
                        std::unordered_set<std::int32_t> visitedSupers{seed.index};
                        std::uint32_t depth = 0;
                        while (nextSuper != 0 && relationshipError.empty()) {
                            if (++depth > limits.maximumChainDepth) {
                                relationshipError = "super chain depth exceeded";
                                break;
                            }
                            const auto foundSuper = indexByObjectWord.find(nextSuper);
                            if (foundSuper == indexByObjectWord.end()) {
                                relationshipError = "super pointer is absent from object snapshot";
                                break;
                            }
                            if (!visitedSupers.insert(foundSuper->second).second) {
                                relationshipError = "super chain cycle detected";
                                break;
                            }
                            const PrivateItem& superItem =
                                privateItems[static_cast<std::size_t>(foundSuper->second)];
                            const auto superToken = reader.DerivePointer(
                                itemChunkCopies[superItem.chunkIndex], superItem.itemOffset,
                                0x48, "UStruct super chain");
                            if (!superToken) {
                                relationshipError = superToken.Error().context;
                                break;
                            }
                            const auto superCopy = BudgetedRead(
                                reader, superToken.Value(), 0, 0x48, budget);
                            if (!superCopy) {
                                relationshipError = superCopy.Error().context;
                                break;
                            }
                            const auto next = superCopy.Value().ValueAt<std::uint64_t>(0x40);
                            if (!next) {
                                relationshipError = next.Error().context;
                                break;
                            }
                            nextSuper = next.Value();
                        }
                    }
                }
            }
        }
        check.state = fullName == seed.expectedFullName && relationshipError.empty()
            ? "pass" : "fail";
        check.detail = !relationshipError.empty() ? relationshipError
            : fullName == seed.expectedFullName
            ? "full-name and class relationship matched"
            : "observed=" + fullName;
        output.report.knownObjects.push_back(check);
        output.reflection.knownObjects_.push_back(std::move(reflected));
    }

    for (std::string_view known : kKnownNames) {
        const auto name = output.names.Find(known);
        ContractCheck check{std::string(known), name ? "pass" : "fail",
                            name ? "owned-pool round trip" : "not found"};
        if (name) {
            const auto resolved = output.names.Resolve(*name);
            if (!resolved || resolved.Value() != known) {
                check.state = "fail";
                check.detail = "round trip mismatch";
            }
        }
        output.report.knownNames.push_back(std::move(check));
    }
    const bool allKnownObjectsPassed = std::all_of(
        output.report.knownObjects.begin(), output.report.knownObjects.end(),
        [](const ContractCheck& check) { return check.state == "pass"; });
    const bool functionFlagsAvailable = std::any_of(
        output.reflection.knownObjects_.begin(), output.reflection.knownObjects_.end(),
        [](const ReflectionIdentity& identity) {
            return identity.fullName
                    == "Function Engine.KismetStringLibrary.Conv_StringToName"
                && identity.functionFlags.has_value();
        });
    output.report.reflectionChecks.push_back({
        "UObject layout", allKnownObjectsPassed ? "pass" : "fail",
        "0x28 owned metadata; index/class/name/outer validators"});
    output.report.reflectionChecks.push_back({
        "UFunction flags", functionFlagsAvailable ? "pass" : "fail",
        "FunctionFlags at 0xB0; parameter ABI unavailable"});
    output.report.reflectionChecks.push_back({
        "Function parameters", "unavailable",
        "NumParms, ParmsSize and ReturnValueOffset were not proven"});
    output.report.reflectionChecks.push_back({
        "Native UE dispatch", "not-used", "evidence-only RVA; no engine call"});

    output.report.captureState = "complete";
    output.report.fNameBlocks = output.names.CurrentBlock() + 1U;
    output.report.fNameEntries = output.names.EntryCount();
    output.report.objectNum = output.objects.Num();
    output.report.objectMax = output.objects.Max();
    output.report.objectNumChunks = output.objects.NumChunks();
    output.report.objectMaxChunks = output.objects.MaxChunks();
    output.report.copiedBytes = budget.copiedBytes;
    output.report.durationMilliseconds = static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - budget.started).count());
    return ContractResult<ReadOnlyContractSnapshot>::Success(std::move(output));
}

}  // namespace serverhost::v2::bindings::ue
