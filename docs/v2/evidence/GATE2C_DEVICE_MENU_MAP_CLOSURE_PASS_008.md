# Gate 2C `.4` continuous menu-to-map closure PASS 008

Result ID: `V2-G2C-CONTINUOUS-MENU-MAP-DEVICE-PASS-008`

Device execution date: 2026-08-19. Context confirmation recorded: 2026-08-21.

## Exact input and immutable provenance

```text
build_id=gate2c-live-relationships-20260819.4
source_revision=4db2599d25350b1eadd9d704afcba2fe76743473
source_tag=v2-gate2c-live-relationships-20260819.4-source
raw_dylib=/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate2c-live-relationships-20260819.4/ServerHostV2.dylib
dylib_sha256=95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677
macho_dsym_uuid=7CB1B073-D9A5-39E0-BDD3-2638B0618B28
profile=ios-shootergame-1.10280-exact-e52a980c
```

The source tag resolves to the embedded source revision. A local read-only
check on 2026-08-21 reproduced the stated dylib SHA-256 and the same UUID for
the Mach-O and sibling dSYM. No artifact was rebuilt or modified while this
result was processed.

This result does not rewrite
`V2-G2C-CONTINUOUS-MAP-REPRODUCIBILITY-PARTIAL-007`. It combines that immutable
runtime transcript with the user's later contextual confirmation of the exact
visible actions and regression observation.

Claim status before: Gate 2C relationship and generation mechanics were
independently device-reproduced, but `.007` lacked visible-state/action labels
and an explicit regression observation.

Claim status after: Gate 2C is device verified and closed. Gate 3 is unblocked
but not started.

## Context supplied for the immutable transcript

The user confirmed exactly:

```text
capture1=main menu
capture2=TheIsland after natural entry
capture3=same TheIsland no travel
visible gameplay/input/audio regressions=none
```

The runtime classifier emitted `Lifecycle=map` in all three reports. That field
is preserved exactly and is not rewritten to `menu`. The first capture is
classified as a user-visible main-menu capture only by the supplied external
action record. Its live validated World, AuthorityGameMode and GameState show
that this menu state retained a live world; their presence is not corruption
and does not contradict the visible-state annotation.

## Artifact and process-continuity audit

There is one startup at `seq=1 uptime_ms=0`, one unchanged build/source/profile
identity and no sequence or uptime reset. Requests and completions are strictly
ordered:

```text
capture 1 request/complete: seq=13/15 uptime_ms=20338/20388
capture 2 request/complete: seq=26/28 uptime_ms=47805/47851
capture 3 request/complete: seq=30/32 uptime_ms=57705/57752
```

The three captures therefore belong to one process and one tracker session.

## Capture audit

| Capture / visible state | Seq / uptime request → complete | Discovery generation | World generation | Previous discovery invalidated | Previous world invalidated | Engine | GameViewport | World | GWorld / ViewportWorld | NetDriverDefinitions | AuthorityGameMode | GameState | NetDriver | Hooks | Engine calls | Mutation | Errors |
|---|---|---:|---:|---|---|---|---|---|---|---|---|---|---|---:|---:|---:|---|
| 1 — main menu | `13@20338 → 15@20388` | 1 | 1 | not applicable | no | pass: unique fresh non-CDO exact ShooterEngine chain | pass: fresh GameViewportClient | pass: fresh validated World | match | pass: bounded populated array; one GameNetDriver, EOS primary / Ip fallback | present; GameModeBase validated | present; GameStateBase validated | none | 0 | 0 | 0 | none |
| 2 — TheIsland after natural entry | `26@47805 → 28@47851` | 2 | 2 | yes | yes | pass | pass | pass: validated replacement | match | pass; same canonical definition | present; GameModeBase validated | present; GameStateBase validated | none | 0 | 0 | 0 | none |
| 3 — same TheIsland, no travel | `30@57705 → 32@57752` | 3 | 2 | yes | no | pass | pass | pass: same validated current World identity | match | pass; same canonical definition | present; GameModeBase validated | present; GameStateBase validated | none | 0 | 0 | 0 | none |

Every capture completed its fresh Gate 2B prerequisite and relationship phase.
All required FName, object/function and bounded reflection validators passed.
Total capture durations were 48/43/44 ms; relationship reads were bounded to
10,096/10,240/10,240 bytes and 1/2/2 ms. No retry or abort occurred.

## Contract conclusions

- Fresh discovery advanced `1 -> 2 -> 3`. Captures 2 and 3 reported
  `Previous invalidated=yes`, proving replacement of the prior owned discovery
  snapshot rather than stale reuse.
- Natural main-menu to TheIsland entry changed the validated World identity,
  advanced world generation `1 -> 2`, and reported
  `previous_world_invalidated=yes`. Previous World/Viewport/NetDriver/
  GameMode/GameState handles were invalidated before the replacement report was
  accepted.
- The no-travel TheIsland repeat used a fresh discovery snapshot while world
  generation stayed 2 and `previous_world_invalidated=no`. This proves stable
  current-UWorld identity without a false world-generation increment.
- Engine, GameViewport, World, independently read GWorld, and
  NetDriverDefinitions remained valid at every step. GWorld and ViewportWorld
  always resolved to the same generation-bound World identity.
- AuthorityGameMode and GameState remained present and passed GameModeBase and
  GameStateBase validation.
- `net_driver=none` remained the normal pre-host state. It is not evidence that
  Listen/hosting exists.
- There is no `severity=error`, stale-identity failure, raw heap/address/ASLR
  disclosure or capability activation in the supplied reports. The symbolic
  `exact-profile-rva-roots`, UUID, fingerprint and segment sizes are permitted
  profile metadata.
- The user observed no visible gameplay, input or audio regression. Death/
  respawn was not used as PASS/FAIL.

## Gate disposition

The required Gate 2C sequence passes. The exact `.4` artifact device-validates
the live Engine/GameViewport/World/NetDriverDefinitions relationships, natural
menu-to-map world replacement and invalidation, same-world generation stability,
normal pre-host null NetDriver, bounded address-free reporting and exactly:

```text
hooks=0
engine_calls=0
mutation=0
```

Gate 2C is closed as device verified. Gate 3 is unblocked but not started.

## Preserved limitations

- A natural TheIsland-to-menu return capture was not supplied and is not
  claimed; it was optional under the Gate 2C protocol.
- No longer Gate 2B or Gate 2C soak is claimed.
- `Class Engine.World` is class metadata, not a live UWorld.
- Parameter ABI and native dispatch remain unavailable.
- A null pre-host NetDriver does not prove hosting or Listen behavior.

## Exact next bounded workflow

The next workflow is **Gate 3A — exact game-thread scheduler contract research
(`ABI-015`)**. Before any dispatcher implementation:

1. read the mandatory Sishen startup/game-thread implementation in
   `Source/Main.h` and `Source/Main.mm` and the directly used scheduling helpers;
2. use exact `110280.i64` to recover the current `FIOSAsyncTask` entry,
   representative callers, callback ownership/lifetime, queue and game-thread
   identity, cancellation, shutdown and background/foreground behavior;
3. compare only the relevant closest UE4.17 `IOSAsyncTask.cpp` behavior;
4. publish the ABI-015 contract card, conflicts, failure behavior and bounded
   static/device test plan.

That workflow is evidence-only until its contract is reviewed. It adds no
SourceV2 dispatcher, UE call, hook, hosting, travel, NetMode policy or mutation.
