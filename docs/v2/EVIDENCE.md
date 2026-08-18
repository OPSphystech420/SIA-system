# Server-Host V2 evidence registry

This bounded registry covers the active SourceV2 workflow. Legacy runtime
material remains under [`archive/legacy/`](archive/legacy/README.md) and is not
an active blocker.

## Current V2 claims

| ID | Claim | State | Evidence and limit |
|---|---|---|---|
| V2-EV-001 | V2 has an explicit source list/package ID and does not link Legacy runtime sources. | statically validated | `SourceV2.mk`, iOS V2 Makefile and boundary/package audits. Legacy build is not run. |
| V2-EV-002 | Gate 1 curated types/layouts, borrowed containers/strings, names, object identity and reflection descriptors have synthetic host coverage. | statically validated historical baseline | Gate 1 reports/tests; not live UE validation. |
| V2-EV-003 | The iOS 1.10280 profile contains the exact Mach-O identity card and the loaded target matched it. | device verified positive identity | `V2-G2A-IDENTITY-PASS-001`: exact UUID, segment card and shortened `__text` fingerprint matched the offline/IDA profile. Wrong-profile negative remains unexecuted. |
| V2-EV-004 | Legacy/V2 co-installation is rejected and V2 startup independently refuses exact loaded `ServerHost.dylib`. | statically validated | Debian `Conflicts` and LegacyRuntimeGuard tests; no co-install device claim. |
| V2-EV-005 | Curated layout assertions compile in host and iOS targets. | compiled | Gate 1/1.5 build receipts. |
| V2-EV-006 | V2 packaging is revision-bound and emits a read-only manifest, raw dylib and matching dSYM. | latest artifact device executed | Clean `.4` receipt `V2-G2C-OPTIONAL-RELATIONSHIP-RECEIPT-BUILD-013` is source `4db2599…43473`, dylib SHA `95c0fe6…a94677`, UUID `7CB1B073-D9A5-39E0-BDD3-2638B0618B28` and manifest SHA `0a7cd36…b99387`; it produced the first-map device PASS `V2-G2C-OPTIONAL-RELATIONSHIPS-MAP-PASS-004`. |
| V2-EV-007 | Gate 2 is split into 2A/2B/2C. | source + device confirmed scope | Gate 2A exact identity and Gate 2B read-only contracts are device verified. Gate 2C `.4` now device-publishes live AuthorityGameMode/GameState presence in its first TheIsland capture. Same-world generation stability and lifecycle transition evidence remain open. |
| V2-EV-008 | Diagnostics are bounded/redacted and publish immutable snapshots with exact zero capabilities. | statically validated + device receipt | Logger/snapshot tests plus `V2-G2A-IDENTITY-PASS-001`: scans/hooks/engine calls/mutation all zero. |
| V2-EV-009 | Corrected Gate 1.5 presentation opens, renders Metal/ImGui, navigates Status/Logs, copies logs, closes and reopens. | device verified functional; extended soak pending | `V2-G1.5-SIDELOAD-PASS-002`. UIKit fallback did not appear. No unreported long soak or independent outside-window touch PASS is inferred. |
| V2-EV-010 | Gate 1.5 device-tested artifact is exact `.2` input SHA `421211…58c32`, source `8fb09e6…477`. | device verified for bounded functions | Manifest/dSYM plus user runtime receipt. Sideloadly re-signs after input identity. |
| V2-EV-011 | Exact `.1` installed its icon but produced no visible panel. | contradicted opening claim | Immutable `V2-G1.5-SIDELOAD-FAIL-001`; preserved despite later `.2` PASS. |
| V2-EV-012 | Gate 2A selects by exact name, joint dyld-main/`MH_EXECUTE`, architecture, UUID, stable segments/fingerprint and unique candidate count. | device verified positive exact match | `V2-G2A-IDENTITY-PASS-001`; no claim for the unexecuted wrong-profile negative. |
| V2-EV-013 | `CheckedMemoryReader` is match-gated, segment-bounded, overflow-checked, permission-typed and returns owned results. | statically validated | Synthetic source tests cover overflow, outside/crossing and forbidden permission cases. Runtime does not instantiate it in Gate 2A. |
| V2-EV-014 | Raw address/ASLR/Mach-O/process-memory operations remain in `Bindings/Platform` and never enter UI/features. | boundary-audit validated | Strengthened `BoundaryAudit.sh`; tests are the only synthetic exception. |
| V2-EV-015 | Production UI compatibility transfer is a separate deferred workflow. | recorded debt | [UI design debt](UI_DESIGN_DEBT.md); current Gate 1.5 panel remains the control. |
| V2-EV-016 | One raw Gate 2A Sideloadly input was built from a clean tagged revision and executed on the exact target. | device verified identity only | `V2-G2A-BUILD-006` plus `V2-G2A-IDENTITY-PASS-001`; dylib SHA `65bb097…9ef72`. Extended stability did not pass. |
| V2-EV-017 | Gate 2A extended stability survived the local-world death path. | contradicted, then classified external | `V2-G2A-DEATH-SIGNAL-EXIT-001` recorded the injected exit; `V2-G2A-DEATH-BASELINE-002` reproduced the same symptom without any dylib. Death/respawn is a deferred baseline limitation, not a current V2 acceptance criterion. |
| V2-EV-018 | A dangling Pawn/HUD/World/UObject pointer inside V2 can explain the Gate 2A exit. | source-incompatible | Gate 2A acquires no such pointer, starts no discovery and has no production `CheckedMemoryReader::Create` caller. This excludes only the V2 UE-dangling hypothesis. |
| V2-EV-019 | Server-Host injection is necessary for the observed death exit. | contradicted | Arm A reproduced the identical death exit with no injected dylib; EOS login did not change it. This does not prove the exact base-game cause or that V2 can never influence the path. |
| V2-EV-020 | The causal control can proceed to B/C after the baseline reproduction. | closed by user decision | Arms B/C are no longer required. `PLAN-G2A-DEATH-CAUSAL-001` closed after A classified the symptom as external baseline reproduced. |
| V2-EV-021 | FreshSDK's two absolute address sets are ASLR variants of one ABI. | exact-binary/static validated | Subtracting regular base `0x100A9C000` or full base `0x1044D8000` yields the same FNamePool `0x5BB5180`, TUObjectArray `0x5D434E8`, GWorld `0x5DBA4F0` and ProcessEvent `0x250147C` RVAs. Production stores only RVAs; the last two are not consumed in Gate 2B. |
| V2-EV-022 | ABI-005/006/007 resolver cards are exact-build grounded. | exact-binary + device verified | `V2-G2B-MULTIREGION-DEVICE-PASS-004` validated all names, objects/functions, UObject `0x28` and FunctionFlags `0xB0` in both menu and TheIsland snapshots. |
| V2-EV-023 | Derived heap access is profile/provenance bounded and produces owned bytes. | device verified | `.3` copied 24,675,204 menu bytes and 26,049,956 TheIsland bytes. The two-chunk world snapshot completed through the multi-region boundary; static gap/unreadable/unmap refusals remain. |
| V2-EV-024 | Gate 2B captures internally consistent owned FName/object/reflection snapshots. | device verified | Generations 1 and 2 completed all validators; generation 2 invalidated generation 1 and observed changed FName/object/chunk counts in TheIsland. |
| V2-EV-025 | Gate 2B execution is explicit and preserves zero active capabilities. | device verified | Pre-capture scans=0; explicit requests set scans=1; hooks/engine calls/mutation stayed zero. UI copied bounded reports; no address appeared. |
| V2-EV-026 | One clean, source-tagged Gate 2B `.1` raw Sideloadly input and matching dSYM/manifest exist. | historical build receipt; device abort preserved | `V2-G2B-BUILD-007`: dylib SHA `e7f6c3c…afb79`, UUID `0D2DBE64-7258-34CC-B9F0-A3DFFB80516D`; subsequent `.1` execution is `V2-G2B-CAPTURE-ABORT-001`. |
| V2-EV-027 | Gate 2B `.1` completes a live owned name/object/reflection snapshot. | contradicted | `V2-G2B-CAPTURE-ABORT-001`: three generations aborted on the same TUObjectArray relationship validator before a completed report. Exact identity/UI lifecycle and zero capabilities passed. |
| V2-EV-028 | Reserved TUObjectArray capacity must fit the same limit as allocated chunks/current objects. | contradicted; correction device verified in menu | `.2` accepted live `61171/1` with reserve `25231360/385`, proving the Max fields are capacity rather than work. Operational limits remained on copied live ranges. |
| V2-EV-029 | The Gate 2B capacity-policy correction preserves bounded work and address-free failures. | menu device verified | Menu capture completed in 49 ms and 24,675,046 bytes with no address output and zero capabilities. The subsequent world abort is a separate VM-region composition limitation. |
| V2-EV-030 | One clean replacement `.2` Gate 2B raw input corresponds to the capacity-policy correction. | device executed | `V2-G2B-CAPACITY-FIX-BUILD-008`: dylib SHA `56e9ebb…03a6c`, UUID `F02EC54E-DEB7-35AA-B91C-C868547BCD03`; exact menu capture passed and world capture aborted fail-closed. |
| V2-EV-031 | Exact Gate 2B menu FName/object/reflection owned snapshot completes. | device verified | `V2-G2B-MENU-CAPTURE-PASS-003`: all required names, core object/function and bounded reflection validators passed at generation 1. Scope is main menu only. |
| V2-EV-032 | The same `.2` artifact completes a replacement snapshot in TheIsland. | contradicted | `V2-G2B-WORLD-VM-REGION-ABORT-002`: generation 2 invalidated generation 1 but aborted in 37 ms on the one-readable-region restriction. No crash; zero capabilities retained. |
| V2-EV-033 | A token-bounded logical owned copy can safely span adjacent readable VM regions. | device verified positive path + static negative paths | `.3` completed the prior failing two-chunk TheIsland capture; 290 normal/UBSan assertions retain gap, unreadable and unmap/copy fail-closed coverage. |
| V2-EV-034 | One clean `.3` raw input contains only the Gate 2B multi-region correction. | device executed | `V2-G2B-MULTIREGION-BUILD-009`: dylib SHA `b5e5f0e…e07829`, UUID `48EB7BC3-7222-3F27-8A09-4224B980EF8C`; menu and TheIsland captures passed. |
| V2-EV-035 | Gate 2B completes generation-bound read-only contracts across menu-to-world transition. | device verified | `V2-G2B-MULTIREGION-DEVICE-PASS-004`: generation `1→2`, previous invalidated, objects `61177→107275`, chunks `1→2`, all validators repeated, zero capabilities. Optional return-menu capture was not reported. |
| V2-EV-036 | Gate 2B is closed by the user-confirmed `.3` multi-region correction. | device verified / gate closed | `V2-G2B-MULTIREGION-DEVICE-PASS-004`: menu generation 1 `61177/1/32ms`, TheIsland generation 2 `107275/2/44ms`, previous invalidated and every required validator passed with zero capabilities. The immutable `.2` world-region abort remains unchanged. No return-menu capture or longer soak is inferred; `Class Engine.World` is not a live UWorld; parameter ABI/native dispatch remain absent. Docs baseline commit is `7d5e4555ed9f89f5eeeed89ac7c95c7f4072d37c`. |
| V2-EV-037 | `DEC-V2-NO-HOOK-FIRST-HOST` makes hooks non-prerequisite for first IP Listen and forbids broad Dedicated forcing. | architecture decision, not runtime evidence | Engine/definitions will be revalidated before Host; current world will be dispatched directly after Gate 3; original GetNetMode is retained. Optional inert observation/narrow policy is conditional on a post-transport demonstrated replication gap. Existing hook/GetNetMode evidence is preserved. |
| V2-EV-038 | Gate 2C exact relationship cards and typed bounded capture are implemented without runtime capability. | exact-binary + sdk/source + host-static validated; map subset device verified | `V2-G2C-MAP-RELATIONSHIPS-PASS-003` completed a fresh TheIsland relationship capture: native Engine, GameViewport, World/GWorld match, definitions and normal null NetDriver passed in 2 ms/10,240 relationship bytes with zero capabilities. Menu lifecycle and world-generation transitions/stability remain unverified. |
| V2-EV-039 | Gate 2C `.1` completes live Engine/Viewport/World relationship capture in TheIsland. | contradicted | The fresh Gate 2B snapshot completed in 37 ms with 110,906 objects/two chunks and every prerequisite validator passed, then the relationship phase aborted on the combined ShooterEngine identity validator with zero relationship bytes and zero capabilities. See `evidence/GATE2C_DEVICE_ENGINE_VALIDATOR_ABORT_001.md`. |
| V2-EV-040 | A live ShooterEngine direct UClass can be identified by a fixed FreshSDK object-array index. | fixed-index claim contradicted; dynamic replacement device verified | UClass object-array index `0x359` remains rejected as dump-instance data. `.3` resolved the direct class by fresh snapshot identity and device-validated exact `Class ShooterGame.ShooterEngine`, non-CDO state and GameEngine/Engine ancestry. No index or pointer is retained across captures. |
| V2-EV-041 | Gate 2C `.2` completes live Engine/Viewport/World relationship capture in TheIsland. | contradicted | `V2-G2C-ENGINE-FULLNAME-ABORT-002`: the 46 ms fresh snapshot completed with 107,279 objects/two chunks and all prerequisite validators passing; relationship capture accepted zero bytes and rejected the Engine instance full name. Runtime class `ShooterEngine` was reached; later CDO/direct-UClass/ancestry and all fields were not. Zero capabilities were retained. |
| V2-EV-042 | The exact transient owner may be represented as raw `Transient` or `/Engine/Transient` while the required published Engine identity remains `ShooterEngine Transient.ShooterEngine_<digits>`. | exact FreshSDK + closest source; host-static and device positive path verified | FreshSDK `FName::ToString` selects text after the last `/`, and its dump records `Package Transient` plus the numbered Engine full name; UE 4.17 constructs `/Engine/Transient`. `.3` retains every strict validator, passed the live Engine identity and relationship path, and still has 393 normal/UBSan negative assertions. |
| V2-EV-043 | Exact `.3` resolves the live TheIsland Engine/Viewport/World/definitions relationship subset read-only. | device verified for first map capture; receipt incomplete for gate closure | `V2-G2C-MAP-RELATIONSHIPS-PASS-003`: fresh discovery generation 1 completed in 45 ms with 106,725 objects/two chunks; relationships completed in 2 ms/10,240 bytes; GEngine and exact ShooterEngine chain passed; GameViewport and World passed; GWorld/ViewportWorld matched; one GameNetDriver decoded EOS primary/IpNetDriver fallback; `net_driver=none`; world generation established at 1; hooks/calls/mutation stayed zero. The public report omitted AuthorityGameMode/GameState presence, and same-world/transition/menu evidence remains open. |
| V2-EV-044 | Optional AuthorityGameMode/GameState validation presence is published without new reads or raw identity leakage. | host-static/arm64/package validated; positive map path device verified | `V2-G2C-OPTIONAL-RELATIONSHIPS-MAP-PASS-004` published present + validated GameModeBase/GameStateBase states from existing owned views. 399 normal + 399 UBSan-only assertions retain present/none/not-applicable and redaction coverage. No raw identity or capability appeared. |
| V2-EV-045 | Exact `.4` completes its first TheIsland relationship capture with all requested optional-presence rows. | device verified for first map capture | Fresh discovery generation 1 completed in 43 ms with 106,725 objects/two chunks; relationships completed in 2 ms/10,240 bytes; Engine/Viewport/World/GWorld/definitions passed, AuthorityGameMode and GameState were present/class-validated, NetDriver was none and capabilities stayed zero. Same-world repeat and lifecycle transition are not inferred. |

