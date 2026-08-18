# Server-Host V2 status

Last updated: 2026-08-18.

## Current state

```text
active workflow: Gate 2C clean artifact ready; device capture pending
Gate 1.5: functional-device-pass; extended-soak-pending
Gate 2A exact identity: device verified
Gate 2A death exit: external baseline reproduced; deferred
Gate 2B .1: exact identity/UI device verified; contract capture aborted fail-closed
Gate 2B .2 menu capture: device verified
Gate 2B .2 TheIsland capture: fail-closed VM-region abort
Gate 2B .3: device verified in main menu and TheIsland
Gate 2B: complete for scoped read-only name/object/reflection snapshots
Gate 2C: exact cards/read-only capture statically verified and packaged; device pending
capabilities before explicit capture: scans_started=0 hooks=0 engine_calls=0 mutation=0
capabilities after explicit capture request: scans_started=1 hooks=0 engine_calls=0 mutation=0
Legacy: archived evidence only; not built, linked, or modified
```

The user explicitly authorized progression from Gate 1.5 to Gate 2. Gate 2 is
split into 2A/2B/2C. Gate 2A exact identity is complete and its death-path
investigation is closed as an external reproduced baseline limitation. Gate 2B
read-only name/object/reflection capture now completes in both the main menu and
TheIsland on `.3`, including generation replacement and changed object counts.
Gate 2B is complete for its named scope. Gate 2C now has exact-binary cards,
typed fresh-snapshot relationship capture, independent world generation and
host-static coverage. Its live values remain unverified until the named clean
artifact is executed under the Gate 2C device protocol.

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
touch pass-through check outside the open panel. They are not retroactively
treated as passed. Gate 2A subsequently produced the separate death-triggered
extended-stability contradiction recorded below. The two supplied temporary
screenshot paths had already disappeared when preservation was attempted.

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
selector's private unique-match proof, rejects overflow, outside/cross-segment
reads and wrong permission class, and returns owned typed results. The historical
Gate 2A `.1` runtime did not instantiate it or start a scan; Gate 2B now creates
it after exact match but performs no name/object read until the explicit button.

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
independent UBSan-only build also passed 191 assertions. This immutable build
receipt made no runtime claim; the later device identity result is recorded
separately below.

Local archive-integrity notice: an initial Gate 2B packaging invocation used
stale Gate 2A control metadata and unintentionally regenerated the ignored
Gate 2A `.deb` path. Its original receipt SHA above remains the historical
immutable value, but the current local archive container SHA is
`46264cbf9471acb4eef9c28a35c25ac74972b91f50ae1dd8761bad514a4194db`.
The package was restored to the original Gate 2A control and exact raw dylib
payload and passes content inspection, but it is not byte-identical to the old
archive. The canonical Gate 2A raw dylib and manifest remain unchanged at their
recorded SHAs; do not use the current `.deb` as a byte copy of the old receipt.

## Gate 2A device results

Identity result: `V2-G2A-IDENTITY-PASS-001`.

```text
identity_state=exact-match
UUID=E52A980C-9C36-34C7-84B0-DD6E846328DC
text_fingerprint=8bfc1fd248a5...
segments=exact profile match
scans_started=0 hooks=0 engine_calls=0 mutation=0
```

The positive exact-target identity sub-contract is device-verified for the
exact `.1` artifact. Status/Logs, open/close/reopen, Copy logs and panel
interaction were confirmed. The wrong-profile negative was not reported and is
not inferred.

The initial extended-stability result was `V2-G2A-DEATH-SIGNAL-EXIT-001`. On Apple Silicon Mac
in a local saved world without EOS, the character died and ShooterGame exited
during the death/respawn transition while the Gate 2A panel was open. The last
reported V2 open was `uptime_ms=120678`; no later close exists. The preserved
Console capture SHA-256 is
`0578303bea504af55cf6762d147debe6443e6f915bc9d3a56738608b360c7a8f`.
Line 7579 contains `GASignalHandler entered`; a subsequent crash-event request
received HTTP 200, which is an upload result rather than a cause. Signal number,
stack, faulting thread and a new 2026-08-18 ShooterGame `.ips` are absent.

Source audit shows that Gate 2A acquires no Pawn, HUD, World or UObject pointer,
does not create a discovery `CheckedMemoryReader`, and performs its Mach-O/text
identity work once inside `V2Entry` before publishing owned diagnostic values.
After startup the UI consumes only immutable snapshots and bounded logs.
Therefore a dangling UE pointer inside V2 is incompatible with this code path;
base death/respawn behavior, an open-overlay interaction and other latent
startup/UI defects were initially unclassified candidates.

