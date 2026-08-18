#pragma once

namespace serverhost::v2::ui {

// Safe to call from a dylib constructor. UIKit work is always transferred to
// the main queue and driven by application/scene lifecycle notifications.
void RequestDiagnosticUIBootstrap();

}  // namespace serverhost::v2::ui