The historical Gate 2A package hash in `V2-G2A-BUILD-006` remains the immutable
receipt, but that ignored local `.deb` container path was accidentally
regenerated during the Gate 2B packaging workflow. Its restored payload embeds
the unchanged Gate 2A dylib SHA `65bb097…9ef72` and passes inspection, while the
current archive SHA is `46264cb…a4194db`; it is not a byte-preserved copy of the
old archive. The canonical Gate 2A injection dylib and manifest were not altered.

## Immutable device results

`V2-G1.5-SIDELOAD-PASS-002` is the authoritative functional Gate 1.5 result:

- icon action and visible Metal/ImGui frame: device verified;
- Status, Logs, Copy logs, Close and reopen: device verified;
- UIKit fallback: not observed;
- `hooks=0`, `engine_calls=0`, `mutation=0`: retained;
- longer menu/map soak and independent touch pass-through outside the open
  window: not separately reported and not claimed.

`V2-G2A-IDENTITY-PASS-001` is the positive exact-target Gate 2A identity PASS:
UUID, fingerprint and segment card matched; `scans_started=0` and all capability
counters remained zero; UI open/close/reopen, Copy logs and interaction worked.

`V2-G2A-DEATH-SIGNAL-EXIT-001` is a separate immutable extended-stability
failure. The character died in a local saved no-EOS world while the panel was
open; the process entered the game's signal handler and exited. No signal
number, stack, faulting thread or new `.ips` identifies a cause.

