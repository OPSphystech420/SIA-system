# Gate 2C `.4` optional relationships map PASS 004

Result ID: `V2-G2C-OPTIONAL-RELATIONSHIPS-MAP-PASS-004`

Date recorded: 2026-08-19.

## Exact input and lifecycle

```text
build_id=gate2c-live-relationships-20260819.4
source_revision=4db2599d25350b1eadd9d704afcba2fe76743473
source_tag=v2-gate2c-live-relationships-20260819.4-source
dylib_sha256=95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677
macho_dsym_uuid=7CB1B073-D9A5-39E0-BDD3-2638B0618B28
profile=ios-shootergame-1.10280-exact-e52a980c
environment=first capture in an already loaded ordinary TheIsland world
```

This was not a menu-first run. The supplied bounded logs contain no error entry.

## Device result

```text
Capture=complete
Relationship capture=complete
Lifecycle=map
FName blocks / entries=180 / 399305
Objects num / max=106725 / 25231360
Chunks num / max=2 / 385
Valid / null / malformed=106725 / 0 / 0
Pending / unreachable=6 / 0
Copied bytes / duration ms=26045236 / 43
Relationship bytes / duration ms=10240 / 2
Retry / abort=none
Discovery / world generation=1 / 1
Previous world invalidated=no
hooks=0 engine_calls=0 mutation=0
```

All ten required FName round trips, all nine core object/function validators,
owned `UObject` metadata and `UFunction::FunctionFlags` passed. Parameter ABI
remained unavailable and native dispatch remained unused.

## Accepted relationship proof

- Native GEngine ownership resolved to one fresh live identity.
- The Engine remained a unique non-CDO ShooterEngine with exact direct UClass
  and validated GameEngine/Engine ancestry.
- GameViewport and live World identities/classes passed.
- Independent GWorld and ViewportWorld reads matched the same generation-bound
  World identity.
- `AuthorityGameMode` was present and its GameModeBase relationship validated.
- `GameState` was present and its GameStateBase relationship validated.
- NetDriver was normally absent: `net_driver=none`; hosting is not inferred.
- The populated canonical definitions array again decoded exactly one
  GameNetDriver with primary `OnlineSubsystemEOS.NetDriverEOS` and fallback
  `OnlineSubsystemUtils.IpNetDriver`.

This device-verifies the positive `.4` optional-presence publication path. No
raw identity/address was published. The `none` and `not-applicable: world=none`
presentation paths remain statically tested but are not device-proven here.

## Generation interpretation and remaining evidence

This first `.4` relationship capture established world generation 1. No prior
accepted `.4` world existed, so the top-level discovery receipt correctly said
`Previous invalidated=not applicable` and the world receipt said
`previous_world_invalidated=no`.

Gate 2C remains open. In the same process and unchanged TheIsland world, the
next capture must show:

```text
Previous invalidated=yes
Discovery / world=2 / 1
Previous world invalidated=no
hooks=0 engine_calls=0 mutation=0
```

Object/FName counts may naturally change; the world identity/generation must
not. A menu lifecycle capture and a validated menu-to-world or world-to-menu
transition are still absent. If natural return is possible, capture it and then
re-enter TheIsland; otherwise perform a later menu-first run.

Gate 3, Host research, hosting, travel, hooks, GetNetMode policy, calls and
mutation remain closed.
