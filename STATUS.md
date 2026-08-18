# Server-Host V2 status

The active authority is [`docs/v2/STATUS.md`](docs/v2/STATUS.md).

Gate 1.5 is `functional-device-pass; extended-soak-pending` under immutable
result `V2-G1.5-SIDELOAD-PASS-002`: corrected build `.2` device-verified the
icon, visible Metal/ImGui panel, Status, Logs, Copy logs, Close and reopen with
all runtime capability counters at zero. No unreported seven/ten-minute soak or
independent outside-window touch PASS is inferred.

Only Gate 2A is active: exact ShooterGame Mach-O identity, unique profile
selection and a checked read-only mapped-segment boundary. Gate 2B
(FNamePool/GUObjectArray/reflection) and Gate 2C
(Engine/GameViewport/World/NetDriver/generation) have not started.

`V2-G2A-BUILD-006` is statically validated and ready for device test: build
`gate2a-exact-identity-20260818.1`, source
`17e4e09ce8029bb89b22560da771ddc170e2ad0d`, raw dylib SHA-256
`65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72`.

Legacy runtime, the root Legacy Makefile, old packages and `HostingRuntime` are
outside the workflow and remain unchanged. The deferred production UI transfer
is recorded in [`docs/v2/UI_DESIGN_DEBT.md`](docs/v2/UI_DESIGN_DEBT.md); the
working Gate 1.5 panel remains the control.
