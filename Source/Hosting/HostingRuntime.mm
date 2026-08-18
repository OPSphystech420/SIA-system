#include "HostingRuntime.h"

#include "HostingConfig.h"
#include "../Libraries/CGuardMemory/CGPMemory.h"
#include "../UnrealEngine/ScriptCore.h"
#include "../UnrealEngine/EngineObjects.hpp"
#include "../../Utilities/Memory.h"
#include "../Libraries/HardwareBreakpointHook/HardwareBreakpointHook.h"

#include <substrate.h>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

#include <pthread.h>
#include <mach/mach.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <atomic>
#include <cctype>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <limits>
#include <sstream>
#include <unordered_set>

#ifndef SERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK
#define SERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK 0
#endif

#ifndef SERVERHOST_LIFECYCLE_AUTOSAVE
#define SERVERHOST_LIFECYCLE_AUTOSAVE 0
#endif

extern "C"
{
    uintptr_t ServerHostUEngineInitResume = 0;
    uintptr_t ServerHostUWorldBeginPlayResume = 0;
    uintptr_t ServerHostUNetDriverGetNetModeResume = 0;
    uintptr_t ServerHostShooterGameModePostLoginResume = 0;
}

namespace
{
    using UEngineInitFn = void (*)(UEngine*, void*);
    using UWorldBeginPlayFn = void (*)(UWorld*);
    using UWorldListenFn = bool (*)(UWorld*, ServerHost::FURL&);
    using UNetDriverGetNetModeFn = ServerHost::ENetMode (*)(UNetDriver*);
    using SetClientTravelFn = void (*)(UObject*, UObject*, const char16_t*, uint8);
    using ProcessEventFn = void (*)(const UObject*, UFunction*, void*);
    using DestroyNamedNetDriverFn = void (*)(UEngine*, UWorld*, FName);
    using ShooterGameModePostLoginFn = void (*)(UObject*, UObject*);
    using ShooterGameModeSaveWorldFn = void (*)(UObject*, bool, bool);

    UEngineInitFn OriginalUEngineInit = nullptr;
    UWorldBeginPlayFn OriginalUWorldBeginPlay = nullptr;
    UNetDriverGetNetModeFn OriginalUNetDriverGetNetMode = nullptr;
    UWorldListenFn UWorldListen = nullptr;
    SetClientTravelFn SetClientTravel = nullptr;
    DestroyNamedNetDriverFn DestroyNamedNetDriver = nullptr;
    ProcessEventFn OriginalProcessEvent = nullptr;
    ShooterGameModePostLoginFn OriginalShooterGameModePostLogin = nullptr;
    ShooterGameModePostLoginFn ShooterGameModeRealPostLogin = nullptr;

    // SaveWorld(true, false) needs the listen-server branch so it can collect
    // every PlayerData write task and wait for it. This is thread-local: only
    // the synchronous save call on the UE game thread observes the original
    // ListenServer result; replication on every other path remains Dedicated.
    thread_local bool SynchronousSaveUsesOriginalHostedNetMode = false;

    constexpr std::size_t NetModeCallerSampleSlots = 12;
    std::array<std::atomic<uintptr_t>, NetModeCallerSampleSlots>
        NetModeCallerAddresses{};
    std::array<std::atomic<uint64>, NetModeCallerSampleSlots>
        NetModeCallerCounts{};

    void ResetNetModeCallerSamples()
    {
        for (std::size_t Index = 0; Index < NetModeCallerSampleSlots; ++Index)
        {
            NetModeCallerCounts[Index].store(0, std::memory_order_relaxed);
            NetModeCallerAddresses[Index].store(0, std::memory_order_relaxed);
        }
    }

    void SampleNetModeCaller(uintptr_t Caller)
    {
        if (!Caller)
            return;
        for (std::size_t Index = 0; Index < NetModeCallerSampleSlots; ++Index)
        {
            uintptr_t Observed = NetModeCallerAddresses[Index].load(
                std::memory_order_relaxed);
            if (Observed == Caller)
            {
                NetModeCallerCounts[Index].fetch_add(1,
                    std::memory_order_relaxed);
                return;
            }
            if (Observed == 0
                && NetModeCallerAddresses[Index].compare_exchange_strong(
                    Observed, Caller, std::memory_order_relaxed))
            {
                NetModeCallerCounts[Index].store(1,
                    std::memory_order_relaxed);
                return;
            }
        }
    }

    std::string NetModeCallerSampleSummary(uintptr_t ImageBase)
    {
        std::vector<std::pair<uint64, uintptr_t>> Samples;
        Samples.reserve(NetModeCallerSampleSlots);
        for (std::size_t Index = 0; Index < NetModeCallerSampleSlots; ++Index)
        {
            const uintptr_t Address = NetModeCallerAddresses[Index].load(
                std::memory_order_relaxed);
            const uint64 Count = NetModeCallerCounts[Index].load(
                std::memory_order_relaxed);
            if (Address && Count)
                Samples.emplace_back(Count, Address);
        }
        std::sort(Samples.begin(), Samples.end(),
            [](const auto& Left, const auto& Right)
            { return Left.first > Right.first; });
        std::ostringstream Result;
        const std::size_t Count = std::min<std::size_t>(Samples.size(), 8);
        for (std::size_t Index = 0; Index < Count; ++Index)
        {
            if (Index) Result << ", ";
            const uintptr_t Address = Samples[Index].second;
            Result << "0x" << std::hex
                   << (ImageBase && Address >= ImageBase
                        ? Address - ImageBase : Address)
                   << std::dec << ":" << Samples[Index].first;
        }
        return Result.str();
    }

    std::atomic<bool> ApplicationLifecycleSaveQueued{false};
    id ApplicationDidEnterBackgroundObserver = nil;
    id SceneDidEnterBackgroundObserver = nil;
    id ApplicationWillTerminateObserver = nil;
    id ApplicationDidBecomeActiveObserver = nil;
    id SceneDidActivateObserver = nil;

    void QueueBestEffortLifecycleSave()
    {
        const ServerHost::RuntimeSnapshot State =
            ServerHost::HostingRuntime::Get().Snapshot();
        if (State.CurrentRole != ServerHost::Role::Host || !State.Hosting
            || ApplicationLifecycleSaveQueued.exchange(
                true, std::memory_order_acq_rel))
            return;
        // UIApplication/UIScene notifications arrive on UIKit's thread. The
        // public request only enqueues an immutable command; UE work remains
        // on the confirmed game thread.
        ServerHost::HostingRuntime::Get().RequestSaveWorld();
    }

    [[maybe_unused]] void InstallApplicationLifecycleObservers()
    {
        NSNotificationCenter* Center = NSNotificationCenter.defaultCenter;
        if (ApplicationDidEnterBackgroundObserver)
            return;
        ApplicationDidEnterBackgroundObserver = [Center
            addObserverForName:UIApplicationDidEnterBackgroundNotification
                        object:nil queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification* Note) {
            QueueBestEffortLifecycleSave();
        }];
        SceneDidEnterBackgroundObserver = [Center
            addObserverForName:UISceneDidEnterBackgroundNotification
                        object:nil queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification* Note) {
            QueueBestEffortLifecycleSave();
        }];
        ApplicationWillTerminateObserver = [Center
            addObserverForName:UIApplicationWillTerminateNotification
                        object:nil queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification* Note) {
            QueueBestEffortLifecycleSave();
        }];
        ApplicationDidBecomeActiveObserver = [Center
            addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification* Note) {
            ApplicationLifecycleSaveQueued.store(false,
                std::memory_order_release);
        }];
        SceneDidActivateObserver = [Center
            addObserverForName:UISceneDidActivateNotification
                        object:nil queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification* Note) {
            ApplicationLifecycleSaveQueued.store(false,
                std::memory_order_release);
        }];
    }

    // Sishen's hardware-breakpoint redirect does not modify ShooterGame text,
    // but calling the original entry would immediately hit the same breakpoint.
    // The Init/BeginPlay trampolines replay two validated instructions;
    // GetNetMode replays four. x16 is ABI scratch state. Do not replace this
    // with an in-place __TEXT patch: iOS-on-Mac validates the complete 16 KiB
    // executable page lazily and terminates the process with CODESIGNING/Invalid
    // Page when any function from the modified page executes.
    extern "C" uintptr_t ServerHostUEngineInitResume;
    extern "C" uintptr_t ServerHostUWorldBeginPlayResume;
    extern "C" uintptr_t ServerHostUNetDriverGetNetModeResume;
    extern "C" uintptr_t ServerHostShooterGameModePostLoginResume;

    extern "C" __attribute__((naked, noinline))
    void ServerHostOriginalUEngineInit(UEngine*, void*)
    {
        __asm__ volatile(
            ".inst 0xd103c3ff\n" // sub sp, sp, #0xf0
            ".inst 0xa9096ffc\n" // stp x28, x27, [sp, #0x90]
            "adrp x16, _ServerHostUEngineInitResume@PAGE\n"
            "ldr x16, [x16, _ServerHostUEngineInitResume@PAGEOFF]\n"
            "br x16\n");
    }

    extern "C" __attribute__((naked, noinline))
    void ServerHostOriginalUWorldBeginPlay(UWorld*)
    {
        __asm__ volatile(
            ".inst 0xa9bc5ff8\n" // stp x24, x23, [sp, #-0x40]!
            ".inst 0xa90157f6\n" // stp x22, x21, [sp, #0x10]
            "adrp x16, _ServerHostUWorldBeginPlayResume@PAGE\n"
            "ldr x16, [x16, _ServerHostUWorldBeginPlayResume@PAGEOFF]\n"
            "br x16\n");
    }

    extern "C" __attribute__((naked, noinline))
    ServerHost::ENetMode ServerHostOriginalUNetDriverGetNetMode(UNetDriver*)
    {
        __asm__ volatile(
            ".inst 0xa9bf7bfd\n" // stp x29, x30, [sp, #-0x10]!
            ".inst 0x910003fd\n" // mov x29, sp
            ".inst 0xf9400008\n" // ldr x8, [x0]
            ".inst 0xf941e108\n" // ldr x8, [x8, #0x3c0]
            "adrp x16, _ServerHostUNetDriverGetNetModeResume@PAGE\n"
            "ldr x16, [x16, _ServerHostUNetDriverGetNetModeResume@PAGEOFF]\n"
            "br x16\n");
    }

    extern "C" __attribute__((naked, noinline))
    void ServerHostOriginalShooterGameModePostLogin(UObject*, UObject*)
    {
        __asm__ volatile(
            ".inst 0xa9be4ff4\n" // stp x20, x19, [sp, #-0x20]!
            ".inst 0xa9017bfd\n" // stp x29, x30, [sp, #0x10]
            "adrp x16, _ServerHostShooterGameModePostLoginResume@PAGE\n"
            "ldr x16, [x16, _ServerHostShooterGameModePostLoginResume@PAGEOFF]\n"
            "br x16\n");
    }

    uintptr_t HandleNewPlayerNativeAddress = 0;
    uintptr_t ClientHUDInitNativeAddress = 0;
    uintptr_t ClientCharacterCreationNativeAddress = 0;
    uintptr_t ClientSpawnUINativeAddress = 0;
    uintptr_t CharacterUICallbackNativeAddress = 0;

    enum DiagnosticEvent : int32
    {
        HandleNewPlayer = 0,
        HandleStartingNewPlayer,
        InitializeHUDForPlayer,
        K2PostLogin,
        RestartPlayer,
        ClientSetHUDAndInitUIScenes,
        ClientShowCharacterCreationUI,
        ClientShowSpawnUI,
        ClientShowSpawnUIForTransferringPlayer,
        ClientRestart,
        ClientRetryClientRestart,
        ServerRequestCreateNewPlayer,
        ServerRequestRespawnAtPoint,
        HandleNetworkError,
        HandleTravelError,
        K2OnLogout,
        ClientNotifyCantHarvest,
        ClientNotifyCantHitHarvest,
        ClientNotifyHitHarvest,
        DiagnosticEventCount
    };

    static_assert(DiagnosticEventCount == 19,
                  "Diagnostic event count must match RuntimeSnapshot storage");

    constexpr std::array<const char*, DiagnosticEventCount> DiagnosticFunctionNames = {{
        "Function ShooterGame.ShooterGameMode.HandleNewPlayer",
        "Function Engine.GameModeBase.HandleStartingNewPlayer",
        "Function Engine.GameModeBase.InitializeHUDForPlayer",
        "Function Engine.GameModeBase.K2_PostLogin",
        "Function Engine.GameModeBase.RestartPlayer",
        "Function ShooterGame.ShooterPlayerController.ClientSetHUDAndInitUIScenes",
        "Function ShooterGame.ShooterPlayerController.ClientShowCharacterCreationUI",
        "Function ShooterGame.ShooterPlayerController.ClientShowSpawnUI",
        "Function ShooterGame.ShooterPlayerController.ClientShowSpawnUIForTransferringPlayer",
        "Function Engine.PlayerController.ClientRestart",
        "Function Engine.PlayerController.ClientRetryClientRestart",
        "Function ShooterGame.ShooterPlayerState.ServerRequestCreateNewPlayer",
        "Function ShooterGame.ShooterPlayerController.ServerRequestRespawnAtPoint",
        "Function Engine.GameInstance.HandleNetworkError",
        "Function Engine.GameInstance.HandleTravelError",
        "Function Engine.GameModeBase.K2_OnLogout",
        "Function ShooterGame.ShooterPlayerController.ClientNotifyCantHarvest",
        "Function ShooterGame.ShooterPlayerController.ClientNotifyCantHitHarvest",
        "Function ShooterGame.ShooterPlayerController.ClientNotifyHitHarvest"
    }};

    std::array<std::atomic<UFunction*>, DiagnosticEventCount> DiagnosticFunctions{};

    std::string BuildPlayerFlowSummary(
        const std::array<int32, DiagnosticEventCount>& Counts,
        int32 CharacterCallbackCount)
    {
        std::ostringstream Summary;
        Summary << "HandleNewPlayer=" << Counts[HandleNewPlayer]
                << ", HUDInit=" << Counts[ClientSetHUDAndInitUIScenes]
                << ", CharacterUI=" << Counts[ClientShowCharacterCreationUI]
                << ", CharacterUICallback=" << CharacterCallbackCount
                << ", SpawnUI=" << (Counts[ClientShowSpawnUI]
                    + Counts[ClientShowSpawnUIForTransferringPlayer])
                << ", ClientRestart=" << (Counts[ClientRestart]
                    + Counts[ClientRetryClientRestart])
                << ", CreateRequest=" << Counts[ServerRequestCreateNewPlayer]
                << ", RespawnRequest=" << Counts[ServerRequestRespawnAtPoint]
                << ", NetworkError=" << Counts[HandleNetworkError]
                << ", TravelError=" << Counts[HandleTravelError]
                << ", Logout=" << Counts[K2OnLogout]
                << ", CantHarvest=" << Counts[ClientNotifyCantHarvest]
                << ", CantHitHarvest=" << Counts[ClientNotifyCantHitHarvest]
                << ", HitHarvest=" << Counts[ClientNotifyHitHarvest];
        return Summary.str();
    }

    struct ArrayHeader
    {
        void* Data = nullptr;
        int32 Num = 0;
        int32 Max = 0;
    };

    static_assert(sizeof(ArrayHeader) == 0x10, "TArray header layout mismatch");

    constexpr const char* GameNetDriverName = "GameNetDriver";
    constexpr const char* IpNetDriverPath = "/Script/OnlineSubsystemUtils.IpNetDriver";

    uint64 CurrentThreadToken()
    {
        return static_cast<uint64>(pthread_mach_thread_np(pthread_self()));
    }

    const char* RecoveryStateName(ServerHost::RecoveryState State)
    {
        using StateType = ServerHost::RecoveryState;
        switch (State)
        {
            case StateType::Discovered: return "Discovered";
            case StateType::WaitingForPlayerState: return "WaitingForPlayerState";
            case StateType::EligibleForRecovery: return "EligibleForRecovery";
            case StateType::RPC1Sent: return "RPC1Sent";
            case StateType::RPC2Sent: return "RPC2Sent";
            case StateType::AwaitingPlayerData: return "AwaitingPlayerData";
            case StateType::AwaitingPawn: return "AwaitingPawn";
            case StateType::Playing: return "Playing";
            case StateType::Completed: return "Completed";
            case StateType::TimedOut: return "TimedOut";
            case StateType::Disconnected: return "Disconnected";
            case StateType::WorldChanged: return "WorldChanged";
            case StateType::Failed: return "Failed";
        }
        return "Unknown";
    }

    bool HasControlCharacters(const std::string& Value)
    {
        return std::any_of(Value.begin(), Value.end(), [](unsigned char Character)
        {
            return Character < 0x20 || Character == 0x7f;
        });
    }

    bool IsSafePasswordOption(const std::string& Password)
    {
        return Password.size() <= 80 && !HasControlCharacters(Password)
            && Password.find('?') == std::string::npos
            && Password.find('&') == std::string::npos
            && Password.find('=') == std::string::npos;
    }

    std::string Lowercase(std::string Value)
    {
        std::transform(Value.begin(), Value.end(), Value.begin(),
                       [](unsigned char Character)
                       { return static_cast<char>(std::tolower(Character)); });
        return Value;
    }

    std::string RedactSecrets(std::string Message)
    {
        static constexpr std::array<const char*, 5> Keys = {{
            "serverpassword=", "password=", "token=", "authorization:", "bearer "
        }};
        std::string Search = Lowercase(Message);
        for (const char* Key : Keys)
        {
            std::size_t Position = 0;
            const std::size_t KeySize = std::strlen(Key);
            while ((Position = Search.find(Key, Position)) != std::string::npos)
            {
                const std::size_t ValueStart = Position + KeySize;
                std::size_t ValueEnd = ValueStart;
                while (ValueEnd < Message.size()
                       && Message[ValueEnd] != '&'
                       && Message[ValueEnd] != '?' && Message[ValueEnd] != ' '
                       && Message[ValueEnd] != '\n' && Message[ValueEnd] != '\r')
                    ++ValueEnd;
                Message.replace(ValueStart, ValueEnd - ValueStart, "<redacted>");
                Search = Lowercase(Message);
                Position = ValueStart + std::strlen("<redacted>");
            }
        }
        return Message;
    }

    bool IsIpNetDriverPath(const std::string& Path)
    {
        return Path == IpNetDriverPath || Path == "OnlineSubsystemUtils.IpNetDriver";
    }

    std::string HexAddress(uintptr_t Address)
    {
        std::ostringstream Stream;
        Stream << "0x" << std::hex << Address;
        return Stream.str();
    }

    const char* NetworkFailureName(uint8 Value)
    {
        static constexpr const char* Names[] = {
            "NetDriverAlreadyExists", "NetDriverCreateFailure", "NetDriverListenFailure",
            "ConnectionLost", "ConnectionTimeout", "FailureReceived", "OutdatedClient",
            "OutdatedServer", "PendingConnectionFailure", "NetGuidMismatch",
            "NetChecksumMismatch", "TotalConversionIDMismatch", "ModMisMatch",
            "ModDLCNotInstalled", "BuildIdMismatch"
        };
        return Value < std::size(Names) ? Names[Value] : "Unknown";
    }

    const char* TravelFailureName(uint8 Value)
    {
        static constexpr const char* Names[] = {
            "NoLevel", "LoadMapFailure", "InvalidURL", "PackageMissing",
            "PackageVersion", "NoDownload", "TravelFailure", "CheatCommands",
            "PendingNetGameCreateFailure", "CloudSaveFailure", "ServerTravelFailure",
            "ClientTravelFailure"
        };
        return Value < std::size(Names) ? Names[Value] : "Unknown";
    }

    bool LooksLikeUObject(void* Candidate);
    void* ReadPointer(uintptr_t Address);
    bool IsClassOrSuper(const UObject* Object, const char* ClassName);

    std::string DescribeObject(void* Candidate)
    {
        if (!LooksLikeUObject(Candidate))
            return HexAddress(reinterpret_cast<uintptr_t>(Candidate)) + "(invalid/null)";

        UObject* Object = static_cast<UObject*>(Candidate);
        return HexAddress(reinterpret_cast<uintptr_t>(Candidate)) + "["
            + Object->GetFullName() + "]";
    }

    std::string SafeFString(const FString* Value)
    {
        if (!Value || Value->Num() <= 0)
            return "";
        const uintptr_t Data = reinterpret_cast<uintptr_t>(Value->CStr());
        const uintptr_t Last = Data + static_cast<uintptr_t>(Value->Num() - 1)
            * sizeof(char16_t);
        if (Value->Num() > 512 || Value->Max() < Value->Num()
            || !Memory::GetInstance().IsValid(Data)
            || !Memory::GetInstance().IsValid(Last)
            || Memory::GetInstance().Read<char16_t>(Last) != u'\0')
            return "<invalid FString>";
        return Value->ToString();
    }

    std::string DescribePlayerUIState(void* PlayerController)
    {
        if (!LooksLikeUObject(PlayerController))
            return "PC=" + DescribeObject(PlayerController);

        UObject* PC = static_cast<UObject*>(PlayerController);
        if (!IsClassOrSuper(PC, "ShooterPlayerController")
            || PC->GetOffset("MyHUD") != static_cast<int32>(
                ServerHost::SDKProfile::KnownBuild::APlayerControllerMyHUD))
            return "PC layout/class rejected: " + DescribeObject(PC);

        const uintptr_t PCAddress = reinterpret_cast<uintptr_t>(PC);
        UObject* HUD = static_cast<UObject*>(ReadPointer(
            PCAddress + ServerHost::SDKProfile::KnownBuild::APlayerControllerMyHUD));
        std::ostringstream Details;
        Details << "PC=" << DescribeObject(PC)
                << ", MyHUD=" << DescribeObject(HUD)
                << ", showDownloadRaw=" << static_cast<int32>(
                    *reinterpret_cast<const uint8*>(PCAddress
                        + ServerHost::SDKProfile::KnownBuild::AShooterPlayerControllerShowDownloadCharacter))
                << ", characterCallbackPendingRaw=" << static_cast<int32>(
                    *reinterpret_cast<const uint8*>(PCAddress
                        + ServerHost::SDKProfile::KnownBuild::AShooterPlayerControllerCharacterUICallbackPending));

        if (!LooksLikeUObject(HUD) || !IsClassOrSuper(HUD, "ShooterHUD"))
            return Details.str();

        const int32 OwnerOffset = HUD->GetOffset("PlayerOwner");
        const int32 TemplateOffset = HUD->GetOffset("SpawnUITemplate");
        Details << ", HUD.PlayerOwner=";
        if (OwnerOffset == static_cast<int32>(
                ServerHost::SDKProfile::KnownBuild::AHUDPlayerOwner))
            Details << DescribeObject(ReadPointer(reinterpret_cast<uintptr_t>(HUD)
                                                  + OwnerOffset));
        else
            Details << "layout-rejected(" << OwnerOffset << ")";

        if (TemplateOffset == static_cast<int32>(
                ServerHost::SDKProfile::KnownBuild::AShooterHUDSpawnUITemplate))
        {
            const uintptr_t Soft = reinterpret_cast<uintptr_t>(HUD) + TemplateOffset;
            FWeakObjectPtr Weak{};
            FName AssetPath;
            std::memcpy(&Weak, reinterpret_cast<const void*>(Soft), sizeof(Weak));
            std::memcpy(&AssetPath, reinterpret_cast<const void*>(Soft + 0xC),
                        sizeof(AssetPath));
            const FString* SubPath = reinterpret_cast<const FString*>(Soft + 0x14);
            Details << ", SpawnUITemplate={asset='" << AssetPath.ToString()
                    << "', sub='" << SafeFString(SubPath)
                    << "', weakIndex=" << Weak.ObjectIndex
                    << ", weakSerial=" << Weak.ObjectSerialNumber;
            if (Weak.IsValid())
                Details << ", resolved=" << DescribeObject(Weak.Get());
            else
                Details << ", resolved=null";
            Details << "}";
        }
        else
        {
            Details << ", SpawnUITemplate=layout-rejected(" << TemplateOffset << ")";
        }
        return Details.str();
    }

    void* ReadPointer(uintptr_t Address)
    {
        return Memory::GetInstance().Read<void*>(Address);
    }

    bool CanReadMemoryRange(uintptr_t Address, std::size_t Size)
    {
        if (Size == 0 || Address + Size - 1 < Address)
            return false;
        const auto CanReadByte = [](uintptr_t ByteAddress)
        {
            uint8 Byte = 0;
            vm_size_t ReadSize = 0;
            return vm_read_overwrite(mach_task_self(), ByteAddress, 1,
                reinterpret_cast<vm_address_t>(&Byte), &ReadSize) == KERN_SUCCESS
                && ReadSize == 1;
        };
        return CanReadByte(Address) && CanReadByte(Address + Size - 1);
    }

    bool LooksLikeUObject(void* Candidate)
    {
        const uintptr_t Address = reinterpret_cast<uintptr_t>(Candidate);
        if (!Memory::GetInstance().IsValid(Address))
            return false;

        const uintptr_t VTable = Memory::GetInstance().Read<uintptr_t>(Address);
        return Memory::GetInstance().IsValid(VTable);
    }

    bool IsClassOrSuper(const UObject* Object, const char* ClassName)
    {
        if (!Object || !LooksLikeUObject(Object->ClassPrivate) || !ClassName)
            return false;

        for (const UStruct* Class = Object->ClassPrivate; Class; Class = Class->SuperStruct)
        {
            if (!LooksLikeUObject(const_cast<UStruct*>(Class)))
                return false;
            if (Class->NamePrivate.ToString() == ClassName)
                return true;
        }
        return false;
    }

    bool IsValidEndpoint(const std::string& Endpoint)
    {
        if (Endpoint.empty() || Endpoint.size() > 253 || HasControlCharacters(Endpoint)
            || Endpoint.find_first_of("?&/\\ ") != std::string::npos)
            return false;
        const std::size_t Colon = Endpoint.rfind(':');
        if (Colon == std::string::npos || Colon == 0 || Colon + 1 >= Endpoint.size()
            || Endpoint.find(':') != Colon)
            return false;

        const std::string Host = Endpoint.substr(0, Colon);
        if (Host.front() == '.' || Host.back() == '.' || Host.front() == '-'
            || Host.back() == '-')
            return false;
        for (unsigned char Character : Host)
        {
            if (!std::isalnum(Character) && Character != '.' && Character != '-')
                return false;
        }

        const std::string PortText = Endpoint.substr(Colon + 1);
        char* End = nullptr;
        const long ParsedPort = std::strtol(PortText.c_str(), &End, 10);
        return End && *End == '\0' && ParsedPort >= 1 && ParsedPort <= 65535;
    }

    void HookUEngineInit(UEngine* Engine, void* EngineLoop)
    {
        if (OriginalUEngineInit)
            OriginalUEngineInit(Engine, EngineLoop);

        ServerHost::HostingRuntime::Get().OnEngineInit(Engine);
    }

    void HookUWorldBeginPlay(UWorld* World)
    {
        if (OriginalUWorldBeginPlay)
            OriginalUWorldBeginPlay(World);

        // Only capture the world after the original BeginPlay has completed.
        // Hosting itself is started later by Tick, outside the engine callback.
        ServerHost::HostingRuntime::Get().OnWorldBeginPlay(World);
    }

    ServerHost::ENetMode HookUNetDriverGetNetMode(UNetDriver* NetDriver)
    {
        const ServerHost::ENetMode OriginalMode = OriginalUNetDriverGetNetMode
            ? OriginalUNetDriverGetNetMode(NetDriver)
            : ServerHost::ENetMode::Standalone;

        const uintptr_t CallerAddress = reinterpret_cast<uintptr_t>(
            __builtin_return_address(0));
        return ServerHost::HostingRuntime::Get().ResolveNetMode(
            NetDriver, OriginalMode, CallerAddress);
    }

    [[maybe_unused]] void HookShooterGameModePostLogin(
        UObject* GameMode, UObject* PlayerController)
    {
        if (ServerHost::HostingRuntime::Get().RouteHostedPostLogin(
                GameMode, PlayerController))
            return;
        if (OriginalShooterGameModePostLogin)
            OriginalShooterGameModePostLogin(GameMode, PlayerController);
    }

    void HookProcessEvent(const UObject* Context, UFunction* Function, void* Parameters)
    {
        int32 EventIndex = -1;
        for (int32 Index = 0; Index < DiagnosticEventCount; ++Index)
        {
            if (DiagnosticFunctions[Index].load(std::memory_order_relaxed) == Function)
            {
                EventIndex = Index;
                break;
            }
        }

        if (EventIndex >= 0)
        {
            ServerHost::HostingRuntime::Get().OnDiagnosticProcessEvent(
                EventIndex, const_cast<UObject*>(Context), Function, Parameters, false);
        }

        if (OriginalProcessEvent)
            OriginalProcessEvent(Context, Function, Parameters);

        if (EventIndex >= 0)
        {
            ServerHost::HostingRuntime::Get().OnDiagnosticProcessEvent(
                EventIndex, const_cast<UObject*>(Context), Function, Parameters, true);
        }
    }

}

namespace ServerHost
{
    HostingRuntime& HostingRuntime::Get()
    {
        static HostingRuntime Instance;
        return Instance;
    }

    void HostingRuntime::Initialize()
    {
        std::call_once(InitializeOnce, [this]
        {
            AddLog("Initializing runtime resolver");
            {
                std::lock_guard<std::mutex> Guard(Mutex);
                HostState = HostLifecycleState::Resolving;
                ClientState = ClientLifecycleState::Ready;
            }

            bool IsIOSOnMac = false;
            if (@available(iOS 14.0, *))
            {
                NSProcessInfo* ProcessInfo = [NSProcessInfo processInfo];
                const SEL Selector = sel_registerName("isiOSAppOnMac");
                if ([ProcessInfo respondsToSelector:Selector])
                {
                    IsIOSOnMac = reinterpret_cast<BOOL (*)(id, SEL)>(objc_msgSend)(
                        ProcessInfo, Selector);
                }
            }
            {
                std::lock_guard<std::mutex> Guard(Mutex);
                IOSAppOnMac = IsIOSOnMac;
            }
            AddLog(std::string("Runtime platform: ")
                   + (IsIOSOnMac ? "iOS app on Apple Silicon Mac" : "iOS device/runtime"));

#if SERVERHOST_LIFECYCLE_AUTOSAVE
            dispatch_async(dispatch_get_main_queue(), ^{
                InstallApplicationLifecycleObservers();
            });
#else
            AddLog("Lifecycle autosave disabled for the stability A/B build; use the explicit Save world command");
#endif

            const bool Resolved = ResolveRuntimeAddresses();
            const bool Hooked = InstallHooks();
            if (Resolved)
                InstallTargetedPlayerFlowHooks();

            if (Resolved && Hooked)
            {
                {
                    std::lock_guard<std::mutex> Guard(Mutex);
                    HostState = HostLifecycleState::Ready;
                    LastError.clear();
                }
                SetStatus("Runtime resolved; hooks installed");
            }
            else if (Resolved)
            {
                {
                    std::lock_guard<std::mutex> Guard(Mutex);
                    HostState = HostLifecycleState::Failed;
                }
                SetStatus("Core resolved; one or more hosting hooks failed to resolve");
            }
            else
            {
                {
                    std::lock_guard<std::mutex> Guard(Mutex);
                    HostState = HostLifecycleState::Failed;
                }
                SetStatus("Current ShooterGame signatures did not resolve");
            }
        });
    }

    bool HostingRuntime::ResolveRuntimeAddresses()
    {
        CGPMemoryScanner Scanner(Config::ImageName);
        if (!Scanner.IsValid())
        {
            AddLog("ShooterGame Mach-O image or __TEXT segment was not found");
            return false;
        }

        auto ResolveUnique = [this, &Scanner](const char* Name, const char* Signature,
                                              bool DecodeADRPAdd) -> uintptr_t
        {
            if (!Signature || !*Signature)
            {
                AddLog(std::string(Name) + ": signature is empty");
                return 0;
            }

            const std::vector<uintptr_t> Matches = Scanner.FindIDAPatternAll(Signature);
            if (Matches.size() != 1)
            {
                AddLog(std::string(Name) + ": expected one signature match, got "
                       + std::to_string(Matches.size()));
                return 0;
            }

            return DecodeADRPAdd ? Scanner.Find_ADRL_Sig(Signature) : Matches.front();
        };

        Addresses[0] = ResolveUnique("GUObjectArray", Config::GUObjectArraySignature, true);
        Addresses[1] = ResolveUnique("FNamePool", Config::NamePoolSignature, true);
        Addresses[2] = ResolveUnique("FMemory::Realloc", Config::EngineReallocSignature, false);
        Addresses[3] = ResolveUnique("SetClientTravel", Config::SetClientTravelSignature, false);
        Addresses[4] = ResolveUnique("UEngine::Init", Config::UEngineInitSignature, false);
        Addresses[5] = ResolveUnique("UWorld::BeginPlay", Config::UWorldBeginPlaySignature, false);
        Addresses[6] = ResolveUnique("UWorld::Listen", Config::UWorldListenSignature, false);
        Addresses[7] = ResolveUnique("UNetDriver::GetNetMode",
                                     Config::UNetDriverGetNetModeSignature, false);
        Addresses[8] = ResolveUnique("UEngine::DestroyNamedNetDriver",
                                     Config::DestroyNamedNetDriverSignature, false);

        KnownProfileEligible = Config::AllowKnownSDKProfileFallback;
        for (std::size_t Index = 0; Index < 8; ++Index)
            KnownProfileEligible = KnownProfileEligible && Addresses[Index] != 0;
        if (KnownProfileEligible)
            AddLog("All native signatures match the fresh 1.10280 SDK profile");

        if (!Addresses[0] && Config::AllowKnownGUObjectArrayOffset)
        {
            Addresses[0] = Memory::GetInstance().GetImageBase(Config::ImageName)
                + Config::KnownGUObjectArrayOffset;
            AddLog("Using explicitly enabled known-build GUObjectArray offset");
        }

        if (Addresses[0])
        {
            UObject::Init(reinterpret_cast<void*>(Addresses[0]));
            AddLog("GUObjectArray: " + HexAddress(Addresses[0]));
            const int32 ObjectCount = UObject::GUObjectArray->ObjObjects.Num();
            this->ObjectCount = ObjectCount;
            AddLog("GUObjectArray objects at resolver initialization: "
                   + std::to_string(ObjectCount));
            if (ObjectCount < 0 || ObjectCount > 1000000)
            {
                AddLog("GUObjectArray validation failed");
                UObject::Init(nullptr);
                Addresses[0] = 0;
            }
        }
        else
        {
            AddLog("GUObjectArray unresolved");
        }

        if (Addresses[1])
        {
            FName::Init(reinterpret_cast<void*>(Addresses[1]));
            AddLog("FNamePool: " + HexAddress(Addresses[1]));
            if (!FName::NamePoolData->Blocks[0])
            {
                AddLog("FNamePool entry validation deferred until engine initialization");
            }
            else if (FName(0).ToString() != "None")
            {
                AddLog("FNamePool validation failed: entry zero is not None");
                FName::Init(nullptr);
                Addresses[1] = 0;
            }
        }
        else
        {
            AddLog("FNamePool unresolved");
        }

        if (Addresses[2])
        {
            FMemory::Init(reinterpret_cast<void*>(Addresses[2]));
            AddLog("FMemory::Realloc: " + HexAddress(Addresses[2]));
        }
        else
        {
            AddLog("FMemory::Realloc unresolved");
        }

        SetClientTravel = reinterpret_cast<SetClientTravelFn>(Addresses[3]);
        UWorldListen = reinterpret_cast<UWorldListenFn>(Addresses[6]);
        DestroyNamedNetDriver = reinterpret_cast<DestroyNamedNetDriverFn>(Addresses[8]);
        if (DestroyNamedNetDriver)
            AddLog("UEngine::DestroyNamedNetDriver: " + HexAddress(Addresses[8]));
        else
            AddLog("Safe Stop unavailable: DestroyNamedNetDriver signature unresolved",
                   LogLevel::Warning);

        return Addresses[0] && Addresses[1];
    }

