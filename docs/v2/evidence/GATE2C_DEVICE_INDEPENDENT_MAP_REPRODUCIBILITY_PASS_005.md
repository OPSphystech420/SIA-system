# Gate 2C `.4` independent map reproducibility PASS 005

Result ID: `V2-G2C-INDEPENDENT-MAP-REPRODUCIBILITY-PASS-005`

Date recorded: 2026-08-19.

## Exact input

```text
build_id=gate2c-live-relationships-20260819.4
source_revision=4db2599d25350b1eadd9d704afcba2fe76743473
source_tag=v2-gate2c-live-relationships-20260819.4-source
dylib_sha256=95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677
macho_dsym_uuid=7CB1B073-D9A5-39E0-BDD3-2638B0618B28
profile=ios-shootergame-1.10280-exact-e52a980c
reported_lifecycle=map
```

The user supplied the bounded report and complete bounded log list. No new
screenshot, hardware/OS detail, explicit process identifier or statement that
the process remained continuous from the preceding result was supplied. The
generation receipt itself resolves that ambiguity: this capture began with no
accepted predecessor in its tracker state.

## Device result

```text
Capture=complete
Relationship capture=complete
Profile roots=exact-profile-rva-roots
Lifecycle=map
Previous invalidated=not applicable
FName blocks / entries=180 / 399628
Objects num / max=109440 / 25231360
Chunks num / max=2 / 385
Valid / null / malformed=109440 / 0 / 0
Pending / unreachable=18 / 0
Copied bytes / duration ms=26123742 / 38
Retry / abort=none
Relationship bytes / duration ms=10240 / 2
Discovery / world=1 / 1
Previous world invalidated=no
hooks=0 engine_calls=0 mutation=0
```

All ten required FName round trips, all nine core object/function validators,
owned `UObject` metadata and `UFunction::FunctionFlags` passed. Parameter ABI
remained unavailable and native dispatch remained unused. The bounded logs
contain one explicit request and one successful completion, with no error
entry.

## Relationship proof accepted

- Native GEngine ownership again resolved to one fresh live identity.
- The Engine again passed unique non-CDO ShooterEngine direct-class and
  GameEngine/Engine ancestry validation.
- GameViewport and live World identities/classes passed.
- Independent GWorld and ViewportWorld reads matched the same fresh World
  identity.
- AuthorityGameMode and GameState were present and passed GameModeBase and
  GameStateBase relationship validation.
- NetDriver was the expected normal pre-host state `none`; hosting is not
  inferred.
- The populated definitions array contained one `GameNetDriver` with primary
  `OnlineSubsystemEOS.NetDriverEOS` and fallback
  `OnlineSubsystemUtils.IpNetDriver`.
- No raw pointer, heap address, ASLR slide or RVA was present in the bounded
  relationship report or supplied logs. The profile-root label is symbolic.

This independently reproduces the positive `.4` map relationship receipt with
different live object/FName counts. It does not establish continuity with
`V2-G2C-OPTIONAL-RELATIONSHIPS-MAP-PASS-004`.

## Required-condition audit

| Required condition | Observation | Disposition |
|---|---|---|
| Fresh discovery generation increases | `generation=1` | Not demonstrated; required same-tracker value was 2. |
| Same UWorld keeps world generation | `world=1` with no accepted predecessor | Not demonstrated; there is no same-tracker world to compare. |
| Previous discovery invalidated | `Previous invalidated=not applicable` | Not demonstrated; required value was `yes`. |
| Previous world invalidated remains no | `previous_world_invalidated=no` | Correct for this first accepted world, but not same-world stability evidence. |
| Engine/Viewport/World/GWorld/definitions | All passed | Device-reproduced positive map path. |
| AuthorityGameMode/GameState | Both present and base-class validated | Device-reproduced positive optional path. |
| Pre-host NetDriver | `none` | Passed; not hosting evidence. |
| Capabilities | `hooks=0 engine_calls=0 mutation=0` | Passed. |
| Error/stale/address leakage | No error or stale identity was reported; no raw address was published | Passed for report contents. Stale-handle rejection was not exercised because no prior snapshot existed. |

## Classification and gate boundary

This is an immutable PASS for an independent generation-1 `.4` map
reproducibility result. It is not the required repeated same-world capture and
does not close Gate 2C. The earlier `.1`, `.2`, `.3` and `.4` build/device
results remain unchanged. No source correction is justified by this output.
Gate 3 remains blocked and not started.

## Minimal next Gate 2C capture

If this exact `.4` tracker session and map are still active, press Capture once
more without restarting, reinjecting, returning to menu or replacing the
world. The next report must show:

```text
Previous invalidated=yes
Discovery / world=2 / 1
Previous world invalidated=no
hooks=0 engine_calls=0 mutation=0
```

All positive relationship validators must remain valid and the bounded output
must remain error/address-free. This single capture proves the missing
same-world stability condition only. The existing Gate 2C lifecycle-transition
item still requires a natural menu/map transition in one continuous tracker
session; if the submitted session has ended, use one new bounded menu → map →
same-map run rather than combining generation-1 results from separate runs.
