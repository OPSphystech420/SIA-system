# ShooterGame 1.10280 host-started signal exit intake

Report ID: `IOS-1.10280-HOST-STARTED-SIGNAL-EXIT-001`  
Test ID: `LEGACY-HOST-SIGNAL-EXIT-001`  
Date: 2026-08-18  
Exact package:
`/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/com.mhga.serverhost_0.2.24-6+debug_iphoneos-arm.deb`  
Package SHA-256:
`d36e023c617f60d968411c8072367c3ce213791d3cd5b2f4f9af493e4b6c279e`  
Embedded dylib SHA-256:
`739b9b994d3f1f4b940f126ff041cc2b426a4db26fe5fb4674537bac9541f439`  
Exact IDA input SHA-256:
`d98d25778e893413ebd6c4da9156e1b74efe2b203bc488393795c3db6c83a178`  
Device log:
`/Users/grimreaper31/.codex/attachments/9991530b-8a5a-4cfc-9e4f-8b2568ad77f0/pasted-text.txt`  
Log SHA-256:
`5e2a9c96de5eadee767454cebb06539b82b6c983d5d224b910f1aec0bf3a1a08`  
Log size: 1,303 lines; user-supplied macOS Console capture, 2026-08-18

## 1. Failure-intake correction

The initial intake incorrectly classified this execution as a no-host idle
exit. The user subsequently clarified that a world was open and ServerHost had
started hosting. The game is stable when the floating ServerHost control is not
opened and no ServerHost command is pressed.

The earlier `LEGACY-NOHOST-EXIT-001` row and its filename are retained for
auditability, but the claim is withdrawn and superseded by this report. It is
not evidence that visible idle UI, constructor hooks or pre-command mutation
alone terminate the process.

## 2. Expected and observed transitions

Expected:

```text
ShooterGame world open
  -> open ServerHost UI
  -> press Start server
  -> host preparation and UWorld::Listen complete or fail closed
  -> process remains alive and reports a stable host/error state
```

Observed:

```text
ShooterGame world open
  -> exact A package d36e...279e loaded
  -> ServerHost UI opened and host started
  -> later, at 14:43:45.372951, Console prints "GASignalHandler entered"
  -> GameAnalytics sends an error event (HTTP 200 completes at 14:43:45.594)
  -> application terminates without a retained conventional crash report
```

The supplied excerpt begins after the full workflow began, so it does not prove
the elapsed time from Start to signal. Lines such as
`isAttemptingTermination (state: Running)` occur earlier while the application
continues running and are not treated as the failure marker. The first strong
termination marker is `GASignalHandler entered`.

The subsequently supplied complete Console file spans `15:14:56.943830` through
`15:17:21.783607`. Foreground/reopen processing starts at
`15:14:57.787790`; the signal marker is at `15:17:21.531409`, exactly
143.743619 seconds later. The marker occurs once. Its GameAnalytics request
finishes at `15:17:21.783607`, 0.252198 seconds later, and that is the final log
line. This supports signal-handler-driven `_Exit(1)` and the reported delayed
closure. It still does not timestamp the ServerHost Start command because the
capture contains zero `[ServerHost]` stderr lines.

This full capture belongs to `ShooterGame` PID 13001. The earlier supplied
failure excerpt belonged to PID 12587 and reached the same marker at
`14:43:45.372951`. They are separate executions, so signal-handler termination
is reproduced at least twice under the reported host-started workflow. The
first excerpt began late and cannot be used to compare time-to-signal with the
second run.

Repeated `SSClientCompletion.cpp:33`, AppKit reopen/pointer-lock events,
periodic HTTP 404s, successful TLS setup and a connection cancellation occur
while the process continues. None is promoted to cause. In particular, the
last ordinary connection cancellation precedes the signal by about 14 seconds,
while the request immediately after the signal matches the recovered
GameAnalytics error-submission path.

## 3. Exact termination-path recovery from IDA

The string is referenced by `sub_100BBA32C` at `0x100BBA32C`. Exact decompilation
shows this path:

1. verify GameAnalytics `useErrorReporting`;
2. print `GASignalHandler entered`;
3. collect `backtrace`/`backtrace_symbols` into an error string;
4. enqueue/process a GameAnalytics error event;
5. call `_Exit(1)` unconditionally.

`sub_100BBA1EC` at `0x100BBA1EC` installs that same function with
`sigaction(..., sa_flags=SA_SIGINFO)` for Darwin signals 3, 4, 5, 6, 7, 8, 10,
11, 12, 13, 14, 24 and 25: `SIGQUIT`, `SIGILL`, `SIGTRAP`, `SIGABRT`, `SIGEMT`,
`SIGFPE`, `SIGBUS`, `SIGSEGV`, `SIGSYS`, `SIGPIPE`, `SIGALRM`, `SIGXCPU` and
`SIGXFSZ`. `sub_100BB9894` installs the signal and uncaught-exception handlers
when error reporting is enabled.

The signal callback does not record or print its signal-number argument. The
provided Console excerpt therefore proves a caught POSIX signal followed by
GameAnalytics `_Exit(1)`, but cannot distinguish a memory fault, abort, pipe
signal, resource signal or another member of that set. The handler explains why
a conventional crash report may be absent. The network requests after the
marker are part of error submission and do not prove networking caused the
signal.

## 4. Exact control and smallest suspect delta

There is no package or source delta between the user's stable control and failed
execution: both use exact A `-6`. The control proves only this state:

