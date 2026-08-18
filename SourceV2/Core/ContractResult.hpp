#pragma once

#include <optional>
#include <string>
#include <utility>
#include <variant>

namespace serverhost::v2 {

enum class ContractErrorCategory {
    InvalidArgument,
    MalformedLayout,
    OutOfRange,
    UnsupportedProfile,
    MissingEvidence,
    StaleIdentity,
    WrongGeneration,
    TypeMismatch,
    NotFound,
    ChangedDuringCapture,
    Cancelled,
    LimitExceeded,
};

struct ContractError final {
    ContractErrorCategory category{};
    std::string context;

    friend bool operator==(const ContractError&, const ContractError&) = default;
};

template <typename T>
class ContractResult final {
public:
    static ContractResult Success(T value) {
        return ContractResult(std::move(value));
    }

    static ContractResult Failure(ContractErrorCategory category, std::string context) {
        return ContractResult(ContractError{category, std::move(context)});
    }

    [[nodiscard]] bool HasValue() const noexcept {
        return std::holds_alternative<T>(storage_);
    }

    [[nodiscard]] explicit operator bool() const noexcept { return HasValue(); }

    [[nodiscard]] const T& Value() const { return std::get<T>(storage_); }
    [[nodiscard]] T& Value() { return std::get<T>(storage_); }
    [[nodiscard]] const ContractError& Error() const { return std::get<ContractError>(storage_); }

private:
    explicit ContractResult(T value) : storage_(std::move(value)) {}
    explicit ContractResult(ContractError error) : storage_(std::move(error)) {}

    std::variant<T, ContractError> storage_;
};

template <>
class ContractResult<void> final {
public:
    static ContractResult Success() { return ContractResult(std::nullopt); }

    static ContractResult Failure(ContractErrorCategory category, std::string context) {
        return ContractResult(ContractError{category, std::move(context)});
    }

    [[nodiscard]] bool HasValue() const noexcept { return !error_.has_value(); }
    [[nodiscard]] explicit operator bool() const noexcept { return HasValue(); }
    [[nodiscard]] const ContractError& Error() const { return *error_; }

private:
    explicit ContractResult(std::optional<ContractError> error) : error_(std::move(error)) {}
    explicit ContractResult(ContractError error) : error_(std::move(error)) {}

    std::optional<ContractError> error_;
};

}  // namespace serverhost::v2
