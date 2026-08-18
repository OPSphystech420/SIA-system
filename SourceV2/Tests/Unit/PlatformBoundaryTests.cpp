#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/Bindings/Platform/CheckedMemoryReader.hpp"
#include "SourceV2/Bindings/Platform/ExactProfileSelector.hpp"
#include "SourceV2/Bindings/Platform/ImageIdentityResolver.hpp"
#include "SourceV2/Bindings/Platform/LoadedImageCatalog.hpp"
#include "SourceV2/Bindings/Platform/MachOImageView.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>
#include <memory>
#include <span>
#include <string>
#include <utility>
#include <vector>

namespace serverhost::v2::tests {
namespace {

using namespace bindings::platform;

constexpr std::uint32_t kMachMagic64 = 0xFEEDFACF;
constexpr std::uint32_t kCpuArm64 = 0x0100000C;
constexpr std::uint32_t kCpuX86_64 = 0x01000007;
constexpr std::uint32_t kFileExecute = 2;
constexpr std::uint32_t kSegment64 = 0x19;
constexpr std::uint32_t kUuid = 0x1B;
constexpr std::uintptr_t kImageBase = 0x100000000ULL;

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

static_assert(sizeof(HeaderWire) == 32);
static_assert(sizeof(SegmentWire) == 72);
static_assert(sizeof(SectionWire) == 80);
static_assert(sizeof(UuidWire) == 24);

template <typename T>
void Append(std::vector<std::byte>& bytes, const T& value) {
    const std::size_t offset = bytes.size();
    bytes.resize(offset + sizeof(value));
    std::memcpy(bytes.data() + offset, &value, sizeof(value));
}

void CopyName(char destination[16], std::string_view name) {
    const std::size_t count = std::min<std::size_t>(name.size(), 15);
    std::memcpy(destination, name.data(), count);
}

struct SyntheticOptions final {
    bool includeUuid{true};
    bool omitData{};
    bool duplicateData{};
    bool overlapData{};
    bool duplicateTextSection{};
    std::uint32_t cpuType{kCpuArm64};
};

struct SegmentDescription final {
    std::string name;
    std::uint64_t address;
    std::uint64_t virtualSize;
    std::uint64_t fileOffset;
    std::uint64_t fileSize;
    std::uint32_t permissions;
    bool hasTextSection{};
};

std::vector<std::byte> BuildMachOPrefix(const SyntheticOptions& options = {}) {
    std::vector<SegmentDescription> descriptions{
        {"__PAGEZERO", 0, kImageBase, 0, 0, ImagePermissionNone, false},
        {"__TEXT", kImageBase, 0x3000, 0, 0x3000,
         ImagePermissionRead | ImagePermissionExecute, true},
        {"__DATA_CONST", kImageBase + 0x3000, 0x1000, 0x3000, 0x1000,
         ImagePermissionRead | ImagePermissionWrite, false},
        {"__DATA", options.overlapData ? kImageBase + 0x3800 : kImageBase + 0x4000,
         0x1000, 0x4000, 0x1000,
         ImagePermissionRead | ImagePermissionWrite, false},
        {"__LINKEDIT", kImageBase + 0x5000, 0x1000, 0x5000, 0x1000,
         ImagePermissionRead, false},
    };
    if (options.omitData) {
        descriptions.erase(
            std::remove_if(descriptions.begin(), descriptions.end(),
                           [](const SegmentDescription& segment) {
                               return segment.name == "__DATA";
                           }),
            descriptions.end());
    }
    if (options.duplicateData) {
        descriptions.push_back({
            "__DATA", kImageBase + 0x6000, 0x1000, 0x6000, 0x1000,
            ImagePermissionRead | ImagePermissionWrite, false});
    }

    std::vector<std::byte> commands;
    for (const SegmentDescription& description : descriptions) {
        SegmentWire segment{};
        segment.command = kSegment64;
        segment.commandSize = sizeof(SegmentWire)
            + (description.hasTextSection
                   ? sizeof(SectionWire) * (options.duplicateTextSection ? 2U : 1U)
                   : 0);
        CopyName(segment.name, description.name);
        segment.virtualAddress = description.address;
        segment.virtualSize = description.virtualSize;
        segment.fileOffset = description.fileOffset;
        segment.fileSize = description.fileSize;
        segment.maximumProtection = description.permissions;
        segment.initialProtection = description.permissions;
        segment.sectionCount = description.hasTextSection
            ? (options.duplicateTextSection ? 2U : 1U)
            : 0;
        Append(commands, segment);
        if (description.hasTextSection) {
            SectionWire section{};
            CopyName(section.sectionName, "__text");
            CopyName(section.segmentName, "__TEXT");
            section.address = kImageBase + 0x1000;
            section.size = 16;
            section.offset = 0x1000;
            Append(commands, section);
            if (options.duplicateTextSection)
                Append(commands, section);
        }
    }
    if (options.includeUuid) {
        UuidWire uuid{};
        uuid.command = kUuid;
        uuid.commandSize = sizeof(UuidWire);
        for (std::size_t index = 0; index < std::size(uuid.uuid); ++index)
            uuid.uuid[index] = static_cast<std::uint8_t>(index + 1);
        Append(commands, uuid);
    }

    HeaderWire header{};
    header.magic = kMachMagic64;
    header.cpuType = options.cpuType;
    header.fileType = kFileExecute;
    header.commandCount = static_cast<std::uint32_t>(
        descriptions.size() + (options.includeUuid ? 1 : 0));
    header.commandBytes = static_cast<std::uint32_t>(commands.size());
    std::vector<std::byte> result;
    Append(result, header);
    result.insert(result.end(), commands.begin(), commands.end());
    return result;
}

class SyntheticMemorySource final : public IMemorySource {
public:
    SyntheticMemorySource(std::uintptr_t base, std::vector<std::byte> bytes)
        : base_(base), bytes_(std::move(bytes)) {}

