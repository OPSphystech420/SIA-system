# Gate 2C `.3` device map relationship PASS 003

Result ID: `V2-G2C-MAP-RELATIONSHIPS-PASS-003`

Date recorded: 2026-08-19.

## Exact input

```text
build_id=gate2c-live-relationships-20260818.3
source_revision=f4598395efeadcd882af5f257b1e6d72a78de6d3
source_tag=v2-gate2c-live-relationships-20260818.3-source
dylib_sha256=4b7ddd7cf68cd089c69ca632415ec0a56594e49f60be0dccabc438dd471e2ae3
dsym_uuid=78EAF0B0-9C08-39BE-B37B-25E4A8EC7629
manifest_sha256=a821b4a88a8228b1f3b81d4c00da063b7103aa2ca35854ec24f95d369bc6749b
archival_deb_sha256=18d4dd6dab7d02325d4e2ce3f513cf1cbe0403d7263424669b2a5bcae674e8f6
profile=ios-shootergame-1.10280-exact-e52a980c
environment=local ordinary TheIsland world
```

The user reported no errors. This was a first capture in an already loaded
TheIsland world, not the menu-first sequence. No screenshot is attached to
this result; the supplied bounded report and logs are the evidence input.

## Device result

The exact profile matched and one explicit capture completed:

```text
Capture=complete
Relationship capture=complete
Lifecycle=map
FName blocks / entries=180 / 399305
Objects num / max=106725 / 25231360
Chunks num / max=2 / 385
Valid / null / malformed=106725 / 0 / 0
Pending / unreachable=6 / 0
Copied bytes / duration ms=26045310 / 45
Relationship bytes / duration ms=10240 / 2
Retry / abort=none
Discovery / world generation=1 / 1
Previous world invalidated=no
hooks=0 engine_calls=0 mutation=0
```

All ten required FName round trips, all nine core object/function validators,
the owned `UObject` `0x28` metadata layout and `UFunction::FunctionFlags` at
`0xB0` passed. Parameter ABI remains unavailable and native dispatch remained
unused.

## Relationship proof accepted

- The native GEngine root resolved to exactly one fresh live object identity.
- The Engine was a unique non-CDO ShooterEngine with exact direct
  `Class ShooterGame.ShooterEngine` and validated GameEngine/Engine ancestry.
  This device-verifies the dynamic direct-UClass path and the narrow transient-
  owner correction used by `.3`; it does not rewrite the immutable `.1` or
  `.2` aborts.
- `Engine->GameViewport` resolved to a fresh validated GameViewportClient
  identity.
- Both the GWorld root and `GameViewport->World` resolved to the same fresh,
  generation-bound World identity. The lifecycle classifier reported `map`.
- `World->NetDriver` was null and was correctly reported as the normal
  pre-host state `net_driver=none`. This is not evidence of Listen or hosting.
- `Engine->NetDriverDefinitions` was a stable bounded populated canonical
  array of `0x18`-byte definitions. Exactly one `GameNetDriver` decoded as:

```text
primary=OnlineSubsystemEOS.NetDriverEOS
fallback=OnlineSubsystemUtils.IpNetDriver
```

The array was not modified. The completed capture also means every non-null
optional relationship inspected by the implementation passed its same-snapshot
class relationship, but this report did not expose AuthorityGameMode or
GameState presence. Their presence is therefore not claimed.

## Generation interpretation

This first relationship capture established world generation 1. There was no
previous accepted relationship snapshot, so the top-level report correctly
said `Previous invalidated=not applicable` while the generation receipt said
`previous_world_invalidated=no`.

This result does not yet prove:

- a repeated capture of the same world keeps world generation 1;
- null-to-world, world-to-null or validated world-replacement increments;
- invalidation of prior World/Viewport/NetDriver/GameMode/GameState handles;
- a main-menu or loading lifecycle relationship snapshot.

## Disposition and next bounded capture

The Gate 2C map relationship subset is device-proven. Gate 2C remains open.
Review found that `.3` did not publish AuthorityGameMode/GameState presence,
although it validated those optional relationships internally. The narrow `.4`
receipt correction supersedes `.3` for further Gate 2C device execution. Run
the full menu/TheIsland/repeated-same-world protocol in
[the `.4` correction report](GATE2C_OPTIONAL_RELATIONSHIP_RECEIPT_FIX_004.md).
This does not rewrite the `.3` map PASS above.

Gate 3, Host research, hosting, travel, hooks, GetNetMode policy, calls and
mutation remain closed.

## Preserved limitations

- No Gate 2C menu or return-to-menu capture is claimed by this result.
- No repeated same-world generation-stability capture is claimed.
- No longer Gate 2B or Gate 2C soak is claimed.
- `Class Engine.World` is class metadata, not a live UWorld.
- Parameter ABI and native dispatch remain unavailable.
- NetDriver absence is not proof of hosting capability.
