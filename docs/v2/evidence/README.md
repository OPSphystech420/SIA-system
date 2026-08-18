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
