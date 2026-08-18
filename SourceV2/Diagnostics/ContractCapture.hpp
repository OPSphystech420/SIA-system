#pragma once

namespace serverhost::v2::diagnostics {

enum class ContractCaptureRequestState {
    Started,
    Busy,
    Unavailable,
};

[[nodiscard]] ContractCaptureRequestState RequestReadOnlyContractCapture();

}  // namespace serverhost::v2::diagnostics
