#pragma once

#include <cstddef>
#include <cstdint>

// Values recovered by the fresh Dumper-7 run against ShooterGame 1.10280
// (UE 4.26.2). They were cross-checked against both the original and the
// Full-Version SDK; their Basic.hpp/core Engine ABI files are byte-identical.
// The generated SDKs are kept verbatim under Reference/FreshSDK.
//
// Layout values describe the target ABI and are safe to compile into this
// build. KnownBuild values are image-relative diagnostics for this exact
// executable; runtime code must prefer signatures/reflection over them.
namespace ServerHost::SDKProfile
{
    inline constexpr const char* GameVersion = "4.26.2-0+++UE4+Release-4.26";
    inline constexpr const char* TargetBuild = "ShooterGame 1.10280";

    namespace Layout
    {
        inline constexpr std::size_t FNameSize = 0x8;
        inline constexpr std::size_t FNamePoolBlocks = 0xD0;
        inline constexpr std::size_t FNameEntryStride = 0x2;
        inline constexpr int32_t FNameEntryLengthBits = 10;
        inline constexpr int32_t FNameBlockOffsetBits = 16;

        inline constexpr std::size_t FUObjectItemSize = 0x18;
        inline constexpr std::size_t TUObjectArrayNumElements = 0x14;
        inline constexpr int32_t UObjectElementsPerChunk = 0x10000;

        inline constexpr std::size_t UObjectClass = 0x10;
        inline constexpr std::size_t UObjectName = 0x18;
        inline constexpr std::size_t UObjectOuter = 0x20;
        inline constexpr std::size_t UObjectSize = 0x28;

        inline constexpr std::size_t UStructSuperStruct = 0x40;
        inline constexpr std::size_t UStructChildren = 0x48;
        inline constexpr std::size_t UStructChildProperties = 0x50;

        inline constexpr std::size_t FFieldNext = 0x20;
        inline constexpr std::size_t FFieldName = 0x28;
        inline constexpr std::size_t FPropertyArrayDim = 0x34;
        inline constexpr std::size_t FPropertyElementSize = 0x38;
        inline constexpr std::size_t FPropertyFlags = 0x40;
        inline constexpr std::size_t FPropertyOffset = 0x4C;
        inline constexpr std::size_t FPropertySize = 0x78;
        inline constexpr std::size_t FBoolPropertyByteMask = 0x7A;

        inline constexpr std::size_t FURLSize = 0x68;
        inline constexpr std::size_t FNetDriverDefinitionSize = 0x18;
    }

    namespace KnownBuild
    {
        // Dumper-7 reports ObjObjects directly at 0x5D434E8. Server-Host's
        // FUObjectArray wrapper expects the 0x10-byte owner header.
        inline constexpr uintptr_t FUObjectArray = 0x5D434D8;
        inline constexpr uintptr_t ObjObjects = 0x5D434E8;
        inline constexpr uintptr_t FNamePool = 0x5BB5180;
        inline constexpr uintptr_t GWorld = 0x5DBA4F0;
        inline constexpr uintptr_t ProcessEvent = 0x250147C;
        inline constexpr int32_t ProcessEventIndex = 69;
        // AActor-derived objects, including PlayerControllerBlueprint_C, use
        // this guarded ProcessEvent thunk in vtable slot 69. It conditionally
        // tail-calls the base UObject::ProcessEvent above.
        inline constexpr uintptr_t ActorProcessEventThunk = 0x35BA838;