    bool HostingRuntime::InstallHooks()
    {
        if (!Addresses[4] || !Addresses[5] || !Addresses[7])
        {
            AddLog("Hardware hook refused: one or more core addresses are unresolved",
                   LogLevel::Error);
            return false;
        }

        static constexpr uint8 EnginePrefix[8] = {
            0xFF, 0xC3, 0x03, 0xD1, 0xFC, 0x6F, 0x09, 0xA9
        };
        static constexpr uint8 WorldPrefix[8] = {
            0xF8, 0x5F, 0xBC, 0xA9, 0xF6, 0x57, 0x01, 0xA9
        };
        static constexpr uint8 NetModePrefix[16] = {
            0xFD, 0x7B, 0xBF, 0xA9, 0xFD, 0x03, 0x00, 0x91,
            0x08, 0x00, 0x40, 0xF9, 0x08, 0xE1, 0x41, 0xF9
        };
        static constexpr uint8 PostLoginPrefix[16] = {
            0xF4, 0x4F, 0xBE, 0xA9, 0xFD, 0x7B, 0x01, 0xA9,
            0xFD, 0x43, 0x00, 0x91, 0xF3, 0x03, 0x01, 0xAA
        };
        static constexpr uint8 RealPostLoginPrefix[16] = {
            0xFF, 0x43, 0x07, 0xD1, 0xEB, 0x2B, 0x16, 0x6D,
            0xE9, 0x23, 0x17, 0x6D, 0xFA, 0x67, 0x18, 0xA9
        };
        static constexpr uint8 StartNewPlayerPrefix[16] = {
            0xFF, 0xC3, 0x05, 0xD1, 0xF8, 0x5F, 0x13, 0xA9,
            0xF6, 0x57, 0x14, 0xA9, 0xF4, 0x4F, 0x15, 0xA9
        };
        const uintptr_t ImageBase = Memory::GetInstance().GetImageBase(
            Config::ImageName);
        const uintptr_t PostLoginAddress = ImageBase
            + SDKProfile::KnownBuild::ShooterGameModePostLogin;
        const uintptr_t RealPostLoginAddress = ImageBase
            + SDKProfile::KnownBuild::ShooterGameModeRealPostLogin;
        const uintptr_t StartNewPlayerAddress = ImageBase
            + SDKProfile::KnownBuild::ShooterGameModeStartNewPlayer;
        const bool CorePrefixesValid =
            std::memcmp(reinterpret_cast<const void*>(Addresses[4]),
                        EnginePrefix, sizeof(EnginePrefix)) == 0
            && std::memcmp(reinterpret_cast<const void*>(Addresses[5]),
                           WorldPrefix, sizeof(WorldPrefix)) == 0
            && std::memcmp(reinterpret_cast<const void*>(Addresses[7]),
                           NetModePrefix, sizeof(NetModePrefix)) == 0;
        const bool PostLoginPrefixesValid = KnownProfileEligible && ImageBase
            && Memory::GetInstance().IsValid(PostLoginAddress)
            && Memory::GetInstance().IsValid(RealPostLoginAddress)
            && Memory::GetInstance().IsValid(StartNewPlayerAddress)
            && std::memcmp(reinterpret_cast<const void*>(PostLoginAddress),
                           PostLoginPrefix, sizeof(PostLoginPrefix)) == 0
            && std::memcmp(reinterpret_cast<const void*>(RealPostLoginAddress),
                           RealPostLoginPrefix,
                           sizeof(RealPostLoginPrefix)) == 0
            && std::memcmp(reinterpret_cast<const void*>(StartNewPlayerAddress),
                           StartNewPlayerPrefix,
                           sizeof(StartNewPlayerPrefix)) == 0;
        if (!CorePrefixesValid
#if SERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK
            || !PostLoginPrefixesValid
#endif
            )
        {
            AddLog("Hardware hook refused: exact trampoline prefixes do not match",
                   LogLevel::Error);
            return false;
        }

        ServerHostUEngineInitResume = Addresses[4] + 8;
        ServerHostUWorldBeginPlayResume = Addresses[5] + 8;
        ServerHostUNetDriverGetNetModeResume = Addresses[7] + 16;
        OriginalUEngineInit = &ServerHostOriginalUEngineInit;
        OriginalUWorldBeginPlay = &ServerHostOriginalUWorldBeginPlay;
        OriginalUNetDriverGetNetMode = &ServerHostOriginalUNetDriverGetNetMode;
#if SERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK
        ServerHostShooterGameModePostLoginResume = PostLoginAddress + 8;
        OriginalShooterGameModePostLogin =
            &ServerHostOriginalShooterGameModePostLogin;
        ShooterGameModeRealPostLogin = reinterpret_cast<
            ShooterGameModePostLoginFn>(RealPostLoginAddress);
#else
        (void)PostLoginPrefixesValid;
        OriginalShooterGameModePostLogin = nullptr;
        ShooterGameModeRealPostLogin = nullptr;
#endif

        void* Targets[4] = {
            reinterpret_cast<void*>(Addresses[4]),
            reinterpret_cast<void*>(Addresses[5]),
            reinterpret_cast<void*>(Addresses[7]), nullptr
        };
        void* Replacements[4] = {
            reinterpret_cast<void*>(&HookUEngineInit),
            reinterpret_cast<void*>(&HookUWorldBeginPlay),
            reinterpret_cast<void*>(&HookUNetDriverGetNetMode), nullptr
        };
        int HookCount = 3;
#if SERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK
        Targets[HookCount] = reinterpret_cast<void*>(PostLoginAddress);
        Replacements[HookCount] =
            reinterpret_cast<void*>(&HookShooterGameModePostLogin);
        ++HookCount;
#endif
        const bool Installed = ServerHostInstallHardwareHooks(
            Targets, Replacements, HookCount);
        if (!Installed)
        {
            OriginalUEngineInit = nullptr;
            OriginalUWorldBeginPlay = nullptr;
            OriginalUNetDriverGetNetMode = nullptr;
            OriginalShooterGameModePostLogin = nullptr;
            ShooterGameModeRealPostLogin = nullptr;
            AddLog("ARM64 hardware-breakpoint hooks failed to install",
                   LogLevel::Error);
            return false;
        }

        AddLog("UEngine::Init hardware hook installed; exact +8 trampoline ready");
        AddLog("UWorld::BeginPlay hardware hook installed; exact +8 trampoline ready");
        AddLog("UNetDriver::GetNetMode hardware hook installed; exact +16 trampoline ready (code-signature safe)");
#if SERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK
        AddLog("AShooterGameMode::PostLogin hardware hook installed; exact +8 trampoline and RealPostLogin target ready");
#else
        AddLog("Experimental AShooterGameMode::PostLogin hook disabled; bounded reflected RPC recovery remains active");
#endif
        if (!Addresses[6])
            AddLog("UWorld::Listen signature did not resolve", LogLevel::Error);
        return Addresses[6] != 0;
    }

    bool HostingRuntime::InstallTargetedPlayerFlowHooks()
    {
        if (!KnownProfileEligible)
        {
            AddLog("Targeted player-flow hooks skipped: exact 1.10280 profile was not confirmed");
            return false;
        }

        const uintptr_t Base = Memory::GetInstance().GetImageBase(Config::ImageName);
        if (!Base)
            return false;

        HandleNewPlayerNativeAddress = Base
            + SDKProfile::KnownBuild::ShooterGameModeHandleNewPlayer;
        ClientHUDInitNativeAddress = Base
            + SDKProfile::KnownBuild::ShooterPlayerControllerClientSetHUDAndInitUIScenes;
        ClientCharacterCreationNativeAddress = Base
            + SDKProfile::KnownBuild::ShooterPlayerControllerClientShowCharacterCreationUI;
        ClientSpawnUINativeAddress = Base
            + SDKProfile::KnownBuild::ShooterPlayerControllerClientShowSpawnUI;
        CharacterUICallbackNativeAddress = Base
            + SDKProfile::KnownBuild::ShooterHUDCharacterCreationTimerCallback;

        static constexpr uint8 HandlePrefix[] = {
            0x28, 0x08, 0x02, 0xB0, 0x08, 0xD1, 0x5B, 0x39,
            0x68, 0x00, 0x00, 0x36, 0x20, 0x00, 0x80, 0x52
        };
        static constexpr uint8 HUDInitPrefix[] = {
            0xF4, 0x4F, 0xBE, 0xA9, 0xFD, 0x7B, 0x01, 0xA9,
            0xFD, 0x43, 0x00, 0x91, 0xF3, 0x03, 0x00, 0xAA
        };
        static constexpr uint8 CharacterPrefix[] = {
            0xFF, 0xC3, 0x02, 0xD1, 0xF6, 0x57, 0x08, 0xA9,
            0xF4, 0x4F, 0x09, 0xA9, 0xFD, 0x7B, 0x0A, 0xA9
        };
        static constexpr uint8 SpawnPrefix[] = {
            0xFF, 0xC3, 0x02, 0xD1, 0xE9, 0x23, 0x07, 0x6D,
            0xF6, 0x57, 0x08, 0xA9, 0xF4, 0x4F, 0x09, 0xA9
        };
        static constexpr uint8 CallbackPrefix[] = {
            0xF4, 0x4F, 0xBE, 0xA9, 0xFD, 0x7B, 0x01, 0xA9,
            0xFD, 0x43, 0x00, 0x91, 0xF3, 0x03, 0x00, 0xAA
        };

        auto Validate = [this](const char* Name, uintptr_t Address,
                               const uint8* Prefix, std::size_t Size) -> bool
        {
            if (!Address || !Memory::GetInstance().IsValid(Address)
                || !Memory::GetInstance().IsValid(Address + Size - 1)
                || std::memcmp(reinterpret_cast<const void*>(Address), Prefix, Size) != 0)
            {
                AddLog(std::string("Targeted hook validation rejected ") + Name
                       + " at " + HexAddress(Address));
                return false;
            }
            return true;
        };

        const bool Valid =
            Validate("HandleNewPlayer", HandleNewPlayerNativeAddress,
                     HandlePrefix, sizeof(HandlePrefix))
            && Validate("ClientSetHUDAndInitUIScenes", ClientHUDInitNativeAddress,
                        HUDInitPrefix, sizeof(HUDInitPrefix))
            && Validate("ClientShowCharacterCreationUI",
                        ClientCharacterCreationNativeAddress,
                        CharacterPrefix, sizeof(CharacterPrefix))
            && Validate("ClientShowSpawnUI", ClientSpawnUINativeAddress,
                        SpawnPrefix, sizeof(SpawnPrefix))
            && Validate("CharacterCreationTimerCallback",
                        CharacterUICallbackNativeAddress,
                        CallbackPrefix, sizeof(CallbackPrefix));
        if (!Valid)
        {
            AddLog("Targeted player-flow hooks refused: native prefix validation failed");
            return false;
        }

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            TargetedPlayerFlowAddressesValidated = true;
        }
        AddLog("Targeted native player-flow addresses validated (5/5) for exact 1.10280 profile");

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            TargetedPlayerFlowHooksInstalled = false;
        }
        AddLog("Targeted native player-flow hooks deliberately disabled: Substrate returned no trampolines on both tested runtimes; recovery uses reflected reliable RPC dispatch from the host");
        return true;
    }

    void HostingRuntime::Tick()
    {
        Initialize();
        ScheduleGameThreadTick();
    }

    void HostingRuntime::ScheduleGameThreadTick()
    {
        bool Expected = false;
        if (!GameThreadTaskPending.compare_exchange_strong(
                Expected, true, std::memory_order_acq_rel))
            return;

        Class AsyncTaskClass = NSClassFromString(@"FIOSAsyncTask");
        const SEL CreateSelector = sel_registerName("CreateTaskWithBlock:");
        if (!AsyncTaskClass || ![AsyncTaskClass respondsToSelector:CreateSelector])
        {
            GameThreadTaskPending.store(false, std::memory_order_release);
            AddLogOnce(LoggedGameThreadUnavailable,
                       "FIOSAsyncTask game-thread dispatcher is not available yet",
                       LogLevel::Warning);
            return;
        }

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            GameThreadDispatchAvailable = true;
        }
        HostingRuntime* Runtime = this;
        id TaskBlock = ^BOOL {
            Runtime->GameThreadTaskPending.store(false, std::memory_order_release);
            Runtime->GameThreadTick();
            return YES;
        };
        reinterpret_cast<void (*)(id, SEL, id)>(objc_msgSend)(
            AsyncTaskClass, CreateSelector, TaskBlock);
    }

    void HostingRuntime::MarkGameThread()
    {
        const uint64 Token = CurrentThreadToken();
        uint64 Expected = 0;
        if (GameThreadToken.compare_exchange_strong(
                Expected, Token, std::memory_order_acq_rel))
            AddLog("UE game thread confirmed through FIOSAsyncTask");
    }

    bool HostingRuntime::IsOnGameThread() const
    {
        const uint64 Token = GameThreadToken.load(std::memory_order_acquire);
        return Token != 0 && Token == CurrentThreadToken();
    }

    void HostingRuntime::GameThreadTick()
    {
        Initialize();
        MarkGameThread();
        DrainCommands();

        const auto Now = std::chrono::steady_clock::now();
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (LastDiscovery.time_since_epoch().count() != 0 &&
                Now - LastDiscovery < std::chrono::seconds(1))
                return;
            LastDiscovery = Now;
        }

        UEngine* Engine = nullptr;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            Engine = CachedEngine;
        }

        if (Engine && !ValidateLiveEngine(Engine))
        {
            AddLog("CachedEngine failed live ShooterEngine validation and was discarded");
            std::lock_guard<std::mutex> Guard(Mutex);
            if (CachedEngine == Engine)
            {
                CachedEngine = nullptr;
                EngineIdentity.clear();
                NetDriverPatched = false;
                NetDriverClassPath.clear();
            }
            Engine = nullptr;
        }

        if (!Engine)
            Engine = FindEngine();

        UWorld* World = Engine ? FindWorld(Engine) : nullptr;

        if (UObject::GUObjectArray)
        {
            const int32 LiveObjectCount = UObject::GUObjectArray->ObjObjects.Num();
            if (LiveObjectCount >= 0 && LiveObjectCount <= 1000000)
            {
                bool BecameReady = false;
                {
                    std::lock_guard<std::mutex> Guard(Mutex);
                    ObjectCount = LiveObjectCount;
                    BecameReady = LiveObjectCount > 0 && !LoggedObjectArrayReady;
                    if (BecameReady)
                        LoggedObjectArrayReady = true;
                }
                if (BecameReady)
                    AddLog("GUObjectArray became ready: "
                           + std::to_string(LiveObjectCount) + " objects");
            }
        }

#if SERVERHOST_DEVELOPER_UI
        // Selective ProcessEvent observation is intentionally debug-only: the
        // base function is hot, so production pays no 19-pointer filter cost.
        EnsureProcessEventDiagnosticsHook();
