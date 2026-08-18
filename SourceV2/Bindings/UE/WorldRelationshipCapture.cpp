#include "SourceV2/Bindings/UE/WorldRelationshipCapture.hpp"

#include "SourceV2/Bindings/Generated/Layouts_1_10280.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstring>
#include <limits>
#include <optional>
#include <span>
#include <string_view>
#include <unordered_set>
#include <utility>

namespace serverhost::v2::bindings::ue {
namespace {

using generated::ios_1_10280::FNetDriverDefinitionLayout;
using generated::ios_1_10280::TArrayHeaderLayout;
using generated::ios_1_10280::UObjectLayout;
using model::engine::CanonicalArrayHeader;
using platform::MemoryReadKind;
using platform::OwnedMemoryCopy;

constexpr std::size_t kEngineExtent = 0xC08;
constexpr std::size_t kGameViewportExtent = 0x78;
constexpr std::size_t kWorldExtent = 0x2C8;
constexpr std::size_t kObjectExtent = sizeof(UObjectLayout);
constexpr std::size_t kClassExtent = 0x48;

bool SameBytes(const OwnedMemoryCopy& left, const OwnedMemoryCopy& right) {
    return left.Bytes().size() == right.Bytes().size()
        && std::equal(left.Bytes().begin(), left.Bytes().end(), right.Bytes().begin());
}

std::string NormalizePackageName(std::string name) {
    constexpr std::string_view prefix = "/Script/";
    if (name.starts_with(prefix))
        name.erase(0, prefix.size());
    return name;
}

bool IsStrictShooterEngineFullName(std::string_view fullName) {
    constexpr std::string_view prefix = "ShooterEngine Transient.ShooterEngine_";
    if (!fullName.starts_with(prefix) || fullName.size() == prefix.size())
        return false;
    return std::all_of(
        fullName.begin() + static_cast<std::ptrdiff_t>(prefix.size()), fullName.end(),
        [](char value) { return std::isdigit(static_cast<unsigned char>(value)) != 0; });
}

struct CaptureBudget final {
    const RelationshipCaptureLimits& limits;
    const std::atomic_bool* cancellation;
    std::chrono::steady_clock::time_point started{std::chrono::steady_clock::now()};
    std::uint64_t copiedBytes{};

    ContractResult<void> BeforeCopy(std::size_t bytes) {
        if (cancellation != nullptr && cancellation->load(std::memory_order_relaxed)) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::Cancelled,
                "relationship capture cancelled");
        }
        if (std::chrono::steady_clock::now() - started > limits.maximumDuration) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::LimitExceeded,
                "relationship capture time limit exceeded");
        }
        if (bytes > limits.maximumCopiedBytes
            || copiedBytes > limits.maximumCopiedBytes - bytes) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::LimitExceeded,
                "relationship capture byte limit exceeded");
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

struct BasicObject final {
    ObjectIdentity identity;
    UObjectLayout wire;
};

struct DescribedObject final {
    ObjectIdentity identity;
    serverhost::v2::ue::EObjectFlags flags{serverhost::v2::ue::EObjectFlags::None};
    std::string objectName;
    std::string className;
    std::string fullName;
    std::int32_t directClassIndex{-1};
};

}  // namespace

class WorldRelationshipReadBoundary final {
public:
    WorldRelationshipReadBoundary(
        const platform::CheckedMemoryReader& reader,
        const ReadOnlyContractSnapshot& snapshot, CaptureBudget& budget)
        : reader_(reader), snapshot_(snapshot), budget_(budget) {}

    ContractResult<std::optional<ObjectIdentity>> IdentityForWord(std::uint64_t word) const {
        if (word == 0)
            return ContractResult<std::optional<ObjectIdentity>>::Success(std::nullopt);
        std::optional<ObjectIdentity> result;
        for (std::size_t index = 0; index < snapshot_.objects.ownedRecords_.size(); ++index) {
            const auto& record = snapshot_.objects.ownedRecords_[index];
            if (record.objectWord != word)
                continue;
            if (result.has_value()) {
                return ContractResult<std::optional<ObjectIdentity>>::Failure(
                    ContractErrorCategory::MalformedLayout,
                    "relationship pointer matches multiple object-array identities");
            }
            const auto& item = snapshot_.objects.items_[index];
            if (item.isNull || item.malformed || item.pendingKill || item.unreachable) {
                return ContractResult<std::optional<ObjectIdentity>>::Failure(
                    ContractErrorCategory::StaleIdentity,
                    "relationship pointer resolves to a non-live object-array item");
            }
            result = ObjectIdentity{
                item.objectIndex, item.serialNumber, snapshot_.generation.value};
        }
        if (!result.has_value()) {
            return ContractResult<std::optional<ObjectIdentity>>::Failure(
                ContractErrorCategory::NotFound,
                "relationship pointer is absent from the fresh object snapshot");
        }
        return ContractResult<std::optional<ObjectIdentity>>::Success(result);
    }

