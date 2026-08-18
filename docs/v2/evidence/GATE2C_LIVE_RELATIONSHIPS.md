# Gate 2C — live Engine, GameViewport, World and NetDriver relationships

Status: exact-binary/sdk/source cards and implementation complete; `.1` and
`.2` are immutable fail-closed Engine-identity aborts; exact `.3` has passed one
TheIsland relationship capture. Same-world generation stability and lifecycle
transition/invalidation remain pending, so Gate 2C is still open.

Scope: one explicit bounded read-only capture. Every Gate 2C request first
creates a fresh Gate 2B owned name/object/reflection snapshot, then resolves all
relationships inside that snapshot. Hooks, engine calls and mutation are zero.

## Exact target and source disposition

- IDA MCP database: `/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64`
- input: `/Users/grimreaper31/Desktop/110280`
- image base: `0x100000000`
- input MD5 reported by IDA: `1c94a1e25e1748e8a008726d6ec20baa`
- V2 exact profile: `ios-shootergame-1.10280-exact-e52a980c`
- FreshSDK: both current `Reference/FreshSDK` trees, including Engine,
  ShooterGame, OnlineSubsystemUtils, object/property dumps and `UEOffsets.hpp`
- closest engine source: local UE4.17 `Engine`, `World` and `UWorldProxy` code
- existing exact research: `Reference/NetDriverDefinitions-1.10280.md`

Sishen's `StaticClasses`, `GameStructs`, `ScriptCore` and `Main` files were
reviewed. V2 adopts the understandable typed Engine → GameViewport → World →
NetDriver boundary. It rejects Sishen's raw globals, forever-cached pointers,
foreign offsets/hooks and short-name-only lookup. No Sishen ABI value enters the
profile.

## Exact contract cards

All image globals are resolved as RVAs against the already-proven exact image.
All heap relationships are derived only from an owned parent copy, copied
through the checked readable-memory source, matched uniquely to the fresh
object array, and re-read for stability. No raw value is formatted or published.

### GEngine native ownership — RVA `0x5DB8CF0`

- Storage shape: one inline `UEngine*` slot in image data, not a pointer to a
  pointer. Owner is the process/engine loop global, not a UObject member.
- Exact writer/ownership: `sub_100F844A4` contains the `Create GEngine`,
  `GEngine->Init` and `GEngine->Start` sequence; `0x100F846B8` stores the newly
  constructed object into `qword_105DB8CF0` before the virtual Init/Start calls.
- Representative reader: `sub_100F8510C`, `0x100F85DAC–0x100F85DBC`, loads the
  global, then reads `Engine+0x780`.
- Nullability: expected before creation/after teardown; a user-triggered Gate
  2C capture in the running game requires a non-null live Engine and fails
  closed otherwise.
- Identity/class/full name: exactly one fresh, non-pending, non-unreachable,
  non-CDO identity; the direct class is dynamically resolved in that snapshot
  and must be exact `Class ShooterGame.ShooterEngine`; its super chain includes
  `GameEngine` and `Engine`; the live object full name matches
  `ShooterEngine Transient.ShooterEngine_<digits>`.
- Failure/revalidation: null, ambiguous, stale, unmapped, wrong class/name/CDO
  or unstable root aborts Gate 2C. Revalidate on every explicit capture and
  every discovery generation; the native root is the independent cross-check.

### `UEngine::GameViewport` — offset `0x780`

- Storage shape: nullable inline `UGameViewportClient*` member of exact owner
  `UEngine`/derived live ShooterEngine.
- Exact reader: `sub_100F8510C`, `0x100F85DBC` and `0x100F85DE0`.
- Writer/lifecycle: Engine construction/load owns assignment; no speculative
  direct writer is promoted into the V2 card. The first and stability samples
  must agree. A null value is a permitted menu/loading lifecycle observation.
- Validation: a non-null value must map to one fresh object identity and pass
  the `GameViewportClient` class relationship/full-name/FName validators.
- Failure/revalidation: wrong/unknown/duplicate/stale identity or class aborts;
  null reports a normal absent relationship. Revalidate on every capture and
  world transition.

### `UEngine::NetDriverDefinitions` — offset `0xBF8`

- Storage shape: inline 16-byte `TArray` header: Data pointer at `+0`, Num at
  `+8`, Max at `+C`. Elements live behind Data; the Engine owns the array.
