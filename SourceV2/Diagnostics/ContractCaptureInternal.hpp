#pragma once

#include "SourceV2/Bindings/Platform/CheckedMemoryReader.hpp"
#include "SourceV2/Bindings/Profiles/ReadOnlyContracts_1_10280.hpp"

namespace serverhost::v2::diagnostics {

void ConfigureReadOnlyContractCapture(
    bindings::platform::CheckedMemoryReader reader,
    bindings::profiles::ReadOnlyContractProfile profile);

}  // namespace serverhost::v2::diagnostics
