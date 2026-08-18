#pragma once

#include "Containers.hpp"
#include "GeneratedSDKProfile.hpp"

inline constexpr int FNamePoolBlocksOffset =
    static_cast<int>(ServerHost::SDKProfile::Layout::FNamePoolBlocks);
inline constexpr int FNameEntryLengthBits =
    ServerHost::SDKProfile::Layout::FNameEntryLengthBits;
inline constexpr int FNameEntryLowercaseProbeHashBits = 16 - (FNameEntryLengthBits + 1);
inline constexpr int FNameEntryAlignment =
    static_cast<int>(ServerHost::SDKProfile::Layout::FNameEntryStride);

template <typename T>
FORCEINLINE constexpr T Align(T Val, uint64 Alignment)
{
	return (T)(((uint64)Val + Alignment - 1) & ~(Alignment - 1));
}

enum { FNameMaxBlockBits = 13 };
enum { FNameBlockOffsetBits = ServerHost::SDKProfile::Layout::FNameBlockOffsetBits };
enum { FNameMaxBlocks = 1 << FNameMaxBlockBits };
enum { FNameBlockOffsets = 1 << FNameBlockOffsetBits };

typedef char ANSICHAR;
typedef char16_t WIDECHAR;

struct FNameEntryHeader
{
	uint16 bIsWide : 1;
	uint16 LowercaseProbeHash : FNameEntryLowercaseProbeHashBits;
	uint16 Len : FNameEntryLengthBits;
};

#pragma pack(push, 2)
struct FNameEntry
{
public:
    FNameEntryHeader Header;
private:
	union
	{
		ANSICHAR AnsiName[0x400];
		WIDECHAR WideName[0x400];
	};
public:

    inline bool IsWide() const
    {
        return Header.bIsWide;
    }

    std::string GetPlainNameString() const
    {
        if ( IsWide() )
        {
            std::u16string ws(WideName, Header.Len);
            return std::string(ws.begin(), ws.end());
        }
        return std::string(AnsiName, Header.Len);
    }

    static int32 GetSize(int32 Length, bool bIsPureAnsi)
    {
        int32 Bytes = 0x2 + Length * (bIsPureAnsi ? sizeof(ANSICHAR) : sizeof(WIDECHAR));
        return Align(Bytes, alignof(FNameEntry));
    }

};
#pragma pack(pop)

class FNamePool
{
public:
    enum { Stride = FNameEntryAlignment };
    enum { BlockSizeBytes = FNameEntryAlignment * FNameBlockOffsets };

    uint8 Pad[FNamePoolBlocksOffset - 0x8];
    uint32 CurrentBlock = 0;
	uint32 CurrentByteCursor = 0;
    uint8* Blocks[FNameMaxBlocks];
public:

    FNameEntry& Resolve(int32 Id) const
    {
        const int32 Block  = Id >> FNameBlockOffsetBits;
        const int32 Offset = (Id & (FNameBlockOffsets - 1));
        
        return *reinterpret_cast<FNameEntry*>(Blocks[Block] + (Stride * Offset));
    }
public:
    void DebugDump(TFreedArray<const FNameEntry*>& Out) const
	{
		//FRWScopeLock _(Lock, FRWScopeLockType::SLT_ReadOnly);

		for (uint32 BlockIdx = 0; BlockIdx < CurrentBlock; ++BlockIdx)
		{
			DebugDumpBlock(Blocks[BlockIdx], BlockSizeBytes, Out);
		}

		DebugDumpBlock(Blocks[CurrentBlock], CurrentByteCursor, Out);
	}

private:
	static void DebugDumpBlock(const uint8* It, uint32 BlockSize, TFreedArray<const FNameEntry*>& Out)
	{
		const uint8* End = It + BlockSize - 0x2; // sizeof(FNameEntryHeader)
		while (It < End)
		{
			const FNameEntry* Entry = (const FNameEntry*)It;
			if (uint32 Len = Entry->Header.Len)
			{
				Out.Add(Entry);
				It += FNameEntry::GetSize(Len, !Entry->IsWide());
			}
			else // Null-terminator entry found
			{
				break;
			}
		}
	}
};

class FName
{
private:
    int32 ComparisonIndex;
    uint32 Number;

public:
    static inline FNamePool* NamePoolData = nullptr;

    FName() : ComparisonIndex(0), Number(0) {}
    FName(int32 _ComparisonIndex, int32 _Number = 0) : ComparisonIndex(_ComparisonIndex), Number(_Number) {}

    static bool Init(void* Location)
    {
        NamePoolData = reinterpret_cast<FNamePool*>(Location);
        return NamePoolData ? true : false;
    }

    FNamePool& GetNamePool() const
    {
        return *NamePoolData;
    }

    inline int32 GetDisplayIndex() const
    {
        return ComparisonIndex;
    }

    inline uint32 GetNumber() const
    {
        return Number;
    }

    inline bool IsNone() const
    {
        return ComparisonIndex == 0;
    }

    const FNameEntry* GetDisplayNameEntry() const
    {
	    if (!NamePoolData || ComparisonIndex < 0)
	        return nullptr;

	    const int32 Block = ComparisonIndex >> FNameBlockOffsetBits;
	    if (Block < 0 || Block >= FNameMaxBlocks || !NamePoolData->Blocks[Block])
	        return nullptr;

	    return &GetNamePool().Resolve(GetDisplayIndex());
    }

    inline std::string ToString() const
    {
        const FNameEntry* NameEntry = GetDisplayNameEntry();
        return NameEntry ? NameEntry->GetPlainNameString() : "";
    }

    inline bool operator==(const FName& other) const { return ComparisonIndex == other.GetDisplayIndex(); }
    inline bool operator!=(const FName& other) const { return ComparisonIndex != other.GetDisplayIndex(); }
};

static_assert(sizeof(FName) == ServerHost::SDKProfile::Layout::FNameSize,
              "Fresh SDK FName layout mismatch");
static_assert(offsetof(FNamePool, Blocks) == ServerHost::SDKProfile::Layout::FNamePoolBlocks,
              "Fresh SDK FNamePool layout mismatch");
