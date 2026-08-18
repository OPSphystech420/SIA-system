#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <string_view>
#include <vector>

namespace serverhost::v2::diagnostics {

enum class LogSeverity : std::uint8_t {
    Debug,
    Info,
    Warning,
    Error,
};

enum class LogCategory : std::uint8_t {
    Startup,
    Profile,
    LegacyGuard,
    UI,
    Artifact,
};

struct LogEntry final {
    std::uint64_t sequence{};
    std::uint64_t uptimeMilliseconds{};
    LogSeverity severity{LogSeverity::Info};
    LogCategory category{LogCategory::Startup};
    std::string message;
};

struct LogSnapshot final {
    std::vector<LogEntry> entries;
    std::size_t capacity{};
    std::uint64_t dropped{};
};

[[nodiscard]] const char* LogSeverityName(LogSeverity severity) noexcept;
[[nodiscard]] const char* LogCategoryName(LogCategory category) noexcept;
[[nodiscard]] std::string RedactDiagnosticText(std::string_view text,
                                                std::size_t maximumLength = 512);
[[nodiscard]] std::string FormatLogEntry(const LogEntry& entry);

class Logger final {
public:
    explicit Logger(std::size_t capacity = 128, std::size_t maximumMessageLength = 512);

    void Add(LogSeverity severity, LogCategory category, std::string_view message);
    [[nodiscard]] LogSnapshot Snapshot() const;
    [[nodiscard]] std::size_t Capacity() const noexcept;

private:
    const std::size_t capacity_;
    const std::size_t maximumMessageLength_;
    const std::chrono::steady_clock::time_point startedAt_;
    mutable std::mutex mutex_;
    std::deque<LogEntry> entries_;
    std::uint64_t nextSequence_{1};
    std::uint64_t dropped_{};
};

}  // namespace serverhost::v2::diagnostics
