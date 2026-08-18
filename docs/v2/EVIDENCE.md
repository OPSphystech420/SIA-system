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
| V2-EV-006 | V2 packaging is revision-bound and emits a read-only manifest, raw dylib and matching dSYM. | statically validated | `V2-G2A-BUILD-006`: clean source `17e4e09…ad0d`, dylib/dSYM UUID `0704076C-EAB6-3F25-800D-C0F0B85431E8`, manifest SHA `77329da…c5ca`. |
| V2-EV-007 | Gate 2 is split into 2A/2B/2C. | source + device confirmed scope | Gate 2A exact identity is device verified; its death symptom reproduced without injection. Gate 2B is active and Gate 2C remains unstarted. |
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
| V2-EV-022 | ABI-005/006/007 resolver cards are exact-build grounded. | exact-binary + static implementation; device pending | IDA proves inline FNamePool `C8/CC/D0`, enclosing/direct object roots `0x5D434D8/+0x10`, item/chunk/flags/serial layout, UObject `0x28` and FunctionFlags `0xB0`. See Gate 2B report for representative functions/data flow. |
| V2-EV-023 | Derived heap access is profile/provenance bounded and produces owned bytes. | statically validated | Opaque reader-nonce tokens originate only from exact-profile RVA copies; depth/scope/overflow/VM permission/region/copy failures fail closed. Synthetic unmap, crossing, overflow, wrong-profile and token-scope tests pass. |
| V2-EV-024 | Gate 2B captures internally consistent owned FName/object/reflection snapshots. | statically validated; device pending | Synthetic mutation/retry, cursor/chunk/entry, flags/serial/index, stale generation, outer/super cycle, malformed relationship, cancellation/time/byte/object limits and known-name/object tests pass. No live target result is inferred. |
| V2-EV-025 | Gate 2B execution is explicit and preserves zero active capabilities. | source/iOS compile validated; device pending | One serial worker runs only after Contracts action. Pre-capture scans=0; post-request scans=1; hooks/engine calls/mutation=0. UI receives only a bounded immutable report and cannot include Bindings/raw address types. |

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

## Evidence required next

Gate 2B exact resolver cards, provenance/snapshot host tests, boundary audit and
iOS compile are complete. Produce/execute the one clean immutable artifact and
return the bounded Contracts report. Gate 2C evidence is not requested.
