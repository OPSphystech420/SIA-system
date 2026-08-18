# Server-Host V2 documentation

This directory is the durable project memory and operating manual for
Server-Host V2. It exists so a new Codex task can recover the user’s goals,
history, current evidence, active workflow and test state without treating the
legacy implementation or chat memory as current truth.

V2 is a separate architecture. No document here authorizes changing legacy
gameplay behavior or copying the current monolith into `SourceV2`.

## Mandatory reading order

Before planning, reverse-engineering, implementing, reviewing or processing a
device result, read these living files in full and in this order:

1. [HISTORY.md](HISTORY.md) — complaints, successful controls, regressions,
   requirements and changes of direction.
2. [PROJECT.md](PROJECT.md) — current iOS objective, scope and strategy.
3. [RULES.md](RULES.md) — binding, Sishen, IDA, type, hook, thread, lifetime,
   testing and documentation requirements.
4. [WORKFLOW.md](WORKFLOW.md) — one-workflow evidence/implementation/test cycle
   and mandatory failure intake.
5. [ROADMAP.md](ROADMAP.md) — ordered near-term iOS gates and short deferred
   Android/VPS direction.
6. [STATUS.md](STATUS.md) — current active workflow, verified state, blockers
   and exact next action.
7. [EVIDENCE.md](EVIDENCE.md) — bounded claim registry, decisions, hypotheses
   and conflicts.
8. [TEST_MATRIX.md](TEST_MATRIX.md) — immutable historical/device-result rows,
   planned protocols and failure-report template.

For architecture, ABI or implementation work, then read:

9. [ARCHITECTURE.md](ARCHITECTURE.md) — approved module/dependency/ownership/
   thread structure.
10. [MIGRATION_MAP.md](MIGRATION_MAP.md) — legacy subsystem and function
    disposition.
11. [ABI_BACKLOG.md](ABI_BACKLOG.md) — exact missing contracts and proving
    database/log/device test.
12. [evidence/README.md](evidence/README.md) — deep evidence-report index and
    report format.

The root [STATUS.md](../../STATUS.md) is a short V2 entry point. The detailed
active-workflow authority is [STATUS.md](STATUS.md); Legacy statuses and failure
material are preserved under [archive/legacy](archive/legacy/README.md).

## Claim language

Use these terms literally:

| Claim | Meaning |
|---|---|
| `compiled` | The named local build command succeeded for the named artifact. No runtime claim. |
| `statically validated` | The named assertions, source/profile checks and host tests passed. No device claim. |
| `ready for device test` | A uniquely identified artifact and complete user protocol exist. It has not passed yet. |
| `device verified` | The user supplied a passing result for the exact artifact, environment and protocol. |
| `contradicted` | Higher-quality evidence or a device failure disproved the claim. Preserve the earlier claim/history and record the contradiction. |
| `unverified` | Evidence is absent, incomplete, stale, mixed or not transferable to V2. |

“Non-crashing,” “present in source,” “found by a signature,” and “works in an
older package” are not substitutes for those states.

## Canonical paths and evidence roles

All paths below were checked on 2026-08-18.

| Material | Path | Role |
|---|---|---|
| V2 project | `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host` | Current workspace. |
| Legacy source | `../../Source`, `../../Menu`, `../../MenuLoad` | Research/regression source; preserve. |
| Known control deb identity | recorded path `../../packages/com.mhga.serverhost_0.2.11+debug_iphoneos-arm.deb` | Device-verified historical result and recorded hash; package file and matching source are now missing, so it is not an available rollback. |
| Current iOS IDA | `../../../Extra_For_Host/110280.i64` | Exact ShooterGame 1.10280 ABI/behavior authority. |
| SEA manager IDA/guide | `../../../Extra_For_Host/SEAServerManager.dylib.i64`, `../../../Extra_For_Host/SEA_host_guide.md` | Deferred control-plane/client-manager evidence, not UE hosting ABI. |
| Decrypted app/EOS | `../../../Extra_For_Host/com.studiowildcard.arkuse-1.10280-Decrypted`, its `Payload/ShooterGame.app/Frameworks/EOSSDK.framework/EOSSDK` | Current app/framework evidence when a workflow requires it. |
| FreshSDK dumps | `../../Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame`, `../../Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame-Full-Version` | Current generated type/name/layout input; validate live. |
| NetDriver report | `../../Reference/NetDriverDefinitions-1.10280.md` | Existing exact-build reverse-engineering report. |
| Sishen | `../../../Sishen/Sishen-main` | Primary V2 code-pattern reference; never current ABI truth. |
| Dragon | `../../../Dragon/ProjDragon/Dragon` | Secondary generated-SDK/typed-access pattern reference. |
| UE4.17 | `/Users/grimreaper31/Desktop/Dev/extra/engines/UE4.17` | Closest available engine behavior reference; lower than exact binary. |
| Android LibUE/IDA | exact path not recorded | Deferred and missing; ask the user when Android becomes active. |

## Prompt entry points

- [00_ARCHITECTURE_PLAN.md](prompts/00_ARCHITECTURE_PLAN.md) — architecture
  planning/reverse engineering only.
- [01_PROJECT_DOCUMENTATION.md](prompts/01_PROJECT_DOCUMENTATION.md) — refresh
  the living documentation.
- [02_FIRST_V2_WORKFLOW.md](prompts/02_FIRST_V2_WORKFLOW.md) — begin the next
  approved bounded implementation workflow.
- [03_FAILED_TEST_WORKFLOW.md](prompts/03_FAILED_TEST_WORKFLOW.md) — process a
  failed user device test without changing workflow.

## Maintenance rules

- A task that changes requirements, establishes/contradicts evidence, changes
  behavior, creates an artifact or receives a device result updates the relevant
  living files before handoff.
- History and device-result rows are append-only. Corrections add a dated note;
  they do not rewrite the earlier belief or result.
- Keep `EVIDENCE.md` as a summary registry. Put substantial function/caller/ABI
  work in `evidence/` and link it from the registry and `ABI_BACKLOG.md`.
- A documentation-only task must say that no runtime code, artifact or device
  state changed.
