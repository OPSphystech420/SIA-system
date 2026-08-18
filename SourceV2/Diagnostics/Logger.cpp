#include "SourceV2/Diagnostics/Logger.hpp"

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <limits>

namespace serverhost::v2::diagnostics {
namespace {

constexpr std::size_t kMinimumCapacity = 1;
constexpr std::size_t kMinimumMessageLength = 32;

bool IsHexDigit(char value) noexcept {
    return std::isxdigit(static_cast<unsigned char>(value)) != 0;
}

char Lower(char value) noexcept {
    return static_cast<char>(std::tolower(static_cast<unsigned char>(value)));
}

bool IsTokenBoundary(char value) noexcept {
    return value == '&' || value == ',' || value == ';' || value == ']' || value == '}';
}

void ReplaceAddressLiterals(std::string& text) {
    std::size_t cursor = 0;
    while (cursor + 2 < text.size()) {
        if (text[cursor] != '0' || (text[cursor + 1] != 'x' && text[cursor + 1] != 'X')) {
            ++cursor;
            continue;
        }
        std::size_t end = cursor + 2;
        while (end < text.size() && IsHexDigit(text[end])) {
            ++end;
        }
        if (end - (cursor + 2) < 6) {
            cursor = end;
            continue;
        }
        text.replace(cursor, end - cursor, "<address>");
        cursor += sizeof("<address>") - 1;
    }
}

void ReplaceSensitiveValue(std::string& text, std::string& lower, std::size_t keyPosition,
                           std::size_t keyLength) {
    const bool consumeSpaces = lower.compare(keyPosition, keyLength, "authorization") == 0;
    std::size_t valueStart = keyPosition + keyLength;
    while (valueStart < text.size()
           && (text[valueStart] == ' ' || text[valueStart] == '\t')) {
        ++valueStart;
    }
    if (valueStart < text.size() && (text[valueStart] == '=' || text[valueStart] == ':')) {
        ++valueStart;
    }
    while (valueStart < text.size()
           && (text[valueStart] == ' ' || text[valueStart] == '\t')) {
        ++valueStart;
    }
    if (valueStart >= text.size()) {
        return;
    }

    std::size_t valueEnd = valueStart;
    const char quote = text[valueStart] == '\'' || text[valueStart] == '"'
        ? text[valueStart]
        : '\0';
    if (quote != '\0') {
        ++valueStart;
        valueEnd = text.find(quote, valueStart);
        if (valueEnd == std::string::npos) {
            valueEnd = text.size();
        }
    } else {
        while (valueEnd < text.size()
               && (consumeSpaces
                   || !std::isspace(static_cast<unsigned char>(text[valueEnd])))
               && !IsTokenBoundary(text[valueEnd])) {
            ++valueEnd;
        }
    }
    if (valueEnd <= valueStart) {
        return;
    }
    text.replace(valueStart, valueEnd - valueStart, "<redacted>");
    lower.assign(text);
    std::transform(lower.begin(), lower.end(), lower.begin(), Lower);
}

void ReplaceSensitiveFields(std::string& text) {
    constexpr std::string_view keys[] = {
        "authorization", "password", "passwd", "api_key", "apikey", "secret", "token",
        "udid",
    };
    std::string lower(text);
    std::transform(lower.begin(), lower.end(), lower.begin(), Lower);

    for (const std::string_view key : keys) {
        std::size_t cursor = 0;
        while ((cursor = lower.find(key, cursor)) != std::string::npos) {
            ReplaceSensitiveValue(text, lower, cursor, key.size());
            cursor += key.size();
        }
    }

    std::size_t bearer = 0;
    while ((bearer = lower.find("bearer ", bearer)) != std::string::npos) {
        const std::size_t valueStart = bearer + sizeof("bearer ") - 1;
        std::size_t valueEnd = valueStart;
        while (valueEnd < text.size()
               && !std::isspace(static_cast<unsigned char>(text[valueEnd]))
               && !IsTokenBoundary(text[valueEnd])) {
            ++valueEnd;
        }
        if (valueEnd > valueStart) {
            text.replace(valueStart, valueEnd - valueStart, "<redacted>");
            lower.assign(text);
            std::transform(lower.begin(), lower.end(), lower.begin(), Lower);
        }
        bearer = valueStart + sizeof("<redacted>") - 1;
    }
}

}  // namespace

const char* LogSeverityName(LogSeverity severity) noexcept {
    switch (severity) {
        case LogSeverity::Debug: return "debug";
        case LogSeverity::Info: return "info";
        case LogSeverity::Warning: return "warning";
        case LogSeverity::Error: return "error";
    }
    return "unknown";
}

const char* LogCategoryName(LogCategory category) noexcept {
    switch (category) {
        case LogCategory::Startup: return "startup";
        case LogCategory::Profile: return "profile";
        case LogCategory::LegacyGuard: return "legacy-guard";
        case LogCategory::UI: return "ui";
        case LogCategory::Artifact: return "artifact";
    }
    return "unknown";
}

std::string RedactDiagnosticText(std::string_view text, std::size_t maximumLength) {
    std::string result(text);
    for (char& value : result) {
        if (value == '\n' || value == '\r' || value == '\0') {
            value = ' ';
        }
    }
    ReplaceAddressLiterals(result);
    ReplaceSensitiveFields(result);

    const std::size_t boundedLength = std::max(maximumLength, kMinimumMessageLength);
    if (result.size() > boundedLength) {
        constexpr std::string_view suffix = "...<truncated>";
        const std::size_t prefixLength = boundedLength > suffix.size()
            ? boundedLength - suffix.size()
            : 0;
        result.resize(prefixLength);
        result.append(suffix);
    }
    return result;
}

std::string FormatLogEntry(const LogEntry& entry) {
    std::string result;
    result.reserve(entry.message.size() + 96);
    result += "seq=" + std::to_string(entry.sequence);
    result += " uptime_ms=" + std::to_string(entry.uptimeMilliseconds);
    result += " severity=";
    result += LogSeverityName(entry.severity);
    result += " category=";
    result += LogCategoryName(entry.category);
    result += " message=";
    result += entry.message;
    return result;
}

Logger::Logger(std::size_t capacity, std::size_t maximumMessageLength)
    : capacity_(std::max(capacity, kMinimumCapacity)),
      maximumMessageLength_(std::max(maximumMessageLength, kMinimumMessageLength)),
      startedAt_(std::chrono::steady_clock::now()) {}

void Logger::Add(LogSeverity severity, LogCategory category, std::string_view message) {
    LogEntry entry;
    entry.severity = severity;
    entry.category = category;
    entry.message = RedactDiagnosticText(message, maximumMessageLength_);
    const auto elapsed = std::chrono::steady_clock::now() - startedAt_;
    entry.uptimeMilliseconds = static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(elapsed).count());

    std::lock_guard lock(mutex_);
    entry.sequence = nextSequence_++;
    if (entries_.size() == capacity_) {
        entries_.pop_front();
        ++dropped_;
    }
    entries_.push_back(entry);
    const std::string formatted = FormatLogEntry(entry);
    std::fprintf(stderr, "[ServerHostV2] %s\n", formatted.c_str());
}

LogSnapshot Logger::Snapshot() const {
    std::lock_guard lock(mutex_);
    return LogSnapshot{
        .entries = std::vector<LogEntry>(entries_.begin(), entries_.end()),
        .capacity = capacity_,
        .dropped = dropped_,
    };
}

std::size_t Logger::Capacity() const noexcept {
    return capacity_;
}

}  // namespace serverhost::v2::diagnostics