`V2-G2A-DEATH-BASELINE-002` is the subsequent immutable causal result. With no
injected Server-Host dylib, the same save and character death reproduced the
same process exit; EOS login did not alter it. The exact underlying stock-game
cause is outside this workflow.

`V2-G2B-CAPTURE-ABORT-001` is the immutable `.1` Gate 2B device result. Exact
profile identity and panel lifecycle passed, but three explicit generations
aborted on the same TUObjectArray relationship validator. The capture remained
fail-closed with scans=1 and zero hooks/engine calls/mutation; no owned live
name/object/reflection snapshot is claimed.

`V2-G2B-MENU-CAPTURE-PASS-003` is the immutable `.2` main-menu PASS. The exact
owned FName/object/reflection snapshot completed with every required validator
and zero active capabilities. `V2-G2B-WORLD-VM-REGION-ABORT-002` is the same
run's separate generation-2 TheIsland abort; it produced no replacement
snapshot and does not rewrite the menu PASS.

`V2-G2B-MULTIREGION-DEVICE-PASS-004` is the authoritative `.3` Gate 2B PASS.
It completed owned snapshots in the main menu and TheIsland, replaced discovery
generation 1 with generation 2, observed changed object/chunk counts, repeated
all validators and retained zero active capabilities. It resolves the `.2`
world limitation without rewriting that immutable abort.

