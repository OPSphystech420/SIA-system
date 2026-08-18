# ShooterGame 1.10280 no-host delayed-exit intake — withdrawn/reclassified

> Correction, 2026-08-18: the user clarified that a world was open and hosting
> had been started in this execution. The no-host interpretation below is
> withdrawn, not a device result. It is retained to preserve the intake trail.
> The corrected evidence and protocol are in
> [IOS_1.10280_HOST_STARTED_SIGNAL_EXIT.md](IOS_1.10280_HOST_STARTED_SIGNAL_EXIT.md).

Report ID: `IOS-1.10280-NOHOST-DELAYED-EXIT-001`  
Test ID: `LEGACY-NOHOST-EXIT-001`  
Date: 2026-08-18  
Exact package:
`/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb`  
Package SHA-256:
`d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e`  
Embedded dylib SHA-256:
`739b9b994d3f1f4b940f126ff041cc2b426a4db26fe5fb4674537bac9541f439`  
Environment: reported Apple Silicon Mac running ShooterGame 1.10280 iOS build;
exact macOS version, app UUID, map and installed tweak inventory not supplied  
Crash/log artifact: none was saved or supplied

## 1. Isolated failure

This report covers exactly one workflow: open the ServerHost UI but do not press
Start, Join, Save, administration or any other action. The ShooterGame process
then closes after approximately one to two minutes. The observation is accepted
as a device failure for the exact package above.

The absence of a saved crash report does not classify the termination. It may be
a handled/unhandled fault, process exit, watchdog/resource kill or another
termination mechanism. No cause is inferred from the delay alone.
Legacy `AddLog` keeps a bounded in-memory vector and writes to `stderr`; it does
not persist a file. Losing ServerHost logs when the process exits is therefore
expected unless macOS Console or another live collector was attached.

## 2. Expected and observed transitions

Expected:

```text
ShooterGame running
  -> ServerHost package loads
  -> floating control and ServerHost UI become available
  -> user opens UI, presses no command
  -> process remains alive for at least the observation window
```

Observed:

```text
ShooterGame running
  -> exact package d36e…279e loaded
  -> user opens ServerHost UI
  -> no host Start and no other command
  -> approximately 1–2 minutes elapse
  -> application closes
  -> no retained ServerHost log or crash report available
```

Unknown: whether the same package also exits if the floating button is never
opened; exact first/last console line; whether the OS terminated the process;
resource pressure; reproducibility count; and whether package `-7` behaves the
same before Start.

## 3. Source state active before Start

The previous visual A/B protocol assumed a stable no-host baseline. Current
source disproves that assumption. Before any Host request:

1. the dylib constructor calls `HostingRuntime::Initialize`;
2. initialization resolves live image/name/object/native addresses and installs
   three hardware-breakpoint hooks for `UEngine::Init`, `UWorld::BeginPlay` and
   `UNetDriver::GetNetMode`;
3. `MenuBootstrap` attaches an always-running 30 FPS transparent `MTKView` after
   launch; every draw calls `HostingRuntime::Tick`, even while the menu is hidden;
4. Tick continuously schedules `FIOSAsyncTask` work; `GameThreadTick` performs
   object/Engine/World discovery at up to once per second;
5. when an Engine is found and `NetDriverPatched` is false, `GameThreadTick`
   unconditionally calls `PatchNetDriverDefinitions` even though role is
   Disabled and no Host/Join command exists;
6. `OnEngineInit`, reached through the installed hook, also unconditionally calls
   `PatchNetDriverDefinitions`;
7. that function can overwrite the existing GameNetDriver primary `FName`, or
   allocate/write/commit a new `FNetDriverDefinition` and `TArray` header.

Therefore `ForceDedicatedMode` is not active before Start, but hook transport,
continuous UI/tick work and a behavior-changing Engine container mutation are.
The failure cannot presently be attributed to the forced-NetMode policy.

