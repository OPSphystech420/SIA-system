#pragma once

#include "Enums.hpp"
#include "NameTypes.hpp"
#include "CommonTypes.hpp"
#include "ObjectArray.hpp"
#include "GeneratedSDKProfile.hpp"
#include "../Offsets.h"

#include <unordered_map>

class FFieldClass
{
public:
    FName Name;					  
    uint64 Id;					 
    EClassCastFlags CastFlags;			 
    EClassFlags ClassFlags;		  
    uint8 Pad_1C[0x4];			 
    class FFieldClass *SuperClass; 

    bool IsType(EClassCastFlags Flags) const
    {
        return (Flags != EClassCastFlags::None ? (CastFlags & Flags) : true);
    }
};

class FFieldVariant
{
public:
    using ContainerType = union
    {
        class FField *Field;
        class UObject* Object;
    }; 

    ContainerType Container; 
    bool bIsUObject;
};

class FField
{
public:
    void** VTable;				
    class FFieldClass *ClassPrivate; 
    FFieldVariant Owner;			
    class FField *Next;				
    FName Name;						
    int32 ObjFlags;		

    bool IsA(EClassCastFlags Flags) const
    {
        return Flags == EClassCastFlags::None ||
            (ClassPrivate && ClassPrivate->IsType(Flags));
    }		
};

struct FProperty : public FField
{
public:
    int32 ArrayDim;		  
    int32 ElementSize;	 
    uint8 Pad_3C[0x4];	 
    uint64 PropertyFlags; 
    uint8 Pad_48[0x4];	 
    int32 Offset;
    uint8 Pad_50[0x28];
};

struct FBoolProperty : public FProperty
{
	uint8 FieldSize;
	uint8 ByteOffset;
	uint8 ByteMask;
	uint8 FieldMask;
};

class UObject
{
public:
	static inline FUObjectArray* GUObjectArray = nullptr; 

	void**          VTable; 
	EObjectFlags    ObjectFlags;      
	int32           InternalIndex;         
	class UClass*   ClassPrivate;     
	class FName     NamePrivate;             
	class UObject*  OuterPrivate; 

public:

	std::string GetFullName() const;
	std::string GetName() const;
	bool HasTypeFlag(EClassCastFlags TypeFlags) const;
	bool IsA(EClassCastFlags TypeFlags) const;
	bool IsA(class UClass* TypeClass) const;
    bool IsA(FName TypeName) const;
	bool IsDefaultObject() const;

    FName GetClassName() const;

public:

    FORCEINLINE bool IsPendingKill() const
    {
        return GUObjectArray->ObjObjects.IndexToObject(InternalIndex)->IsPendingKill();
    }

	void ProcessEvent(class UFunction* Function, void* Parms) const
    {
        if ( !Function )
            return;

        reinterpret_cast<void(*)(const UObject*, UFunction*, void*)>(VTable[Off::Idx::ProcessEvent])(this, Function, Parms);
    }

	static class UClass* FindClass(const std::string& ClassFullName)
	{
		return FindObject<UClass>(ClassFullName, EClassCastFlags::Class);
	}

	static class UClass* FindClassFast(const std::string& ClassName)
	{
		return FindObjectFast<UClass>(ClassName, EClassCastFlags::Class);
	}
	
	template<typename UEType = UObject>
	static UEType* FindObject(const std::string& Name, EClassCastFlags RequiredType = EClassCastFlags::None)
	{
		for (int i = 0; i < GUObjectArray->ObjObjects.Num(); ++i)
        {
            UObject* Object = GUObjectArray->ObjObjects[i];
            if (!Object)
			    continue;
		
            if ((RequiredType == EClassCastFlags::None || Object->HasTypeFlag(RequiredType)) &&
                Object->GetFullName() == Name)
                return static_cast<UEType*>(Object);
        }
        return nullptr;
	}

	template<typename UEType = UObject>
	static UEType* FindObjectFast(const std::string& Name, EClassCastFlags RequiredType = EClassCastFlags::None)
	{
		for (int i = 0; i < GUObjectArray->ObjObjects.Num(); ++i)
        {
            UObject* Object = GUObjectArray->ObjObjects[i];
            if (!Object)
			    continue;
		
            if ((RequiredType == EClassCastFlags::None || Object->HasTypeFlag(RequiredType)) &&
                Object->GetName() == Name)
                return static_cast<UEType*>(Object);
        }
        return nullptr;
	}

