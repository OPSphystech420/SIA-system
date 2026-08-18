#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/Bindings/Generated/Layouts_1_10280.hpp"
#include "SourceV2/Bindings/Platform/CheckedMemoryReader.hpp"
#include "SourceV2/Bindings/Platform/ExactProfileSelector.hpp"
#include "SourceV2/Bindings/Platform/ImageIdentityResolver.hpp"
#include "SourceV2/Bindings/Profiles/ReadOnlyContracts_1_10280.hpp"
#include "SourceV2/Bindings/UE/ReadOnlySnapshotCapture.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

namespace serverhost::v2::tests {
namespace {

using namespace bindings::platform;
using namespace bindings::generated::ios_1_10280;
using bindings::ue::CaptureLimits;
using bindings::ue::ReadOnlySnapshotCapture;

constexpr std::uint32_t kMachMagic64 = 0xFEEDFACF;
constexpr std::uint32_t kCpuArm64 = 0x0100000C;
constexpr std::uint32_t kFileExecute = 2;
constexpr std::uint32_t kSegment64 = 0x19;
constexpr std::uint32_t kUuid = 0x1B;
constexpr std::uintptr_t kImageBase = 0x100000000ULL;
constexpr std::uint64_t kNameRva = 0x6000;
constexpr std::uint64_t kFUObjectRva = 0x17000;
constexpr std::uint64_t kObjectRva = kFUObjectRva + 0x10;
constexpr std::uintptr_t kNameBlockAddress = 0x200000000ULL;
constexpr std::uintptr_t kChunkTableAddress = 0x210000000ULL;
constexpr std::uintptr_t kItemChunkAddress = 0x220000000ULL;
constexpr std::uintptr_t kMetadataAddress = 0x230000000ULL;
constexpr std::size_t kObjectCount = 0x410E;
constexpr std::size_t kMetadataStride = 0x100;

#pragma pack(push, 1)
struct HeaderWire final {
    std::uint32_t magic;
    std::uint32_t cpuType;
    std::uint32_t cpuSubtype;
    std::uint32_t fileType;
    std::uint32_t commandCount;
    std::uint32_t commandBytes;
    std::uint32_t flags;
    std::uint32_t reserved;
};
struct SegmentWire final {
    std::uint32_t command;
    std::uint32_t commandSize;
    char name[16];
    std::uint64_t virtualAddress;
    std::uint64_t virtualSize;
    std::uint64_t fileOffset;
    std::uint64_t fileSize;
    std::uint32_t maximumProtection;
    std::uint32_t initialProtection;
    std::uint32_t sectionCount;
    std::uint32_t flags;
};
struct SectionWire final {
    char sectionName[16];
    char segmentName[16];
    std::uint64_t address;
    std::uint64_t size;
    std::uint32_t offset;
    std::uint32_t alignment;
    std::uint32_t relocationOffset;
    std::uint32_t relocationCount;
    std::uint32_t flags;
    std::uint32_t reserved1;
    std::uint32_t reserved2;
    std::uint32_t reserved3;
};
struct UuidWire final {
    std::uint32_t command;
    std::uint32_t commandSize;
    std::uint8_t uuid[16];
};
#pragma pack(pop)

template <typename T>
void Append(std::vector<std::byte>& bytes, const T& value) {
    const std::size_t offset = bytes.size();
    bytes.resize(offset + sizeof(value));
    std::memcpy(bytes.data() + offset, &value, sizeof(value));
}

template <typename T>
void Store(std::vector<std::byte>& bytes, std::size_t offset, const T& value) {
    std::memcpy(bytes.data() + offset, &value, sizeof(value));
}

void CopyName(char destination[16], std::string_view name) {
    std::memcpy(destination, name.data(), std::min<std::size_t>(name.size(), 15));
}

std::vector<std::byte> BuildMachOPrefix() {
    struct Description final {
        const char* name;
        std::uint64_t address;
        std::uint64_t virtualSize;
        std::uint64_t fileOffset;
        std::uint64_t fileSize;
        std::uint32_t permissions;
        bool textSection;
    };
    const std::array descriptions{
        Description{"__PAGEZERO", 0, kImageBase, 0, 0, ImagePermissionNone, false},
        Description{"__TEXT", kImageBase, 0x4000, 0, 0x4000,
                    ImagePermissionRead | ImagePermissionExecute, true},
        Description{"__DATA_CONST", kImageBase + 0x4000, 0x2000, 0x4000, 0x2000,
                    ImagePermissionRead | ImagePermissionWrite, false},
        Description{"__DATA", kImageBase + 0x6000, 0x20000, 0x6000, 0x20000,
                    ImagePermissionRead | ImagePermissionWrite, false},
        Description{"__LINKEDIT", kImageBase + 0x26000, 0x1000, 0x26000, 0x1000,
                    ImagePermissionRead, false},
    };
    std::vector<std::byte> commands;
    for (const auto& description : descriptions) {
        SegmentWire segment{};
        segment.command = kSegment64;
        segment.commandSize = sizeof(SegmentWire)
            + (description.textSection ? sizeof(SectionWire) : 0);
        CopyName(segment.name, description.name);
        segment.virtualAddress = description.address;
        segment.virtualSize = description.virtualSize;
        segment.fileOffset = description.fileOffset;
        segment.fileSize = description.fileSize;
        segment.maximumProtection = description.permissions;
        segment.initialProtection = description.permissions;
        segment.sectionCount = description.textSection ? 1 : 0;
        Append(commands, segment);
        if (description.textSection) {
            SectionWire section{};
            CopyName(section.sectionName, "__text");
            CopyName(section.segmentName, "__TEXT");
            section.address = kImageBase + 0x1000;
            section.size = 16;
            section.offset = 0x1000;
            Append(commands, section);
        }
    }
    UuidWire uuid{};
    uuid.command = kUuid;
    uuid.commandSize = sizeof(UuidWire);
    for (std::size_t index = 0; index < sizeof(uuid.uuid); ++index)
        uuid.uuid[index] = static_cast<std::uint8_t>(index + 0x31);
    Append(commands, uuid);

    HeaderWire header{};
    header.magic = kMachMagic64;
    header.cpuType = kCpuArm64;
    header.fileType = kFileExecute;
    header.commandCount = descriptions.size() + 1;
    header.commandBytes = static_cast<std::uint32_t>(commands.size());
    std::vector<std::byte> result;
    Append(result, header);
    result.insert(result.end(), commands.begin(), commands.end());
    return result;
}

class SparseMemorySource final : public IMemorySource {
public:
    struct Region final {
        std::uintptr_t base{};
        std::vector<std::byte> bytes;
    };