#endif

        WeakObjectIdentity PreviousWorldIdentity;
        UWorld* PreviousWorld = nullptr;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            PreviousWorld = CachedWorld;
            PreviousWorldIdentity = CachedWorldIdentity;
        }
        const WeakObjectIdentity LiveWorldIdentity = MakeWeakIdentity(World);
        if (World && PreviousWorldIdentity.IsSet()
            && !SameIdentity(PreviousWorldIdentity, LiveWorldIdentity))
            HandleWorldChanged(PreviousWorld, World);

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (Engine)
                CachedEngine = Engine;
            if (World)
            {
                CachedWorld = World;
                CachedWorldIdentity = LiveWorldIdentity;
                WorldName = World->NamePrivate.ToString();
            }
        }

        bool NeedsNetDriverPatch = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            NeedsNetDriverPatch = !NetDriverPatched;
        }
        if (Engine && NeedsNetDriverPatch)
        {
            {
                std::lock_guard<std::mutex> Guard(Mutex);
                if (CurrentRole == Role::Host && HostPending)
                    HostState = HostLifecycleState::PatchingNetDriver;
            }
            const bool Patched = PatchNetDriverDefinitions(Engine);
            std::lock_guard<std::mutex> Guard(Mutex);
            if (CurrentRole == Role::Host && HostPending)
                HostState = Patched ? HostLifecycleState::HostRequested
                                    : HostLifecycleState::Failed;
        }

        UNetDriver* ActiveNetDriver = nullptr;
        if (World)
        {
            UObject* WorldObject = static_cast<UObject*>(World);
            int32 NetDriverOffset = WorldObject->GetOffset("NetDriver");
            if (NetDriverOffset <= 0 && KnownProfileEligible)
            {
                NetDriverOffset = static_cast<int32>(SDKProfile::KnownBuild::UWorldNetDriver);
                AddLogOnce(LoggedWorldNetDriverFallback,
                           "Using fresh SDK UWorld::NetDriver offset 0x1D8");
            }
            if (NetDriverOffset > 0 && NetDriverOffset < 0x2000)
                ActiveNetDriver = static_cast<UNetDriver*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(World) + NetDriverOffset));
        }

        Role ActiveRole;
        bool IsHosting;
        UNetDriver* HostDriver;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ActiveRole = CurrentRole;
            IsHosting = Hosting;
            HostDriver = HostedNetDriver;
        }

        UpdateConnectionDiagnostics(World, ActiveNetDriver, ActiveRole,
                                    IsHosting, HostDriver);
        if (ActiveRole == Role::Host && IsHosting && HostDriver)
            UpdateRecoveryState(World, HostDriver);

        const uint64 HostedModeCalls = HostedNetModeCallCount.load(
            std::memory_order_relaxed);
        bool LogHostedModeActivity = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            LogHostedModeActivity = IsHosting && HostedModeCalls > 1
                && !LoggedHostedNetModeActivity;
            if (LogHostedModeActivity)
                LoggedHostedNetModeActivity = true;
        }
        if (LogHostedModeActivity)
        {
            AddLog("GetNetMode runtime activity confirmed after Listen: hostedCalls="
                   + std::to_string(HostedModeCalls)
                   + ", forcedDedicated=" + std::to_string(
                       ForcedDedicatedCallCount.load(std::memory_order_relaxed)));
            const std::string Callers = NetModeCallerSampleSummary(
                Memory::GetInstance().GetImageBase(Config::ImageName));
            if (!Callers.empty())
                AddLog("Sampled forced-GetNetMode caller RVAs (count/1024): "
                       + Callers, LogLevel::Debug);
        }

        bool ClientTimedOut = false;
        bool ReturnToMenuTimedOut = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            const std::chrono::seconds ClientTimeout =
                ClientReturnToMenuPending ? std::chrono::seconds(180)
                                          : std::chrono::seconds(45);
            if (CurrentRole == Role::Client && ClientTravelPending
                && ClientTravelStartedAt.time_since_epoch().count() != 0
                && Now - ClientTravelStartedAt > ClientTimeout)
            {
                ReturnToMenuTimedOut = ClientReturnToMenuPending;
                ClientTravelPending = false;
                ClientReturnToMenuPending = false;
                ClientReturnTransportDetachedLogged = false;
                ClientState = ClientLifecycleState::Failed;
                LastError = ReturnToMenuTimedOut
                    ? "Return to main menu timed out after 180 seconds"
                    : "Connection timed out after 45 seconds";
                Status = LastError;
                ClientTimedOut = true;
            }
        }
        if (ClientTimedOut)
            AddLog(ReturnToMenuTimedOut
                ? "Return to main menu timed out: no MainMenu UWorld change was observed after 180 seconds"
                : "Client connection timed out after 45 seconds",
                LogLevel::Error);

        bool ShouldHost = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ShouldHost = CurrentRole == Role::Host && HostPending;
        }

        // Fallback for builds where BeginPlay already ran before our hook was
        // installed. UWorld::Listen can still be tested from the live world.
        if (ShouldHost && World)
            TryStartHosting(World);
    }

    bool HostingRuntime::Enqueue(RuntimeCommand&& Command)
    {
        bool Refused = false;
        {
            std::lock_guard<std::mutex> Guard(CommandMutex);
            if (PendingCommands.size() >= 64)
                Refused = true;
            else
                PendingCommands.emplace_back(std::move(Command));
        }
        if (Refused)
        {
            AddLog("Command queue is full; command refused", LogLevel::Error);
            return false;
        }
        ScheduleGameThreadTick();
        return true;
    }

    void HostingRuntime::RequestHost(int32 RequestedPort,
                                     const std::string& RequestedMap,
                                     const std::string& RequestedPassword,
                                     bool ForceDedicatedMode,
                                     bool RequestedBypassArkLoginLock)
    {
        if (!IsSafePasswordOption(RequestedPassword))
        {
            SetError("Password contains unsupported URL option characters");
            return;
        }
        if (RequestedMap.size() > 96 || HasControlCharacters(RequestedMap))
        {
            SetError("Map name is invalid");
            return;
        }

        RuntimeCommand Command;
        Command.Type = CommandType::StartHost;
        Command.Port = std::clamp(RequestedPort, 1, 65535);
        Command.Primary = RequestedMap;
        Command.Secret = RequestedPassword;
        Command.FlagA = ForceDedicatedMode;
        Command.FlagB = RequestedBypassArkLoginLock;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::RequestStop()
    {
        RuntimeCommand Command;
        Command.Type = CommandType::StopHost;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::ExecuteHostRequest(const RuntimeCommand& Command)
    {
        const int32 RequestedPort = Command.Port;
        const std::string& RequestedMap = Command.Primary;
        const std::string& RequestedPassword = Command.Secret;
        const bool ForceDedicatedMode = Command.FlagA;
        const bool RequestedBypassArkLoginLock = Command.FlagB;

        bool Refused = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            Refused = Hosting || HostedNetDriver || HostPending
                || ListenAttemptInProgress
                || (CurrentRole == Role::Client
                    && (ClientTravelPending
                        || ClientState == ClientLifecycleState::Connected
                        || ClientState == ClientLifecycleState::Playing))
                || HostState == HostLifecycleState::Listening
                || HostState == HostLifecycleState::AcceptingClients
                || HostState == HostLifecycleState::Stopping;
            if (Refused)
                Status = "Start refused: host lifecycle is already active";
        }
        if (Refused)
        {
            AddLog("Duplicate Start command refused; UWorld::Listen was not called",
                   LogLevel::Warning);
            return;
        }

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            CurrentRole = Role::Host;
            ClientTravelPending = false;
            ClientReturnToMenuPending = false;
            ClientReturnTransportDetachedLogged = false;
            ForceNetMode = ForceDedicatedMode;
            ModePolicy = ForceDedicatedMode
                ? NetModePolicy::DedicatedServerExperimental
                : NetModePolicy::AutomaticListenServer;
            BypassArkLoginLock = RequestedBypassArkLoginLock;
            ArkLoginBypassApplied = false;
            ArkLoginBypassWorld = nullptr;
            Port = std::clamp(RequestedPort, 1, 65535);
            BoundPort = 0;
            // Production hosts the currently loaded world. A map constraint is
            // available only to the developer UI for controlled experiments.
            MapName = RequestedMap;
            Password = RequestedPassword;
            HostPending = true;
            ListenAttemptInProgress = false;
            Hosting = false;
            HostedWorld = nullptr;
            HostedNetDriver = nullptr;
            HostedWorldIdentity = {};
            HostedNetDriverIdentity = {};
            ConnectedClients = 0;
            GameplayReadyClients = 0;
            ArkLoginLockedClients = 0;
            ClientGameplayReady = false;
            ClientArkLoginLocked = false;
            ClientPlayerStateReady = false;
            ClientHUDReady = false;
            ClientPawnReady = false;
            ClientCharacterCreationRPCSeen = false;
            ClientSpawnUIRPCSeen = false;
            ClientUIRecoveryAttempted = false;
            ConnectionDiagnostics.clear();
            PlayerInitializationDiagnostics.clear();
            GameStateDiagnostics.clear();
            UIFlowDiagnostics.clear();
            RPCDiagnostics.clear();
            PlayerUIRecoveryDiagnostics.clear();
            DiagnosticEventCounts.fill(0);
            ClientCharacterUICallbackCount = 0;
            LastLoggedHostPlayerInitialization.clear();
            LastLoggedClientPlayerInitialization.clear();
            LastLoggedGameStateDiagnostics.clear();
            LastLoggedUIFlowDiagnostics.clear();
            LastLoggedTransportClients = -1;
            LastLoggedGameplayClients = -1;
            LastLoggedArkLockedClients = -1;
            LastLoggedClientGameplayReady = false;
            LastLoggedClientArkLocked = false;
            LoggedLateListenStateMismatch = false;
            LoggedHostedNetModeActivity = false;
            Status = "Host requested; waiting for matching UWorld";
            LastError.clear();
            HostState = HostLifecycleState::HostRequested;
            ClientState = ClientLifecycleState::Disabled;
        }
        NetModeCallCount.store(0, std::memory_order_relaxed);
        HostedNetModeCallCount.store(0, std::memory_order_relaxed);
        ForcedDedicatedCallCount.store(0, std::memory_order_relaxed);
        HostedOriginalStandaloneCallCount.store(0, std::memory_order_relaxed);
        HostedOriginalDedicatedCallCount.store(0, std::memory_order_relaxed);
        HostedOriginalListenCallCount.store(0, std::memory_order_relaxed);
        HostedOriginalClientCallCount.store(0, std::memory_order_relaxed);
        LastHostedOriginalMode.store(static_cast<uint8>(ENetMode::Max),
                                     std::memory_order_relaxed);
        ResetNetModeCallerSamples();
        HotRole.store(static_cast<uint8>(Role::Host), std::memory_order_release);
        HotModePolicy.store(static_cast<uint8>(ForceDedicatedMode
            ? NetModePolicy::DedicatedServerExperimental
            : NetModePolicy::AutomaticListenServer), std::memory_order_release);
        HotHosting.store(false, std::memory_order_release);
        HotHostedNetDriver.store(nullptr, std::memory_order_release);
        AddLog("Host mode requested");
        if (ForceDedicatedMode)
            AddLog("Replication A/B policy armed: return DedicatedServer only for the confirmed hosted GameNetDriver");
        else
            AddLog("Diagnostic original-NetMode policy armed: hook and host path unchanged; return the engine result");
        if (!UWorldListen)
            SetStatus("Host requested, but UWorld::Listen is unresolved");
        else if (!FMemory::EngineRealloc)
            SetStatus("Host requested, but FMemory::Realloc is unresolved");
    }

    void HostingRuntime::Disable()
    {
        RuntimeCommand Command;
        Command.Type = CommandType::Disable;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::ExecuteDisable()
    {
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            CurrentRole = Role::Disabled;
            ClientTravelPending = false;
            ClientReturnToMenuPending = false;
            ClientReturnTransportDetachedLogged = false;
            HostPending = false;
            ListenAttemptInProgress = false;
            ForceNetMode = false;
            ModePolicy = NetModePolicy::AutomaticListenServer;
            HostState = Hosting ? HostLifecycleState::Listening
                                : HostLifecycleState::Disabled;
            ClientState = ClientLifecycleState::Disabled;
            Status = Hosting
                ? "Hooks disabled; active NetDriver must be stopped by travel/restart"
                : "Disabled";
        }
        HotRole.store(static_cast<uint8>(Role::Disabled), std::memory_order_release);
        HotModePolicy.store(static_cast<uint8>(NetModePolicy::AutomaticListenServer),
                            std::memory_order_release);
        AddLog("Runtime forcing disabled");
    }

    bool HostingRuntime::Join(const std::string& Endpoint,
                              const std::string& JoinPassword,
                              bool ForceClientMode)
    {
        if (!IsValidEndpoint(Endpoint) || !IsSafePasswordOption(JoinPassword))
        {
            SetError("Join failed: use a valid domain/IP, port and password");
            return false;
        }
        RuntimeCommand Command;
        Command.Type = CommandType::Join;
        Command.Primary = Endpoint;
        Command.Secret = JoinPassword;
        Command.FlagA = ForceClientMode;
        Enqueue(std::move(Command));
        return true;
    }

    void HostingRuntime::RequestReturnToMenu()
    {
        RuntimeCommand Command;
        Command.Type = CommandType::ReturnToMenu;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::ExecuteJoin(const RuntimeCommand& Command)
    {
        const std::string& Endpoint = Command.Primary;
        const std::string& JoinPassword = Command.Secret;
        if (!SetClientTravel)
        {
            SetStatus("SetClientTravel unresolved");
            AddLog("Join failed: SetClientTravel is not resolved");
            return;
        }

        bool JoinAlreadyPending = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (ClientTravelPending || Hosting || HostPending
                || ListenAttemptInProgress || HostedNetDriver)
            {
                Status = "Join refused: another host/client lifecycle is active";
                JoinAlreadyPending = true;
            }
        }
        if (JoinAlreadyPending)
        {
            AddLog("SetClientTravel not repeated: a previous client travel is already pending/active; use Disable forcing before an intentional new attempt");
            return;
        }

        UEngine* Engine = nullptr;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            Engine = CachedEngine;
        }
        if (!Engine)
            Engine = FindEngine();
        UWorld* World = Engine ? FindWorld(Engine) : nullptr;
        if (!Engine || !World || !IsValidEndpoint(Endpoint))
        {
            SetStatus("Join failed: use a valid host:port endpoint");
            return;
        }

        UObject* WorldObject = static_cast<UObject*>(World);
        int32 NetDriverOffset = WorldObject->GetOffset("NetDriver");
        if (NetDriverOffset <= 0 && KnownProfileEligible)
            NetDriverOffset = static_cast<int32>(SDKProfile::KnownBuild::UWorldNetDriver);
        if (NetDriverOffset == static_cast<int32>(
                SDKProfile::KnownBuild::UWorldNetDriver))
        {
            void* ExistingDriver = ReadPointer(
                reinterpret_cast<uintptr_t>(World) + NetDriverOffset);
            if (LooksLikeUObject(ExistingDriver))
            {
                void* ExistingServerConnection = ReadPointer(
                    reinterpret_cast<uintptr_t>(ExistingDriver)
                    + SDKProfile::KnownBuild::UNetDriverServerConnection);
                if (LooksLikeUObject(ExistingServerConnection))
                {
                    SetStatus("Join refused: this world already has a ServerConnection");
                    AddLog("SetClientTravel not repeated: existing connection is "
                           + static_cast<UObject*>(ExistingServerConnection)->GetFullName());
                    return;
                }
            }
        }

        PatchNetDriverDefinitions(Engine);

        std::string URL = Endpoint;
        if (!JoinPassword.empty())
            URL += (URL.find('?') == std::string::npos ? "?" : "&")
                + std::string("ServerPassword=") + JoinPassword;

        const std::u16string WideURL(URL.begin(), URL.end());

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            CurrentRole = Role::Client;
            ClientTravelPending = true;
            ClientReturnToMenuPending = false;
            ClientReturnTransportDetachedLogged = false;
            ForceNetMode = false;
            ModePolicy = NetModePolicy::AutomaticListenServer;
            CachedEngine = Engine;
            CachedWorld = World;
            ConnectedClients = 0;
            GameplayReadyClients = 0;
            ArkLoginLockedClients = 0;
            ClientGameplayReady = false;
            ClientArkLoginLocked = false;
            ClientPlayerStateReady = false;
            ClientHUDReady = false;
            ClientPawnReady = false;
            ClientCharacterCreationRPCSeen = false;
            ClientSpawnUIRPCSeen = false;
            ClientUIRecoveryAttempted = false;
            ConnectionDiagnostics.clear();
            PlayerInitializationDiagnostics.clear();
            GameStateDiagnostics.clear();
            UIFlowDiagnostics.clear();
            RPCDiagnostics.clear();
            PlayerUIRecoveryDiagnostics.clear();
            DiagnosticEventCounts.fill(0);
            ClientCharacterUICallbackCount = 0;
            LastLoggedHostPlayerInitialization.clear();
            LastLoggedClientPlayerInitialization.clear();
            LastLoggedGameStateDiagnostics.clear();
            LastLoggedUIFlowDiagnostics.clear();
            ArkLoginBypassApplied = false;
            ArkLoginBypassWorld = nullptr;
            LastLoggedTransportClients = -1;
            LastLoggedGameplayClients = -1;
            LastLoggedArkLockedClients = -1;
            LastLoggedClientGameplayReady = false;
            LastLoggedClientArkLocked = false;
            Status = "Client travel pending";
            LastError.clear();
            HostState = HostLifecycleState::Disabled;
            ClientState = ClientLifecycleState::Traveling;
            ClientTravelStartedAt = std::chrono::steady_clock::now();
        }

        HotRole.store(static_cast<uint8>(Role::Client), std::memory_order_release);
        HotModePolicy.store(static_cast<uint8>(NetModePolicy::AutomaticListenServer),
                            std::memory_order_release);
        HotHosting.store(false, std::memory_order_release);
        HotHostedNetDriver.store(nullptr, std::memory_order_release);

        SetClientTravel(static_cast<UObject*>(Engine), static_cast<UObject*>(World),
                        WideURL.c_str(), 0);
        AddLog("SetClientTravel dispatched to " + Endpoint
               + (JoinPassword.empty() ? " (no password)" : " (password supplied)"));
    }

    void HostingRuntime::ExecuteReturnToMenu()
    {
        void* World = nullptr;
        WeakObjectIdentity WorldIdentity;
        ClientLifecycleState State = ClientLifecycleState::Disabled;
        Role ActiveRole = Role::Disabled;
        bool AlreadyPending = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            World = CachedWorld;
            WorldIdentity = CachedWorldIdentity;
            State = ClientState;
            ActiveRole = CurrentRole;
            AlreadyPending = ClientReturnToMenuPending;
        }
        if (AlreadyPending)
        {
            AddLog("Return-to-menu command not repeated", LogLevel::Warning);
            return;
        }
        if (ActiveRole != Role::Client
            || (State != ClientLifecycleState::Connected
                && State != ClientLifecycleState::Playing)
            || ResolveWeakIdentity(WorldIdentity) != World
            || !LooksLikeUObject(World))
        {
            SetError("Return to menu refused: no live client world/connection");
            return;
        }

        UObject* WorldObject = static_cast<UObject*>(World);
        if (WorldObject->GetOffset("NetDriver") != static_cast<int32>(
                SDKProfile::KnownBuild::UWorldNetDriver))
        {
            SetError("Return to menu refused: UWorld::NetDriver layout changed");
            return;
        }
        void* Driver = ReadPointer(reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UWorldNetDriver);
        UObject* Connection = LooksLikeUObject(Driver)
            ? static_cast<UObject*>(ReadPointer(reinterpret_cast<uintptr_t>(Driver)
                + SDKProfile::KnownBuild::UNetDriverServerConnection))
            : nullptr;
        UObject* PC = LooksLikeUObject(Connection)
            ? static_cast<UObject*>(ReadPointer(reinterpret_cast<uintptr_t>(Connection)
                + SDKProfile::KnownBuild::UPlayerPlayerController))
            : nullptr;
        if (!LooksLikeUObject(Driver) || !LooksLikeUObject(Connection)
            || !LooksLikeUObject(PC)
            || !IsClassOrSuper(PC, "ShooterPlayerController")
            || PC->GetOffset("NetConnection") != static_cast<int32>(
                SDKProfile::KnownBuild::APlayerControllerNetConnection)
            || ReadPointer(reinterpret_cast<uintptr_t>(PC)
                + SDKProfile::KnownBuild::APlayerControllerNetConnection) != Connection)
        {
            SetError("Return to menu refused: client connection ownership is stale");
            return;
        }

        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Public)
            | static_cast<uint32>(EFunctionFlags::BlueprintCallable);
        UFunction* Function = ResolveFunctionCached(CachedQuitToMainMenu,
            "Function ShooterGame.ShooterPlayerController.QuitToMainMenu",
            0, 0, Flags);
        if (!Function || !ValidateProcessEventTarget(PC))
        {
            SetError("Return to menu refused: ShooterPlayerController::QuitToMainMenu ABI is unavailable");
            return;
        }

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ClientReturnToMenuPending = true;
            ClientReturnTransportDetachedLogged = false;
            ClientTravelPending = true;
            ClientState = ClientLifecycleState::Traveling;
            ClientTravelStartedAt = std::chrono::steady_clock::now();
            Status = "Return to main menu requested";
            LastError.clear();
        }
        PC->ProcessEvent(Function, nullptr);
        AddLog("ShooterPlayerController::QuitToMainMenu dispatched on the client game thread; awaiting MainMenu UWorld change");
    }

    void HostingRuntime::RequestBroadcast(const std::string& Message)
    {
        if (Message.empty() || Message.size() > 256 || HasControlCharacters(Message))
        {
            SetError("Broadcast must contain 1-256 printable characters");
            return;
        }
        RuntimeCommand Command;
        Command.Type = CommandType::Broadcast;
        Command.Primary = Message;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::RequestSaveWorld()
    {
        RuntimeCommand Command;
        Command.Type = CommandType::SaveWorld;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::RequestSetRuntimeAdmin(
        const std::string& StablePlayerId, bool Enable)
    {
        if (StablePlayerId.empty() || StablePlayerId.size() > 96)
        {
            SetError("Runtime-admin request has an invalid player identity");
            return;
        }
        RuntimeCommand Command;
        Command.Type = CommandType::SetRuntimeAdmin;
        Command.Primary = StablePlayerId;
        Command.FlagA = Enable;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::RequestAdminCheat(
        const std::string& StablePlayerId, const std::string& Action)
    {
        static const std::unordered_set<std::string> Whitelist = {
            "fly", "walk", "god", "infinitestats"
        };
        const std::string Normalized = Lowercase(Action);
        if (StablePlayerId.empty() || StablePlayerId.size() > 96
            || Whitelist.find(Normalized) == Whitelist.end())
        {
            SetError("Player admin action was refused by the fixed whitelist");
            return;
        }
        RuntimeCommand Command;
        Command.Type = CommandType::AdminCheat;
        Command.Primary = StablePlayerId;
        Command.Secondary = Normalized;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::RequestKick(const std::string& StablePlayerId,
                                     const std::string& Reason)
    {
        if (StablePlayerId.empty() || StablePlayerId.size() > 96
            || Reason.size() > 128 || HasControlCharacters(Reason))
        {
            SetError("Kick request is invalid");
            return;
        }
        RuntimeCommand Command;
        Command.Type = CommandType::Kick;
        Command.Primary = StablePlayerId;
        Command.Secondary = Reason;
        Enqueue(std::move(Command));
    }

    void HostingRuntime::RequestConsoleCommand(const std::string& CommandText)
    {
        static const std::unordered_set<std::string> Whitelist = {
            "stat net", "stat fps", "stat unit", "stat game", "stat none"
        };
        const std::string Normalized = Lowercase(CommandText);
        if (Whitelist.find(Normalized) == Whitelist.end())
        {
            SetError("Console command refused by local whitelist");
            AddLog("Non-whitelisted local console command refused", LogLevel::Warning);
            return;
        }
        RuntimeCommand Command;
        Command.Type = CommandType::Console;
        Command.Primary = Normalized;
        Enqueue(std::move(Command));
    }

#if SERVERHOST_DEVELOPER_UI
    void HostingRuntime::RequestDeveloperProcessEventExample()
    {
        bool Expected = false;
        if (!DeveloperProcessEventExamplePending.compare_exchange_strong(
                Expected, true, std::memory_order_acq_rel))
        {
            AddLog("Developer ProcessEvent example is already queued",
                   LogLevel::Warning);
            return;
        }

        RuntimeCommand Command;
        Command.Type = CommandType::DeveloperProcessEventExample;
        if (!Enqueue(std::move(Command)))
        {
            DeveloperProcessEventExamplePending.store(
                false, std::memory_order_release);
            return;
        }
        AddLog("Developer ProcessEvent example queued for the UE game thread",
               LogLevel::Debug);
    }

    void HostingRuntime::RequestDeveloperHarvestProbe(
        const std::string& StablePlayerId)
    {
        if (StablePlayerId.empty() || StablePlayerId.size() > 96
            || HasControlCharacters(StablePlayerId))
        {
            SetError("Harvest probe requires one valid selected remote player");
            return;
        }
        bool Expected = false;
        if (!DeveloperHarvestProbePending.compare_exchange_strong(
                Expected, true, std::memory_order_acq_rel))
        {
            AddLog("Harvest/stasis probe is already queued",
                   LogLevel::Warning);
            return;
        }
        RuntimeCommand Command;
        Command.Type = CommandType::DeveloperHarvestProbe;
        Command.Primary = StablePlayerId;
        if (!Enqueue(std::move(Command)))
        {
            DeveloperHarvestProbePending.store(false,
                std::memory_order_release);
            return;
        }
        AddLog("Read-only harvest/stasis probe queued for the UE game thread",
               LogLevel::Debug);
    }
#endif

    void HostingRuntime::DrainCommands()
    {
        if (!IsOnGameThread())
        {
            SetError("UE command execution refused outside the game thread");
            return;
        }

        std::deque<RuntimeCommand> Commands;
        {
            std::lock_guard<std::mutex> Guard(CommandMutex);
            Commands.swap(PendingCommands);
        }
        for (const RuntimeCommand& Command : Commands)
        {
            switch (Command.Type)
            {
                case CommandType::StartHost: ExecuteHostRequest(Command); break;
                case CommandType::StopHost: ExecuteStop(); break;
                case CommandType::Disable: ExecuteDisable(); break;
                case CommandType::Join: ExecuteJoin(Command); break;
                case CommandType::ReturnToMenu: ExecuteReturnToMenu(); break;
                case CommandType::PatchNetDriver: ExecutePatchCurrentNetDriver(); break;
                case CommandType::ManualRecovery: ExecuteManualRecovery(); break;
                case CommandType::Broadcast: ExecuteBroadcast(Command.Primary); break;
                case CommandType::SaveWorld: ExecuteSaveWorld(); break;
                case CommandType::SetRuntimeAdmin:
                    ExecuteSetRuntimeAdmin(Command.Primary, Command.FlagA); break;
                case CommandType::AdminCheat:
                    ExecuteAdminCheat(Command.Primary, Command.Secondary); break;
                case CommandType::Kick:
                    ExecuteKick(Command.Primary, Command.Secondary); break;
                case CommandType::Console: ExecuteConsole(Command.Primary); break;
#if SERVERHOST_DEVELOPER_UI
                case CommandType::DeveloperProcessEventExample:
                    ExecuteDeveloperProcessEventExample(); break;
                case CommandType::DeveloperHarvestProbe:
                    ExecuteDeveloperHarvestProbe(Command.Primary); break;
#endif
            }
        }
    }

    bool HostingRuntime::PatchCurrentNetDriver()
    {
        RuntimeCommand Command;
        Command.Type = CommandType::PatchNetDriver;
        Enqueue(std::move(Command));
        return true;
    }

    bool HostingRuntime::ExecutePatchCurrentNetDriver()
    {
        UEngine* Engine = nullptr;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            Engine = CachedEngine;
        }
        if (!Engine)
            Engine = FindEngine();
        if (!Engine)
        {
            SetStatus("ShooterEngine object not found");
            return false;
        }
        return PatchNetDriverDefinitions(Engine);
    }

    bool HostingRuntime::RecoverRemotePlayerUI()
    {
        RuntimeCommand Command;
        Command.Type = CommandType::ManualRecovery;
        Enqueue(std::move(Command));
        return true;
    }

    bool HostingRuntime::ExecuteManualRecovery()
    {
        Role ActiveRole = Role::Disabled;
        bool IsHosting = false;
        bool AlreadyAttempted = false;
        bool AddressesReady = false;
        void* World = nullptr;
        void* Driver = nullptr;
        WeakObjectIdentity WorldIdentity;
        WeakObjectIdentity DriverIdentity;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ActiveRole = CurrentRole;
            IsHosting = Hosting;
            AlreadyAttempted = ClientUIRecoveryAttempted;
            AddressesReady = TargetedPlayerFlowAddressesValidated;
            World = HostedWorld;
            Driver = HostedNetDriver;
            WorldIdentity = HostedWorldIdentity;
            DriverIdentity = HostedNetDriverIdentity;
        }
        if (ActiveRole != Role::Host || !IsHosting || !AddressesReady
            || ResolveWeakIdentity(WorldIdentity) != World
            || ResolveWeakIdentity(DriverIdentity) != Driver)
        {
            SetStatus("Remote UI recovery refused: exact-profile host is not ready");
            AddLog("Remote UI recovery refused: requires the active hosted UWorld, IpNetDriver, and exact 1.10280 validation");
            return false;
        }
        if (AlreadyAttempted)
        {
            SetStatus("Remote UI recovery was already attempted");
            AddLog("Remote UI recovery not repeated: one server-authoritative RPC pair is allowed per host request");
            return false;
        }

        UObject* WorldObject = static_cast<UObject*>(World);
        if (WorldObject->GetOffset("NetDriver") != static_cast<int32>(
                SDKProfile::KnownBuild::UWorldNetDriver)
            || ReadPointer(reinterpret_cast<uintptr_t>(World)
                           + SDKProfile::KnownBuild::UWorldNetDriver) != Driver)
        {
            SetStatus("Remote UI recovery refused: hosted World/NetDriver changed");
            AddLog("Remote UI recovery refused: stale hosted World or NetDriver");
            return false;
        }

        const ArrayHeader Connections = Memory::GetInstance().Read<ArrayHeader>(
            reinterpret_cast<uintptr_t>(Driver)
            + SDKProfile::KnownBuild::UNetDriverClientConnections);
        if (!Connections.Data || Connections.Num <= 0 || Connections.Num > 128
            || Connections.Max < Connections.Num || Connections.Max > 128
            || !Memory::GetInstance().IsValid(
                reinterpret_cast<uintptr_t>(Connections.Data)))
        {
            SetStatus("Remote UI recovery refused: no valid remote connection");
            AddLog("Remote UI recovery refused: ClientConnections data/num/max="
                   + HexAddress(reinterpret_cast<uintptr_t>(Connections.Data))
                   + "/" + std::to_string(Connections.Num)
                   + "/" + std::to_string(Connections.Max));
            return false;
        }

        UObject* RemotePC = nullptr;
        UObject* RemotePlayerState = nullptr;
        void* SelectedConnection = nullptr;
        for (int32 Index = 0; Index < Connections.Num; ++Index)
        {
            void* Connection = ReadPointer(
                reinterpret_cast<uintptr_t>(Connections.Data)
                + sizeof(void*) * Index);
            UObject* PC = LooksLikeUObject(Connection)
                ? static_cast<UObject*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(Connection)
                    + SDKProfile::KnownBuild::UPlayerPlayerController))
                : nullptr;
            if (!LooksLikeUObject(PC)
                || !IsClassOrSuper(PC, "ShooterPlayerController")
                || PC->GetOffset("PlayerState") != static_cast<int32>(
                    SDKProfile::KnownBuild::AControllerPlayerState)
                || PC->GetOffset("Pawn") != static_cast<int32>(
                    SDKProfile::KnownBuild::AControllerPawn))
                continue;

            UObject* PlayerState = static_cast<UObject*>(ReadPointer(
                reinterpret_cast<uintptr_t>(PC)
                + SDKProfile::KnownBuild::AControllerPlayerState));
            void* Pawn = ReadPointer(reinterpret_cast<uintptr_t>(PC)
                                     + SDKProfile::KnownBuild::AControllerPawn);
            if (!LooksLikeUObject(PlayerState) || LooksLikeUObject(Pawn)
                || !IsClassOrSuper(PlayerState, "ShooterPlayerState")
                || PlayerState->GetOffset("MyPlayerData") != static_cast<int32>(
                    SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData))
                continue;

            void* PlayerData = ReadPointer(
                reinterpret_cast<uintptr_t>(PlayerState)
                + SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData);
            if (LooksLikeUObject(PlayerData))
                continue;

            SelectedConnection = Connection;
            RemotePC = PC;
            RemotePlayerState = PlayerState;
            break;
        }
        if (!RemotePC)
        {
            SetStatus("Remote UI recovery refused: no waiting player without data/pawn");
            AddLog("Remote UI recovery refused: no connected ShooterPlayerController matched PlayerState-ready, MyPlayerData-null, Pawn-null");
            return false;
        }

        UObject* GameMode = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UWorldAuthorityGameMode));
        if (!LooksLikeUObject(GameMode)
            || !IsClassOrSuper(GameMode, "ShooterGameMode")
            || GameMode->GetOffset("HUDClass") != static_cast<int32>(
                SDKProfile::KnownBuild::AGameModeBaseHUDClass))
        {
            SetStatus("Remote UI recovery refused: live ShooterGameMode/HUDClass layout mismatch");
            return false;
        }
        UClass* HUDClass = static_cast<UClass*>(ReadPointer(
            reinterpret_cast<uintptr_t>(GameMode)
            + SDKProfile::KnownBuild::AGameModeBaseHUDClass));
        UClass* BaseHUDClass = UObject::FindClass("Class Engine.HUD");
        if (!LooksLikeUObject(HUDClass) || !LooksLikeUObject(BaseHUDClass)
            || !HUDClass->IsChildOf(BaseHUDClass))
        {
            SetStatus("Remote UI recovery refused: authority HUDClass is invalid");
            AddLog("Remote UI recovery refused: HUDClass=" + DescribeObject(HUDClass)
                   + ", base=" + DescribeObject(BaseHUDClass));
            return false;
        }

        UFunction* HUDRPC = UObject::FindObject<UFunction>(
            "Function ShooterGame.ShooterPlayerController.ClientSetHUDAndInitUIScenes",
            EClassCastFlags::Function);
        UFunction* CharacterRPC = UObject::FindObject<UFunction>(
            "Function ShooterGame.ShooterPlayerController.ClientShowCharacterCreationUI",
            EClassCastFlags::Function);
        const uint32 HUDFlags = HUDRPC
            ? static_cast<uint32>(HUDRPC->FunctionFlags) : 0;
        const uint32 CharacterFlags = CharacterRPC
            ? static_cast<uint32>(CharacterRPC->FunctionFlags) : 0;
        constexpr uint32 RequiredRPCFlags =
            static_cast<uint32>(EFunctionFlags::Net)
            | static_cast<uint32>(EFunctionFlags::NetReliable)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::NetClient);
        if (!LooksLikeUObject(HUDRPC) || !LooksLikeUObject(CharacterRPC)
            || HUDRPC->ParmsSize != sizeof(void*) || HUDRPC->NumParms != 1
            || CharacterRPC->ParmsSize != sizeof(uint8) || CharacterRPC->NumParms != 1
            || (HUDFlags & RequiredRPCFlags) != RequiredRPCFlags
            || (CharacterFlags & RequiredRPCFlags) != RequiredRPCFlags)
        {
            SetStatus("Remote UI recovery refused: reflected RPC signature mismatch");
            AddLog("Remote UI recovery refused: HUD RPC=" + DescribeObject(HUDRPC)
                   + " parms=" + std::to_string(HUDRPC ? HUDRPC->ParmsSize : 0)
                   + " flags=" + HexAddress(HUDFlags)
                   + "; character RPC=" + DescribeObject(CharacterRPC)
                   + " parms=" + std::to_string(
                        CharacterRPC ? CharacterRPC->ParmsSize : 0)
                   + " flags=" + HexAddress(CharacterFlags));
            return false;
        }

        const uintptr_t ImageBase = Memory::GetInstance().GetImageBase(
            Config::ImageName);
        const uintptr_t ExpectedProcessEvent = ImageBase
            + SDKProfile::KnownBuild::ProcessEvent;
        const uintptr_t ExpectedActorProcessEvent = ImageBase
            + SDKProfile::KnownBuild::ActorProcessEventThunk;
        const uintptr_t ActualProcessEvent = reinterpret_cast<uintptr_t>(
            RemotePC->VTable[SDKProfile::KnownBuild::ProcessEventIndex]);
        static constexpr uint8 ActorProcessEventPrefix[] = {
            0xF6, 0x57, 0xBD, 0xA9, 0xF4, 0x4F, 0x01, 0xA9,
            0xFD, 0x7B, 0x02, 0xA9, 0xFD, 0x83, 0x00, 0x91
        };
        const bool IsBaseProcessEvent = ActualProcessEvent == ExpectedProcessEvent;
        const bool IsValidatedActorThunk =
            ActualProcessEvent == ExpectedActorProcessEvent
            && Memory::GetInstance().IsValid(ActualProcessEvent)
            && Memory::GetInstance().IsValid(
                ActualProcessEvent + sizeof(ActorProcessEventPrefix) - 1)
            && std::memcmp(reinterpret_cast<const void*>(ActualProcessEvent),
                           ActorProcessEventPrefix,
                           sizeof(ActorProcessEventPrefix)) == 0;
        if (!ExpectedProcessEvent || (!IsBaseProcessEvent
                                      && !IsValidatedActorThunk)
            || !Memory::GetInstance().IsValid(ActualProcessEvent))
        {
            SetStatus("Remote UI recovery refused: PlayerController ProcessEvent mismatch");
            AddLog("Remote UI recovery refused: ProcessEvent actual="
                   + HexAddress(ActualProcessEvent) + ", expected="
                   + HexAddress(ExpectedProcessEvent) + " or actor thunk="
                   + HexAddress(ExpectedActorProcessEvent));
            return false;
        }

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (ClientUIRecoveryAttempted)
                return false;
            ClientUIRecoveryAttempted = true;
        }

        struct HUDRPCParameters
        {
            UClass* NewHUDClass = nullptr;
        } HUDParameters{HUDClass};
        struct CharacterRPCParameters
        {
            uint8 ShowDownloadCharacter = 0;
        } CharacterParameters{};
        static_assert(sizeof(HUDRPCParameters) == 8,
                      "ClientSetHUDAndInitUIScenes parameters mismatch");
        static_assert(sizeof(CharacterRPCParameters) == 1,
                      "ClientShowCharacterCreationUI parameters mismatch");

        AddLog("Remote UI recovery validated: connection="
               + DescribeObject(SelectedConnection) + ", PC="
               + DescribeObject(RemotePC) + ", PlayerState="
               + DescribeObject(RemotePlayerState) + ", HUDClass="
               + DescribeObject(HUDClass) + ", ProcessEvent="
               + HexAddress(ActualProcessEvent)
               + (IsValidatedActorThunk
                    ? " (validated AActor ProcessEvent thunk)"
                    : " (base UObject::ProcessEvent)"));
        AddLog("Remote UI recovery dispatch 1/2: reliable NetClient ClientSetHUDAndInitUIScenes");
        RemotePC->ProcessEvent(HUDRPC, &HUDParameters);
        AddLog("Remote UI recovery dispatch 1/2 returned; dispatch 2/2: reliable NetClient ClientShowCharacterCreationUI(false)");
        RemotePC->ProcessEvent(CharacterRPC, &CharacterParameters);

        const std::string Details = "server RPC pair returned for PC="
            + DescribeObject(RemotePC) + ", HUDClass=" + DescribeObject(HUDClass);
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            PlayerUIRecoveryDiagnostics = Details;
        }
        const WeakObjectIdentity ConnectionIdentity = MakeWeakIdentity(SelectedConnection);
        for (ClientRecoveryRecord& Record : RecoveryRecords)
        {
            if (!SameIdentity(Record.Connection, ConnectionIdentity))
                continue;
            Record.PlayerController = MakeWeakIdentity(RemotePC);
            Record.PlayerState = MakeWeakIdentity(RemotePlayerState);
            Record.DispatchAttempts = 1;
            Record.RPCSentAt = std::chrono::steady_clock::now();
            TransitionRecovery(Record, RecoveryState::AwaitingPlayerData,
                               "developer-triggered pair; automatic duplicate suppressed");
            break;
        }
        SetStatus("Remote HUD + character UI RPCs dispatched; inspect iPhone state");
        AddLog("Remote UI recovery dispatch completed: " + Details);
        return true;
    }

    WeakObjectIdentity HostingRuntime::MakeWeakIdentity(void* Candidate) const
    {
        WeakObjectIdentity Identity;
        if (!LooksLikeUObject(Candidate) || !UObject::GUObjectArray)
            return Identity;
        UObject* Object = static_cast<UObject*>(Candidate);
        if (Object->InternalIndex < 0)
            return Identity;
        const FUObjectItem* Item = UObject::GUObjectArray->ObjObjects.IndexToObject(
            Object->InternalIndex);
        if (!Item || Item->Object != Object || Item->SerialNumber == 0
            || Item->IsPendingKill() || Item->IsUnreachable())
            return Identity;
        Identity.Pointer = reinterpret_cast<uintptr_t>(Object);
        Identity.ObjectIndex = Object->InternalIndex;
        Identity.SerialNumber = Item->SerialNumber;
        return Identity;
    }

    void* HostingRuntime::ResolveWeakIdentity(
        const WeakObjectIdentity& Identity) const
    {
        if (!Identity.IsSet() || !UObject::GUObjectArray)
            return nullptr;
        const FUObjectItem* Item = UObject::GUObjectArray->ObjObjects.IndexToObject(
            Identity.ObjectIndex);
        if (!Item || Item->SerialNumber != Identity.SerialNumber
            || reinterpret_cast<uintptr_t>(Item->Object) != Identity.Pointer
            || Item->IsPendingKill() || Item->IsUnreachable())
            return nullptr;
        return LooksLikeUObject(Item->Object) ? Item->Object : nullptr;
    }

    bool HostingRuntime::SameIdentity(const WeakObjectIdentity& A,
                                      const WeakObjectIdentity& B) const
    {
        return A.IsSet() && B.IsSet()
            && A.ObjectIndex == B.ObjectIndex
            && A.SerialNumber == B.SerialNumber
            && A.Pointer == B.Pointer;
    }

    bool HostingRuntime::ValidateProcessEventTarget(UObject* Object) const
    {
        if (!Object || !LooksLikeUObject(Object) || !UObject::GUObjectArray
            || Object->InternalIndex < 0)
            return false;

        const FUObjectItem* Item = UObject::GUObjectArray->ObjObjects.IndexToObject(
            Object->InternalIndex);
        if (!Item || Item->Object != Object || Item->IsPendingKill()
            || Item->IsUnreachable())
            return false;

        // UE allocates FUObjectItem serials lazily. Runtime actors still require
        // the normal confirmed weak identity, but an immortal class-default
        // object may legitimately have SerialNumber == 0. This narrow case is
        // used by reflected static libraries such as KismetSystemLibrary.
        const WeakObjectIdentity Identity = MakeWeakIdentity(Object);
        if (Identity.IsSet())
        {
            if (ResolveWeakIdentity(Identity) != Object)
                return false;
        }
        else if (!Object->IsDefaultObject() || Item->SerialNumber != 0)
        {
            return false;
        }
        const uintptr_t Base = Memory::GetInstance().GetImageBase(Config::ImageName);
        const uintptr_t ExpectedBase = Base + SDKProfile::KnownBuild::ProcessEvent;
        const uintptr_t ExpectedActor = Base
            + SDKProfile::KnownBuild::ActorProcessEventThunk;
        const uintptr_t Actual = reinterpret_cast<uintptr_t>(
            Object->VTable[SDKProfile::KnownBuild::ProcessEventIndex]);
        if (Actual == ExpectedBase)
            return Memory::GetInstance().IsValid(Actual);
        static constexpr uint8 ActorPrefix[] = {
            0xF6, 0x57, 0xBD, 0xA9, 0xF4, 0x4F, 0x01, 0xA9,
            0xFD, 0x7B, 0x02, 0xA9, 0xFD, 0x83, 0x00, 0x91
        };
        return Actual == ExpectedActor
            && Memory::GetInstance().IsValid(Actual)
            && Memory::GetInstance().IsValid(Actual + sizeof(ActorPrefix) - 1)
            && std::memcmp(reinterpret_cast<const void*>(Actual), ActorPrefix,
                           sizeof(ActorPrefix)) == 0;
    }

    bool HostingRuntime::DispatchBaseProcessEvent(UObject* Object,
                                                   UFunction* Function,
                                                   void* Parameters) const
    {
        if (!IsOnGameThread() || !Object || !Function || !LooksLikeUObject(Object)
            || !LooksLikeUObject(Function) || !UObject::GUObjectArray
            || Object->InternalIndex < 0 || Function->InternalIndex < 0)
            return false;

        const FUObjectItem* ObjectItem = UObject::GUObjectArray->ObjObjects.IndexToObject(
            Object->InternalIndex);
        const FUObjectItem* FunctionItem = UObject::GUObjectArray->ObjObjects.IndexToObject(
            Function->InternalIndex);
        if (!ObjectItem || ObjectItem->Object != Object
            || ObjectItem->IsPendingKill() || ObjectItem->IsUnreachable()
            || !FunctionItem || FunctionItem->Object != Function
            || FunctionItem->IsPendingKill() || FunctionItem->IsUnreachable())
            return false;

        // FUObjectItem serials are allocated lazily. A live transient
        // PrimalPlayerData instance can therefore have serial 0 even though
        // the exact array slot still owns it. This helper is synchronous and
        // game-thread-only: permit that narrow case without ever caching the
        // raw pointer. When a serial exists, retain the stronger weak-identity
        // round trip.
        if (ObjectItem->SerialNumber != 0)
        {
            const WeakObjectIdentity Identity = MakeWeakIdentity(Object);
            if (!Identity.IsSet() || ResolveWeakIdentity(Identity) != Object)
                return false;
        }
        if (FunctionItem->SerialNumber != 0)
        {
            const WeakObjectIdentity Identity = MakeWeakIdentity(Function);
            if (!Identity.IsSet() || ResolveWeakIdentity(Identity) != Function)
                return false;
        }

        // Blueprint-generated UObject instances may use a class-specific
        // ProcessEvent thunk which is not one of the two actor/base thunks
        // accepted by ValidateProcessEventTarget. Calling the exact validated
        // UObject::ProcessEvent implementation is the normal base-class call
        // and preserves UFunction dispatch without trusting an unknown vtable
        // entry.
        const uintptr_t Address = Memory::GetInstance().GetImageBase(
            Config::ImageName) + SDKProfile::KnownBuild::ProcessEvent;
        if (!Memory::GetInstance().IsValid(Address))
            return false;
        reinterpret_cast<ProcessEventFn>(Address)(Object, Function, Parameters);
        return true;
    }

    UFunction* HostingRuntime::ResolveFunctionCached(
        UFunction*& Cache, const char* FullName, uint16 ParmsSize,
        uint8 NumParms, uint32 RequiredFlags)
    {
        if (!ResolveWeakIdentity(MakeWeakIdentity(Cache)))
            Cache = nullptr;
        if (!Cache)
            Cache = UObject::FindObject<UFunction>(FullName,
                                                   EClassCastFlags::Function);
        const uint32 Flags = Cache
            ? static_cast<uint32>(Cache->FunctionFlags) : 0;
        if (!LooksLikeUObject(Cache) || Cache->ParmsSize != ParmsSize
            || Cache->NumParms != NumParms
            || (Flags & RequiredFlags) != RequiredFlags)
        {
            Cache = nullptr;
            return nullptr;
        }
        return Cache;
    }

    UObject* HostingRuntime::GetAuthorityGameMode() const
    {
        void* World = nullptr;
        WeakObjectIdentity WorldIdentity;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            World = HostedWorld;
            WorldIdentity = HostedWorldIdentity;
        }
        if (ResolveWeakIdentity(WorldIdentity) != World)
            return nullptr;
        UObject* WorldObject = static_cast<UObject*>(World);
        if (WorldObject->GetOffset("AuthorityGameMode") != static_cast<int32>(
                SDKProfile::KnownBuild::UWorldAuthorityGameMode))
            return nullptr;
        UObject* GameMode = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UWorldAuthorityGameMode));
        return LooksLikeUObject(GameMode) && !GameMode->IsDefaultObject()
            && IsClassOrSuper(GameMode, "ShooterGameMode") ? GameMode : nullptr;
    }

    void HostingRuntime::TransitionRecovery(ClientRecoveryRecord& Record,
                                             RecoveryState State,
                                             const std::string& Detail)
    {
        if (Record.State == State)
            return;
        // Completed is terminal for this connection/controller identity.
        // Normal death, respawn or a temporarily missing pawn must not reopen
        // the one-shot recovery protocol or turn success into TimedOut.
        if (Record.State == RecoveryState::Completed
            && State != RecoveryState::Disconnected
            && State != RecoveryState::WorldChanged)
            return;
        const RecoveryState Previous = Record.State;
        Record.State = State;
        Record.StateChangedAt = std::chrono::steady_clock::now();
        if (!Detail.empty())
            Record.LastError = Detail;
        AddLog("RPC recovery " + Record.StableId + ": "
               + RecoveryStateName(Previous) + " -> " + RecoveryStateName(State)
               + (Detail.empty() ? "" : " (" + Detail + ")"),
               State == RecoveryState::Failed || State == RecoveryState::TimedOut
                    ? LogLevel::Warning : LogLevel::Info);
    }

    bool HostingRuntime::DispatchRecoveryRPCs(ClientRecoveryRecord& Record,
                                               UObject* PlayerController,
                                               UObject* PlayerState,
                                               void* Connection)
    {
        if (Record.DispatchAttempts != 0 || !IsOnGameThread()
            || ResolveWeakIdentity(Record.Connection) != Connection
            || ResolveWeakIdentity(Record.PlayerController) != PlayerController
            || ResolveWeakIdentity(Record.PlayerState) != PlayerState
            || !ValidateProcessEventTarget(PlayerController))
        {
            TransitionRecovery(Record, RecoveryState::Failed,
                               "stale identity or invalid ProcessEvent target");
            return false;
        }

        void* PCConnection = ReadPointer(reinterpret_cast<uintptr_t>(PlayerController)
            + SDKProfile::KnownBuild::APlayerControllerNetConnection);
        if (PCConnection != Connection)
        {
            TransitionRecovery(Record, RecoveryState::Failed,
                               "PlayerController no longer owns NetConnection");
            return false;
        }

        UObject* GameMode = GetAuthorityGameMode();
        if (!GameMode || GameMode->GetOffset("HUDClass") != static_cast<int32>(
                SDKProfile::KnownBuild::AGameModeBaseHUDClass))
        {
            TransitionRecovery(Record, RecoveryState::Failed,
                               "authority GameMode/HUDClass layout rejected");
            return false;
        }
        UClass* HUDClass = static_cast<UClass*>(ReadPointer(
            reinterpret_cast<uintptr_t>(GameMode)
            + SDKProfile::KnownBuild::AGameModeBaseHUDClass));
        if (!ResolveWeakIdentity(MakeWeakIdentity(CachedHUDBaseClass)))
            CachedHUDBaseClass = UObject::FindClass("Class Engine.HUD");
        if (!LooksLikeUObject(HUDClass) || !LooksLikeUObject(CachedHUDBaseClass)
            || !HUDClass->IsChildOf(CachedHUDBaseClass))
        {
            TransitionRecovery(Record, RecoveryState::Failed,
                               "authority HUDClass is invalid");
            return false;
        }

        constexpr uint32 RPCFlags = static_cast<uint32>(EFunctionFlags::Net)
            | static_cast<uint32>(EFunctionFlags::NetReliable)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::NetClient);
        UFunction* HUDRPC = ResolveFunctionCached(CachedHUDRecoveryRPC,
            "Function ShooterGame.ShooterPlayerController.ClientSetHUDAndInitUIScenes",
            sizeof(void*), 1, RPCFlags);
        UFunction* CharacterRPC = ResolveFunctionCached(CachedCharacterRecoveryRPC,
            "Function ShooterGame.ShooterPlayerController.ClientShowCharacterCreationUI",
            sizeof(uint8), 1, RPCFlags);
        if (!HUDRPC || !CharacterRPC)
        {
            TransitionRecovery(Record, RecoveryState::Failed,
                               "reflected recovery RPC ABI rejected");
            return false;
        }

        struct HUDParams { UClass* NewHUDClass = nullptr; } HUDParameters{HUDClass};
        struct CharacterParams { uint8 ShowDownloadCharacter = 0; } CharacterParameters{};
        static_assert(sizeof(HUDParams) == 8, "HUD RPC parameters mismatch");
        static_assert(sizeof(CharacterParams) == 1,
                      "character RPC parameters mismatch");

        // Mark the one allowed attempt before entering ProcessEvent. There is
        // intentionally no retry loop: the known-good 0.2.11 protocol is one
        // reliable pair, and duplicate client RPCs are more dangerous than a
        // visible timeout.
        Record.DispatchAttempts = 1;
        Record.RPCSentAt = std::chrono::steady_clock::now();
        PlayerController->ProcessEvent(HUDRPC, &HUDParameters);
        TransitionRecovery(Record, RecoveryState::RPC1Sent);
        if (ResolveWeakIdentity(Record.Connection) != Connection
            || ResolveWeakIdentity(Record.PlayerController) != PlayerController
            || ReadPointer(reinterpret_cast<uintptr_t>(PlayerController)
                + SDKProfile::KnownBuild::APlayerControllerNetConnection) != Connection)
        {
            TransitionRecovery(Record, RecoveryState::Disconnected,
                               "connection changed after RPC1");
            return false;
        }
        PlayerController->ProcessEvent(CharacterRPC, &CharacterParameters);
        TransitionRecovery(Record, RecoveryState::RPC2Sent);
        TransitionRecovery(Record, RecoveryState::AwaitingPlayerData);

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ClientUIRecoveryAttempted = true;
            PlayerUIRecoveryDiagnostics = "automatic reliable RPC pair dispatched once to "
                + Record.StableId;
        }
        AddLog("Automatic RPC recovery pair dispatched once for " + Record.StableId);
        return true;
    }

    bool HostingRuntime::PopulatePlayerOnlineIdentity(
        UObject* PlayerState, UObject* PlayerController, void* Connection,
        PlayerSummary& Summary)
    {
        if (!IsOnGameThread() || !LooksLikeUObject(PlayerState)
            || !IsClassOrSuper(PlayerState, "ShooterPlayerState"))
            return false;

        auto ReplicationByteCount = [](uintptr_t UniqueIdAddress) -> int32
        {
            const ArrayHeader Bytes = Memory::GetInstance().Read<ArrayHeader>(
                UniqueIdAddress + 0x18);
            if (Bytes.Num < 0 || Bytes.Num > 128 || Bytes.Max < Bytes.Num
                || Bytes.Max > 128 || (Bytes.Num > 0
                    && (!Bytes.Data || !Memory::GetInstance().IsValid(
                        reinterpret_cast<uintptr_t>(Bytes.Data)))))
                return -1;
            return Bytes.Num;
        };

        if (PlayerState->GetOffset("UniqueID") == static_cast<int32>(
                SDKProfile::KnownBuild::APlayerStateUniqueID))
            Summary.PlayerStateIdentityBytes = ReplicationByteCount(
                reinterpret_cast<uintptr_t>(PlayerState)
                + SDKProfile::KnownBuild::APlayerStateUniqueID);

        UObject* ConnectionObject = static_cast<UObject*>(Connection);
        if (LooksLikeUObject(ConnectionObject)
            && ConnectionObject->GetOffset("PlayerID") == static_cast<int32>(
                SDKProfile::KnownBuild::UNetConnectionPlayerID))
            Summary.ConnectionIdentityBytes = ReplicationByteCount(
                reinterpret_cast<uintptr_t>(Connection)
                + SDKProfile::KnownBuild::UNetConnectionPlayerID);

        constexpr uint32 GetterFlags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Public)
            | static_cast<uint32>(EFunctionFlags::BlueprintCallable);
        UFunction* IdentityFunction = ResolveFunctionCached(
            CachedPlayerStateUniqueId,
            "Function ShooterGame.ShooterPlayerState.GetUniqueIdString",
            0x10, 1, GetterFlags);
        if (IdentityFunction && ValidateProcessEventTarget(PlayerState))
        {
            struct IdentityParameters { FString ReturnValue; } Params{};
            static_assert(sizeof(IdentityParameters) == 0x10,
                          "ShooterPlayerState GetUniqueIdString mismatch");
            PlayerState->ProcessEvent(IdentityFunction, &Params);
            Summary.OnlineIdentity = SafeFString(&Params.ReturnValue);
            void* ReturnedData = Params.ReturnValue.CStr();
            if (ReturnedData && FMemory::EngineRealloc
                && Memory::GetInstance().IsValid(
                    reinterpret_cast<uintptr_t>(ReturnedData)))
                FMemory::Free(ReturnedData);
        }

        UFunction* ArkPassFunction = ResolveFunctionCached(
            CachedPlayerHasArkPass,
            "Function ShooterGame.ShooterPlayerController.PlayerHasArkPass",
            0x1, 1, GetterFlags);
        if (ArkPassFunction && LooksLikeUObject(PlayerController)
            && IsClassOrSuper(PlayerController, "ShooterPlayerController")
            && ValidateProcessEventTarget(PlayerController))
        {
            struct ArkPassParameters { uint8 ReturnValue = 0; } Params;
            static_assert(sizeof(ArkPassParameters) == 0x1,
                          "PlayerHasArkPass parameters mismatch");
            PlayerController->ProcessEvent(ArkPassFunction, &Params);
            Summary.ArkPassKnown = true;
            Summary.HasArkPass = Params.ReturnValue != 0;
        }
        return true;
    }

    bool HostingRuntime::PopulatePlayerPersistence(UObject* PlayerData,
                                                    PlayerSummary& Summary)
    {
        if (!IsOnGameThread() || !LooksLikeUObject(PlayerData)
            || !IsClassOrSuper(PlayerData, "PrimalPlayerData")
            || PlayerData->GetOffset("MyData") != static_cast<int32>(
                SDKProfile::KnownBuild::UPrimalPlayerDataMyData))
            return false;

        const uintptr_t Data = reinterpret_cast<uintptr_t>(PlayerData)
            + SDKProfile::KnownBuild::UPrimalPlayerDataMyData;
        Summary.PlayerDataId = *reinterpret_cast<const uint64*>(Data
            + SDKProfile::KnownBuild::FPrimalPlayerDataPlayerDataID);
        const ArrayHeader PersistentBytes = Memory::GetInstance().Read<ArrayHeader>(
            Data + SDKProfile::KnownBuild::FPrimalPlayerDataUniqueID + 0x18);
        Summary.PlayerDataIdentityBytes = (PersistentBytes.Num >= 0
            && PersistentBytes.Num <= 128
            && PersistentBytes.Max >= PersistentBytes.Num
            && PersistentBytes.Max <= 128
            && (PersistentBytes.Num == 0 || (PersistentBytes.Data
                && Memory::GetInstance().IsValid(
                    reinterpret_cast<uintptr_t>(PersistentBytes.Data)))))
            ? PersistentBytes.Num : -1;
        Summary.SavedNetworkAddress = SafeFString(
            reinterpret_cast<const FString*>(Data
                + SDKProfile::KnownBuild::FPrimalPlayerDataSavedNetworkAddress));

        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Public)
            | static_cast<uint32>(EFunctionFlags::BlueprintCallable);
        UFunction* Function = ResolveFunctionCached(CachedPlayerDataUniqueId,
            "Function ShooterGame.PrimalPlayerData.GetUniqueIdString",
            0x10, 1, Flags);
        if (!Function)
            return true;

        struct Parameters { FString ReturnValue; } Params{};
        static_assert(sizeof(Parameters) == 0x10,
                      "GetUniqueIdString parameters mismatch");
        if (!DispatchBaseProcessEvent(PlayerData, Function, &Params))
        {
            Summary.PersistentIdentity =
                PersistentIdentityResult::DispatchRejected;
            return true;
        }

        const int32 ReturnedNum = Params.ReturnValue.Num();
        const int32 ReturnedMax = Params.ReturnValue.Max();
        void* ReturnedData = Params.ReturnValue.CStr();
        bool ReturnedStringValid = ReturnedNum >= 0 && ReturnedNum <= 512
            && ReturnedMax >= ReturnedNum && ReturnedMax <= 512;
        if (ReturnedStringValid && ReturnedNum == 0)
        {
            ReturnedStringValid = (!ReturnedData && ReturnedMax == 0)
                || (ReturnedData && ReturnedMax > 0
                    && Memory::GetInstance().IsValid(
                        reinterpret_cast<uintptr_t>(ReturnedData)));
        }
        else if (ReturnedStringValid)
        {
            const uintptr_t First = reinterpret_cast<uintptr_t>(ReturnedData);
            const uintptr_t Last = First
                + static_cast<uintptr_t>(ReturnedNum - 1) * sizeof(char16_t);
            ReturnedStringValid = ReturnedData
                && Memory::GetInstance().IsValid(First)
                && Memory::GetInstance().IsValid(Last)
                && Memory::GetInstance().Read<char16_t>(Last) == u'\0';
        }
        if (!ReturnedStringValid)
        {
            Summary.PersistentIdentity = PersistentIdentityResult::Invalid;
            return true;
        }

        Summary.PersistentIdentityValue = ReturnedNum > 0
            ? Params.ReturnValue.ToString() : std::string{};
        Summary.PersistentIdentity = Summary.PersistentIdentityValue.empty()
            ? PersistentIdentityResult::Empty
            : PersistentIdentityResult::Present;
        if (ReturnedData && FMemory::EngineRealloc
            && Memory::GetInstance().IsValid(
                reinterpret_cast<uintptr_t>(ReturnedData)))
            FMemory::Free(ReturnedData);
        return true;
    }

    void HostingRuntime::LogStasisRegistrationSnapshot(
        UWorld* World, ClientRecoveryRecord& Record,
        AShooterPlayerController* PlayerController, AActor* Pawn)
    {
        if (!IsOnGameThread() || !World || !PlayerController || !Pawn
            || !KnownProfileEligible)
            return;

        UObject* PersistentLevel = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UWorldPersistentLevel));
        UObject* WorldSettings = LooksLikeUObject(PersistentLevel)
            ? static_cast<UObject*>(ReadPointer(
                reinterpret_cast<uintptr_t>(PersistentLevel)
                + SDKProfile::KnownBuild::ULevelWorldSettings))
            : nullptr;

        int32 SourceCount = -1;
        bool RemoteControllerRegistered = false;
        int32 TimestampCount = -1;
        bool RemotePawnTimestampPresent = false;
        double RemoteTimestampAge = -1.0;

        const bool WorldSettingsLayout = LooksLikeUObject(WorldSettings)
            && IsClassOrSuper(WorldSettings, "BasePrimalWorldSettings");
        if (WorldSettingsLayout)
        {
            const uintptr_t SettingsAddress =
                reinterpret_cast<uintptr_t>(WorldSettings);
            const uintptr_t SourcesAddress = SettingsAddress
                + SDKProfile::KnownBuild::ABasePrimalWorldSettingsUnstasisViewpointControllers;
            const ArrayHeader Sources = Memory::GetInstance().Read<ArrayHeader>(
                SourcesAddress);
            const bool SourcesValid = CanReadMemoryRange(
                    SourcesAddress, sizeof(ArrayHeader))
                && Sources.Num >= 0 && Sources.Num <= 128
                && Sources.Max >= Sources.Num && Sources.Max <= 128
                && ((Sources.Num == 0 && (!Sources.Data || Sources.Max == 0))
                    || (Sources.Data && CanReadMemoryRange(
                        reinterpret_cast<uintptr_t>(Sources.Data),
                        static_cast<std::size_t>(std::max(Sources.Num, 1))
                            * sizeof(void*))));
            if (SourcesValid)
            {
                SourceCount = Sources.Num;
                for (int32 Index = 0; Index < Sources.Num; ++Index)
                {
                    if (ReadPointer(reinterpret_cast<uintptr_t>(Sources.Data)
                            + static_cast<uintptr_t>(Index) * sizeof(void*))
                        == PlayerController)
                    {
                        RemoteControllerRegistered = true;
                        break;
                    }
                }
            }

            const uintptr_t Viewpoints = SettingsAddress
                + SDKProfile::KnownBuild::ABasePrimalWorldSettingsPlayerCharacterUnstasisViewpoints;
            const int32 Allocated = Memory::GetInstance().Read<int32>(
                Viewpoints + 0x8);
            const int32 MaxAllocated = Memory::GetInstance().Read<int32>(
                Viewpoints + 0xC);
            const int32 Free = Memory::GetInstance().Read<int32>(
                Viewpoints + 0x34);
            const int32 FlagBits = Memory::GetInstance().Read<int32>(
                Viewpoints + 0x28);
            const int32 MaxFlagBits = Memory::GetInstance().Read<int32>(
                Viewpoints + 0x2C);
            void* MapData = ReadPointer(Viewpoints);
            void* SecondaryFlags = ReadPointer(Viewpoints + 0x20);
            const uintptr_t FlagData = SecondaryFlags
                ? reinterpret_cast<uintptr_t>(SecondaryFlags)
                : Viewpoints + 0x10;
            const std::size_t FlagBytes = static_cast<std::size_t>(
                (std::max(FlagBits, 0) + 31) / 32) * sizeof(uint32);
            const bool MapValid = CanReadMemoryRange(Viewpoints, 0x50)
                && Allocated >= 0 && Allocated <= 128
                && MaxAllocated >= Allocated && MaxAllocated <= 128
                && Free >= 0 && Free <= Allocated
                && FlagBits == Allocated && MaxFlagBits >= FlagBits
                && MaxFlagBits <= 128
                && ((Allocated == 0 && (!MapData || MaxAllocated == 0))
                    || (MapData && CanReadMemoryRange(
                        reinterpret_cast<uintptr_t>(MapData),
                        static_cast<std::size_t>(std::max(Allocated, 1)) * 24)))
                && (FlagBytes == 0 || CanReadMemoryRange(FlagData, FlagBytes));
            if (MapValid)
            {
                TimestampCount = Allocated - Free;
                const double Clock = Memory::GetInstance().Read<double>(
                    reinterpret_cast<uintptr_t>(World)
                    + SDKProfile::KnownBuild::UWorldUnstasisTimestampClock);
                for (int32 Index = 0; Index < Allocated; ++Index)
                {
                    const uint32 Word = Memory::GetInstance().Read<uint32>(
                        FlagData + static_cast<uintptr_t>(Index / 32)
                            * sizeof(uint32));
                    if ((Word & (uint32{1} << (Index % 32))) == 0)
                        continue;
                    const uintptr_t Slot = reinterpret_cast<uintptr_t>(MapData)
                        + static_cast<uintptr_t>(Index) * 24;
                    if (ReadPointer(Slot) != Pawn)
                        continue;
                    RemotePawnTimestampPresent = true;
                    const double Timestamp = Memory::GetInstance().Read<double>(
                        Slot + 8);
                    if (std::isfinite(Clock) && std::isfinite(Timestamp))
                        RemoteTimestampAge = Clock - Timestamp;
                    break;
                }
            }
        }

        const int32 WorldFrame = Memory::GetInstance().Read<int32>(
            reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UPrimalWorldFrameCounter);
        const int32 RemoteFrame = Memory::GetInstance().Read<int32>(
            reinterpret_cast<uintptr_t>(PlayerController)
            + SDKProfile::KnownBuild::AShooterPlayerControllerLastValidUnstasisCasterFrame);

        std::ostringstream Details;
        Details << "Late-listen stasis snapshot " << Record.StableId
                << ": layout=" << (WorldSettingsLayout ? "confirmed" : "unavailable")
                << ", viewpointControllers="
                << (SourceCount >= 0 ? std::to_string(SourceCount) : "invalid")
                << ", remotePCRegistered="
                << (RemoteControllerRegistered ? "true" : "false")
                << ", timestampActors="
                << (TimestampCount >= 0 ? std::to_string(TimestampCount) : "invalid")
                << ", remotePawnTimestamp="
                << (RemotePawnTimestampPresent ? "present" : "missing")
                << ", timestampAge="
                << (RemoteTimestampAge >= 0.0 && std::isfinite(RemoteTimestampAge)
                    ? std::to_string(RemoteTimestampAge) : "unavailable")
                << ", worldFrame=" << WorldFrame
                << ", remoteUnstasisFrame=" << RemoteFrame
                << ", frameAge="
                << (static_cast<int64>(WorldFrame)
                    - static_cast<int64>(RemoteFrame));
        AddLog(Details.str(), WorldSettingsLayout
            ? LogLevel::Info : LogLevel::Warning);
        Record.StasisSnapshotLogged = true;
    }

    void HostingRuntime::LogPlayerPersistenceLookupSnapshot(
        ClientRecoveryRecord& Record, const PlayerSummary& Incoming)
    {
        if (Record.PersistenceLookupLogged || !IsOnGameThread())
            return;

        UObject* GameMode = GetAuthorityGameMode();
        if (!LooksLikeUObject(GameMode)
            || !IsClassOrSuper(GameMode, "ShooterGameMode"))
            return;

        uint8 AutoCreateMask = 0;
        uint8 DisableSaveMask = 0;
        const int32 AutoCreateOffset = GameMode->GetOffset(
            "bAutoCreateNewPlayerData", &AutoCreateMask);
        const int32 DisableSaveOffset = GameMode->GetOffset(
            "bDisableSaveLoad", &DisableSaveMask);
        const int32 PlayerDatasOffset = GameMode->GetOffset("PlayerDatas");
        const bool LayoutConfirmed =
            AutoCreateOffset == static_cast<int32>(
                SDKProfile::KnownBuild::AShooterGameModeAutoCreateNewPlayerData)
            && DisableSaveOffset == static_cast<int32>(
                SDKProfile::KnownBuild::AShooterGameModeDisableSaveLoad)
            && PlayerDatasOffset == static_cast<int32>(
                SDKProfile::KnownBuild::AShooterGameModePlayerDatas)
            && AutoCreateMask && DisableSaveMask;
        if (!LayoutConfirmed)
        {
            AddLog("Player persistence lookup " + Record.StableId
                   + ": ShooterGameMode persistence layout rejected",
                   LogLevel::Warning);
            Record.PersistenceLookupLogged = true;
            return;
        }

        const uintptr_t GM = reinterpret_cast<uintptr_t>(GameMode);
        const bool AutoCreate = (Memory::GetInstance().Read<uint8>(
            GM + AutoCreateOffset) & AutoCreateMask) != 0;
        const bool DisableSave = (Memory::GetInstance().Read<uint8>(
            GM + DisableSaveOffset) & DisableSaveMask) != 0;
        const ArrayHeader PlayerDatas = Memory::GetInstance().Read<ArrayHeader>(
            GM + PlayerDatasOffset);
        const bool ArrayStorageValid = PlayerDatas.Num > 0
            ? (PlayerDatas.Data && CanReadMemoryRange(
                reinterpret_cast<uintptr_t>(PlayerDatas.Data),
                static_cast<std::size_t>(PlayerDatas.Num) * sizeof(void*)))
            : (PlayerDatas.Max == 0 ? PlayerDatas.Data == nullptr
                : (PlayerDatas.Data && CanReadMemoryRange(
                    reinterpret_cast<uintptr_t>(PlayerDatas.Data), 1)));
        const bool ArrayValid = PlayerDatas.Num >= 0 && PlayerDatas.Num <= 256
            && PlayerDatas.Max >= PlayerDatas.Num && PlayerDatas.Max <= 256
            && ArrayStorageValid;

        int32 ValidEntries = 0;
        int32 PresentIdentities = 0;
        UObject* MatchingPlayerData = nullptr;
        uint64 MatchingPlayerDataId = 0;
        std::ostringstream FirstIdentities;
        if (ArrayValid)
        {
            for (int32 Index = 0; Index < PlayerDatas.Num; ++Index)
            {
                UObject* PlayerData = static_cast<UObject*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(PlayerDatas.Data)
                    + static_cast<uintptr_t>(Index) * sizeof(void*)));
                if (!LooksLikeUObject(PlayerData)
                    || !IsClassOrSuper(PlayerData, "PrimalPlayerData"))
                    continue;
                ++ValidEntries;
                PlayerSummary Candidate;
                if (!PopulatePlayerPersistence(PlayerData, Candidate)
                    || Candidate.PersistentIdentity
                        != PersistentIdentityResult::Present)
                    continue;
                ++PresentIdentities;
                if (PresentIdentities <= 4)
                {
                    if (PresentIdentities > 1) FirstIdentities << "; ";
                    FirstIdentities << Candidate.PlayerDataId << "="
                                    << Candidate.PersistentIdentityValue;
                }
                if (!Incoming.OnlineIdentity.empty()
                    && Candidate.PersistentIdentityValue
                        == Incoming.OnlineIdentity)
                {
                    MatchingPlayerData = PlayerData;
                    MatchingPlayerDataId = Candidate.PlayerDataId;
                }
            }
        }

        std::ostringstream Details;
        Details << "Player persistence lookup " << Record.StableId
                << ": incomingIdentity="
                << (Incoming.OnlineIdentity.empty()
                    ? "missing" : Incoming.OnlineIdentity)
                << ", identityBytes(PS/connection)="
                << Incoming.PlayerStateIdentityBytes << "/"
                << Incoming.ConnectionIdentityBytes
                << ", bAutoCreateNewPlayerData="
                << (AutoCreate ? "true" : "false")
                << ", bDisableSaveLoad="
                << (DisableSave ? "true" : "false")
                << ", PlayerDatas=";
        if (ArrayValid)
            Details << PlayerDatas.Num << "/" << PlayerDatas.Max
                    << ", valid=" << ValidEntries
                    << ", identities=" << PresentIdentities;
        else
            Details << "invalid(" << PlayerDatas.Num << "/"
                    << PlayerDatas.Max << ")";
        Details << ", matchingPlayerData=" << DescribeObject(MatchingPlayerData)
                << ", matchingPlayerDataID=" << MatchingPlayerDataId;
        if (!FirstIdentities.str().empty())
            Details << ", firstIdentities={" << FirstIdentities.str() << "}";
        AddLog(Details.str(), (DisableSave || !ArrayValid)
            ? LogLevel::Warning : LogLevel::Info);
        Record.PersistenceLookupLogged = true;
    }

    void HostingRuntime::UpdateRecoveryState(UWorld* World,
                                              UNetDriver* HostDriver)
    {
        WeakObjectIdentity ExpectedWorld;
        WeakObjectIdentity ExpectedDriver;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ExpectedWorld = HostedWorldIdentity;
            ExpectedDriver = HostedNetDriverIdentity;
        }
        if (!IsOnGameThread() || !KnownProfileEligible
            || ResolveWeakIdentity(ExpectedWorld) != World
            || ResolveWeakIdentity(ExpectedDriver) != HostDriver
            || ReadPointer(reinterpret_cast<uintptr_t>(World)
                + SDKProfile::KnownBuild::UWorldNetDriver) != HostDriver
            || ReadPointer(reinterpret_cast<uintptr_t>(HostDriver)
                + SDKProfile::KnownBuild::UNetDriverWorld) != World)
            return;

        const ArrayHeader Connections = Memory::GetInstance().Read<ArrayHeader>(
            reinterpret_cast<uintptr_t>(HostDriver)
            + SDKProfile::KnownBuild::UNetDriverClientConnections);
        if (Connections.Num < 0 || Connections.Num > 128
            || Connections.Max < Connections.Num || Connections.Max > 128
            || (Connections.Num > 0
                && (!Connections.Data || !Memory::GetInstance().IsValid(
                    reinterpret_cast<uintptr_t>(Connections.Data)))))
            return;

        for (ClientRecoveryRecord& Record : RecoveryRecords)
            Record.SeenThisScan = false;
        std::vector<PlayerSummary> Summaries;
        const auto Now = std::chrono::steady_clock::now();

        for (int32 Index = 0; Index < Connections.Num; ++Index)
        {
            void* Connection = ReadPointer(reinterpret_cast<uintptr_t>(Connections.Data)
                                           + sizeof(void*) * Index);
            const WeakObjectIdentity ConnectionIdentity = MakeWeakIdentity(Connection);
            if (!ConnectionIdentity.IsSet())
                continue;

            auto Existing = std::find_if(RecoveryRecords.begin(), RecoveryRecords.end(),
                [this, &ConnectionIdentity](const ClientRecoveryRecord& Candidate)
                { return SameIdentity(Candidate.Connection, ConnectionIdentity); });
            if (Existing == RecoveryRecords.end())
            {
                ClientRecoveryRecord NewRecord;
                NewRecord.Connection = ConnectionIdentity;
                NewRecord.DiscoveredAt = Now;
                NewRecord.StateChangedAt = Now;
                NewRecord.StableId = "c" + std::to_string(ConnectionIdentity.ObjectIndex)
                    + ":" + std::to_string(ConnectionIdentity.SerialNumber);
                RecoveryRecords.push_back(NewRecord);
                Existing = std::prev(RecoveryRecords.end());
                AddLog("RPC recovery discovered remote connection "
                       + Existing->StableId);
            }
            ClientRecoveryRecord& Record = *Existing;
            Record.SeenThisScan = true;

            AShooterPlayerController* PC = static_cast<AShooterPlayerController*>(ReadPointer(
                reinterpret_cast<uintptr_t>(Connection)
                + SDKProfile::KnownBuild::UPlayerPlayerController));
            const WeakObjectIdentity PCIdentity = MakeWeakIdentity(PC);
            if (!PCIdentity.IsSet() || !IsClassOrSuper(PC, "ShooterPlayerController"))
                continue;
            if (Record.PlayerController.IsSet()
                && !SameIdentity(Record.PlayerController, PCIdentity))
            {
                TransitionRecovery(Record, RecoveryState::Disconnected,
                                   "PlayerController identity changed");
                Record = ClientRecoveryRecord{};
                Record.Connection = ConnectionIdentity;
                Record.PlayerController = PCIdentity;
                Record.DiscoveredAt = Now;
                Record.StateChangedAt = Now;
                Record.SeenThisScan = true;
            }
            if (PC->GetOffset("NetConnection") != static_cast<int32>(
                    SDKProfile::KnownBuild::APlayerControllerNetConnection)
                || ReadPointer(reinterpret_cast<uintptr_t>(PC)
                    + SDKProfile::KnownBuild::APlayerControllerNetConnection) != Connection)
            {
                TransitionRecovery(Record, RecoveryState::Failed,
                                   "remote controller/connection ownership rejected");
                continue;
            }
            Record.PlayerController = PCIdentity;
            Record.StableId = "c" + std::to_string(ConnectionIdentity.ObjectIndex)
                + ":" + std::to_string(ConnectionIdentity.SerialNumber)
                + "/p" + std::to_string(PCIdentity.ObjectIndex)
                + ":" + std::to_string(PCIdentity.SerialNumber);

            uint8 WaitingMask = 0;
            const bool PCLayout =
                PC->GetOffset("PlayerState") == static_cast<int32>(SDKProfile::KnownBuild::AControllerPlayerState)
                && PC->GetOffset("StateName") == static_cast<int32>(SDKProfile::KnownBuild::AControllerStateName)
                && PC->GetOffset("Pawn") == static_cast<int32>(SDKProfile::KnownBuild::AControllerPawn)
                && PC->GetOffset("AcknowledgedPawn") == static_cast<int32>(SDKProfile::KnownBuild::APlayerControllerAcknowledgedPawn)
                && PC->GetOffset("bPlayerIsWaiting", &WaitingMask) == static_cast<int32>(SDKProfile::KnownBuild::APlayerControllerPlayerIsWaiting)
                && WaitingMask != 0;
            if (!PCLayout)
            {
                TransitionRecovery(Record, RecoveryState::Failed,
                                   "PlayerController layout rejected");
                continue;
            }

            const uintptr_t PCAddress = reinterpret_cast<uintptr_t>(PC);
            UObject* PlayerState = static_cast<UObject*>(ReadPointer(
                PCAddress + SDKProfile::KnownBuild::AControllerPlayerState));
            const WeakObjectIdentity PlayerStateIdentity = MakeWeakIdentity(PlayerState);
            const FName StateNameValue = *reinterpret_cast<const FName*>(
                PCAddress + SDKProfile::KnownBuild::AControllerStateName);
            const std::string StateName = StateNameValue.ToString();
            const bool Waiting = (*(reinterpret_cast<const uint8*>(PC)
                + SDKProfile::KnownBuild::APlayerControllerPlayerIsWaiting)
                & WaitingMask) != 0;
            AActor* Pawn = static_cast<AActor*>(ReadPointer(
                PCAddress + SDKProfile::KnownBuild::AControllerPawn));
            AActor* AcknowledgedPawn = static_cast<AActor*>(ReadPointer(
                PCAddress + SDKProfile::KnownBuild::APlayerControllerAcknowledgedPawn));

            PlayerSummary Summary;
            Summary.StableId = Record.StableId;
            Summary.Controller = PC->ClassPrivate->NamePrivate.ToString();
            Summary.StateName = StateName;
            Summary.Waiting = Waiting;
            Summary.Pawn = LooksLikeUObject(Pawn)
                ? static_cast<UObject*>(Pawn)->ClassPrivate->NamePrivate.ToString()
                : "null";

            uint8 AdminMask = 0;
            uint8 CheatMask = 0;
            if (PC->GetOffset("bIsAdmin", &AdminMask) == static_cast<int32>(
                    SDKProfile::KnownBuild::APlayerControllerAdminFlags)
                && PC->GetOffset("bCheatPlayer", &CheatMask)
                    == static_cast<int32>(
                        SDKProfile::KnownBuild::APlayerControllerAdminFlags)
                && AdminMask
                    == SDKProfile::KnownBuild::APlayerControllerIsAdminMask
                && CheatMask
                    == SDKProfile::KnownBuild::APlayerControllerCheatPlayerMask)
            {
                const uint8 ControllerFlags = *(reinterpret_cast<const uint8*>(PC)
                    + SDKProfile::KnownBuild::APlayerControllerAdminFlags);
                Summary.IsAdmin = (ControllerFlags & AdminMask) != 0;
                Summary.IsCheatPlayer = (ControllerFlags & CheatMask) != 0;
            }

            if (static_cast<UObject*>(Connection)->GetOffset("LastReceiveTime")
                    == static_cast<int32>(
                        SDKProfile::KnownBuild::UNetConnectionLastReceiveTime)
                && static_cast<UObject*>(HostDriver)->GetOffset("Time")
                    == static_cast<int32>(SDKProfile::KnownBuild::UNetDriverTime))
            {
                const double LastReceive = *reinterpret_cast<const double*>(
                    reinterpret_cast<uintptr_t>(Connection)
                    + SDKProfile::KnownBuild::UNetConnectionLastReceiveTime);
                const float DriverTime = *reinterpret_cast<const float*>(
                    reinterpret_cast<uintptr_t>(HostDriver)
                    + SDKProfile::KnownBuild::UNetDriverTime);
                const double ReceiveAge = static_cast<double>(DriverTime)
                    - LastReceive;
                if (std::isfinite(LastReceive) && std::isfinite(ReceiveAge)
                    && LastReceive >= 0.0 && std::abs(ReceiveAge) < 1000000.0)
                {
                    Summary.ReceiveTimingValid = true;
                    Summary.ReceiveAgeSeconds = std::max(0.0, ReceiveAge);
                    Summary.Responsive = Summary.ReceiveAgeSeconds < 15.0;
                }
            }

            if (!PlayerStateIdentity.IsSet())
            {
                TransitionRecovery(Record, RecoveryState::WaitingForPlayerState);
                Summary.PlayerName = "Connecting player";
                Summary.PlayerState = "null";
                Summary.Recovery = RecoveryStateName(Record.State);
                Summaries.push_back(std::move(Summary));
                continue;
            }
            Record.PlayerState = PlayerStateIdentity;
            Summary.PlayerState = PlayerState->ClassPrivate->NamePrivate.ToString();

            void* PlayerData = nullptr;
            const bool ShooterPlayerStateLayout =
                IsClassOrSuper(PlayerState, "ShooterPlayerState")
                && PlayerState->GetOffset("MyPlayerData") == static_cast<int32>(
                    SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData);
            PopulatePlayerOnlineIdentity(PlayerState, PC, Connection, Summary);
            if (ShooterPlayerStateLayout)
                PlayerData = ReadPointer(reinterpret_cast<uintptr_t>(PlayerState)
                    + SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData);
            const bool HasPlayerData = LooksLikeUObject(PlayerData);
            if (!HasPlayerData && !Record.PersistenceLookupLogged
                && !Summary.OnlineIdentity.empty())
                LogPlayerPersistenceLookupSnapshot(Record, Summary);
            const bool HasPawn = LooksLikeUObject(Pawn)
                || LooksLikeUObject(AcknowledgedPawn);
            Summary.HasPlayerData = HasPlayerData;
            Summary.Playing = Summary.Responsive
                && (StateName == "Playing" || (!Waiting && HasPawn));
            if (HasPlayerData)
            {
                const bool PersistenceLayout = PopulatePlayerPersistence(
                    static_cast<UObject*>(PlayerData), Summary);
                if (PersistenceLayout
                    && Summary.PersistentIdentity
                        == PersistentIdentityResult::Empty
                    && !Record.PersistenceWarningLogged)
                {
                    Record.PersistenceWarningLogged = true;
                    AddLog("Player persistence identity is empty for "
                           + Record.StableId
                           + "; PlayerState online identity="
                           + (Summary.OnlineIdentity.empty()
                                ? "missing" : Summary.OnlineIdentity)
                           + ", identity bytes PlayerData/PS/connection="
                           + std::to_string(Summary.PlayerDataIdentityBytes)
                           + "/"
                           + std::to_string(Summary.PlayerStateIdentityBytes)
                           + "/" + std::to_string(Summary.ConnectionIdentityBytes)
                           + ". IP reconnect may create a new character even when world save succeeds",
                           LogLevel::Warning);
                }
            }

            if (PlayerState->GetOffset("PlayerID") == static_cast<int32>(
                    SDKProfile::KnownBuild::APlayerStatePlayerID))
                Summary.PlayerId = *reinterpret_cast<const int32*>(
                    reinterpret_cast<uintptr_t>(PlayerState)
                    + SDKProfile::KnownBuild::APlayerStatePlayerID);
            if (PlayerState->GetOffset("PlayerNamePrivate") == static_cast<int32>(
                    SDKProfile::KnownBuild::APlayerStatePlayerNamePrivate))
                Summary.PlayerName = SafeFString(reinterpret_cast<const FString*>(
                    reinterpret_cast<uintptr_t>(PlayerState)
                    + SDKProfile::KnownBuild::APlayerStatePlayerNamePrivate));
            if (Summary.PlayerName.empty())
                Summary.PlayerName = Summary.PlayerId >= 0
                    ? "Player " + std::to_string(Summary.PlayerId) : "Remote player";

            AActor* EffectivePawn = LooksLikeUObject(Pawn)
                ? Pawn : (LooksLikeUObject(AcknowledgedPawn)
                    ? AcknowledgedPawn : nullptr);
            if (Summary.Playing && EffectivePawn
                && !Record.StasisSnapshotLogged)
                LogStasisRegistrationSnapshot(World, Record, PC, EffectivePawn);

            if (Record.State == RecoveryState::Completed)
            {
                // Keep publishing the live player summary, but do not run the
                // recovery transition logic again for this identity.
            }
            else if (!ShooterPlayerStateLayout)
            {
                TransitionRecovery(Record, RecoveryState::Failed,
                                   "ShooterPlayerState/MyPlayerData layout rejected");
            }
            else if (Summary.Playing || (HasPlayerData && HasPawn))
            {
                TransitionRecovery(Record, RecoveryState::Playing);
                TransitionRecovery(Record, RecoveryState::Completed);
            }
            else if (Record.DispatchAttempts > 0)
            {
                if (Now - Record.RPCSentAt > std::chrono::seconds(45))
                    TransitionRecovery(Record, RecoveryState::TimedOut,
                                       "no duplicate RPC retry was sent");
                else if (HasPlayerData)
                    TransitionRecovery(Record, RecoveryState::AwaitingPawn);
                else
                    TransitionRecovery(Record, RecoveryState::AwaitingPlayerData);
            }
            else if (Record.NativePostLoginRouted
                     && Now - Record.NativePostLoginAt
                        < std::chrono::seconds(15))
            {
                // The stock mobile token branch is empty. Our low-frequency
                // PostLogin hook has already run ShooterGame's synchronous
                // RealPostLogin/StartNewPlayer load path. Do not race that
                // path with the character-creation recovery pair.
                TransitionRecovery(Record, RecoveryState::AwaitingPlayerData,
                    "native RealPostLogin/StartNewPlayer persistence flow");
            }
            else if (!HasPlayerData && !HasPawn
                     && (Waiting || StateName == "Spectating"))
            {
                TransitionRecovery(Record, RecoveryState::EligibleForRecovery);
                DispatchRecoveryRPCs(Record, PC, PlayerState, Connection);
            }

            Summary.Recovery = RecoveryStateName(Record.State);
            Summaries.push_back(std::move(Summary));
        }

        for (ClientRecoveryRecord& Record : RecoveryRecords)
        {
            if (!Record.SeenThisScan && Record.State != RecoveryState::Disconnected)
                TransitionRecovery(Record, RecoveryState::Disconnected);
        }
        RecoveryRecords.erase(std::remove_if(RecoveryRecords.begin(), RecoveryRecords.end(),
            [](const ClientRecoveryRecord& Record)
            {
                return !Record.SeenThisScan
                    && Record.State == RecoveryState::Disconnected
                    && std::chrono::steady_clock::now() - Record.StateChangedAt
                        > std::chrono::seconds(5);
            }), RecoveryRecords.end());

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            PlayerSummaries = std::move(Summaries);
            if (Hosting)
                HostState = HostLifecycleState::AcceptingClients;
        }
    }

    bool HostingRuntime::ExecuteSaveWorld()
    {
        const auto SaveStartedAt = std::chrono::steady_clock::now();
        void* World = nullptr;
        void* HostDriver = nullptr;
        WeakObjectIdentity WorldIdentity;
        WeakObjectIdentity DriverIdentity;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            World = HostedWorld;
            HostDriver = HostedNetDriver;
            WorldIdentity = HostedWorldIdentity;
            DriverIdentity = HostedNetDriverIdentity;
        }
        if (!IsOnGameThread() || ResolveWeakIdentity(WorldIdentity) != World
            || ResolveWeakIdentity(DriverIdentity) != HostDriver
            || !LooksLikeUObject(World) || !LooksLikeUObject(HostDriver)
            || ReadPointer(reinterpret_cast<uintptr_t>(World)
                + SDKProfile::KnownBuild::UWorldNetDriver) != HostDriver
            || ReadPointer(reinterpret_cast<uintptr_t>(HostDriver)
                + SDKProfile::KnownBuild::UNetDriverWorld) != World)
        {
            SetError("Save world refused: hosted world/driver identity is stale");
            return false;
        }

        int32 ValidatedPlayerData = 0;
        int32 ScannedConnections = 0;
        int32 MissingController = 0;
        int32 OwnershipRejected = 0;
        int32 MissingPlayerState = 0;
        int32 MissingPlayerData = 0;
        int32 SerialZeroTargets = 0;
        int32 MissingPersistentIdentity = 0;
        int32 PersistentIdentityLayoutRejected = 0;
        int32 PersistentIdentityGetterUnavailable = 0;
        int32 PersistentIdentityDispatchRejected = 0;
        int32 PersistentIdentityInvalid = 0;
        std::vector<uint64> PlayerDataIds;
        std::vector<int32> PlayerDataIdentityPayloadBytes;
        // Snapshot current connected PlayerData for the audit log. The actual
        // write is performed once by the stock synchronous SaveWorld path
        // below; dispatching SavePlayerData here as well would race two writes
        // to the same character file.
        const ArrayHeader Connections = Memory::GetInstance().Read<ArrayHeader>(
            reinterpret_cast<uintptr_t>(HostDriver)
            + SDKProfile::KnownBuild::UNetDriverClientConnections);
        const bool ConnectionsValid = Connections.Num >= 0
            && Connections.Num <= 128 && Connections.Max >= Connections.Num
            && Connections.Max <= 128 && (Connections.Num == 0
                || (Connections.Data && Memory::GetInstance().IsValid(
                    reinterpret_cast<uintptr_t>(Connections.Data))));
        if (!ConnectionsValid)
        {
            AddLog("Connected PlayerData snapshot skipped: ClientConnections layout rejected",
                   LogLevel::Warning);
        }
        else for (int32 Index = 0; Index < Connections.Num; ++Index)
        {
                ++ScannedConnections;
                void* Connection = ReadPointer(
                    reinterpret_cast<uintptr_t>(Connections.Data)
                    + sizeof(void*) * Index);
                UObject* ConnectionObject = static_cast<UObject*>(Connection);
                if (!LooksLikeUObject(ConnectionObject)
                    || ReadPointer(reinterpret_cast<uintptr_t>(Connection)
                        + SDKProfile::KnownBuild::UNetConnectionDriver) != HostDriver)
                {
                    ++OwnershipRejected;
                    continue;
                }
                UObject* PC = static_cast<UObject*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(Connection)
                    + SDKProfile::KnownBuild::UPlayerPlayerController));
                if (!LooksLikeUObject(PC)
                    || !IsClassOrSuper(PC, "ShooterPlayerController"))
                {
                    ++MissingController;
                    continue;
                }
                if (PC->GetOffset("NetConnection") != static_cast<int32>(
                        SDKProfile::KnownBuild::APlayerControllerNetConnection)
                    || ReadPointer(reinterpret_cast<uintptr_t>(PC)
                        + SDKProfile::KnownBuild::APlayerControllerNetConnection)
                        != Connection)
                {
                    ++OwnershipRejected;
                    continue;
                }
                UObject* PlayerState = static_cast<UObject*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(PC)
                    + SDKProfile::KnownBuild::AControllerPlayerState));
                if (!LooksLikeUObject(PlayerState)
                    || !IsClassOrSuper(PlayerState, "ShooterPlayerState")
                    || PlayerState->GetOffset("MyPlayerData") != static_cast<int32>(
                        SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData))
                {
                    ++MissingPlayerState;
                    continue;
                }
                UObject* PlayerData = static_cast<UObject*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(PlayerState)
                    + SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData));
                if (!LooksLikeUObject(PlayerData)
                    || !IsClassOrSuper(PlayerData, "PrimalPlayerData"))
                {
                    ++MissingPlayerData;
                    continue;
                }
                const FUObjectItem* PlayerDataItem = UObject::GUObjectArray
                    && PlayerData->InternalIndex >= 0
                    ? UObject::GUObjectArray->ObjObjects.IndexToObject(
                        PlayerData->InternalIndex)
                    : nullptr;
                if (PlayerDataItem && PlayerDataItem->Object == PlayerData
                    && PlayerDataItem->SerialNumber == 0)
                    ++SerialZeroTargets;
                PlayerSummary Persistence;
                if (PopulatePlayerPersistence(PlayerData, Persistence))
                {
                    PlayerDataIds.push_back(Persistence.PlayerDataId);
                    PlayerDataIdentityPayloadBytes.push_back(
                        Persistence.PlayerDataIdentityBytes);
                    switch (Persistence.PersistentIdentity)
                    {
                        case PersistentIdentityResult::Unavailable:
                            ++PersistentIdentityGetterUnavailable;
                            break;
                        case PersistentIdentityResult::DispatchRejected:
                            ++PersistentIdentityDispatchRejected;
                            break;
                        case PersistentIdentityResult::Invalid:
                            ++PersistentIdentityInvalid;
                            break;
                        case PersistentIdentityResult::Empty:
                            ++MissingPersistentIdentity;
                            break;
                        case PersistentIdentityResult::Present:
                            break;
                    }
                }
                else
                {
                    ++PersistentIdentityLayoutRejected;
                }
                ++ValidatedPlayerData;
        }

        UObject* GameMode = GetAuthorityGameMode();
        const uintptr_t ImageBase = Memory::GetInstance().GetImageBase(
            Config::ImageName);
        const uintptr_t ExpectedSaveWorld = ImageBase
            + SDKProfile::KnownBuild::ShooterGameModeSaveWorld;
        const std::size_t SaveWorldSlot =
            SDKProfile::KnownBuild::ShooterGameModeSaveWorldVTableOffset
            / sizeof(void*);
        static constexpr uint8 SaveWorldPrefix[16] = {
            0xFF, 0xC3, 0x03, 0xD1, 0xFA, 0x67, 0x0A, 0xA9,
            0xF8, 0x5F, 0x0B, 0xA9, 0xF6, 0x57, 0x0C, 0xA9
        };
        if (!KnownProfileEligible || !GameMode
            || !ValidateProcessEventTarget(GameMode) || !ImageBase
            || !GameMode->VTable
            || reinterpret_cast<uintptr_t>(GameMode->VTable[SaveWorldSlot])
                != ExpectedSaveWorld
            || !Memory::GetInstance().IsValid(ExpectedSaveWorld)
            || std::memcmp(reinterpret_cast<const void*>(ExpectedSaveWorld),
                           SaveWorldPrefix, sizeof(SaveWorldPrefix)) != 0)
        {
            SetError("Save world refused: exact synchronous SaveWorld ABI is unavailable");
            AddLog("Synchronous SaveWorld validation failed", LogLevel::Error);
            return false;
        }
        {
            struct OriginalNetModeScope
            {
                OriginalNetModeScope()
                {
                    SynchronousSaveUsesOriginalHostedNetMode = true;
                }
                ~OriginalNetModeScope()
                {
                    SynchronousSaveUsesOriginalHostedNetMode = false;
                }
            } OriginalModeScope;
            AddLog("BEGIN native AShooterGameMode::SaveWorld(true,false)",
                   LogLevel::Debug);
            reinterpret_cast<ShooterGameModeSaveWorldFn>(ExpectedSaveWorld)(
                GameMode, true, false);
            AddLog("END native AShooterGameMode::SaveWorld(true,false)",
                   LogLevel::Debug);
        }
        const auto SaveElapsed = std::chrono::duration_cast<
            std::chrono::milliseconds>(
                std::chrono::steady_clock::now() - SaveStartedAt).count();
        std::ostringstream PlayerDataIdList;
        PlayerDataIdList << "{";
        const std::size_t IdCount = std::min<std::size_t>(
            PlayerDataIds.size(), 8);
        for (std::size_t Index = 0; Index < IdCount; ++Index)
        {
            if (Index) PlayerDataIdList << ",";
            PlayerDataIdList << PlayerDataIds[Index];
        }
        if (PlayerDataIds.size() > IdCount)
            PlayerDataIdList << ",...";
        PlayerDataIdList << "}";
        std::ostringstream IdentityPayloadList;
        IdentityPayloadList << "{";
        const std::size_t PayloadCount = std::min<std::size_t>(
            PlayerDataIdentityPayloadBytes.size(), 8);
        for (std::size_t Index = 0; Index < PayloadCount; ++Index)
        {
            if (Index) IdentityPayloadList << ",";
            IdentityPayloadList << PlayerDataIdentityPayloadBytes[Index];
        }
        if (PlayerDataIdentityPayloadBytes.size() > PayloadCount)
            IdentityPayloadList << ",...";
        IdentityPayloadList << "}";
        AddLog("Stock synchronous SaveWorld(true,false) returned after validating "
               + std::to_string(ValidatedPlayerData)
               + "/" + std::to_string(ScannedConnections)
               + " current connection PlayerData object(s) on the host game thread"
               + " (noPC=" + std::to_string(MissingController)
               + ", ownership=" + std::to_string(OwnershipRejected)
               + ", noPS=" + std::to_string(MissingPlayerState)
               + ", noPlayerData=" + std::to_string(MissingPlayerData)
               + ", serial0=" + std::to_string(SerialZeroTargets)
               + ", identityMissing=" + std::to_string(MissingPersistentIdentity)
               + ", identityLayout="
                    + std::to_string(PersistentIdentityLayoutRejected)
               + ", identityGetter="
                    + std::to_string(PersistentIdentityGetterUnavailable)
               + ", identityDispatch="
                    + std::to_string(PersistentIdentityDispatchRejected)
               + ", identityInvalid="
                    + std::to_string(PersistentIdentityInvalid)
               + ", identityPayloadBytes=" + IdentityPayloadList.str()
               + ", PlayerDataIDs=" + PlayerDataIdList.str()
               + ", elapsedMs=" + std::to_string(SaveElapsed) + ")");
        SetStatus("Synchronous world/player save returned");
        return true;
    }

    void HostingRuntime::ExecuteBroadcast(const std::string& Message)
    {
        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Public)
            | static_cast<uint32>(EFunctionFlags::HasDefaults)
            | static_cast<uint32>(EFunctionFlags::BlueprintCallable);
        UFunction* Function = ResolveFunctionCached(
            CachedSendServerChatMessage,
            "Function ShooterGame.ShooterGameMode.SendServerChatMessage",
            0x30, 5, Flags);
        UObject* GameMode = GetAuthorityGameMode();
        if (!Function || !GameMode || !ValidateProcessEventTarget(GameMode))
        {
            SetError("Broadcast refused: authoritative SendServerChatMessage ABI is unavailable");
            return;
        }

        struct Parameters
        {
            FString MessageText;
            float MessageColor[4] = {1.0f, 1.0f, 1.0f, 1.0f};
            uint8 IsBold = 0;
            uint8 Pad21[3]{};
            int32 ReceiverTeamId = -1;
            int32 ReceiverPlayerId = -1;
            uint8 Pad2C[4]{};
        };
        static_assert(sizeof(Parameters) == 0x30,
                      "SendServerChatMessage parameters mismatch");

        const std::u16string Wide(Message.begin(), Message.end());
        Parameters Params{};
        Params.MessageText = FString(Wide.c_str());
        AddLog("BEGIN authority GameMode SendServerChatMessage",
               LogLevel::Debug);
        GameMode->ProcessEvent(Function, &Params);
        AddLog("END authority GameMode SendServerChatMessage",
               LogLevel::Debug);
        AddLog("Authoritative server broadcast dispatched through ShooterGameMode");
        SetStatus("Broadcast dispatched");
    }

    void HostingRuntime::ExecuteSetRuntimeAdmin(const std::string& StableId,
                                                bool Enable)
    {
        const auto Record = std::find_if(
            RecoveryRecords.begin(), RecoveryRecords.end(),
            [&StableId](const ClientRecoveryRecord& Candidate)
            {
                return Candidate.StableId == StableId && Candidate.SeenThisScan
                    && Candidate.State != RecoveryState::Disconnected
                    && Candidate.State != RecoveryState::WorldChanged;
            });
        if (Record == RecoveryRecords.end())
        {
            SetError("Runtime-admin change refused: selected player identity is stale");
            return;
        }

        UObject* PC = static_cast<UObject*>(ResolveWeakIdentity(
            Record->PlayerController));
        void* Connection = ResolveWeakIdentity(Record->Connection);
        if (!PC || !Connection
            || !IsClassOrSuper(PC, "ShooterPlayerController")
            || PC->GetOffset("NetConnection") != static_cast<int32>(
                SDKProfile::KnownBuild::APlayerControllerNetConnection)
            || ReadPointer(reinterpret_cast<uintptr_t>(PC)
                + SDKProfile::KnownBuild::APlayerControllerNetConnection)
                != Connection)
        {
            SetError("Runtime-admin change refused: controller/connection identity changed");
            return;
        }

        uint8 AdminMask = 0;
        uint8 CheatMask = 0;
        const int32 AdminOffset = PC->GetOffset("bIsAdmin", &AdminMask);
        const int32 CheatOffset = PC->GetOffset("bCheatPlayer", &CheatMask);
        if (AdminOffset != static_cast<int32>(
                SDKProfile::KnownBuild::APlayerControllerAdminFlags)
            || CheatOffset != AdminOffset
            || AdminMask != SDKProfile::KnownBuild::APlayerControllerIsAdminMask
            || CheatMask
                != SDKProfile::KnownBuild::APlayerControllerCheatPlayerMask)
        {
            SetError("Runtime-admin change refused: reflected controller flags mismatch");
            return;
        }

        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Exec)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Protected);
        UFunction* Function = ResolveFunctionCached(CachedSetCheatPlayer,
            "Function ShooterGame.ShooterPlayerController.SetCheatPlayer",
            0x1, 1, Flags);
        if (!Function)
        {
            SetError("Runtime-admin change refused: SetCheatPlayer ABI is unavailable");
            return;
        }

        struct Parameters { uint8 Enable = 0; } Params;
        static_assert(sizeof(Parameters) == 0x1,
                      "SetCheatPlayer parameters mismatch");
        Params.Enable = Enable ? 1 : 0;
        uint8* FlagByte = reinterpret_cast<uint8*>(PC) + AdminOffset;
        const uint8 OriginalFlags = *FlagByte;
        if (Enable)
            *FlagByte |= AdminMask;
        if (!DispatchBaseProcessEvent(PC, Function, &Params))
        {
            *FlagByte = OriginalFlags;
            SetError("Runtime-admin change refused: SetCheatPlayer dispatch was rejected");
            return;
        }
        if (!Enable)
            *FlagByte &= static_cast<uint8>(~AdminMask);

        const bool AdminAfter = (*FlagByte & AdminMask) != 0;
        const bool CheatAfter = (*FlagByte & CheatMask) != 0;
        if (AdminAfter != Enable || CheatAfter != Enable)
        {
            *FlagByte = OriginalFlags;
            SetError("Runtime-admin change failed post-dispatch verification");
            return;
        }
        AddLog(std::string("Runtime admin ")
               + (Enable ? "granted to " : "revoked from ") + StableId
               + " (bIsAdmin=" + (AdminAfter ? "true" : "false")
               + ", bCheatPlayer=" + (CheatAfter ? "true" : "false")
               + ")");
        SetStatus(Enable ? "Runtime admin granted" : "Runtime admin revoked");
    }

    void HostingRuntime::ExecuteAdminCheat(const std::string& StableId,
                                           const std::string& Action)
    {
        static const std::unordered_set<std::string> Whitelist = {
            "fly", "walk", "god", "infinitestats"
        };
        if (Whitelist.find(Action) == Whitelist.end())
        {
            SetError("Player admin action was refused by the fixed whitelist");
            return;
        }
        const auto Record = std::find_if(
            RecoveryRecords.begin(), RecoveryRecords.end(),
            [&StableId](const ClientRecoveryRecord& Candidate)
            {
                return Candidate.StableId == StableId && Candidate.SeenThisScan
                    && Candidate.State != RecoveryState::Disconnected
                    && Candidate.State != RecoveryState::WorldChanged;
            });
        if (Record == RecoveryRecords.end())
        {
            SetError("Player admin action refused: selected identity is stale");
            return;
        }
        UObject* PC = static_cast<UObject*>(ResolveWeakIdentity(
            Record->PlayerController));
        void* Connection = ResolveWeakIdentity(Record->Connection);
        uint8 AdminMask = 0;
        uint8 CheatMask = 0;
        if (!PC || !Connection
            || !IsClassOrSuper(PC, "ShooterPlayerController")
            || PC->GetOffset("NetConnection") != static_cast<int32>(
                SDKProfile::KnownBuild::APlayerControllerNetConnection)
            || ReadPointer(reinterpret_cast<uintptr_t>(PC)
                + SDKProfile::KnownBuild::APlayerControllerNetConnection)
                != Connection
            || PC->GetOffset("bIsAdmin", &AdminMask) != static_cast<int32>(
                SDKProfile::KnownBuild::APlayerControllerAdminFlags)
            || PC->GetOffset("bCheatPlayer", &CheatMask) != static_cast<int32>(
                SDKProfile::KnownBuild::APlayerControllerAdminFlags)
            || AdminMask != SDKProfile::KnownBuild::APlayerControllerIsAdminMask
            || CheatMask
                != SDKProfile::KnownBuild::APlayerControllerCheatPlayerMask)
        {
            SetError("Player admin action refused: controller ownership/layout changed");
            return;
        }
        const uint8 FlagByte = *(reinterpret_cast<const uint8*>(PC)
            + SDKProfile::KnownBuild::APlayerControllerAdminFlags);
        if ((FlagByte & AdminMask) == 0 || (FlagByte & CheatMask) == 0)
        {
            SetError("Player admin action refused: grant runtime admin first");
            return;
        }

        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Exec)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Public);
        UFunction* Function = ResolveFunctionCached(CachedAdminCheat,
            "Function ShooterGame.ShooterPlayerController.AdminCheat",
            0x10, 1, Flags);
        if (!Function)
        {
            SetError("Player admin action refused: AdminCheat ABI is unavailable");
            return;
        }
        struct Parameters { FString Message; };
        static_assert(sizeof(Parameters) == 0x10,
                      "AdminCheat parameters mismatch");
        const std::u16string Wide(Action.begin(), Action.end());
        Parameters Params{FString(Wide.c_str())};
        if (!DispatchBaseProcessEvent(PC, Function, &Params))
        {
            SetError("Player admin action refused: AdminCheat dispatch failed");
            return;
        }
        AddLog("Whitelisted player admin action '" + Action
               + "' dispatched for " + StableId);
        SetStatus("Player admin action dispatched: " + Action);
    }

    void HostingRuntime::ExecuteKick(const std::string& StableId,
                                     const std::string& Reason)
    {
        const auto Record = std::find_if(RecoveryRecords.begin(), RecoveryRecords.end(),
            [&StableId](const ClientRecoveryRecord& Candidate)
            {
                return Candidate.StableId == StableId && Candidate.SeenThisScan
                    && Candidate.State != RecoveryState::Disconnected
                    && Candidate.State != RecoveryState::WorldChanged;
            });
        if (Record == RecoveryRecords.end())
        {
            SetError("Kick refused: selected player identity is stale");
            return;
        }
        UObject* PC = static_cast<UObject*>(ResolveWeakIdentity(Record->PlayerController));
        void* Connection = ResolveWeakIdentity(Record->Connection);
        if (!PC || !Connection || ReadPointer(reinterpret_cast<uintptr_t>(PC)
                + SDKProfile::KnownBuild::APlayerControllerNetConnection) != Connection)
        {
            SetError("Kick refused: controller/connection identity changed");
            return;
        }

        std::string PreKickSave = ExecuteSaveWorld()
            ? "synchronous-world-player-save-returned"
            : "synchronous-save-failed";
        PC = static_cast<UObject*>(ResolveWeakIdentity(Record->PlayerController));
        Connection = ResolveWeakIdentity(Record->Connection);
        if (!PC || !Connection
            || ReadPointer(reinterpret_cast<uintptr_t>(PC)
                + SDKProfile::KnownBuild::APlayerControllerNetConnection)
                != Connection)
        {
            SetError("Kick cancelled after save: controller/connection became stale");
            return;
        }
        UObject* PlayerState = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(PC)
            + SDKProfile::KnownBuild::AControllerPlayerState));
        UObject* PlayerData = LooksLikeUObject(PlayerState)
            && IsClassOrSuper(PlayerState, "ShooterPlayerState")
            && PlayerState->GetOffset("MyPlayerData") == static_cast<int32>(
                SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData)
            ? static_cast<UObject*>(ReadPointer(
                reinterpret_cast<uintptr_t>(PlayerState)
                + SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData))
            : nullptr;
        if (LooksLikeUObject(PlayerData)
            && IsClassOrSuper(PlayerData, "PrimalPlayerData"))
        {
            PlayerSummary Persistence;
            if (PopulatePlayerPersistence(PlayerData, Persistence))
                PreKickSave += ", PlayerDataID="
                    + std::to_string(Persistence.PlayerDataId)
                    + ", identity="
                    + (Persistence.PersistentIdentity
                            == PersistentIdentityResult::Present
                        ? Persistence.PersistentIdentityValue
                        : "not-present");
            else
                PreKickSave += ", identity-layout-unavailable";
        }

        UObject* GameMode = GetAuthorityGameMode();
        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Public)
            | static_cast<uint32>(EFunctionFlags::BlueprintCallable);
        UFunction* Function = ResolveFunctionCached(CachedAdminKick,
            "Function ShooterGame.ShooterGameMode.KickPlayerController",
            0x18, 2, Flags);
        if (!GameMode || !Function || !ValidateProcessEventTarget(GameMode))
        {
            SetError("Kick refused: reflected KickPlayerController ABI is unavailable");
            return;
        }

        struct Parameters { UObject* PlayerController; FString KickMessage; };
        static_assert(sizeof(Parameters) == 0x18,
                      "KickPlayerController parameters mismatch");
        const std::string SafeReason = Reason.empty()
            ? "Removed by local host administrator" : Reason;
        const std::u16string Wide(SafeReason.begin(), SafeReason.end());
        Parameters Params{PC, FString(Wide.c_str())};
        GameMode->ProcessEvent(Function, &Params);
        AddLog("KickPlayerController dispatched for " + StableId
               + " (preKickSave=" + PreKickSave + ")",
               LogLevel::Warning);
        SetStatus("Kick command dispatched");
    }

    void HostingRuntime::ExecuteConsole(const std::string& Command)
    {
        static const std::unordered_set<std::string> Whitelist = {
            "stat net", "stat fps", "stat unit", "stat game", "stat none"
        };
        if (Whitelist.find(Command) == Whitelist.end())
        {
            SetError("Console command refused by local whitelist");
            return;
        }
        void* World = nullptr;
        WeakObjectIdentity WorldIdentity;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            World = HostedWorld;
            WorldIdentity = HostedWorldIdentity;
        }
        if (ResolveWeakIdentity(WorldIdentity) != World)
        {
            SetError("Console command refused: hosted world is stale");
            return;
        }
        if (!ResolveWeakIdentity(MakeWeakIdentity(CachedKismetSystemLibrary)))
            CachedKismetSystemLibrary = UObject::FindObject<UObject>(
                "KismetSystemLibrary Engine.Default__KismetSystemLibrary");
        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Static)
            | static_cast<uint32>(EFunctionFlags::Public)
            | static_cast<uint32>(EFunctionFlags::BlueprintCallable);
        UFunction* Function = ResolveFunctionCached(CachedConsoleCommand,
            "Function Engine.KismetSystemLibrary.ExecuteConsoleCommand",
            0x20, 3, Flags);
        const bool TargetValid = CachedKismetSystemLibrary
            && ValidateProcessEventTarget(CachedKismetSystemLibrary);
        if (!CachedKismetSystemLibrary || !Function || !TargetValid)
        {
            std::string Detail = "Console ABI validation: library=";
            Detail += CachedKismetSystemLibrary ? "found" : "missing";
            Detail += ", function=";
            Detail += Function ? "valid" : "missing/rejected";
            Detail += ", ProcessEventTarget=";
            Detail += TargetValid ? "valid" : "rejected";
            if (CachedKismetSystemLibrary)
            {
                const FUObjectItem* Item = UObject::GUObjectArray
                    ? UObject::GUObjectArray->ObjObjects.IndexToObject(
                        CachedKismetSystemLibrary->InternalIndex)
                    : nullptr;
                Detail += ", CDO=";
                Detail += CachedKismetSystemLibrary->IsDefaultObject()
                    ? "true" : "false";
                Detail += ", serial="
                    + std::to_string(Item ? Item->SerialNumber : -1);
            }
            AddLog(Detail, LogLevel::Debug);
            SetError("Console command refused: reflected ABI is unavailable");
            return;
        }
        struct Parameters
        {
            UObject* WorldContextObject;
            FString Command;
            UObject* SpecificPlayer;
        };
        static_assert(sizeof(Parameters) == 0x20,
                      "ExecuteConsoleCommand parameters mismatch");
        const std::u16string Wide(Command.begin(), Command.end());
        Parameters Params{static_cast<UObject*>(World), FString(Wide.c_str()), nullptr};
        CachedKismetSystemLibrary->ProcessEvent(Function, &Params);
        AddLog("Whitelisted local console command executed: " + Command,
               LogLevel::Debug);
        SetStatus("Console command executed");
    }

