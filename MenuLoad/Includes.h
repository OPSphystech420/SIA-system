#pragma once

#include "../ImGui/imgui.h"
#include "../ImGui/imgui_internal.h"
#include "../ImGui/imgui_impl_metal.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <type_traits>
#include <unordered_map>
#include <utility>
#include <vector>

using int8 = int8_t;
using int16 = int16_t;
using int32 = int32_t;
using int64 = int64_t;
using uint8 = uint8_t;
using uint16 = uint16_t;
using uint32 = uint32_t;
using uint64 = uint64_t;
using uintptr = uintptr_t;

#ifndef FORCEINLINE
#define FORCEINLINE inline __attribute__((always_inline))
#endif

template<int32 Len>
struct StringLiteral
{
    char Chars[Len];

    consteval StringLiteral(const char (&String)[Len])
    {
        std::copy_n(String, Len, Chars);
    }

    operator std::string() const
    {
        return Chars;
    }
};
