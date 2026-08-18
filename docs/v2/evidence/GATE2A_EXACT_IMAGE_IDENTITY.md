# Gate 2A exact image identity and checked-memory boundary

Report ID: `V2-G2A-IDENTITY-001`  
Workflow / ABI backlog IDs: Gate 2A / ABI-001  
Date: 2026-08-18  
Claim before: iOS 1.10280 image identity was intentionally incomplete  
Claim after: exact offline profile and fail-closed boundary implemented;
device identity remains unverified

## Sources read

Sishen organizational references:

- `Sishen-main/Utilities/Memory.h`
- `Sishen-main/Source/Offsets.h`
- `Sishen-main/Source/SigsAndOffsets.txt`
- `Sishen-main/Source/Main.h`
- `Sishen-main/Source/Main.mm`

Exact target sources:

- `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/com.studiowildcard.arkuse-1.10280-Decrypted/Payload/ShooterGame.app/ShooterGame`
- `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64`

IDA MCP confirmed that the open database is exactly `110280.i64`, ARM 64-bit
little-endian, with stored input SHA-256 equal to the offline binary hash below.
IDA's bytes for the complete `__text` section produced the same fingerprint as
the offline file range.

## Exact offline ShooterGame identity

```text
product / CFBundleExecutable: ShooterGame
bundle identifier: com.studiowildcard.arkuse
CFBundleShortVersionString: 1.10280
CFBundleVersion: 1.10288
file type: MH_EXECUTE
architecture: arm64 / CPU subtype ALL
Mach-O commands: 97, 11152 bytes
file size: 98254880 bytes
whole-file SHA-256: d98d25778e893413ebd6c4da9156e1b74efe2b203bc488393795c3db6c83a178
LC_UUID: E52A980C-9C36-34C7-84B0-DD6E846328DC
stable pre-__LINKEDIT prefix: 94224384 bytes
__TEXT,__text file offset: 0x4000
__TEXT,__text size: 0x448B030 / 71872560 bytes
__TEXT,__text SHA-256: 8bfc1fd248a5bf2fc589b85de0afccb57fe872789dff1b0e8c0d7b3db591bcf8
```

Original load-command segment card:

| Segment | VM size | File size | Initial permission |
|---|---:|---:|---|
| `__PAGEZERO` | `0x100000000` | `0` | none |
| `__TEXT` | `0x4D9C000` | `0x4D9C000` | read/execute |
| `__DATA_CONST` | `0xAA0000` | `0xAA0000` | read/write |
| `__DATA` | `0x580000` | `0x1A0000` | read/write |
| `__LINKEDIT` | `0x3DC000` | `0x3D8020` | read |

The exact segment set, permissions and every non-`__LINKEDIT` size are matching
inputs. `__LINKEDIT` presence/permission are required, but its sizes and the
whole-file size are not equality inputs because code signing rewrites that
payload. The stable prefix ends at its original file offset.

## Fingerprint range decision

The fingerprint covers every byte of `__TEXT,__text` and nothing else. It is
computed from mapped bytes after applying ASLR only to locate the range; ASLR
addresses are not hash input. The section excludes the Mach-O header/load
commands and `__LINKEDIT` code signature, both of which can change during dylib
insertion or Sideloadly re-signing. It also excludes mutable data/fixups. The
offline file and IDA database independently returned the same SHA-256.

## Sishen pattern disposition

Accepted as organization only:

- one recognizable image/memory boundary;
- central startup phases before higher-level work;
- keeping offsets/signatures away from feature presentation.

Adapted:

- dyld enumeration becomes a copied `LoadedImageCatalog` and exact basename,
  dyld-main plus `MH_EXECUTE` selection;
- image-relative access becomes parsed segment/section metadata with checked
  overflow and permissions;
- memory reads return typed `ContractResult` values and owned byte copies.

Rejected:

- substring-only `ShooterGame` selection and the function-static singleton base
  cache;
- broad numeric address heuristics;
- unchecked globals, copied offsets/signatures and raw base-plus-offset calls;
- write/call/hook helpers, delayed hook initialization, detached scanning loops,
  anti-cheat/hide-record behavior and gameplay features.

No Sishen offset, signature, ABI or runtime global entered SourceV2.

## Implemented fail-closed contracts

All raw address, ASLR, Mach-O parsing and process-memory operations live under
`SourceV2/Bindings/Platform`:

