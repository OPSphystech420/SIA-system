# Gate 2B read-only FNamePool, GUObjectArray and reflection snapshot

```text
Report ID: V2-G2B-READONLY-CONTRACTS-001
Workflow / ABI backlog IDs: Gate 2B; ABI-005, ABI-006, ABI-007; ABI-008 evidence-only
Date: 2026-08-18
Author/task: Codex Gate 2B workflow
Exact platform and build identity: ShooterGame 1.10280 arm64 MH_EXECUTE
Binary/database: /Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64
IDA stored input SHA-256: d98d25778e893413ebd6c4da9156e1b74efe2b203bc488393795c3db6c83a178
Target LC_UUID: E52A980C-9C36-34C7-84B0-DD6E846328DC
Claim status before: Gate 2B active; FName/object/reflection ABI unresolved for runtime use
Claim status after: exact-binary resolver cards and static/iOS build validation complete; device capture pending
```

## Scope and non-scope

Gate 2B creates one explicit read-only capture. It resolves exact-build roots,
copies names/object items/minimal UObject metadata into owned storage and emits a
bounded immutable report. It does not discover a live Engine, World, viewport or
NetDriver instance. It does not call ProcessEvent or any UE/native method, install
a hook, schedule gameplay work, poll every frame or write memory. Gate 2C and
hosting have not started.

The reproduced death/respawn exit is closed separately as
`V2-G2A-DEATH-BASELINE-002`: the identical symptom occurs without injection.
It is excluded from this gate's acceptance criteria as an external baseline
limitation; no save/EOS/death workaround was added.

## Sources read

Sishen was read completely for organization and rejected as current ABI truth:

- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Source/UnrealEngine/NameTypes.hpp`;
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Source/UnrealEngine/ObjectArray.hpp`;
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Source/UnrealEngine/ScriptCore.h`;
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Source/UnrealEngine/ScriptCore.mm`;
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Source/StaticClasses.h`;
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Source/GameStructs.h`;
- `/Users/grimreaper31/Desktop/Dev/MHGA/Sishen/Sishen-main/Utilities/Memory.h`.

Both current FreshSDK trees were compared:

- `Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame`;
- `Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame-Full-Version`.

The review included each `UEOffsets.hpp`, `CppSDK/UnrealContainers.hpp`, relevant
`CppSDK/SDK/CoreUObject_*` files, both object dumps and the Dumpspace offsets,
classes and functions JSON files. The two SDK trees agree on the used layouts
and dumps; their exported absolute addresses differ by constant dump-time ASLR.

## Adopted, adapted and rejected patterns

Adopted as organization:

- typed FName/pool representation;
- chunked object-array organization;
- small name/object/full-name helpers;
- separate class and function lookup;
- one centralized resolver/capture owner.

Adapted:

- Sishen's direct reads became profile-gated opaque tokens and owned
  `vm_read_overwrite` copies;
- global name/object access became bounded snapshots with double-sampled mutable
  headers and discovery-generation invalidation;
- object/full-name helpers operate only on copied metadata with cycle/depth
  checks.

Rejected:

- every Sishen offset/signature and unchecked global/singleton pointer;
- direct dereference, borrowed live UObject return, infinite scan and permanent
  class cache;
- unverified serial/flags ABI, hooks, FunctionFlags mutation and ProcessEvent;
- gameplay, login, security, download and legacy offset paths.

## FreshSDK address normalization

The regular dump base is `0x100A9C000`; the full dump base is `0x1044D8000`.
Corresponding exported addresses differ by `0x3A3C000`, proving session ASLR
rather than a different ABI.

| Contract | Regular absolute | Full absolute | Stable RVA | Gate 2B use |
|---|---:|---:|---:|---|
| FNamePool | `0x106651180` | `0x10A08D180` | `0x5BB5180` | used |
| direct TUObjectArray | `0x1067DF4E8` | `0x10A21B4E8` | `0x5D434E8` | used |
| GWorld | `0x1068564F0` | `0x10A2924F0` | `0x5DBA4F0` | recorded only; Gate 2C |
| ProcessEvent | `0x102F9D47C` | `0x1069D947C` | `0x250147C` | recorded only; never invoked |