`V2-G2C-ENGINE-VALIDATOR-ABORT-001` is the immutable `.1` Gate 2C result.
The fresh prerequisite snapshot completed in TheIsland, but no relationship
snapshot was accepted because the combined Engine identity validator rejected
the native root. Source audit found a fixed FreshSDK UClass object index in that
validator; the replacement removes it without changing roots, offsets or
capabilities. The `.1` failure is not rewritten by the correction.

`V2-G2C-ENGINE-FULLNAME-ABORT-002` is the immutable `.2` Gate 2C result. Its
fresh TheIsland snapshot passed, and the split diagnostic proved the native
root's runtime class name was `ShooterEngine`, but the instance full-name check
failed before CDO/direct-class/ancestry and all relationship fields. No live
relationship or world generation is claimed; zero capabilities were retained.

`V2-G2C-MAP-RELATIONSHIPS-PASS-003` is the exact `.3` first-map relationship
PASS. It device-validates the native Engine root, strict ShooterEngine identity,
GameViewport, same-identity GWorld/ViewportWorld, definitions decoding and the
normal pre-host `net_driver=none` state. World generation 1 was established,
but no earlier relationship snapshot existed, so transition invalidation and
same-world stability remain unproven. It does not rewrite `.1` or `.2`.
Its public report did not expose AuthorityGameMode/GameState presence, so it is
not a complete Gate 2C receipt. `.4` corrects only that publication boundary.

