# Codex research and implementation workflow

This file defines how a Codex task should continue Server-Host V2 across chats.
The goal is sustained work on one outcome with durable evidence, not a sequence
of speculative patches.

## Start-of-task protocol

1. Read every document listed in `README.md` in the mandatory order.
2. Read the current workflow entry in `STATUS.md` and the relevant rows in
   `EVIDENCE.md` and `TEST_MATRIX.md`.
3. Inspect the current working tree before assuming a prior task completed all
   described changes.
4. Read the relevant Sishen implementation in full enough to understand its
   actual pattern. Record the files and ideas used; do not merely name Sishen.
5. Identify the exact current-build evidence required from FreshSDK, iOS IDA,
   Android symbols, UE source, or live logs.
6. State one bounded workflow and its pass/fail criteria before editing code.

For a documentation-only task, state that no runtime code, build artifact or
device state will change. Do not manufacture an implementation workflow merely
to produce a package.

## Claim-state lifecycle

Artifact/capability claims advance only through evidence actually produced:

```text
unverified
  -> compiled
  -> statically validated
  -> ready for device test
  -> device verified
```

`compiled` and `statically validated` may both apply to one artifact, but neither
implies runtime behavior. A failed test of the active V2 artifact moves the affected runtime claim to
`unverified` or `contradicted` and the workflow to
`failed-under-investigation`; it does not erase the compile/static result.
Legacy results are stored in the Legacy archive and do not change the active V2
state unless the user explicitly switches to a Legacy investigation.

## Workflow phases

### Phase A — reproduce and constrain

- Write the observed and expected behavior.
- Identify exact host/client builds, devices, map, connection sequence and
  timing.
- Separate transport, gameplay login, replication, UI, persistence and save
  symptoms. They are not interchangeable.
- Establish the last known control build and smallest suspect delta.

### Phase B — evidence collection

- Inspect current source and generated SDK structures.
- Use IDA MCP when native behavior or ABI matters. If the required database is
  not open, explicitly ask the user to open it. Current iOS work uses
  `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64`.
- Follow xrefs/callers and state mutations until the call contract is clear.
- Compare with Android symbols and UE source where they provide names or
  implementation context.
- Update `EVIDENCE.md` with confirmed, contradicted and still-unknown facts.
- Put substantial per-function analysis in a named file under `evidence/` and
  link it rather than pasting a long decompilation narrative into the registry.

This phase may conclude without a code change. That is a valid result when the
evidence disproves the proposed implementation or identifies missing input.

### Phase C — design the smallest intervention

- Choose direct typed call, ProcessEvent, vtable call, hook, or observation based
  on evidence, not convenience.
- Specify ownership, thread, lifecycle, retry/idempotence and teardown.
- Keep raw ABI operations behind typed bindings.
- Define runtime validations and fail-closed behavior.
- Add a feature flag when an experiment can affect unrelated game systems.

### Phase D — implement and statically verify

- Make only the changes required by the active workflow.
- Keep refactors behavior-neutral or split them into a preceding workflow.
- Build with warnings visible.
- Run available static checks, symbol inspection and artifact checks.
- Update source-facing documentation and the ABI registry with the actual
  implementation, not the intended implementation.

### Phase E — hand off one device test

Provide:

- exact package path and build ID;
- control package or rollback path;
- host and client preparation;
- exact action sequence;
- expected log transitions;
- pass/fail conditions;
- which additional logs/crash files to return on failure.

Set `STATUS.md` to `awaiting-device-test`. Do not call the behavior verified.

### Phase F — process the result

On pass:

- add the test result to `TEST_MATRIX.md`;
- promote only the tested fact in `EVIDENCE.md`;
- update `STATUS.md` and the roadmap gate;
- record any untested edge cases.

On failure:

- execute the failure-intake protocol below;
- remain in the same workflow;
- do not begin another feature.

## Failure-intake protocol

When the user says that the exact artifact in the current V2 workflow failed,
crashed, timed out, corrupted state, or produced a visual/gameplay regression,
update the living documents before or alongside deeper investigation:

1. Append a dated entry to `TEST_MATRIX.md` with build, environment, steps,
   observed result and available evidence.
2. Set the current workflow in `STATUS.md` to `failed-under-investigation`.
3. Downgrade affected `EVIDENCE.md` claims from verified to contradicted or
   unverified. Preserve the old conclusion in the notes.
4. Append to `HISTORY.md` if the failure changes architecture, requirements, or
   a previously important conclusion.
5. Record the smallest suspected change set; do not assert causality without a
   differential test or binary/source evidence.
6. Prefer a diagnostic A/B package that removes one suspect at a time.
7. Work on that workflow until it passes, is disproven, or is blocked on a
   specific required artifact/user action.

Never edit or delete the earlier result row after a fix. The next package and
test get a new ID and row linked to the failure it addresses.

If the report concerns Legacy, preserve it under `archive/legacy/` with its
artifact identity, date, hashes, observations and conclusions. Do not set V2 to
`failed-under-investigation`, suspend Gate 2, or run a Legacy build unless the
user explicitly chooses Legacy investigation.

If new user feedback changes the requested behavior, update `PROJECT.md` or
`ROADMAP.md` as well. Do not bury a requirement change inside a test note.

## Documentation ownership

| Event | Required update |
|---|---|
| User changes goal or priority | `HISTORY.md`, `PROJECT.md`, `ROADMAP.md` |
| ABI/function/field confirmed | `EVIDENCE.md`, relevant architecture docs |
| Implementation decision | `STATUS.md`, `EVIDENCE.md`, optional decision note |
| New package ready | `STATUS.md`, `TEST_MATRIX.md` pending row |
| Device pass/failure | `TEST_MATRIX.md`, `STATUS.md`, `EVIDENCE.md` |
| Regression changes design | all relevant files plus `HISTORY.md` |
| Deep IDA/caller/ABI report completed | new/updated `evidence/*.md`, summary link in `EVIDENCE.md`, contract state in `ABI_BACKLOG.md` |
| Documentation-only consistency refresh | living docs and `STATUS.md`; explicitly no artifact/device claim |

Documentation must remain concise enough to read at the start of every task.
Move deep per-function reverse-engineering reports into future `evidence/`
documents and link them from `EVIDENCE.md`.

## Scope control

One active workflow may contain multiple technical steps, but they all must
serve one observable result. Examples:

- acceptable: map GetNetMode callers, compare UE source, implement one policy,
  and build an A/B package for far replication;
- unacceptable: change GetNetMode, rewrite save, add kick, and alter client
  return-to-menu in the same package.

No new V2 workflow begins while `STATUS.md` says `awaiting-device-test` or
`failed-under-investigation` for the current V2 workflow, unless the user
explicitly changes priority. Archived Legacy failures are outside this lock.

## End-of-task consistency audit

Before handoff, report and record:

- requirements that conflict and the chosen precedence, or “none found”;
- referenced artifacts/paths that are missing;
- claims that remain unverified or contradicted;
- current workflow state and the exact next bounded action;
- files changed, artifact path if any, disabled behavior and rollback/control;
- whether runtime code or legacy behavior changed.