#if SERVERHOST_DEVELOPER_UI
    void HostingRuntime::ExecuteDeveloperProcessEventExample()
    {
        // Developer ProcessEvent template.
        //
        // Keep the full reflected name, parameter layout, ParmsSize/NumParms
        // and required flags in sync with the SDK entry you choose. This
        // example deliberately calls the harmless static IsValid(World)
        // function; it does not intercept or replace another call's result.
        static constexpr const char* FunctionName =
            "Function Engine.KismetSystemLibrary.IsValid";

        struct Parameters
        {
            const UObject* Object;
            bool ReturnValue;
            uint8 Padding[7];
        };
        static_assert(sizeof(Parameters) == 0x10,
                      "KismetSystemLibrary.IsValid parameters mismatch");

        struct PendingReset
        {
            std::atomic<bool>& Pending;
            ~PendingReset() { Pending.store(false, std::memory_order_release); }
        } Reset{DeveloperProcessEventExamplePending};

        if (!IsOnGameThread())
        {
            SetError("Developer ProcessEvent example refused outside the game thread");
            return;
        }

        void* World = nullptr;
        WeakObjectIdentity WorldIdentity;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            World = CachedWorld;
            WorldIdentity = CachedWorldIdentity;
        }
        if (ResolveWeakIdentity(WorldIdentity) != World || !LooksLikeUObject(World))
        {
            SetError("Developer ProcessEvent example refused: current world is stale");
            return;
        }

        if (!ResolveWeakIdentity(MakeWeakIdentity(CachedKismetSystemLibrary)))
        {
            CachedKismetSystemLibrary = UObject::FindObject<UObject>(
                "KismetSystemLibrary Engine.Default__KismetSystemLibrary");
        }

        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Static)
            | static_cast<uint32>(EFunctionFlags::Public)
            | static_cast<uint32>(EFunctionFlags::BlueprintCallable)
            | static_cast<uint32>(EFunctionFlags::BlueprintPure);
        UFunction* ObservedFunction = UObject::FindObject<UFunction>(
            FunctionName, EClassCastFlags::Function);
        UFunction* Function = ResolveFunctionCached(
            CachedDeveloperProcessEventExample, FunctionName, 0x10, 2, Flags);
        const bool TargetValid = CachedKismetSystemLibrary
            && ValidateProcessEventTarget(CachedKismetSystemLibrary);
        if (!CachedKismetSystemLibrary || !Function || !TargetValid)
        {
            std::ostringstream Detail;
            Detail << "Developer ProcessEvent example ABI: library="
                   << (CachedKismetSystemLibrary ? "found" : "missing")
                   << ", target=" << (TargetValid ? "valid" : "rejected")
                   << ", function=" << (ObservedFunction ? "found" : "missing");
            if (ObservedFunction)
            {
                Detail << ", ParmsSize=0x" << std::hex
                       << ObservedFunction->ParmsSize << std::dec
                       << ", NumParms="
                       << static_cast<int32>(ObservedFunction->NumParms)
                       << ", flags=0x" << std::hex
                       << static_cast<uint32>(ObservedFunction->FunctionFlags)
                       << std::dec;
            }
            AddLog(Detail.str(), LogLevel::Debug);
            SetError("Developer ProcessEvent example refused: reflected ABI is unavailable");
            return;
        }

        Parameters Params{static_cast<UObject*>(World), false, {}};
        if (!DispatchBaseProcessEvent(CachedKismetSystemLibrary, Function,
                                      &Params))
        {
            SetError("Developer ProcessEvent example refused: synchronous base ProcessEvent validation failed");
            return;
        }

        AddLog(std::string("Developer ProcessEvent example completed once: ")
               + FunctionName + ", ReturnValue="
               + (Params.ReturnValue ? "true" : "false"),
               LogLevel::Debug);
        SetStatus("Developer ProcessEvent example completed");
    }

    void HostingRuntime::ExecuteDeveloperHarvestProbe(
        const std::string& StableId)
    {
        // Differential, read-only late-listen diagnostics. This calls the
        // exact ShooterGame query used by the server harvest path; it does not
        // wake actors, insert viewpoints, load levels or change net mode.
        struct PendingReset
        {
            std::atomic<bool>& Pending;
            ~PendingReset() { Pending.store(false, std::memory_order_release); }
        } Reset{DeveloperHarvestProbePending};

        if (!IsOnGameThread())
        {
            SetError("Harvest probe refused outside the game thread");
            return;
        }

        void* World = nullptr;
        void* Driver = nullptr;
        WeakObjectIdentity WorldIdentity;
        WeakObjectIdentity DriverIdentity;
        WeakObjectIdentity ConnectionIdentity;
        WeakObjectIdentity ControllerIdentity;
        bool HostActive = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            HostActive = Hosting;
            World = HostedWorld;
            Driver = HostedNetDriver;
            WorldIdentity = HostedWorldIdentity;
            DriverIdentity = HostedNetDriverIdentity;
            const auto Record = std::find_if(RecoveryRecords.begin(),
                RecoveryRecords.end(), [&](const ClientRecoveryRecord& Candidate)
                {
                    return Candidate.StableId == StableId
                        && Candidate.State != RecoveryState::Disconnected
                        && Candidate.State != RecoveryState::WorldChanged;
                });
            if (Record != RecoveryRecords.end())
            {
                ConnectionIdentity = Record->Connection;
                ControllerIdentity = Record->PlayerController;
            }
        }
        if (!HostActive)
        {
            SetError("Harvest probe requires an active local host");
            return;
        }

        void* Connection = ResolveWeakIdentity(ConnectionIdentity);
        UObject* PC = static_cast<UObject*>(ResolveWeakIdentity(ControllerIdentity));
        if (ResolveWeakIdentity(WorldIdentity) != World
            || ResolveWeakIdentity(DriverIdentity) != Driver
            || !LooksLikeUObject(World) || !LooksLikeUObject(Driver)
            || !LooksLikeUObject(Connection) || !LooksLikeUObject(PC)
            || !IsClassOrSuper(PC, "ShooterPlayerController")
            || ReadPointer(reinterpret_cast<uintptr_t>(World)
                + SDKProfile::KnownBuild::UWorldNetDriver) != Driver
            || ReadPointer(reinterpret_cast<uintptr_t>(Driver)
                + SDKProfile::KnownBuild::UNetDriverWorld) != World
            || ReadPointer(reinterpret_cast<uintptr_t>(Connection)
                + SDKProfile::KnownBuild::UNetConnectionDriver) != Driver
            || ReadPointer(reinterpret_cast<uintptr_t>(Connection)
                + SDKProfile::KnownBuild::UPlayerPlayerController) != PC
            || ReadPointer(reinterpret_cast<uintptr_t>(PC)
                + SDKProfile::KnownBuild::APlayerControllerNetConnection)
                != Connection)
        {
            SetError("Harvest probe refused: selected connection/controller is stale");
            return;
        }

        UObject* Pawn = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(PC)
            + SDKProfile::KnownBuild::AControllerPawn));
        if (!LooksLikeUObject(Pawn)
            || !IsClassOrSuper(Pawn, "PrimalCharacter"))
        {
            SetError("Harvest probe refused: selected player has no live PrimalCharacter Pawn");
            return;
        }

        constexpr uint32 Flags = static_cast<uint32>(EFunctionFlags::Final)
            | static_cast<uint32>(EFunctionFlags::Native)
            | static_cast<uint32>(EFunctionFlags::Public)
            | static_cast<uint32>(EFunctionFlags::HasOutParms)
            | static_cast<uint32>(EFunctionFlags::BlueprintCallable);
        UFunction* Function = ResolveFunctionCached(CachedDeveloperHarvestProbe,
            "Function ShooterGame.ShooterPlayerController.GetAllAimedHarvestActors",
            0x40, 5, Flags);
        if (!Function || !ValidateProcessEventTarget(PC))
        {
            SetError("Harvest probe refused: reflected query ABI is unavailable");
            return;
        }

        struct Parameters
        {
            float MaxDistance = 500.0f;
            uint8 Pad04[4]{};
            ArrayHeader HarvestActors;
            ArrayHeader HarvestComponents;
            ArrayHeader HitBodyIndices;
            uint8 ReturnValue = 0;
            uint8 Pad39[7]{};
        } Params;
        static_assert(sizeof(Parameters) == 0x40,
                      "GetAllAimedHarvestActors parameters mismatch");

        PC->ProcessEvent(Function, &Params);

        const auto ArrayShapeValid = [](const ArrayHeader& Values,
                                        int32 Limit, std::size_t ElementSize)
        {
            if (Values.Num < 0 || Values.Max < Values.Num
                || Values.Max > Limit || ElementSize == 0)
                return false;
            if (!Values.Data)
                return Values.Num == 0 && Values.Max == 0;
            if (Values.Max <= 0)
                return false;
            const uintptr_t First = reinterpret_cast<uintptr_t>(Values.Data);
            if (!CanReadMemoryRange(First, 1))
                return false;
            if (Values.Num == 0)
                return true;
            const std::size_t UsedSize = static_cast<std::size_t>(Values.Num)
                * ElementSize;
            return CanReadMemoryRange(First, UsedSize);
        };
        const bool ActorArrayValid = ArrayShapeValid(
            Params.HarvestActors, 256, sizeof(UObject*));
        const bool ComponentArrayValid = ArrayShapeValid(
            Params.HarvestComponents, 256, sizeof(UObject*));
        const bool BodyArrayValid = ArrayShapeValid(
            Params.HitBodyIndices, 256, sizeof(int32));

        UObject* PersistentLevel = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UWorldPersistentLevel));
        UObject* WorldSettings = LooksLikeUObject(PersistentLevel)
            ? static_cast<UObject*>(ReadPointer(
                reinterpret_cast<uintptr_t>(PersistentLevel)
                + SDKProfile::KnownBuild::ULevelWorldSettings))
            : nullptr;
        const bool StasisLayout = LooksLikeUObject(WorldSettings)
            && IsClassOrSuper(WorldSettings, "BasePrimalWorldSettings");

        float BaseStasisDistance = 0.0f;
        int32 ViewpointCount = -1;
        int32 ViewpointSourceCount = -1;
        bool RemoteControllerIsSource = false;
        bool RemotePawnInTimestampMap = false;
        bool HostPawnInTimestampMap = false;
        UObject* LocalHostController = nullptr;
        UObject* LocalHostPawn = nullptr;
        double RemotePawnTimestampAge = -1.0;
        std::string FirstViewpointSources;
        std::string FirstTimestampKeys;
        if (StasisLayout)
        {
            BaseStasisDistance = Memory::GetInstance().Read<float>(
                reinterpret_cast<uintptr_t>(WorldSettings)
                + SDKProfile::KnownBuild::ABasePrimalWorldSettingsBaseNetStasisDistance);
            const uintptr_t SourcesAddress = reinterpret_cast<uintptr_t>(WorldSettings)
                + SDKProfile::KnownBuild::ABasePrimalWorldSettingsUnstasisViewpointControllers;
            const ArrayHeader Sources = Memory::GetInstance().Read<ArrayHeader>(
                SourcesAddress);
            const bool SourcesValid = CanReadMemoryRange(
                    SourcesAddress, sizeof(ArrayHeader))
                && Sources.Num >= 0 && Sources.Num <= 128
                && Sources.Max >= Sources.Num && Sources.Max <= 128
                && ((Sources.Num == 0 && (!Sources.Data || Sources.Max == 0))
                    || (Sources.Data && CanReadMemoryRange(
                        reinterpret_cast<uintptr_t>(Sources.Data),
                        static_cast<std::size_t>(std::max(Sources.Num, 1))
                            * sizeof(void*))));
            if (SourcesValid)
            {
                ViewpointSourceCount = Sources.Num;
                std::ostringstream SourceList;
                const int32 Listed = std::min<int32>(Sources.Num, 4);
                for (int32 Index = 0; Index < Sources.Num; ++Index)
                {
                    UObject* Candidate = static_cast<UObject*>(ReadPointer(
                        reinterpret_cast<uintptr_t>(Sources.Data)
                        + static_cast<uintptr_t>(Index) * sizeof(void*)));
                    if (Candidate == PC)
                        RemoteControllerIsSource = true;
                    if (LooksLikeUObject(Candidate)
                        && IsClassOrSuper(Candidate, "ShooterPlayerController"))
                    {
                        UObject* CandidatePawn = static_cast<UObject*>(ReadPointer(
                            reinterpret_cast<uintptr_t>(Candidate)
                            + SDKProfile::KnownBuild::AControllerPawn));
                        void* CandidateConnection = ReadPointer(
                            reinterpret_cast<uintptr_t>(Candidate)
                            + SDKProfile::KnownBuild::APlayerControllerNetConnection);
                        if (Candidate != PC && !CandidateConnection
                            && LooksLikeUObject(CandidatePawn)
                            && IsClassOrSuper(CandidatePawn, "PrimalCharacter"))
                        {
                            LocalHostController = Candidate;
                            LocalHostPawn = CandidatePawn;
                        }
                    }
                    if (Index < Listed)
                    {
                        if (Index) SourceList << "; ";
                        SourceList << DescribeObject(Candidate);
                    }
                }
                FirstViewpointSources = SourceList.str();
            }

            const uintptr_t Viewpoints = reinterpret_cast<uintptr_t>(WorldSettings)
                + SDKProfile::KnownBuild::ABasePrimalWorldSettingsPlayerCharacterUnstasisViewpoints;
            // Exact UE TMap<AActor*, double> layout: sparse element stride 24,
            // allocation bits at +0x10/+0x20, and free count at +0x34.
            const int32 Allocated = Memory::GetInstance().Read<int32>(
                Viewpoints + 0x8);
            const int32 MaxAllocated = Memory::GetInstance().Read<int32>(
                Viewpoints + 0xC);
            const int32 Free = Memory::GetInstance().Read<int32>(
                Viewpoints + 0x34);
            const int32 FlagBits = Memory::GetInstance().Read<int32>(
                Viewpoints + 0x28);
            const int32 MaxFlagBits = Memory::GetInstance().Read<int32>(
                Viewpoints + 0x2C);
            void* MapData = ReadPointer(Viewpoints);
            void* SecondaryFlags = ReadPointer(Viewpoints + 0x20);
            const uintptr_t FlagData = SecondaryFlags
                ? reinterpret_cast<uintptr_t>(SecondaryFlags)
                : Viewpoints + 0x10;
            const std::size_t FlagBytes = static_cast<std::size_t>(
                (std::max(FlagBits, 0) + 31) / 32) * sizeof(uint32);
            const bool MapShapeValid = CanReadMemoryRange(Viewpoints, 0x50)
                && Allocated >= 0 && Allocated <= 128
                && MaxAllocated >= Allocated && MaxAllocated <= 128
                && Free >= 0 && Free <= Allocated
                && FlagBits == Allocated && MaxFlagBits >= FlagBits
                && MaxFlagBits <= 128
                && ((Allocated == 0 && (!MapData || MaxAllocated == 0))
                    || (MapData && CanReadMemoryRange(
                        reinterpret_cast<uintptr_t>(MapData),
                        static_cast<std::size_t>(std::max(Allocated, 1)) * 24)))
                && (FlagBytes == 0 || CanReadMemoryRange(FlagData, FlagBytes));
            if (MapShapeValid)
            {
                ViewpointCount = Allocated - Free;
                const double TimestampClock = Memory::GetInstance().Read<double>(
                    reinterpret_cast<uintptr_t>(World)
                    + SDKProfile::KnownBuild::UWorldUnstasisTimestampClock);
                std::ostringstream KeyList;
                int32 ListedKeys = 0;
                for (int32 Index = 0; Index < Allocated; ++Index)
                {
                    const uint32 Word = Memory::GetInstance().Read<uint32>(
                        FlagData + static_cast<uintptr_t>(Index / 32)
                            * sizeof(uint32));
                    if ((Word & (uint32{1} << (Index % 32))) == 0)
                        continue;
                    const uintptr_t Slot = reinterpret_cast<uintptr_t>(MapData)
                        + static_cast<uintptr_t>(Index) * 24;
                    if (!CanReadMemoryRange(Slot, 16))
                        continue;
                    UObject* Key = static_cast<UObject*>(ReadPointer(Slot));
                    const double Timestamp = Memory::GetInstance().Read<double>(
                        Slot + 8);
                    if (Key == Pawn)
                    {
                        RemotePawnInTimestampMap = true;
                        if (std::isfinite(TimestampClock)
                            && std::isfinite(Timestamp))
                            RemotePawnTimestampAge = TimestampClock - Timestamp;
                    }
                    if (Key == LocalHostPawn)
                        HostPawnInTimestampMap = true;
                    if (ListedKeys < 4)
                    {
                        if (ListedKeys) KeyList << "; ";
                        KeyList << DescribeObject(Key);
                        ++ListedKeys;
                    }
                }
                FirstTimestampKeys = KeyList.str();
            }
        }

        const uintptr_t PawnAddress = reinterpret_cast<uintptr_t>(Pawn);
        const uint8 AutoFlags = Memory::GetInstance().Read<uint8>(PawnAddress
            + SDKProfile::KnownBuild::UPrimalActorAutoStasisFlags);
        const uint8 StasisFlags = Memory::GetInstance().Read<uint8>(PawnAddress
            + SDKProfile::KnownBuild::UPrimalActorStasisFlags);
        const uint8 GridFlags = Memory::GetInstance().Read<uint8>(PawnAddress
            + SDKProfile::KnownBuild::UPrimalActorUseStasisGridFlags);
        const float PawnRangeMultiplier = Memory::GetInstance().Read<float>(
            PawnAddress
            + SDKProfile::KnownBuild::UPrimalActorNetworkAndStasisRangeMultiplier);

        float TetherMultiplier = 0.0f;
        UObject* GameState = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UWorldGameState));
        const bool GameStateLayout = LooksLikeUObject(GameState)
            && IsClassOrSuper(GameState, "ShooterGameState");
        if (GameStateLayout)
            TetherMultiplier = Memory::GetInstance().Read<float>(
                reinterpret_cast<uintptr_t>(GameState)
                + SDKProfile::KnownBuild::AShooterGameStateListenServerTetherDistanceMultiplier);
        const int32 WorldFrame = Memory::GetInstance().Read<int32>(
            reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UPrimalWorldFrameCounter);
        const int32 RemoteUnstasisFrame = Memory::GetInstance().Read<int32>(
            reinterpret_cast<uintptr_t>(PC)
            + SDKProfile::KnownBuild::AShooterPlayerControllerLastValidUnstasisCasterFrame);
        const int64 RemoteFrameAge = static_cast<int64>(WorldFrame)
            - static_cast<int64>(RemoteUnstasisFrame);

        std::ostringstream Result;
        Result << std::fixed << std::setprecision(2)
               << "Harvest probe " << StableId
               << ": query=" << (Params.ReturnValue ? "true" : "false")
               << ", maxDistance=" << Params.MaxDistance
               << ", actors=" << (ActorArrayValid
                    ? std::to_string(Params.HarvestActors.Num) : "invalid")
               << ", components=" << (ComponentArrayValid
                    ? std::to_string(Params.HarvestComponents.Num) : "invalid")
               << ", bodies=" << (BodyArrayValid
                    ? std::to_string(Params.HitBodyIndices.Num) : "invalid")
               << ", Pawn=" << DescribeObject(Pawn)
               << ", stasis={base="
               << (StasisLayout && std::isfinite(BaseStasisDistance)
                    ? std::to_string(BaseStasisDistance) : "unavailable")
               << ", sources=" << (ViewpointSourceCount >= 0
                    ? std::to_string(ViewpointSourceCount) : "unavailable")
               << ", remotePCSource="
               << (RemoteControllerIsSource ? "true" : "false")
               << ", localHostPC=" << DescribeObject(LocalHostController)
               << ", viewpoints=" << (ViewpointCount >= 0
                    ? std::to_string(ViewpointCount) : "unavailable")
               << ", remotePawnTimestamp="
               << (RemotePawnInTimestampMap ? "present" : "missing")
               << ", remoteTimestampAge="
               << (RemotePawnTimestampAge >= 0.0
                    && std::isfinite(RemotePawnTimestampAge)
                    ? std::to_string(RemotePawnTimestampAge) : "unavailable")
               << ", hostPawnTimestamp="
               << (LocalHostPawn
                    ? (HostPawnInTimestampMap ? "present" : "missing")
                    : "unavailable")
               << ", worldFrame=" << WorldFrame
               << ", remoteUnstasisFrame=" << RemoteUnstasisFrame
               << ", remoteFrameAge=" << RemoteFrameAge
               << ", auto=" << ((AutoFlags & 0x80) ? "true" : "false")
               << ", stasised=" << ((StasisFlags & 0x08) ? "true" : "false")
               << ", prevent=" << ((StasisFlags & 0x10) ? "true" : "false")
               << ", grid=" << ((GridFlags & 0x20) ? "true" : "false")
               << ", pawnRange=" << (std::isfinite(PawnRangeMultiplier)
                    ? std::to_string(PawnRangeMultiplier) : "unavailable")
               << ", tether=" << (GameStateLayout
                    && std::isfinite(TetherMultiplier)
                    ? std::to_string(TetherMultiplier) : "unavailable")
               << "}";
        if (ActorArrayValid && Params.HarvestActors.Num > 0)
        {
            Result << ", firstActors={";
            const int32 Count = std::min<int32>(Params.HarvestActors.Num, 4);
            for (int32 Index = 0; Index < Count; ++Index)
            {
                if (Index) Result << "; ";
                Result << DescribeObject(ReadPointer(
                    reinterpret_cast<uintptr_t>(Params.HarvestActors.Data)
                    + static_cast<uintptr_t>(Index) * sizeof(void*)));
            }
            Result << "}";
        }
        if (!FirstViewpointSources.empty())
            Result << ", firstSources={" << FirstViewpointSources << "}";
        if (!FirstTimestampKeys.empty())
            Result << ", firstTimestampKeys={" << FirstTimestampKeys << "}";
        AddLog(Result.str(), (ActorArrayValid && ComponentArrayValid
            && BodyArrayValid) ? LogLevel::Debug : LogLevel::Warning);

        // ProcessEvent owns only the call; these out arrays are returned to
        // the caller. Free with UE's allocator only after the complete header
        // shape and allocation base were validated. A malformed diagnostic
        // result is intentionally leaked rather than freeing an untrusted
        // pointer and turning evidence collection into a crash.
        const auto ReleaseValidated = [](ArrayHeader& Values, bool Valid)
        {
            if (Valid && Values.Data && FMemory::EngineRealloc
                && CanReadMemoryRange(
                    reinterpret_cast<uintptr_t>(Values.Data), 1))
                FMemory::Free(Values.Data);
            Values = {};
        };
        ReleaseValidated(Params.HarvestActors, ActorArrayValid);
        ReleaseValidated(Params.HarvestComponents, ComponentArrayValid);
        ReleaseValidated(Params.HitBodyIndices, BodyArrayValid);
        SetStatus("Read-only harvest/stasis probe completed");
    }
