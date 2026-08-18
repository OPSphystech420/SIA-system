#pragma once

#include "HostingTypes.hpp"

#include <array>
#include <atomic>
#include <chrono>
#include <deque>
#include <mutex>
#include <string>
#include <vector>

class UObject;
class UFunction;
class UClass;
class UEngine;
class UWorld;
class UNetDriver;
class AActor;
class AShooterPlayerController;

namespace ServerHost
{
    enum class Role : uint8 { Disabled, Host, Client };

    enum class HostLifecycleState : uint8
    {
        Disabled, Resolving, Ready, HostRequested, PatchingNetDriver,
        ListenStarting, Listening, AcceptingClients, Stopping, Stopped, Failed
    };

    enum class ClientLifecycleState : uint8
    {
        Disabled, Ready, TravelRequested, Traveling, Connecting, Connected,
        Playing, Disconnected, Failed
    };

    enum class RecoveryState : uint8
    {
        Discovered, WaitingForPlayerState, EligibleForRecovery, RPC1Sent,
        RPC2Sent, AwaitingPlayerData, AwaitingPawn, Playing, Completed,
        TimedOut, Disconnected, WorldChanged, Failed
    };

    enum class NetModePolicy : uint8
    {
        AutomaticListenServer,
        DedicatedServerExperimental
    };

    enum class LogLevel : uint8 { Info, Warning, Error, Debug };

    struct WeakObjectIdentity
    {
        uintptr_t Pointer = 0;
        int32 ObjectIndex = -1;
        int32 SerialNumber = 0;

        bool IsSet() const
        {
            return Pointer != 0 && ObjectIndex >= 0 && SerialNumber != 0;
        }
    };

    struct RuntimeLogEntry
    {
        LogLevel Level = LogLevel::Info;
        std::string Text;
    };

    enum class PersistentIdentityResult : uint8
    {
        Unavailable,
        DispatchRejected,
        Invalid,
        Empty,
        Present
    };

    struct PlayerSummary
    {
        std::string StableId;
        std::string PlayerName;
        std::string Controller;
        std::string PlayerState;
        std::string Pawn;
        std::string StateName;
        std::string Recovery;
        std::string OnlineIdentity;
        std::string PersistentIdentityValue;
        std::string SavedNetworkAddress;
        uint64 PlayerDataId = 0;
        int32 PlayerDataIdentityBytes = 0;
        int32 PlayerStateIdentityBytes = 0;
        int32 ConnectionIdentityBytes = 0;
        double ReceiveAgeSeconds = 0.0;
        int32 PlayerId = -1;
        bool Waiting = false;
        bool HasPlayerData = false;
        bool Playing = false;
        bool ReceiveTimingValid = false;
        bool Responsive = true;
        PersistentIdentityResult PersistentIdentity =
            PersistentIdentityResult::Unavailable;
        bool ArkPassKnown = false;
        bool HasArkPass = false;
        bool IsAdmin = false;
        bool IsCheatPlayer = false;
    };

