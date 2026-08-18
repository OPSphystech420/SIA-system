# Prompt: investigate one failed device workflow deeply

Use this only after an actual V2 device execution failed and the exact V2 build,
steps, logs and crash data are supplied. Do not use this template for a Legacy
failure unless the user has explicitly selected a Legacy investigation; Legacy
evidence otherwise remains in `docs/v2/archive/legacy/` and cannot block V2.

```text
Continue Server-Host V2 by investigating exactly one failed device workflow.

User report:
[PASTE THE COMPLETE FAILURE REPORT HERE]

Work in /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host.

First read every mandatory docs/v2 document and inspect the exact source/package
delta for the reported build. Apply the failure-intake protocol in WORKFLOW.md:
record the result, downgrade affected claims, update current status, and remain
on this workflow. Do not add or improve unrelated functionality.

Treat the user's runtime observation as evidence even if it contradicts the
previous static conclusion. Do not assume causality from timing alone.

Investigation requirements:

1. Reconstruct exact expected and observed state transitions.
2. Identify the last known working/control package and the smallest suspect
   source delta.
3. Read the relevant Sishen implementation seriously and identify its applicable
   organization/call/type/lifetime pattern. Do not copy its old ABI.
4. Validate current class layouts and UFunctions against FreshSDK/runtime
   reflection.
5. For native behavior, ask the user to open the exact required IDA database and
   use MCP deeply: decompile the target, follow xrefs/callers/callees, recover
   prototypes and vtable slots, inspect state changes and failure paths, and
   compare Android symbols/UE source when useful.
6. Separate hook-target correctness from hook-policy correctness. A correct hook
   can still return a value that breaks unrelated callers.
7. Produce competing hypotheses and state the evidence that supports or rejects
   each. Do not patch until one intervention is justified.
8. Prefer one-variable A/B packages if live behavior is required to distinguish
   hypotheses.
9. Implement the smallest evidence-backed correction behind an appropriate
   feature/diagnostic gate. Preserve a rollback/control artifact.
10. Build and give one exact test protocol with expected logs and pass/fail
    conditions.

Update HISTORY.md if this failure changes an important design conclusion;
otherwise keep the detailed entry in TEST_MATRIX.md. Update EVIDENCE.md,
STATUS.md, relevant per-function evidence, and architecture/migration documents
if their contract changed.

Do not finish with "likely fixed" merely because the code compiles. Finish in
one honest state: evidence disproved the implementation, ready for a bounded
device test, device verified from supplied results, or blocked on one specific
missing artifact/action.
```