The user then executed arm A with no injected dylib, the same local save and a
character death. ShooterGame exited in the same way; EOS login did not change
the result. Immutable result `V2-G2A-DEATH-BASELINE-002` is therefore
`classification: external baseline reproduced`. Gate 2A is not a necessary
cause of the observed symptom. Plausible base-game causes include save damage,
the stock death/respawn path, or running the iOS application on Apple Silicon
Mac; this project does not investigate which one. This does not assert that V2
can never affect that path, only that the current symptom is not a V2-specific
regression. Arms B/C were waived by explicit user decision. Death/respawn is
excluded from the current V2 stability acceptance criteria as a reproduced
baseline limitation, and Gate 2B is unblocked.

Full report: [Gate 2A device identity and death exit](evidence/GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md).

## Gate 2B implementation state

Workflow: `Gate 2B — read-only FNamePool, GUObjectArray and reflection snapshot`.

Exact resolver cards established in the required open `110280.i64` database:

```text
FNamePool inline root             RVA 0x5BB5180
FUObjectArray enclosing           RVA 0x5D434D8
TUObjectArray direct / ObjObjects RVA 0x5D434E8 (= enclosing + 0x10)
GWorld evidence only              RVA 0x5DBA4F0 (not read before Gate 2C)
ProcessEvent evidence only        RVA 0x250147C (not resolved or invoked)
```

The two FreshSDK address sets normalize to these RVAs after subtracting their
respective dump-time image bases; production stores no FreshSDK absolute value.
FNamePool `C8/CC/D0`, two-byte entry encoding, FUObjectItem `0/8/C/10` and
`0x18`, chunk size `0x10000`, flags masks, TUObjectArray header, UObject `0x28`
and FunctionFlags `0xB0` are exact-binary/source card facts. Function parameter
offsets remain unavailable.

Gate 2B extends the platform boundary with profile-bound opaque image/derived
tokens. Every derived token originates in an earlier owned copy; every heap copy
rechecks overflow, token scope, readable VM region and copy completion. FName and
object roots are sampled before/after bounded copies and retried at most three
times. All decoding/relationship work uses owned buffers and discovery-generation
identities. Raw pointer values, tokens, ASLR data and RVAs do not enter the
immutable Diagnostics/UI report.

Capture is explicit, never per-frame, and runs on one controlled serial queue.
Before the action `scans_started=0`; after a request it is `1`. Repeated capture
increments discovery generation and invalidates the prior owned snapshot.
Hooks, native/UE calls and mutation remain zero. The Contracts page exposes only
bounded root/name/object/reflection receipts and Copy report; it is not a hosting
control and does not redesign the Gate 1.5 panel.

Host/static validation covers normalization, wrong profile/RVA, derived scope,
VM failure, mutation/retry, name and object bounds, flags/serial/index, stale
generation, malformed/unknown/cyclic relationships, cancellation and limits,
plus diagnostics redaction/immutability. Normal and UBSan-only suites each pass
270 assertions for `.1`; the combined ASan/UBSan binary compiled but stalled before its
first marker and is not claimed as passing. The boundary audit and iOS arm64
compile pass. No live name/object capture is claimed until the device protocol
succeeds.

Detailed evidence: [Gate 2B read-only contracts](evidence/GATE2B_READ_ONLY_CONTRACTS.md).

## Gate 2B device capture abort

Result ID: `V2-G2B-CAPTURE-ABORT-001`.

The exact `.1` image/profile receipt, panel open/close/reopen, stopped Metal on
Close and Copy logs were device-confirmed. Three explicit captures at
generations 1, 2 and 3 deterministically aborted in 47/39/38 ms with
`invalid TUObjectArray num/max/chunk relationship`. Every attempt retained
`scans_started=1 hooks=0 engine_calls=0 mutation=0`; no name/object/reflection
PASS is claimed.

Audit found that `.1` incorrectly applied the allocated-chunk work limit to the
reserved `MaxChunks` field and imposed an arbitrary 4,000,000 `MaxElements`
capacity ceiling. Exact IDA and FreshSDK still support the root and field
offsets. The replacement bounds live `NumElements`, allocated `NumChunks`, bytes
and time, while checking reserved max fields through overflow-safe semantic
relationships. Future aborts include the four integer counters but no address.
The correction passed 280 normal and 280 UBSan-only assertions, the boundary
audit and an iOS arm64 compile and was packaged as `.2` below.