```text
same A package + ServerHost UI never opened + no command -> stable
```

The failed arm changes two execution variables together: the panel becomes
visible and the Start command activates the host path. Its first source edge is
`HostMenu::Render -> RequestHost`; the game-thread path then executes
`ExecuteHostRequest -> PatchNetDriverDefinitions/login-lock preparation ->
TryStartHosting -> UWorld::Listen`, publishes the hosted driver, and arms the
GetNetMode policy for that driver. At the same time, visible rendering copies
the locked `RuntimeSnapshot`, player summaries and up to 512 structured logs at
30 FPS.

The current FreshSDK confirms `FNetDriverDefinition` size `0x18`,
`UEngine::NetDriverDefinitions` at `0xBF8`, and `UWorld::NetDriver` at `0x1D8`.
Current code rechecks the reflected `NetDriver` offset and verifies world/driver
ownership after Listen. Those layout facts do not prove the lifetime of a
mutated Engine array or identify the signal. No live UFunction metadata or
reflection snapshot was captured in this run, and no reflected UFunction is
identified by the Console marker.

The last host-capable working control remains the historical 0.2.11 device
result, whose package file/source snapshot is missing. Package `-4` was only
compiled/inspected and is not a device control. Exact A's hidden/no-command
result is a current idle control, not a successful-host control.

## 5. Applicable Sishen pattern

Sishen's `InitializeStaticOffsets` and `InitializeDefaultHooks` make resolution
and hook installation separate phases. `VMTHookManager<FuncType>` stores a
typed original and exposes `InvokeOriginal`; `Functions.mm` keeps one typed
parameter struct and a cached function per wrapper. The applicable adjustment
for ShooterGame 1.10280 is organizational only: preserve explicit resolve,
install, policy and original-call boundaries, then validate every current
address/type/lifetime from FreshSDK, exact IDA and runtime reflection.

Sishen's old offsets, vtable indices, writable-vtable transport and process-wide
static caches are not current ABI evidence and are not copied. In particular,
its organization does not validate the legacy hardware-breakpoint lifecycle or
justify a forced return policy for unrelated GetNetMode callers.

## 6. Competing hypotheses

| Hypothesis | Supporting evidence | Rejecting/limiting evidence | Discriminator |
|---|---|---|---|
| H1: visible `HostMenu::Render`/snapshot work races or faults only after host state becomes populated | failed arm had the UI open; visible mode copies player/log vectors and renders host/admin state at 30 FPS | idle visible-only behavior was not actually tested; snapshot is copied under the runtime mutex | start the same host, then hide versus leave the panel visible |
| H2: host preparation/Listen or a post-Listen lifetime error raises the signal | the failure occurred only after Start in the supplied execution; host path mutates Engine state, raw game flags and native ownership | no ServerHost transition log/backtrace or signal number was captured | if both post-Start visibility arms fail, next isolate one host-path variable behind a diagnostic gate |
| H3: forced Dedicated hook policy is correct at the target but semantically breaks a later caller | exact IDA proves many non-replication-sensitive callers distinguish Dedicated and Listen | no caller sample/backtrace ties the signal to GetNetMode; target entry/replay is straight-line compatible | only after a stable hosted baseline, compare A forced with B original-NetMode |
| H4: hardware-breakpoint transport faults independently of returned policy | lifecycle/chaining/new-thread coverage remains unproved; hosting increases GetNetMode traffic | exact A remains stable while hidden/unused; no exception/debug-register evidence identifies transport | if both visibility arms fail, a no-hook diagnostic retaining the rest is one later isolation candidate |
| H5: a non-memory signal such as SIGPIPE is converted into process exit by GameAnalytics | exact handler catches SIGPIPE and many other signals then `_Exit(1)` | collected log omits the signal number and stack; timing of nearby HTTP activity is not causality | capture signal number plus symbolicated fault stack in a diagnostic run |

No hypothesis is promoted to cause and no source correction is justified yet.

## 7. One bounded device protocol

Use exact package A `-6` for both arms, the same world, no clients and the same
port. Capture Console filtered to `ShooterGame` and `ServerHost` before pressing
Start.

1. Arm H: open the panel, press `Start server` once, wait until the panel reports
   either `Hosting started`/Listening or a terminal error, then immediately
   close the panel with the floating button. Do nothing for five minutes.
2. Fully terminate and relaunch the game into the same world.
3. Arm V: press `Start server` once under the same conditions and leave the
   panel visible for five minutes. Do nothing else.
4. For each arm report: whether `Hosting started` appeared, alive/exited, elapsed
   time from Start, the final 30 Console lines, and any `GASignalHandler entered`
   marker.

Pass/fail interpretation:

- H survives and V exits: UI visibility/render/snapshot is the selected next
  boundary; do not change host policy yet.
- H and V both exit after a comparable host transition: visibility is rejected;
  select one host/transport diagnostic using the last ServerHost log and stack.
- neither exits: the current failure is intermittent; repeat each arm once
  before changing source.
- H exits and V survives: timing is nondeterministic; repeat, with no causal
  conclusion.

Current honest state: **ready for this bounded device test**. No fix package was
created and the A/B original-NetMode package remains suspended until a stable
host-started baseline exists.

The supplied log does not encode whether the ServerHost panel was hidden after
Start or left visible. That one user observation is required to classify this
capture as arm H or arm V; until supplied, it is failure confirmation rather
than completion of either arm.