    static std::unordered_map<UClass*, std::unordered_map<std::string, int32>> OffsetsMap;

    int32 GetOffset(const std::string& Name, uint8* OutBit = nullptr) const;

    template<typename Type>
    Type* GetMember(const std::string& Name) const
    {
        if (ClassPrivate)
        {
            auto& ClassOffsets = OffsetsMap[ClassPrivate];
            if (auto It = ClassOffsets.find(Name); It != ClassOffsets.end() && It->second != 0)
            {
                return reinterpret_cast<Type*>((uint8*)this + It->second);
            }

            int32 Offset = GetOffset(Name);
            if (Offset > 0)
            {
                ClassOffsets[Name] = Offset;
                return reinterpret_cast<Type*>((uint8*)this + Offset);
            }
        }
        return nullptr;
    }

    static std::unordered_map<UClass*, std::unordered_map<std::string, std::pair<int32, uint8>>> BitOffsetsMap;

    bool GetBitMember(const std::string& Name) const
    {
        if (ClassPrivate)
        {
            auto& ClassOffsets = BitOffsetsMap[ClassPrivate];
            if (auto It = ClassOffsets.find(Name); It != ClassOffsets.end() && It->second.first != 0)
            {
                return *(uint8*)((uint8*)this + It->second.first) & It->second.second;
            }

            uint8 OutBit = 0;
            int32 Offset = GetOffset(Name, &OutBit);
            if (Offset <= 0 || OutBit == 0)
                return false;
            ClassOffsets[Name] = std::make_pair(Offset, OutBit);

            return *(uint8*)((uint8*)this + Offset) & OutBit;
        }
        return false;
    }

    void SetBitMember(const std::string& Name, bool Value) const 
    {
        if (ClassPrivate)
        {
            auto& ClassOffsets = BitOffsetsMap[ClassPrivate];
            if (auto It = ClassOffsets.find(Name); It != ClassOffsets.end() && It->second.first != 0)
            {
                uint8* BitFlagAddr = (uint8*)((uint8*)this + It->second.first);
                if (Value)
                    *BitFlagAddr |= It->second.second;
                else 
                    *BitFlagAddr &= ~It->second.second;
                return;
            }

            uint8 OutBit = 0;
            int32 Offset = GetOffset(Name, &OutBit);
            if (Offset <= 0 || OutBit == 0)
                return;
            ClassOffsets[Name] = std::make_pair(Offset, OutBit);

            uint8* NewBitFlagAddr = (uint8*)((uint8*)this + Offset);
            if (Value)
                *NewBitFlagAddr |= OutBit;
            else
                *NewBitFlagAddr &= ~OutBit;
        }
    }

    static void Init(void* Address)
    {
        GUObjectArray = reinterpret_cast<FUObjectArray*>(Address);
    }

};

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"

static_assert(sizeof(UObject) == ServerHost::SDKProfile::Layout::UObjectSize,
              "Fresh SDK UObject layout mismatch");
static_assert(offsetof(UObject, ClassPrivate) == ServerHost::SDKProfile::Layout::UObjectClass,
              "Fresh SDK UObject::ClassPrivate mismatch");
static_assert(offsetof(UObject, NamePrivate) == ServerHost::SDKProfile::Layout::UObjectName,
              "Fresh SDK UObject::NamePrivate mismatch");
static_assert(offsetof(UObject, OuterPrivate) == ServerHost::SDKProfile::Layout::UObjectOuter,
              "Fresh SDK UObject::OuterPrivate mismatch");
static_assert(offsetof(FField, Next) == ServerHost::SDKProfile::Layout::FFieldNext,
              "Fresh SDK FField::Next mismatch");
static_assert(offsetof(FField, Name) == ServerHost::SDKProfile::Layout::FFieldName,
              "Fresh SDK FField::Name mismatch");
