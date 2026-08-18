#pragma once

#include "SourceV2/UE/Containers.hpp"
#include "SourceV2/UE/Name.hpp"
#include "SourceV2/UE/Primitives.hpp"
#include "SourceV2/UE/String.hpp"

#include <cstddef>

namespace serverhost::v2::bindings::generated::ios_1_10280 {

using namespace serverhost::v2::ue;

// Curated from the two current FreshSDK trees. Opaque bytes are intentional:
// Gate 1 does not assign semantics to members the current SDK does not name.
struct FNamePoolLayout final {
    std::byte pad_0000[0xC8];
    uint32 currentBlock;
    uint32 currentByteCursor;
    const std::byte* blocks[0x2000];
};

struct FUObjectItemLayout final {
    uint64 objectWord;
    uint32 flags;
    int32 clusterIndex;
    int32 serialNumber;
    uint32 pad_0014;
};

struct TUObjectArrayLayout final {
    uint64 objectsWord;
    uint64 preAllocatedObjectsWord;
    int32 maxElements;
    int32 numElements;
    int32 maxChunks;
    int32 numChunks;
};

struct FUObjectArrayLayout final {
    int32 firstGCIndex;
    int32 lastNonGCIndex;
    int32 maxObjectsNotConsideredByGC;
    bool openForDisregardForGC;
    std::byte pad_000D[0x3];
    TUObjectArrayLayout objObjects;
};

struct UObjectLayout final {
    uint64 vtableWord;
    EObjectFlags flags;
    int32 index;
    uint64 classObjectWord;
    FName name;
    uint64 outerWord;
};

struct FNetDriverDefinitionLayout final {
    FName defName;
    FName driverClassName;
    FName driverClassNameFallback;
};

struct TArrayHeaderLayout final {
    uint64 dataWord;
    int32 num;
    int32 max;
};

struct UFieldLayout final {
    UObjectLayout object;
    const void* next;
};

struct FStructBaseChainLayout final {
    const void* chain;
    int32 numBasesMinusOne;
    std::byte pad_000C[0x4];
};

struct UStructLayout final {
    UFieldLayout field;
    FStructBaseChainLayout baseChain;
    const void* superStruct;
    const void* children;
    const void* childProperties;
    int32 size;
    int16 minimumAlignment;
    std::byte pad_005E[0x52];
};

struct UFunctionLayout final {
    std::byte opaque_0000[0xB0];
    uint32 functionFlags;
    std::byte opaque_00B4[0x2C];
};

struct UClassLayout final {
    std::byte opaque_0000[0xD8];
    EClassCastFlags castFlags;
    std::byte opaque_00E0[0x40];
    const void* classDefaultObject;
    std::byte opaque_0128[0x1E8];
};

struct FFieldClassLayout final {
    FName name;
    uint64 id;
    uint64 castFlags;
    EClassFlags classFlags;
    std::byte pad_001C[0x4];
    const void* superClass;
};

struct FFieldVariantLayout final {
    const void* container;
    bool isUObject;
    std::byte pad_0009[0x7];
};

struct FFieldLayout final {
    void* vtable;
    const void* classPrivate;
    FFieldVariantLayout owner;
    const void* next;
    FName name;
    int32 objectFlags;
    std::byte pad_0034[0x4];
};

struct FPropertyLayout final {
    void* vtable;
    const void* classPrivate;
    FFieldVariantLayout owner;
    const void* next;
    FName name;
    int32 objectFlags;
    int32 arrayDim;
    int32 elementSize;
    std::byte pad_003C[0x4];
    uint64 propertyFlags;
    std::byte pad_0048[0x4];
    int32 offset;
    std::byte pad_0050[0x28];
};

struct FBoolPropertyLayout final {
    FPropertyLayout property;
    uint8 fieldSize;
    uint8 byteOffset;
    uint8 byteMask;
    uint8 fieldMask;
    std::byte pad_007C[0x4];
};

static_assert(sizeof(TArrayLayout<int32>) == 0x10);
static_assert(alignof(TArrayLayout<int32>) == 0x8);
static_assert(offsetof(TArrayLayout<int32>, data) == 0x0);
static_assert(offsetof(TArrayLayout<int32>, num) == 0x8);
static_assert(offsetof(TArrayLayout<int32>, max) == 0xC);
static_assert(sizeof(FStringLayout) == 0x10);
static_assert(sizeof(FName) == 0x8 && alignof(FName) == 0x4);
static_assert(sizeof(FNamePoolLayout) == 0x100D0);
static_assert(offsetof(FNamePoolLayout, currentBlock) == 0xC8);
static_assert(offsetof(FNamePoolLayout, currentByteCursor) == 0xCC);
static_assert(offsetof(FNamePoolLayout, blocks) == 0xD0);
static_assert(sizeof(FUObjectItemLayout) == 0x18);
static_assert(offsetof(FUObjectItemLayout, objectWord) == 0x0);
static_assert(offsetof(FUObjectItemLayout, flags) == 0x8);
static_assert(offsetof(FUObjectItemLayout, clusterIndex) == 0xC);
static_assert(offsetof(FUObjectItemLayout, serialNumber) == 0x10);
static_assert(sizeof(TUObjectArrayLayout) == 0x20);
static_assert(sizeof(FUObjectArrayLayout) == 0x30);
static_assert(offsetof(FUObjectArrayLayout, objObjects) == 0x10);
static_assert(offsetof(TUObjectArrayLayout, objectsWord) == 0x0);
static_assert(offsetof(TUObjectArrayLayout, maxElements) == 0x10);
static_assert(offsetof(TUObjectArrayLayout, numElements) == 0x14);
static_assert(offsetof(TUObjectArrayLayout, maxChunks) == 0x18);
static_assert(offsetof(TUObjectArrayLayout, numChunks) == 0x1C);
static_assert(sizeof(UObjectLayout) == 0x28 && alignof(UObjectLayout) == 0x8);
static_assert(offsetof(UObjectLayout, flags) == 0x8);
static_assert(offsetof(UObjectLayout, index) == 0xC);
static_assert(offsetof(UObjectLayout, classObjectWord) == 0x10);
static_assert(offsetof(UObjectLayout, name) == 0x18);
static_assert(offsetof(UObjectLayout, outerWord) == 0x20);
static_assert(sizeof(FNetDriverDefinitionLayout) == 0x18);
static_assert(offsetof(FNetDriverDefinitionLayout, defName) == 0x0);
static_assert(offsetof(FNetDriverDefinitionLayout, driverClassName) == 0x8);
static_assert(offsetof(FNetDriverDefinitionLayout, driverClassNameFallback) == 0x10);
static_assert(sizeof(TArrayHeaderLayout) == 0x10);
static_assert(offsetof(TArrayHeaderLayout, dataWord) == 0x0);
static_assert(offsetof(TArrayHeaderLayout, num) == 0x8);
static_assert(offsetof(TArrayHeaderLayout, max) == 0xC);
static_assert(sizeof(UFieldLayout) == 0x30);
static_assert(offsetof(UFieldLayout, next) == 0x28);
static_assert(sizeof(FStructBaseChainLayout) == 0x10);
static_assert(sizeof(UStructLayout) == 0xB0);
static_assert(offsetof(UStructLayout, superStruct) == 0x40);
static_assert(offsetof(UStructLayout, children) == 0x48);
static_assert(offsetof(UStructLayout, childProperties) == 0x50);
static_assert(offsetof(UStructLayout, size) == 0x58);
static_assert(offsetof(UStructLayout, minimumAlignment) == 0x5C);
static_assert(sizeof(UFunctionLayout) == 0xE0);
static_assert(offsetof(UFunctionLayout, functionFlags) == 0xB0);
static_assert(sizeof(UClassLayout) == 0x310);
static_assert(offsetof(UClassLayout, castFlags) == 0xD8);
static_assert(offsetof(UClassLayout, classDefaultObject) == 0x120);
static_assert(sizeof(FFieldClassLayout) == 0x28);
static_assert(offsetof(FFieldClassLayout, superClass) == 0x20);
static_assert(sizeof(FFieldVariantLayout) == 0x10);
static_assert(sizeof(FFieldLayout) == 0x38);
static_assert(offsetof(FFieldLayout, objectFlags) == 0x30);
static_assert(sizeof(FPropertyLayout) == 0x78);
static_assert(offsetof(FPropertyLayout, arrayDim) == 0x34);
static_assert(offsetof(FPropertyLayout, elementSize) == 0x38);
static_assert(offsetof(FPropertyLayout, propertyFlags) == 0x40);
static_assert(offsetof(FPropertyLayout, offset) == 0x4C);
static_assert(sizeof(FBoolPropertyLayout) == 0x80);
static_assert(offsetof(FBoolPropertyLayout, fieldSize) == 0x78);
static_assert(offsetof(FBoolPropertyLayout, byteMask) == 0x7A);

static_assert(static_cast<uint32>(EObjectFlags::ClassDefaultObject) == 0x10);
static_assert(static_cast<uint32>(EFunctionFlags::Native) == 0x400);
static_assert(static_cast<uint64>(EClassCastFlags::Class) == 0x20);
static_assert(static_cast<uint64>(EClassCastFlags::Property) == 0x8000);
static_assert(static_cast<uint64>(EClassCastFlags::BoolProperty) == 0x20000);
static_assert(static_cast<uint64>(EClassCastFlags::Function) == 0x80000);
static_assert(static_cast<uint64>(EPropertyFlags::Parm) == 0x80);

}  // namespace serverhost::v2::bindings::generated::ios_1_10280