    struct RuntimeSnapshot
    {
        Role CurrentRole = Role::Disabled;
        HostLifecycleState HostState = HostLifecycleState::Disabled;
        ClientLifecycleState ClientState = ClientLifecycleState::Disabled;
        NetModePolicy ModePolicy = NetModePolicy::AutomaticListenServer;
        bool ForceNetMode = false;
        bool HostPending = false;
        bool ListenAttemptInProgress = false;
        bool Hosting = false;
        bool StopAvailable = false;
        bool GameThreadConfirmed = false;
        bool GameThreadDispatchAvailable = false;
        bool NetDriverPatched = false;
        bool IOSAppOnMac = false;
        bool BypassArkLoginLock = true;
        bool ArkLoginBypassApplied = false;
        bool GameModeGlobalDisableLoginLockCheck = false;
        bool GameModeTempDisableLoginLockCheck = false;
        bool ClientGameplayReady = false;
        bool ClientArkLoginLocked = false;
        bool ProcessEventDiagnosticsInstalled = false;
        bool ClientPlayerStateReady = false;
        bool ClientHUDReady = false;
        bool ClientPawnReady = false;
        bool ClientCharacterCreationRPCSeen = false;
        bool ClientSpawnUIRPCSeen = false;
        bool ClientTravelPending = false;
        bool ClientReturnToMenuPending = false;
        bool TargetedPlayerFlowAddressesValidated = false;
        bool TargetedPlayerFlowHooksInstalled = false;
        bool ClientUIRecoveryAttempted = false;
        int32 ObjectCount = 0;
        int32 ConnectedClients = 0;
        int32 GameplayReadyClients = 0;
        int32 ArkLoginLockedClients = 0;
        int32 Port = 7777;
        int32 RequestedPort = 7777;
        int32 BoundPort = 0;
        int32 QueuedCommands = 0;
        uint64 GetNetModeCalls = 0;
        uint64 HostedNetModeCalls = 0;
        uint64 ForcedDedicatedCalls = 0;
        uint64 HostedOriginalStandaloneCalls = 0;
        uint64 HostedOriginalDedicatedCalls = 0;
        uint64 HostedOriginalListenCalls = 0;
        uint64 HostedOriginalClientCalls = 0;
        ENetMode LastHostedOriginalMode = ENetMode::Max;
        std::string MapName = "TheIsland";
        std::string WorldName;
        std::string Status;
        std::string LastError;
        uintptr_t Engine = 0;
        uintptr_t World = 0;
        uintptr_t NetDriver = 0;
        uintptr_t ProcessEvent = 0;
        uintptr_t NetDriverDefinitionsData = 0;
        int32 NetDriverDefinitionsOffset = 0;
        int32 NetDriverDefinitionsNum = 0;
        int32 NetDriverDefinitionsMax = 0;
        std::string EngineIdentity;
        std::string AuthorityGameModeIdentity;
        std::string ConnectionDiagnostics;
        std::string PlayerInitializationDiagnostics;
        std::string GameStateDiagnostics;
        std::string UIFlowDiagnostics;
        std::string RPCDiagnostics;
        std::string PlayerUIRecoveryDiagnostics;
        std::string NetDriverClassPath;
        std::array<uintptr_t, 9> Addresses{};
        std::vector<PlayerSummary> Players;
        std::vector<RuntimeLogEntry> LogEntries;
        std::vector<std::string> Log;
    };

    class HostingRuntime
    {
    public:
        static HostingRuntime& Get();

        void Initialize();
        // Called by the Metal view: only schedules a task for UE's game thread.
        void Tick();

        void RequestHost(int32 Port, const std::string& MapName,
                         const std::string& Password, bool ForceDedicatedMode,
                         bool BypassArkLoginLock);
        void RequestStop();
        void Disable();
        bool Join(const std::string& Endpoint, const std::string& Password,
                  bool ForceClientMode = false);
        void RequestReturnToMenu();
        bool PatchCurrentNetDriver();
        bool RecoverRemotePlayerUI();
        void RequestBroadcast(const std::string& Message);
        void RequestSaveWorld();
        void RequestSetRuntimeAdmin(const std::string& StablePlayerId,
                                    bool Enable);
        void RequestAdminCheat(const std::string& StablePlayerId,
                               const std::string& Action);
        void RequestKick(const std::string& StablePlayerId,
                         const std::string& Reason);
        void RequestConsoleCommand(const std::string& Command);
#if SERVERHOST_DEVELOPER_UI
        // Queues one harmless reflected-call example for execution on the UE
        // game thread. The implementation is an editable developer template.
        void RequestDeveloperProcessEventExample();
        // Executes ShooterGame's own aimed-harvest spatial query for one
        // selected remote controller. This is read-only differential
        // diagnostics for the late-listen stasis/streaming investigation.
        void RequestDeveloperHarvestProbe(const std::string& StablePlayerId);
#endif
        void ClearLogs();

        RuntimeSnapshot Snapshot() const;

        void OnEngineInit(UEngine* Engine);
        void OnWorldBeginPlay(UWorld* World);
        // Returns true when the exact mobile ShooterGame PostLogin gap was
        // handled through the validated RealPostLogin implementation.
        bool RouteHostedPostLogin(UObject* GameMode, UObject* PlayerController);
        ENetMode ResolveNetMode(UNetDriver* NetDriver,
                               ENetMode OriginalMode,
                               uintptr_t CallerAddress) const;
        void OnDiagnosticProcessEvent(int32 EventIndex, UObject* Context,
                                      UFunction* Function, void* Parameters,
                                      bool AfterOriginal);
        void OnNativeHandleNewPlayer(void* GameMode, void* PlayerController,
                                     void* PlayerData, void* PlayerCharacter,
                                     bool FromLogin, bool AfterOriginal,
                                     bool ReturnValue);
        void OnNativeClientHUDInit(void* PlayerController, void* HUDClass,
                                   bool AfterOriginal);
        void OnNativeCharacterCreationUI(void* PlayerController,
                                         bool ShowDownloadCharacter,
                                         bool AfterOriginal);
        void OnNativeSpawnUI(void* PlayerController, float Delay,
                             bool AfterOriginal);
        void OnNativeCharacterUICallback(void* HUD, bool AfterOriginal,
                                         uintptr_t ReturnValue);

