#include "SourceV2/Bindings/Platform/MachOImageView.hpp"

#include <algorithm>
#include <cstring>
#include <iomanip>
#include <limits>
#include <set>
#include <sstream>

namespace serverhost::v2::bindings::platform {
namespace {

constexpr std::uint32_t kMachMagic64 = 0xFEEDFACF;
constexpr std::uint32_t kCpuTypeArm64 = 0x0100000C;
constexpr std::uint32_t kCpuTypeX86_64 = 0x01000007;
constexpr std::uint32_t kCpuSubtypeMask = 0xFF000000;
constexpr std::uint32_t kCpuSubtypeArm64e = 2;
constexpr std::uint32_t kFileTypeExecute = 2;
constexpr std::uint32_t kFileTypeDylib = 6;
constexpr std::uint32_t kLoadSegment64 = 0x19;
constexpr std::uint32_t kLoadUuid = 0x1B;
constexpr std::size_t kLoadCommandSize = 8;
constexpr std::size_t kSegment64Size = 72;
constexpr std::size_t kSection64Size = 80;
constexpr std::size_t kUuidCommandSize = 24;
constexpr std::size_t kMaximumCommands = 4096;

#pragma pack(push, 1)
struct Header64Wire final {
    std::uint32_t magic;
    std::uint32_t cpuType;
    std::uint32_t cpuSubtype;
    std::uint32_t fileType;
    std::uint32_t commandCount;
    std::uint32_t commandBytes;
    std::uint32_t flags;
    std::uint32_t reserved;
};

struct LoadCommandWire final {
    std::uint32_t command;
    std::uint32_t commandSize;
};

struct Segment64Wire final {
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

struct Section64Wire final {
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

struct UuidCommandWire final {
    std::uint32_t command;
    std::uint32_t commandSize;
    std::uint8_t uuid[16];
};
#pragma pack(pop)

static_assert(sizeof(Header64Wire) == MachOImageView::kHeader64Size);
static_assert(sizeof(LoadCommandWire) == kLoadCommandSize);
static_assert(sizeof(Segment64Wire) == kSegment64Size);
static_assert(sizeof(Section64Wire) == kSection64Size);
static_assert(sizeof(UuidCommandWire) == kUuidCommandSize);

template <typename T>
bool AddOverflows(T left, T right) noexcept {
    return right > std::numeric_limits<T>::max() - left;
}

template <typename T>
T CopyWire(std::span<const std::byte> bytes, std::size_t offset) {
    T value{};
    std::memcpy(&value, bytes.data() + offset, sizeof(value));
    return value;
}

std::string FixedName(const char value[16]) {
    const auto end = std::find(value, value + 16, '\0');
    return std::string(value, end);
}

ContractResult<std::uintptr_t> ApplySlide(std::uint64_t address, std::intptr_t slide) {
    if (address > std::numeric_limits<std::uintptr_t>::max()) {
        return ContractResult<std::uintptr_t>::Failure(
            ContractErrorCategory::OutOfRange, "Mach-O address exceeds uintptr_t");
    }
    std::uintptr_t result = static_cast<std::uintptr_t>(address);
    if (slide >= 0) {
        const auto positive = static_cast<std::uintptr_t>(slide);
        if (AddOverflows(result, positive)) {
            return ContractResult<std::uintptr_t>::Failure(
                ContractErrorCategory::OutOfRange, "Mach-O address plus slide overflows");
        }
        result += positive;
        return ContractResult<std::uintptr_t>::Success(result);
    }
    const std::uintptr_t magnitude = static_cast<std::uintptr_t>(-(slide + 1)) + 1U;
    if (result < magnitude) {
        return ContractResult<std::uintptr_t>::Failure(
            ContractErrorCategory::OutOfRange, "Mach-O address plus negative slide underflows");
    }
    return ContractResult<std::uintptr_t>::Success(result - magnitude);
}

bool IntervalsOverlap(std::uint64_t firstStart, std::uint64_t firstSize,
                      std::uint64_t secondStart, std::uint64_t secondSize) noexcept {
    if (firstSize == 0 || secondSize == 0 || AddOverflows(firstStart, firstSize)
        || AddOverflows(secondStart, secondSize)) {
        return false;
    }
    return firstStart < secondStart + secondSize && secondStart < firstStart + firstSize;
}

ImageArchitecture DecodeArchitecture(std::uint32_t cpuType, std::uint32_t cpuSubtype) noexcept {
    if (cpuType == kCpuTypeArm64) {
        const std::uint32_t subtype = cpuSubtype & ~kCpuSubtypeMask;
        return subtype == kCpuSubtypeArm64e ? ImageArchitecture::Arm64e
                                            : ImageArchitecture::Arm64;
    }
    return cpuType == kCpuTypeX86_64 ? ImageArchitecture::X86_64
                                     : ImageArchitecture::Unknown;
}

ImageRole DecodeRole(std::uint32_t fileType) noexcept {
    if (fileType == kFileTypeExecute)
        return ImageRole::MainExecutable;
    if (fileType == kFileTypeDylib)
        return ImageRole::DynamicLibrary;
    return ImageRole::Unknown;
}

}  // namespace

bool MappedSegment::IsReadable() const noexcept {
    return (initialPermissions & ImagePermissionRead) != 0;
}

bool MappedSegment::IsExecutable() const noexcept {
    return (initialPermissions & ImagePermissionExecute) != 0;
}

bool MappedSegment::Contains(std::uintptr_t address, std::size_t size) const noexcept {
    if (size == 0 || virtualSize > std::numeric_limits<std::uintptr_t>::max()
        || AddOverflows(address, static_cast<std::uintptr_t>(size))) {
        return false;
    }
    const std::uintptr_t segmentSize = static_cast<std::uintptr_t>(virtualSize);
    if (AddOverflows(mappedAddress, segmentSize)) {
        return false;
    }
    const std::uintptr_t end = address + size;
    return address >= mappedAddress && end <= mappedAddress + segmentSize;
}

ContractResult<std::size_t> MachOImageView::RequiredPrefixSize(
    std::span<const std::byte> headerBytes) {
    if (headerBytes.size() < sizeof(Header64Wire)) {
        return ContractResult<std::size_t>::Failure(
            ContractErrorCategory::MalformedLayout, "truncated Mach-O 64 header");
    }
    const Header64Wire header = CopyWire<Header64Wire>(headerBytes, 0);
    if (header.magic != kMachMagic64) {
        return ContractResult<std::size_t>::Failure(
            ContractErrorCategory::MalformedLayout, "unsupported Mach-O magic");
    }
    if (header.commandCount == 0 || header.commandCount > kMaximumCommands
        || header.commandBytes > kMaximumLoadCommandBytes
        || header.commandBytes < header.commandCount * kLoadCommandSize
        || AddOverflows(sizeof(Header64Wire), static_cast<std::size_t>(header.commandBytes))) {
        return ContractResult<std::size_t>::Failure(
            ContractErrorCategory::MalformedLayout, "invalid Mach-O load-command envelope");
    }
    return ContractResult<std::size_t>::Success(
        sizeof(Header64Wire) + static_cast<std::size_t>(header.commandBytes));
}

ContractResult<MachOImageView> MachOImageView::Parse(
    std::span<const std::byte> bytes, std::intptr_t slide) {
    const auto required = RequiredPrefixSize(bytes);
    if (!required)
        return ContractResult<MachOImageView>::Failure(
            required.Error().category, required.Error().context);
    if (bytes.size() < required.Value()) {
        return ContractResult<MachOImageView>::Failure(
            ContractErrorCategory::MalformedLayout, "truncated Mach-O load commands");
    }

    const Header64Wire header = CopyWire<Header64Wire>(bytes, 0);
    MachOImageView view;
    view.architecture_ = DecodeArchitecture(header.cpuType, header.cpuSubtype);
    view.role_ = DecodeRole(header.fileType);
    std::set<std::string> segmentNames;
    std::set<std::pair<std::string, std::string>> sectionNames;
    std::size_t cursor = sizeof(Header64Wire);
    const std::size_t commandEnd = required.Value();

    for (std::uint32_t commandIndex = 0; commandIndex < header.commandCount; ++commandIndex) {
        if (cursor > commandEnd || commandEnd - cursor < sizeof(LoadCommandWire)) {
            return ContractResult<MachOImageView>::Failure(
                ContractErrorCategory::MalformedLayout, "truncated Mach-O load command");
        }
        const LoadCommandWire command = CopyWire<LoadCommandWire>(bytes, cursor);
        if (command.commandSize < sizeof(LoadCommandWire)
            || command.commandSize > commandEnd - cursor) {
            return ContractResult<MachOImageView>::Failure(
                ContractErrorCategory::MalformedLayout, "invalid Mach-O load-command size");
        }

        if (command.command == kLoadUuid) {
            if (command.commandSize != sizeof(UuidCommandWire) || view.hasUuid_) {
                return ContractResult<MachOImageView>::Failure(
                    ContractErrorCategory::MalformedLayout, "absent-sized or duplicate LC_UUID");
            }
            const UuidCommandWire uuid = CopyWire<UuidCommandWire>(bytes, cursor);
            std::copy(std::begin(uuid.uuid), std::end(uuid.uuid), view.uuid_.begin());
            view.hasUuid_ = true;
        } else if (command.command == kLoadSegment64) {
            if (command.commandSize < sizeof(Segment64Wire)) {
                return ContractResult<MachOImageView>::Failure(
                    ContractErrorCategory::MalformedLayout, "truncated LC_SEGMENT_64");
            }
            const Segment64Wire segment = CopyWire<Segment64Wire>(bytes, cursor);
            const std::size_t requiredSegmentSize = sizeof(Segment64Wire)
                + static_cast<std::size_t>(segment.sectionCount) * sizeof(Section64Wire);
            if (requiredSegmentSize > command.commandSize
                || AddOverflows(segment.virtualAddress, segment.virtualSize)
                || AddOverflows(segment.fileOffset, segment.fileSize)
                || segment.fileSize > segment.virtualSize) {
                return ContractResult<MachOImageView>::Failure(
                    ContractErrorCategory::MalformedLayout, "invalid segment bounds");
            }
            const std::string segmentName = FixedName(segment.name);
            if (segmentName.empty() || !segmentNames.insert(segmentName).second) {
                return ContractResult<MachOImageView>::Failure(
                    ContractErrorCategory::MalformedLayout, "absent or duplicate segment name");
            }
            const auto mappedAddress = ApplySlide(segment.virtualAddress, slide);
            if (!mappedAddress) {
                return ContractResult<MachOImageView>::Failure(
                    mappedAddress.Error().category, mappedAddress.Error().context);
            }
            MappedSegment mapped{
                .name = segmentName,
                .preferredAddress = segment.virtualAddress,
                .mappedAddress = mappedAddress.Value(),
                .virtualSize = segment.virtualSize,
                .fileOffset = segment.fileOffset,
                .fileSize = segment.fileSize,
                .initialPermissions = static_cast<std::uint8_t>(segment.initialProtection & 0x7U),
            };
            for (const MappedSegment& existing : view.segments_) {
                if (IntervalsOverlap(existing.preferredAddress, existing.virtualSize,
                                     mapped.preferredAddress, mapped.virtualSize)
                    || IntervalsOverlap(existing.fileOffset, existing.fileSize,
                                        mapped.fileOffset, mapped.fileSize)) {
                    return ContractResult<MachOImageView>::Failure(
                        ContractErrorCategory::MalformedLayout, "overlapping Mach-O segments");
                }
            }
            if (segment.fileSize != 0) {
                const std::uint64_t fileEnd = segment.fileOffset + segment.fileSize;
                if (fileEnd > std::numeric_limits<std::size_t>::max()) {
                    return ContractResult<MachOImageView>::Failure(
                        ContractErrorCategory::OutOfRange, "Mach-O file span exceeds size_t");
                }
                view.fileSpanSize_ = std::max(
                    view.fileSpanSize_, static_cast<std::size_t>(fileEnd));
            }
            if (segmentName == "__LINKEDIT") {
                if (segment.fileOffset == 0
                    || segment.fileOffset > std::numeric_limits<std::size_t>::max()) {
                    return ContractResult<MachOImageView>::Failure(
                        ContractErrorCategory::MalformedLayout,
                        "__LINKEDIT has invalid stable-prefix boundary");
                }
                view.stableFilePrefixSize_ = static_cast<std::size_t>(segment.fileOffset);
            }

            for (std::uint32_t sectionIndex = 0; sectionIndex < segment.sectionCount;
                 ++sectionIndex) {
                const std::size_t sectionOffset = cursor + sizeof(Segment64Wire)
                    + static_cast<std::size_t>(sectionIndex) * sizeof(Section64Wire);
                const Section64Wire section = CopyWire<Section64Wire>(bytes, sectionOffset);
                const std::string sectionSegmentName = FixedName(section.segmentName);
                const std::string sectionName = FixedName(section.sectionName);
                if (AddOverflows(section.address, section.size)
                    || section.address < segment.virtualAddress
                    || section.address + section.size
                        > segment.virtualAddress + segment.virtualSize
                    || sectionSegmentName != segmentName || sectionName.empty()
                    || !sectionNames.insert({sectionSegmentName, sectionName}).second) {
                    return ContractResult<MachOImageView>::Failure(
                        ContractErrorCategory::MalformedLayout,
                        "section is invalid, misplaced, or duplicated");
                }
                const auto sectionMappedAddress = ApplySlide(section.address, slide);
                if (!sectionMappedAddress) {
                    return ContractResult<MachOImageView>::Failure(
                        sectionMappedAddress.Error().category,
                        sectionMappedAddress.Error().context);
                }
                view.sections_.push_back({
                    .segmentName = sectionSegmentName,
                    .sectionName = sectionName,
                    .mappedAddress = sectionMappedAddress.Value(),
                    .size = section.size,
                    .fileOffset = section.offset,
                });
            }
            view.segments_.push_back(std::move(mapped));
        }
        cursor += command.commandSize;
    }
    if (cursor != commandEnd) {
        return ContractResult<MachOImageView>::Failure(
            ContractErrorCategory::MalformedLayout, "load commands do not fill declared envelope");
    }
    if (!view.hasUuid_) {
        return ContractResult<MachOImageView>::Failure(
            ContractErrorCategory::MissingEvidence, "LC_UUID is missing");
    }
    if (view.stableFilePrefixSize_ == 0) {
        return ContractResult<MachOImageView>::Failure(
            ContractErrorCategory::MissingEvidence, "__LINKEDIT boundary is missing");
    }
    return ContractResult<MachOImageView>::Success(std::move(view));
}

ImageArchitecture MachOImageView::Architecture() const noexcept { return architecture_; }
ImageRole MachOImageView::Role() const noexcept { return role_; }
const std::array<std::uint8_t, 16>& MachOImageView::Uuid() const noexcept { return uuid_; }
bool MachOImageView::HasUuid() const noexcept { return hasUuid_; }
const std::vector<MappedSegment>& MachOImageView::Segments() const noexcept { return segments_; }
std::size_t MachOImageView::FileSpanSize() const noexcept { return fileSpanSize_; }
std::size_t MachOImageView::StableFilePrefixSize() const noexcept {
    return stableFilePrefixSize_;
}

const MachOSection* MachOImageView::FindSection(
    std::string_view segmentName, std::string_view sectionName) const noexcept {
    const auto found = std::find_if(
        sections_.begin(), sections_.end(), [&](const MachOSection& section) {
            return section.segmentName == segmentName && section.sectionName == sectionName;
        });
    return found == sections_.end() ? nullptr : &*found;
}

std::string ImageArchitectureName(ImageArchitecture architecture) {
    switch (architecture) {
        case ImageArchitecture::Arm64: return "arm64";
        case ImageArchitecture::Arm64e: return "arm64e";
        case ImageArchitecture::X86_64: return "x86_64";
        case ImageArchitecture::Unknown: return "unknown";
    }
    return "unknown";
}

std::string FormatUuid(const std::array<std::uint8_t, 16>& uuid) {
    std::ostringstream stream;
    stream << std::uppercase << std::hex << std::setfill('0');
    for (std::size_t index = 0; index < uuid.size(); ++index) {
        if (index == 4 || index == 6 || index == 8 || index == 10)
            stream << '-';
        stream << std::setw(2) << static_cast<unsigned int>(uuid[index]);
    }
    return stream.str();
}

std::string FormatSegmentSizes(std::span<const ImageSegmentIdentity> segments) {
    std::ostringstream stream;
    for (std::size_t index = 0; index < segments.size(); ++index) {
        if (index != 0)
            stream << ", ";
        stream << segments[index].name << " vm=" << segments[index].virtualSize
               << "B file=" << segments[index].fileSize << 'B';
    }
    return stream.str();
}

}  // namespace serverhost::v2::bindings::platform