#endif

    void HostingRuntime::ExecuteStop()
    {
        UEngine* Engine = nullptr;
        UWorld* World = nullptr;
        UNetDriver* Driver = nullptr;
        WeakObjectIdentity WorldIdentity;
        WeakObjectIdentity DriverIdentity;
        bool CanStop = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            Engine = CachedEngine;
            World = HostedWorld;
            Driver = HostedNetDriver;
            WorldIdentity = HostedWorldIdentity;
            DriverIdentity = HostedNetDriverIdentity;
            CanStop = CurrentRole == Role::Host && Hosting
                && !ListenAttemptInProgress && DestroyNamedNetDriver;
            if (CanStop)
                HostState = HostLifecycleState::Stopping;
        }
        if (!CanStop)
        {
            SetError("Stop is unavailable for the current host lifecycle state");
            return;
        }
        if (!ValidateLiveEngine(Engine)
            || ResolveWeakIdentity(WorldIdentity) != World
            || ResolveWeakIdentity(DriverIdentity) != Driver
            || ReadPointer(reinterpret_cast<uintptr_t>(World)
                + SDKProfile::KnownBuild::UWorldNetDriver) != Driver
            || ReadPointer(reinterpret_cast<uintptr_t>(Driver)
                + SDKProfile::KnownBuild::UNetDriverWorld) != World)
        {
            SetError("Stop refused: hosted Engine/World/NetDriver ownership is stale");
            std::lock_guard<std::mutex> Guard(Mutex);
            HostState = HostLifecycleState::Failed;
            return;
        }

        // Stop is network lifecycle only; saving is dispatched first through
        // the confirmed ShooterGame function. The world remains loaded after
        // DestroyNamedNetDriver.
        if (!ExecuteSaveWorld())
        {
            SetError("Stop refused because the pre-stop world save was not dispatched");
            std::lock_guard<std::mutex> Guard(Mutex);
            HostState = HostLifecycleState::Listening;
            return;
        }
        FName DriverName;
        if (!MakeName(GameNetDriverName, DriverName))
        {
            SetError("Stop refused: GameNetDriver FName validation failed");
            std::lock_guard<std::mutex> Guard(Mutex);
            HostState = HostLifecycleState::Listening;
            return;
        }

        AddLog("Calling UEngine::DestroyNamedNetDriver for GameNetDriver");
        DestroyNamedNetDriver(Engine, World, DriverName);
        const bool Destroyed = ReadPointer(reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UWorldNetDriver) == nullptr;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (Destroyed)
            {
                Hosting = false;
                HostedWorld = nullptr;
                HostedNetDriver = nullptr;
                HostedWorldIdentity = {};
                HostedNetDriverIdentity = {};
                HostPending = false;
                ListenAttemptInProgress = false;
                HostState = HostLifecycleState::Stopped;
                Status = "Server stopped; world remains loaded";
                LastError.clear();
                Password.clear();
                BoundPort = 0;
                ArkLoginBypassApplied = false;
                ArkLoginBypassWorld = nullptr;
                PlayerSummaries.clear();
                ConnectedClients = 0;
                GameplayReadyClients = 0;
                ArkLoginLockedClients = 0;
            }
            else
            {
                HostState = HostLifecycleState::Failed;
                Status = "Stop failed: World still owns GameNetDriver";
                LastError = Status;
            }
        }
        if (Destroyed)
        {
            HotHostedNetDriver.store(nullptr, std::memory_order_release);
            HotHosting.store(false, std::memory_order_release);
            for (ClientRecoveryRecord& Record : RecoveryRecords)
                TransitionRecovery(Record, RecoveryState::Disconnected);
            RecoveryRecords.clear();
            ResetWorldDependentCaches();
        }
        AddLog(Destroyed ? "GameNetDriver destroyed and postcondition confirmed"
                         : "DestroyNamedNetDriver returned but NetDriver is still attached",
               Destroyed ? LogLevel::Info : LogLevel::Error);
    }

    void HostingRuntime::OnEngineInit(UEngine* Engine)
    {
        if (!Engine)
            return;

        std::string Identity;
        if (!ValidateLiveEngine(Engine, &Identity))
        {
            AddLog("UEngine::Init argument rejected (not a live Transient.ShooterEngine): "
                   + Identity + " @ "
                   + HexAddress(reinterpret_cast<uintptr_t>(Engine)));
            return;
        }

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            CachedEngine = Engine;
            EngineIdentity = Identity;
        }

        AddLog("UEngine::Init captured live Engine "
               + HexAddress(reinterpret_cast<uintptr_t>(Engine)) + ": " + Identity);

        PatchNetDriverDefinitions(Engine);
    }

    void HostingRuntime::OnWorldBeginPlay(UWorld* World)
    {
        if (!World)
            return;

        UWorld* PreviousWorld = nullptr;
        WeakObjectIdentity PreviousIdentity;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            PreviousWorld = CachedWorld;
            PreviousIdentity = CachedWorldIdentity;
        }
        const WeakObjectIdentity NewIdentity = MakeWeakIdentity(World);
        if (PreviousIdentity.IsSet() && !SameIdentity(PreviousIdentity, NewIdentity))
            HandleWorldChanged(PreviousWorld, World);

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            CachedWorld = World;
            CachedWorldIdentity = NewIdentity;
        }

        AddLog("UWorld::BeginPlay captured World "
               + HexAddress(reinterpret_cast<uintptr_t>(World)));

        // Do not call Listen from inside BeginPlay. Tick validates that this is
        // still the live GWorld and performs one explicit attempt.
    }

    bool HostingRuntime::RouteHostedPostLogin(UObject* GameMode,
                                               UObject* PlayerController)
    {
        if (!IsOnGameThread() || !KnownProfileEligible
            || !ShooterGameModeRealPostLogin
            || !LooksLikeUObject(GameMode)
            || !LooksLikeUObject(PlayerController)
            || GameMode->IsDefaultObject() || PlayerController->IsDefaultObject()
            || !IsClassOrSuper(GameMode, "ShooterGameMode")
            || !IsClassOrSuper(PlayerController, "ShooterPlayerController"))
            return false;

        UWorld* ExpectedWorld = nullptr;
        UNetDriver* ExpectedDriver = nullptr;
        WeakObjectIdentity ExpectedWorldIdentity;
        WeakObjectIdentity ExpectedDriverIdentity;
        bool ShouldRoute = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ExpectedWorld = HostedWorld;
            ExpectedDriver = HostedNetDriver;
            ExpectedWorldIdentity = HostedWorldIdentity;
            ExpectedDriverIdentity = HostedNetDriverIdentity;
            ShouldRoute = CurrentRole == Role::Host && Hosting
                && HostState != HostLifecycleState::Stopping
                && HostState != HostLifecycleState::Stopped
                && HostState != HostLifecycleState::Failed;
        }
        if (!ShouldRoute || ResolveWeakIdentity(ExpectedWorldIdentity) != ExpectedWorld
            || ResolveWeakIdentity(ExpectedDriverIdentity) != ExpectedDriver
            || GetAuthorityGameMode() != GameMode
            || ReadPointer(reinterpret_cast<uintptr_t>(ExpectedWorld)
                + SDKProfile::KnownBuild::UWorldNetDriver) != ExpectedDriver)
            return false;

        const uintptr_t ImageBase = Memory::GetInstance().GetImageBase(
            Config::ImageName);
        const uintptr_t ExpectedStartNewPlayer = ImageBase
            + SDKProfile::KnownBuild::ShooterGameModeStartNewPlayer;
        const std::size_t StartNewPlayerSlot =
            SDKProfile::KnownBuild::ShooterGameModeStartNewPlayerVTableOffset
            / sizeof(void*);
        if (!ImageBase || !GameMode->VTable
            || reinterpret_cast<uintptr_t>(GameMode->VTable[StartNewPlayerSlot])
                != ExpectedStartNewPlayer)
        {
            SetError("Hosted PostLogin routing refused: StartNewPlayer vtable slot mismatch");
            return false;
        }

        uint8 WaitingMask = 0;
        if (PlayerController->GetOffset("NetConnection") != static_cast<int32>(
                SDKProfile::KnownBuild::APlayerControllerNetConnection)
            || PlayerController->GetOffset("bPlayerIsWaiting", &WaitingMask)
                != static_cast<int32>(SDKProfile::KnownBuild::
                    APlayerControllerPlayerIsWaiting)
            || WaitingMask == 0)
        {
            SetError("Hosted PostLogin routing refused: remote controller layout mismatch");
            return false;
        }
        UObject* Connection = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(PlayerController)
            + SDKProfile::KnownBuild::APlayerControllerNetConnection));
        if (!LooksLikeUObject(Connection)
            || Connection->GetOffset("Driver") != static_cast<int32>(
                SDKProfile::KnownBuild::UNetConnectionDriver)
            || Connection->GetOffset("PlayerController") != static_cast<int32>(
                SDKProfile::KnownBuild::UPlayerPlayerController)
            || ReadPointer(reinterpret_cast<uintptr_t>(Connection)
                + SDKProfile::KnownBuild::UNetConnectionDriver) != ExpectedDriver
            || ReadPointer(reinterpret_cast<uintptr_t>(Connection)
                + SDKProfile::KnownBuild::UPlayerPlayerController)
                != PlayerController)
        {
            // A local host controller has no remote NetConnection and must
            // always continue through ShooterGame's original PostLogin path.
            return false;
        }

        const WeakObjectIdentity ConnectionIdentity = MakeWeakIdentity(Connection);
        const WeakObjectIdentity ControllerIdentity = MakeWeakIdentity(
            PlayerController);
        if (!ConnectionIdentity.IsSet() || !ControllerIdentity.IsSet())
        {
            SetError("Hosted PostLogin routing refused: remote weak identity is unavailable");
            return false;
        }

        AddLog("Late-listen PostLogin: routing remote controller through "
               "ShooterGame RealPostLogin -> StartNewPlayer persistence flow");
        ShooterGameModeRealPostLogin(GameMode, PlayerController);

        const auto Now = std::chrono::steady_clock::now();
        auto Existing = std::find_if(RecoveryRecords.begin(), RecoveryRecords.end(),
            [this, &ConnectionIdentity](const ClientRecoveryRecord& Candidate)
            { return SameIdentity(Candidate.Connection, ConnectionIdentity); });
        if (Existing == RecoveryRecords.end())
        {
            ClientRecoveryRecord NewRecord;
            NewRecord.Connection = ConnectionIdentity;
            NewRecord.PlayerController = ControllerIdentity;
            NewRecord.DiscoveredAt = Now;
            NewRecord.StateChangedAt = Now;
            NewRecord.SeenThisScan = true;
            RecoveryRecords.push_back(std::move(NewRecord));
            Existing = std::prev(RecoveryRecords.end());
        }
        Existing->PlayerController = ControllerIdentity;
        Existing->NativePostLoginRouted = true;
        Existing->NativePostLoginAt = Now;
        Existing->StableId = "c"
            + std::to_string(ConnectionIdentity.ObjectIndex) + ":"
            + std::to_string(ConnectionIdentity.SerialNumber) + "/p"
            + std::to_string(ControllerIdentity.ObjectIndex) + ":"
            + std::to_string(ControllerIdentity.SerialNumber);
        AddLog("Late-listen RealPostLogin returned for " + Existing->StableId
               + "; automatic RPC recovery is held while player-data load resolves");
        return true;
    }

    void HostingRuntime::ResetWorldDependentCaches()
    {
        CachedHUDRecoveryRPC = nullptr;
        CachedCharacterRecoveryRPC = nullptr;
        CachedQuitToMainMenu = nullptr;
        CachedHUDBaseClass = nullptr;
        CachedSendServerChatMessage = nullptr;
        CachedSetCheatPlayer = nullptr;
        CachedAdminCheat = nullptr;
        CachedAdminKick = nullptr;
        CachedPlayerStateUniqueId = nullptr;
        CachedPlayerHasArkPass = nullptr;
        CachedPlayerDataUniqueId = nullptr;
        CachedConsoleCommand = nullptr;
#if SERVERHOST_DEVELOPER_UI
        CachedDeveloperProcessEventExample = nullptr;
        CachedDeveloperHarvestProbe = nullptr;
#endif
        CachedKismetSystemLibrary = nullptr;
    }

    void HostingRuntime::HandleWorldChanged(UWorld* PreviousWorld,
                                            UWorld* NewWorld)
    {
        const std::string NewWorldName = LooksLikeUObject(NewWorld)
            ? static_cast<UObject*>(NewWorld)->NamePrivate.ToString()
            : std::string{};
        const bool NewWorldIsMainMenu = NewWorldName == "MainMenu"
            || NewWorldName.rfind("MainMenu_", 0) == 0;
        for (ClientRecoveryRecord& Record : RecoveryRecords)
            TransitionRecovery(Record, RecoveryState::WorldChanged);
        RecoveryRecords.clear();
        ResetWorldDependentCaches();

        bool ClearedHostedState = false;
        bool CompletedClientReturn = false;
        bool ClientReturnWasPending = false;
        bool IntermediateClientReturnWorld = false;
        bool HostEndedInMainMenu = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ClearedHostedState = HostedWorld != nullptr;
            if (ClearedHostedState)
            {
                Hosting = false;
                HostPending = false;
                ListenAttemptInProgress = false;
                HostedWorld = nullptr;
                HostedNetDriver = nullptr;
                HostedWorldIdentity = {};
                HostedNetDriverIdentity = {};
                HostState = HostLifecycleState::Stopped;
                Password.clear();
                BoundPort = 0;
                ArkLoginBypassApplied = false;
                ArkLoginBypassWorld = nullptr;
                if (NewWorldIsMainMenu && CurrentRole == Role::Host)
                {
                    HostEndedInMainMenu = true;
                    CurrentRole = Role::Disabled;
                    HostState = HostLifecycleState::Ready;
                    Status = "Host session ended in main menu";
                    LastError.clear();
                }
            }
            if (CurrentRole == Role::Client && NewWorldIsMainMenu)
            {
                CompletedClientReturn = true;
                ClientReturnWasPending = ClientReturnToMenuPending;
                CurrentRole = Role::Disabled;
                ClientReturnToMenuPending = false;
                ClientReturnTransportDetachedLogged = false;
                ClientTravelPending = false;
                ClientTravelStartedAt = {};
                ClientState = ClientLifecycleState::Disconnected;
                ConnectedClients = 0;
                GameplayReadyClients = 0;
                ClientGameplayReady = false;
                ClientArkLoginLocked = false;
                ClientPlayerStateReady = false;
                ClientHUDReady = false;
                ClientPawnReady = false;
                Status = "Returned to main menu";
                LastError.clear();
            }
            else if (CurrentRole == Role::Client && ClientReturnToMenuPending)
            {
                IntermediateClientReturnWorld = true;
                ClientState = ClientLifecycleState::Traveling;
                Status = "Return travel entered "
                    + (NewWorldName.empty() ? std::string("an unknown world")
                                            : NewWorldName)
                    + "; awaiting MainMenu";
            }
            CachedWorld = NewWorld;
            CachedWorldIdentity = MakeWeakIdentity(NewWorld);
            PlayerSummaries.clear();
            ConnectedClients = 0;
            GameplayReadyClients = 0;
            ArkLoginLockedClients = 0;
            PlayerUIRecoveryDiagnostics.clear();
        }
        if (ClearedHostedState)
        {
            HotHostedNetDriver.store(nullptr, std::memory_order_release);
            HotHosting.store(false, std::memory_order_release);
        }
        if (CompletedClientReturn || HostEndedInMainMenu)
        {
            HotRole.store(static_cast<uint8>(Role::Disabled),
                          std::memory_order_release);
            HotModePolicy.store(
                static_cast<uint8>(NetModePolicy::AutomaticListenServer),
                std::memory_order_release);
            if (CompletedClientReturn)
                AddLog(ClientReturnWasPending
                    ? "Client return-to-menu completed after MainMenu UWorld change"
                    : "Client session cleanup completed after delayed MainMenu UWorld change");
            else
                AddLog("Host session cleanup completed after MainMenu UWorld change");
        }
        else if (IntermediateClientReturnWorld)
        {
            AddLog("Return-to-menu observed intermediate UWorld '"
                   + (NewWorldName.empty() ? std::string("unknown") : NewWorldName)
                   + "'; still awaiting MainMenu", LogLevel::Debug);
        }
        AddLog("UWorld identity changed from "
               + HexAddress(reinterpret_cast<uintptr_t>(PreviousWorld)) + " to "
               + HexAddress(reinterpret_cast<uintptr_t>(NewWorld))
               + "; hosted/recovery state was cleared",
               LogLevel::Warning);
    }

    ENetMode HostingRuntime::ResolveNetMode(UNetDriver* NetDriver,
                                            ENetMode OriginalMode,
                                            uintptr_t CallerAddress) const
    {
        NetModeCallCount.fetch_add(1, std::memory_order_relaxed);
        if (!NetDriver
            || HotHostedNetDriver.load(std::memory_order_acquire) != NetDriver)
            return OriginalMode;

        HostedNetModeCallCount.fetch_add(1, std::memory_order_relaxed);
        LastHostedOriginalMode.store(static_cast<uint8>(OriginalMode),
                                     std::memory_order_relaxed);
        switch (OriginalMode)
        {
            case ENetMode::Standalone:
                HostedOriginalStandaloneCallCount.fetch_add(
                    1, std::memory_order_relaxed);
                break;
            case ENetMode::DedicatedServer:
                HostedOriginalDedicatedCallCount.fetch_add(
                    1, std::memory_order_relaxed);
                break;
            case ENetMode::ListenServer:
                HostedOriginalListenCallCount.fetch_add(
                    1, std::memory_order_relaxed);
                break;
            case ENetMode::Client:
                HostedOriginalClientCallCount.fetch_add(
                    1, std::memory_order_relaxed);
                break;
            case ENetMode::Max:
                break;
        }
        const Role ActiveRole = static_cast<Role>(
            HotRole.load(std::memory_order_relaxed));
        const NetModePolicy Policy = static_cast<NetModePolicy>(
            HotModePolicy.load(std::memory_order_relaxed));
        if (SynchronousSaveUsesOriginalHostedNetMode)
            return OriginalMode;
        if (ActiveRole == Role::Host
            && HotHosting.load(std::memory_order_acquire)
            && Policy == NetModePolicy::DedicatedServerExperimental)
        {
            const uint64 ForcedIndex = ForcedDedicatedCallCount.fetch_add(
                1, std::memory_order_relaxed);
            if ((ForcedIndex & 0x3FFu) == 0)
                SampleNetModeCaller(CallerAddress);
            return ENetMode::DedicatedServer;
        }
        // Production policy preserves UE's original ListenServer result. Core
        // replication authority is driven by the driver's ServerConnection /
        // ClientConnections state, not by pretending the local host is a
        // dedicated process.
        return OriginalMode;
    }

    bool HostingRuntime::ApplyArkLoginLockBypass(UWorld* World)
    {
        if (!KnownProfileEligible || !LooksLikeUObject(World))
        {
            AddLog("ARK login-lock bypass refused: exact SDK/signature profile or World is invalid");
            return false;
        }

        UObject* WorldObject = static_cast<UObject*>(World);
        const int32 GameModeOffset = WorldObject->GetOffset("AuthorityGameMode");
        if (GameModeOffset != static_cast<int32>(
                SDKProfile::KnownBuild::UWorldAuthorityGameMode))
        {
            AddLog("ARK login-lock bypass refused: AuthorityGameMode offset is "
                   + HexAddress(static_cast<uintptr_t>(GameModeOffset))
                   + ", expected 0x2b8");
            return false;
        }

        UObject* GameMode = static_cast<UObject*>(ReadPointer(
            reinterpret_cast<uintptr_t>(World) + GameModeOffset));
        if (!LooksLikeUObject(GameMode) || GameMode->IsDefaultObject()
            || !IsClassOrSuper(GameMode, "ShooterGameMode"))
        {
            AddLog("ARK login-lock bypass refused: live AShooterGameMode was not found");
            return false;
        }

        uint8 GlobalMask = 0;
        uint8 TempMask = 0;
        const int32 GlobalOffset = GameMode->GetOffset(
            "bGlobalDisableLoginLockCheck", &GlobalMask);
        const int32 TempOffset = GameMode->GetOffset(
            "bTempDisableLoginLockCheck", &TempMask);
        if (GlobalOffset != static_cast<int32>(
                SDKProfile::KnownBuild::AShooterGameModeGlobalDisableLoginLockCheck)
            || TempOffset != static_cast<int32>(
                SDKProfile::KnownBuild::AShooterGameModeTempDisableLoginLockCheck)
            || GlobalMask == 0 || TempMask == 0)
        {
            AddLog("ARK login-lock bypass refused: reflected flags are global="
                   + HexAddress(static_cast<uintptr_t>(GlobalOffset))
                   + "/mask=" + HexAddress(GlobalMask)
                   + ", temp=" + HexAddress(static_cast<uintptr_t>(TempOffset))
                   + "/mask=" + HexAddress(TempMask)
                   + "; expected 0x8c0/0x8c1");
            return false;
        }

        uint8* GlobalAddress = reinterpret_cast<uint8*>(GameMode) + GlobalOffset;
        uint8* TempAddress = reinterpret_cast<uint8*>(GameMode) + TempOffset;
        const bool GlobalBefore = (*GlobalAddress & GlobalMask) != 0;
        const bool TempBefore = (*TempAddress & TempMask) != 0;
        // ShooterGame rewrites the temporary flag from Redis health every
        // maintenance interval. The instance-scoped global-disable flag is the
        // stable policy gate checked by the same PreLogin branch.
        *GlobalAddress |= GlobalMask;
        const bool GlobalAfter = (*GlobalAddress & GlobalMask) != 0;
        const bool TempAfter = (*TempAddress & TempMask) != 0;
        const std::string Identity = GameMode->GetFullName();

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            AuthorityGameModeIdentity = Identity;
            GameModeGlobalDisableLoginLockCheck = GlobalAfter;
            GameModeTempDisableLoginLockCheck = TempAfter;
            ArkLoginBypassApplied = GlobalAfter;
            ArkLoginBypassWorld = GlobalAfter ? World : nullptr;
        }

        AddLog("ARK login-lock flags before host: GameMode=" + Identity
               + ", global=" + (GlobalBefore ? "true" : "false")
               + ", temp=" + (TempBefore ? "true" : "false"));
        AddLog(std::string("Instance ARK login-lock bypass: ")
               + (GlobalAfter ? "enabled and verified at +0x8c0"
                            : "write verification failed"));
        return GlobalAfter;
    }

    void HostingRuntime::EnsureProcessEventDiagnosticsHook()
    {
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (ProcessEventDiagnosticsInstalled || ProcessEventDiagnosticsAttempted)
                return;
        }

        if (!KnownProfileEligible || !UObject::GUObjectArray
            || !FName::NamePoolData || !FName::NamePoolData->Blocks[0]
            || UObject::GUObjectArray->ObjObjects.Num() <= 0)
            return;

        UClass* KismetClass = UObject::FindClass(
            "Class Engine.KismetStringLibrary");
        UObject* Validator = KismetClass ? KismetClass->ClassDefaultObject : nullptr;
        if (!LooksLikeUObject(Validator)
            || !Memory::GetInstance().IsValid(
                reinterpret_cast<uintptr_t>(Validator->VTable)))
            return;

        const uintptr_t Expected = Memory::GetInstance().GetImageBase(Config::ImageName)
            + SDKProfile::KnownBuild::ProcessEvent;
        void* VTableProcessEvent =
            Validator->VTable[SDKProfile::KnownBuild::ProcessEventIndex];
        if (!Expected || reinterpret_cast<uintptr_t>(VTableProcessEvent) != Expected
            || !Memory::GetInstance().IsValid(Expected))
        {
            {
                std::lock_guard<std::mutex> Guard(Mutex);
                ProcessEventDiagnosticsAttempted = true;
            }
            AddLog("Selective ProcessEvent trace refused: Kismet vtable entry "
                   + HexAddress(reinterpret_cast<uintptr_t>(VTableProcessEvent))
                   + " does not match exact-profile address " + HexAddress(Expected));
            return;
        }

        int32 ResolvedFunctions = 0;
        for (int32 Index = 0; Index < DiagnosticEventCount; ++Index)
        {
            UFunction* Function = UObject::FindObject<UFunction>(
                DiagnosticFunctionNames[Index], EClassCastFlags::Function);
            DiagnosticFunctions[Index].store(Function, std::memory_order_relaxed);
            if (Function)
            {
                ++ResolvedFunctions;
                AddLog("Diagnostic UFunction ready: "
                       + std::string(DiagnosticFunctionNames[Index])
                       + " @" + HexAddress(reinterpret_cast<uintptr_t>(Function))
                       + ", flags="
                       + HexAddress(static_cast<uintptr_t>(Function->FunctionFlags))
                       + ", parms=" + std::to_string(Function->ParmsSize));
            }
            else
            {
                AddLog("Diagnostic UFunction missing: "
                       + std::string(DiagnosticFunctionNames[Index]));
            }
        }

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (ProcessEventDiagnosticsInstalled || ProcessEventDiagnosticsAttempted)
                return;
            ProcessEventDiagnosticsAttempted = true;
            ProcessEventAddress = Expected;
        }

        MSHookFunction(reinterpret_cast<void*>(Expected),
                       reinterpret_cast<void*>(&HookProcessEvent),
                       reinterpret_cast<void**>(&OriginalProcessEvent));

        const bool Installed = OriginalProcessEvent != nullptr;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ProcessEventDiagnosticsInstalled = Installed;
        }
        AddLog(std::string("Selective ProcessEvent trace ")
               + (Installed ? "installed" : "failed") + " at "
               + HexAddress(Expected) + "; tracked functions="
               + std::to_string(ResolvedFunctions) + "/"
               + std::to_string(DiagnosticEventCount));
    }

    void HostingRuntime::OnDiagnosticProcessEvent(int32 EventIndex,
                                                   UObject* Context,
                                                   UFunction* Function,
                                                   void* Parameters,
                                                   bool AfterOriginal)
    {
        if (EventIndex < 0 || EventIndex >= DiagnosticEventCount
            || !LooksLikeUObject(Context) || !LooksLikeUObject(Function))
            return;

        Role EventRole = Role::Disabled;
        int32 EventCount = 0;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            EventRole = CurrentRole;
            if (!AfterOriginal)
            {
                EventCount = ++DiagnosticEventCounts[EventIndex];
                if (EventIndex == ClientShowCharacterCreationUI)
                    ClientCharacterCreationRPCSeen = true;
                if (EventIndex == ClientShowSpawnUI
                    || EventIndex == ClientShowSpawnUIForTransferringPlayer)
                    ClientSpawnUIRPCSeen = true;
            }
            else
            {
                EventCount = DiagnosticEventCounts[EventIndex];
            }

            std::ostringstream Summary;
            Summary << "HandleNewPlayer=" << DiagnosticEventCounts[HandleNewPlayer]
                    << ", K2_PostLogin=" << DiagnosticEventCounts[K2PostLogin]
                    << ", HUDInit=" << DiagnosticEventCounts[ClientSetHUDAndInitUIScenes]
                    << ", CharacterUI=" << DiagnosticEventCounts[ClientShowCharacterCreationUI]
                    << ", SpawnUI=" << (DiagnosticEventCounts[ClientShowSpawnUI]
                        + DiagnosticEventCounts[ClientShowSpawnUIForTransferringPlayer])
                    << ", ClientRestart=" << (DiagnosticEventCounts[ClientRestart]
                        + DiagnosticEventCounts[ClientRetryClientRestart])
                    << ", CreateRequest=" << DiagnosticEventCounts[ServerRequestCreateNewPlayer]
                    << ", RespawnRequest=" << DiagnosticEventCounts[ServerRequestRespawnAtPoint];
            Summary << ", NetworkError=" << DiagnosticEventCounts[HandleNetworkError]
                    << ", TravelError=" << DiagnosticEventCounts[HandleTravelError]
                    << ", Logout=" << DiagnosticEventCounts[K2OnLogout]
                    << ", CantHarvest="
                    << DiagnosticEventCounts[ClientNotifyCantHarvest]
                    << ", CantHitHarvest="
                    << DiagnosticEventCounts[ClientNotifyCantHitHarvest]
                    << ", HitHarvest="
                    << DiagnosticEventCounts[ClientNotifyHitHarvest];
            RPCDiagnostics = Summary.str();
        }

        const bool HarvestEvent = EventIndex == ClientNotifyCantHarvest
            || EventIndex == ClientNotifyCantHitHarvest
            || EventIndex == ClientNotifyHitHarvest;
        if (HarvestEvent && EventCount > 8
            && (EventCount & (EventCount - 1)) != 0)
            return;

        const char* RoleText = EventRole == Role::Host ? "host"
            : (EventRole == Role::Client ? "client" : "disabled");
        std::ostringstream Details;
        Details << "PE " << (AfterOriginal ? "EXIT " : "ENTER ")
                << Function->NamePrivate.ToString() << " #" << EventCount
                << " role=" << RoleText
                << ", context=" << DescribeObject(Context);

        const uint8* Raw = static_cast<const uint8*>(Parameters);
        auto ParameterObject = [Raw](std::size_t Offset) -> void*
        {
            return Raw ? *reinterpret_cast<void* const*>(Raw + Offset) : nullptr;
        };

        switch (EventIndex)
        {
            case HandleNewPlayer:
                Details << ", NewPlayer=" << DescribeObject(ParameterObject(0x0))
                        << ", PlayerData=" << DescribeObject(ParameterObject(0x8))
                        << ", PlayerCharacter=" << DescribeObject(ParameterObject(0x10));
                if (Raw)
                {
                    Details << ", bIsFromLogin=" << (Raw[0x18] ? "true" : "false");
                    if (AfterOriginal)
                        Details << ", ReturnValue=" << (Raw[0x19] ? "true" : "false");
                }
                break;
            case HandleStartingNewPlayer:
            case InitializeHUDForPlayer:
            case K2PostLogin:
            case RestartPlayer:
                Details << ", NewPlayer=" << DescribeObject(ParameterObject(0x0));
                break;
            case ClientSetHUDAndInitUIScenes:
                Details << ", NewHUDClass=" << DescribeObject(ParameterObject(0x0));
                break;
            case ClientShowCharacterCreationUI:
                if (Raw)
                    Details << ", bShowDownloadCharacter="
                            << (Raw[0] ? "true" : "false");
                break;
            case ClientShowSpawnUI:
                if (Raw)
                    Details << ", Delay=" << *reinterpret_cast<const float*>(Raw);
                break;
            case ClientShowSpawnUIForTransferringPlayer:
                Details << ", NewHUDClass=" << DescribeObject(ParameterObject(0x0));
                if (Raw)
                {
                    Details << ", TransferingPlayerID="
                            << *reinterpret_cast<const uint64*>(Raw + 0x8)
                            << ", bUseTimer=" << (Raw[0x10] ? "true" : "false");
                }
                break;
            case ClientRestart:
            case ClientRetryClientRestart:
                Details << ", NewPawn=" << DescribeObject(ParameterObject(0x0));
                break;
            case ServerRequestCreateNewPlayer:
                if (Raw)
                {
                    const FString* CharacterName =
                        reinterpret_cast<const FString*>(Raw + 0x48);
                    Details << ", characterName='" << SafeFString(CharacterName)
                            << "', female=" << ((Raw[0] & 1) ? "true" : "false")
                            << ", spawnRegion="
                            << *reinterpret_cast<const int32*>(Raw + 0xB0);
                }
                break;
            case ServerRequestRespawnAtPoint:
                if (Raw)
                {
                    Details << ", spawnPointID="
                            << *reinterpret_cast<const int32*>(Raw)
                            << ", spawnRegionIndex="
                            << *reinterpret_cast<const int32*>(Raw + 0x4);
                }
                break;
            case HandleNetworkError:
                if (Raw)
                    Details << ", FailureType=" << NetworkFailureName(Raw[0])
                            << "(" << static_cast<int32>(Raw[0]) << ")"
                            << ", bIsServer=" << (Raw[1] ? "true" : "false");
                break;
            case HandleTravelError:
                if (Raw)
                    Details << ", FailureType=" << TravelFailureName(Raw[0])
                            << "(" << static_cast<int32>(Raw[0]) << ")";
                break;
            case K2OnLogout:
                Details << ", ExitingController=" << DescribeObject(ParameterObject(0x0));
                break;
            case ClientNotifyCantHarvest:
                Details << ", result=server rejected harvest interaction";
                break;
            case ClientNotifyCantHitHarvest:
                Details << ", result=server rejected harvest hit";
                break;
            case ClientNotifyHitHarvest:
                Details << ", result=server accepted harvest hit";
                break;
            default:
                break;
        }

        AddLog(Details.str());
    }

    void HostingRuntime::OnNativeHandleNewPlayer(void* GameMode,
                                                  void* PlayerController,
                                                  void* PlayerData,
                                                  void* PlayerCharacter,
                                                  bool FromLogin,
                                                  bool AfterOriginal,
                                                  bool ReturnValue)
    {
        int32 Count = 0;
        Role EventRole = Role::Disabled;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            EventRole = CurrentRole;
            if (!AfterOriginal)
                Count = ++DiagnosticEventCounts[HandleNewPlayer];
            else
                Count = DiagnosticEventCounts[HandleNewPlayer];
            RPCDiagnostics = BuildPlayerFlowSummary(
                DiagnosticEventCounts, ClientCharacterUICallbackCount);
        }
        if (Count > 8)
            return;
        AddLog(std::string("Native ") + (AfterOriginal ? "EXIT " : "ENTER ")
               + "HandleNewPlayer #" + std::to_string(Count)
               + ", role=" + (EventRole == Role::Host ? "host" : "other")
               + ", GameMode=" + DescribeObject(GameMode)
               + ", PC=" + DescribeObject(PlayerController)
               + ", PlayerData=" + DescribeObject(PlayerData)
               + ", PlayerCharacter=" + DescribeObject(PlayerCharacter)
               + ", fromLogin=" + (FromLogin ? "true" : "false")
               + (AfterOriginal
                    ? std::string(", return=") + (ReturnValue ? "true" : "false")
                    : ""));
    }

    void HostingRuntime::OnNativeClientHUDInit(void* PlayerController,
                                                void* HUDClass,
                                                bool AfterOriginal)
    {
        int32 Count = 0;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (!AfterOriginal)
                Count = ++DiagnosticEventCounts[ClientSetHUDAndInitUIScenes];
            else
                Count = DiagnosticEventCounts[ClientSetHUDAndInitUIScenes];
            RPCDiagnostics = BuildPlayerFlowSummary(
                DiagnosticEventCounts, ClientCharacterUICallbackCount);
        }
        if (Count > 8)
            return;
        AddLog(std::string("Native ") + (AfterOriginal ? "EXIT " : "ENTER ")
               + "ClientSetHUDAndInitUIScenes #" + std::to_string(Count)
               + ", HUDClass=" + DescribeObject(HUDClass)
               + ", " + DescribePlayerUIState(PlayerController));
    }

    void HostingRuntime::OnNativeCharacterCreationUI(
        void* PlayerController, bool ShowDownloadCharacter, bool AfterOriginal)
    {
        int32 Count = 0;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (!AfterOriginal)
            {
                Count = ++DiagnosticEventCounts[ClientShowCharacterCreationUI];
                ClientCharacterCreationRPCSeen = true;
            }
            else
                Count = DiagnosticEventCounts[ClientShowCharacterCreationUI];
            RPCDiagnostics = BuildPlayerFlowSummary(
                DiagnosticEventCounts, ClientCharacterUICallbackCount);
        }
        if (Count > 8)
            return;
        AddLog(std::string("Native ") + (AfterOriginal ? "EXIT " : "ENTER ")
               + "ClientShowCharacterCreationUI #" + std::to_string(Count)
               + ", showDownload=" + (ShowDownloadCharacter ? "true" : "false")
               + ", " + DescribePlayerUIState(PlayerController));
    }

    void HostingRuntime::OnNativeSpawnUI(void* PlayerController, float Delay,
                                          bool AfterOriginal)
    {
        int32 Count = 0;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (!AfterOriginal)
            {
                Count = ++DiagnosticEventCounts[ClientShowSpawnUI];
                ClientSpawnUIRPCSeen = true;
            }
            else
                Count = DiagnosticEventCounts[ClientShowSpawnUI];
            RPCDiagnostics = BuildPlayerFlowSummary(
                DiagnosticEventCounts, ClientCharacterUICallbackCount);
        }
        if (Count > 8)
            return;
        AddLog(std::string("Native ") + (AfterOriginal ? "EXIT " : "ENTER ")
               + "ClientShowSpawnUI #" + std::to_string(Count)
               + ", delay=" + std::to_string(Delay)
               + ", " + DescribePlayerUIState(PlayerController));
    }

    void HostingRuntime::OnNativeCharacterUICallback(void* HUD,
                                                      bool AfterOriginal,
                                                      uintptr_t ReturnValue)
    {
        int32 Count = 0;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (!AfterOriginal)
                Count = ++ClientCharacterUICallbackCount;
            else
                Count = ClientCharacterUICallbackCount;
            RPCDiagnostics = BuildPlayerFlowSummary(
                DiagnosticEventCounts, ClientCharacterUICallbackCount);
        }
        if (Count > 8)
            return;
        void* PC = nullptr;
        if (LooksLikeUObject(HUD)
            && static_cast<UObject*>(HUD)->GetOffset("PlayerOwner")
                == static_cast<int32>(SDKProfile::KnownBuild::AHUDPlayerOwner))
            PC = ReadPointer(reinterpret_cast<uintptr_t>(HUD)
                             + SDKProfile::KnownBuild::AHUDPlayerOwner);
        AddLog(std::string("Native ") + (AfterOriginal ? "EXIT " : "ENTER ")
               + "CharacterCreationTimerCallback #" + std::to_string(Count)
               + ", HUD=" + DescribeObject(HUD)
               + ", " + DescribePlayerUIState(PC)
               + (AfterOriginal ? ", return=" + HexAddress(ReturnValue) : ""));
    }

    void HostingRuntime::UpdateConnectionDiagnostics(void* World,
                                                     void* ActiveNetDriver,
                                                     Role ActiveRole,
                                                     bool IsHosting,
                                                     void* HostDriver)
    {
        if (!KnownProfileEligible)
            return;

        struct ConnectionInfo
        {
            bool Valid = false;
            bool GameplayReady = false;
            bool PlayerStateReady = false;
            bool HUDReady = false;
            bool PawnReady = false;
            bool ArkLoginLocked = false;
            int32 OpenChannels = -1;
            std::string Description;
            std::string PlayerInitialization;
        };

        auto InspectConnection = [](void* ConnectionPointer) -> ConnectionInfo
        {
            ConnectionInfo Info;
            if (!LooksLikeUObject(ConnectionPointer))
                return Info;

            UObject* Connection = static_cast<UObject*>(ConnectionPointer);
            if (!LooksLikeUObject(Connection->ClassPrivate))
                return Info;
            const int32 PlayerControllerOffset = Connection->GetOffset("PlayerController");
            const int32 OwningActorOffset = Connection->GetOffset("OwningActor");
            const int32 OpenChannelsOffset = Connection->GetOffset("OpenChannels");
            uint8 ArkLoginLockMask = 0;
            const int32 ArkLoginLockOffset = Connection->GetOffset(
                "bHasArkLoginLock", &ArkLoginLockMask);
            if (PlayerControllerOffset != static_cast<int32>(
                    SDKProfile::KnownBuild::UPlayerPlayerController)
                || OwningActorOffset != static_cast<int32>(
                    SDKProfile::KnownBuild::UNetConnectionOwningActor)
                || OpenChannelsOffset != static_cast<int32>(
                    SDKProfile::KnownBuild::UNetConnectionOpenChannels)
                || ArkLoginLockOffset != static_cast<int32>(
                    SDKProfile::KnownBuild::UNetConnectionArkLoginLock)
                || ArkLoginLockMask == 0)
                return Info;

            void* PlayerController = ReadPointer(
                reinterpret_cast<uintptr_t>(Connection) + PlayerControllerOffset);
            void* OwningActor = ReadPointer(
                reinterpret_cast<uintptr_t>(Connection) + OwningActorOffset);
            const auto Channels = Memory::GetInstance().Read<ArrayHeader>(
                reinterpret_cast<uintptr_t>(Connection) + OpenChannelsOffset);

            Info.Valid = true;
            Info.GameplayReady = LooksLikeUObject(PlayerController);
            Info.ArkLoginLocked = (*(reinterpret_cast<uint8*>(Connection)
                                      + ArkLoginLockOffset) & ArkLoginLockMask) != 0;
            if (Channels.Num >= 0 && Channels.Num <= 32768
                && Channels.Max >= Channels.Num && Channels.Max <= 32768)
                Info.OpenChannels = Channels.Num;

            Info.Description = "connection=" + Connection->GetFullName()
                + ", class=" + Connection->ClassPrivate->GetFullName()
                + ", PlayerController=" + DescribeObject(PlayerController)
                + ", OwningActor=" + DescribeObject(OwningActor)
                + ", bHasArkLoginLock="
                + (Info.ArkLoginLocked ? "true" : "false")
                + ", open channels=" + std::to_string(Info.OpenChannels);

            const int32 DriverOffset = Connection->GetOffset("Driver");
            const int32 PackageMapOffset = Connection->GetOffset("PackageMap");
            const int32 ViewTargetOffset = Connection->GetOffset("ViewTarget");
            const int32 LastReceiveOffset = Connection->GetOffset("LastReceiveTime");
            if (DriverOffset == static_cast<int32>(SDKProfile::KnownBuild::UNetConnectionDriver)
                && PackageMapOffset == static_cast<int32>(SDKProfile::KnownBuild::UNetConnectionPackageMap)
                && ViewTargetOffset == static_cast<int32>(SDKProfile::KnownBuild::UNetConnectionViewTarget)
                && LastReceiveOffset == static_cast<int32>(SDKProfile::KnownBuild::UNetConnectionLastReceiveTime))
            {
                void* Driver = ReadPointer(reinterpret_cast<uintptr_t>(Connection) + DriverOffset);
                const double LastReceive = *reinterpret_cast<const double*>(
                    reinterpret_cast<uintptr_t>(Connection) + LastReceiveOffset);
                float DriverTime = 0.0f;
                if (LooksLikeUObject(Driver)
                    && IsClassOrSuper(static_cast<UObject*>(Driver), "NetDriver")
                    && static_cast<UObject*>(Driver)->GetOffset("Time")
                        == static_cast<int32>(SDKProfile::KnownBuild::UNetDriverTime))
                    DriverTime = *reinterpret_cast<const float*>(
                        reinterpret_cast<uintptr_t>(Driver)
                        + SDKProfile::KnownBuild::UNetDriverTime);
                Info.Description += ", Driver=" + DescribeObject(Driver)
                    + ", PackageMap=" + DescribeObject(ReadPointer(
                        reinterpret_cast<uintptr_t>(Connection) + PackageMapOffset))
                    + ", ViewTarget=" + DescribeObject(ReadPointer(
                        reinterpret_cast<uintptr_t>(Connection) + ViewTargetOffset));
                const double SecondsSinceReceive = static_cast<double>(DriverTime)
                    - LastReceive;
                if (std::isfinite(LastReceive) && std::isfinite(SecondsSinceReceive)
                    && LastReceive >= 0.0 && std::abs(SecondsSinceReceive) < 1000000.0)
                {
                    Info.Description += ", secondsSinceReceive="
                        + std::to_string(SecondsSinceReceive);
                }
                else
                {
                    Info.Description += ", receiveTiming=invalid(driverTime="
                        + std::to_string(DriverTime) + ", lastReceiveTime="
                        + std::to_string(LastReceive) + ")";
                }
            }

            if (Channels.Data && Channels.Num > 0 && Channels.Num <= 32768
                && Memory::GetInstance().IsValid(reinterpret_cast<uintptr_t>(Channels.Data)))
            {
                int32 Control = 0, Actor = 0, Voice = 0, Other = 0;
                for (int32 Index = 0; Index < Channels.Num; ++Index)
                {
                    UObject* Channel = static_cast<UObject*>(ReadPointer(
                        reinterpret_cast<uintptr_t>(Channels.Data) + sizeof(void*) * Index));
                    if (!LooksLikeUObject(Channel) || !LooksLikeUObject(Channel->ClassPrivate))
                        continue;
                    const std::string Name = Channel->ClassPrivate->NamePrivate.ToString();
                    if (Name == "ControlChannel") ++Control;
                    else if (Name == "ActorChannel") ++Actor;
                    else if (Name == "VoiceChannel") ++Voice;
                    else ++Other;
                }
                Info.Description += ", channelClasses={Control=" + std::to_string(Control)
                    + ",Actor=" + std::to_string(Actor)
                    + ",Voice=" + std::to_string(Voice)
                    + ",Other=" + std::to_string(Other) + "}";
            }

            UObject* PC = static_cast<UObject*>(PlayerController);
            if (!LooksLikeUObject(PC) || !IsClassOrSuper(PC, "PlayerController"))
                return Info;

            uint8 WaitingMask = 0;
            const bool PlayerLayoutConfirmed =
                PC->GetOffset("PlayerState") == static_cast<int32>(SDKProfile::KnownBuild::AControllerPlayerState)
                && PC->GetOffset("StateName") == static_cast<int32>(SDKProfile::KnownBuild::AControllerStateName)
                && PC->GetOffset("Pawn") == static_cast<int32>(SDKProfile::KnownBuild::AControllerPawn)
                && PC->GetOffset("Character") == static_cast<int32>(SDKProfile::KnownBuild::AControllerCharacter)
                && PC->GetOffset("Player") == static_cast<int32>(SDKProfile::KnownBuild::APlayerControllerPlayer)
                && PC->GetOffset("AcknowledgedPawn") == static_cast<int32>(SDKProfile::KnownBuild::APlayerControllerAcknowledgedPawn)
                && PC->GetOffset("MyHUD") == static_cast<int32>(SDKProfile::KnownBuild::APlayerControllerMyHUD)
                && PC->GetOffset("bPlayerIsWaiting", &WaitingMask) == static_cast<int32>(SDKProfile::KnownBuild::APlayerControllerPlayerIsWaiting)
                && PC->GetOffset("NetConnection") == static_cast<int32>(SDKProfile::KnownBuild::APlayerControllerNetConnection)
                && WaitingMask != 0;
            if (!PlayerLayoutConfirmed)
            {
                Info.PlayerInitialization = "PlayerController layout rejected by reflection: "
                    + PC->GetFullName();
                return Info;
            }

            const uintptr_t PCAddress = reinterpret_cast<uintptr_t>(PC);
            UObject* PlayerState = static_cast<UObject*>(ReadPointer(
                PCAddress + SDKProfile::KnownBuild::AControllerPlayerState));
            void* Pawn = ReadPointer(PCAddress + SDKProfile::KnownBuild::AControllerPawn);
            void* Character = ReadPointer(PCAddress + SDKProfile::KnownBuild::AControllerCharacter);
            void* AcknowledgedPawn = ReadPointer(
                PCAddress + SDKProfile::KnownBuild::APlayerControllerAcknowledgedPawn);
            void* HUD = ReadPointer(PCAddress + SDKProfile::KnownBuild::APlayerControllerMyHUD);
            const FName StateName = *reinterpret_cast<const FName*>(
                PCAddress + SDKProfile::KnownBuild::AControllerStateName);
            const bool Waiting = (*(reinterpret_cast<const uint8*>(PC)
                + SDKProfile::KnownBuild::APlayerControllerPlayerIsWaiting) & WaitingMask) != 0;
            Info.PlayerStateReady = LooksLikeUObject(PlayerState);
            Info.HUDReady = LooksLikeUObject(HUD);
            Info.PawnReady = LooksLikeUObject(Pawn) || LooksLikeUObject(AcknowledgedPawn);

            std::ostringstream Player;
            Player << "PC=" << DescribeObject(PC)
                   << ", StateName=" << StateName.ToString()
                   << ", bPlayerIsWaiting=" << (Waiting ? "true" : "false")
                   << ", Player=" << DescribeObject(ReadPointer(
                        PCAddress + SDKProfile::KnownBuild::APlayerControllerPlayer))
                   << ", NetConnection=" << DescribeObject(ReadPointer(
                        PCAddress + SDKProfile::KnownBuild::APlayerControllerNetConnection))
                   << ", PlayerState=" << DescribeObject(PlayerState)
                   << ", Pawn=" << DescribeObject(Pawn)
                   << ", Character=" << DescribeObject(Character)
                   << ", AcknowledgedPawn=" << DescribeObject(AcknowledgedPawn)
                   << ", MyHUD=" << DescribeObject(HUD);

            if (LooksLikeUObject(PlayerState) && IsClassOrSuper(PlayerState, "PlayerState")
                && PlayerState->GetOffset("PlayerID") == static_cast<int32>(SDKProfile::KnownBuild::APlayerStatePlayerID)
                && PlayerState->GetOffset("PawnPrivate") == static_cast<int32>(SDKProfile::KnownBuild::APlayerStatePawnPrivate)
                && PlayerState->GetOffset("PlayerNamePrivate") == static_cast<int32>(SDKProfile::KnownBuild::APlayerStatePlayerNamePrivate))
            {
                const uintptr_t PS = reinterpret_cast<uintptr_t>(PlayerState);
                const int32 PlayerID = *reinterpret_cast<const int32*>(
                    PS + SDKProfile::KnownBuild::APlayerStatePlayerID);
                const uint8 SpectatorFlags = *reinterpret_cast<const uint8*>(
                    PS + SDKProfile::KnownBuild::APlayerStateSpectatorFlags);
                Player << ", PlayerName='" << SafeFString(reinterpret_cast<const FString*>(
                            PS + SDKProfile::KnownBuild::APlayerStatePlayerNamePrivate)) << "'"
                       << ", PlayerID=" << PlayerID
                       << ", spectator=" << ((SpectatorFlags & 0x2) ? "true" : "false")
                       << ", onlySpectator=" << ((SpectatorFlags & 0x4) ? "true" : "false")
                       << ", PawnPrivate=" << DescribeObject(ReadPointer(
                            PS + SDKProfile::KnownBuild::APlayerStatePawnPrivate));
                if (IsClassOrSuper(PlayerState, "ShooterPlayerState")
                    && PlayerState->GetOffset("MyPlayerData") == static_cast<int32>(SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData)
                    && PlayerState->GetOffset("CachedSpawnPointInfos") == static_cast<int32>(SDKProfile::KnownBuild::AShooterPlayerStateCachedSpawnPointInfos))
                {
                    const ArrayHeader SpawnInfos = *reinterpret_cast<const ArrayHeader*>(
                        PS + SDKProfile::KnownBuild::AShooterPlayerStateCachedSpawnPointInfos);
                    Player << ", MyPlayerData=" << DescribeObject(ReadPointer(
                                PS + SDKProfile::KnownBuild::AShooterPlayerStateMyPlayerData))
                           << ", CachedSpawnPointInfos=" << SpawnInfos.Num << "/" << SpawnInfos.Max;
                }
            }
            Info.PlayerInitialization = Player.str();
            return Info;
        };

        std::string GameModeIdentity;
        std::string GameModeDetails;
        bool GlobalDisable = false;
        bool TempDisable = false;
        bool ReappliedArkBypass = false;
        bool MaintainArkBypass = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            MaintainArkBypass = ActiveRole == Role::Host && IsHosting
                && BypassArkLoginLock && ArkLoginBypassApplied
                && ArkLoginBypassWorld == World;
        }
        if (LooksLikeUObject(World))
        {
            UObject* WorldObject = static_cast<UObject*>(World);
            const int32 GameModeOffset = WorldObject->GetOffset("AuthorityGameMode");
            if (GameModeOffset == static_cast<int32>(
                    SDKProfile::KnownBuild::UWorldAuthorityGameMode))
            {
                UObject* GameMode = static_cast<UObject*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(World) + GameModeOffset));
                if (LooksLikeUObject(GameMode) && IsClassOrSuper(GameMode, "ShooterGameMode"))
                {
                    uint8 GlobalMask = 0;
                    uint8 TempMask = 0;
                    const int32 GlobalOffset = GameMode->GetOffset(
                        "bGlobalDisableLoginLockCheck", &GlobalMask);
                    const int32 TempOffset = GameMode->GetOffset(
                        "bTempDisableLoginLockCheck", &TempMask);
                    if (GlobalOffset == static_cast<int32>(
                            SDKProfile::KnownBuild::AShooterGameModeGlobalDisableLoginLockCheck)
                        && TempOffset == static_cast<int32>(
                            SDKProfile::KnownBuild::AShooterGameModeTempDisableLoginLockCheck)
                        && GlobalMask && TempMask)
                    {
                        GlobalDisable = (*(reinterpret_cast<uint8*>(GameMode)
                                           + GlobalOffset) & GlobalMask) != 0;
                        TempDisable = (*(reinterpret_cast<uint8*>(GameMode)
                                         + TempOffset) & TempMask) != 0;
                        if (MaintainArkBypass && !GlobalDisable)
                        {
                            *(reinterpret_cast<uint8*>(GameMode) + GlobalOffset)
                                |= GlobalMask;
                            GlobalDisable = (*(reinterpret_cast<uint8*>(GameMode)
                                               + GlobalOffset) & GlobalMask) != 0;
                            ReappliedArkBypass = GlobalDisable;
                        }
                        GameModeIdentity = GameMode->GetFullName();
                        const uintptr_t GM = reinterpret_cast<uintptr_t>(GameMode);
                        uint8 SpectatorMask = 0;
                        const int32 SpectatorOffset = GameMode->GetOffset(
                            "bStartPlayersAsSpectators", &SpectatorMask);
                        const bool BaseLayoutConfirmed =
                            GameMode->GetOffset("GameStateClass") == static_cast<int32>(SDKProfile::KnownBuild::AGameModeBaseGameStateClass)
                            && GameMode->GetOffset("PlayerControllerClass") == static_cast<int32>(SDKProfile::KnownBuild::AGameModeBasePlayerControllerClass)
                            && GameMode->GetOffset("PlayerStateClass") == static_cast<int32>(SDKProfile::KnownBuild::AGameModeBasePlayerStateClass)
                            && GameMode->GetOffset("HUDClass") == static_cast<int32>(SDKProfile::KnownBuild::AGameModeBaseHUDClass)
                            && GameMode->GetOffset("DefaultPawnClass") == static_cast<int32>(SDKProfile::KnownBuild::AGameModeBaseDefaultPawnClass)
                            && GameMode->GetOffset("GameSession") == static_cast<int32>(SDKProfile::KnownBuild::AGameModeBaseGameSession);
                        std::ostringstream Details;
                        Details << "GameMode=" << DescribeObject(GameMode);
                        if (BaseLayoutConfirmed)
                        {
                            Details
                                << ", GameStateClass=" << DescribeObject(ReadPointer(
                                    GM + SDKProfile::KnownBuild::AGameModeBaseGameStateClass))
                                << ", PlayerControllerClass=" << DescribeObject(ReadPointer(
                                    GM + SDKProfile::KnownBuild::AGameModeBasePlayerControllerClass))
                                << ", PlayerStateClass=" << DescribeObject(ReadPointer(
                                    GM + SDKProfile::KnownBuild::AGameModeBasePlayerStateClass))
                                << ", HUDClass=" << DescribeObject(ReadPointer(
                                    GM + SDKProfile::KnownBuild::AGameModeBaseHUDClass))
                                << ", DefaultPawnClass=" << DescribeObject(ReadPointer(
                                    GM + SDKProfile::KnownBuild::AGameModeBaseDefaultPawnClass))
                                << ", GameSession=" << DescribeObject(ReadPointer(
                                    GM + SDKProfile::KnownBuild::AGameModeBaseGameSession))
                                << ", bStartPlayersAsSpectators="
                                << ((SpectatorOffset == static_cast<int32>(SDKProfile::KnownBuild::AGameModeBaseStartPlayersAsSpectators)
                                     && SpectatorMask != 0
                                     && (*(reinterpret_cast<uint8*>(GameMode) + SpectatorOffset)
                                         & SpectatorMask) != 0) ? "true" : "false");
                        }
                        else
                        {
                            Details << ", base-class layout rejected by reflection";
                        }
                        Details << ", loginLockGlobal=" << (GlobalDisable ? "true" : "false")
                                << ", loginLockTemp=" << (TempDisable ? "true" : "false");
                        const int32 RegionsOffset = GameMode->GetOffset(
                            "SupportedSpawnRegions");
                        if (RegionsOffset == static_cast<int32>(
                                SDKProfile::KnownBuild::AShooterGameModeSupportedSpawnRegions))
                        {
                            const ArrayHeader Regions = *reinterpret_cast<const ArrayHeader*>(
                                GM + RegionsOffset);
                            if (Regions.Num >= 0 && Regions.Num <= 1024
                                && Regions.Max >= Regions.Num && Regions.Max <= 1024)
                            {
                                Details << ", authority SupportedSpawnRegions="
                                        << Regions.Num << "/" << Regions.Max;
                            }
                            else
                            {
                                Details << ", authority SupportedSpawnRegions=invalid(" 
                                        << Regions.Num << "/" << Regions.Max << ")";
                            }
                        }
                        GameModeDetails = Details.str();
                    }
                }
            }
        }

        std::string GameStateDetails;
        bool GameStateListenFlagKnown = false;
        bool GameStateListenFlag = false;
        if (LooksLikeUObject(World))
        {
            UObject* WorldObject = static_cast<UObject*>(World);
            const int32 GameStateOffset = WorldObject->GetOffset("GameState");
            UObject* GameState = GameStateOffset == static_cast<int32>(
                SDKProfile::KnownBuild::UWorldGameState)
                ? static_cast<UObject*>(ReadPointer(reinterpret_cast<uintptr_t>(World)
                                                    + GameStateOffset))
                : nullptr;
            if (LooksLikeUObject(GameState) && IsClassOrSuper(GameState, "ShooterGameState"))
            {
                uint8 BegunMask = 0, ListenMask = 0, DediMask = 0;
                uint8 CreationMask = 0, SpawnSelectionMask = 0;
                const bool LayoutConfirmed =
                    GameState->GetOffset("PlayerArray") == static_cast<int32>(SDKProfile::KnownBuild::AGameStateBasePlayerArray)
                    && GameState->GetOffset("bReplicatedHasBegunPlay", &BegunMask) == static_cast<int32>(SDKProfile::KnownBuild::AGameStateBaseReplicatedHasBegunPlay)
                    && GameState->GetOffset("MatchState") == static_cast<int32>(SDKProfile::KnownBuild::AGameStateMatchState)
                    && GameState->GetOffset("NumPlayerActors") == static_cast<int32>(SDKProfile::KnownBuild::AShooterGameStateNumPlayerActors)
                    && GameState->GetOffset("NumPlayerConnected") == static_cast<int32>(SDKProfile::KnownBuild::AShooterGameStateNumPlayerConnected)
                    && GameState->GetOffset("bIsListenServer", &ListenMask) == static_cast<int32>(SDKProfile::KnownBuild::AShooterGameStateIsListenServer)
                    && GameState->GetOffset("bIsDediServer", &DediMask) == static_cast<int32>(SDKProfile::KnownBuild::AShooterGameStateIsDediServer)
                    && GameState->GetOffset("bAllowCharacterCreation", &CreationMask) == static_cast<int32>(SDKProfile::KnownBuild::AShooterGameStateAllowCharacterCreation)
                    && GameState->GetOffset("bAllowSpawnPointSelection", &SpawnSelectionMask) == static_cast<int32>(SDKProfile::KnownBuild::AShooterGameStateAllowSpawnPointSelection)
                    && GameState->GetOffset("SupportedSpawnRegions") == static_cast<int32>(SDKProfile::KnownBuild::AShooterGameStateSupportedSpawnRegions)
                    && BegunMask && ListenMask && DediMask && CreationMask && SpawnSelectionMask;
                if (LayoutConfirmed)
                {
                    const uintptr_t GS = reinterpret_cast<uintptr_t>(GameState);
                    const ArrayHeader Players = *reinterpret_cast<const ArrayHeader*>(
                        GS + SDKProfile::KnownBuild::AGameStateBasePlayerArray);
                    const ArrayHeader Regions = *reinterpret_cast<const ArrayHeader*>(
                        GS + SDKProfile::KnownBuild::AShooterGameStateSupportedSpawnRegions);
                    const FName MatchState = *reinterpret_cast<const FName*>(
                        GS + SDKProfile::KnownBuild::AGameStateMatchState);
                    auto Flag = [GS](std::size_t Offset, uint8 Mask)
                    {
                        return (*reinterpret_cast<const uint8*>(GS + Offset) & Mask) != 0;
                    };
                    GameStateListenFlagKnown = true;
                    GameStateListenFlag = Flag(
                        SDKProfile::KnownBuild::AShooterGameStateIsListenServer,
                        ListenMask);
                    std::ostringstream Details;
                    Details << "GameState=" << DescribeObject(GameState)
                            << ", MatchState=" << MatchState.ToString()
                            << ", replicatedBeginPlay=" << (Flag(SDKProfile::KnownBuild::AGameStateBaseReplicatedHasBegunPlay, BegunMask) ? "true" : "false")
                            << ", PlayerArray=" << Players.Num << "/" << Players.Max
                            << ", NumPlayerActors=" << *reinterpret_cast<const int32*>(GS + SDKProfile::KnownBuild::AShooterGameStateNumPlayerActors)
                            << ", NumPlayerConnected=" << *reinterpret_cast<const int32*>(GS + SDKProfile::KnownBuild::AShooterGameStateNumPlayerConnected)
                            << ", bIsListenServer=" << (GameStateListenFlag ? "true" : "false")
                            << ", bIsDediServer=" << (Flag(SDKProfile::KnownBuild::AShooterGameStateIsDediServer, DediMask) ? "true" : "false")
                            << ", allowCharacterCreation=" << (Flag(SDKProfile::KnownBuild::AShooterGameStateAllowCharacterCreation, CreationMask) ? "true" : "false")
                            << ", allowSpawnPointSelection=" << (Flag(SDKProfile::KnownBuild::AShooterGameStateAllowSpawnPointSelection, SpawnSelectionMask) ? "true" : "false")
                            << ", SupportedSpawnRegions=" << Regions.Num << "/" << Regions.Max;
                    GameStateDetails = Details.str();
                }
                else
                {
                    GameStateDetails = "GameState layout rejected by reflection: "
                        + GameState->GetFullName();
                }
            }
            else
            {
                GameStateDetails = "GameState unavailable: offset="
                    + HexAddress(static_cast<uintptr_t>(GameStateOffset))
                    + ", object=" + DescribeObject(GameState);
            }
        }

        int32 TransportClients = 0;
        int32 ReadyClients = 0;
        int32 LockedClients = 0;
        bool ClientReady = false;
        bool ClientLocked = false;
        bool ClientHasPlayerState = false;
        bool ClientHasHUD = false;
        bool ClientHasPawn = false;
        std::string Diagnostics;
        std::string PlayerInitialization;

        if (ActiveRole == Role::Client && ActiveNetDriver)
        {
            void* ServerConnection = ReadPointer(
                reinterpret_cast<uintptr_t>(ActiveNetDriver)
                + SDKProfile::KnownBuild::UNetDriverServerConnection);
            ConnectionInfo Info = InspectConnection(ServerConnection);
            if (Info.Valid)
            {
                UObject* PC = static_cast<UObject*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(ServerConnection)
                    + SDKProfile::KnownBuild::UPlayerPlayerController));
                UObject* PlayerState = LooksLikeUObject(PC)
                    ? static_cast<UObject*>(ReadPointer(
                        reinterpret_cast<uintptr_t>(PC)
                        + SDKProfile::KnownBuild::AControllerPlayerState))
                    : nullptr;
                PlayerSummary IdentitySummary;
                if (PopulatePlayerOnlineIdentity(PlayerState, PC,
                                                   ServerConnection,
                                                   IdentitySummary))
                {
                    Info.PlayerInitialization += ", OnlineIdentity="
                        + (IdentitySummary.OnlineIdentity.empty()
                            ? std::string("missing")
                            : IdentitySummary.OnlineIdentity)
                        + ", IdentityBytes(PS/connection)="
                        + std::to_string(IdentitySummary.PlayerStateIdentityBytes)
                        + "/"
                        + std::to_string(IdentitySummary.ConnectionIdentityBytes)
                        + ", ArkPass="
                        + (IdentitySummary.ArkPassKnown
                            ? (IdentitySummary.HasArkPass ? "owned" : "not-owned")
                            : "unavailable");
                }
                TransportClients = 1;
                ClientReady = Info.GameplayReady;
                ClientLocked = Info.ArkLoginLocked;
                ClientHasPlayerState = Info.PlayerStateReady;
                ClientHasHUD = Info.HUDReady;
                ClientHasPawn = Info.PawnReady;
                ReadyClients = ClientReady ? 1 : 0;
                LockedClients = ClientLocked ? 1 : 0;
                Diagnostics = Info.Description;
                PlayerInitialization = Info.PlayerInitialization;
            }
        }
        else if (ActiveRole == Role::Host && IsHosting && HostDriver)
        {
            const ArrayHeader Connections = Memory::GetInstance().Read<ArrayHeader>(
                reinterpret_cast<uintptr_t>(HostDriver)
                + SDKProfile::KnownBuild::UNetDriverClientConnections);
            if (Connections.Num >= 0 && Connections.Num <= 128
                && Connections.Max >= Connections.Num && Connections.Max <= 128
                && (Connections.Num == 0
                    || Memory::GetInstance().IsValid(
                        reinterpret_cast<uintptr_t>(Connections.Data))))
            {
                TransportClients = Connections.Num;
                for (int32 Index = 0; Index < Connections.Num; ++Index)
                {
                    void* Connection = ReadPointer(
                        reinterpret_cast<uintptr_t>(Connections.Data)
                        + sizeof(void*) * Index);
                    const ConnectionInfo Info = InspectConnection(Connection);
                    if (!Info.Valid)
                        continue;
                    ReadyClients += Info.GameplayReady ? 1 : 0;
                    LockedClients += Info.ArkLoginLocked ? 1 : 0;
                    if (Diagnostics.empty())
                    {
                        Diagnostics = Info.Description;
                        PlayerInitialization = Info.PlayerInitialization;
                    }
                }
            }
        }

        bool CharacterRPC = false;
        bool SpawnRPC = false;
        std::string RPCSummary;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            CharacterRPC = ClientCharacterCreationRPCSeen;
            SpawnRPC = ClientSpawnUIRPCSeen;
            RPCSummary = RPCDiagnostics;
        }
        std::ostringstream UIState;
        UIState << "CharacterCreationRPC=" << (CharacterRPC ? "seen" : "not-seen")
                << ", SpawnUIRPC=" << (SpawnRPC ? "seen" : "not-seen")
                << ", MyHUD=" << (ClientHasHUD ? "ready" : "null");
        if (!RPCSummary.empty()) UIState << ", calls={" << RPCSummary << "}";
        const std::string UIStateText = UIState.str();

        bool LogHostTransition = false;
        bool LogClientTransition = false;
        bool LogReturnTransportDetached = false;
        bool ClientReturnPending = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ConnectedClients = TransportClients;
            GameplayReadyClients = ReadyClients;
            ArkLoginLockedClients = LockedClients;
            ClientGameplayReady = ClientReady;
            ClientArkLoginLocked = ClientLocked;
            ClientPlayerStateReady = ClientHasPlayerState;
            ClientHUDReady = ClientHasHUD;
            ClientPawnReady = ClientHasPawn;
            if (ActiveRole == Role::Client)
            {
                if (ClientReturnToMenuPending)
                {
                    ClientTravelPending = true;
                    ClientState = ClientLifecycleState::Traveling;
                    if (TransportClients == 0
                        && !ClientReturnTransportDetachedLogged)
                    {
                        ClientReturnTransportDetachedLogged = true;
                        Status = "Server transport detached; awaiting MainMenu world";
                        LogReturnTransportDetached = true;
                    }
                }
                else if (TransportClients > 0)
                {
                    ClientTravelPending = false;
                    ClientState = ClientHasPawn
                        ? ClientLifecycleState::Playing
                        : ClientLifecycleState::Connected;
                    LastError.clear();
                }
                else if (ClientTravelPending)
                {
                    ClientState = ClientLifecycleState::Connecting;
                }
            }
            ClientReturnPending = ClientReturnToMenuPending;
            ConnectionDiagnostics = Diagnostics;
            PlayerInitializationDiagnostics = PlayerInitialization;
            GameStateDiagnostics = GameStateDetails;
            UIFlowDiagnostics = UIStateText;
            if (!GameModeIdentity.empty())
            {
                AuthorityGameModeIdentity = GameModeIdentity;
                GameModeGlobalDisableLoginLockCheck = GlobalDisable;
                GameModeTempDisableLoginLockCheck = TempDisable;
            }

            LogHostTransition = ActiveRole == Role::Host
                && (TransportClients != LastLoggedTransportClients
                    || ReadyClients != LastLoggedGameplayClients
                    || LockedClients != LastLoggedArkLockedClients);
            LogClientTransition = ActiveRole == Role::Client
                && (ClientReady != LastLoggedClientGameplayReady
                    || ClientLocked != LastLoggedClientArkLocked
                    || (TransportClients > 0 && LastLoggedTransportClients <= 0));
            LastLoggedTransportClients = TransportClients;
            LastLoggedGameplayClients = ReadyClients;
            LastLoggedArkLockedClients = LockedClients;
            LastLoggedClientGameplayReady = ClientReady;
            LastLoggedClientArkLocked = ClientLocked;
        }

        bool LogPlayerInitialization = false;
        bool LogGameState = false;
        bool LogUIState = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            std::string& LastPlayer = ActiveRole == Role::Host
                ? LastLoggedHostPlayerInitialization
                : LastLoggedClientPlayerInitialization;
            LogPlayerInitialization = !PlayerInitialization.empty()
                && PlayerInitialization != LastPlayer;
            if (LogPlayerInitialization) LastPlayer = PlayerInitialization;
            LogGameState = !GameStateDetails.empty()
                && GameStateDetails != LastLoggedGameStateDiagnostics;
            if (LogGameState) LastLoggedGameStateDiagnostics = GameStateDetails;
            LogUIState = ActiveRole == Role::Client
                && UIStateText != LastLoggedUIFlowDiagnostics;
            if (LogUIState) LastLoggedUIFlowDiagnostics = UIStateText;
        }

        if (LogReturnTransportDetached)
            AddLog("Return-to-menu transport detached; waiting for a MainMenu UWorld change",
                   LogLevel::Debug);
        if (LogHostTransition)
        {
            AddLog("Host connection state: transport="
                   + std::to_string(TransportClients)
                   + ", PlayerControllers-assigned=" + std::to_string(ReadyClients)
                   + ", ARK-login-locked=" + std::to_string(LockedClients));
            if (!Diagnostics.empty())
                AddLog("Host first connection: " + Diagnostics);
        }
        if (LogClientTransition && TransportClients > 0)
            AddLog("Client connection state: " + Diagnostics);
        if (LogPlayerInitialization)
            AddLog(std::string(ActiveRole == Role::Host ? "Host" : "Client")
                   + " player initialization: " + PlayerInitialization);
        if (LogGameState)
        {
            if (!GameModeDetails.empty()) AddLog("Authority flow: " + GameModeDetails);
            AddLog("Replicated flow: " + GameStateDetails);
        }
        if (LogUIState)
            AddLog("Client UI flow: " + UIStateText);
        if (ReappliedArkBypass)
            AddLog("ShooterGame reset bGlobalDisableLoginLockCheck; LAN host bypass was re-applied");
        if (ActiveRole == Role::Host && IsHosting && GameStateListenFlagKnown
            && !GameStateListenFlag)
        {
            AddLogOnce(LoggedLateListenStateMismatch,
                       "Late-listen state mismatch: UWorld has an active listen NetDriver, but ShooterGameState.bIsListenServer is still false. ShooterGame server startup ran earlier as standalone; no flag is being forced by this build");
        }

        if (ActiveRole == Role::Client && TransportClients > 0
            && !ClientReturnPending)
        {
            if (ClientHasPawn)
                SetStatus(ClientHasHUD ? "Pawn and HUD assigned" : "Pawn assigned; HUD is still null");
            else if (ClientReady && (CharacterRPC || SpawnRPC))
                SetStatus("Character/spawn UI flow reached; waiting for spawn selection/pawn");
            else if (ClientReady && !ClientHasPlayerState)
                SetStatus("PlayerController assigned; waiting for PlayerState");
            else if (ClientReady && !ClientHasHUD)
                SetStatus("PlayerController/PlayerState assigned; character/spawn UI RPC not observed");
            else if (ClientReady)
                SetStatus("PlayerController/HUD assigned; waiting for pawn or spawn UI");
            else if (ClientLocked)
                SetStatus("Transport connected; waiting for ARK login lock");
            else
                SetStatus("Transport connected; waiting for gameplay login/PlayerController");
        }
        else if (ActiveRole == Role::Host && TransportClients > ReadyClients)
        {
            SetStatus(LockedClients > 0
                ? "Client connected; ARK login lock is pending"
                : "Client connected; waiting for gameplay login/PlayerController");
        }
        else if (ActiveRole == Role::Host && ReadyClients > 0)
        {
            SetStatus("Client PlayerController assigned; character/spawn initialization pending");
        }
    }

    bool HostingRuntime::TryStartHosting(UWorld* World)
    {
        if (!World || !UWorldListen || !FMemory::EngineRealloc)
            return false;

        int32 RequestedPort = 7777;
        std::string RequestedMap;
        std::string RequestedPassword;
        bool RequestedArkLoginBypass = true;
        bool ForceDedicatedMode = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (CurrentRole != Role::Host || !HostPending || ListenAttemptInProgress
                || HostedWorld == World)
                return false;
            RequestedPort = Port;
            RequestedMap = MapName;
            RequestedPassword = Password;
            RequestedArkLoginBypass = BypassArkLoginLock;
            ForceDedicatedMode = ForceNetMode;
        }

        if (KnownProfileEligible)
        {
            const uintptr_t ImageBase = Memory::GetInstance().GetImageBase(Config::ImageName);
            void* LiveGWorld = ImageBase
                ? ReadPointer(ImageBase + SDKProfile::KnownBuild::GWorld)
                : nullptr;
            if (!LooksLikeUObject(LiveGWorld) || LiveGWorld != World)
            {
                SetStatus("Host waiting for a stable current GWorld");
                return false;
            }
        }

        bool DriverReady = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            DriverReady = NetDriverPatched;
            if (!DriverReady)
                HostPending = false;
        }
        if (!DriverReady)
        {
            SetStatus("Host not started: IP NetDriver was not confirmed");
            AddLog("Listen blocked because GameNetDriver fallback is not confirmed");
            return false;
        }

        UObject* WorldObject = static_cast<UObject*>(World);
        if (WorldObject->GetOffset("NetDriver") != static_cast<int32>(
                SDKProfile::KnownBuild::UWorldNetDriver))
        {
            SetError("Listen refused: UWorld::NetDriver layout is not confirmed");
            std::lock_guard<std::mutex> Guard(Mutex);
            HostPending = false;
            HostState = HostLifecycleState::Failed;
            return false;
        }
        UNetDriver* ExistingDriver = static_cast<UNetDriver*>(ReadPointer(
            reinterpret_cast<uintptr_t>(World)
            + SDKProfile::KnownBuild::UWorldNetDriver));
        if (LooksLikeUObject(ExistingDriver))
        {
            SetError("Listen refused: current UWorld already owns a NetDriver");
            AddLog("UWorld::Listen was not called because NetDriver already exists: "
                   + DescribeObject(ExistingDriver), LogLevel::Warning);
            std::lock_guard<std::mutex> Guard(Mutex);
            HostPending = false;
            HostState = HostLifecycleState::Failed;
            return false;
        }

        const std::string CurrentWorldName = WorldObject->NamePrivate.ToString();
        if (!RequestedMap.empty() && !CurrentWorldName.empty()
            && CurrentWorldName != RequestedMap)
            return false;
        if (CurrentWorldName.empty() && KnownProfileEligible)
            AddLogOnce(LoggedMissingWorldName,
                       "World name is unavailable; accepting the live SDK-profile world");

        if (RequestedArkLoginBypass && !ApplyArkLoginLockBypass(World))
        {
            {
                std::lock_guard<std::mutex> Guard(Mutex);
                HostPending = false;
            }
            SetStatus("Host not started: ARK login-lock bypass was not verified");
            AddLog("Listen blocked because the requested LAN login-lock bypass was not verified");
            return false;
        }
        if (!RequestedArkLoginBypass)
            AddLog("ARK login-lock bypass disabled by user; backend/EOS identity may be required");

        // Consume the request before entering UE. A failed Listen is not safe
        // to retry automatically because it may partially create or tear down
        // a NetDriver. The user must explicitly press Start hosting again.
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (!HostPending || ListenAttemptInProgress)
                return false;
            HostPending = false;
            ListenAttemptInProgress = true;
            HostState = HostLifecycleState::ListenStarting;
        }

        FURL URL{};
        URL.Port = RequestedPort;
        URL.Valid = 1;

        TFreedArray<FString> Options;
        Options.Add(FString(u"listen"));

        std::u16string PasswordOption;
        if (!RequestedPassword.empty())
        {
            const std::string Option = "ServerPassword=" + RequestedPassword;
            PasswordOption.assign(Option.begin(), Option.end());
            Options.Add(FString(PasswordOption.c_str()));
        }
        URL.Op = static_cast<TArray<FString>>(Options);

        AddLog("Calling UWorld::Listen on "
               + (CurrentWorldName.empty() ? RequestedMap : CurrentWorldName)
               + ":" + std::to_string(RequestedPort));
        const bool Result = UWorldListen(World, URL);

        // In this exact build UIpNetDriver::InitListen writes the port of the
        // successfully bound socket back to FURL::Port. MaxPortCountToTry may
        // therefore select a neighbouring port even when Listen returns true.
        // Publish the actual port instead of leaving the UI on the request.
        const int32 ActualPort = Result && URL.Port > 0 && URL.Port <= 65535
            ? URL.Port : 0;
        if (Result && ActualPort == 0)
            AddLog("Listen succeeded but returned an invalid bound port",
                   LogLevel::Error);
        else if (Result && ActualPort != RequestedPort)
            AddLog("IP NetDriver selected port " + std::to_string(ActualPort)
                   + " because requested port " + std::to_string(RequestedPort)
                   + " was unavailable", LogLevel::Warning);
        else if (Result)
            AddLog("IP NetDriver confirmed bound port "
                   + std::to_string(ActualPort));

        UNetDriver* StartedNetDriver = nullptr;
        if (Result)
        {
            int32 NetDriverOffset = WorldObject->GetOffset("NetDriver");
            if (NetDriverOffset <= 0 && KnownProfileEligible)
            {
                NetDriverOffset = static_cast<int32>(SDKProfile::KnownBuild::UWorldNetDriver);
                AddLogOnce(LoggedWorldNetDriverFallback,
                           "Using fresh SDK UWorld::NetDriver offset 0x1D8");
            }
            if (NetDriverOffset > 0 && NetDriverOffset < 0x2000)
            {
                StartedNetDriver = static_cast<UNetDriver*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(World) + NetDriverOffset));
                AddLog("UWorld::NetDriver offset: " + HexAddress(
                    static_cast<uintptr_t>(NetDriverOffset)));
            }
            else
            {
                AddLog("Listen succeeded, but reflected UWorld::NetDriver was not found");
            }
        }

        const WeakObjectIdentity StartedWorldIdentity = MakeWeakIdentity(World);
        const WeakObjectIdentity StartedDriverIdentity =
            MakeWeakIdentity(StartedNetDriver);
        bool ConfirmedHosting = Result && StartedWorldIdentity.IsSet()
            && StartedDriverIdentity.IsSet();
        if (ConfirmedHosting)
        {
            void* DriverWorld = ReadPointer(reinterpret_cast<uintptr_t>(StartedNetDriver)
                + SDKProfile::KnownBuild::UNetDriverWorld);
            ConfirmedHosting = DriverWorld == World;
        }
        if (Result && !ConfirmedHosting)
            AddLog("Listen returned true, but Hosted GameNetDriver ownership was not confirmed",
                   LogLevel::Error);

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            Hosting = ConfirmedHosting;
            HostPending = false;
            ListenAttemptInProgress = false;
            if (ConfirmedHosting)
            {
                HostedWorld = World;
                HostedNetDriver = StartedNetDriver;
                HostedWorldIdentity = StartedWorldIdentity;
                HostedNetDriverIdentity = StartedDriverIdentity;
                BoundPort = ActualPort;
            }
            else
                BoundPort = 0;
            HostState = ConfirmedHosting ? HostLifecycleState::Listening
                                         : HostLifecycleState::Failed;
            Status = ConfirmedHosting ? "UWorld::Listen succeeded"
                                      : "UWorld::Listen failed; explicit Start is required";
            if (!ConfirmedHosting)
                LastError = Result
                    ? "Listen driver ownership verification failed"
                    : "UWorld::Listen returned false";
        }
        HotHostedNetDriver.store(ConfirmedHosting ? StartedNetDriver : nullptr,
                                 std::memory_order_release);
        HotHosting.store(ConfirmedHosting, std::memory_order_release);
        AddLog(ConfirmedHosting ? "Hosting started"
                                : "UWorld::Listen failed; no automatic retry",
               ConfirmedHosting ? LogLevel::Info : LogLevel::Error);
        if (ConfirmedHosting && Addresses[7])
        {
            const uint64 CallsBefore = NetModeCallCount.load(
                std::memory_order_relaxed);
            const ENetMode ReportedMode = reinterpret_cast<UNetDriverGetNetModeFn>(
                Addresses[7])(StartedNetDriver);
            const uint64 CallsAfter = NetModeCallCount.load(
                std::memory_order_relaxed);
            const bool HookObserved = CallsAfter == CallsBefore + 1;
            const bool PolicyObserved = !ForceDedicatedMode
                || ReportedMode == ENetMode::DedicatedServer;
            AddLog("GetNetMode post-Listen health-check: hook="
                   + std::string(HookObserved ? "active" : "NOT OBSERVED")
                   + ", directResult=" + std::to_string(
                       static_cast<int32>(ReportedMode))
                   + ", expected=" + std::string(ForceDedicatedMode
                       ? "DedicatedServer(1)" : "engine policy")
                   + ", hostedDriver=" + DescribeObject(StartedNetDriver),
                   HookObserved && PolicyObserved
                       ? LogLevel::Info : LogLevel::Error);
            if (!HookObserved || !PolicyObserved)
                SetError("GetNetMode health-check failed after Listen");
        }
        return ConfirmedHosting;
    }

    UEngine* HostingRuntime::FindEngine()
    {
        if (!UObject::GUObjectArray || !FName::NamePoolData ||
            !FName::NamePoolData->Blocks[0] ||
            UObject::GUObjectArray->ObjObjects.Num() <= 0)
            return nullptr;

        const int32 Count = UObject::GUObjectArray->ObjObjects.Num();
        for (int32 Index = 0; Index < Count; ++Index)
        {
            UObject* Candidate = UObject::GUObjectArray->ObjObjects[Index];
            if (!Candidate || Candidate->NamePrivate.ToString() != "ShooterEngine")
                continue;

            std::string Identity;
            if (!ValidateLiveEngine(static_cast<UEngine*>(Candidate), &Identity))
                continue;

            bool ShouldLog = false;
            {
                std::lock_guard<std::mutex> Guard(Mutex);
                EngineIdentity = Identity;
                ShouldLog = !LoggedEngineIdentity;
                LoggedEngineIdentity = true;
            }
            if (ShouldLog)
                AddLog("Found live Engine "
                       + HexAddress(reinterpret_cast<uintptr_t>(Candidate)) + ": " + Identity);
            return static_cast<UEngine*>(Candidate);
        }
        return nullptr;
    }

    bool HostingRuntime::ValidateLiveEngine(UEngine* EnginePointer,
                                            std::string* Identity) const
    {
        auto SetIdentity = [Identity](const std::string& Value)
        {
            if (Identity)
                *Identity = Value;
        };

        if (!LooksLikeUObject(EnginePointer) || !UObject::GUObjectArray)
        {
            SetIdentity("invalid UObject pointer");
            return false;
        }

        UObject* Engine = static_cast<UObject*>(EnginePointer);
        if (Engine->InternalIndex < 0)
        {
            SetIdentity("negative InternalIndex");
            return false;
        }
        const FUObjectItem* Item = UObject::GUObjectArray->ObjObjects.IndexToObject(
            Engine->InternalIndex);
        if (!Item || Item->Object != Engine || Item->IsPendingKill() || Item->IsUnreachable())
        {
            SetIdentity("GUObjectArray identity/liveness check failed");
            return false;
        }
        if (Engine->IsDefaultObject())
        {
            SetIdentity("ClassDefaultObject " + Engine->GetFullName());
            return false;
        }
        if (!LooksLikeUObject(Engine->ClassPrivate)
            || !LooksLikeUObject(Engine->OuterPrivate))
        {
            SetIdentity("invalid class or outer pointer");
            return false;
        }

        const std::string ClassFullName = Engine->ClassPrivate->GetFullName();
        const std::string OuterName = Engine->OuterPrivate->GetName();
        const std::string BaseName = Engine->NamePrivate.ToString();
        if (ClassFullName != "Class ShooterGame.ShooterEngine"
            || OuterName != "Transient" || BaseName != "ShooterEngine")
        {
            SetIdentity("object=" + Engine->GetFullName()
                        + ", class=" + ClassFullName + ", outer=" + OuterName);
            return false;
        }

        SetIdentity("object=" + Engine->GetFullName()
                    + " (FName number=" + std::to_string(Engine->NamePrivate.GetNumber())
                    + "), class=" + ClassFullName + ", outer=" + OuterName);
        return true;
    }

    bool HostingRuntime::MakeName(const std::string& Value, FName& Result)
    {
        Result = FName{};
        if (!KnownProfileEligible || Value.empty() || !UObject::GUObjectArray)
        {
            AddLog("Conv_StringToName blocked: exact 1.10280 profile is not confirmed");
            return false;
        }

        UObject* Library = UObject::FindObject<UObject>(
            "KismetStringLibrary Engine.Default__KismetStringLibrary");
        UFunction* Function = UObject::FindObject<UFunction>(
            "Function Engine.KismetStringLibrary.Conv_StringToName",
            EClassCastFlags::Function);
        if (!Library || !Function || !LooksLikeUObject(Library)
            || !LooksLikeUObject(Function)
            || Function->ParmsSize != 0x18 || Function->ReturnValueOffset != 0x10)
        {
            AddLog("Conv_StringToName blocked: default object/function/parameter layout invalid");
            return false;
        }

        void** VTable = Library->VTable;
        if (!Memory::GetInstance().IsValid(reinterpret_cast<uintptr_t>(VTable)))
        {
            AddLog("Conv_StringToName blocked: Kismet vtable is invalid");
            return false;
        }
        void* ProcessEvent = VTable[SDKProfile::KnownBuild::ProcessEventIndex];
        const uintptr_t Expected = Memory::GetInstance().GetImageBase(Config::ImageName)
            + SDKProfile::KnownBuild::ProcessEvent;
        if (!Memory::GetInstance().IsValid(reinterpret_cast<uintptr_t>(ProcessEvent))
            || reinterpret_cast<uintptr_t>(ProcessEvent) != Expected)
        {
            AddLog("Conv_StringToName blocked: ProcessEvent vtable entry "
                   + HexAddress(reinterpret_cast<uintptr_t>(ProcessEvent))
                   + " does not match confirmed 0x250147C address "
                   + HexAddress(Expected));
            return false;
        }
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            ProcessEventAddress = Expected;
        }

        struct Params
        {
            FString InString;
            FName ReturnValue;
        };
        static_assert(sizeof(Params) == 0x18,
                      "Conv_StringToName parameter layout mismatch");

        const std::u16string Wide(Value.begin(), Value.end());
        Params Parameters{};
        Parameters.InString = FString(Wide.c_str());
        reinterpret_cast<void (*)(const UObject*, UFunction*, void*)>(ProcessEvent)(
            Library, Function, &Parameters);

        if (Parameters.ReturnValue.IsNone()
            || Parameters.ReturnValue.ToString() != Value)
        {
            AddLog("Conv_StringToName returned an invalid FName for " + Value);
            return false;
        }

        Result = Parameters.ReturnValue;
        AddLog("Created FName '" + Value + "' (ComparisonIndex="
               + std::to_string(Result.GetDisplayIndex()) + ", Number="
               + std::to_string(Result.GetNumber()) + ")");
        return true;
    }

    UWorld* HostingRuntime::FindWorld(UEngine* EnginePointer)
    {
        if (!EnginePointer)
            return nullptr;

        if (FName::NamePoolData && FName::NamePoolData->Blocks[0])
        {
            UObject* Engine = static_cast<UObject*>(EnginePointer);
            const int32 ViewportOffset = Engine->GetOffset("GameViewport");
            if (ViewportOffset > 0 && ViewportOffset < 0x2000)
            {
                UObject* Viewport = static_cast<UObject*>(ReadPointer(
                    reinterpret_cast<uintptr_t>(Engine) + ViewportOffset));
                if (LooksLikeUObject(Viewport))
                {
                    const int32 WorldOffset = Viewport->GetOffset("World");
                    if (WorldOffset > 0 && WorldOffset < 0x1000)
                    {
                        void* World = ReadPointer(reinterpret_cast<uintptr_t>(Viewport)
                                                  + WorldOffset);
                        if (LooksLikeUObject(World))
                            return static_cast<UWorld*>(World);
                    }
                }
            }
        }

        if (!KnownProfileEligible)
            return nullptr;

        // Primary SDK fallback: UEngine::GameViewport ->
        // UGameViewportClient::World. Both offsets came from the fresh dump.
        void* Viewport = ReadPointer(reinterpret_cast<uintptr_t>(EnginePointer)
            + SDKProfile::KnownBuild::UEngineGameViewport);
        if (LooksLikeUObject(Viewport))
        {
            void* World = ReadPointer(reinterpret_cast<uintptr_t>(Viewport)
                + SDKProfile::KnownBuild::UGameViewportClientWorld);
            if (LooksLikeUObject(World))
            {
                AddLogOnce(LoggedProfileWorld,
                           "World resolved through fresh SDK GameViewport fallback: "
                           + HexAddress(reinterpret_cast<uintptr_t>(World)));
                return static_cast<UWorld*>(World);
            }
        }

        // Independent fallback from Dumper-7's live GWorld scan. This also
        // covers the short interval in which GameViewport is not assigned.
        const uintptr_t ImageBase = Memory::GetInstance().GetImageBase(Config::ImageName);
        void* World = ImageBase ? ReadPointer(ImageBase + SDKProfile::KnownBuild::GWorld)
                                : nullptr;
        if (LooksLikeUObject(World))
        {
            AddLogOnce(LoggedGWorld,
                       "World resolved through fresh SDK GWorld fallback: "
                       + HexAddress(reinterpret_cast<uintptr_t>(World)));
            return static_cast<UWorld*>(World);
        }

        return nullptr;
    }

    bool HostingRuntime::PatchNetDriverDefinitions(UEngine* EnginePointer)
    {
        if (!EnginePointer)
            return false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (NetDriverPatched && CachedEngine == EnginePointer)
                return true;
        }
        if (!FName::NamePoolData || !FName::NamePoolData->Blocks[0])
        {
            AddLogOnce(LoggedNamePoolNotReady,
                       "Cannot patch GameNetDriver yet: FNamePool is not ready");
            return false;
        }

        std::string Identity;
        if (!ValidateLiveEngine(EnginePointer, &Identity))
        {
            SetStatus("IP NetDriver patch refused: Engine is not live ShooterEngine");
            AddLog("Patch IP NetDriver refused: " + Identity);
            return false;
        }

        UObject* Engine = static_cast<UObject*>(EnginePointer);
        const int32 ReflectedOffset = Engine->GetOffset("NetDriverDefinitions");
        int32 DefinitionsOffset = ReflectedOffset;
        if (DefinitionsOffset <= 0 && (Config::AllowKnownNetDriverDefinitionsOffset
                                      || KnownProfileEligible))
        {
            DefinitionsOffset = static_cast<int32>(Config::KnownNetDriverDefinitionsOffset);
            AddLogOnce(LoggedDefinitionsFallback,
                       "Using fresh SDK UEngine::NetDriverDefinitions offset 0xBF8");
        }
        if (DefinitionsOffset <= 0 || DefinitionsOffset >= 0x2000)
            return false;

        if (!KnownProfileEligible
            || DefinitionsOffset != static_cast<int32>(
                SDKProfile::KnownBuild::UEngineNetDriverDefinitions))
        {
            SetStatus("IP NetDriver patch refused: exact SDK/signature profile mismatch");
            AddLog("Patch refused: NetDriverDefinitions reflected/static offset mismatch "
                   "(reflected=" + HexAddress(static_cast<uintptr_t>(ReflectedOffset))
                   + ", selected=" + HexAddress(static_cast<uintptr_t>(DefinitionsOffset))
                   + ", expected=0xbf8)");
            return false;
        }

        const uintptr_t DefinitionsAddress = reinterpret_cast<uintptr_t>(Engine)
            + DefinitionsOffset;
        ArrayHeader Header = Memory::GetInstance().Read<ArrayHeader>(DefinitionsAddress);
        bool WasPatched = false;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            WasPatched = NetDriverPatched;
            EngineIdentity = Identity;
            NetDriverDefinitionsOffset = DefinitionsOffset;
            NetDriverDefinitionsData = reinterpret_cast<uintptr_t>(Header.Data);
            NetDriverDefinitionsNum = Header.Num;
            NetDriverDefinitionsMax = Header.Max;
        }
        if (!WasPatched)
        {
            AddLog("NetDriverDefinitions reflected/static offset: reflected="
                   + HexAddress(static_cast<uintptr_t>(ReflectedOffset))
                   + ", selected=" + HexAddress(static_cast<uintptr_t>(DefinitionsOffset)));
            AddLog("NetDriverDefinitions before patch: data="
                   + HexAddress(reinterpret_cast<uintptr_t>(Header.Data))
                   + ", num=" + std::to_string(Header.Num)
                   + ", max=" + std::to_string(Header.Max));
        }

        const bool CanonicalEmpty = !Header.Data && Header.Num == 0 && Header.Max == 0;
        const bool ReservedEmpty = Header.Data && Header.Num == 0
            && Header.Max > 0 && Header.Max <= 128
            && Memory::GetInstance().IsValid(reinterpret_cast<uintptr_t>(Header.Data));
        const bool Populated = Header.Data && Header.Num > 0
            && Header.Num <= Header.Max && Header.Max <= 128
            && Memory::GetInstance().IsValid(reinterpret_cast<uintptr_t>(Header.Data));
        if (!CanonicalEmpty && !ReservedEmpty && !Populated)
        {
            AddLogOnce(LoggedDefinitionsInvalid,
                       "NetDriverDefinitions is invalid at "
                       + HexAddress(static_cast<uintptr_t>(DefinitionsOffset))
                       + " (data=" + HexAddress(reinterpret_cast<uintptr_t>(Header.Data))
                       + ", num=" + std::to_string(Header.Num)
                       + ", max=" + std::to_string(Header.Max) + ")");
            return false;
        }

        UClass* IpClass = UObject::FindClass("Class OnlineSubsystemUtils.IpNetDriver");
        UClass* EOSClass = UObject::FindClass("Class OnlineSubsystemEOS.NetDriverEOS");
        UClass* EOSBaseClass = UObject::FindClass(
            "Class SocketSubsystemEOS.NetDriverEOSBase");
        if (!WasPatched)
        {
            AddLog("Resolved NetDriver classes: IpNetDriver="
                   + HexAddress(reinterpret_cast<uintptr_t>(IpClass))
                   + ", NetDriverEOS=" + HexAddress(reinterpret_cast<uintptr_t>(EOSClass))
                   + ", NetDriverEOSBase="
                   + HexAddress(reinterpret_cast<uintptr_t>(EOSBaseClass)));
            AddLog(std::string("Selected class path: primary=") + IpNetDriverPath
                   + ", fallback=" + IpNetDriverPath
                   + " (ordinary IP requested; cooked game config uses EOS primary)");
        }
        if (!IpClass || !LooksLikeUObject(IpClass))
        {
            SetStatus("IP NetDriver patch refused: UIpNetDriver UClass not found");
            AddLog("Patch IP NetDriver result: refused (IpNetDriver UClass invalid)");
            return false;
        }

        for (int32 Index = 0; Index < Header.Num; ++Index)
        {
            const uintptr_t EntryAddress = reinterpret_cast<uintptr_t>(Header.Data)
                + static_cast<uintptr_t>(Index) * sizeof(FNetDriverDefinition);
            FNetDriverDefinition Definition =
                Memory::GetInstance().Read<FNetDriverDefinition>(EntryAddress);
            if (Definition.DefName.ToString() != GameNetDriverName)
                continue;

            if (!WasPatched)
            {
                AddLog("NetDriverDefinitions offset: "
                       + HexAddress(static_cast<uintptr_t>(DefinitionsOffset)));
                AddLog("GameNetDriver primary: " + Definition.DriverClassName.ToString());
                AddLog("GameNetDriver fallback: "
                       + Definition.DriverClassNameFallback.ToString());
            }

            const std::string Primary = Definition.DriverClassName.ToString();
            const std::string Fallback = Definition.DriverClassNameFallback.ToString();
            if (!IsIpNetDriverPath(Fallback))
            {
                SetStatus("GameNetDriver fallback is not the confirmed IP driver");
                AddLog("Patch IP NetDriver result: refused; fallback path is " + Fallback);
                return false;
            }

            if (!IsIpNetDriverPath(Primary))
                Memory::GetInstance().Write<FName>(
                    EntryAddress + offsetof(FNetDriverDefinition, DriverClassName),
                    Definition.DriverClassNameFallback);

            const FNetDriverDefinition Verified =
                Memory::GetInstance().Read<FNetDriverDefinition>(EntryAddress);
            const bool Ready = Verified.DefName.ToString() == GameNetDriverName
                && IsIpNetDriverPath(Verified.DriverClassName.ToString())
                && IsIpNetDriverPath(Verified.DriverClassNameFallback.ToString());
            {
                std::lock_guard<std::mutex> Guard(Mutex);
                NetDriverPatched = Ready;
                NetDriverClassPath = Verified.DriverClassName.ToString();
            }
            if (!WasPatched || !Ready)
            {
                AddLog("GameNetDriver re-read: DefName=" + Verified.DefName.ToString()
                       + ", primary=" + Verified.DriverClassName.ToString()
                       + ", fallback=" + Verified.DriverClassNameFallback.ToString());
                AddLog(std::string("Patch IP NetDriver result: ")
                       + (Ready ? "confirmed (existing entry)" : "failed verification"));
            }
            if (!WasPatched || !Ready)
            {
                SetStatus(Ready ? "IP GameNetDriver confirmed"
                                : "IP GameNetDriver verification failed");
            }
            return Ready;
        }

        if (Header.Num != 0)
        {
            std::string Names = "No GameNetDriver entry; definitions="
                + std::to_string(Header.Num) + ":";
            for (int32 Index = 0; Index < Header.Num && Index < 16; ++Index)
            {
                const uintptr_t EntryAddress = reinterpret_cast<uintptr_t>(Header.Data)
                    + static_cast<uintptr_t>(Index) * sizeof(FNetDriverDefinition);
                const FNetDriverDefinition Entry =
                    Memory::GetInstance().Read<FNetDriverDefinition>(EntryAddress);
                Names += " [" + std::to_string(Index) + "]=" + Entry.DefName.ToString();
            }
            AddLogOnce(LoggedDefinitionsNoMatch, Names);
            SetStatus("IP NetDriver patch refused: non-empty array has no GameNetDriver");
            return false;
        }

        if (!FMemory::EngineRealloc)
        {
            SetStatus("IP NetDriver patch refused: FMemory::Realloc unresolved");
            return false;
        }

        FNetDriverDefinition NewDefinition{};
        if (!MakeName(GameNetDriverName, NewDefinition.DefName)
            || !MakeName(IpNetDriverPath, NewDefinition.DriverClassName)
            || !MakeName(IpNetDriverPath, NewDefinition.DriverClassNameFallback))
        {
            SetStatus("IP NetDriver patch refused: FName creation failed");
            AddLog("Patch IP NetDriver result: refused (FName creation failed)");
            return false;
        }

        void* Data = Header.Data;
        bool OwnsUncommittedAllocation = false;
        if (!Data)
        {
            Data = FMemory::Malloc(sizeof(FNetDriverDefinition),
                                   alignof(FNetDriverDefinition));
            OwnsUncommittedAllocation = Data != nullptr;
        }
        if (!Data || !Memory::GetInstance().IsValid(reinterpret_cast<uintptr_t>(Data)))
        {
            if (Data && OwnsUncommittedAllocation)
                FMemory::Free(Data);
            SetStatus("IP NetDriver patch refused: FMemory allocation failed");
            return false;
        }

        Memory::GetInstance().Write<FNetDriverDefinition>(
            reinterpret_cast<uintptr_t>(Data), NewDefinition);
        const FNetDriverDefinition Staged =
            Memory::GetInstance().Read<FNetDriverDefinition>(
                reinterpret_cast<uintptr_t>(Data));
        if (Staged.DefName.ToString() != GameNetDriverName
            || !IsIpNetDriverPath(Staged.DriverClassName.ToString())
            || !IsIpNetDriverPath(Staged.DriverClassNameFallback.ToString()))
        {
            if (OwnsUncommittedAllocation)
                FMemory::Free(Data);
            SetStatus("IP NetDriver patch refused: staged entry write failed");
            AddLog("Patch IP NetDriver result: refused before TArray commit");
            return false;
        }

        const ArrayHeader Committed{Data, 1, Header.Max > 0 ? Header.Max : 1};
        Memory::GetInstance().Write<ArrayHeader>(DefinitionsAddress, Committed);

        const ArrayHeader VerifiedHeader =
            Memory::GetInstance().Read<ArrayHeader>(DefinitionsAddress);
        FNetDriverDefinition Verified{};
        if (VerifiedHeader.Data
            && Memory::GetInstance().IsValid(
                reinterpret_cast<uintptr_t>(VerifiedHeader.Data)))
        {
            Verified = Memory::GetInstance().Read<FNetDriverDefinition>(
                reinterpret_cast<uintptr_t>(VerifiedHeader.Data));
        }
        const bool Ready = VerifiedHeader.Data == Data && VerifiedHeader.Num == 1
            && VerifiedHeader.Max >= 1
            && Verified.DefName.ToString() == GameNetDriverName
            && IsIpNetDriverPath(Verified.DriverClassName.ToString())
            && IsIpNetDriverPath(Verified.DriverClassNameFallback.ToString());

        if (!Ready && OwnsUncommittedAllocation
            && (VerifiedHeader.Data != Data || VerifiedHeader.Num == 0))
            FMemory::Free(Data);

        {
            std::lock_guard<std::mutex> Guard(Mutex);
            NetDriverPatched = Ready;
            NetDriverClassPath = Ready ? Verified.DriverClassName.ToString() : "";
            NetDriverDefinitionsData = reinterpret_cast<uintptr_t>(VerifiedHeader.Data);
            NetDriverDefinitionsNum = VerifiedHeader.Num;
            NetDriverDefinitionsMax = VerifiedHeader.Max;
        }
        AddLog("NetDriverDefinitions after injection: data="
               + HexAddress(reinterpret_cast<uintptr_t>(VerifiedHeader.Data))
               + ", num=" + std::to_string(VerifiedHeader.Num)
               + ", max=" + std::to_string(VerifiedHeader.Max));
        AddLog("Injected entry re-read: DefName=" + Verified.DefName.ToString()
               + " (ComparisonIndex="
               + std::to_string(Verified.DefName.GetDisplayIndex()) + ")"
               + ", primary=" + Verified.DriverClassName.ToString()
               + " (ComparisonIndex="
               + std::to_string(Verified.DriverClassName.GetDisplayIndex()) + ")"
               + ", fallback=" + Verified.DriverClassNameFallback.ToString()
               + " (ComparisonIndex="
               + std::to_string(Verified.DriverClassNameFallback.GetDisplayIndex()) + ")");
        AddLog(std::string("Patch IP NetDriver result: ")
               + (Ready ? "confirmed (new engine-owned entry)"
                        : "failed post-write verification"));
        SetStatus(Ready ? "IP GameNetDriver created and confirmed"
                        : "IP GameNetDriver injection verification failed");
        return Ready;
    }

    RuntimeSnapshot HostingRuntime::Snapshot() const
    {
        int32 CommandCount = 0;
        {
            std::lock_guard<std::mutex> Guard(CommandMutex);
            CommandCount = static_cast<int32>(PendingCommands.size());
        }
        std::lock_guard<std::mutex> Guard(Mutex);
        RuntimeSnapshot Result;
        Result.CurrentRole = CurrentRole;
        Result.HostState = HostState;
        Result.ClientState = ClientState;
        Result.ModePolicy = ModePolicy;
        Result.ForceNetMode = ForceNetMode;
        Result.HostPending = HostPending;
        Result.ListenAttemptInProgress = ListenAttemptInProgress;
        Result.Hosting = Hosting;
        Result.StopAvailable = Hosting && CurrentRole == Role::Host
            && HostedWorld && HostedNetDriver && DestroyNamedNetDriver
            && !ListenAttemptInProgress;
        Result.GameThreadConfirmed = GameThreadToken.load(
            std::memory_order_acquire) != 0;
        Result.GameThreadDispatchAvailable = GameThreadDispatchAvailable;
        Result.NetDriverPatched = NetDriverPatched;
        Result.IOSAppOnMac = IOSAppOnMac;
        Result.BypassArkLoginLock = BypassArkLoginLock;
        Result.ArkLoginBypassApplied = ArkLoginBypassApplied;
        Result.GameModeGlobalDisableLoginLockCheck =
            GameModeGlobalDisableLoginLockCheck;
        Result.GameModeTempDisableLoginLockCheck =
            GameModeTempDisableLoginLockCheck;
        Result.ClientGameplayReady = ClientGameplayReady;
        Result.ClientArkLoginLocked = ClientArkLoginLocked;
        Result.ProcessEventDiagnosticsInstalled = ProcessEventDiagnosticsInstalled;
        Result.ClientPlayerStateReady = ClientPlayerStateReady;
        Result.ClientHUDReady = ClientHUDReady;
        Result.ClientPawnReady = ClientPawnReady;
        Result.ClientCharacterCreationRPCSeen = ClientCharacterCreationRPCSeen;
        Result.ClientSpawnUIRPCSeen = ClientSpawnUIRPCSeen;
        Result.ClientTravelPending = ClientTravelPending;
        Result.ClientReturnToMenuPending = ClientReturnToMenuPending;
        Result.TargetedPlayerFlowAddressesValidated =
            TargetedPlayerFlowAddressesValidated;
        Result.TargetedPlayerFlowHooksInstalled = TargetedPlayerFlowHooksInstalled;
        Result.ClientUIRecoveryAttempted = ClientUIRecoveryAttempted;
        Result.ObjectCount = ObjectCount;
        Result.ConnectedClients = ConnectedClients;
        Result.GameplayReadyClients = GameplayReadyClients;
        Result.ArkLoginLockedClients = ArkLoginLockedClients;
        Result.Port = BoundPort > 0 ? BoundPort : Port;
        Result.RequestedPort = Port;
        Result.BoundPort = BoundPort;
        Result.QueuedCommands = CommandCount;
        Result.GetNetModeCalls = NetModeCallCount.load(std::memory_order_relaxed);
        Result.HostedNetModeCalls = HostedNetModeCallCount.load(
            std::memory_order_relaxed);
        Result.ForcedDedicatedCalls = ForcedDedicatedCallCount.load(
            std::memory_order_relaxed);
        Result.HostedOriginalStandaloneCalls =
            HostedOriginalStandaloneCallCount.load(std::memory_order_relaxed);
        Result.HostedOriginalDedicatedCalls =
            HostedOriginalDedicatedCallCount.load(std::memory_order_relaxed);
        Result.HostedOriginalListenCalls =
            HostedOriginalListenCallCount.load(std::memory_order_relaxed);
        Result.HostedOriginalClientCalls =
            HostedOriginalClientCallCount.load(std::memory_order_relaxed);
        Result.LastHostedOriginalMode = static_cast<ENetMode>(
            LastHostedOriginalMode.load(std::memory_order_relaxed));
        Result.MapName = MapName;
        Result.WorldName = WorldName;
        Result.Status = Status;
        Result.LastError = LastError;
        Result.Engine = reinterpret_cast<uintptr_t>(CachedEngine);
        Result.World = reinterpret_cast<uintptr_t>(CachedWorld);
        Result.NetDriver = reinterpret_cast<uintptr_t>(HostedNetDriver);
        Result.ProcessEvent = ProcessEventAddress;
        Result.NetDriverDefinitionsData = NetDriverDefinitionsData;
        Result.NetDriverDefinitionsOffset = NetDriverDefinitionsOffset;
        Result.NetDriverDefinitionsNum = NetDriverDefinitionsNum;
        Result.NetDriverDefinitionsMax = NetDriverDefinitionsMax;
        Result.EngineIdentity = EngineIdentity;
        Result.AuthorityGameModeIdentity = AuthorityGameModeIdentity;
        Result.ConnectionDiagnostics = ConnectionDiagnostics;
        Result.PlayerInitializationDiagnostics = PlayerInitializationDiagnostics;
        Result.GameStateDiagnostics = GameStateDiagnostics;
        Result.UIFlowDiagnostics = UIFlowDiagnostics;
        Result.RPCDiagnostics = RPCDiagnostics;
        Result.PlayerUIRecoveryDiagnostics = PlayerUIRecoveryDiagnostics;
        Result.NetDriverClassPath = NetDriverClassPath;
        Result.Addresses = Addresses;
        Result.Players = PlayerSummaries;
        Result.LogEntries = StructuredLog;
        Result.Log = Log;
        return Result;
    }

    void HostingRuntime::AddLog(const std::string& Message, LogLevel Level)
    {
        const std::string SafeMessage = RedactSecrets(Message);
        const LogLevel EffectiveLevel = Level == LogLevel::Info
            && SafeMessage.find("0x") != std::string::npos
            ? LogLevel::Debug : Level;
        std::string Decorated;
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            const auto Elapsed = std::chrono::duration<double>(
                std::chrono::steady_clock::now() - RuntimeStartedAt).count();
            std::ostringstream Stream;
            Stream << "#" << std::setfill('0') << std::setw(4) << ++LogSequence
                   << " +" << std::fixed << std::setprecision(3) << Elapsed
                   << "s " << SafeMessage;
            Decorated = Stream.str();
            Log.push_back(Decorated);
            StructuredLog.push_back({EffectiveLevel, Decorated});
            if (Log.size() > 512)
                Log.erase(Log.begin(), Log.begin() + (Log.size() - 512));
            if (StructuredLog.size() > 512)
                StructuredLog.erase(StructuredLog.begin(),
                    StructuredLog.begin() + (StructuredLog.size() - 512));
        }
        std::fprintf(stderr, "[ServerHost] %s\n", Decorated.c_str());
    }

    void HostingRuntime::AddLogOnce(bool& Flag, const std::string& Message,
                                    LogLevel Level)
    {
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            if (Flag)
                return;
            Flag = true;
        }
        AddLog(Message, Level);
    }

    void HostingRuntime::SetStatus(const std::string& Message)
    {
        std::lock_guard<std::mutex> Guard(Mutex);
        Status = Message;
    }

    void HostingRuntime::SetError(const std::string& Message)
    {
        {
            std::lock_guard<std::mutex> Guard(Mutex);
            LastError = RedactSecrets(Message);
            Status = LastError;
        }
        AddLog(Message, LogLevel::Error);
    }

    void HostingRuntime::ClearLogs()
    {
        std::lock_guard<std::mutex> Guard(Mutex);
        Log.clear();
        StructuredLog.clear();
    }
}

__attribute__((constructor))
static void InitializeServerHostRuntime()
{
    ServerHost::HostingRuntime::Get().Initialize();
}