    private:
        HostingRuntime() = default;
        HostingRuntime(const HostingRuntime&) = delete;
        HostingRuntime& operator=(const HostingRuntime&) = delete;

        enum class CommandType : uint8
        {
            StartHost, StopHost, Disable, Join, PatchNetDriver, ManualRecovery,
            ReturnToMenu, Broadcast, SaveWorld, SetRuntimeAdmin, AdminCheat,
            Kick, Console
#if SERVERHOST_DEVELOPER_UI
            , DeveloperProcessEventExample, DeveloperHarvestProbe
#endif
        };

        struct RuntimeCommand
        {
            CommandType Type = CommandType::Disable;
            int32 Port = 0;
            bool FlagA = false;
            bool FlagB = false;
            std::string Primary;
            std::string Secondary;
            std::string Secret;
        };

        struct ClientRecoveryRecord
        {
            WeakObjectIdentity Connection;
            WeakObjectIdentity PlayerController;
            WeakObjectIdentity PlayerState;
            RecoveryState State = RecoveryState::Discovered;
            int32 DispatchAttempts = 0;
            bool SeenThisScan = false;
            bool PersistenceWarningLogged = false;
            bool PersistenceLookupLogged = false;
            bool StasisSnapshotLogged = false;
            bool NativePostLoginRouted = false;
            std::string StableId;
            std::string LastError;
            std::chrono::steady_clock::time_point DiscoveredAt{};
            std::chrono::steady_clock::time_point StateChangedAt{};
            std::chrono::steady_clock::time_point RPCSentAt{};
            std::chrono::steady_clock::time_point NativePostLoginAt{};
        };

        bool ResolveRuntimeAddresses();
        bool InstallHooks();
        bool InstallTargetedPlayerFlowHooks();
        void ScheduleGameThreadTick();
        void GameThreadTick();
        void MarkGameThread();
        bool IsOnGameThread() const;
        bool Enqueue(RuntimeCommand&& Command);
        void DrainCommands();
        void ExecuteHostRequest(const RuntimeCommand& Command);
        void ExecuteDisable();
        void ExecuteJoin(const RuntimeCommand& Command);
        void ExecuteReturnToMenu();
        bool ExecutePatchCurrentNetDriver();
        bool ExecuteManualRecovery();
        void ExecuteStop();
        bool ExecuteSaveWorld();
        void ExecuteBroadcast(const std::string& Message);
        void ExecuteSetRuntimeAdmin(const std::string& StableId, bool Enable);
        void ExecuteAdminCheat(const std::string& StableId,
                               const std::string& Action);
        void ExecuteKick(const std::string& StableId, const std::string& Reason);
        void ExecuteConsole(const std::string& Command);
#if SERVERHOST_DEVELOPER_UI
        void ExecuteDeveloperProcessEventExample();
        void ExecuteDeveloperHarvestProbe(const std::string& StableId);
#endif
        bool TryStartHosting(UWorld* World);
        void HandleWorldChanged(UWorld* PreviousWorld, UWorld* NewWorld);
        void UpdateRecoveryState(UWorld* World, UNetDriver* HostDriver);
        void LogStasisRegistrationSnapshot(UWorld* World,
                                           ClientRecoveryRecord& Record,
                                           AShooterPlayerController* PlayerController,
                                           AActor* Pawn);
        void LogPlayerPersistenceLookupSnapshot(
            ClientRecoveryRecord& Record, const PlayerSummary& Incoming);
        bool DispatchRecoveryRPCs(ClientRecoveryRecord& Record,
                                  UObject* PlayerController,
                                  UObject* PlayerState,
                                  void* Connection);
        bool PopulatePlayerPersistence(UObject* PlayerData,
                                       PlayerSummary& Summary);
        bool PopulatePlayerOnlineIdentity(UObject* PlayerState,
                                          UObject* PlayerController,
                                          void* Connection,
                                          PlayerSummary& Summary);
        void TransitionRecovery(ClientRecoveryRecord& Record,
                                RecoveryState State,
                                const std::string& Detail = {});
        void ResetWorldDependentCaches();
        UObject* GetAuthorityGameMode() const;
        WeakObjectIdentity MakeWeakIdentity(void* Object) const;
        void* ResolveWeakIdentity(const WeakObjectIdentity& Identity) const;
        bool SameIdentity(const WeakObjectIdentity& A,
                          const WeakObjectIdentity& B) const;
        bool ValidateProcessEventTarget(UObject* Object) const;
        bool DispatchBaseProcessEvent(UObject* Object, UFunction* Function,
                                      void* Parameters) const;
        UFunction* ResolveFunctionCached(UFunction*& Cache,
                                         const char* FullName,
                                         uint16 ParmsSize,
                                         uint8 NumParms,
                                         uint32 RequiredFlags);
        UEngine* FindEngine();
        UWorld* FindWorld(UEngine* Engine);
        bool ValidateLiveEngine(UEngine* Engine,
                                std::string* Identity = nullptr) const;
        bool ApplyArkLoginLockBypass(UWorld* World);
        void EnsureProcessEventDiagnosticsHook();
        void UpdateConnectionDiagnostics(void* World, void* ActiveNetDriver,
                                         Role ActiveRole, bool IsHosting,
                                         void* HostDriver);
        bool MakeName(const std::string& Value, FName& Result);
        bool PatchNetDriverDefinitions(UEngine* Engine);
        void AddLog(const std::string& Message,
                    LogLevel Level = LogLevel::Info);
        void AddLogOnce(bool& Flag, const std::string& Message,
                        LogLevel Level = LogLevel::Info);
        void SetStatus(const std::string& Message);
        void SetError(const std::string& Message);

