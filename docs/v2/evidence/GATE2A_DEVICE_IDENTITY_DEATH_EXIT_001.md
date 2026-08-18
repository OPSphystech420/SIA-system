# Gate 2A device identity PASS and death-triggered signal exit

Date: 2026-08-18

Identity result: `V2-G2A-IDENTITY-PASS-001`

Failure intake: `V2-G2A-DEATH-SIGNAL-EXIT-001`

Causal protocol: `PLAN-G2A-DEATH-CAUSAL-001` (closed after arm A)

This report separates the exact artifact execution from its later no-injection
control. The exact
image-identity sub-contract is device-verified. Extended Gate 2A stability is
contradicted by a death/respawn-triggered signal exit whose cause is not yet
classified.

## Exact artifact

```text
Build ID: gate2a-exact-identity-20260818.1
Source revision: 17e4e09ce8029bb89b22560da771ddc170e2ad0d
Raw input dylib SHA-256:
65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72
```

This is the single artifact recorded by `V2-G2A-BUILD-006`. No diagnostic
variant or replacement package was built for this intake.

## Device-verified identity sub-contract

The user reported the following runtime receipt:

```text
identity_state=exact-match
UUID=E52A980C-9C36-34C7-84B0-DD6E846328DC
text_fingerprint=8bfc1fd248a5...
segments=matched exact Gate 2A profile card
scans_started=0
hooks=0
engine_calls=0
mutation=0
```

Status/Logs, panel open/close/reopen, Copy logs and panel interaction were also
confirmed. This makes `V2-G2A-IDENTITY-PASS-001` a device PASS for the positive
exact-target identity sub-contract. It does not claim the still-unexecuted
wrong-profile negative or extended stability PASS.

The two temporary screenshot paths supplied for this execution were absent
when checked. No screenshot bytes or hashes are claimed.

## Immutable death-signal failure intake

Console capture:

```text
/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/gate2a-exact-identity20260818_logs.md
SHA-256: 0578303bea504af55cf6762d147debe6443e6f915bc9d3a56738608b360c7a8f
```

Observed conditions supplied by the user:

- Apple Silicon Mac;
- local saved world;
- no EOS login;
- the character died;
- ShooterGame exited while transitioning into the death/respawn state;
- the Gate 2A panel was open: its last V2 `open` was at
  `uptime_ms=120678`, with no later `close` receipt;
- the signal marker appeared at approximately the 145th process second.

The preserved Console capture contains `GASignalHandler entered` exactly at
line 7579 (`19:23:56.052907+0300`). Lines 7580–7591 show the subsequent crash-
event network submission completing successfully, including HTTP 200 at line
7585. HTTP 200 is only the result of sending that event; it is not evidence for
the cause of the signal or exit.

The capture contains no signal number, stack/backtrace or identified faulting
thread. No new ShooterGame `.ips` dated 2026-08-18 was present in
`~/Library/Logs/DiagnosticReports` when checked. The game's signal handler may
terminate with `_Exit(1)`, but the absence of `.ips` does not independently
prove which signal or fault occurred.

Result `V2-G2A-DEATH-SIGNAL-EXIT-001` therefore contradicts only extended Gate
2A stability. It does not contradict the exact identity PASS and does not assign
root cause to Server-Host, the HTTP request or the base game.

## Source audit: dangling UE pointer compatibility

The exact artifact source was audited without modification:

- `V2Entry` is a dylib constructor. Its sole production invocation of
  `LoadedImageCatalog::CaptureRuntime` performs copied Mach-O metadata parsing,
  exact profile selection and the complete `__TEXT,__text` fingerprint before
  the constructor returns.
- Gate 2A does not look up or read `Pawn`, `MyHUD`, `UWorld`, `UObject`,
  FNamePool or GUObjectArray. Foundation type/layout definitions exist in the
  source tree, but this runtime path never instantiates their readers or
  resolvers.
- `CheckedMemoryReader::Create` has no production caller. Its only call site is
  the synthetic host test; no Gate 2A discovery reader survives startup.
- The selection, memory source and mapped-image details are local to the
  constructor. Only owned/redacted strings are moved into the diagnostic
  publisher.
