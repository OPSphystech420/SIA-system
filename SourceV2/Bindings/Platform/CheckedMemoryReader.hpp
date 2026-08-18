#pragma once

#include "SourceV2/Bindings/Platform/ExactProfileSelector.hpp"
#include "SourceV2/Bindings/Platform/MemorySource.hpp"
#include "SourceV2/Core/ContractResult.hpp"

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <memory>
#include <span>
#include <type_traits>
#include <vector>

namespace serverhost::v2::bindings::platform {

enum class MemoryReadKind {
    ReadableData,
    ExecutableText,
};

class CheckedMemoryReader final {
public:
    [[nodiscard]] static ContractResult<CheckedMemoryReader> Create(
        const ExactProfileMatch& match, std::shared_ptr<const IMemorySource> source);

    [[nodiscard]] ContractResult<std::vector<std::byte>> ReadBytes(
        std::uintptr_t address, std::size_t size, MemoryReadKind kind) const;

    template <typename T>
    [[nodiscard]] ContractResult<T> Read(
        std::uintptr_t address, MemoryReadKind kind) const {
        static_assert(std::is_trivially_copyable_v<T>);
        const auto bytes = ReadBytes(address, sizeof(T), kind);
        if (!bytes) {
            return ContractResult<T>::Failure(bytes.Error().category, bytes.Error().context);
        }
        T value{};
        std::memcpy(&value, bytes.Value().data(), sizeof(T));
        return ContractResult<T>::Success(value);
    }

private:
    CheckedMemoryReader(
        std::vector<MappedSegment> segments, std::shared_ptr<const IMemorySource> source);

    std::vector<MappedSegment> segments_;
    std::shared_ptr<const IMemorySource> source_;
};

}  // namespace serverhost::v2::bindings::platform
