# Server-Host V2 status

Last updated: 2026-08-18.

## Current state

```text
active workflow: Gate 2A — exact image identity and checked-memory boundary
Gate 1.5: functional-device-pass; extended-soak-pending
Gate 2A: statically validated; single artifact ready for device test
Gate 2B: not started
Gate 2C: not started
capabilities: scans_started=0 hooks=0 engine_calls=0 mutation=0
Legacy: archived evidence only; not built, linked, or modified
```

The user explicitly authorized progression from Gate 1.5 to Gate 2. Gate 2 is
now split into 2A/2B/2C, and only 2A is active. No FNamePool, GUObjectArray,
reflection, Engine, World or NetDriver discovery exists in this workflow.

## Immutable Gate 1.5 result

Result ID: `V2-G1.5-SIDELOAD-PASS-002`

```text
Build ID: gate1.5-diagnostic-ui-20260818.2
Source revision: 8fb09e654466b07b534a3dd16b2618e789d84777
Input dylib SHA-256: 4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32
```

The user device-verified the icon action, visible Metal/ImGui frame, Status,
Logs, Copy logs, Close and reopen. Runtime logs confirmed button dispatch,
hierarchy attachment, first-frame entry, drawable/render-pass acquisition,
ImGui submission/presentation, stopped Metal rendering on Close, reopen and log
copy. UIKit fallback did not appear. Capabilities remained `hooks=0`,
`engine_calls=0`, `mutation=0`.

This result does not claim the earlier seven-minute or ten-minute soak protocol.
The user did not separately report a longer menu/map soak or an independent
touch pass-through check outside the open panel. Those read-only checks are now
part of the Gate 2A device protocol. The two supplied temporary screenshot paths
had already disappeared when preservation was attempted.

The prior immutable `.1` result remains `V2-G1.5-SIDELOAD-FAIL-001`: its icon
appeared, but no visible panel opened. The later `.2` PASS does not rewrite that
failure.

Full report: [Gate 1.5 PASS 002](evidence/GATE1_5_SIDELOAD_PASS_002.md).

## Gate 2A exact offline target

```text
ShooterGame path: /Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/com.studiowildcard.arkuse-1.10280-Decrypted/Payload/ShooterGame.app/ShooterGame
IDA database: /Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64
product / executable: ShooterGame
bundle: com.studiowildcard.arkuse
version: 1.10280 (bundle build 1.10288)
architecture / role: arm64 / MH_EXECUTE
LC_UUID: E52A980C-9C36-34C7-84B0-DD6E846328DC
whole-file SHA-256: d98d25778e893413ebd6c4da9156e1b74efe2b203bc488393795c3db6c83a178
stable pre-__LINKEDIT prefix: 94224384 bytes
__TEXT,__text: file offset 0x4000, size 0x448B030 / 71872560 bytes
__TEXT,__text SHA-256: 8bfc1fd248a5bf2fc589b85de0afccb57fe872789dff1b0e8c0d7b3db591bcf8
```

IDA MCP was connected to the required database. Its stored input SHA-256 and
its hash of the full `__text` bytes match the offline target. The fingerprint
does not include load commands, `__LINKEDIT`, the code signature, ASLR values or
mutable data, so ordinary dylib insertion/re-signing does not change its input.

Original segment card:

| Segment | VM size | File size | Initial permission |
|---|---:|---:|---|
| `__PAGEZERO` | `0x100000000` | `0` | none |
| `__TEXT` | `0x4D9C000` | `0x4D9C000` | read/execute |
| `__DATA_CONST` | `0xAA0000` | `0xAA0000` | read/write |
| `__DATA` | `0x580000` | `0x1A0000` | read/write |
| `__LINKEDIT` | `0x3DC000` | `0x3D8020` | read |

The selector requires the exact segment set, permissions and all stable
non-`__LINKEDIT` sizes. `__LINKEDIT` sizes and whole-file size are recorded but
excluded from equality because re-signing can rewrite the signature payload.

## Gate 2A implementation state

All low-level operations are isolated to `SourceV2/Bindings/Platform`:

- `LoadedImageCatalog`;
- `MachOImageView` and `MappedSegment`;
- `ImageIdentityResolver`;
- `ExactProfileSelector`;
- `CheckedMemoryReader` and its injected memory source.

Selection requires exact basename/product, dyld main-executable status,
`MH_EXECUTE`, architecture, UUID, stable segment card, stable pre-linkedit span,
full `__text` fingerprint and exactly one matching image/profile pair. Mismatch,
ambiguity and malformed input fail closed before later discovery.

`CheckedMemoryReader` is the only Gate 2B-facing read mechanism. It requires the
selector's private unique-match proof, rejects `address + size` overflow,
outside/cross-segment reads and wrong permission class, and returns owned typed
results. Gate 2A runtime does not instantiate it and starts no scan.

Status/Logs receive only an immutable redacted receipt: selected image/product,
architecture, UUID, decimal segment sizes, shortened fingerprint, match state,
reason and exact zero counters. ASLR slide, pointers and absolute addresses are
never published.

Detailed evidence: [Gate 2A exact identity](evidence/GATE2A_EXACT_IMAGE_IDENTITY.md).

## Gate 2A immutable build receipt

Result ID: `V2-G2A-BUILD-006`

```text
Build ID: gate2a-exact-identity-20260818.1
Source revision: 17e4e09ce8029bb89b22560da771ddc170e2ad0d
Source tag: v2-gate2a-exact-identity-20260818.1-source
Raw dylib SHA-256: 65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72
Mach-O / dSYM UUID: 0704076C-EAB6-3F25-800D-C0F0B85431E8
Manifest SHA-256: 77329da6d35f49c332c63a39e733d6fc970eaf474f89600b7edd37909ad1c5ca
Archive .deb SHA-256: 19d75c2e4ec8df0bc3e00d33e7337f3f7e981ddfc8308ebd8981007eb0784209
```

The clean build passed 191 host assertions, the boundary audit, iOS arm64
compile, package inspection and injection Legacy/gameplay isolation audit. An
independent UBSan-only build also passed 191 assertions. This is ready-for-
device-test evidence only; no runtime exact-match PASS is claimed.

## Deferred production UI debt

The working Gate 1.5 panel remains the control. A separate future UI workflow
must inspect and compatibly transfer the real ProjDragon `ARKFont`, appropriate
self-contained `DRGui` blocks and useful Sishen style/layout patterns only after
ImGui API, font ownership and license/provenance review. Login, UDID, API,
crypto/security, remote downloads, hide-record, gameplay code and old offsets
are explicitly excluded. See [UI design debt](UI_DESIGN_DEBT.md).

## Exact next action

Execute `PLAN-G2A-SIDELOAD-001` with the one manifested raw dylib. Do not use
the archival `.deb` for this device test and do not start Gate 2B in this task.