- Exact reader: inferred `UEngine::CreateNetDriver` path `sub_103D869C0` reads
  count from `Engine+0xC00` at `0x103D869C0`, Data from `Engine+0xBF8` at
  `0x103D869E0`, computes `24*Num`, compares DefName and advances by 24 bytes.
  The same body loads the primary class and, if unavailable, the fallback.
- Relevant writer: exact `UEngine::Init` invokes UObject config loading on its
  live `this`; the prior exact research found no later direct clear/write in
  that function. Gate 2C performs no config or array write.
- Nullability/layout: `{Data=null, Num=0, Max=0}` is canonical valid empty.
  Null Data with non-zero Num/Max, negative/inverted bounds, non-null Data with
  zero Max, excessive bounds or overflow are malformed and fail closed.
- Validation: header is re-read; populated arrays are bounded to 64 entries and
  capacity 256; every FName resolves from the owned pool; duplicate
  `GameNetDriver` fails. Exact observed primary/fallback names are reported but
  never changed.
- Revalidation: every capture and immediately before a future Host command.

### `FNetDriverDefinition` — size `0x18`

- Storage shape: inline value of three `FName` values: DefName `+0`,
  DriverClassName `+8`, DriverClassNameFallback `+0x10`.
- Owner: one element of `UEngine::NetDriverDefinitions`.
- Exact evidence: `sub_103D869C0` 24-byte stride/primary/fallback consumer;
  both FreshSDK Engine layouts and `NetDriverDefinitions-1.10280.md` agree.
- Failure/revalidation: invalid FName, truncated entry, duplicate GameNetDriver
  or header instability aborts; revalidate with the Engine array each capture.

### GWorld — RVA `0x5DBA4F0`

- Storage shape: one inline nullable `UWorld*` image-data slot, not a
  pointer-to-pointer. Owner is UE world lifecycle global storage.
- Representative readers: `sub_100F88FF0` (`0x100F89068–70`),
  `sub_1032D3B3C`, and `sub_1018865E4` (`0x101886628–38`, followed by the
  GameState read).
- Representative writers: `sub_10388C0FC` replaces the slot at
  `0x10388C2E8`/`0x10388C754`; `sub_103DFD50C` clears it at `0x103DFD65C`;
  `sub_103E0AA28` clears/assigns at `0x103E0B60C`/`0x103E0B828`;
  `sub_103E1B71C` clears it at `0x103E1D004`.
- Nullability: normal during menu/loading/teardown; null alone is not
  corruption. A non-null value must be one fresh validated `World` identity.
- Cross-check/failure: independently compare against GameViewport->World. If
  both are non-null they must resolve to the same identity; inequality is the
  dedicated `GWorld/ViewportWorld mismatch` failure. Revalidate each capture.

### `UGameViewportClient::World` — offset `0x70`

- Storage shape: nullable inline `UWorld*` member of exact owner
  `UGameViewportClient`.
- Exact reader: `sub_1038C04E0` returns `*(this+112)` at `0x1038C04E4`. Its
  function pointer is present in two exact vtables (`0x104FE9988` and
  `0x105494E20`); FreshSDK and Sishen independently identify this typed owner
  relationship.
- Writer/lifecycle: viewport/world-context loading owns assignment; no writer
  or offset from a reference project is guessed. The member is stability
  re-read and may be null during menu/loading/teardown.
- Validation/failure: non-null must be present in the same fresh snapshot and
  pass World class/name/full-name validation; mismatch with non-null GWorld
  fails separately. Revalidate each capture/world change.

### `UWorld` relationships — `0x1D8`, `0x2B8`, `0x2C0`

- Storage shape: three nullable inline UObject pointers owned by exact `UWorld`:
  NetDriver `+0x1D8`, AuthorityGameMode `+0x2B8`, GameState `+0x2C0`.
- Exact readers/writers: `sub_103E0AA28` reads NetDriver at `0x103E0AAB0` and
  again near `0x103E0AE60`; it reads and writes AuthorityGameMode in the same
  lifecycle body, including the store at `0x103E0B414`. `sub_101D5216C` reads
  AuthorityGameMode at `0x101D52258`. `sub_1018865E4` and `sub_10188691C` read
  GameState at `0x101886638`/`0x10188695C`. Exact Listen/cleanup ownership is
  preserved in the separate host backlog and is not called by Gate 2C.
- Nullability: all three are optional by lifecycle. Null NetDriver reports
  `net_driver=none`; presence does not prove Listen or hosting.