    ContractResult<OwnedMemoryCopy> ReadExtent(
        ObjectIdentity identity, std::size_t extent, std::string expectedType) {
        const auto resolved = snapshot_.objects.Resolve(identity, snapshot_.generation);
        if (!resolved) {
            return ContractResult<OwnedMemoryCopy>::Failure(
                resolved.Error().category, resolved.Error().context);
        }
        const std::size_t index = static_cast<std::size_t>(identity.objectIndex);
        if (index >= snapshot_.objects.ownedRecords_.size()) {
            return ContractResult<OwnedMemoryCopy>::Failure(
                ContractErrorCategory::OutOfRange,
                "relationship identity is outside owned object records");
        }
        const auto& record = snapshot_.objects.ownedRecords_[index];
        if (record.chunkIndex >= snapshot_.objects.ownedItemChunks_.size()) {
            return ContractResult<OwnedMemoryCopy>::Failure(
                ContractErrorCategory::MalformedLayout,
                "relationship object has no owned chunk provenance");
        }
        const auto token = reader_.DerivePointer(
            snapshot_.objects.ownedItemChunks_[record.chunkIndex], record.itemOffset,
            extent, std::move(expectedType));
        if (!token) {
            return ContractResult<OwnedMemoryCopy>::Failure(
                token.Error().category, token.Error().context);
        }
        const auto copy = BudgetedRead(reader_, token.Value(), 0, extent, budget_);
        if (!copy)
            return copy;
        const auto internalIndex = copy.Value().ValueAt<std::int32_t>(0xC);
        if (!internalIndex || internalIndex.Value() != identity.objectIndex) {
            return ContractResult<OwnedMemoryCopy>::Failure(
                ContractErrorCategory::MalformedLayout,
                "relationship UObject internal index does not match its fresh identity");
        }
        return copy;
    }

    ContractResult<BasicObject> ReadBasic(ObjectIdentity identity) {
        const auto copy = ReadExtent(identity, kObjectExtent, "UObject relationship metadata");
        if (!copy)
            return ContractResult<BasicObject>::Failure(
                copy.Error().category, copy.Error().context);
        const auto wire = copy.Value().ValueAt<UObjectLayout>(0);
        if (!wire || wire.Value().classObjectWord == 0) {
            return ContractResult<BasicObject>::Failure(
                ContractErrorCategory::MalformedLayout,
                "relationship UObject has no class identity");
        }
        return ContractResult<BasicObject>::Success({identity, wire.Value()});
    }

    ContractResult<DescribedObject> Describe(ObjectIdentity identity) {
        const auto basic = ReadBasic(identity);
        if (!basic)
            return ContractResult<DescribedObject>::Failure(
                basic.Error().category, basic.Error().context);
        const auto classIdentity = IdentityForWord(basic.Value().wire.classObjectWord);
        if (!classIdentity || !classIdentity.Value().has_value()) {
            return ContractResult<DescribedObject>::Failure(
                classIdentity ? ContractErrorCategory::MalformedLayout
                              : classIdentity.Error().category,
                classIdentity ? "relationship class pointer is null"
                              : classIdentity.Error().context);
        }
        const auto classBasic = ReadBasic(*classIdentity.Value());
        if (!classBasic) {
            return ContractResult<DescribedObject>::Failure(
                classBasic.Error().category, classBasic.Error().context);
        }
        const auto objectName = snapshot_.names.Resolve(basic.Value().wire.name);
        const auto className = snapshot_.names.Resolve(classBasic.Value().wire.name);
        if (!objectName || !className) {
            const auto& error = !objectName ? objectName.Error() : className.Error();
            return ContractResult<DescribedObject>::Failure(
                error.category, "relationship FName validation failed: " + error.context);
        }

        std::vector<std::string> outers;
        std::unordered_set<std::int32_t> visited;
        std::uint64_t outerWord = basic.Value().wire.outerWord;
        while (outerWord != 0) {
            if (outers.size() >= maximumChainDepth_) {
                return ContractResult<DescribedObject>::Failure(
                    ContractErrorCategory::LimitExceeded,
                    "relationship outer chain depth exceeded");
            }
            const auto outerIdentity = IdentityForWord(outerWord);
            if (!outerIdentity || !outerIdentity.Value().has_value()) {
                return ContractResult<DescribedObject>::Failure(
                    outerIdentity ? ContractErrorCategory::MalformedLayout
                                  : outerIdentity.Error().category,
                    outerIdentity ? "relationship outer pointer is null"
                                  : outerIdentity.Error().context);
            }
            if (!visited.insert(outerIdentity.Value()->objectIndex).second) {
                return ContractResult<DescribedObject>::Failure(
                    ContractErrorCategory::MalformedLayout,
                    "relationship outer chain contains a cycle");
            }
            const auto outer = ReadBasic(*outerIdentity.Value());
            if (!outer) {
                return ContractResult<DescribedObject>::Failure(
                    outer.Error().category, outer.Error().context);
            }
            const auto name = snapshot_.names.Resolve(outer.Value().wire.name);
            if (!name) {
                return ContractResult<DescribedObject>::Failure(
                    name.Error().category,
                    "relationship outer FName validation failed: " + name.Error().context);
            }
            outers.push_back(NormalizePackageName(name.Value()));
            outerWord = outer.Value().wire.outerWord;
        }
        std::reverse(outers.begin(), outers.end());
        std::string fullName = className.Value() + " ";
        for (const std::string& outer : outers) {
            fullName += outer;
            fullName.push_back('.');
        }
        fullName += objectName.Value();
        return ContractResult<DescribedObject>::Success({
            identity, basic.Value().wire.flags, objectName.Value(), className.Value(),
            std::move(fullName), classIdentity.Value()->objectIndex});
    }

