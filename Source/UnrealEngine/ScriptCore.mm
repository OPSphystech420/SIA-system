#include "ScriptCore.h"
#include "Enums.hpp"
#include "CommonTypes.hpp"
#include <cstddef>

std::unordered_map<UClass*, std::unordered_map<std::string, int32>> UObject::OffsetsMap;
std::unordered_map<UClass*, std::unordered_map<std::string, std::pair<int32, uint8>>> UObject::BitOffsetsMap;

FMatrix FMatrix::Identity = FMatrix(
	FPlane(1, 0, 0, 0),
	FPlane(0, 1, 0, 0), 
	FPlane(0, 0, 1, 0), 
	FPlane(0, 0, 0, 1) 
);
FVector2D FVector2D::Zero = FVector2D(0.0f, 0.0f);
FVector FVector::Zero = FVector(0.0f, 0.0f, 0.0f);

std::string UObject::GetFullName() const
{
	if (ClassPrivate)
	{
		std::string Temp;

		for (UObject* NextOuter = OuterPrivate; NextOuter; NextOuter = NextOuter->OuterPrivate)
		{
			Temp = NextOuter->GetName() + "." + Temp;
		}

		std::string Name = ClassPrivate->GetName();
		Name += " ";
		Name += Temp;
		Name += GetName();

		return Name;
	}

	return "None";
}

std::string UObject::GetName() const
{
	std::string RawString = NamePrivate.ToString();

	size_t Pos = RawString.rfind('/');
	if (Pos == std::string::npos)
		return RawString;

	return RawString.substr(Pos + 1);
}

bool UObject::HasTypeFlag(EClassCastFlags TypeFlags) const
{
	return TypeFlags == EClassCastFlags::None ||
		(ClassPrivate && (ClassPrivate->ClassCastFlags & TypeFlags));
}

bool UObject::IsA(FName TypeName) const
{
	if (TypeName.GetDisplayIndex() == -1)
		return false;

	for (UStruct* Super = ClassPrivate; Super; Super = Super->SuperStruct)
	{
		if (Super->NamePrivate == TypeName)
			return true;
	}

	return false;
}

bool UObject::IsDefaultObject() const
{
	return (ObjectFlags & EObjectFlags::ClassDefaultObject);
}

FName UObject::GetClassName() const
{
	return ClassPrivate->NamePrivate;
}

class UFunction* UClass::GetFunction(const std::string& ClassName, const std::string& FuncName) const
{
	for (const UStruct* Clss = this; Clss; Clss = Clss->SuperStruct)
	{
		if (Clss->GetName() != ClassName)
			continue;
			
		for (UField* Field = Clss->Children; Field; Field = Field->Next)
		{
			if (Field->HasTypeFlag(EClassCastFlags::Function) && Field->GetName() == FuncName)
				return static_cast<class UFunction*>(Field);
		}
	}

	return nullptr;
}

bool FWeakObjectPtr::IsValid() const
{
    if (ObjectIndex < 0 || ObjectSerialNumber == 0)
        return false;

    auto ObjectItem = UObject::GUObjectArray->ObjObjects.IndexToObject(ObjectIndex);
    if (!ObjectItem)
        return false;

    if (!SerialNumbersMatch(ObjectItem)) 
        return false;

    return !(ObjectItem->IsUnreachable() || ObjectItem->IsPendingKill());
}