- `LoadedImageCatalog` copies dyld header/load-command envelopes;
- `MachOImageView` rejects malformed/truncated commands, duplicates, overflows,
  missing UUID, section escape and segment overlap;
- `ImageIdentityResolver` derives the UUID/segment receipt and hashes only the
  bounded readable/executable `__text` section;
- `ExactProfileSelector` requires one exact product/main-role/architecture/UUID/
  segment/fingerprint/profile pair and rejects zero or multiple matches;
- `CheckedMemoryReader` can be created only from the selector's private unique-
  match proof. It checks `address + size`, one-segment containment, no boundary
  crossing, readable-vs-executable class and returns owned typed results.

The runtime Gate 2A path intentionally does not instantiate the reader and does
not begin any name/object scan. Every match, mismatch, ambiguity or inspection
failure keeps:

```text
scans_started=0
hooks=0
engine_calls=0
mutation=0
```

The UI receives only a redacted immutable diagnostic snapshot containing the
image/product, architecture, UUID, decimal segment sizes, shortened fingerprint,
profile state and reason. It receives no slide, pointer, RVA or absolute address.

## Verification and limits

Host tests use synthetic byte buffers plus an injected memory source; they never
read arbitrary addresses from the test process. Coverage includes malformed and
truncated commands, missing/wrong UUID, wrong architecture, absent/duplicate/
overlapping segments, ambiguous images, overflow, outside/cross-segment reads,
permission-class refusal, fingerprint mismatch, one exact match, unsupported
fail-close, diagnostic redaction and immutable snapshots. The boundary audit
rejects raw/Mach-O operations outside `Bindings/Platform` (tests excluded) and
keeps UI free of Bindings/UE/runtime work.

The normal C++20 host run passed 191/191 assertions. An independent UBSan-only
build also passed 191/191 assertions, and the boundary audit passed. The local
combined ASan/UBSan runtime initialized its libc interceptors but did not enter
the test `main`; it was terminated without a sanitizer diagnostic, so no ASan
PASS is claimed.

## Immutable artifact receipt

```text
Result ID: V2-G2A-BUILD-006
Build ID: gate2a-exact-identity-20260818.1
Source revision: 17e4e09ce8029bb89b22560da771ddc170e2ad0d
Source tag: v2-gate2a-exact-identity-20260818.1-source
Raw dylib SHA-256: 65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72
Mach-O / dSYM UUID: 0704076C-EAB6-3F25-800D-C0F0B85431E8
dSYM DWARF SHA-256: a5f14164e93815538c7fb7962ce36eaa94f669c066c6247fbb8f603d04a4c9b2
Manifest SHA-256: 77329da6d35f49c332c63a39e733d6fc970eaf474f89600b7edd37909ad1c5ca
Archive .deb SHA-256: 19d75c2e4ec8df0bc3e00d33e7337f3f7e981ddfc8308ebd8981007eb0784209
```

Artifact paths:

- `packages/v2/injection/gate2a-exact-identity-20260818.1/ServerHostV2.dylib`
- `packages/v2/injection/gate2a-exact-identity-20260818.1/ServerHostV2.dylib.dSYM`
- `packages/v2/injection/gate2a-exact-identity-20260818.1/manifest.txt`
- `packages/v2/com.mhga.serverhost.v2_0.2.0~gate2a.20260818.1_iphoneos-arm.deb`

The read-only manifest is `serverhost-v2-injection-manifest-v3` and records the
exact target UUID/fingerprint range plus zero runtime capabilities. Package and
raw injection audits passed. This is a static/build receipt, not a Gate 2A
device PASS.

Gate 2B (FNamePool/GUObjectArray/reflection) and Gate 2C
(Engine/GameViewport/World/NetDriver/generation) had not started at this build
receipt.

## Subsequent device result

The same artifact later passed the positive exact-target identity sub-contract
as `V2-G2A-IDENTITY-PASS-001`. Its extended stability was separately
contradicted by death-triggered signal exit
`V2-G2A-DEATH-SIGNAL-EXIT-001`. The subsequent no-injection control reproduced
the same symptom as `V2-G2A-DEATH-BASELINE-002`, so it is an external baseline
limitation and Gate 2B is unblocked.

See [Gate 2A device identity and death exit](GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md).