    ContractResult<void> RequireIsA(
        const DescribedObject& object, std::int32_t expectedClassIndex,
        std::string_view expectedClassName) {
        if (expectedClassIndex < 0
            || static_cast<std::size_t>(expectedClassIndex)
                >= snapshot_.objects.items_.size()) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange,
                "required relationship class index is outside the fresh object snapshot");
        }
        const auto& expectedItem = snapshot_.objects.items_[
            static_cast<std::size_t>(expectedClassIndex)];
        const ObjectIdentity expectedIdentity{
            expectedClassIndex, expectedItem.serialNumber,
            snapshot_.generation.value};
        const auto expectedClass = Describe(expectedIdentity);
        const std::string expectedFullName =
            "Class Engine." + std::string(expectedClassName);
        if (!expectedClass
            || expectedClass.Value().className != "Class"
            || expectedClass.Value().objectName != expectedClassName
            || expectedClass.Value().fullName != expectedFullName) {
            return ContractResult<void>::Failure(
                expectedClass ? ContractErrorCategory::TypeMismatch
                              : expectedClass.Error().category,
                expectedClass
                    ? "required relationship class anchor failed exact name/full-name validation"
                    : expectedClass.Error().context);
        }
        std::int32_t classIndex = object.directClassIndex;
        std::unordered_set<std::int32_t> visited;
        for (std::uint32_t depth = 0; depth < maximumChainDepth_; ++depth) {
            if (classIndex == expectedClassIndex)
                return ContractResult<void>::Success();
            if (classIndex < 0 || !visited.insert(classIndex).second) {
                return ContractResult<void>::Failure(
                    ContractErrorCategory::MalformedLayout,
                    "relationship class chain is invalid or cyclic");
            }
            if (static_cast<std::size_t>(classIndex) >= snapshot_.objects.items_.size()) {
                return ContractResult<void>::Failure(
                    ContractErrorCategory::OutOfRange,
                    "relationship class index is outside the fresh object snapshot");
            }
            const auto item = snapshot_.objects.Resolve(
                {classIndex, snapshot_.objects.items_[static_cast<std::size_t>(classIndex)].serialNumber,
                 snapshot_.generation.value},
                snapshot_.generation);
            if (!item) {
                return ContractResult<void>::Failure(
                    item.Error().category, item.Error().context);
            }
            const ObjectIdentity classIdentity{
                classIndex, item.Value().serialNumber, snapshot_.generation.value};
            const auto classCopy = ReadExtent(classIdentity, kClassExtent, "UClass super chain");
            if (!classCopy)
                return ContractResult<void>::Failure(
                    classCopy.Error().category, classCopy.Error().context);
            const auto superWord = classCopy.Value().ValueAt<std::uint64_t>(0x40);
            if (!superWord)
                return ContractResult<void>::Failure(
                    superWord.Error().category, superWord.Error().context);
            if (superWord.Value() == 0)
                break;
            const auto superIdentity = IdentityForWord(superWord.Value());
            if (!superIdentity || !superIdentity.Value().has_value()) {
                return ContractResult<void>::Failure(
                    superIdentity ? ContractErrorCategory::MalformedLayout
                                  : superIdentity.Error().category,
                    superIdentity ? "class super pointer is null"
                                  : superIdentity.Error().context);
            }
            classIndex = superIdentity.Value()->objectIndex;
        }
        return ContractResult<void>::Failure(
            ContractErrorCategory::TypeMismatch,
            "relationship object is not in the required "
                + std::string(expectedClassName) + " class chain");
    }

    void SetMaximumChainDepth(std::uint32_t value) { maximumChainDepth_ = value; }