- Validation: each non-null value must be a unique live identity in the same
  snapshot and pass `NetDriver`, `GameModeBase` or `GameStateBase` class-chain
  validation. No GetNetMode or virtual method is invoked. UNetDriver world
  ownership is not enforced until its separate exact member card is required.
- Failure/revalidation: absent-from-snapshot or wrong-class relationships abort;
  null is normal. The World relationship extent is stability re-read. Revalidate
  on every capture and world generation.

## Typed views and generation contract

`EngineView`, `GameViewportView`, `WorldView`, `NetDriverView`,
`NetDriverDefinitionsView`, `WorldRelationshipSnapshot` and
`WorldGenerationTracker` expose only value identities and bounded strings. UI
and feature code cannot access roots, heap values, ASLR metadata or layout
offsets.

Discovery generation changes for every fresh Gate 2B snapshot. World generation
is separate: the first directly observed live world establishes generation 1;
subsequent null→world, world→null, index/serial change or validated fingerprint
replacement increments it. A repeated capture of the same index/serial/full-
name/class keeps the generation. The tracker retains no heap value. On a change,
old World/Viewport/NetDriver/GameMode/GameState handles fail discovery/world-
generation validation and the immutable report says
`previous_world_invalidated=yes`.

## Static acceptance

Normal and independent UBSan-only host runs for corrected `.3` each pass 393
assertions. Tests cover unique/ambiguous Engine, CDO and wrong class/full name;
relocated exact ShooterEngine direct UClass and wrong-package direct UClass;
exact `/Engine/Transient` owner canonicalization and unnumbered Engine refusal;
canonical empty and malformed arrays; valid/duplicate/invalid-name definitions;
nullable/wrong Viewport; null/mismatched/absent/wrong World; optional and wrong-
class relationships; stable, null-transition and replacement generations; stale
handles and discovery replacement; cancellation/bounds/unsupported profile;
redaction/report bounds and exact zero capabilities. Boundary audit rejects
Gate 2C Listen, travel, driver lifecycle calls, ProcessEvent, GetNetMode calls,
hooks and mutation paths.

## Historical `.1` artifact receipt

Result ID: `V2-G2C-BUILD-010`

```text
build_id=gate2c-live-relationships-20260818.1
source_revision=695b230d9db8438142c48aa4b9eb6479e3e1fe35
source_tag=v2-gate2c-live-relationships-20260818.1-source
dylib_sha256=9a0aee70e9012dd57a1fa543b035f5037d7e0ed26c800e8e029ef4c438ffefb4
dsym_uuid=53A00208-554E-334F-815E-59A9694AFD15
dsym_dwarf_sha256=cf55bb237a7cb8bdbc9eceb29a21d5f33f76cdc6150605d1376f13ba66cd2aed
manifest_sha256=342e58f8315ccc03e535235b0ee7a3bcff98b27116d49d0239c6fa033cc641d9
archival_deb_sha256=65984a8265a0e15dd73f80dfd34613d1360f41cc8fe17fc3959b0dc3038a45a2
raw_dylib=packages/v2/injection/gate2c-live-relationships-20260818.1/ServerHostV2.dylib
manifest=packages/v2/injection/gate2c-live-relationships-20260818.1/manifest.txt
archival_deb=packages/v2/com.mhga.serverhost.v2_0.4.0~gate2c.20260818.1_iphoneos-arm.deb
```

The clean tagged `.1` build reran 383 host assertions and the boundary audit, then
compiled/linked arm64 UIKit/Metal/ImGui, inspected package metadata/payload,
verified Legacy/gameplay-symbol isolation, copied the package dylib
byte-identically, and matched the Mach-O/dSYM UUID. The v4 manifest records all
Gate 2C RVAs/offsets, separate-generation contract and
`DEC-V2-NO-HOOK-FIRST-HOST`. No package was installed or executed.

Packaging incident: the first packaging attempt encountered stale Gate 2B
control metadata and was rejected by the expected-path check, but Theos had
already replaced the ignored archival Gate 2B `.3` container path. Its
canonical raw dylib, dSYM and manifest were not changed and retain hashes
`b5e5f0e…e07829`, `3832a56…8bedd` and `29eaa59…ff89e`. The archive path was
restored from that exact raw dylib and original metadata and passes V2 package
inspection; its current container SHA is `e3054a9e…891fe`, not the immutable
historical `.deb` SHA `e1147e8f…c8f8`. The historical receipt is not rewritten.

## Immutable `.1` device result and correction