Full intake: [Gate 2B device capture abort 001](evidence/GATE2B_DEVICE_CAPTURE_ABORT_001.md).

## Gate 2B immutable build receipt

Result ID: `V2-G2B-BUILD-007`

```text
Build ID: gate2b-readonly-contracts-20260818.1
Source revision: ff9637b34b308117208555482c5a8a872c8b94c9
Source tag: v2-gate2b-readonly-contracts-20260818.1-source
Raw dylib SHA-256: e7f6c3c932c2af759547d69b46359b2e1004c51dbd5f2f5a7c9fbd25729afb79
Mach-O / dSYM UUID: 0D2DBE64-7258-34CC-B9F0-A3DFFB80516D
dSYM DWARF SHA-256: 0735a7aa34b7fa6205bd055f6171df111f31cf5820d1ecb12ef9ccb689342acd
Manifest SHA-256: 956d912aeb15aee671661ca96a5abee0eb0a166229d13bb2138b81b7bba88d78
Archive .deb SHA-256: bff134a2ec73fac33b8cff6fa9cd3e7dc9f426efb2e6ce21241423a816cb7232
```

Canonical Sideloadly input:
`packages/v2/injection/gate2b-readonly-contracts-20260818.1/ServerHostV2.dylib`.
The sibling dSYM and manifest are the matching handoff; the `.deb` is archival
only. The clean source tag resolves to the manifest revision. Package and raw
dylib contents, embedded build/source identity, arm64 Mach-O, matching UUID,
Legacy/gameplay isolation and the boundary audit passed. This is a build/static
receipt only; live FName/object/reflection capture remains device-unverified.

## Gate 2B capacity correction build receipt

Result ID: `V2-G2B-CAPACITY-FIX-BUILD-008`

```text
Build ID: gate2b-readonly-contracts-20260818.2
Source revision: 739f274c5b01c29703bbc9b34b40ad6a167c24af
Source tag: v2-gate2b-readonly-contracts-20260818.2-source
Raw dylib SHA-256: 56e9ebb0d4453b90e4d63ccfa5431a142d8d94bc42b043b0e45b24e819203a6c
Mach-O / dSYM UUID: F02EC54E-DEB7-35AA-B91C-C868547BCD03
dSYM DWARF SHA-256: 3360fabf343e1f5db2acdf2d35aff476cd80f1156116aadaea14784c0bed2771
Manifest SHA-256: 88c29c99dafb6522caedcef27c4538dcb1df43bd06385dc82519658ae3ea17cc
Archive .deb SHA-256: ceffbde6f34f3323459a3e2754cf18ce09e6d353336564caee01e401a44bad83
```

Canonical replacement Sideloadly input:
`packages/v2/injection/gate2b-readonly-contracts-20260818.2/ServerHostV2.dylib`.
The clean tag resolves to the embedded/manifest revision. Normal and UBSan-only
suites each pass 280 assertions; boundary, iOS package and injection audits
pass. This replaces `.1` only for the pending Gate 2B device protocol and does
not turn `V2-G2B-CAPTURE-ABORT-001` into a PASS.

## Gate 2B `.2` device menu PASS / world abort

`V2-G2B-MENU-CAPTURE-PASS-003` completed generation 1 in the main menu in 49
ms, copying 24,675,046 bytes. It owned 178 FName blocks with 390,585 entries and
61,171 object items (`max=25231360`, `num_chunks=1`, `max_chunks=385`). All ten
known names, all nine exact core objects/functions, UObject `0x28` metadata and
UFunction flags at `0xB0` passed. This device-verifies ABI-005/006 and the
bounded ABI-007 subset for a menu snapshot. Capabilities remained zero.

`V2-G2B-WORLD-VM-REGION-ABORT-002` is the immutable generation-2 TheIsland
result. The previous generation was invalidated, but capture aborted after 37
ms because a requested owned copy did not fit in one readable VM region. The
zero partial counters in the abort view are discarded candidate state, not an
empty runtime. No crash occurred and zero capabilities remained.

The `.3` correction composes one token-bounded owned result from consecutive
readable VM regions while keeping each individual `vm_read_overwrite` inside
one queried region. Gaps, unreadable ranges, overflow and unmap/copy failure
still fail closed. Derived errors now add only a redacted expected-type label.
Normal and UBSan-only suites pass 290 assertions; boundary audit passes. Device
verification of this correction subsequently passed on `.3` as recorded below.

Full report: [Gate 2B menu PASS / world abort](evidence/GATE2B_DEVICE_MENU_PASS_WORLD_ABORT_002.md).

## Gate 2B multi-region correction build receipt

