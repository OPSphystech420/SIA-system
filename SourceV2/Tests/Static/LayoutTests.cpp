#include "SourceV2/Bindings/Generated/Layouts_1_10280.hpp"

namespace serverhost::v2::tests {

void CompileLayoutAssertions() {
    // All checks are static_asserts in the curated layout header. Keeping this
    // translation unit explicit makes the ABI evidence part of the test target.
}

}  // namespace serverhost::v2::tests