    ContractResult<void> Copy(
        std::uintptr_t address, std::span<std::byte> destination) const override {
        if (destination.empty() || address < base_
            || destination.size() > std::numeric_limits<std::uintptr_t>::max() - address) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange, "synthetic read is invalid");
        }
        const std::uintptr_t offset = address - base_;
        if (offset > bytes_.size() || destination.size() > bytes_.size() - offset) {
            return ContractResult<void>::Failure(
                ContractErrorCategory::OutOfRange, "synthetic read is outside buffer");
        }
        std::memcpy(destination.data(), bytes_.data() + offset, destination.size());
        return ContractResult<void>::Success();
    }

private:
    std::uintptr_t base_;
    std::vector<std::byte> bytes_;
};

struct SyntheticImage final {
    LoadedImageRecord record;
    std::shared_ptr<const IMemorySource> source;
};

SyntheticImage MakeSyntheticImage(
    const SyntheticOptions& options = {}, std::string imageName = "ShooterGame") {
    std::vector<std::byte> prefix = BuildMachOPrefix(options);
    std::vector<std::byte> memory(0x7000);
    std::copy(prefix.begin(), prefix.end(), memory.begin());
    for (std::size_t index = 0; index < 16; ++index)
        memory[0x1000 + index] = static_cast<std::byte>(0xA0 + index);
    memory[0x4000] = std::byte{0x2A};
    return {
        .record = {
            .path = "/Applications/ARK.app/" + imageName,
            .imageName = std::move(imageName),
            .isDyldMainExecutable = true,
            .headerAddress = kImageBase,
            .slide = 0,
            .headerAndLoadCommands = std::move(prefix),
        },
        .source = std::make_shared<const SyntheticMemorySource>(
            kImageBase, std::move(memory)),
    };
}

