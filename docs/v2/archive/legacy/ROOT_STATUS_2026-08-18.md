# Server-Host stages

## 2026-08-18 failure intake

The user reports abnormal host sky/weather/world lighting or effect animation
after a later legacy hosting-hook workflow becomes active. Treat host visual
stability as failed for the deleted artifact with supplied SHA-256
`217c15cba0f634ee9427b219d30f17a2f917045d9683f35ea8bbc02079cb15f4`.
Its bytes/source, map, timing, logs and attempt count remain unavailable, so do
not label a current package as that artifact or infer GetNetMode causality from
timing. Exact 1.10280 IDA analysis proves forced Dedicated changes actor
registration, Listen distance/relevancy and stasis/grid paths. That justifies a
policy-only A/B, not a fix claim. Administration, save, reconnect and
return-to-menu are outside this isolated investigation. Detailed intake:
`docs/v2/evidence/IOS_1.10280_GETNETMODE_FAILURE_INTAKE.md`.

Preserved pre-gate rollback/reference:
`packages/com.mhga.serverhost_0.2.24-4+debug_iphoneos-arm.deb`. Ready
same-gated-source A/forced:
`packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb`; monotonic
B/original:
`packages/com.mhga.serverhost_0.2.24-7+debug_iphoneos-arm.deb`. The earlier
statement that A failed before Start is withdrawn: the user clarified that a
world was open and hosting had started. Exact A is stable while ServerHost is
unopened/unused; the host-started execution reached `GASignalHandler entered`
and then terminated. Exact IDA shows that this broad GameAnalytics signal
handler submits an error event and calls `_Exit(1)`, but the supplied log does
not identify which registered signal fired. B remains suspended and is not a
fix artifact.

Known control: `0.2.11` connected a physical iPhone to an Apple Silicon Mac host and entered gameplay.

## 0.2.24 — current stability A/B stage

- Far-away replication remains on the device-confirmed policy: only the exact hosted `GameNetDriver` reports `NM_DedicatedServer`. Client, beacon, pending and unrelated drivers keep their original mode.
- The experimental fourth `AShooterGameMode::PostLogin` hardware hook is disabled by default for this crash-isolation build. The three confirmed hooks remain: `UEngine::Init`, `UWorld::BeginPlay`, and hosted `UNetDriver::GetNetMode`. The idempotent reflected RPC recovery pair is again the active player-flow path.
- Save uses the confirmed native vtable slot `AShooterGameMode::SaveWorld(true, false)`. Only for that synchronous game-thread call, GetNetMode temporarily returns the original Listen result so ShooterGame collects all `PlayerDatas` write tasks and waits for them. The previous duplicate asynchronous per-player dispatch was removed.
- Kick performs that synchronous world/player save first and revalidates the controller/connection before disconnecting it.
- Broadcast now uses the authority `ShooterGameMode.SendServerChatMessage` native function (`0x30`, five parameters) instead of a per-controller RPC. The mobile `ShooterCheatManager.Broadcast` path was rejected after IDA showed that it terminates in stubs. Unproven runtime-admin and fly/god/infinite-stat controls are hidden from the normal UI; Kick remains.
- Background/termination autosave is disabled in this A/B build. UIKit lifecycle notifications can overlap suspension/close handling; only the explicit game-thread `Save world` command invokes the native save path.
- Client return-to-menu remains the confirmed `ShooterPlayerController.QuitToMainMenu` path. Its timeout is 180 seconds because a device trace completed the MainMenu world transition after approximately 125 seconds. A delayed MainMenu transition now clears stale client state even after an earlier connection failure.
- The hot GetNetMode path now samples caller RVAs once per 1024 forced calls into a fixed atomic table. This is diagnostic evidence for the host sky/FPS issue; no rendering/audio function is suppressed by assumption.

## Next test

Use exact A `-6` only. In both arms open the same world and press `Start server`
once. In arm H, wait for `Hosting started`/Listening (or a terminal error), then
close the ServerHost panel and observe for five minutes. Relaunch and repeat in
arm V, leaving the panel visible for five minutes. Report host transition,
`alive/exited + time`, final Console lines and whether
`GASignalHandler entered` appeared. Do not connect clients, save or administer.
