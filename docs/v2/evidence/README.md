# Server-Host V2 deep evidence reports

This directory holds detailed, reproducible reverse-engineering and device-log
reports. `../EVIDENCE.md` remains the short claim registry; each report added
here must create or update one summary claim and the corresponding contract in
`../ABI_BACKLOG.md`.

## Current linked reports

- [Gate 1 typed foundation](GATE1_TYPED_FOUNDATION.md) — curated core layout,
  ownership, identity, reflection, build/profile and static-test provenance.
- [NetDriverDefinitions 1.10280](../../../Reference/NetDriverDefinitions-1.10280.md)
  — existing exact-build CreateNetDriver/definition analysis retained in its
  reference location.
- [GetNetMode architecture analysis](../ARCHITECTURE.md#9-hook-design-and-getnetmode-investigation)
  — current exact facts, hook boundary and remaining investigation plan. A
  standalone caller ledger belongs here when Gate 4 becomes active.
- [Sishen V2 foundation pattern review](SISHEN_V2_FOUNDATION_REVIEW_2026-08-18.md)
  — Makefile/source organization, startup phases, UE types/containers/names/
  objects and memory/address patterns adopted, adapted or rejected.
- [Gate 1.5 diagnostic UI review](GATE1_5_DIAGNOSTIC_UI_REVIEW.md) — Sishen and
  Legacy UI/Metal/ImGui patterns adopted, adapted or rejected for the inert
  Sideloadly diagnostic workflow.
- [Gate 1.5 Sideloadly failure intake 001](GATE1_5_SIDELOAD_FAILURE_001.md) —
  exact `.1` artifact identity, observed icon/no-panel result, preserved
  unknowns and correction boundary.
- [Gate 1.5 UI failure investigation](GATE1_5_UI_FAILURE_INVESTIGATION.md) —
  exact V2/Legacy/Sishen/Dragon files, verified failed-code defects, competing
  hypotheses and adopted/adapted/rejected presentation patterns.
- [Gate 1.5 Sideloadly functional PASS 002](GATE1_5_SIDELOAD_PASS_002.md) —
  exact `.2` identity, device-verified presentation functions and explicit
  extended-soak/touch unknowns carried into Gate 2A.
- [Gate 2A exact image identity](GATE2A_EXACT_IMAGE_IDENTITY.md) — exact offline
  ShooterGame/IDA identity, stable fingerprint range, Sishen dispositions and
  checked-memory fail-closed contract.
- [Gate 2A device identity and death exit](GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md)
  — positive exact-target identity PASS, immutable death/respawn signal-exit
  intake, source audit and the single no-build A/B/C causal protocol.
- [Gate 2B read-only contracts](GATE2B_READ_ONLY_CONTRACTS.md) — exact IDA
  FNamePool/GUObjectArray/UObject resolver cards, FreshSDK ASLR normalization,
  provenance/owned-snapshot design, static verification and device protocol.
- [Gate 2B device capture abort 001](GATE2B_DEVICE_CAPTURE_ABORT_001.md) —
  exact `.1` device receipt, deterministic fail-closed TUObjectArray rejection
  and reserved-capacity versus live-work validator correction.
- [Gate 2B menu PASS and world VM-region abort 002](GATE2B_DEVICE_MENU_PASS_WORLD_ABORT_002.md)
  — exact `.2` main-menu owned-snapshot PASS, TheIsland generation-2
  fail-closed region-boundary abort and the bounded multi-region correction.
- [Gate 2B device PASS 004](GATE2B_DEVICE_PASS_004.md) — exact `.3` completed
  owned snapshots in both menu and TheIsland, generation invalidation/count
  change, repeated validators and unchanged zero capabilities.
- [Gate 2C live relationships](GATE2C_LIVE_RELATIONSHIPS.md) — exact GEngine,
  GWorld, Engine/Viewport/World/NetDriver/definition cards, typed bounded
  capture, independent world generation, static acceptance and device protocol.
- [Gate 2C device Engine-validator abort 001](GATE2C_DEVICE_ENGINE_VALIDATOR_ABORT_001.md)
  — exact `.1` TheIsland prerequisite snapshot PASS, fail-closed relationship
  abort, invalid fixed UClass dump-index assumption and bounded `.2` correction.
- [Gate 2C `.2` Engine full-name abort 002](GATE2C_DEVICE_ENGINE_FULLNAME_ABORT_002.md)
  — exact `.2` TheIsland prerequisite snapshot PASS, isolated instance
  full-name failure, retained zero capabilities and narrow `.3` canonicalization/
  bounded diagnostic correction.
- [Gate 2C `.3` map relationship PASS 003](GATE2C_DEVICE_MAP_PASS_003.md)
  — exact `.3` first TheIsland capture validated the native Engine, Viewport,
  World/GWorld match, definitions and normal null NetDriver with world
  generation 1; stability and lifecycle transition evidence remain pending.
- [Gate 2C `.4` optional relationship receipt correction](GATE2C_OPTIONAL_RELATIONSHIP_RECEIPT_FIX_004.md)
  — publishes already-validated AuthorityGameMode/GameState presence without
  new reads; clean raw artifact and full repeat protocol.
- [Gate 2C `.4` optional relationships map PASS 004](GATE2C_DEVICE_OPTIONAL_RELATIONSHIPS_MAP_PASS_004.md)
  — first `.4` TheIsland capture passed with both optional relationships
  present/class-validated; generation stability and lifecycle transition remain.
- [Gate 2C `.4` independent map reproducibility PASS 005](GATE2C_DEVICE_INDEPENDENT_MAP_REPRODUCIBILITY_PASS_005.md)
  — a second fresh tracker state reproduced every positive map relationship,
  but discovery/world `1/1` and previous discovery not-applicable do not prove
  same-world generation stability or invalidation.
- [Gate 2C `.4` continuous map generations PARTIAL 006](GATE2C_DEVICE_CONTINUOUS_MAP_GENERATIONS_PARTIAL_006.md)
  — one cumulative tracker session proves discovery replacement, validated
  world replacement and an unchanged-world repeat with zero capabilities; all
  captures remained lifecycle `map`, so menu lifecycle transition evidence is
  still required.
- [Gate 2C `.4` continuous map reproducibility PARTIAL 007](GATE2C_DEVICE_CONTINUOUS_MAP_REPRODUCIBILITY_PARTIAL_007.md)
  — a second independent cumulative process reproduces discovery `1->2->3`,
  world `1->2->2` and every relationship with zero capabilities; visible
  capture actions and a no-regression observation were not supplied, so the
  repeated `map` lifecycle receipts do not close the menu transition.
- [Gate 2C `.4` continuous menu-to-map closure PASS 008](GATE2C_DEVICE_MENU_MAP_CLOSURE_PASS_008.md)
  — preserves `.007` and records the user's exact contextual confirmation:
  main menu -> natural TheIsland -> same TheIsland/no travel, with no visible
  gameplay/input/audio regression; Gate 2C is device verified and closed.
- [Archived Legacy failure evidence](../archive/legacy/README.md) — preserved
  reports and former execution rows. They are not active V2 blockers.

No standalone per-function report was invented for Gate 1; live resolver and
function reports remain ordered work for later gates.

## Naming

Use stable descriptive names, for example:

```text
IOS_1.10280_GETNETMODE_CALLERS.md
IOS_1.10280_NATIVE_HOST_INITIALIZATION.md
IOS_1.10280_PLAYER_INITIALIZATION.md
DEVICE_<build-id>_<workflow>_<date>.md
```

Do not key the filename only by an RVA; RVAs can change between builds.

## Required report header

```text
Report ID:
Workflow / ABI backlog IDs:
Date:
Author/task:
Exact platform and build identity:
Binary/database absolute path and hash/UUID when known:
FreshSDK/source paths used:
Sishen files/functions read for pattern comparison:
Device artifact/build and log paths, if applicable:
Claim status before:
Claim status after:
```

## Required content

1. Question and why the active workflow needs it.
2. Evidence-source precedence and any conflicts.
3. Exact symbols/addresses as diagnostic metadata, signatures and uniqueness.
4. Xrefs, representative callers, virtual dispatch, parameter/return recovery,
   state mutations, construction, teardown, side effects and failure paths as
   applicable.
5. Distinction between inline/thunk/wrapper/native/UFunction/Blueprint paths.
6. Relevant current FreshSDK/live reflection checks.
7. Sishen adopt/adapt/reject pattern comparison; its ABI is never copied as
   current truth.
8. Closest UE/Dragon/SEA comparison only at their proper evidence priority.
9. Facts, design decisions and hypotheses in separate subsections.
10. Remaining uncertainty and the exact database/log/device test that resolves
    it.
11. Contract card or reason the contract remains unavailable.
12. Links back to Evidence, ABI Backlog, Roadmap gate and immutable test row.

Avoid long copyrighted source excerpts or generated SDK dumps. Record small
instruction/pseudocode facts needed to support the contract and point to exact
local locations.

## Device reports

A device report never edits an earlier report/result to turn failure into pass.
It records exact artifact path/hash, host/client environment, map/endpoint,
actions, expected/observed state, bounded logs, crash material, attempt count,
control comparison and final classification. A later fix receives a new build,
report and `TEST_MATRIX.md` row.
