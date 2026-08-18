//
// Made by OPSphystech420
//

#ifndef MEMORY_H
#define MEMORY_H

#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <type_traits> 
#include <utility>    
#include "Singleton.h"

typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;
typedef intptr_t intptr;
typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;
typedef uintptr_t uintptr;

class Memory : public Singleton<Memory> 
{
public:
    
    uintptr_t GetImageBase(const char* imageName) const noexcept
    {
        if (!imageName || !*imageName)
            return 0;

        for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
            const char* loadedName = _dyld_get_image_name(i);
            if (loadedName && strstr(loadedName, imageName)) {
                return reinterpret_cast<uintptr_t>(_dyld_get_image_header(i));
            }
        }

        return 0;
    }
    
    uintptr_t GetOffset(uintptr_t offset) const noexcept 
    {
        return GetImageBase("ShooterGame") + offset;
    }

    bool IsValid(uintptr_t addr) const noexcept 
    {
        return addr > 0x100000000 && addr < 0x3000000000;
    }

    bool IsNull(uintptr_t addr) const noexcept 
    {
        return !IsValid(addr);
    }

    template<typename T>
    T Read(uintptr_t address) const 
    {
        if (!IsValid(address)) return T{};
        T data;
        if (!ReadMemory(address, &data, sizeof(T))) return T{};
        return data;
    }

    template<typename T>
    void Write(uintptr_t address, const T& data) const 
    {
        if (!IsValid(address)) return;
        WriteMemory(address, &data, sizeof(T));
    }
    
    // void InitHook(void* Class, uint64_t VTableIndex, void* NewFunc) const {
    //     if (IsValidPtr(Class)) {
    //         uint64_t V_Table = Read<uint64_t>((uint64_t)Class);
    //         Write<uint64_t>(V_Table + VTableIndex, reinterpret_cast<uint64_t>(NewFunc));
    //     }
    // }
    
    template<typename Func, typename... Args>
    auto CallAddr(uintptr_t offset, Args&&... args) -> std::invoke_result_t<Func, Args...> 
    {
        auto func = reinterpret_cast<Func*>(GetOffset(offset));
        return (*func)(std::forward<Args>(args)...);
    }
    
private:
    friend class Singleton<Memory>;
    Memory() { }
    ~Memory() { }

    bool ReadMemory(uintptr_t addr, void* buffer, size_t len) const noexcept 
    {
        vm_size_t size = 0;
        kern_return_t error = vm_read_overwrite(mach_task_self(),
                                                addr, len, (vm_address_t)buffer, &size);
        return error == KERN_SUCCESS && size == len;
    }

    bool WriteMemory(uintptr_t addr, const void* buffer, size_t len) const noexcept 
    {
        kern_return_t error = vm_write(mach_task_self(),
                                       addr, (vm_offset_t)buffer, (mach_msg_type_number_t)len);
        return error == KERN_SUCCESS;
    }
};

/*
template<typename T>
class UnrealHook
{
public:
    
    bool bIsSet = false; 
    bool bIsReset = true; 
    
    UnrealHook(void* NewFunc, uint64_t VTableIndex = 0x230)
        : ClassPtr_(nullptr), VTableIndex_(VTableIndex / sizeof(void*)),
          NewFunc_(NewFunc), OrigFunc_(nullptr), Mem(Memory::GetInstance()) {}

    void SetClassPtr(T* ClassPtr) noexcept {
        ClassPtr_ = ClassPtr;
    }
    
    void VTSwap(T* NewClassPtr = nullptr) noexcept {
        T* ClassPtr = NewClassPtr ? NewClassPtr : ClassPtr_;

        if (bIsSet = IsSet(ClassPtr); !bIsSet) return;
        
        void** VTable = *reinterpret_cast<void***>(ClassPtr);
        if (VTable && VTable[VTableIndex_] != NewFunc_) {
            OrigFunc_ = VTable[VTableIndex_];
            VTable[VTableIndex_] = NewFunc_;
            bIsReset = false;
        }
    }

    void VTReset(T* NewClassPtr = nullptr) noexcept {
        T* ClassPtr = NewClassPtr ? NewClassPtr : ClassPtr_;

        if (bIsSet = IsSet(ClassPtr); !bIsSet) return;
        
        void** VTable = *reinterpret_cast<void***>(ClassPtr);
        if (VTable && VTable[VTableIndex_] != OrigFunc_) {
            VTable[VTableIndex_] = OrigFunc_;
            bIsReset = true;
        }
    }

    template<typename Func, typename... Args>
    auto CallOriginal(Args&&... args) const -> decltype(auto) {
        auto func = reinterpret_cast<Func*>(OrigFunc_);
        return (*func)(std::forward<Args>(args)...);
    }

    void CallOriginalPE(T* UObject, void* Function, void* Parameters) const {
        CallOriginal<void(T*, void*, void*)>(UObject, Function, Parameters);
    }

private:
    T* ClassPtr_;
    uint64_t VTableIndex_; 
    void* NewFunc_;
    void* OrigFunc_;
        
    Memory& Mem;

    bool IsSet(T* ptr) const noexcept {
        return ptr && Mem.IsValidPtr(ptr);
    }
};*/

#endif // MEMORY_H
