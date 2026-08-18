#pragma once

#include "../UnrealEngine/NameTypes.hpp"
#include "../UnrealEngine/GeneratedSDKProfile.hpp"

namespace ServerHost
{
    enum class ENetMode : uint8
    {
        Standalone = 0,
        DedicatedServer = 1,
        ListenServer = 2,
        Client = 3,
        Max = 4
    };

    struct FURL
    {
        FString Protocol;
        FString Host;
        int32 Port = 0;
        int32 Valid = 1;
        FString Map;
        FString RedirectURL;
        TArray<FString> Op;
        FString Portal;
    };

    struct FNetDriverDefinition
    {
        FName DefName;
        FName DriverClassName;
        FName DriverClassNameFallback;
    };

#if defined(__aarch64__)
    static_assert(sizeof(FURL) == SDKProfile::Layout::FURLSize,
                  "Fresh SDK FURL layout mismatch");
    static_assert(offsetof(FURL, Port) == 0x20,
                  "Fresh SDK FURL::Port layout mismatch");
    static_assert(offsetof(FURL, Valid) == 0x24,
                  "Fresh SDK FURL::Valid layout mismatch");
    static_assert(sizeof(FNetDriverDefinition) == SDKProfile::Layout::FNetDriverDefinitionSize,
                  "Fresh SDK FNetDriverDefinition layout mismatch");
    static_assert(offsetof(FNetDriverDefinition, DefName) == 0x0,
                  "Fresh SDK FNetDriverDefinition::DefName mismatch");
    static_assert(offsetof(FNetDriverDefinition, DriverClassName) == 0x8,
                  "Fresh SDK FNetDriverDefinition::DriverClassName mismatch");
    static_assert(offsetof(FNetDriverDefinition, DriverClassNameFallback) == 0x10,
                  "Fresh SDK FNetDriverDefinition::DriverClassNameFallback mismatch");
#endif
}