        mutable std::mutex Mutex;
        mutable std::mutex CommandMutex;
        std::once_flag InitializeOnce;
        std::deque<RuntimeCommand> PendingCommands;
        std::atomic<bool> GameThreadTaskPending{false};
#if SERVERHOST_DEVELOPER_UI
        std::atomic<bool> DeveloperProcessEventExamplePending{false};
        std::atomic<bool> DeveloperHarvestProbePending{false};
#endif
        std::atomic<uint64> GameThreadToken{0};
        std::atomic<UNetDriver*> HotHostedNetDriver{nullptr};
        std::atomic<uint8> HotRole{static_cast<uint8>(Role::Disabled)};
        std::atomic<uint8> HotModePolicy{
            static_cast<uint8>(NetModePolicy::AutomaticListenServer)};
        std::atomic<bool> HotHosting{false};
        mutable std::atomic<uint64> NetModeCallCount{0};
        mutable std::atomic<uint64> HostedNetModeCallCount{0};
        mutable std::atomic<uint64> ForcedDedicatedCallCount{0};
        mutable std::atomic<uint64> HostedOriginalStandaloneCallCount{0};
        mutable std::atomic<uint64> HostedOriginalDedicatedCallCount{0};
        mutable std::atomic<uint64> HostedOriginalListenCallCount{0};
        mutable std::atomic<uint64> HostedOriginalClientCallCount{0};
        mutable std::atomic<uint8> LastHostedOriginalMode{
            static_cast<uint8>(ENetMode::Max)};