    void Add(std::uintptr_t base, std::vector<std::byte> bytes) {
        regions_.push_back({base, std::move(bytes)});
    }

    template <typename T>
    void Write(std::uintptr_t address, const T& value) {
        Region& region = RegionFor(address, sizeof(value));
        std::memcpy(region.bytes.data() + (address - region.base), &value, sizeof(value));
    }

    void FailAt(std::uintptr_t address) { failingAddress_ = address; }
    void FlipDestinationOnHit(
        std::uintptr_t address, std::size_t hit, std::size_t destinationOffset) {
        mutationAddress_ = address;
        mutationHit_ = hit;
        mutationOffset_ = destinationOffset;
    }

    ContractResult<void> Copy(
        std::uintptr_t address, std::span<std::byte> destination) const override {
        if (failingAddress_.has_value() && address == *failingAddress_) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange, "synthetic VM region unmapped");
        }
        for (const Region& region : regions_) {
            if (address < region.base || destination.size() > region.bytes.size()
                || address - region.base > region.bytes.size() - destination.size()) {
                continue;
            }
            std::memcpy(destination.data(), region.bytes.data() + (address - region.base),
                        destination.size());
            if (mutationAddress_.has_value() && address == *mutationAddress_) {
                const std::size_t hit = ++mutationAddressHits_;
                if (hit == mutationHit_ && mutationOffset_ < destination.size())
                    destination[mutationOffset_] ^= std::byte{0x1};
            }
            return ContractResult<void>::Success();
        }
        return ContractResult<void>::Failure(
            ContractErrorCategory::OutOfRange,
            "synthetic read is outside one registered region");
    }

private:
    Region& RegionFor(std::uintptr_t address, std::size_t size) {
        for (Region& region : regions_) {
            if (address >= region.base && size <= region.bytes.size()
                && address - region.base <= region.bytes.size() - size) {
                return region;
            }
        }
        std::abort();
    }