- After startup, the open UI captures `shared_ptr<const DiagnosticSnapshot>`
  values and renders copied status rows plus bounded log snapshots. It does not
  include or call the Platform/UE discovery layers.
- The device receipt independently confirms `scans_started=0` and every runtime
  capability counter at zero.

Consequently a dangling Pawn/HUD/World/UObject pointer inside V2 is incompatible
with the implemented Gate 2A path: no such pointer is acquired. This exclusion
does not rule out a base ShooterGame death/respawn bug, an interaction between
the continuously rendering open Metal/ImGui overlay and the respawn UI, or some
other latent startup/UI defect. Damage caused earlier by the bounded identity
read is structurally much less likely, but cannot be disproved from a signal
marker without a stack or causal control.

## Causal candidates and Legacy context

The evidence supports three candidates, not a conclusion:

1. base ShooterGame death/respawn behavior in the local no-EOS/save path;
2. conflict between the open Metal/ImGui overlay and the death/respawn UI;
3. significantly less likely latent corruption from injection/bootstrap or the
   startup identity boundary.

The explicit death trigger also makes a shared death-path explanation for some
archived Legacy signal exits plausible. That weakens any inference based only
on temporal correlation with hosting/hooks. The archived captures did not prove
the same gameplay trigger, so this remains a hypothesis and does not rewrite an
immutable Legacy result.

The apparent inability to drag the panel is separately explained by
`DiagnosticUIBootstrap.mm`: every rendered frame applies centered
`SetNextWindowPos(..., ImGuiCond_Always)`. It is not evidence for a `NoMove`
flag or for this exit.

## PLAN-G2A-DEATH-CAUSAL-001

Run each arm once, using the same ShooterGame 1.10280 save/map and character,
without EOS, hosting, client travel or any other mod.

### A — baseline

1. Launch ShooterGame with no injected ServerHost dylib.
2. Bring the same character to death.
3. Record whether respawn UI appears, whether the process exits, wall-clock
   time, approximate process uptime and Console tail.

### B — exact Gate 2A, UI closed

1. Inject the exact dylib named above.
2. Open once and verify its build ID, then close the panel.
3. Wait at least 30 seconds with the panel closed.
4. Bring the same character to death and record the same observations.

### C — exact Gate 2A, UI open

1. Fully restart the application with the same injected dylib.
2. Leave the Gate 2A panel open.
3. Bring the same character to death and record the same observations.

For every arm retain the exact start/death/respawn-or-exit times, whether
`GASignalHandler entered` appeared, the final Console tail and any new `.ips`.
Do not create a new package or change the artifact between B and C.

## Fixed interpretation

- **A exits at death:** strong evidence for a base-game/EOS/save death-path
  problem. Repeat A once. If reproduced, record the external baseline
  limitation and Gate 2B may continue.
- **A and B stable; C exits:** isolate the open Metal/ImGui presentation path.
  Gate 2B remains blocked until the UI issue is fixed.
- **A stable; B and C exit:** isolate a V2 injection/bootstrap/identity delta.
  Only then define a Gate 1.5 `.2` versus Gate 2A control; do not build it now.
- **A and B exit:** ambiguous. Repeat baseline A before any attribution.
- **All three stable:** intermittent result. Do not patch code without a second
  reproduction.

## Subsequent causal result

Result ID: `V2-G2A-DEATH-BASELINE-002`

```text
classification: external baseline reproduced
```

The user executed arm A with ShooterGame carrying no injected Server-Host
dylib, the same local saved world and a character death. The application exited
in the identical manner. Signing in to EOS did not alter the result.

This proves that Gate 2A injection is not necessary for the observed symptom.
It does not identify whether the stock cause is damaged save data, base
death/respawn logic or the iOS application running on Apple Silicon Mac, and
that attribution is outside this project workflow. It also does not assert
that V2 can never influence this path. Arms B/C are no longer required by
explicit user decision. Death/respawn is a reproduced baseline limitation and
is excluded from the current V2 stability acceptance criteria.

Final classification:

```text
Gate 2A exact identity: device verified
Gate 2A death exit: external baseline reproduced; deferred
Gate 2B: active
Gate 2C: not started
hooks=0 engine_calls=0 mutation=0
```
