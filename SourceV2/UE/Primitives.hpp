#pragma once

#include <cstddef>
#include <cstdint>
#include <type_traits>

namespace serverhost::v2::ue {

using int8 = std::int8_t;
using int16 = std::int16_t;
using int32 = std::int32_t;
using int64 = std::int64_t;
using uint8 = std::uint8_t;
using uint16 = std::uint16_t;
using uint32 = std::uint32_t;
using uint64 = std::uint64_t;
using TCHAR = char16_t;

enum class EObjectFlags : uint32 {
    None = 0x00000000,
    Public = 0x00000001,
    ClassDefaultObject = 0x00000010,
    BeginDestroyed = 0x00008000,
    FinishDestroyed = 0x00010000,
};

enum class EFunctionFlags : uint32 {
    None = 0x00000000,
    Net = 0x00000040,
    NetReliable = 0x00000080,
    Native = 0x00000400,
    Event = 0x00000800,
    Public = 0x00020000,
    NetServer = 0x00200000,
    NetClient = 0x01000000,
    BlueprintCallable = 0x04000000,
};

enum class EClassFlags : uint32 {
    None = 0x00000000,
    Native = 0x00000080,
};

enum class EClassCastFlags : uint64 {
    None = 0x0000000000000000,
    Field = 0x0000000000000001,
    Struct = 0x0000000000000008,
    Class = 0x0000000000000020,
    Property = 0x0000000000008000,
    BoolProperty = 0x0000000000020000,
    Function = 0x0000000000080000,
};

enum class EPropertyFlags : uint64 {
    None = 0x0000000000000000,
    Parm = 0x0000000000000080,
    OutParm = 0x0000000000000100,
    ReturnParm = 0x0000000000000400,
};

template <typename Enum>
requires std::is_enum_v<Enum>
[[nodiscard]] constexpr Enum operator|(Enum left, Enum right) noexcept {
    using Underlying = std::underlying_type_t<Enum>;
    return static_cast<Enum>(static_cast<Underlying>(left) | static_cast<Underlying>(right));
}

template <typename Enum>
requires std::is_enum_v<Enum>
[[nodiscard]] constexpr bool HasAllFlags(Enum value, Enum flags) noexcept {
    using Underlying = std::underlying_type_t<Enum>;
    const auto rawValue = static_cast<Underlying>(value);
    const auto rawFlags = static_cast<Underlying>(flags);
    return (rawValue & rawFlags) == rawFlags;
}

static_assert(sizeof(int8) == 1 && sizeof(uint8) == 1);
static_assert(sizeof(int16) == 2 && sizeof(uint16) == 2);
static_assert(sizeof(int32) == 4 && sizeof(uint32) == 4);
static_assert(sizeof(int64) == 8 && sizeof(uint64) == 8);
static_assert(sizeof(TCHAR) == 2);
static_assert(sizeof(void*) == 8, "Gate 1 layout evidence is for 64-bit ShooterGame only");

}  // namespace serverhost::v2::ue
