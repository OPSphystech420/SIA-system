# Gate 2B device PASS 004

```text
Result ID: V2-G2B-MULTIREGION-DEVICE-PASS-004
Date: 2026-08-18
Build ID: gate2b-readonly-contracts-20260818.3
Source revision: 852e260d353c9a67a18e5763f358f1242b6e7947
Source tag: v2-gate2b-readonly-contracts-20260818.3-source
Input dylib SHA-256: b5e5f0edf47ebb5b71c0c08d947bd6d186538ea2a9f9bc9722c4076ee0e07829
Mach-O / dSYM UUID: 48EB7BC3-7222-3F27-8A09-4224B980EF8C
Classification: Gate 2B device verified
```

## Exact identity and pre-capture state

Runtime selected the unique exact ShooterGame 1.10280 profile with UUID
`E52A980C-9C36-34C7-84B0-DD6E846328DC`, expected segment card and shortened
text fingerprint `8bfc1fd248a5...`. Before the first explicit action:

```text
scans_started=0
hooks=0
engine_calls=0
mutation=0
```

The panel opened and presented normally. Between the two captures, Close
stopped Metal rendering and reopen reacquired/presented a Metal/ImGui frame.

## Generation 1 — main menu

The explicit menu capture completed in 32 ms:

```text
FName blocks / entries: 178 / 390585
Objects num / max: 61177 / 25231360
Chunks num / max: 1 / 385
Valid / null / malformed: 61177 / 0 / 0
Pending / unreachable: 29 / 0
Copied bytes: 24675204
Retry / abort: none
```

All ten required FName round trips, all nine exact core class/function
relationships, owned UObject `0x28` metadata and UFunction flags at `0xB0`
passed. Parameter ABI remained explicitly unavailable and native UE dispatch
was not used.

## Generation 2 — TheIsland

After entering TheIsland, the explicit replacement capture completed in 44 ms:

```text
Previous invalidated: yes
FName blocks / entries: 180 / 399365
Objects num / max: 107275 / 25231360
Chunks num / max: 2 / 385
Valid / null / malformed: 107275 / 0 / 0
Pending / unreachable: 6 / 715
Copied bytes: 26049956
Retry / abort: none
```

All name, object/function and reflection validators passed again. Relative to
generation 1, the owned snapshot observed two additional FName blocks, 8,780
additional decoded entries, 46,098 additional object items and a second live
object chunk. The changed counts plus `Previous invalidated=yes` device-verify
successful discovery-generation replacement across menu-to-world transition.
The pending/unreachable values are reported item flags, not malformed items.

Both completed reports retained:

```text
scans_started=1
hooks=0
engine_calls=0
mutation=0
```

Bounded report copy succeeded after each capture. The supplied log continues
through `uptime_ms=127298` and contains no abort or crash.

## Scope and limitations

This closes Gate 2B for the exact ShooterGame 1.10280 profile: bounded explicit
FNamePool, GUObjectArray and minimal reflection snapshots are device verified
in both menu and ordinary TheIsland state. It also device-verifies the `.3`
multi-region composition correction that replaced the immutable `.2` world
abort.

The following are not inferred:

- a third capture after returning naturally to the menu was not reported; that
  optional protocol step is not required for the menu-to-world PASS;
- no longer soak, background/foreground cycle or death/respawn PASS is claimed;
- `Class Engine.World` is class metadata validation, not live GWorld/UWorld,
  Engine, GameViewport or NetDriver instance discovery;
- `NumParms`, `ParmsSize` and `ReturnValueOffset` remain unavailable;
- no ProcessEvent, native UE call, hook, write, hosting or mutation occurred.

Gate 2C is unblocked by this result but remains not started. It requires a
separate explicitly scoped workflow.
