# Prompt: create or refresh the living project description and rules

Use this when starting the documentation foundation in a new workspace, or when
the project's requirements have changed enough that the living documents need a
careful consistency pass.

```text
Create or comprehensively refresh the living Server-Host V2 project
documentation under:
/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/docs/v2

Do not change runtime code in this task.

Read the current Server-Host source, root STATUS.md, Reference materials,
preserved packages, Sishen, Dragon/ProjDragon and Extra_For_Host materials.
Preserve factual history: do not rewrite earlier failures or hypotheses as if
the final conclusion had always been known.

Sishen must be represented as the primary code-pattern reference for V2. The
documents must require future Codex tasks to read the corresponding Sishen
implementation before designing UE types, lookups, ProcessEvent wrappers,
memory access or hooks. Also state clearly that current FreshSDK and exact
binary analysis remain the source of truth for ABI and addresses.

Create or update these living files:

- README.md: entry point and mandatory reading order;
- HISTORY.md: user complaints, successful tests, regressions, requirements and
  changes of direction;
- PROJECT.md: current iOS goal, technical strategy, scope and long-term wishes;
- RULES.md: binding, type, IDA, Sishen, hook, thread, lifetime, testing and
  documentation rules;
- WORKFLOW.md: one-workflow research/implementation/test cycle and failure intake;
- ROADMAP.md: detailed near-term iOS gates and only a short deferred Android/VPS
  direction;
- STATUS.md: current active workflow, verified state and next action;
- EVIDENCE.md: claims with status, source and limitations;
- TEST_MATRIX.md: immutable pass/failure rows and a user failure-report template.

Important behavior when the user reports a failed test:
- record the exact report and build;
- immediately downgrade affected claims/status;
- preserve the earlier conclusion in history;
- identify one failing workflow;
- continue working deeply on that workflow instead of adding another feature;
- update the documents again after the cause and next package are known.

The documents must distinguish:
- compiled;
- statically validated;
- ready for device test;
- device verified;
- contradicted or unverified.

Cross-check all links and paths. Keep documents readable at the start of every
future Codex task. Put future deep per-function IDA reports in linked evidence
files rather than growing the summary registry without bound.

Finish with a consistency audit: list any conflicting requirements, missing
artifact paths, unproven claims and the exact next project workflow. Do not
invent missing facts.
```

