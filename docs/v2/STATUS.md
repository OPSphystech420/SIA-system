# Server-Host V2 status

Last updated: 2026-08-18.

## Current state

```text
active workflow: V2 Gate 1 infrastructure hardening and Gate 2 preparation
workflow state: implementation complete; final V2 build/static/package verification pending
next workflow: Gate 2 read-only live contract discovery
device state: unchanged; no package installed or executed
Legacy state: archived evidence only; it cannot block V2 without an explicit Legacy investigation request
```

The separate V2 target contains the typed Gate 1 foundation and an inert iOS
entry. The existing 56 host-local foundation assertions remain useful static
tests, not live validation. Five additional host-local assertions cover exact
Legacy dylib-name isolation. No live UE discovery, hook, `ProcessEvent`, native
engine call, host/client flow or mutation is implemented.

## Infrastructure outcome

- Host object/dependency output and iOS Theos state are routed to ignored
  `.artifacts/v2` paths; `.build`, source-local `.theos` and `.DS_Store` are not
  source inputs.
- Host compilation emits and consumes `-MMD -MP` header dependency files.
- The package declares `Conflicts: com.mhga.serverhost`, and V2 startup refuses
  to continue when the exact Legacy basename `ServerHost.dylib` is already
  loaded or loaded-image enumeration fails.
- The curated 1.10280 layout assertion translation unit is compiled by both the
  host test target and the iOS arm64 target.
- `BoundaryAudit.sh` reports what it checks: regex raw-access boundaries,
  include-layer direction, Legacy include/source-list isolation and a bounded
  low-level inventory.
- Package production requires a clean Git revision, performs content
  inspection, and emits a read-only SHA-addressed manifest containing build ID,
  revision, flags, package SHA-256 and dylib SHA-256.

Final package path and hashes are recorded here only after the clean revision
build completes.

## Exact next Gate 2 workflow

Gate 2 begins in a separate task and only after this infrastructure verification
is complete:

1. Add a read-only `Bindings/Platform` image/segment reader that captures the
   loaded ShooterGame Mach-O UUID, mapped image/segment sizes and a bounded text
   fingerprint.
2. Match exactly one fail-closed 1.10280 profile; an incomplete, ambiguous or
   mismatched identity produces only a refusal report.
3. Resolve FNamePool and GUObjectArray through reviewed read-only resolver cards,
   explicitly settle the current direct-root versus `+0x10` conflict, and never
   scan or write from feature code.
4. Read a bounded set of known names/objects/reflection descriptors and discover
   Engine/World relationships as scoped identities tied to a world generation.
5. Emit a redacted `ContractReport`/snapshot, validate generation invalidation
   across natural map enter/leave, then build one uniquely identified diagnostic
   package and hand off its device protocol.

Gate 2 exclusions are absolute for that workflow: no hooks, `ProcessEvent`,
native engine calls, hosting, NetMode policy, client travel, save,
administration, gameplay mutation or Legacy runtime changes.