private:
    const platform::CheckedMemoryReader& reader_;
    const ReadOnlyContractSnapshot& snapshot_;
    CaptureBudget& budget_;
    std::uint32_t maximumChainDepth_{32};
};

namespace {

ContractCheck Pass(std::string label, std::string detail) {
    return {std::move(label), "pass", std::move(detail)};
}

ContractCheck Normal(std::string label, std::string detail) {
    return {std::move(label), "normal", std::move(detail)};
}

template <typename T>
ContractResult<T> FailFrom(const ContractError& error) {
    return ContractResult<T>::Failure(error.category, error.context);
}

}  // namespace

ContractResult<WorldRelationshipCaptureResult> WorldRelationshipCapture::Capture(
    const platform::CheckedMemoryReader& reader,
    const profiles::LiveRelationshipProfile& profile,
    const ReadOnlyContractSnapshot& freshSnapshot,
    model::engine::WorldGenerationTracker& generationTracker,
    const RelationshipCaptureLimits& limits,
    const std::atomic_bool* cancellation) const {
    if (freshSnapshot.generation.value == 0 || limits.maximumDefinitions < 0
        || limits.maximumDefinitionCapacity < limits.maximumDefinitions
        || limits.maximumChainDepth == 0) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::InvalidArgument,
            "invalid Gate 2C relationship capture configuration");
    }
    if (!reader.CanUseProfile(profile.identityProfileId)) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::UnsupportedProfile,
            "checked reader and Gate 2C relationship profile do not match");
    }
    CaptureBudget budget{limits, cancellation};
    WorldRelationshipReadBoundary relationships(reader, freshSnapshot, budget);
    relationships.SetMaximumChainDepth(limits.maximumChainDepth);
    WorldRelationshipCaptureResult output;
    output.snapshot.discoveryGeneration = freshSnapshot.generation.value;

    const auto gEngineToken = reader.ResolveImageRva(
        profile.gEngineRva, sizeof(std::uint64_t), MemoryReadKind::ReadableData);
    const auto gWorldToken = reader.ResolveImageRva(
        profile.gWorldRva, sizeof(std::uint64_t), MemoryReadKind::ReadableData);
    if (!gEngineToken || !gWorldToken) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::OutOfRange,
            "one or more exact Gate 2C native roots failed image validation");
    }
    const auto gEngineFirst = BudgetedRead(
        reader, gEngineToken.Value(), 0, sizeof(std::uint64_t), budget);
    const auto gWorldFirst = BudgetedRead(
        reader, gWorldToken.Value(), 0, sizeof(std::uint64_t), budget);
    if (!gEngineFirst || !gWorldFirst) {
        const auto& error = !gEngineFirst ? gEngineFirst.Error() : gWorldFirst.Error();
        return FailFrom<WorldRelationshipCaptureResult>(error);
    }
    const auto engineWord = gEngineFirst.Value().ValueAt<std::uint64_t>(0);
    const auto gWorldWord = gWorldFirst.Value().ValueAt<std::uint64_t>(0);
    if (!engineWord || !gWorldWord || engineWord.Value() == 0) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::MalformedLayout,
            "native Engine root is null or malformed");
    }

    const auto engineIdentity = relationships.IdentityForWord(engineWord.Value());
    if (!engineIdentity || !engineIdentity.Value().has_value()) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            engineIdentity ? ContractErrorCategory::NotFound : engineIdentity.Error().category,
            engineIdentity ? "native Engine root did not resolve uniquely"
                           : engineIdentity.Error().context);
    }
    const auto engineDescription = relationships.Describe(*engineIdentity.Value());
    if (!engineDescription)
        return FailFrom<WorldRelationshipCaptureResult>(engineDescription.Error());
    if (engineDescription.Value().directClassIndex != profile.shooterEngineClassIndex
        || engineDescription.Value().className != "ShooterEngine"
        || !IsStrictShooterEngineFullName(engineDescription.Value().fullName)) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::TypeMismatch,
            "native Engine identity failed exact ShooterEngine class/full-name validators");
    }
    if (serverhost::v2::ue::HasAllFlags(
            engineDescription.Value().flags,
            serverhost::v2::ue::EObjectFlags::ClassDefaultObject)) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::TypeMismatch,
            "native Engine identity is a class default object");
    }
    const auto isGameEngine = relationships.RequireIsA(
        engineDescription.Value(), profile.gameEngineClassIndex, "GameEngine");
    const auto isEngine = relationships.RequireIsA(
        engineDescription.Value(), profile.engineClassIndex, "Engine");
    if (!isGameEngine || !isEngine)
        return FailFrom<WorldRelationshipCaptureResult>(
            !isGameEngine ? isGameEngine.Error() : isEngine.Error());
    output.snapshot.engine = {
        engineDescription.Value().identity,
        engineDescription.Value().fullName,
        engineDescription.Value().className};
    output.engineChecks.push_back(Pass(
        "native ownership", "GEngine root resolved to one fresh live object identity"));
    output.engineChecks.push_back(Pass(
        "identity/full name/class", "unique non-CDO ShooterEngine with GameEngine/Engine chain"));

    const auto engineCopy = relationships.ReadExtent(
        engineDescription.Value().identity, kEngineExtent, "UEngine relationship fields");
    if (!engineCopy)
        return FailFrom<WorldRelationshipCaptureResult>(engineCopy.Error());
    const auto viewportWord = engineCopy.Value().ValueAt<std::uint64_t>(
        profile.engineGameViewportOffset);
    const auto definitionsHeader = engineCopy.Value().ValueAt<TArrayHeaderLayout>(
        profile.engineNetDriverDefinitionsOffset);
    if (!viewportWord || !definitionsHeader) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::MalformedLayout,
            "Engine relationship fields are truncated");
    }

    const CanonicalArrayHeader canonicalHeader{
        definitionsHeader.Value().dataWord != 0,
        definitionsHeader.Value().num,
        definitionsHeader.Value().max};
    const auto headerValid = model::engine::ValidateCanonicalArrayHeader(
        canonicalHeader, limits.maximumDefinitions, limits.maximumDefinitionCapacity);
    if (!headerValid)
        return FailFrom<WorldRelationshipCaptureResult>(headerValid.Error());
    output.snapshot.netDriverDefinitions.canonicalEmpty =
        definitionsHeader.Value().dataWord == 0;
    output.snapshot.netDriverDefinitions.count = definitionsHeader.Value().num;
    output.snapshot.netDriverDefinitions.capacity = definitionsHeader.Value().max;
    if (definitionsHeader.Value().num == 0) {
        if (definitionsHeader.Value().dataWord != 0) {
            const auto definitionsToken = reader.DerivePointer(
                engineCopy.Value(), profile.engineNetDriverDefinitionsOffset,
                1, "allocated-empty FNetDriverDefinition storage");
            if (!definitionsToken)
                return FailFrom<WorldRelationshipCaptureResult>(definitionsToken.Error());
            const auto readable = BudgetedRead(
                reader, definitionsToken.Value(), 0, 1, budget);
            if (!readable)
                return FailFrom<WorldRelationshipCaptureResult>(readable.Error());
        }
        output.netDriverDefinitionChecks.push_back(Normal(
            "TArray header", definitionsHeader.Value().dataWord == 0
                ? "canonical empty {Data=null, Num=0, Max=0}"
                : "allocated empty array with bounded capacity"));
    } else {
        const std::size_t count = static_cast<std::size_t>(definitionsHeader.Value().num);
        if (profile.netDriverDefinitionBytes != sizeof(FNetDriverDefinitionLayout)
            || count > std::numeric_limits<std::size_t>::max()
                    / profile.netDriverDefinitionBytes) {
            return ContractResult<WorldRelationshipCaptureResult>::Failure(
                ContractErrorCategory::MalformedLayout,
                "FNetDriverDefinition stride or extent is invalid");
        }
        const std::size_t bytes = count * profile.netDriverDefinitionBytes;
        const auto definitionsToken = reader.DerivePointer(
            engineCopy.Value(), profile.engineNetDriverDefinitionsOffset,
            bytes, "FNetDriverDefinition array");
        if (!definitionsToken)
            return FailFrom<WorldRelationshipCaptureResult>(definitionsToken.Error());
        const auto definitions = BudgetedRead(
            reader, definitionsToken.Value(), 0, bytes, budget);
        if (!definitions)
            return FailFrom<WorldRelationshipCaptureResult>(definitions.Error());
        std::uint32_t gameNetDriverCount = 0;
        for (std::size_t index = 0; index < count; ++index) {
            const auto definition = definitions.Value().ValueAt<FNetDriverDefinitionLayout>(
                index * profile.netDriverDefinitionBytes);
            if (!definition) {
                return ContractResult<WorldRelationshipCaptureResult>::Failure(
                    definition.Error().category,
                    "FNetDriverDefinition entry is truncated");
            }
            const auto defName = freshSnapshot.names.Resolve(definition.Value().defName);
            const auto primary = freshSnapshot.names.Resolve(
                definition.Value().driverClassName);
            const auto fallback = freshSnapshot.names.Resolve(
                definition.Value().driverClassNameFallback);
            if (!defName || !primary || !fallback) {
                const auto& error = !defName ? defName.Error()
                    : !primary ? primary.Error() : fallback.Error();
                return ContractResult<WorldRelationshipCaptureResult>::Failure(
                    error.category,
                    "FNetDriverDefinition contains an invalid FName: " + error.context);
            }
            if (defName.Value() == "GameNetDriver")
                ++gameNetDriverCount;
            output.snapshot.netDriverDefinitions.definitions.push_back({
                defName.Value(), primary.Value(), fallback.Value()});
        }
        if (gameNetDriverCount > 1) {
            return ContractResult<WorldRelationshipCaptureResult>::Failure(
                ContractErrorCategory::MalformedLayout,
                "NetDriverDefinitions contains duplicate GameNetDriver entries");
        }
        output.netDriverDefinitionChecks.push_back(Pass(
            "TArray header", "bounded populated array with 0x18-byte definitions"));
        output.netDriverDefinitionChecks.push_back({
            "GameNetDriver uniqueness", gameNetDriverCount == 1 ? "pass" : "normal",
            gameNetDriverCount == 1 ? "one primary/fallback definition decoded"
                                    : "GameNetDriver is absent"});
    }

    std::optional<ObjectIdentity> viewportIdentity;
    std::optional<DescribedObject> viewportDescription;
    std::uint64_t viewportWorldWord = 0;
    std::optional<OwnedMemoryCopy> viewportCopy;
    if (viewportWord.Value() == 0) {
        output.gameViewportChecks.push_back(Normal(
            "GameViewport", "none during a permitted menu/loading lifecycle"));
    } else {
        const auto resolved = relationships.IdentityForWord(viewportWord.Value());
        if (!resolved || !resolved.Value().has_value()) {
            return ContractResult<WorldRelationshipCaptureResult>::Failure(
                resolved ? ContractErrorCategory::NotFound : resolved.Error().category,
                resolved ? "GameViewport pointer did not resolve"
                         : resolved.Error().context);
        }
        viewportIdentity = *resolved.Value();
        const auto described = relationships.Describe(*viewportIdentity);
        if (!described)
            return FailFrom<WorldRelationshipCaptureResult>(described.Error());
        const auto validClass = relationships.RequireIsA(
            described.Value(), profile.gameViewportClientClassIndex,
            "GameViewportClient");
        if (!validClass)
            return FailFrom<WorldRelationshipCaptureResult>(validClass.Error());
        viewportDescription = described.Value();
        const auto copy = relationships.ReadExtent(
            *viewportIdentity, kGameViewportExtent, "UGameViewportClient relationship fields");
        if (!copy)
            return FailFrom<WorldRelationshipCaptureResult>(copy.Error());
        const auto worldWord = copy.Value().ValueAt<std::uint64_t>(
            profile.gameViewportWorldOffset);
        if (!worldWord)
            return FailFrom<WorldRelationshipCaptureResult>(worldWord.Error());
        viewportWorldWord = worldWord.Value();
        viewportCopy = copy.Value();
        output.gameViewportChecks.push_back(Pass(
            "identity/full name/class", "fresh GameViewportClient relationship validated"));
    }

    if (gWorldWord.Value() != 0 && viewportWorldWord != 0
        && gWorldWord.Value() != viewportWorldWord) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::ChangedDuringCapture,
            "GWorld/ViewportWorld mismatch");
    }
    const std::uint64_t selectedWorldWord = viewportWorldWord != 0
        ? viewportWorldWord : gWorldWord.Value();
    std::optional<ObjectIdentity> worldIdentity;
    std::optional<DescribedObject> worldDescription;
    std::optional<OwnedMemoryCopy> worldCopy;
    std::optional<DescribedObject> netDriverDescription;
    std::optional<DescribedObject> gameModeDescription;
    std::optional<DescribedObject> gameStateDescription;
    if (selectedWorldWord != 0) {
        const auto resolved = relationships.IdentityForWord(selectedWorldWord);
        if (!resolved || !resolved.Value().has_value()) {
            return ContractResult<WorldRelationshipCaptureResult>::Failure(
                resolved ? ContractErrorCategory::NotFound : resolved.Error().category,
                resolved ? "World pointer is absent from the fresh object snapshot"
                         : resolved.Error().context);
        }
        worldIdentity = *resolved.Value();
        const auto described = relationships.Describe(*worldIdentity);
        if (!described)
            return FailFrom<WorldRelationshipCaptureResult>(described.Error());
        const auto validClass = relationships.RequireIsA(
            described.Value(), profile.worldClassIndex, "World");
        if (!validClass)
            return FailFrom<WorldRelationshipCaptureResult>(validClass.Error());
        worldDescription = described.Value();
        const auto copy = relationships.ReadExtent(
            *worldIdentity, kWorldExtent, "UWorld relationship fields");
        if (!copy)
            return FailFrom<WorldRelationshipCaptureResult>(copy.Error());
        worldCopy = copy.Value();
        const auto netDriverWord = copy.Value().ValueAt<std::uint64_t>(
            profile.worldNetDriverOffset);
        const auto gameModeWord = copy.Value().ValueAt<std::uint64_t>(
            profile.worldAuthorityGameModeOffset);
        const auto gameStateWord = copy.Value().ValueAt<std::uint64_t>(
            profile.worldGameStateOffset);
        if (!netDriverWord || !gameModeWord || !gameStateWord) {
            return ContractResult<WorldRelationshipCaptureResult>::Failure(
                ContractErrorCategory::MalformedLayout,
                "World relationship fields are truncated");
        }
        const auto validateOptional = [&relationships](
            std::uint64_t word, std::int32_t classIndex, std::string_view className)
            -> ContractResult<std::optional<DescribedObject>> {
            if (word == 0)
                return ContractResult<std::optional<DescribedObject>>::Success(std::nullopt);
            const auto identity = relationships.IdentityForWord(word);
            if (!identity || !identity.Value().has_value()) {
                return ContractResult<std::optional<DescribedObject>>::Failure(
                    identity ? ContractErrorCategory::NotFound : identity.Error().category,
                    identity ? "optional World relationship did not resolve"
                             : identity.Error().context);
            }
            const auto described = relationships.Describe(*identity.Value());
            if (!described)
                return ContractResult<std::optional<DescribedObject>>::Failure(
                    described.Error().category, described.Error().context);
            const auto validClass = relationships.RequireIsA(
                described.Value(), classIndex, className);
            if (!validClass)
                return ContractResult<std::optional<DescribedObject>>::Failure(
                    validClass.Error().category, validClass.Error().context);
            return ContractResult<std::optional<DescribedObject>>::Success(described.Value());
        };
        const auto netDriver = validateOptional(
            netDriverWord.Value(), profile.netDriverClassIndex, "NetDriver");
        const auto gameMode = validateOptional(
            gameModeWord.Value(), profile.gameModeBaseClassIndex, "GameModeBase");
        const auto gameState = validateOptional(
            gameStateWord.Value(), profile.gameStateBaseClassIndex, "GameStateBase");
        if (!netDriver || !gameMode || !gameState) {
            const auto& error = !netDriver ? netDriver.Error()
                : !gameMode ? gameMode.Error() : gameState.Error();
            return FailFrom<WorldRelationshipCaptureResult>(error);
        }
        netDriverDescription = netDriver.Value();
        gameModeDescription = gameMode.Value();
        gameStateDescription = gameState.Value();
        output.worldChecks.push_back(Pass(
            "identity/full name/class", "fresh World identity and class chain validated"));
        output.worldChecks.push_back({
            "GWorld vs ViewportWorld",
            gWorldWord.Value() != 0 && viewportWorldWord != 0 ? "pass" : "normal",
            gWorldWord.Value() != 0 && viewportWorldWord != 0
                ? "same generation-bound World identity"
                : "one lifecycle root is null; comparison not applicable"});
        output.netDriverChecks.push_back({
            "NetDriver", netDriverDescription.has_value() ? "pass" : "normal",
            netDriverDescription.has_value()
                ? "fresh NetDriver class relationship; hosting not inferred"
                : "net_driver=none"});
    } else {
        output.worldChecks.push_back(Normal(
            "World", "none in a permitted main-menu/loading lifecycle"));
        output.netDriverChecks.push_back(Normal("NetDriver", "net_driver=none"));
    }

    const auto engineSecond = relationships.ReadExtent(
        engineDescription.Value().identity, kEngineExtent, "UEngine stability sample");
    const auto gEngineSecond = BudgetedRead(
        reader, gEngineToken.Value(), 0, sizeof(std::uint64_t), budget);
    const auto gWorldSecond = BudgetedRead(
        reader, gWorldToken.Value(), 0, sizeof(std::uint64_t), budget);
    if (!engineSecond || !gEngineSecond || !gWorldSecond) {
        const auto& error = !engineSecond ? engineSecond.Error()
            : !gEngineSecond ? gEngineSecond.Error() : gWorldSecond.Error();
        return FailFrom<WorldRelationshipCaptureResult>(error);
    }
    const std::span<const std::byte> firstViewportField = engineCopy.Value().Bytes().subspan(
        profile.engineGameViewportOffset, sizeof(std::uint64_t));
    const std::span<const std::byte> secondViewportField = engineSecond.Value().Bytes().subspan(
        profile.engineGameViewportOffset, sizeof(std::uint64_t));
    const std::span<const std::byte> firstDefinitionsHeader = engineCopy.Value().Bytes().subspan(
        profile.engineNetDriverDefinitionsOffset, sizeof(TArrayHeaderLayout));
    const std::span<const std::byte> secondDefinitionsHeader = engineSecond.Value().Bytes().subspan(
        profile.engineNetDriverDefinitionsOffset, sizeof(TArrayHeaderLayout));
    if (!SameBytes(gEngineFirst.Value(), gEngineSecond.Value())
        || !SameBytes(gWorldFirst.Value(), gWorldSecond.Value())
        || !std::equal(firstViewportField.begin(), firstViewportField.end(),
                       secondViewportField.begin(), secondViewportField.end())
        || !std::equal(firstDefinitionsHeader.begin(), firstDefinitionsHeader.end(),
                       secondDefinitionsHeader.begin(), secondDefinitionsHeader.end())) {
        return ContractResult<WorldRelationshipCaptureResult>::Failure(
            ContractErrorCategory::ChangedDuringCapture,
            "Engine or World relationship roots changed during capture");
    }
    if (viewportIdentity.has_value()) {
        const auto second = relationships.ReadExtent(
            *viewportIdentity, kGameViewportExtent, "GameViewport stability sample");
        if (!second || !viewportCopy.has_value() || !SameBytes(*viewportCopy, second.Value())) {
            return ContractResult<WorldRelationshipCaptureResult>::Failure(
                ContractErrorCategory::ChangedDuringCapture,
                "GameViewport relationships changed during capture");
        }
    }
    if (worldIdentity.has_value()) {
        const auto second = relationships.ReadExtent(
            *worldIdentity, kWorldExtent, "World stability sample");
        if (!second || !worldCopy.has_value() || !SameBytes(*worldCopy, second.Value())) {
            return ContractResult<WorldRelationshipCaptureResult>::Failure(
                ContractErrorCategory::ChangedDuringCapture,
                "World relationships changed during capture");
        }
    }

    const auto withinFinalBudget = budget.BeforeCopy(0);
    if (!withinFinalBudget)
        return FailFrom<WorldRelationshipCaptureResult>(withinFinalBudget.Error());

    std::optional<model::engine::StableWorldIdentity> stableWorld;
    if (worldDescription.has_value()) {
        stableWorld = model::engine::StableWorldIdentity{
            worldDescription->identity.objectIndex,
            worldDescription->identity.serialNumber,
            worldDescription->className + "|" + worldDescription->fullName};
    }
    const auto observed = generationTracker.Observe(std::move(stableWorld));
    if (!observed)
        return FailFrom<WorldRelationshipCaptureResult>(observed.Error());
    output.snapshot.worldGeneration = observed.Value().generation;
    output.snapshot.previousWorldInvalidated = observed.Value().previousWorldInvalidated;
    const auto bind = [&output](const DescribedObject& object) {
        return model::engine::WorldBoundIdentity{
            object.identity, output.snapshot.worldGeneration};
    };
    if (viewportDescription.has_value()) {
        output.snapshot.gameViewport = model::engine::GameViewportView{
            bind(*viewportDescription), viewportDescription->fullName,
            viewportDescription->className};
    }
    if (worldDescription.has_value()) {
        output.snapshot.world = model::engine::WorldView{
            bind(*worldDescription), worldDescription->fullName,
            worldDescription->className, worldDescription->objectName};
    }
    if (netDriverDescription.has_value()) {
        output.snapshot.netDriver = model::engine::NetDriverView{
            bind(*netDriverDescription), netDriverDescription->fullName,
            netDriverDescription->className};
    }
    if (gameModeDescription.has_value()) {
        output.snapshot.authorityGameMode = model::engine::OptionalWorldObjectView{
            bind(*gameModeDescription), gameModeDescription->fullName,
            gameModeDescription->className};
    }
    if (gameStateDescription.has_value()) {
        output.snapshot.gameState = model::engine::OptionalWorldObjectView{
            bind(*gameStateDescription), gameStateDescription->fullName,
            gameStateDescription->className};
    }
    if (selectedWorldWord == 0 && viewportWord.Value() != 0) {
        output.snapshot.lifecycleState = "main-menu";
    } else if (selectedWorldWord == 0) {
        output.snapshot.lifecycleState = "loading";
    } else if (gWorldWord.Value() == 0 || viewportWorldWord == 0) {
        output.snapshot.lifecycleState = "loading";
    } else {
        output.snapshot.lifecycleState = "map";
    }
    output.snapshot.worldRelationshipState =
        gWorldWord.Value() != 0 && viewportWorldWord != 0 ? "match" : "not-comparable";
    output.generationChecks.push_back(Pass(
        "discovery generation",
        "fresh Gate 2B snapshot generation="
            + std::to_string(output.snapshot.discoveryGeneration)));
    output.generationChecks.push_back({
        "world generation", "pass",
        "generation=" + std::to_string(output.snapshot.worldGeneration)
            + " previous_world_invalidated="
            + (output.snapshot.previousWorldInvalidated ? "yes" : "no")});
    output.copiedBytes = budget.copiedBytes;
    output.durationMilliseconds = static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - budget.started).count());
    return ContractResult<WorldRelationshipCaptureResult>::Success(std::move(output));
}

}  // namespace serverhost::v2::bindings::ue
