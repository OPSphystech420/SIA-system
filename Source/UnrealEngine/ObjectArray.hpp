#pragma once

#include "Containers.hpp"
#include "ScriptCore.h"
#include "GeneratedSDKProfile.hpp"

struct FUObjectItem final
{
public:
	class UObject* Object;
	int32 Flags;   
	int32 ClusterIndex; 
	int32 SerialNumber; 
	uint8 Pad_14[0x4]; 

public:
	bool IsUnreachable() const
	{
	    return !!(Flags & (1 << 28));
	}

	bool IsPendingKill() const
	{
	    return !!(Flags & (1 << 29));
	}
};

class TUObjectArray
{
public:
	enum
	{
		NumElementsPerChunk = 64 * 1024,
	};

	FUObjectItem** Objects;
	FUObjectItem* PreAllocatedObjects;
	int32 MaxElements;
	int32 NumElements;
	int32 MaxChunks;
	int32 NumChunks;

public:
	inline int32 Num() const
    {
        return NumElements;
    }

    inline int32 Capacity() const
    {
        return MaxElements;
    }

    inline bool IsValidIndex(int32 Index) const
	{
		return Index < Num() && Index >= 0;
	}

    inline FUObjectItem const* IndexToObject(int32 Index) const
    {
        const int32 ChunkIndex = Index / NumElementsPerChunk;
        const int32 WithinChunkIndex = Index % NumElementsPerChunk;

        if ( !IsValidIndex(Index) ) 
            return nullptr;

		if (ChunkIndex >= NumChunks)
			return nullptr;

		if (Index >= Capacity())
            return nullptr;

        FUObjectItem* Chunk = Objects[ChunkIndex];
        if ( !Chunk )
            return nullptr;

        return reinterpret_cast<FUObjectItem*>(Chunk + WithinChunkIndex);
    }

    inline UObject* operator[](int32 Index) const
    {
        FUObjectItem const* ObjectItem = IndexToObject(Index);
        if ( ObjectItem )
        {
            return ObjectItem->Object;
        }
        return nullptr;
    }
};

static_assert(sizeof(FUObjectItem) == ServerHost::SDKProfile::Layout::FUObjectItemSize,
              "Fresh SDK FUObjectItem layout mismatch");
static_assert(offsetof(TUObjectArray, NumElements) ==
                  ServerHost::SDKProfile::Layout::TUObjectArrayNumElements,
              "Fresh SDK TUObjectArray layout mismatch");
static_assert(TUObjectArray::NumElementsPerChunk ==
                  ServerHost::SDKProfile::Layout::UObjectElementsPerChunk,
              "Fresh SDK chunk size mismatch");

class FUObjectArray 
{
public:
    int32 ObjFirstGCIndex;
	int32 ObjLastNonGCIndex;
	int32 MaxObjectsNotConsideredByGC;
	bool OpenForDisregardForGC;
    uint8 Pad[0x3];
	TUObjectArray ObjObjects;
};




