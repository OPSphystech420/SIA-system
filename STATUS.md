# Server-Host V2 status

The active authority is [`docs/v2/STATUS.md`](docs/v2/STATUS.md).

Gate 2A exact identity and Gate 2B read-only discovery are device verified.
Gate 2C remains the only active workflow. Exact `.4` artifact
`gate2c-live-relationships-20260819.4` has device-proven Engine,
GameViewport, World/GWorld, NetDriverDefinitions, optional AuthorityGameMode/
GameState and normal pre-host `net_driver=none` relationships with
`hooks=0 engine_calls=0 mutation=0`.

Immutable result `V2-G2C-CONTINUOUS-MAP-GENERATIONS-PARTIAL-006` additionally
proves one continuous tracker session with discovery generations `1->2->3`, a
validated world replacement `1->2` that invalidated old world-bound identities,
and a fresh repeated capture of the unchanged current World `2->2`. All three
captures reported lifecycle `map`; no menu lifecycle/menu-map transition or
explicit visible-regression observation was supplied. Gate 2C therefore remains
open and Gate 3 is blocked/not started.

`V2-G2C-CONTINUOUS-MAP-REPRODUCIBILITY-PARTIAL-007` independently reproduces
the same continuous generation and relationship behavior in another process,
with zero capabilities and no error/address output. Its visible capture actions
and no-regression observation were not supplied, and every lifecycle field is
again `map`; it does not close the remaining menu-transition requirement.

The exact next action is to annotate `.7`: confirm capture 1 was main menu,
capture 2 followed natural entry to TheIsland, capture 3 was the same TheIsland
without travel, and no visible gameplay/input/audio regression occurred. If
that sequence was not used, repeat only that labeled sequence with the same
artifact. No new build or source correction is justified.

Legacy runtime, the root Legacy Makefile, old packages and `HostingRuntime` are
outside the workflow and remain unchanged. Death/respawn is a reproduced stock
baseline limitation and is not a Gate 2C PASS/FAIL condition.