The exact current FreshSDK layout still places
`UEngine::NetDriverDefinitions` at `0xBF8` and `FNetDriverDefinition` at size
`0x18`; exact-binary work confirms CreateNetDriver consumes the definition
array. Those facts validate the intended field, not the allocation/ownership
lifetime or safety of changing it during an idle client-rendered world. No live
reflection snapshot from this failed run exists.

Relevant Sishen comparison remains organizational only: its
`InitializeStaticOffsets`/`InitializeDefaultHooks` separation makes resolve and
hook phases visible, and its typed hook manager keeps an explicit original. Its
hardware-breakpoint implementation still supplies no current 1.10280 ABI or
proof of prior exception-port chaining, new-thread coverage, nesting and
teardown. Nothing in Sishen supports unconditional Engine-container mutation
merely because a UI/runtime singleton initialized.

## 4. Competing hypotheses

| Hypothesis | Support | Limit | One-variable discriminator |
|---|---|---|---|
| H1: opening/rendering the visible ImGui panel triggers the exit | the user reports the failure after opening the UI; visible mode adds `HostMenu::Render` and repeated snapshot/vector processing | the transparent MTK overlay, runtime Tick and hooks already run while hidden | same exact package, hidden UI for five minutes versus visible UI for five minutes |
| H2: hardware-breakpoint hook transport terminates the process before hosting | all three hooks install in the constructor; GetNetMode/BeginPlay can execute without a host; backend replaces the process breakpoint exception port and lacks proven chaining/new-thread/uninstall behavior | exact entry replay is straight-line compatible; no exception/crash trace exists | after the UI visibility control, a separately gated no-hook package retaining resolver/UI/tick/mutation |
| H3: unconditional pre-host NetDriverDefinitions mutation corrupts or destabilizes Engine state | source proves mutation occurs from Engine discovery/Init while role is Disabled; allocation/ownership and concurrent readers are not proven | no log shows that the write completed before this exit; timing alone is insufficient | gated package retaining hooks/UI but deferring definitions mutation until explicit Host/Join |
| H4: resource/watchdog pressure from the always-running 30 FPS overlay and game-thread scheduling closes the app | overlay renders continuously and schedules runtime work even when no command is active; no crash report was retained | no memory/CPU/watchdog evidence exists | hidden-versus-visible control plus live Console/process resource capture |
| H5: unrelated base-game/tweak/OS state caused termination | OS version, tweak inventory and hidden-UI control are missing | exact hash is now tied to an observed failure | same-session package-disabled or inert-V2 control after the bounded same-package visibility test |

No hypothesis is promoted to cause.

## 5. Intervention decision

No source patch is justified from this observation alone. A no-hook build and a
deferred-mutation build change different active pre-host variables; selecting
one before determining whether UI visibility matters would skip the smallest
available control.

Run exactly this same-package control first:

1. install/confirm package SHA-256 `d36e…279e`;
2. launch the same ShooterGame/map and never open the floating ServerHost button
   for five minutes; do not invoke any host/client/admin/save behavior;
3. record whether the process remains alive and, if possible, capture macOS
   Console filtered to `ShooterGame` and `ServerHost` from launch until exit;
4. relaunch, open the ServerHost UI once, press nothing, and observe for five
   minutes under the same conditions;
5. report `hidden: alive/exited + time` and `visible: alive/exited + time`.

Interpretation:

- hidden survives and visible exits: next isolate the UI/render/snapshot path;
- both exit: UI visibility is rejected; next build one no-hook diagnostic while
  retaining all other pre-host behavior;
- neither exits: result is intermittent; repeat each arm twice before changing
  source;
- hidden exits but visible survives: treat timing as nondeterministic and repeat;
  do not infer that visibility is protective.

## 6. Current state

The earlier host-visual A/B protocol is suspended because package A failed its
no-host prerequisite. No fix package is claimed. This workflow is blocked on one
specific action: the same-package hidden-versus-visible five-minute control (and
live Console capture if available).
