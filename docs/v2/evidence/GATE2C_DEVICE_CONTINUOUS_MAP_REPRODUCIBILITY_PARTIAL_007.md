# Gate 2C `.4` continuous map-generation reproducibility PARTIAL 007

Result ID: `V2-G2C-CONTINUOUS-MAP-REPRODUCIBILITY-PARTIAL-007`

Date recorded: 2026-08-19.

## Exact input and local identity check

```text
build_id=gate2c-live-relationships-20260819.4
source_revision=4db2599d25350b1eadd9d704afcba2fe76743473
source_tag=v2-gate2c-live-relationships-20260819.4-source
raw_dylib=/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate2c-live-relationships-20260819.4/ServerHostV2.dylib
dylib_sha256=95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677
macho_dsym_uuid=7CB1B073-D9A5-39E0-BDD3-2638B0618B28
profile=ios-shootergame-1.10280-exact-e52a980c
reported_lifecycle=map for all three captures
```

The local raw dylib SHA-256 matches the supplied artifact identity. Its Mach-O
UUID and sibling dSYM UUID both match the supplied UUID, and the source tag
resolves to the revision embedded in every startup line. File metadata was
recorded before documentation changes. The artifact was not modified or
rebuilt while processing this result.

Claim status before: one continuous `.4` session already device-proved fresh
discovery replacement, validated map-world replacement and an unchanged-world
repeat, while menu lifecycle/action context and a visible-regression
observation remained missing.

Claim status after: a second independent continuous `.4` process reproduces
the same generation and relationship behavior. The new transcript still does
not label the three user-visible states/actions, and every runtime lifecycle
field is `map`; therefore it cannot by itself establish the required main-menu
to TheIsland transition or the explicit no-regression condition. Gate 2C
remains open and Gate 3 remains blocked/not started.

## Process continuity

The second and third reports contain the complete preceding bounded-log prefix.
They show one startup at `seq=1 uptime_ms=0`, one unchanged build/source/profile
identity, strictly increasing sequence numbers and monotonic uptime:

```text
capture 1 request/complete: seq=13/15 uptime_ms=20338/20388
capture 2 request/complete: seq=26/28 uptime_ms=47805/47851
capture 3 request/complete: seq=30/32 uptime_ms=57705/57752
```

There is no second startup, sequence reset or uptime reset. The three captures
therefore belong to one process and one `WorldGenerationTracker` session. This
continuity does not identify which user-visible state preceded each capture.

## Capture audit

| Capture | Request / complete seq and uptime | Discovery generation | World generation | Previous discovery invalidated | Previous world invalidated | Engine | GameViewport | World | GWorld / ViewportWorld | NetDriverDefinitions | AuthorityGameMode | GameState | NetDriver | Hooks / calls / mutation | Errors |
|---|---|---:|---:|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `13@20338` / `15@20388` | 1 | 1 | not applicable | no | pass: unique fresh non-CDO exact ShooterEngine chain | pass: fresh GameViewportClient | pass: fresh validated World | match | pass: bounded populated array; one GameNetDriver, EOS primary/Ip fallback | present; GameModeBase validated | present; GameStateBase validated | none | `0 / 0 / 0` | none in bounded log |
| 2 | `26@47805` / `28@47851` | 2 | 2 | yes | yes | pass | pass | pass: validated replacement | match | pass; same canonical definition | present; GameModeBase validated | present; GameStateBase validated | none | `0 / 0 / 0` | none in bounded log |
| 3 | `30@57705` / `32@57752` | 3 | 2 | yes | no | pass | pass | pass: same validated current World identity | match | pass; same canonical definition | present; GameModeBase validated | present; GameStateBase validated | none | `0 / 0 / 0` | none in bounded log |

All captures completed both the fresh Gate 2B prerequisite and relationship
phase. Every required FName, core object/function and bounded reflection
validator passed. Total captures completed in 48/43/44 ms; relationship reads
were bounded to 10,096/10,240/10,240 bytes and 1/2/2 ms. No retry or abort was
reported.

## Generation and relationship conclusion

Discovery advanced `1 -> 2 -> 3`; the second and third captures each reported
top-level `Previous invalidated=yes`. This proves fresh owned discovery
replacement and rejects reuse of a prior discovery snapshot.

Capture 2 observed a different validated World identity, incremented world
generation `1 -> 2`, and reported `previous_world_invalidated=yes`. The prior
World/Viewport/NetDriver/GameMode/GameState handles were therefore invalidated
before the replacement relationship report was accepted.

Capture 3 again used a fresh discovery snapshot but resolved the current World
to the same generation-bound identity. World generation stayed 2 and
`previous_world_invalidated=no`. Engine, GameViewport, World/GWorld,
NetDriverDefinitions, AuthorityGameMode, GameState and normal pre-host
`net_driver=none` were all re-read and revalidated in discovery generation 3.
No stale identity error or evidence of stale pointer reuse appears.

This independently reproduces the generation mechanics already captured in
`V2-G2C-CONTINUOUS-MAP-GENERATIONS-PARTIAL-006`. It does not identify the
external lifecycle action that caused capture 1 -> capture 2. Object-count
similarity to an earlier menu result is not lifecycle proof, and a `map` label
must not be silently rewritten to `menu`.

## Redaction, capability and regression audit

There is no `severity=error` entry. The reports contain no heap pointer, raw
address or ASLR slide; `exact-profile-rva-roots` is a symbolic profile label,
and UUID, fingerprint and decimal segment sizes are permitted identity
metadata. Every capture reports exactly:

```text
hooks=0
engine_calls=0
mutation=0
```

The transcript contains no stale-identity failure and no runtime error. It also
contains no explicit observation about visible gameplay, input or audio
regression, and it does not state whether capture 1 was taken in the main menu,
capture 2 after natural entry to TheIsland, and capture 3 in the same TheIsland
without travel. Those facts are not inferred from object counts or successful
relationship validation. Death/respawn remains outside PASS/FAIL.

## Gate disposition and minimal missing evidence

This is an immutable partial PASS. It strengthens Gate 2C by independently
reproducing continuous-process discovery invalidation, world replacement,
same-world stability, every live relationship, optional base-class validation,
normal null NetDriver and zero capabilities. It does not close Gate 2C.

If these exact three captures were in fact performed as main menu -> natural
TheIsland entry -> same TheIsland with no intervening travel, no new capture is
needed: supply only that action annotation plus an explicit statement that no
visible gameplay/input/audio regression occurred. That contextual evidence can
then be evaluated against this immutable transcript.

If those actions were not the actual sequence, use the same existing `.4`
artifact for one continuous main-menu -> TheIsland -> same-TheIsland sequence
and return the labeled captures plus the no-regression observation. No source
change or new build is justified. Gate 3, Host research, hooks, `ProcessEvent`,
UE calls, hosting, NetMode policy and mutation remain not started.