    std::vector<Region> regions_;
    std::optional<std::uintptr_t> failingAddress_;
    std::optional<std::uintptr_t> mutationAddress_;
    std::size_t mutationHit_{};
    std::size_t mutationOffset_{};
    mutable std::size_t mutationAddressHits_{};
};

struct Fixture final {
    std::shared_ptr<SparseMemorySource> memory;
    CheckedMemoryReader reader;
    bindings::profiles::ReadOnlyContractProfile profile;
};

bindings::BuildProfile IdentityProfile(const ResolvedImageIdentity& resolved) {
    return {
        .profileId = "synthetic-gate2b",
        .platform = resolved.identity.platform,
        .product = resolved.identity.product,
        .version = resolved.identity.version,
        .expectedArchitecture = resolved.identity.architecture,
        .expectedRole = resolved.identity.role,
        .expectedImageUuid = resolved.identity.imageUuid,
        .expectedTextFingerprint = resolved.identity.textFingerprint,
        .expectedTextFingerprintRange = resolved.identity.textFingerprintRange,
        .expectedTextFingerprintSize = resolved.identity.textFingerprintSize,
        .expectedSegments = resolved.identity.segments,
        .expectedStableImagePrefixSize = resolved.identity.stableImagePrefixSize,
        .identityEvidenceComplete = true,
    };
}

