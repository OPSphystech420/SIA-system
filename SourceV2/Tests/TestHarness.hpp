#pragma once

#include <iostream>
#include <string_view>

namespace serverhost::v2::tests {

class TestContext final {
public:
    void Expect(bool condition, std::string_view expression, std::string_view file, int line) {
        ++assertions_;
        if (!condition) {
            ++failures_;
            std::cerr << file << ':' << line << ": expectation failed: " << expression << '\n';
        }
    }

    [[nodiscard]] int Assertions() const noexcept { return assertions_; }
    [[nodiscard]] int Failures() const noexcept { return failures_; }

private:
    int assertions_{};
    int failures_{};
};

}  // namespace serverhost::v2::tests

#define V2_EXPECT(context, expression) \
    (context).Expect(static_cast<bool>(expression), #expression, __FILE__, __LINE__)
