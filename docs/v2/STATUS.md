# Server-Host V2 status

Last updated: 2026-08-18.

## Current state

```text
active workflow: V2 Gate 1 infrastructure hardening and Gate 2 preparation
workflow state: complete; clean host/static/iOS package verification passed
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

Verified build identity: `gate1-foundation-20260818.3`, source revision
`23da20fe1bbc472bf2476ec6d33a7cd658d7c0d3`.

- Package:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/com.mhga.serverhost.v2_0.1.1~gate1.20260818.3_iphoneos-arm.deb`
- Package SHA-256:
  `e9d8d187705370270b310a7ee7a05f37909aee12736e261de8b37a204049af29`
- Packaged dylib SHA-256:
  `9f06fffb905bbd8a8b97959f2fe32faa49d89528d6668502a0ebb24781b5834a`
- Read-only manifest:
  `/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/com.mhga.serverhost.v2_0.1.1~gate1.20260818.3_iphoneos-arm.deb.e9d8d187705370270b310a7ee7a05f37909aee12736e261de8b37a204049af29.manifest`
- Manifest SHA-256:
  `91bafa567caf311a597e88f3dd1a24f9e0ef6857cd76a58550fa69c4f75eae78`

The package was inspected but not installed or executed. These results are
build/static evidence only, not live validation.

## Exact next Gate 2 workflow

Gate 2 begins in a separate task:

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