        inline constexpr std::size_t UEngineGameViewport = 0x780;
        inline constexpr std::size_t UEngineNetDriverDefinitions = 0xBF8;
        inline constexpr std::size_t UGameViewportClientWorld = 0x70;
        inline constexpr std::size_t UWorldPersistentLevel = 0x1D0;
        inline constexpr std::size_t UWorldNetDriver = 0x1D8;
        inline constexpr std::size_t UPrimalWorldFrameCounter = 0x28;
        inline constexpr std::size_t UWorldUnstasisTimestampClock = 0x738;
        inline constexpr std::size_t UWorldAuthorityGameMode = 0x2B8;
        inline constexpr std::size_t UWorldGameState = 0x2C0;
        inline constexpr std::size_t UNetDriverServerConnection = 0x88;
        inline constexpr std::size_t UNetDriverClientConnections = 0x90;
        inline constexpr std::size_t UNetDriverWorld = 0x140;
        inline constexpr std::size_t UNetDriverTime = 0x210;
        inline constexpr std::size_t UPlayerPlayerController = 0x30;
        inline constexpr std::size_t UNetConnectionDriver = 0x60;
        inline constexpr std::size_t UNetConnectionPackageMap = 0x70;
        inline constexpr std::size_t UNetConnectionOpenChannels = 0x78;
        inline constexpr std::size_t UNetConnectionViewTarget = 0x98;
        inline constexpr std::size_t UNetConnectionOwningActor = 0xA0;
        inline constexpr std::size_t UNetConnectionPlayerID = 0x168;
        inline constexpr std::size_t UNetConnectionLastReceiveTime = 0x1E8;
        inline constexpr std::size_t UNetConnectionArkLoginLock = 0x1B21;
        inline constexpr std::size_t AControllerPlayerState = 0x3E0;
        inline constexpr std::size_t AControllerStateName = 0x400;
        inline constexpr std::size_t AControllerPawn = 0x408;
        inline constexpr std::size_t AControllerCharacter = 0x418;
        inline constexpr std::size_t APlayerControllerPlayer = 0x460;
        inline constexpr std::size_t APlayerControllerAcknowledgedPawn = 0x468;
        inline constexpr std::size_t APlayerControllerMyHUD = 0x478;
        inline constexpr std::size_t APlayerControllerPlayerIsWaiting = 0x5B8;
        inline constexpr std::size_t APlayerControllerNetConnection = 0x600;
        // Shared APlayerController bitfield byte. Dumper-7 reports
        // bCheatPlayer at bit 2 and bIsAdmin at bit 5 for this exact build.
        inline constexpr std::size_t APlayerControllerAdminFlags = 0x778;
        inline constexpr uint8_t APlayerControllerCheatPlayerMask = 0x04;
        inline constexpr uint8_t APlayerControllerIsAdminMask = 0x20;
        inline constexpr std::size_t AShooterPlayerControllerLastValidUnstasisCasterFrame = 0x450;
        inline constexpr std::size_t AHUDPlayerOwner = 0x3D8;
        inline constexpr std::size_t AShooterHUDSpawnUITemplate = 0x610;
        inline constexpr std::size_t AShooterPlayerControllerShowDownloadCharacter = 0x1090;
        inline constexpr std::size_t AShooterPlayerControllerCharacterUICallbackPending = 0x11AB;
        inline constexpr std::size_t APlayerStatePlayerID = 0x3DC;
        inline constexpr std::size_t APlayerStateSpectatorFlags = 0x3E2;
        inline constexpr std::size_t APlayerStateUniqueID = 0x418;
        inline constexpr std::size_t APlayerStatePawnPrivate = 0x448;
        inline constexpr std::size_t APlayerStatePlayerNamePrivate = 0x4C0;
        inline constexpr std::size_t AShooterPlayerStateMyPlayerData = 0x520;
        inline constexpr std::size_t UPrimalPlayerDataMyData = 0x28;
        inline constexpr std::size_t FPrimalPlayerDataPlayerDataID = 0x0;
        inline constexpr std::size_t FPrimalPlayerDataUniqueID = 0x8;
        inline constexpr std::size_t FPrimalPlayerDataSavedNetworkAddress = 0x30;
        inline constexpr std::size_t AShooterPlayerStateCachedSpawnPointInfos = 0xCB8;
        inline constexpr std::size_t AGameModeBaseGameStateClass = 0x400;
        inline constexpr std::size_t AGameModeBasePlayerControllerClass = 0x408;
        inline constexpr std::size_t AGameModeBasePlayerStateClass = 0x410;
        inline constexpr std::size_t AGameModeBaseHUDClass = 0x418;
        inline constexpr std::size_t AGameModeBaseDefaultPawnClass = 0x420;
        inline constexpr std::size_t AGameModeBaseGameSession = 0x440;
        inline constexpr std::size_t AGameModeBaseStartPlayersAsSpectators = 0x470;
        inline constexpr std::size_t AShooterGameModeGlobalCommandsCheatManager = 0x750;
        inline constexpr std::size_t AGameStateBasePlayerArray = 0x3F0;
        inline constexpr std::size_t AGameStateBaseReplicatedHasBegunPlay = 0x400;
        inline constexpr std::size_t AGameStateMatchState = 0x498;
        inline constexpr std::size_t AShooterGameStateNumPlayerActors = 0x4D8;
        inline constexpr std::size_t AShooterGameStateNumPlayerConnected = 0x4DC;
        inline constexpr std::size_t AShooterGameStateIsListenServer = 0x531;
        inline constexpr std::size_t AShooterGameStateIsDediServer = 0x532;
        inline constexpr std::size_t AShooterGameStateAllowCharacterCreation = 0x574;
        inline constexpr std::size_t AShooterGameStateAllowSpawnPointSelection = 0x575;
        inline constexpr std::size_t AShooterGameStateListenServerTetherDistanceMultiplier = 0x730;
        inline constexpr std::size_t AShooterGameStateSupportedSpawnRegions = 0x748;
        inline constexpr std::size_t AShooterGameModeSupportedSpawnRegions = 0x23A8;
        inline constexpr std::size_t AShooterGameModeGlobalDisableLoginLockCheck = 0x8C0;
        inline constexpr std::size_t AShooterGameModeTempDisableLoginLockCheck = 0x8C1;
        inline constexpr std::size_t AShooterGameModeAutoCreateNewPlayerData = 0x968;
        inline constexpr std::size_t AShooterGameModePlayerDatas = 0xAF8;
        inline constexpr std::size_t AShooterGameModeDisableSaveLoad = 0xCC8;