static_assert(offsetof(FProperty, ArrayDim) == ServerHost::SDKProfile::Layout::FPropertyArrayDim,
              "Fresh SDK FProperty::ArrayDim mismatch");
static_assert(offsetof(FProperty, ElementSize) == ServerHost::SDKProfile::Layout::FPropertyElementSize,
              "Fresh SDK FProperty::ElementSize mismatch");
static_assert(offsetof(FProperty, PropertyFlags) == ServerHost::SDKProfile::Layout::FPropertyFlags,
              "Fresh SDK FProperty::PropertyFlags mismatch");
static_assert(offsetof(FProperty, Offset) == ServerHost::SDKProfile::Layout::FPropertyOffset,
              "Fresh SDK FProperty::Offset mismatch");
static_assert(sizeof(FProperty) == ServerHost::SDKProfile::Layout::FPropertySize,
              "Fresh SDK FProperty size mismatch");
static_assert(offsetof(FBoolProperty, ByteMask) ==
                  ServerHost::SDKProfile::Layout::FBoolPropertyByteMask,
              "Fresh SDK FBoolProperty::ByteMask mismatch");


class UField : public UObject
{
public:
	class UField* Next;
};

class UProperty : public UField
{
public:
	uint8 Pad_35[0x40];
};

class FStructBaseChain
{
protected:
	FORCEINLINE bool IsChildOfUsingStructArray(const FStructBaseChain& Parent) const
	{
		int32 NumParentStructBasesInChainMinusOne = Parent.NumStructBasesInChainMinusOne;
		return NumParentStructBasesInChainMinusOne <= NumStructBasesInChainMinusOne && StructBaseChainArray[NumParentStructBasesInChainMinusOne] == &Parent;
	}

private:
	FStructBaseChain** StructBaseChainArray;
	int32 NumStructBasesInChainMinusOne;

	friend class UStruct;
};

class UStruct : public UField, private FStructBaseChain
{
public:
	class UStruct*  SuperStruct;  
	class UField*   Children;   
	class FField*   ChildProperties;  
	int32           Size;             
	int32           MinAlignemnt;  
	uint8           Pad_38[0x50]; 

    FORCEINLINE bool IsChildOf(UStruct* SomeBase) const
    {
        return FStructBaseChain::IsChildOfUsingStructArray(*SomeBase);
    }
};

class UFunction : public UStruct
{
public:
	using FNativeFuncPtr = void (*)(void* Context, void* TheStack, void* Result); 

	EFunctionFlags FunctionFlags;
    uint8          NumParms;
    uint16         ParmsSize;
    uint16         ReturnValueOffset;
	uint8          Pad_42[0x20];  
	FNativeFuncPtr ExecFunction;    

};

class UClass : public UStruct
{
public:
	uint8            Pad_3D[0x28]; 
	EClassCastFlags  ClassCastFlags;    
	uint8            Pad_3E[0x40];       
	class UObject*   ClassDefaultObject;   
	uint8            Pad_3F[0x100]; 

public:
	class UFunction* GetFunction(const std::string& ClassName, const std::string& FuncName) const;

    int32 GetOffset(const std::string& Name, uint8* OutBit = nullptr)
    {
        for (UStruct* Super = this; Super; Super = Super->SuperStruct)
        {
            for (FField* Field = Super->ChildProperties; Field; Field = Field->Next)
            {
                if (Field->Name.ToString() == Name)
                {
                    if (OutBit && Field->IsA(EClassCastFlags::BoolProperty))
                        *OutBit = static_cast<FBoolProperty*>(Field)->ByteMask;

                    return static_cast<FProperty*>(Field)->Offset;
                }
            }
        }
        return 0;
    }

    FProperty* GetPropertyPtr(const std::string& Name)
    {
        for (UStruct* Super = this; Super; Super = Super->SuperStruct)
        {
            for (FField* Field = Super->ChildProperties; Field; Field = Field->Next)
            {
                if (Field->Name.ToString() == Name)
                {
                    return static_cast<FProperty*>(Field);
                }
            }
        }
        return nullptr;
    }

    UObject* GetDefaultObj() const
    {
        return ClassDefaultObject;
    }
};