Result ID: `V2-G2B-MULTIREGION-BUILD-009`

```text
Build ID: gate2b-readonly-contracts-20260818.3
Source revision: 852e260d353c9a67a18e5763f358f1242b6e7947
Source tag: v2-gate2b-readonly-contracts-20260818.3-source
Raw dylib SHA-256: b5e5f0edf47ebb5b71c0c08d947bd6d186538ea2a9f9bc9722c4076ee0e07829
Mach-O / dSYM UUID: 48EB7BC3-7222-3F27-8A09-4224B980EF8C
dSYM DWARF SHA-256: 3832a561277f1bb5812af7662a2e07383fe75a2015f8400acaf214a4a9a8bedd
Manifest SHA-256: 29eaa59a1fbe428213c8f75b1b0a6453ab062467ae929f364915857b45cff89e
Archive .deb SHA-256: e1147e8fee5f7fa64bf1fe90d4e109448da1949e202117287f3deee363b7c8f8
```

Canonical Sideloadly input:
`packages/v2/injection/gate2b-readonly-contracts-20260818.3/ServerHostV2.dylib`.
The source tag resolves to the manifest revision. Normal and UBSan-only suites
each pass 290 assertions; boundary, iOS package and injection audits pass. The
`.deb` remains archival and is not a device-test input.

## Gate 2B `.3` device PASS

Result ID: `V2-G2B-MULTIREGION-DEVICE-PASS-004`

Generation 1 completed in the main menu in 32 ms with 178 FName blocks/390,585
entries and 61,177 object items in one live chunk. Generation 2 completed in
TheIsland in 44 ms with 180 blocks/399,365 entries and 107,275 object items in
two live chunks. It reported `Previous invalidated=yes`; all ten FNames, all
nine exact objects/functions, UObject `0x28` metadata and UFunction flags
passed in both snapshots.

The multi-region correction is therefore device verified. Both explicit
captures retained `scans_started=1 hooks=0 engine_calls=0 mutation=0`; no retry,
abort or crash was reported. The optional third capture after returning to menu
was not reported and is not inferred. The class named `Engine.World` remains
reflection metadata only—no live GWorld/UWorld, Engine, GameViewport or
NetDriver instance discovery occurred.

Full report: [Gate 2B device PASS 004](evidence/GATE2B_DEVICE_PASS_004.md).

## Gate 2C clean build receipt

Result ID: `V2-G2C-BUILD-010`

```text
Build ID: gate2c-live-relationships-20260818.1
Source revision: 695b230d9db8438142c48aa4b9eb6479e3e1fe35
Source tag: v2-gate2c-live-relationships-20260818.1-source
Raw dylib SHA-256: 9a0aee70e9012dd57a1fa543b035f5037d7e0ed26c800e8e029ef4c438ffefb4
Mach-O / dSYM UUID: 53A00208-554E-334F-815E-59A9694AFD15
dSYM DWARF SHA-256: cf55bb237a7cb8bdbc9eceb29a21d5f33f76cdc6150605d1376f13ba66cd2aed
Manifest SHA-256: 342e58f8315ccc03e535235b0ee7a3bcff98b27116d49d0239c6fa033cc641d9
Archive .deb SHA-256: 65984a8265a0e15dd73f80dfd34613d1360f41cc8fe17fc3959b0dc3038a45a2
```

Canonical Sideloadly input:
`packages/v2/injection/gate2c-live-relationships-20260818.1/ServerHostV2.dylib`.
Normal and UBSan-only runs each pass 383 assertions; boundary, arm64 iOS,
package, injection-isolation and dSYM audits pass. The artifact has not been
installed or executed, so live Engine/Viewport/World/NetDriver values and world
transitions remain device-unverified.

## Deferred production UI debt

The working Gate 1.5 panel remains the control. A separate future UI workflow
must inspect and compatibly transfer the real ProjDragon `ARKFont`, appropriate
self-contained `DRGui` blocks and useful Sishen style/layout patterns only after
ImGui API, font ownership and license/provenance review. Login, UDID, API,
crypto/security, remote downloads, hide-record, gameplay code and old offsets
are explicitly excluded. See [UI design debt](UI_DESIGN_DEBT.md).

## Exact next action

Execute only the clean Gate 2C V2 raw artifact under the bounded
menu/TheIsland/same-world/optional-return capture protocol in
[`GATE2C_LIVE_RELATIONSHIPS.md`](evidence/GATE2C_LIVE_RELATIONSHIPS.md).
Do not start Gate 3, hooks, UE calls, hosting or mutation in this workflow.