        // Read-only late-listen/stasis diagnostics. These offsets are emitted
        // by the full 1.10280 Dumper-7 SDK and are never mutated by the probe.
        inline constexpr std::size_t ULevelWorldSettings = 0x258;
        inline constexpr std::size_t ABasePrimalWorldSettingsBaseNetStasisDistance = 0x850;
        // Hidden raw TArray<AShooterPlayerController*> confirmed by IDA's
        // PostInitializeComponents/Destroyed lifecycle and stasis updater.
        inline constexpr std::size_t ABasePrimalWorldSettingsUnstasisViewpointControllers = 0x4B0;
        inline constexpr std::size_t ABasePrimalWorldSettingsPlayerCharacterUnstasisViewpoints = 0x858;
        inline constexpr std::size_t UPrimalActorAutoStasisFlags = 0x32;
        inline constexpr std::size_t UPrimalActorStasisFlags = 0x33;
        inline constexpr std::size_t UPrimalActorUseStasisGridFlags = 0x39;
        inline constexpr std::size_t UPrimalActorNetworkAndStasisRangeMultiplier = 0xB8;

        // Native implementations recovered from the 1.10280 arm64 IDA database.
        // They are used only after every core signature matches this exact profile
        // and their non-relocating instruction prefixes are verified at runtime.
        inline constexpr uintptr_t ShooterGameModeHandleNewPlayer = 0x1BB8E00;
        inline constexpr uintptr_t ShooterGameModePostLogin = 0x1B99DA8;
        inline constexpr uintptr_t ShooterGameModeRealPostLogin = 0x1B99E28;
        inline constexpr uintptr_t ShooterGameModeStartNewPlayer = 0x1B9C824;
        inline constexpr std::size_t ShooterGameModeStartNewPlayerVTableOffset = 0xDB0;
        inline constexpr uintptr_t ShooterGameModeSaveWorld = 0x1B96B40;
        inline constexpr std::size_t ShooterGameModeSaveWorldVTableOffset = 0xEF8;
        inline constexpr uintptr_t ShooterPlayerControllerClientSetHUDAndInitUIScenes = 0x1AC2148;
        inline constexpr uintptr_t ShooterPlayerControllerClientShowCharacterCreationUI = 0x1AA07E8;
        inline constexpr uintptr_t ShooterPlayerControllerClientShowSpawnUI = 0x1AA0648;
        inline constexpr uintptr_t ShooterHUDCharacterCreationTimerCallback = 0x19A562C;
    }
}