Result ID: `V2-G2C-ENGINE-VALIDATOR-ABORT-001`

The exact `.1` artifact ran in a local TheIsland world. Its fresh Gate 2B
snapshot completed in 37 ms with 180 FName blocks/399,494 entries, 110,906
objects in two chunks and every required name/object/reflection validator
passing. Gate 2C then aborted before accepting a relationship byte with:

```text
native Engine identity failed exact ShooterEngine class/full-name validators
```

The combined `.1` message does not identify its failing predicate. Source audit
found that `.1` required the direct ShooterEngine UClass object-array index to
equal FreshSDK dump index `0x359`. That index is snapshot identity, not ABI.
Corrected `.2` removes it from the profile, resolves the direct class within the
fresh owned snapshot, requires exact `Class ShooterGame.ShooterEngine`, and
keeps the independent `GameEngine`/`Engine` chain checks. Diagnostics now
separate runtime class, live full name, CDO and direct-class failures. The exact
native roots and every relationship offset remain unchanged.

Full immutable intake: [Gate 2C device Engine-validator abort 001](GATE2C_DEVICE_ENGINE_VALIDATOR_ABORT_001.md).

## Corrected `.2` artifact receipt

Result ID: `V2-G2C-ENGINE-VALIDATOR-FIX-BUILD-011`

```text
build_id=gate2c-live-relationships-20260818.2
source_revision=4a53ab940e8085c2e13c00489b4ab6ab9e95764c
source_tag=v2-gate2c-live-relationships-20260818.2-source
dylib_sha256=ee6f6d9014fa98171a105fa009750e4d078a099a8ecf4a969dce98c704b60cae
dsym_uuid=E70F89CA-A7DE-3AEA-8CA1-D23AEF07AD8F
dsym_dwarf_sha256=2f7c171b866cd9ee1a36ee7c3798766cb67bb3d3ee8828b6305c9bf21e6db041
manifest_sha256=832ace6c517a56f319847131e1297b46ede67100adad8bb38ba1febd59fe10e7
archival_deb_sha256=7bc9607751fb630c38ee18aa56be3c187320765f1e95cfa92aee1ca51aaa61fe
raw_dylib=packages/v2/injection/gate2c-live-relationships-20260818.2/ServerHostV2.dylib
manifest=packages/v2/injection/gate2c-live-relationships-20260818.2/manifest.txt
archival_deb=packages/v2/com.mhga.serverhost.v2_0.4.1~gate2c.20260818.2_iphoneos-arm.deb
```

The clean tagged source passed 387 normal and 387 UBSan-only assertions, the
boundary audit, arm64 iOS compile, package/control/payload/build/source identity
inspection and injection isolation. The package/raw dylib bytes match and the
Mach-O/dSYM UUID is identical. Manifest v4 names the fresh-snapshot exact direct
UClass contract and records zero hooks/engine calls/mutation. No package was
installed or executed.

That execution has now occurred and is immutable result
`V2-G2C-ENGINE-FULLNAME-ABORT-002`. In TheIsland, `.2` completed a fresh
46 ms Gate 2B snapshot with 107,279 objects/two chunks and all prerequisite
validators passing, then accepted zero relationship bytes and rejected the
strict Engine instance full name. The preceding runtime-class predicate passed;
the later CDO/direct-UClass/ancestry predicates and every relationship field
were not reached by `.2` ordering. See
[Gate 2C `.2` Engine full-name abort](GATE2C_DEVICE_ENGINE_FULLNAME_ABORT_002.md).

## `.3` bounded full-name correction

FreshSDK's exact dump records `Package Transient` and the numbered full name
`ShooterEngine Transient.ShooterEngine_2147482613`; its generated
`FName::ToString` selects the text after the last `/`. Closest UE source creates
the same owner using package-path spelling `/Engine/Transient`. `.3`
canonicalizes only that exact alias to `Transient`; it does not accept a broad
package suffix or short-name match. The required published shape remains
`ShooterEngine Transient.ShooterEngine_<digits>`.

The check now follows non-CDO, exact direct
`Class ShooterGame.ShooterEngine`, and GameEngine/Engine ancestry. If the
instance full-name still differs, the failure includes at most 160 printable
bytes each of observed full name/object name with controls, quotes and
backslashes replaced by `?`; it includes no raw address, RVA, slide or pointer.
The `/Engine/Transient` positive and unnumbered Engine negative pass both 393-
assertion normal and UBSan-only suites plus all boundary, arm64, package and
injection-isolation audits.