Production stores only stable RVAs. No dump-time absolute address, ASLR slide,
runtime pointer or heap address is published.

## ABI-005 resolver card — FNamePool

Result: the root at IDA address `0x105BB5180` / RVA `0x5BB5180` is an inline
pool, not a pointer to a pool.

Validated layout:

```text
CurrentBlock      +0xC8
CurrentByteCursor +0xCC
Blocks            +0xD0
maximum blocks    0x2000
block bytes       0x20000
entry stride      2
header bit 0      wide
header bits 6..15 length
```

Representative exact-binary evidence:

- `sub_10234E684` initializes the inline root and first block;
- `sub_10235072C` and `sub_102351754` compute
  `Blocks[HIWORD(index)] + 2 * LOWORD(index)` and branch on the wide bit;
- `sub_102351CDC` reads CurrentBlock;
- `sub_102355E14` uses `+C8/+CC/+D0`, the `0x20000` block capacity, two-byte
  alignment and narrow/wide allocation paths.

Runtime validator: read `C8/CC` and the used part of `Blocks[]`, copy every used
block, resample header/table, discard and retry at most three times if changed,
then decode only owned buffers. Bounds are 512 captured blocks, 96 MiB copied,
1023 encoded units and 2048 output bytes. Known round trips are `None`, `Object`,
`Class`, `Function`, `World`, `Engine`, `GameEngine`, `GameViewportClient`,
`NetDriver` and `GameNetDriver`.

## ABI-006 resolver card — GUObjectArray

The two candidates describe one object:

```text
FUObjectArray enclosing RVA 0x5D434D8
ObjObjects/TUObjectArray    +0x10
direct TUObjectArray RVA    0x5D434E8
```

Gate 2B resolves both roots and requires the enclosing `+0x10` bytes to equal
the direct header before any heap derivation.

Validated current layout:

```text
FUObjectItem: Object +0x0; Flags +0x8; ClusterIndex +0xC;
              SerialNumber +0x10; size 0x18
unreachable mask 0x10000000; pending-kill mask 0x20000000
chunk items 0x10000
TUObjectArray: Objects +0x0; MaxElements +0x10; NumElements +0x14;
               MaxChunks +0x18; NumChunks +0x1C; size 0x20
```

Representative exact-binary evidence:

- `sub_100F8CBB8` addresses the enclosing object and its direct fields;
- `sub_10158C9BC` performs chunk/index math with 65536 items and 24-byte items;
- `sub_100FAC328` and `sub_100FBDA28` use UObject index `+C`, item flags `+8`
  and the pending mask;
- weak-pointer validation at `0x102530648`, `0x1025306E8`, `0x10253075C`,
  `0x1025307DC` and `0x1025308CC` validates chunk lookup and serial `+0x10`;
- `sub_10251C484`/`sub_10251C5F4` use cluster `+C` and unreachable state.

Runtime validator: sample header, validate num/max/chunks/capacities, copy the
chunk-pointer table and required item bytes, then resample header/table. Null,
pending, unreachable, malformed serial and index counts are owned report values;
no object address survives the low capture layer.

## ABI-007 resolver card — UObject/reflection

FreshSDK and exact-binary data flow support the used current layout:

```text
UObject size 0x28
ObjectFlags +0x8; InternalIndex +0xC; ClassPrivate +0x10;
NamePrivate +0x18; OuterPrivate +0x20
UField Next +0x28
UStruct SuperStruct +0x40; Children +0x48; ChildProperties +0x50;
        PropertiesSize +0x58; MinAlignment +0x5C; size 0xB0
UFunction FunctionFlags +0xB0; size 0xE0
```

Only UObject identity, class/outer, bounded class super chains and FunctionFlags
are read in Gate 2B. `NumParms`, `ParmsSize` and `ReturnValueOffset` are explicitly
unavailable. The exact ProcessEvent body at `0x10250147C` was inspected only as
data-flow evidence for UObject index and FunctionFlags; there is no binding or
call.

Static dump indices seed validation but never become live pointers:

