#pragma once

#include "ScriptCore.h"

// Non-owning typed views over the UE4 object hierarchy used by Server-Host.
// The game owns every instance. These wrappers intentionally add no fields;
// member access remains offset/reflection validated for the exact SDK profile.
class UEngine : public UObject {};
class UWorld : public UObject {};
class UNetDriver : public UObject {};
class UIpNetDriver : public UNetDriver {};
class UNetConnection : public UObject {};
class UPlayer : public UObject {};

class AActor : public UObject {};
class AController : public AActor {};
class APlayerController : public AController {};
class AShooterPlayerController : public APlayerController {};
class AShooterPlayerState : public AActor {};
class AShooterGameMode : public AActor {};
class UPrimalPlayerData : public UObject {};

static_assert(sizeof(UEngine) == sizeof(UObject));
static_assert(sizeof(UWorld) == sizeof(UObject));
static_assert(sizeof(UNetDriver) == sizeof(UObject));
static_assert(sizeof(UNetConnection) == sizeof(UObject));
static_assert(sizeof(AShooterPlayerController) == sizeof(UObject));
static_assert(sizeof(AShooterPlayerState) == sizeof(UObject));
static_assert(sizeof(AShooterGameMode) == sizeof(UObject));
static_assert(sizeof(UPrimalPlayerData) == sizeof(UObject));