## Corrected `.3` artifact receipt

Result ID: `V2-G2C-ENGINE-FULLNAME-FIX-BUILD-012`

```text
build_id=gate2c-live-relationships-20260818.3
source_revision=f4598395efeadcd882af5f257b1e6d72a78de6d3
source_tag=v2-gate2c-live-relationships-20260818.3-source
dylib_sha256=4b7ddd7cf68cd089c69ca632415ec0a56594e49f60be0dccabc438dd471e2ae3
dsym_uuid=78EAF0B0-9C08-39BE-B37B-25E4A8EC7629
dsym_dwarf_sha256=04724342f3e9d343b1c562703e3ce791581244135e295201ec0840c2bb5d8707
manifest_sha256=a821b4a88a8228b1f3b81d4c00da063b7103aa2ca35854ec24f95d369bc6749b
archival_deb_sha256=18d4dd6dab7d02325d4e2ce3f513cf1cbe0403d7263424669b2a5bcae674e8f6
raw_dylib=packages/v2/injection/gate2c-live-relationships-20260818.3/ServerHostV2.dylib
manifest=packages/v2/injection/gate2c-live-relationships-20260818.3/manifest.txt
archival_deb=packages/v2/com.mhga.serverhost.v2_0.4.2~gate2c.20260818.3_iphoneos-arm.deb
```

The source tag resolves to the revision embedded in both dylib and manifest.
The package/raw dylib bytes match, the dSYM UUID matches, and no package was
installed or executed as part of this build receipt. Device execution is the
separate result below.

## `.3` first TheIsland relationship result

Result ID: `V2-G2C-MAP-RELATIONSHIPS-PASS-003`

The exact `.3` input was captured once in an already loaded ordinary TheIsland
world. Fresh discovery generation 1 completed in 45 ms with 180/399,305 FName
blocks/entries, 106,725 valid objects in two chunks and 26,045,310 owned bytes;
all required FName, object/function and reflection validators passed. The
relationship phase completed in 2 ms/10,240 bytes.

The native Engine root resolved to one fresh live identity. Exact non-CDO
ShooterEngine direct UClass plus GameEngine/Engine ancestry passed. GameViewport
and the live World passed, and independent GWorld/ViewportWorld reads resolved
to the same generation-bound identity. Lifecycle was `map`; world generation 1
was established; and NetDriver correctly reported the normal pre-host state
`none`. The populated definitions array had one GameNetDriver:

```text
primary=OnlineSubsystemEOS.NetDriverEOS
fallback=OnlineSubsystemUtils.IpNetDriver
```

The report did not expose AuthorityGameMode/GameState presence, so no presence
claim is made. Because this was the first accepted relationship capture, no
prior world could be invalidated. Hooks, engine calls and mutation stayed zero.
See [Gate 2C `.3` map PASS 003](GATE2C_DEVICE_MAP_PASS_003.md).

## Remaining corrected `.3` device protocol

1. While the exact current process and TheIsland world remain active, Capture
   again. Discovery generation should become 2 while world generation remains
   1 and `previous_world_invalidated=no`.
2. If naturally possible, return to menu without restarting and capture once
   more. Record the lifecycle and world transition; do not invent a null World
   if the game retains/replaces one.
3. After any accepted menu capture, enter ordinary TheIsland and capture again
   to prove the menu-to-map direction. If natural return is unavailable, use a
   later menu-first run. Repeat once in the same world when needed.
4. Verify Engine/Viewport identities, definitions, GWorld/ViewportWorld state
   and optional relationships in every accepted report. A null driver remains
   `net_driver=none` and is not hosting proof.
5. Do not use death/respawn as PASS/FAIL.
6. In every state confirm exactly:

```text
hooks=0
engine_calls=0
mutation=0
```

Use only build `gate2c-live-relationships-20260818.3`; `.1` and `.2` cannot
satisfy this protocol. Gate closure still requires no raw address output, no
relationship abort/mismatch, bounded duration, correct same-world generation
stability and applicable transition invalidation. Gate 3 and hosting remain
closed.

## Preserved limitations

- Gate 2B return-to-menu capture was not reported.
- No longer Gate 2B or Gate 2C soak is claimed.
- `Class Engine.World` is class metadata, not a live UWorld.
- Parameter ABI and native dispatch remain unavailable.
- The first Gate 2C TheIsland relationship values are device-proven, but menu
  lifecycle, same-world stability and transition invalidation are not.