```text
0x1    Class CoreUObject.Object
0x44   Class Engine.NetDriver
0x1A8  Class Engine.Engine
0x266  Class Engine.GameViewportClient
0x358  Class Engine.GameEngine
0x37F  Class CoreUObject.Class
0x380  Class CoreUObject.Function
0x712  Class Engine.World
0x410D Function Engine.KismetStringLibrary.Conv_StringToName
```

Every seed is re-read through a derived token, checks `InternalIndex`, resolves
FName/class/outer from the same object snapshot and reconstructs a bounded full
name. Unknown pointers, cycles, excessive depth or malformed names fail that
relationship. Class and function lookups return discovery-generation identities.

## Provenance and lifetime contract

`CheckedMemoryReader` can be created only from the selector's private unique
exact-match proof and retains the matched profile ID. An image RVA becomes an
opaque image token only when one mapped segment contains the complete range and
its permission class matches. A derived token can be created only by decoding a
pointer field from an earlier `OwnedMemoryCopy`; it records reader nonce, scope,
expected type and depth. Maximum depth is eight.

Every copy checks offset/size overflow and token scope. Process memory walks the
logical range through consecutive readable VM regions and calls
`vm_read_overwrite` separately for the part inside each queried region. A gap,
unreadable region, unmap, permission change or partial copy rejects the complete
owned result. Borrowed pointers are never returned. The low capture
implementation may temporarily compare copied pointer words to the copied
object-item inventory, but raw values/tokens do not enter Diagnostics, UI or
Features.

The capture runs only after the explicit Contracts action on one serial worker
queue. It supports cancellation and time/byte/object/name/depth/retry limits. A
new request increments `DiscoveryGeneration` and drops the prior owned snapshot;
old identities fail `WrongGeneration`. UI reads only the publisher's immutable,
redacted `DiagnosticSnapshot` and bounded `ReadOnlyContractReport`.

## Static verification

Synthetic tests use injected sparse byte regions, never random host addresses.
They cover exact profile/RVA normalization, wrong/overflow RVA and profile,
derived-token scope, unmap/read failure, FName header mutation/retry, cursor and
entry bounds, narrow/wide/output limits, object header/table mutation/retry,
invalid num/max/chunks, null chunks, flags/serial/index, serial zero/reuse,
stale generation, malformed names, unknown/cyclic outer and super chains,
cancellation and time/byte/object limits. Diagnostics tests cover redaction,
bounded reports and immutable prior snapshots. The boundary audit prevents UI
from including Bindings or using address/RVA vocabulary.

The normal host suite passed 270 assertions; an independent UBSan-only build
also passed 270 assertions. The combined ASan/UBSan binary compiled but its local
runtime stalled before the first test marker and was interrupted, so no combined
sanitizer PASS is claimed. The boundary audit and iOS arm64 compile pass. Exact
artifact receipts are recorded after the clean tagged build.

After the `.2` TheIsland region-edge intake, adjacent-readable composition plus
gap, unreadable, unmap/copy and redacted type-context coverage raised the normal
and UBSan-only suites to 290 assertions each. This later count does not rewrite
the historical `.1` receipt.

## Immutable build receipt

Result ID: `V2-G2B-BUILD-007`.

```text
build_id=gate2b-readonly-contracts-20260818.1
source_revision=ff9637b34b308117208555482c5a8a872c8b94c9
source_tag=v2-gate2b-readonly-contracts-20260818.1-source
dylib_sha256=e7f6c3c932c2af759547d69b46359b2e1004c51dbd5f2f5a7c9fbd25729afb79
macho_uuid=0D2DBE64-7258-34CC-B9F0-A3DFFB80516D
dsym_uuid=0D2DBE64-7258-34CC-B9F0-A3DFFB80516D
dsym_dwarf_sha256=0735a7aa34b7fa6205bd055f6171df111f31cf5820d1ecb12ef9ccb689342acd
manifest_sha256=956d912aeb15aee671661ca96a5abee0eb0a166229d13bb2138b81b7bba88d78
archive_deb_sha256=bff134a2ec73fac33b8cff6fa9cd3e7dc9f426efb2e6ce21241423a816cb7232
```