static_assert(offsetof(UStruct, SuperStruct) ==
                  ServerHost::SDKProfile::Layout::UStructSuperStruct,
              "Fresh SDK UStruct::SuperStruct mismatch");
static_assert(offsetof(UStruct, Children) == ServerHost::SDKProfile::Layout::UStructChildren,
              "Fresh SDK UStruct::Children mismatch");
static_assert(offsetof(UStruct, ChildProperties) ==
                  ServerHost::SDKProfile::Layout::UStructChildProperties,
              "Fresh SDK UStruct::ChildProperties mismatch");

#pragma clang diagnostic pop


class FWeakObjectPtr
{
public:
    int32 ObjectIndex;
    int32 ObjectSerialNumber; 

public:
    class UObject *Get() const;
    class UObject *operator->() const;
    bool operator==(const FWeakObjectPtr &Other) const;
    bool operator!=(const FWeakObjectPtr &Other) const;
    bool operator==(const class UObject *Other) const;
    bool operator!=(const class UObject *Other) const;
    bool IsValid() const;
    bool SerialNumbersMatch(const FUObjectItem *ObjectItem) const;
};

template <typename UEType>
class TWeakObjectPtr : public FWeakObjectPtr
{
public:
    UEType *Get() const
    {
        return static_cast<UEType *>(FWeakObjectPtr::Get());
    }

    UEType *operator->() const
    {
        return static_cast<UEType *>(FWeakObjectPtr::Get());
    }

    inline bool IsValid() const
    {
        return FWeakObjectPtr::IsValid();
    }

    TWeakObjectPtr<UEType>& operator=(const UObject* Object)
    {
        ObjectIndex        = Object->InternalIndex;
        ObjectSerialNumber = UObject::GUObjectArray->ObjObjects.IndexToObject(ObjectIndex)->SerialNumber;
        return *this;
    }
};

/* Inlined Functions */

FORCEINLINE bool UObject::IsA(EClassCastFlags TypeFlags) const
{
	return TypeFlags == EClassCastFlags::None ||
		(ClassPrivate && (ClassPrivate->ClassCastFlags & TypeFlags));
}

FORCEINLINE int32 UObject::GetOffset(const std::string& Name, uint8* OutBit) const
{
    return ClassPrivate->GetOffset(Name, OutBit);
}

FORCEINLINE bool UObject::IsA(class UClass* TypeClass) const
{
	return ClassPrivate->IsChildOf(TypeClass);
	// if the game doesnt use USTRUCT_ISCHILDOF_STRUCTARRAY
    /*
	if (!TypeClass)
		return false;

	for (UStruct* Super = ClassPrivate; Super; Super = Super->SuperStruct)
	{
		if (Super == TypeClass)
			return true;
	}

	return false;*/
}

FORCEINLINE class UObject* FWeakObjectPtr::Get() const
{
	if (!UObject::GUObjectArray || ObjectIndex < 0 || ObjectSerialNumber == 0)
		return nullptr;
	const FUObjectItem* Item = UObject::GUObjectArray->ObjObjects.IndexToObject(ObjectIndex);
	if (!Item || !SerialNumbersMatch(Item) || Item->IsUnreachable()
		|| Item->IsPendingKill())
		return nullptr;
	return Item->Object;
}

FORCEINLINE class UObject* FWeakObjectPtr::operator->() const
{
	return Get();
}

FORCEINLINE bool FWeakObjectPtr::operator==(const FWeakObjectPtr& Other) const
{
	return ObjectIndex == Other.ObjectIndex;
}

FORCEINLINE bool FWeakObjectPtr::operator!=(const FWeakObjectPtr& Other) const
{
	return ObjectIndex != Other.ObjectIndex;
}

FORCEINLINE bool FWeakObjectPtr::operator==(const class UObject* Other) const
{
	return ObjectIndex == Other->InternalIndex;
}

FORCEINLINE bool FWeakObjectPtr::operator!=(const class UObject* Other) const
{
	return ObjectIndex != Other->InternalIndex;
}

FORCEINLINE bool FWeakObjectPtr::SerialNumbersMatch(const FUObjectItem* ObjectItem) const
{
    return ObjectItem->SerialNumber == ObjectSerialNumber;
}