Fixture MakeFixture() {
    auto memory = std::make_shared<SparseMemorySource>();
    std::vector<std::byte> image(0x27000);
    const auto prefix = BuildMachOPrefix();
    std::copy(prefix.begin(), prefix.end(), image.begin());
    for (std::size_t index = 0; index < 16; ++index)
        image[0x1000 + index] = static_cast<std::byte>(0x80 + index);

    std::vector<std::byte> nameBlock(0x20000);
    std::unordered_map<std::string, serverhost::v2::ue::FName> names;
    std::size_t nameCursor = 0;
    const auto addName = [&](std::string_view value, bool wide = false) {
        const std::uint16_t header = static_cast<std::uint16_t>(
            (value.size() << 6U) | (wide ? 1U : 0U));
        const std::size_t offset = nameCursor;
        Store(nameBlock, nameCursor, header);
        nameCursor += sizeof(header);
        if (wide) {
            for (char character : value) {
                const char16_t unit = static_cast<unsigned char>(character);
                Store(nameBlock, nameCursor, unit);
                nameCursor += sizeof(unit);
            }
        } else {
            std::memcpy(nameBlock.data() + nameCursor, value.data(), value.size());
            nameCursor += value.size();
        }
        nameCursor = (nameCursor + 1U) & ~std::size_t{1};
        names.insert_or_assign(
            std::string(value), serverhost::v2::ue::FName{
                static_cast<std::int32_t>(offset / 2U), 0});
    };
    addName("None");
    addName("Object");
    addName("Class");
    addName("Function");
    addName("World", true);
    addName("Engine");
    addName("GameEngine");
    addName("GameViewportClient");
    addName("NetDriver");
    addName("GameNetDriver");
    addName("CoreUObject");
    addName("KismetStringLibrary");
    addName("Conv_StringToName");

    Store(image, kNameRva + 0xC8, std::uint32_t{0});
    Store(image, kNameRva + 0xCC, static_cast<std::uint32_t>(nameCursor));
    Store(image, kNameRva + 0xD0, kNameBlockAddress);

    std::vector<std::byte> chunk(kObjectCount * sizeof(FUObjectItemLayout));
    std::vector<std::byte> metadata(kObjectCount * kMetadataStride);
    const auto objectAddress = [](std::int32_t index) {
        return static_cast<std::uint64_t>(
            kMetadataAddress + static_cast<std::size_t>(index) * kMetadataStride);
    };
    const std::array<std::int32_t, 12> populated{
        0x1, 0x2, 0x3, 0x4, 0x44, 0x1A8, 0x266, 0x358,
        0x37F, 0x380, 0x712, 0x410D,
    };
    for (const std::int32_t index : populated) {
        FUObjectItemLayout item{
            .objectWord = objectAddress(index),
            .flags = 0,
            .clusterIndex = 0,
            .serialNumber = index + 100,
            .pad_0014 = 0,
        };
        Store(chunk, static_cast<std::size_t>(index) * sizeof(item), item);
    }
    const auto writeObject = [&](std::int32_t index, std::string_view name,
                                 std::int32_t classIndex,
                                 std::optional<std::int32_t> outerIndex) {
        UObjectLayout object{};
        object.vtableWord = 0x5555;
        object.index = index;
        object.classObjectWord = objectAddress(classIndex);
        object.name = names.at(std::string(name));
        object.outerWord = outerIndex ? objectAddress(*outerIndex) : 0;
        Store(metadata, static_cast<std::size_t>(index) * kMetadataStride, object);
    };
    writeObject(0x2, "CoreUObject", 0x37F, std::nullopt);
    writeObject(0x3, "Engine", 0x37F, std::nullopt);
    writeObject(0x4, "KismetStringLibrary", 0x37F, 0x3);
    writeObject(0x37F, "Class", 0x37F, 0x2);
    writeObject(0x380, "Function", 0x37F, 0x2);
    writeObject(0x1, "Object", 0x37F, 0x2);
    writeObject(0x44, "NetDriver", 0x37F, 0x3);
    writeObject(0x1A8, "Engine", 0x37F, 0x3);
    writeObject(0x266, "GameViewportClient", 0x37F, 0x3);
    writeObject(0x358, "GameEngine", 0x37F, 0x3);
    writeObject(0x712, "World", 0x37F, 0x3);
    writeObject(0x410D, "Conv_StringToName", 0x380, 0x4);
    Store(metadata, static_cast<std::size_t>(0x410D) * kMetadataStride + 0xB0,
          static_cast<std::uint32_t>(serverhost::v2::ue::EFunctionFlags::Native));

    std::vector<std::byte> table(sizeof(std::uint64_t));
    Store(table, 0, kItemChunkAddress);
    TUObjectArrayLayout direct{
        .objectsWord = kChunkTableAddress,
        .preAllocatedObjectsWord = 0,
        .maxElements = 0x10000,
        .numElements = static_cast<std::int32_t>(kObjectCount),
        .maxChunks = 1,
        .numChunks = 1,
    };
    FUObjectArrayLayout enclosing{};
    enclosing.objObjects = direct;
    Store(image, kFUObjectRva, enclosing);

    memory->Add(kImageBase, std::move(image));
    memory->Add(kNameBlockAddress, std::move(nameBlock));
    memory->Add(kChunkTableAddress, std::move(table));
    memory->Add(kItemChunkAddress, std::move(chunk));
    memory->Add(kMetadataAddress, std::move(metadata));

    LoadedImageRecord record{
        .path = "/Applications/ShooterGame.app/ShooterGame",
        .imageName = "ShooterGame",
        .isDyldMainExecutable = true,
        .headerAddress = kImageBase,
        .slide = 0,
        .headerAndLoadCommands = prefix,
    };
    const ImageIdentityResolver resolver;
    const auto resolved = resolver.Resolve(record, *memory, "synthetic");
    const bindings::BuildProfile identity = IdentityProfile(resolved.Value());
    const ExactProfileSelector selector;
    const ExactProfileSelection selected = selector.Select(
        LoadedImageCatalog({record}), {&identity, 1}, *memory);
    auto reader = CheckedMemoryReader::Create(*selected.match, memory);

    auto profile = bindings::profiles::kReadOnlyContractsIOS_1_10280;
    profile.identityProfileId = "synthetic-gate2b";
    profile.fNamePoolRva = kNameRva;
    profile.fuObjectArrayRva = kFUObjectRva;
    profile.directObjectArrayRva = kObjectRva;
    profile.knownObjectSeeds = {{
        {0x1, "Class CoreUObject.Object"},
        {0x44, "Class Engine.NetDriver"},
        {0x1A8, "Class Engine.Engine"},
        {0x266, "Class Engine.GameViewportClient"},
        {0x358, "Class Engine.GameEngine"},
        {0x37F, "Class CoreUObject.Class"},
        {0x380, "Class CoreUObject.Function"},
        {0x712, "Class Engine.World"},
        {0x410D, "Function Engine.KismetStringLibrary.Conv_StringToName"},
    }};
    return {memory, reader.Value(), profile};
}