        Role CurrentRole = Role::Disabled;
        HostLifecycleState HostState = HostLifecycleState::Resolving;
        ClientLifecycleState ClientState = ClientLifecycleState::Disabled;
        NetModePolicy ModePolicy = NetModePolicy::AutomaticListenServer;
        bool ForceNetMode = false;
        bool HostPending = false;
        bool ListenAttemptInProgress = false;
        bool Hosting = false;
        bool GameThreadDispatchAvailable = false;
        bool NetDriverPatched = false;
        bool IOSAppOnMac = false;
        bool BypassArkLoginLock = true;
        bool ArkLoginBypassApplied = false;
        bool GameModeGlobalDisableLoginLockCheck = false;
        bool GameModeTempDisableLoginLockCheck = false;
        bool ClientGameplayReady = false;
        bool ClientArkLoginLocked = false;
        bool ProcessEventDiagnosticsInstalled = false;
        bool ProcessEventDiagnosticsAttempted = false;
        bool ClientPlayerStateReady = false;
        bool ClientHUDReady = false;
        bool ClientPawnReady = false;
        bool ClientCharacterCreationRPCSeen = false;
        bool ClientSpawnUIRPCSeen = false;
        bool ClientTravelPending = false;
        bool ClientReturnToMenuPending = false;
        bool ClientReturnTransportDetachedLogged = false;
        bool TargetedPlayerFlowAddressesValidated = false;
        bool TargetedPlayerFlowHooksInstalled = false;
        bool ClientUIRecoveryAttempted = false;
        bool KnownProfileEligible = false;
        bool LoggedEngineIdentity = false;
        bool LoggedProfileWorld = false;
        bool LoggedGWorld = false;
        bool LoggedDefinitionsFallback = false;
        bool LoggedDefinitionsInvalid = false;
        bool LoggedDefinitionsNoMatch = false;
        bool LoggedNamePoolNotReady = false;
        bool LoggedWorldNetDriverFallback = false;
        bool LoggedMissingWorldName = false;
        bool LoggedObjectArrayReady = false;
        bool LoggedLateListenStateMismatch = false;
        bool LoggedHostedNetModeActivity = false;
        bool LoggedGameThreadUnavailable = false;
        int32 ObjectCount = 0;
        int32 ConnectedClients = 0;
        int32 GameplayReadyClients = 0;
        int32 ArkLoginLockedClients = 0;
        int32 Port = 7777;
        int32 BoundPort = 0;
        std::string MapName = "TheIsland";
        std::string WorldName;
        std::string Password;
        std::string Status = "Not initialized";
        std::string LastError;
        std::string EngineIdentity;
        std::string AuthorityGameModeIdentity;
        std::string ConnectionDiagnostics;
        std::string PlayerInitializationDiagnostics;
        std::string GameStateDiagnostics;
        std::string UIFlowDiagnostics;
        std::string RPCDiagnostics;
        std::string PlayerUIRecoveryDiagnostics;
        std::string NetDriverClassPath;
        uintptr_t ProcessEventAddress = 0;
        uintptr_t NetDriverDefinitionsData = 0;
        int32 NetDriverDefinitionsOffset = 0;
        int32 NetDriverDefinitionsNum = 0;
        int32 NetDriverDefinitionsMax = 0;
        std::vector<std::string> Log;
        std::vector<RuntimeLogEntry> StructuredLog;
        std::vector<PlayerSummary> PlayerSummaries;
        std::vector<ClientRecoveryRecord> RecoveryRecords;
        std::array<uintptr_t, 9> Addresses{};
        UEngine* CachedEngine = nullptr;
        UWorld* CachedWorld = nullptr;
        UWorld* HostedWorld = nullptr;
        UNetDriver* HostedNetDriver = nullptr;
        UWorld* ArkLoginBypassWorld = nullptr;
        WeakObjectIdentity CachedWorldIdentity;
        WeakObjectIdentity HostedWorldIdentity;
        WeakObjectIdentity HostedNetDriverIdentity;
        UFunction* CachedHUDRecoveryRPC = nullptr;
        UFunction* CachedCharacterRecoveryRPC = nullptr;
        UFunction* CachedQuitToMainMenu = nullptr;
        UClass* CachedHUDBaseClass = nullptr;
        UFunction* CachedSendServerChatMessage = nullptr;
        UFunction* CachedSetCheatPlayer = nullptr;
        UFunction* CachedAdminCheat = nullptr;
        UFunction* CachedAdminKick = nullptr;
        UFunction* CachedPlayerStateUniqueId = nullptr;
        UFunction* CachedPlayerHasArkPass = nullptr;
        UFunction* CachedPlayerDataUniqueId = nullptr;
        UFunction* CachedConsoleCommand = nullptr;
#if SERVERHOST_DEVELOPER_UI
        UFunction* CachedDeveloperProcessEventExample = nullptr;
        UFunction* CachedDeveloperHarvestProbe = nullptr;
#endif
        UObject* CachedKismetSystemLibrary = nullptr;
        int32 LastLoggedTransportClients = -1;
        int32 LastLoggedGameplayClients = -1;
        int32 LastLoggedArkLockedClients = -1;
        bool LastLoggedClientGameplayReady = false;
        bool LastLoggedClientArkLocked = false;
        std::string LastLoggedHostPlayerInitialization;
        std::string LastLoggedClientPlayerInitialization;
        std::string LastLoggedGameStateDiagnostics;
        std::string LastLoggedUIFlowDiagnostics;
        std::array<int32, 19> DiagnosticEventCounts{};
        int32 ClientCharacterUICallbackCount = 0;
        uint64 LogSequence = 0;
        std::chrono::steady_clock::time_point RuntimeStartedAt =
            std::chrono::steady_clock::now();
        std::chrono::steady_clock::time_point LastDiscovery{};
        std::chrono::steady_clock::time_point ClientTravelStartedAt{};
    };
}
