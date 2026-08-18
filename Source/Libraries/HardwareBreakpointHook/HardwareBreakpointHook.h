#pragma once

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Installs ARM64 execution hardware breakpoints and redirects each matching
// function entry to the paired replacement. Targets are not byte-patched.
bool ServerHostInstallHardwareHooks(void* Targets[], void* Replacements[],
                                    int Count);

#ifdef __cplusplus
}
#endif