The canonical Sideloadly input is
`packages/v2/injection/gate2b-readonly-contracts-20260818.1/ServerHostV2.dylib`.
Its sibling dSYM UUID matches. The sibling immutable manifest records the exact
target UUID/text fingerprint, both object-array roots, FNamePool RVA, clean
source state and pre/post-capture capability states. The archival `.deb` passed
content inspection but is not a device-test mechanism. No device claim is made
by this receipt.

## Device protocol

1. Inject only
   `packages/v2/injection/gate2b-readonly-contracts-20260818.3/ServerHostV2.dylib`
   through Sideloadly.
2. In main menu verify the exact identity card and `scans_started=0`.
3. Open Contracts and press **Capture read-only contracts** once.
4. Wait for `capture=complete`; copy the bounded report/logs. If the capture
   aborts, stop this run and report the new reason/counters before entering a
   world.
5. Confirm all ten known FNames and nine core object/function checks pass.
6. Enter an ordinary TheIsland local world and capture again.
7. Confirm discovery generation changed, previous generation is invalidated,
   object count may change, and `hooks=0 engine_calls=0 mutation=0` remains.
8. Return to menu naturally if possible and perform a third capture.
9. Do not use death/respawn as PASS/FAIL; it is a reproduced baseline limitation.
10. Report timeout, retry, malformed relationship, crash or UI regression with
    copied bounded output and Console tail.

Gate 2B PASS requires exact profile roots, successful known-name/core-object
validators, generation change, bounded address-free diagnostics and unchanged
zero capabilities. Gate 2C does not begin in this workflow.

## Device execution `.1` — immutable abort

`V2-G2B-CAPTURE-ABORT-001` executed the exact clean `.1` artifact. Identity and
panel lifecycle passed, but generations 1, 2 and 3 all aborted on the generic
TUObjectArray relationship validator. No live name/object/reflection PASS is
claimed. The fail-closed counters remained scans=1 and zero hooks/calls/mutation.

Post-device audit retained the resolver card but corrected validator policy:
the `.1` 4,000,000 element capacity ceiling and `MaxChunks <= 128` requirement
were not ABI facts. Only live Num fields bound copying; Max fields now receive
overflow-safe capacity-envelope validation. Detailed intake:
[Gate 2B device capture abort 001](GATE2B_DEVICE_CAPTURE_ABORT_001.md).

The correction is packaged as `V2-G2B-CAPACITY-FIX-BUILD-008`: build `.2`,
source `739f274c5b01c29703bbc9b34b40ad6a167c24af`, dylib SHA
`56e9ebb0d4453b90e4d63ccfa5431a142d8d94bc42b043b0e45b24e819203a6c`
and UUID `F02EC54E-DEB7-35AA-B91C-C868547BCD03`.

## Device execution `.2` — menu PASS / world abort

`V2-G2B-MENU-CAPTURE-PASS-003` completed the exact generation-1 main-menu
snapshot: 178 FName blocks/390585 entries, 61171 live object items, all ten
known names, nine exact objects/functions and required reflection checks passed
in 49 ms. This is a scoped device PASS for ABI-005/006/007 and device-validates
the reserved-capacity correction.

`V2-G2B-WORLD-VM-REGION-ABORT-002` records the same process's TheIsland
generation 2. It invalidated the previous generation but aborted in 37 ms on
the one-readable-region policy, retained zero capabilities and did not crash.
No world snapshot or changed object count is inferred. The `.3` correction
splits only the low physical copies; provenance, logical token scope and owned
publication are unchanged. Detailed receipt:
[Gate 2B menu PASS / world abort](GATE2B_DEVICE_MENU_PASS_WORLD_ABORT_002.md).

The single replacement handoff is `V2-G2B-MULTIREGION-BUILD-009`: build `.3`,
source `852e260d353c9a67a18e5763f358f1242b6e7947`, raw dylib SHA
`b5e5f0edf47ebb5b71c0c08d947bd6d186538ea2a9f9bc9722c4076ee0e07829`
and UUID `48EB7BC3-7222-3F27-8A09-4224B980EF8C`. Device repeat is pending.