`V2-G2C-OPTIONAL-RELATIONSHIPS-MAP-PASS-004` is the exact `.4` positive
optional-presence device result. It repeats the live map relationship proof and
adds explicit present/class-validated AuthorityGameMode and GameState rows.
Because it is discovery/world generation `1/1`, it proves neither same-world
stability nor transition invalidation and does not close Gate 2C.

## Sishen pattern evidence

Sishen is an organization/reference source, never the iOS 1.10280 ABI
authority. Gate 2A read `Memory.h`, `Offsets.h`, `SigsAndOffsets.txt`, `Main.h`
and `Main.mm`. It accepted the idea of one image/memory boundary and ordered
startup phases; adapted dyld/image access into exact copied/parsed identity; and
rejected substring selection, singleton base caching, address heuristics,
unchecked globals, copied offsets/signatures, writes, calls, hooks, anti-analysis
and gameplay code.

Detailed reviews:

- [Sishen V2 foundation](evidence/SISHEN_V2_FOUNDATION_REVIEW_2026-08-18.md)
- [Gate 1.5 UI review](evidence/GATE1_5_DIAGNOSTIC_UI_REVIEW.md)
- [Gate 1.5 failure correction](evidence/GATE1_5_UI_FAILURE_INVESTIGATION.md)
- [Gate 2A identity](evidence/GATE2A_EXACT_IMAGE_IDENTITY.md)
- [Gate 2A device identity/death exit](evidence/GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md)
- [Gate 2B read-only contracts](evidence/GATE2B_READ_ONLY_CONTRACTS.md)
- [Gate 2B device capture abort](evidence/GATE2B_DEVICE_CAPTURE_ABORT_001.md)
- [Gate 2B device PASS](evidence/GATE2B_DEVICE_PASS_004.md)
- [Gate 2C live relationship cards and device protocol](evidence/GATE2C_LIVE_RELATIONSHIPS.md)
- [Gate 2C `.1` Engine-validator abort](evidence/GATE2C_DEVICE_ENGINE_VALIDATOR_ABORT_001.md)
- [Gate 2C `.2` Engine full-name abort](evidence/GATE2C_DEVICE_ENGINE_FULLNAME_ABORT_002.md)
- [Gate 2C `.3` first map relationship PASS](evidence/GATE2C_DEVICE_MAP_PASS_003.md)
- [Gate 2C `.4` optional relationship receipt correction](evidence/GATE2C_OPTIONAL_RELATIONSHIP_RECEIPT_FIX_004.md)
- [Gate 2C `.4` optional relationships map PASS](evidence/GATE2C_DEVICE_OPTIONAL_RELATIONSHIPS_MAP_PASS_004.md)

## Evidence required next

Gate 2B evidence is complete for the named read-only snapshot scope. Gate 2C
`.1` and `.2` are immutable fail-closed device aborts; `.3` has one passing map
relationship subset with an incomplete optional-presence receipt. Execute only
clean `.4`, whose first map capture has now passed. While the same process/world
is active, repeat Capture and require discovery/world `2/1`, discovery previous
invalidated yes and previous world invalidated no. Then capture a menu/map
lifecycle transition when possible. Gate 3, hosting, travel and hooks remain
closed.