bindings::BuildProfile ProfileFrom(const ResolvedImageIdentity& resolved) {
    return {
        .profileId = "synthetic-exact-profile",
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

struct ExactFixture final {
    SyntheticImage image;
    bindings::BuildProfile profile;
    ExactProfileSelection selection;
};

ExactFixture MakeExactFixture() {
    SyntheticImage image = MakeSyntheticImage();
    const ImageIdentityResolver resolver;
    auto resolved = resolver.Resolve(image.record, *image.source, "test-version");
    bindings::BuildProfile profile = ProfileFrom(resolved.Value());
    LoadedImageCatalog catalog({image.record});
    const ExactProfileSelector selector;
    ExactProfileSelection selection = selector.Select(catalog, {&profile, 1}, *image.source);
    return {std::move(image), std::move(profile), std::move(selection)};
}

}  // namespace

void RunPlatformBoundaryTests(TestContext& context) {
    const std::vector<std::byte> valid = BuildMachOPrefix();
    V2_EXPECT(context, !MachOImageView::Parse(
        std::span<const std::byte>(valid).first(20), 0));

    std::vector<std::byte> truncatedCommand = valid;
    const std::uint32_t impossibleCommandSize = 0x00FFFFFF;
    std::memcpy(truncatedCommand.data() + sizeof(HeaderWire) + sizeof(std::uint32_t),
                &impossibleCommandSize, sizeof(impossibleCommandSize));
    V2_EXPECT(context, !MachOImageView::Parse(truncatedCommand, 0));

    V2_EXPECT(context, !MachOImageView::Parse(
        BuildMachOPrefix({.includeUuid = false}), 0));
    V2_EXPECT(context, !MachOImageView::Parse(
        BuildMachOPrefix({.duplicateData = true}), 0));
    V2_EXPECT(context, !MachOImageView::Parse(
        BuildMachOPrefix({.overlapData = true}), 0));
    V2_EXPECT(context, !MachOImageView::Parse(
        BuildMachOPrefix({.duplicateTextSection = true}), 0));

    ExactFixture fixture = MakeExactFixture();
    V2_EXPECT(context, fixture.selection.state == ProfileMatchState::ExactMatch);
    V2_EXPECT(context, fixture.selection.match.has_value());
    V2_EXPECT(context, fixture.selection.receipt.scansStarted == 0);
    V2_EXPECT(context, fixture.selection.receipt.hooks == 0);
    V2_EXPECT(context, fixture.selection.receipt.engineCalls == 0);
    V2_EXPECT(context, fixture.selection.receipt.mutation == 0);
    V2_EXPECT(context, fixture.selection.receipt.segmentSizes.find("__TEXT") != std::string::npos);

    auto reader = CheckedMemoryReader::Create(*fixture.selection.match, fixture.image.source);
    V2_EXPECT(context, reader);
    const auto dataByte = reader.Value().Read<std::uint8_t>(
        kImageBase + 0x4000, MemoryReadKind::ReadableData);
    V2_EXPECT(context, dataByte && dataByte.Value() == 0x2A);
    V2_EXPECT(context, reader.Value().Read<std::uint32_t>(
        std::numeric_limits<std::uintptr_t>::max() - 1,
        MemoryReadKind::ReadableData).Error().category == ContractErrorCategory::OutOfRange);
    V2_EXPECT(context, !reader.Value().ReadBytes(
        kImageBase + 0x7000, 1, MemoryReadKind::ReadableData));
    V2_EXPECT(context, !reader.Value().ReadBytes(
        kImageBase + 0x3FFF, 2, MemoryReadKind::ReadableData));
    V2_EXPECT(context, !reader.Value().ReadBytes(
        1, 1, MemoryReadKind::ReadableData));
    V2_EXPECT(context, !reader.Value().ReadBytes(
        kImageBase + 0x1000, 1, MemoryReadKind::ReadableData));
    V2_EXPECT(context, reader.Value().ReadBytes(
        kImageBase + 0x1000, 1, MemoryReadKind::ExecutableText));

    bindings::BuildProfile wrongUuid = fixture.profile;
    (*wrongUuid.expectedImageUuid)[0] ^= 0xFF;
    LoadedImageCatalog oneImage({fixture.image.record});
    const ExactProfileSelector selector;
    const auto uuidMismatch = selector.Select(oneImage, {&wrongUuid, 1}, *fixture.image.source);
    V2_EXPECT(context, uuidMismatch.state == ProfileMatchState::Mismatch);
    V2_EXPECT(context, !uuidMismatch.match.has_value());
    V2_EXPECT(context, uuidMismatch.receipt.reason == "LC_UUID mismatch");
    V2_EXPECT(context, uuidMismatch.receipt.scansStarted == 0);

    bindings::BuildProfile wrongFingerprint = fixture.profile;
    wrongFingerprint.expectedTextFingerprint = std::string(64, '0');
    const auto fingerprintMismatch = selector.Select(
        oneImage, {&wrongFingerprint, 1}, *fixture.image.source);
    V2_EXPECT(context, fingerprintMismatch.state == ProfileMatchState::Mismatch);
    V2_EXPECT(context, fingerprintMismatch.receipt.reason == "__text fingerprint mismatch");

    SyntheticImage wrongArchitectureImage = MakeSyntheticImage({.cpuType = kCpuX86_64});
    LoadedImageCatalog wrongArchitectureCatalog({wrongArchitectureImage.record});
    const auto architectureMismatch = selector.Select(
        wrongArchitectureCatalog, {&fixture.profile, 1}, *wrongArchitectureImage.source);
    V2_EXPECT(context, architectureMismatch.state == ProfileMatchState::Mismatch);
    V2_EXPECT(context, architectureMismatch.receipt.reason == "architecture mismatch");

    SyntheticImage missingSegmentImage = MakeSyntheticImage({.omitData = true});
    LoadedImageCatalog missingSegmentCatalog({missingSegmentImage.record});
    const auto segmentMismatch = selector.Select(
        missingSegmentCatalog, {&fixture.profile, 1}, *missingSegmentImage.source);
    V2_EXPECT(context, segmentMismatch.state == ProfileMatchState::Mismatch);
    V2_EXPECT(context,
              segmentMismatch.receipt.reason == "segment set, size, or permission mismatch");

    LoadedImageRecord duplicateRecord = fixture.image.record;
    duplicateRecord.path = "/Duplicate/ShooterGame";
    LoadedImageCatalog duplicateCatalog({fixture.image.record, duplicateRecord});
    const auto ambiguous = selector.Select(
        duplicateCatalog, {&fixture.profile, 1}, *fixture.image.source);
    V2_EXPECT(context, ambiguous.state == ProfileMatchState::Ambiguous);
    V2_EXPECT(context, !ambiguous.match.has_value());
    V2_EXPECT(context, ambiguous.receipt.scansStarted == 0);

    SyntheticImage unrelated = MakeSyntheticImage({}, "NotShooterGame");
    LoadedImageCatalog unrelatedCatalog({unrelated.record});
    const auto unsupported = selector.Select(
        unrelatedCatalog, {&fixture.profile, 1}, *unrelated.source);
    V2_EXPECT(context, unsupported.state == ProfileMatchState::Mismatch);
    V2_EXPECT(context, !unsupported.match.has_value());
    V2_EXPECT(context, unsupported.receipt.scansStarted == 0);
    V2_EXPECT(context, unsupported.receipt.hooks == 0);
    V2_EXPECT(context, unsupported.receipt.engineCalls == 0);
    V2_EXPECT(context, unsupported.receipt.mutation == 0);
}

}  // namespace serverhost::v2::tests
