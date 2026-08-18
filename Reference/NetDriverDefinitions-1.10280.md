# NetDriverDefinitions research — ShooterGame 1.10280

## Confirmed

- The fresh Dumper-7 SDK gives `UEngine::NetDriverDefinitions = 0xBF8`,
  `sizeof(TArray) = 0x10`, `sizeof(FNetDriverDefinition) = 0x18`, and the three
  `FName` fields at `0x0`, `0x8`, and `0x10`.
- Exact `110280.i64` decompilation of the CreateNetDriver path reads the array
  data at `UEngine+0xBF8`, its count at `UEngine+0xC00`, and advances entries by
  `0x18`. It compares `DefName`, calls `StaticLoadClass` with the primary class
  name, checks the driver's `IsAvailable`, and loads the fallback if necessary.
- Exact `UWorld::Listen` calls CreateNamedNetDriver for `GameNetDriver`, attaches
  the returned driver to the world/level collections, then calls virtual
  `InitListen`. `UIpNetDriver::InitListen` performs the socket-side initialization
  only after that engine setup.
- Exact `UEngine::Init` invokes the UObject config-loading path on its live
  `this`. No later direct clear/write of `NetDriverDefinitions` exists in that
  function.
- Cooked `BaseEngine.ini` contains an IP definition using
  `/Script/OnlineSubsystemUtils.IpNetDriver` for both primary and fallback.
- Cooked `ShooterGame/Config/DefaultEngine.ini` clears the inherited GameEngine
  array and adds `GameNetDriver` with primary
  `OnlineSubsystemEOS.NetDriverEOS` and fallback
  `OnlineSubsystemUtils.IpNetDriver`. The iOS config enables EOS and EOS P2P.
  Therefore EOS is the title's intended online primary, while IP is the intended
  fallback. For this project's explicit ordinary-IP hosting goal, selecting IP
  as both primary and fallback is intentional.
- Both path spellings are accepted because CreateNetDriver converts the stored
  `FName` to a string and passes it to `StaticLoadClass`; the cooked configs use
  both spellings. The injected entry uses the unambiguous `/Script/...` form.
- `ProcessEvent` is `ShooterGame+0x250147C`, at UObject vtable index 69. The
  generated `Conv_StringToName` parameter block is `0x18`, with its returned
  `FName` at `0x10`.
- `SEAServerManager.dylib.i64` contains no `GameNetDriver`, `IpNetDriver`,
  `NetDriverEOS`, CreateNetDriver/CreateNamedNetDriver, InitListen, or
  NetDriverDefinitions creation/replacement path. Its two `"NetDriver"` users
  only read reflected world `NetDriver` and `ServerConnection` state.

## Cause of the observed failure

The reported `{Data=null, Num=0, Max=0}` is the canonical valid representation
of an empty Unreal `TArray`. Server-Host called `TArray::IsValid()`, whose local
implementation returns false unless `Data != null` and `Num > 0`. It therefore
misclassified a valid empty array as corrupt and returned before any recovery.
That predicate is the exact cause of the logged refusal.

The earlier log did not include object identity or class, so it cannot by itself
prove why the live value was empty even though the cooked config contains an
entry. Static analysis rules out a direct late clear inside `UEngine::Init`; the
remaining possibilities are a wrong/cached Engine object, config not being
applied in that runtime, or an external later mutation. Version 0.2.3 logs and
requires a live `Transient.ShooterEngine_*`, its exact class and object-array
liveness, so the next in-app run will distinguish those cases without calling
Listen.

## Selected implementation

Variant A is used. A native CreateNamedNetDriver call cannot repair the array
because that path consumes the array, and direct UIpNetDriver creation would
duplicate engine bookkeeping and cleanup.

For a canonical/reserved empty array, version 0.2.3:

1. Requires all eight exact-build signatures and reflected/static offset `0xBF8`.
2. Validates the live non-CDO `Transient.ShooterEngine_*` and the IP UClass.
3. Validates ProcessEvent against the confirmed vtable entry and creates every
   `FName` through `KismetStringLibrary.Conv_StringToName`.
4. Allocates through `FMemory`, stages and re-reads the entry before committing
   the TArray header, and leaves committed data owned by the Engine array.
5. Re-reads the header and entry after commit before setting the ready flag.
6. On repeated calls, reuses the existing entry and performs no allocation.

For a populated array, it retains the prior primary-to-fallback behavior only
when the fallback string is one of the confirmed IpNetDriver spellings. Listen
remains blocked until the final re-read proves an IP `GameNetDriver`.

## Assumptions requiring live testing

- The app will allow `UIpNetDriver` to bind an incoming UDP socket on each target.
- iOS-on-Mac firewall/sandbox/local-network policy and physical-iPhone local
  network permission may independently affect connectivity after InitListen.
- Replication/gameplay behavior under the optional forced DedicatedServer mode
  still requires two-process testing.