bool AllPassed(const std::vector<ContractCheck>& checks) {
    return std::all_of(checks.begin(), checks.end(), [](const ContractCheck& check) {
        return check.state == "pass";
    });
}

}  // namespace

void RunReadOnlySnapshotCaptureTests(TestContext& context) {
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(
        0x106651180, 0x100A9C000) == 0x5BB5180);
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(
        0x10A08D180, 0x1044D8000) == 0x5BB5180);
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(
        0x1067DF4E8, 0x100A9C000) == 0x5D434E8);
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(
        0x10A21B4E8, 0x1044D8000) == 0x5D434E8);
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(
        0x1068564F0, 0x100A9C000) == 0x5DBA4F0);
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(
        0x10A2924F0, 0x1044D8000) == 0x5DBA4F0);
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(
        0x102F9D47C, 0x100A9C000) == 0x250147C);
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(
        0x1069D947C, 0x1044D8000) == 0x250147C);
    V2_EXPECT(context,
        bindings::profiles::kReadOnlyContractsIOS_1_10280.fuObjectArrayRva + 0x10
            == bindings::profiles::kReadOnlyContractsIOS_1_10280.directObjectArrayRva);
    V2_EXPECT(context, bindings::profiles::NormalizeDumpAddress(1, 2)
        == std::numeric_limits<std::uint64_t>::max());

    Fixture fixture = MakeFixture();
    ReadOnlySnapshotCapture capture;
    auto result = capture.Capture(fixture.reader, fixture.profile, {1}, {});
    V2_EXPECT(context, result);
    V2_EXPECT(context, result.Value().report.captureState == "complete");
    V2_EXPECT(context, result.Value().report.scansStarted == 1);
    V2_EXPECT(context, result.Value().report.hooks == 0);
    V2_EXPECT(context, result.Value().report.engineCalls == 0);
    V2_EXPECT(context, result.Value().report.mutation == 0);
    V2_EXPECT(context, result.Value().report.objectNum == static_cast<std::int32_t>(kObjectCount));
    V2_EXPECT(context, AllPassed(result.Value().report.knownNames));
    V2_EXPECT(context, AllPassed(result.Value().report.knownObjects));
    const auto knownFunction = result.Value().reflection.FindFunction(
        "Function Engine.KismetStringLibrary.Conv_StringToName", {1});
    V2_EXPECT(context, knownFunction && knownFunction.Value().functionFlags.has_value());
    V2_EXPECT(context, !result.Value().reflection.FindByFullName(
        "Function Engine.KismetStringLibrary.Conv_StringToName", {2}));
    V2_EXPECT(context, result.Value().reflection.FindClass(
        "Class CoreUObject.Object", {1}));
    V2_EXPECT(context, !result.Value().reflection.FindFunction(
        "Class CoreUObject.Object", {1}));
    const ObjectIdentity oldIdentity = knownFunction.Value().identity;
    V2_EXPECT(context, result.Value().objects.Resolve(oldIdentity, {1}));
    V2_EXPECT(context, !result.Value().objects.Resolve(oldIdentity, {2}));

    Fixture retryNames = MakeFixture();
    retryNames.memory->FlipDestinationOnHit(kImageBase + kNameRva + 0xC8, 2, 0);
    auto retriedNames = capture.Capture(retryNames.reader, retryNames.profile, {2}, {});
    V2_EXPECT(context, retriedNames);
    V2_EXPECT(context, retriedNames.Value().report.retryOrAbortReason.find("FNamePool")
        != std::string::npos);

    Fixture retryObjects = MakeFixture();
    retryObjects.memory->FlipDestinationOnHit(kChunkTableAddress, 2, 0);
    auto retriedObjects = capture.Capture(retryObjects.reader, retryObjects.profile, {3}, {});
    V2_EXPECT(context, retriedObjects);
    V2_EXPECT(context, retriedObjects.Value().report.retryOrAbortReason.find("TUObjectArray")
        != std::string::npos);

    Fixture retryObjectHeader = MakeFixture();
    retryObjectHeader.memory->FlipDestinationOnHit(
        kImageBase + kObjectRva, 3, 0x14);
    auto retriedObjectHeader = capture.Capture(
        retryObjectHeader.reader, retryObjectHeader.profile, {31}, {});
    V2_EXPECT(context, retriedObjectHeader);
    V2_EXPECT(context,
        retriedObjectHeader.Value().report.retryOrAbortReason.find("TUObjectArray")
            != std::string::npos);

    Fixture unmapped = MakeFixture();
    unmapped.memory->FailAt(kNameBlockAddress);
    V2_EXPECT(context, !capture.Capture(unmapped.reader, unmapped.profile, {4}, {}));

    Fixture wrongRva = MakeFixture();
    wrongRva.profile.fNamePoolRva = std::numeric_limits<std::uint64_t>::max();
    V2_EXPECT(context, !capture.Capture(wrongRva.reader, wrongRva.profile, {5}, {}));

    Fixture wrongProfile = MakeFixture();
    wrongProfile.profile.identityProfileId = "unsupported-profile";
    const auto wrongProfileResult = capture.Capture(
        wrongProfile.reader, wrongProfile.profile, {51}, {});
    V2_EXPECT(context, !wrongProfileResult
        && wrongProfileResult.Error().category == ContractErrorCategory::UnsupportedProfile);

    Fixture badCursor = MakeFixture();
    badCursor.memory->Write(kImageBase + kNameRva + 0xCC, std::uint32_t{0x20002});
    V2_EXPECT(context, !capture.Capture(badCursor.reader, badCursor.profile, {6}, {}));

    Fixture badObjectHeader = MakeFixture();
    badObjectHeader.memory->Write(kImageBase + kObjectRva + 0x10, std::int32_t{100});
    const auto badObjectHeaderResult = capture.Capture(
        badObjectHeader.reader, badObjectHeader.profile, {7}, {});
    V2_EXPECT(context, !badObjectHeaderResult);
    V2_EXPECT(context, badObjectHeaderResult.Error().context.find("num=")
        != std::string::npos);
    V2_EXPECT(context, badObjectHeaderResult.Error().context.find("num_chunks=")
        != std::string::npos);
    V2_EXPECT(context, badObjectHeaderResult.Error().context.find("0x")
        == std::string::npos);

    Fixture reservedCapacity = MakeFixture();
    reservedCapacity.memory->Write(
        kImageBase + kObjectRva + 0x10, std::int32_t{0x2000000});
    reservedCapacity.memory->Write(
        kImageBase + kObjectRva + 0x18, std::int32_t{0x200});
    const auto reservedCapacityResult = capture.Capture(
        reservedCapacity.reader, reservedCapacity.profile, {71}, {});
    V2_EXPECT(context, reservedCapacityResult);
    V2_EXPECT(context, reservedCapacityResult.Value().report.objectMax == 0x2000000);
    V2_EXPECT(context, reservedCapacityResult.Value().report.objectMaxChunks == 0x200);

    Fixture insufficientCapacityChunks = MakeFixture();
    insufficientCapacityChunks.memory->Write(
        kImageBase + kObjectRva + 0x10, std::int32_t{0x20000});
    const auto insufficientCapacityResult = capture.Capture(
        insufficientCapacityChunks.reader, insufficientCapacityChunks.profile, {72}, {});
    V2_EXPECT(context, !insufficientCapacityResult);
    V2_EXPECT(context, insufficientCapacityResult.Error().context.find("chunk envelope")
        != std::string::npos);

    Fixture configuredCapacityLimit = MakeFixture();
    CaptureLimits configuredCapacityLimits;
    configuredCapacityLimits.maximumObjectCapacity = 0x8000;
    const auto configuredCapacityResult = capture.Capture(
        configuredCapacityLimit.reader, configuredCapacityLimit.profile, {73},
        configuredCapacityLimits);
    V2_EXPECT(context, !configuredCapacityResult
        && configuredCapacityResult.Error().category == ContractErrorCategory::LimitExceeded);

    Fixture allocatedChunkLimit = MakeFixture();
    allocatedChunkLimit.memory->Write(
        kImageBase + kObjectRva + 0x10, std::int32_t{0x810000});
    allocatedChunkLimit.memory->Write(
        kImageBase + kObjectRva + 0x18, std::int32_t{129});
    allocatedChunkLimit.memory->Write(
        kImageBase + kObjectRva + 0x1C, std::int32_t{129});
    const auto allocatedChunkResult = capture.Capture(
        allocatedChunkLimit.reader, allocatedChunkLimit.profile, {74}, {});
    V2_EXPECT(context, !allocatedChunkResult
        && allocatedChunkResult.Error().category == ContractErrorCategory::LimitExceeded);

    Fixture nullChunk = MakeFixture();
    nullChunk.memory->Write(kChunkTableAddress, std::uint64_t{0});
    V2_EXPECT(context, !capture.Capture(nullChunk.reader, nullChunk.profile, {8}, {}));

    Fixture malformedName = MakeFixture();
    malformedName.memory->Write(
        kMetadataAddress + kMetadataStride + 0x18,
        serverhost::v2::ue::FName{0x7FFFFFFF, 0});
    auto malformedNameResult = capture.Capture(
        malformedName.reader, malformedName.profile, {9}, {});
    V2_EXPECT(context, malformedNameResult);
    V2_EXPECT(context, !AllPassed(malformedNameResult.Value().report.knownObjects));

    Fixture malformedIndex = MakeFixture();
    malformedIndex.memory->Write(
        kMetadataAddress + kMetadataStride + 0xC, std::int32_t{2});
    auto malformedIndexResult = capture.Capture(
        malformedIndex.reader, malformedIndex.profile, {91}, {});
    V2_EXPECT(context, malformedIndexResult);
    V2_EXPECT(context, !AllPassed(malformedIndexResult.Value().report.knownObjects));

    Fixture unknownClass = MakeFixture();
    unknownClass.memory->Write(
        kMetadataAddress + kMetadataStride + 0x10, std::uint64_t{0xDEADBEEF});
    auto unknownClassResult = capture.Capture(
        unknownClass.reader, unknownClass.profile, {92}, {});
    V2_EXPECT(context, unknownClassResult);
    V2_EXPECT(context, !AllPassed(unknownClassResult.Value().report.knownObjects));

    Fixture outerCycle = MakeFixture();
    outerCycle.memory->Write(
        kMetadataAddress + kMetadataStride + 0x20,
        static_cast<std::uint64_t>(kMetadataAddress + kMetadataStride));
    auto outerCycleResult = capture.Capture(outerCycle.reader, outerCycle.profile, {10}, {});
    V2_EXPECT(context, outerCycleResult);
    V2_EXPECT(context, !AllPassed(outerCycleResult.Value().report.knownObjects));

    Fixture superCycle = MakeFixture();
    superCycle.memory->Write(
        kMetadataAddress + kMetadataStride + 0x40,
        static_cast<std::uint64_t>(kMetadataAddress + kMetadataStride));
    auto superCycleResult = capture.Capture(superCycle.reader, superCycle.profile, {11}, {});
    V2_EXPECT(context, superCycleResult);
    V2_EXPECT(context, !AllPassed(superCycleResult.Value().report.knownObjects));

    Fixture depthLimited = MakeFixture();
    CaptureLimits depthLimits;
    depthLimits.maximumChainDepth = 0;
    auto depthLimitResult = capture.Capture(
        depthLimited.reader, depthLimited.profile, {111}, depthLimits);
    V2_EXPECT(context, depthLimitResult);
    V2_EXPECT(context, !AllPassed(depthLimitResult.Value().report.knownObjects));

    Fixture flags = MakeFixture();
    const std::uintptr_t firstItem = kItemChunkAddress + sizeof(FUObjectItemLayout);
    flags.memory->Write(firstItem + 0x8, std::uint32_t{0x30000000});
    flags.memory->Write(firstItem + 0x10, std::int32_t{-1});
    auto flagsResult = capture.Capture(flags.reader, flags.profile, {12}, {});
    V2_EXPECT(context, flagsResult);
    V2_EXPECT(context, flagsResult.Value().report.pendingKillObjects == 1);
    V2_EXPECT(context, flagsResult.Value().report.unreachableObjects == 1);
    V2_EXPECT(context, flagsResult.Value().report.malformedObjects == 1);

    std::atomic_bool cancelled{true};
    Fixture cancelledFixture = MakeFixture();
    const auto cancelledResult = capture.Capture(
        cancelledFixture.reader, cancelledFixture.profile, {13}, {}, &cancelled);
    V2_EXPECT(context, !cancelledResult
        && cancelledResult.Error().category == ContractErrorCategory::Cancelled);

    Fixture byteLimited = MakeFixture();
    CaptureLimits byteLimits;
    byteLimits.maximumCopiedBytes = 64;
    const auto byteLimitResult = capture.Capture(
        byteLimited.reader, byteLimited.profile, {14}, byteLimits);
    V2_EXPECT(context, !byteLimitResult
        && byteLimitResult.Error().category == ContractErrorCategory::LimitExceeded);

    Fixture objectLimited = MakeFixture();
    CaptureLimits objectLimits;
    objectLimits.maximumObjects = 100;
    V2_EXPECT(context, !capture.Capture(
        objectLimited.reader, objectLimited.profile, {15}, objectLimits));

    Fixture timeLimited = MakeFixture();
    CaptureLimits timeLimits;
    timeLimits.maximumDuration = std::chrono::milliseconds{-1};
    const auto timeLimitResult = capture.Capture(
        timeLimited.reader, timeLimited.profile, {16}, timeLimits);
    V2_EXPECT(context, !timeLimitResult
        && timeLimitResult.Error().category == ContractErrorCategory::LimitExceeded);
}

}  // namespace serverhost::v2::tests
