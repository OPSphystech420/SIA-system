# Gate 1.5 Sideloadly functional device PASS 002

Report ID: `V2-G1.5-SIDELOAD-PASS-002`  
Workflow / ABI backlog IDs: Gate 1.5 / ABI-001, ABI-026  
Date: 2026-08-18  
Evidence source: user manual Sideloadly execution  
Claim before: corrected `.2` was statically validated but device-unverified  
Claim after: `functional-device-pass; extended-soak-pending`

## Exact artifact

```text
Build ID: gate1.5-diagnostic-ui-20260818.2
Source revision: 8fb09e654466b07b534a3dd16b2618e789d84777
Input dylib SHA-256: 4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32
```

The identity above is the raw input before Sideloadly re-signing. Its source tag
is `v2-gate1.5-diagnostic-ui-20260818.2-source`; the preserved manifest and dSYM
remain under `packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/`.

## User-supplied runtime receipt

The user reported the following bounded messages:

```text
button action received
open requested
overlay attached and hierarchy verified for open
first frame entered
Metal drawable and render-pass descriptor acquired
ImGui frame rendered and submitted
first frame presented
close completed; Metal rendering stopped
button action received
open requested
first frame presented
bounded diagnostic logs copied
```

This device-verifies the icon action, visible Metal/ImGui first frame, Status,
Logs, Copy logs, Close and reopen. The UIKit failed-stage fallback did not
appear. The diagnostic receipt retained `hooks=0`, `engine_calls=0` and
`mutation=0`.

The two temporary screenshot paths supplied with the result were already absent
when preservation was attempted. No screenshot bytes or hashes are claimed.

## Bounded PASS and explicit unknowns

This is a functional device PASS for the corrected presentation path. It is not
a claimed seven-minute, ten-minute or twenty-minute stability PASS. The user did
not separately report:

- the longer menu/map soak;
- an independent touch pass-through check outside the open diagnostic window;
- device/OS identity or resource measurements.

Those remaining read-only checks move into `PLAN-G2A-SIDELOAD-001`; the earlier
missing evidence is not retroactively inferred. The user explicitly authorized
progression to Gate 2, which is now split into 2A/2B/2C. Only Gate 2A is active.

## Result

Gate 1.5 changes from `failed-under-investigation` to
`functional-device-pass; extended-soak-pending`. The failed `.1` row remains an
immutable contradicted result and is not rewritten by this PASS.
