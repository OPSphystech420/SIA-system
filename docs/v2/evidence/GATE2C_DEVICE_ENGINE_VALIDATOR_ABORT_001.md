# Gate 2C device Engine-validator abort 001

```text
Report ID: V2-G2C-ENGINE-VALIDATOR-ABORT-001
Workflow / ABI backlog IDs: Gate 2C / ABI-009 / ABI-010
Date: 2026-08-18
Exact platform and build identity: ShooterGame 1.10280 arm64; exact profile UUID E52A980C-9C36-34C7-84B0-DD6E846328DC
Device artifact: gate2c-live-relationships-20260818.1
Source revision: 695b230d9db8438142c48aa4b9eb6479e3e1fe35
Input dylib SHA-256: 9a0aee70e9012dd57a1fa543b035f5037d7e0ed26c800e8e029ef4c438ffefb4
Classification: deterministic fail-closed Engine identity validator rejection
Claim status before: Gate 2C clean artifact ready; device pending
Claim status after: Gate 2C .1 live relationship capture contradicted; correction required
```

## Device receipt

The user executed the exact `.1` artifact in a local TheIsland world. Exact
image/profile selection passed and an explicit fresh Gate 2B snapshot completed
in 37 ms:

```text
FName blocks / entries=180 / 399494
Objects num / max=110906 / 25231360
Chunks num / max=2 / 385
Valid / null / malformed=110906 / 0 / 0
Pending / unreachable=6 / 0
Copied bytes=26141130
```

All ten required FName round trips, all nine core object/function validators,
the owned `UObject` layout, and `UFunction::FunctionFlags` passed. Parameter ABI
remained unavailable and native dispatch was not used.

Gate 2C then aborted before its first relationship byte was accepted:

```text
Retry / abort=native Engine identity failed exact ShooterEngine class/full-name validators
Relationship bytes / duration ms=0 / 0
Discovery / world generation=1 / 0
Previous world invalidated=no
hooks=0 engine_calls=0 mutation=0
```

No Engine, GameViewport, World, NetDriver, definitions, lifecycle or world-
generation value is claimed from this run. The fresh Gate 2B snapshot remains a
valid prerequisite result inside the attempt, but it does not turn the aborted
relationship phase into a Gate 2C PASS.

Temporary screenshots supplied at intake:

```text
/var/folders/n0/y5h0f9qs3053tyzp2mq0vc040000gn/T/TemporaryItems/NSIRD_screencaptureui_OfmBHO/Снимок экрана — 2026-08-18 в 23.25.22.png
SHA-256 54e5af75529bd0a861501c11efb8f34a5c26a3e68d24ba535ad20cc492e0986c
746x566

/var/folders/n0/y5h0f9qs3053tyzp2mq0vc040000gn/T/TemporaryItems/NSIRD_screencaptureui_UizcOw/Снимок экрана — 2026-08-18 в 23.25.35.png
SHA-256 65941f993a6b05b17c38125cb60d91a83b4d15b26aad76846f6f765e114a5ed0
718x326
```

They visibly confirm the `.1` build/source, exact profile receipt, no scans
before the explicit action and zero hooks/engine calls/mutation.

## Source and reference audit

The `.1` failure text combined three predicates, so the device transcript alone
does not identify which predicate rejected the object. Source audit found one
invalid promoted assumption: the profile required the live Engine's direct
UClass to have object-array index `0x359`, copied from a FreshSDK object dump.
An object-array index is snapshot identity, not a cross-process ABI offset.
FreshSDK does establish `Class ShooterGame.ShooterEngine`, but its dump index is
not a stable runtime constant.

Sishen independently demonstrates the typed `Engine -> GameViewport -> World`
shape and a ShooterEngine class relationship. Its forever-cached object,
short-name lookup and offsets remain rejected. Exact native `GEngine` ownership,
the Gate 2B snapshot and the existing IDA/FreshSDK cards remain unchanged.

## Corrective contract

The correction removes game-specific UClass object indices from the exact
profile. For every explicit capture it:

- resolves `GEngine` to one live snapshot identity;
- separately validates runtime class name, strict live full name and non-CDO;
- follows the direct class relationship inside the same fresh snapshot;
- requires exact `Class ShooterGame.ShooterEngine`;
- then proves the independently validated `GameEngine` and `Engine` super chain;
- emits a distinct bounded failure for each predicate and no address.

The direct UClass identity is generation-bound by index, serial and discovery
generation for that capture only. It is never cached. A synthetic fixture now
moves the exact ShooterEngine UClass to a different object-array index and must
still pass; a wrong package/full name must fail. Normal and UBSan-only suites
each pass 387 assertions, and the boundary audit passes.

The replacement is `gate2c-live-relationships-20260818.2`, recorded as
`V2-G2C-ENGINE-VALIDATOR-FIX-BUILD-011`: source
`4a53ab940e8085c2e13c00489b4ab6ab9e95764c`, raw dylib SHA-256
`ee6f6d9014fa98171a105fa009750e4d078a099a8ecf4a969dce98c704b60cae`,
Mach-O/dSYM UUID `E70F89CA-A7DE-3AEA-8CA1-D23AEF07AD8F`. It changes only the
Gate 2C read-only Engine validator/diagnostics and its tests/receipts. Gate 3,
hosting, calls, hooks and mutation remain closed. The `.1` result above stays
immutable regardless of a later replacement result.
