# Server-Host V2 test matrix

This active matrix contains V2 protocols and V2 executions only. The former
matrix, including every Legacy execution/failure row, date, SHA-256 and
clarification, is preserved verbatim at
[`archive/legacy/TEST_MATRIX_2026-08-18.md`](archive/legacy/TEST_MATRIX_2026-08-18.md).

Completed V2 rows are immutable. Append a new row for a new execution; never
rewrite a PASS or FAIL into a later conclusion.

## Claim states

| State | Meaning |
|---|---|
| `compiled` | Named local build succeeded; no runtime claim. |
| `statically validated` | Named host tests/assertions/audits passed; no device claim. |
| `ready for device test` | Unique artifact and exact protocol exist; no pass yet. |
| `device verified` | User supplied a PASS for the exact V2 artifact and protocol. |
| `contradicted` | Exact V2 execution disproved the affected claim. |
| `unverified` | Missing, incomplete or non-transferable evidence. |

## Current V2 protocols

| Protocol ID | Gate | Procedure summary | Exit condition | State |
|---|---|---|---|---|
| PLAN-G1-STATIC-001 | 1 | Clean host build; foundation assertions; boundary audit | Deterministic PASS and fail-closed negative cases | executed historically and rechecked by the preparation workflow |
| PLAN-G1-PACKAGE-001 | 1 | Build from a clean revision; inspect package/control/payload/arm64/signature/strings; emit immutable manifest | Package and dylib hashes recorded; no installation | executed by `V2-G1-PREP-003` |
| PLAN-G1.5-SIDELOAD-001 | 1.5 | Inject only manifested raw V2 dylib into a clean app; inspect Status/Logs, close/pause behavior and menu/local-world soak | Icon/refusal visibility, exact zero capabilities, bounded logs, touch/render isolation and stability | executed; FAIL `V2-G1.5-SIDELOAD-FAIL-001` |
| PLAN-G1.5-SIDELOAD-002 | 1.5 | Inject corrected `.2`; verify acknowledged action, visible panel, Status/Logs, Copy, Close/reopen and zero capabilities | Functional panel path passes; missing longer soak/touch checks remain explicit | executed by `V2-G1.5-SIDELOAD-PASS-002`; functional-device-pass, extended-soak-pending |
| PLAN-G2A-SIDELOAD-001 | 2A | Inject the single Gate 2A artifact; verify exact image/profile receipt, zero scans/capabilities, fail-close behavior and rolled-over read-only stability/touches | One exact profile, no address disclosure, no later discovery, panel lifecycle and ordinary menu/local-world stability | partially executed: identity PASS; death-triggered stability FAIL; wrong-profile negative unexecuted |
| PLAN-G2A-DEATH-CAUSAL-001 | 2A | Same-save death baseline without injection; B/C were conditional controls | Classify whether injection is necessary for the symptom | closed after arm A; external baseline reproduced; B/C waived by user |
| PLAN-G2B-DISCOVERY-001 | 2B | Explicit bounded FNamePool, GUObjectArray and reflection capture only through the provenance reader | Owned known-name/object/reflection snapshots; generation invalidation; zero capabilities | complete via `V2-G2B-MULTIREGION-DEVICE-PASS-004` |
| PLAN-G2C-RELATIONSHIPS-001 | 2C | Fresh Gate 2B snapshot followed by bounded Engine/GameViewport/World/NetDriver/definition relationships and world-generation invalidation | Exact relationships, menu/map transition, same-world generation stability, stale-generation refusal and zero capabilities | complete via contextual closure `V2-G2C-CONTINUOUS-MENU-MAP-DEVICE-PASS-008` over immutable `.007` |

## Immutable V2 execution rows

| Test ID | Date | Artifact / build ID | Environment and procedure | Result | Claim after | Report |
|---|---|---|---|---|---|---|
| V2-G1-STATIC-001 | 2026-08-18 | historical `.build/v2-host/serverhost_v2_core_tests`; SHA-256 `fbc91b80c77ee35c95c93b28be837aa76ec355d0a2ebb221a399f76cdb750da5`; `gate1-static-20260818` | Apple Silicon Mac host-local; clean C++20 build, 56 assertions and the then-current raw boundary audit | PASS | Gate 1 statically validated only; no live/device claim | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md) |
| V2-G1-PACKAGE-BUILD-001 | 2026-08-18 | historical `packages/v2/com.mhga.serverhost.v2_0.1.0~gate1.20260818.1_iphoneos-arm.deb`; SHA-256 `4b4e10d6d8e88f3f439fe1bca1ae082a0062277350d5e21611b83662efe7aa35`; `gate1-inert-package-20260818.1` | Local iOS cross-build and content inspection; no game/client execution | PASS | compiled/statically inspected; runtime unverified | [Gate 1 report](evidence/GATE1_TYPED_FOUNDATION.md#inert-ios-packaging-supplement) |
| V2-G1-STATIC-RECHECK-002 | 2026-08-18 | historical Gate 1 host binary, same SHA-256 as `V2-G1-STATIC-001` | 56 host-local assertions and old audit rerun during a Legacy investigation | PASS | static foundation still passed; explicitly not live validation | [Archived context](archive/legacy/TEST_MATRIX_2026-08-18.md) |
| V2-G1-PREP-003 | 2026-08-18 | revision `23da20fe1bbc472bf2476ec6d33a7cd658d7c0d3`; `gate1-foundation-20260818.3`; host binary SHA-256 `d6a841979411c94dabe746afb2c9a64ef6b5b01dd8e0935f47c5e8030c94e6cd`; package SHA-256 `e9d8d187705370270b310a7ee7a05f37909aee12736e261de8b37a204049af29`; dylib SHA-256 `9f06fffb905bbd8a8b97959f2fe32faa49d89528d6668502a0ebb24781b5834a` | Clean V2-only host build; 61 host-local assertions; regex/include-layer boundary audit; iOS arm64 compile including layout assertions; package metadata/payload/Mach-O/signature/build-ID/Legacy-isolation inspection; immutable manifest SHA-256 `91bafa567caf311a597e88f3dd1a24f9e0ef6857cd76a58550fa69c4f75eae78`; no installation | PASS | Gate 1 infrastructure is statically validated and Gate 2 is next; no device/live claim | [Current status](STATUS.md) |
| V2-G1.5-BUILD-004 | 2026-08-18 | Git baseline `a8defbc9f37ed17e54f30b88f715a5ea238ff667`, modified task tree; `gate1.5-diagnostic-ui-20260818.1`; host binary SHA-256 `d1ae694709c4c357b76c215b3f8d3448c851560a74e594632aad511be6ebbc02`; raw dylib SHA-256 `780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b`; Mach-O/dSYM UUID `A4313EC9-3901-3EFC-BC54-5A910DA4F514`; package SHA-256 `f5e0503e72e9d027e851884743d3279b8603d4f6732b1a605d5efa2744099348` | 96 host-local assertions; logger bounds/redaction/concurrency/snapshot/refusal tests; UI/include/render boundary audit; iOS arm64 UIKit/Metal/ImGui build; package and injectable Legacy/gameplay symbol audits; final package dylib copied byte-identically with matching dSYM; manifest SHA-256 `9dbd094744753448416a40a8d29c121c9337f05d6a887f5350d2ee84d6c9cbc2`; no installation/execution | PASS | compiled/statically validated and ready for `PLAN-G1.5-SIDELOAD-001`; runtime UI/stability unverified; Gate 2 not started | [Gate 1.5 review](evidence/GATE1_5_DIAGNOSTIC_UI_REVIEW.md) |
| V2-G1.5-SIDELOAD-FAIL-001 | 2026-08-18 | `gate1.5-diagnostic-ui-20260818.1`; raw pre-injection dylib SHA-256 `780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b` | User manual execution of `PLAN-G1.5-SIDELOAD-001`; floating V2 icon appeared and was tapped. Device/OS, attempt count, logs and screenshot were not supplied. | FAIL: no visible menu opened | Bootstrap/icon installation observed; visible menu opening contradicted; Metal rendering, touch routing, logs and close/pause behavior unverified; Gate 1.5 failed-under-investigation | [Failure intake](evidence/GATE1_5_SIDELOAD_FAILURE_001.md) |
| V2-G1.5-FIX-BUILD-005 | 2026-08-18 | clean revision `8fb09e654466b07b534a3dd16b2618e789d84777`, tag `v2-gate1.5-diagnostic-ui-20260818.2-source`; `gate1.5-diagnostic-ui-20260818.2`; host binary SHA-256 `418ec0df03be3175fea571a177ae0fb21f1c37a92432abf7457fc9f833b6326f`; raw dylib SHA-256 `4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32`; Mach-O/dSYM UUID `4D308F3A-41F6-392C-9C0C-D2384DAFB889`; package SHA-256 `646798a6c880767146d8c32b068a972e39deafb87ecd5c3e0aedabb9602423ee` | 143 host assertions; presentation transition/deadline/fallback/event tests; boundary audit; iOS arm64 UIKit/Metal/ImGui build; package and injection Legacy/gameplay symbol audits; byte-identical package/raw dylib and matching dSYM; immutable manifest SHA-256 `6aea8368b71e74363f9c5e3c4faf95d943c24d744d208dc8d7a9d319f770b9e7`; no installation/execution | PASS | compiled/statically validated and ready for `PLAN-G1.5-SIDELOAD-002`; UIKit/Metal pixels, input, copy, close/reopen and stability remain unverified; Gate 2 not started | [Investigation/correction report](evidence/GATE1_5_UI_FAILURE_INVESTIGATION.md) |
| V2-G1.5-SIDELOAD-PASS-002 | 2026-08-18 | `gate1.5-diagnostic-ui-20260818.2`; source `8fb09e654466b07b534a3dd16b2618e789d84777`; raw input dylib SHA-256 `4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32` | User manual Sideloadly execution. Runtime receipt confirmed button action, open request, verified hierarchy, first frame, Metal drawable/pass, ImGui submission/presentation, stopped Metal on Close, reopen and bounded log copy. | PASS: functional device path | Device-verified icon action, visible Metal/ImGui, Status, Logs, Copy logs, Close/reopen; no UIKit fallback; capabilities remained zero. Longer menu/map soak and independent outside-window touch check were not separately reported and are not claimed; user authorized Gate 2A. | [Gate 1.5 PASS 002](evidence/GATE1_5_SIDELOAD_PASS_002.md) |
| V2-G2A-BUILD-006 | 2026-08-18 | clean revision `17e4e09ce8029bb89b22560da771ddc170e2ad0d`, tag `v2-gate2a-exact-identity-20260818.1-source`; `gate2a-exact-identity-20260818.1`; host binary SHA-256 `89b6e8322857c64cd731fa17897212fd5748fe744bd8c4ccd81c8455d5b67abc`; raw dylib SHA-256 `65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72`; Mach-O/dSYM UUID `0704076C-EAB6-3F25-800D-C0F0B85431E8`; package SHA-256 `19d75c2e4ec8df0bc3e00d33e7337f3f7e981ddfc8308ebd8981007eb0784209` | 191 normal host assertions and 191 UBSan-only assertions; malformed/ambiguous identity and checked-read negative tests; raw boundary audit; iOS arm64 compile; package/control/payload/build-ID and injection Legacy/gameplay isolation audits; byte-identical package/raw dylib, matching dSYM; manifest SHA-256 `77329da6d35f49c332c63a39e733d6fc970eaf474f89600b7edd37909ad1c5ca`; no installation/execution | PASS | statically validated and ready for `PLAN-G2A-SIDELOAD-001`; exact runtime match, wrong-profile refusal and stability/touch behavior remain device-unverified; Gate 2B not started | [Gate 2A report](evidence/GATE2A_EXACT_IMAGE_IDENTITY.md) |
| V2-G2A-IDENTITY-PASS-001 | 2026-08-18 | `gate2a-exact-identity-20260818.1`; source `17e4e09ce8029bb89b22560da771ddc170e2ad0d`; raw input dylib SHA-256 `65bb0975e7de52b83df082fa16f5ba7478f111355174d7255724c9afb6d9ef72` | User manual Sideloadly execution on Apple Silicon Mac. Status/Logs showed exact-match UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC`, expected segment card and fingerprint `8bfc1fd248a5...`; open/close/reopen, Copy logs and interaction worked. | PASS: positive exact-target identity sub-contract | Exact image identity is device verified; `scans_started=0`, hooks/engine calls/mutation zero. Wrong-profile negative and extended stability are not included in this PASS. | [Gate 2A device report](evidence/GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md) |
| V2-G2A-DEATH-SIGNAL-EXIT-001 | 2026-08-18 | same exact Gate 2A artifact; Console SHA-256 `0578303bea504af55cf6762d147debe6443e6f915bc9d3a56738608b360c7a8f` | Apple Silicon Mac; local saved world; no EOS; character death and death/respawn transition with panel open. Last V2 open `uptime_ms=120678`, no later close. Console line 7579: `GASignalHandler entered`; subsequent crash-event upload received HTTP 200; no signal number, stack, faulting thread or new 2026-08-18 ShooterGame `.ips`. | FAIL: extended stability contradicted | At intake the cause was unclassified and Gate 2B paused. Subsequent `V2-G2A-DEATH-BASELINE-002` reproduced the symptom without injection and reclassified it as an external baseline limitation. HTTP 200 is upload success, not cause. | [Gate 2A device report](evidence/GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md) |
| V2-G2A-DEATH-BASELINE-002 | 2026-08-18 | ShooterGame 1.10280 without any injected Server-Host dylib | User executed arm A with the same local saved world and character death. The application exited identically; signing in to EOS did not alter the result. | classification: external baseline reproduced | Gate 2A is not a necessary cause. Exact stock-game cause is deferred; B/C waived; death/respawn removed from current V2 stability acceptance; Gate 2B unblocked. | [Gate 2A device report](evidence/GATE2A_DEVICE_IDENTITY_DEATH_EXIT_001.md) |
| V2-G2B-STATIC-001 | 2026-08-18 | Gate 2B source; synthetic exact image plus sparse owned memory regions | 270 normal + 270 UBSan-only assertions; FreshSDK RVA normalization; provenance/unmap/overflow/scope; FName/object double-sample mutation/retry; malformed bounds/entries/chunks/relationships; flags/serial/generation/cycles; cancellation/time/byte/object limits; report redaction/immutability; boundary audit; iOS arm64 compile. Combined ASan/UBSan compiled but stalled before the first marker and was interrupted. | PASS for normal/UBSan/audit/iOS compile; combined sanitizer runtime unverified | Static/compile claim only. Exact live roots/names/objects remain device-unverified; Gate 2C and hosting not started. | [Gate 2B report](evidence/GATE2B_READ_ONLY_CONTRACTS.md) |
| V2-G2B-BUILD-007 | 2026-08-18 | clean revision `ff9637b34b308117208555482c5a8a872c8b94c9`, tag `v2-gate2b-readonly-contracts-20260818.1-source`; `gate2b-readonly-contracts-20260818.1`; raw dylib SHA-256 `e7f6c3c932c2af759547d69b46359b2e1004c51dbd5f2f5a7c9fbd25729afb79`; Mach-O/dSYM UUID `0D2DBE64-7258-34CC-B9F0-A3DFFB80516D`; package SHA-256 `bff134a2ec73fac33b8cff6fa9cd3e7dc9f426efb2e6ce21241423a816cb7232` | 270 normal and 270 UBSan-only assertions; boundary audit; iOS arm64 build; package/control/payload/build/source ID and injection Legacy/gameplay isolation audits; matching dSYM with DWARF SHA `0735a7a…342acd`; manifest SHA `956d912…88d78`; no installation/execution | PASS | compiled/statically validated and ready for `PLAN-G2B-DISCOVERY-001`; exact live names/objects/reflection and repeated-capture generation remain device-unverified; Gate 2C and hosting not started | [Gate 2B report](evidence/GATE2B_READ_ONLY_CONTRACTS.md) |
| V2-G2B-CAPTURE-ABORT-001 | 2026-08-18 | exact `.1` build/source above; screenshot SHAs `cf9e0cf…cb0392`, `ea0bb3d…2deed` | Exact profile matched; panel open/close/reopen and Copy logs worked. Explicit generations 1/2/3 each aborted after 47/39/38 ms on `invalid TUObjectArray num/max/chunk relationship`. | FAIL: completed read-only contract snapshot contradicted | Fail-closed behavior passed with scans=1 and hooks/engine calls/mutation=0. `.1` returned no valid FName/object/reflection result. Source audit found operational limits incorrectly applied to reserved Max fields; corrected artifact required. | [Device abort report](evidence/GATE2B_DEVICE_CAPTURE_ABORT_001.md) |
| V2-G2B-CAPACITY-FIX-STATIC-002 | 2026-08-18 | Gate 2B `.2` correction source before clean artifact receipt | 280 normal + 280 UBSan-only assertions; large valid reserve capacity, insufficient capacity envelope, configured capacity limit, allocated-chunk work limit and address-free counter diagnostics; boundary audit; iOS arm64 compile | PASS | Capacity is separated from bounded live work statically; exact live header/capture remains device-unverified | [Device abort report](evidence/GATE2B_DEVICE_CAPTURE_ABORT_001.md) |
| V2-G2B-CAPACITY-FIX-BUILD-008 | 2026-08-18 | clean revision `739f274c5b01c29703bbc9b34b40ad6a167c24af`, tag `v2-gate2b-readonly-contracts-20260818.2-source`; `gate2b-readonly-contracts-20260818.2`; raw dylib SHA-256 `56e9ebb0d4453b90e4d63ccfa5431a142d8d94bc42b043b0e45b24e819203a6c`; Mach-O/dSYM UUID `F02EC54E-DEB7-35AA-B91C-C868547BCD03`; package SHA-256 `ceffbde6f34f3323459a3e2754cf18ce09e6d353336564caee01e401a44bad83` | 280 normal + 280 UBSan-only assertions; boundary audit; iOS arm64 build; package/control/payload/build/source ID and injection isolation audits; dSYM DWARF SHA `3360fab…d2771`; manifest SHA `88c29c9…a17cc`; no installation/execution | PASS | Single corrected artifact ready for the bounded Gate 2B menu capture repeat; live header and owned snapshots remain device-unverified | [Device abort report](evidence/GATE2B_DEVICE_CAPTURE_ABORT_001.md) |
| V2-G2B-MENU-CAPTURE-PASS-003 | 2026-08-18 | exact `.2` artifact above; screenshot SHAs `14c6265…34b9d`, `a6eb666…28c6` | Generation 1 completed in 49 ms: 178/390585 FName blocks/entries; objects 61171/25231360; chunks 1/385; 24,675,046 copied bytes; ten names, nine core objects/functions and required reflection checks passed. | PASS: exact main-menu owned snapshot | ABI-005/006 and bounded ABI-007 are device-proven for the menu snapshot; scans=1 and hooks/engine calls/mutation=0. No world or repeated-success claim. | [Menu PASS/world abort report](evidence/GATE2B_DEVICE_MENU_PASS_WORLD_ABORT_002.md) |
| V2-G2B-WORLD-VM-REGION-ABORT-002 | 2026-08-18 | same `.2` process after entering TheIsland | Generation 2 marked previous invalidated, then aborted after 37 ms: `requested bytes are not contained in one readable VM region`. Bounded report copy succeeded; no crash in supplied log. | FAIL: TheIsland replacement snapshot contradicted | Partial zeros are discarded candidate state. No generation-2 object count or snapshot is claimed; scans=1 and zero capabilities retained. | [Menu PASS/world abort report](evidence/GATE2B_DEVICE_MENU_PASS_WORLD_ABORT_002.md) |
| V2-G2B-MULTIREGION-STATIC-003 | 2026-08-18 | Gate 2B `.3` source before clean artifact receipt | 290 normal + 290 UBSan-only assertions; adjacent-readable composition, gap, unreadable, unmap/copy failure and redacted type-context tests; boundary audit | PASS | Each underlying copy remains within one queried readable region; composed owned result is returned only after full success. Exact TheIsland result remains device-unverified. | [Menu PASS/world abort report](evidence/GATE2B_DEVICE_MENU_PASS_WORLD_ABORT_002.md) |
| V2-G2B-MULTIREGION-BUILD-009 | 2026-08-18 | clean revision `852e260d353c9a67a18e5763f358f1242b6e7947`, tag `v2-gate2b-readonly-contracts-20260818.3-source`; `gate2b-readonly-contracts-20260818.3`; raw dylib SHA-256 `b5e5f0edf47ebb5b71c0c08d947bd6d186538ea2a9f9bc9722c4076ee0e07829`; Mach-O/dSYM UUID `48EB7BC3-7222-3F27-8A09-4224B980EF8C`; package SHA `e1147e8fee5f7fa64bf1fe90d4e109448da1949e202117287f3deee363b7c8f8` | 290 normal + 290 UBSan-only assertions; boundary audit; iOS arm64 build; package/control/payload/build/source ID and injection isolation audits; dSYM DWARF SHA `3832a56…8bedd`; manifest SHA `29eaa59…ff89e`; no installation/execution | PASS | Single replacement artifact ready for menu/TheIsland repeat; live multi-region behavior remains device-unverified | [Menu PASS/world abort report](evidence/GATE2B_DEVICE_MENU_PASS_WORLD_ABORT_002.md) |
| V2-G2B-MULTIREGION-DEVICE-PASS-004 | 2026-08-18 | exact `.3` artifact/source above | User Sideloadly execution: menu generation 1 completed in 32 ms with FNames `178/390585`, objects `61177/25231360`, chunks `1/385`, copied bytes `24675204`; TheIsland generation 2 completed in 44 ms with FNames `180/399365`, objects `107275/25231360`, chunks `2/385`, copied bytes `26049956`; previous invalidated=yes; all ten names, nine objects/functions and reflection validators passed twice. | PASS: Gate 2B device verified | Exact profile, owned snapshots, menu-to-world generation replacement and multi-region positive path passed with scans=1 and hooks/engine calls/mutation=0. Optional return-menu capture and longer soak not reported; Gate 2C not started. | [Gate 2B device PASS](evidence/GATE2B_DEVICE_PASS_004.md) |
| V2-G2C-BUILD-010 | 2026-08-18 | clean revision `695b230d9db8438142c48aa4b9eb6479e3e1fe35`, tag `v2-gate2c-live-relationships-20260818.1-source`; `gate2c-live-relationships-20260818.1`; raw dylib SHA-256 `9a0aee70e9012dd57a1fa543b035f5037d7e0ed26c800e8e029ef4c438ffefb4`; Mach-O/dSYM UUID `53A00208-554E-334F-815E-59A9694AFD15`; package SHA-256 `65984a8265a0e15dd73f80dfd34613d1360f41cc8fe17fc3959b0dc3038a45a2` | 383 normal + 383 UBSan-only assertions; exact relationship/array/generation negatives; boundary audit; arm64 iOS build; package/control/payload/build/source ID and injection isolation audits; dSYM DWARF SHA `cf55bb2…d2aed`; v4 manifest SHA `342e58f…641d9`; no installation/execution | PASS | Gate 2C compiled/statically validated and ready for `PLAN-G2C-RELATIONSHIPS-001`; all live values, lifecycle observations and device world-generation transitions remain unverified; Gate 3/hosting remain closed | [Gate 2C report](evidence/GATE2C_LIVE_RELATIONSHIPS.md) |
| V2-G2C-ENGINE-VALIDATOR-ABORT-001 | 2026-08-18 | exact `.1` artifact/source above; screenshot SHAs `54e5af7…0986c`, `65941f9…a5ed0`; local TheIsland | Exact profile passed. Fresh Gate 2B generation 1 completed in 37 ms with FNames `180/399494`, objects `110906/25231360`, chunks `2/385`, copied bytes `26141130`; all required name/object/reflection validators passed. Gate 2C accepted zero relationship bytes and aborted on the combined exact ShooterEngine identity validator. | FAIL: live relationship capture contradicted | Fail-closed behavior passed with scans=1 and hooks/engine calls/mutation=0. No Engine/Viewport/World/NetDriver/definitions/lifecycle/world-generation value is claimed. Source audit found fixed FreshSDK UClass dump index `0x359` promoted to a runtime invariant. | [Device abort report](evidence/GATE2C_DEVICE_ENGINE_VALIDATOR_ABORT_001.md) |
| V2-G2C-ENGINE-VALIDATOR-FIX-STATIC-002 | 2026-08-18 | corrected `.2` source before clean artifact receipt | 387 normal + 387 UBSan-only assertions; relocated exact ShooterEngine UClass positive; wrong package/full-name negative; split class/full-name/CDO/direct-class diagnostics; boundary audit | PASS | Fixed game-specific UClass index removed. Direct class is resolved by fresh snapshot index/serial/generation and validated as exact `Class ShooterGame.ShooterEngine`; live corrected behavior remains device-unverified. | [Device abort report](evidence/GATE2C_DEVICE_ENGINE_VALIDATOR_ABORT_001.md) |
| V2-G2C-ENGINE-VALIDATOR-FIX-BUILD-011 | 2026-08-18 | clean revision `4a53ab940e8085c2e13c00489b4ab6ab9e95764c`, tag `v2-gate2c-live-relationships-20260818.2-source`; `gate2c-live-relationships-20260818.2`; raw dylib SHA-256 `ee6f6d9014fa98171a105fa009750e4d078a099a8ecf4a969dce98c704b60cae`; Mach-O/dSYM UUID `E70F89CA-A7DE-3AEA-8CA1-D23AEF07AD8F`; package SHA-256 `7bc9607751fb630c38ee18aa56be3c187320765f1e95cfa92aee1ca51aaa61fe` | 387 normal + 387 UBSan-only assertions; exact direct-class correction positives/negatives; boundary audit; clean arm64 iOS build; package/control/payload/build/source ID and injection isolation audits; dSYM DWARF SHA `2f7c171…db041`; v4 manifest SHA `832ace6…10e7`; no installation/execution | PASS | One corrected raw artifact is ready for the Gate 2C menu/TheIsland/same-world device repeat. All relationship values and world-generation transitions remain device-unverified; Gate 3/hosting remain closed. | [Gate 2C report](evidence/GATE2C_LIVE_RELATIONSHIPS.md) |
| V2-G2C-ENGINE-FULLNAME-ABORT-002 | 2026-08-18 | exact `.2` artifact/source above; local TheIsland | Exact profile passed. Fresh Gate 2B generation 1 completed in 46 ms with FNames `180/399365`, objects `107279/25231360`, chunks `2/385`, copied bytes `26050080`; all required name/object/reflection validators passed. Gate 2C accepted zero relationship bytes and rejected `ShooterEngine Transient.ShooterEngine_<number>`. | FAIL: live relationship capture contradicted | The split error proves runtime class name `ShooterEngine` was reached, but `.2` ordering did not reach CDO/direct-UClass/ancestry or fields. World generation remained zero; hooks/engine calls/mutation remained zero. | [`.2` device abort report](evidence/GATE2C_DEVICE_ENGINE_FULLNAME_ABORT_002.md) |
| V2-G2C-ENGINE-FULLNAME-FIX-STATIC-003 | 2026-08-19 | `.3` correction source before clean artifact receipt | 393 normal + 393 UBSan-only assertions; exact `/Engine/Transient` owner canonicalization positive; unnumbered Engine negative; bounded printable/address-free failure context after exact direct class and GameEngine/Engine ancestry; boundary audit | PASS | Strict required published identity remains numbered and unchanged. Only the exact transient-package alias is normalized; roots, offsets and zero capabilities are unchanged. Clean build receipt is recorded separately below. | [`.2` device abort report](evidence/GATE2C_DEVICE_ENGINE_FULLNAME_ABORT_002.md) |
| V2-G2C-ENGINE-FULLNAME-FIX-BUILD-012 | 2026-08-19 | clean revision `f4598395efeadcd882af5f257b1e6d72a78de6d3`, tag `v2-gate2c-live-relationships-20260818.3-source`; `gate2c-live-relationships-20260818.3`; raw dylib SHA-256 `4b7ddd7cf68cd089c69ca632415ec0a56594e49f60be0dccabc438dd471e2ae3`; Mach-O/dSYM UUID `78EAF0B0-9C08-39BE-B37B-25E4A8EC7629`; package SHA-256 `18d4dd6dab7d02325d4e2ce3f513cf1cbe0403d7263424669b2a5bcae674e8f6` | 393 normal + 393 UBSan-only assertions; exact transient-owner/full-name positives/negatives; boundary audit; clean arm64 iOS build; package/control/payload/build/source ID and injection isolation audits; dSYM DWARF SHA `0472434…d8707`; v4 manifest SHA `a821b4a…6749b`; no installation/execution as part of build receipt | PASS | Exact input subsequently produced the first-map device PASS below. Build evidence itself remains static; Gate 3/hosting remain closed. | [Gate 2C report](evidence/GATE2C_LIVE_RELATIONSHIPS.md) |
| V2-G2C-MAP-RELATIONSHIPS-PASS-003 | 2026-08-19 | exact `.3` artifact/source above; first capture in an already loaded local TheIsland world | Fresh Gate 2B generation 1 completed in 45 ms with FNames `180/399305`, 106,725 valid objects/two chunks and 26,045,310 copied bytes; all prerequisite validators passed. Relationships completed in 2 ms/10,240 bytes: one exact live ShooterEngine root/class/ancestry, GameViewport and World validated, GWorld/ViewportWorld matched, lifecycle map, populated definitions decoded one EOS/IpNetDriver GameNetDriver, and NetDriver was normally absent. | PASS: first map relationship subset | World generation 1 was established with no prior world to invalidate; same-world stability, menu lifecycle and transition invalidation remain unverified. AuthorityGameMode/GameState presence was not reported. Hooks/engine calls/mutation stayed zero. | [`.3` map PASS](evidence/GATE2C_DEVICE_MAP_PASS_003.md) |
| V2-G2C-OPTIONAL-RELATIONSHIP-RECEIPT-BUILD-013 | 2026-08-19 | clean revision `4db2599d25350b1eadd9d704afcba2fe76743473`, tag `v2-gate2c-live-relationships-20260819.4-source`; `gate2c-live-relationships-20260819.4`; raw dylib SHA-256 `95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677`; Mach-O/dSYM UUID `7CB1B073-D9A5-39E0-BDD3-2638B0618B28`; package SHA-256 `190ffbb9addb5e1b3a388d5e5cda168042e0df7738c34e1203f4b8259f78bbcb` | 399 normal + 399 UBSan-only assertions; optional present/none rendering and redaction; boundary audit; clean arm64 iOS build; package/control/payload/build/source ID and injection isolation audits; dSYM DWARF SHA `2d1f7ba…d5719b`; v4 manifest SHA `0a7cd36…b99387`; no installation/execution | PASS | `.4` publishes already-owned AuthorityGameMode/GameState presence without a new read. Use it for the full menu/TheIsland/same-world/optional-return device protocol. Gate 3/hosting remain closed. | [`.4` receipt correction](evidence/GATE2C_OPTIONAL_RELATIONSHIP_RECEIPT_FIX_004.md) |
| V2-G2C-OPTIONAL-RELATIONSHIPS-MAP-PASS-004 | 2026-08-19 | exact `.4` artifact/source above; first capture in an already loaded local TheIsland world | Fresh discovery generation 1 completed in 43 ms with FNames `180/399305`, 106,725 valid objects/two chunks and 26,045,236 total copied bytes; all prerequisite validators passed. Relationships completed in 2 ms/10,240 bytes; Engine/Viewport/World/GWorld/definitions passed; AuthorityGameMode and GameState were present and base-class validated; NetDriver was none. | PASS: first `.4` map relationship receipt | Positive optional-presence publication is device-proven with zero hooks/calls/mutation and no error log. Same-world generation stability, menu lifecycle and transition invalidation remain unverified. | [`.4` map PASS](evidence/GATE2C_DEVICE_OPTIONAL_RELATIONSHIPS_MAP_PASS_004.md) |
| V2-G2C-INDEPENDENT-MAP-REPRODUCIBILITY-PASS-005 | 2026-08-19 | same exact `.4` artifact/source; separately submitted map capture | Fresh discovery generation 1 completed in 38 ms with FNames `180/399628`, 109,440 valid objects/two chunks and 26,123,742 copied bytes; all prerequisite validators passed. Relationships completed in 2 ms/10,240 bytes; Engine/Viewport/World/GWorld/definitions, present GameMode/GameState and normal null NetDriver all passed. | PASS: independent map relationship reproducibility; requested generation repeat incomplete | Zero hooks/calls/mutation, no error entry and no raw address passed. `Previous invalidated=not applicable` and discovery/world `1/1` prove no same-tracker predecessor; discovery increment, same-world stability, stale invalidation and lifecycle transition remain unverified. | [Independent map reproducibility PASS](evidence/GATE2C_DEVICE_INDEPENDENT_MAP_REPRODUCIBILITY_PASS_005.md) |
| V2-G2C-CONTINUOUS-MAP-GENERATIONS-PARTIAL-006 | 2026-08-19 | same exact `.4` artifact/source; raw dylib SHA-256 `95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677`; Mach-O/dSYM UUID `7CB1B073-D9A5-39E0-BDD3-2638B0618B28` | One cumulative process log: requests/completions `seq 12/14 @ 24464/24500`, `25/27 @ 65631/65668`, `29/31 @ 83298/83336`; discovery `1->2->3`; world `1->2->2`; prior discovery `not-applicable/yes/yes`; prior world invalidated `no/yes/no`. Engine/Viewport/World/GWorld/definitions, present class-validated GameMode/GameState and normal null NetDriver passed in all captures. | PARTIAL PASS: same-tracker map generation contracts device-proven; Gate 2C not closed | World replacement invalidated old world-bound identities; the fresh repeated current-world capture kept generation stable. Hooks/calls/mutation stayed zero; no bounded-log error or raw address. All lifecycle labels were `map`; no menu lifecycle/menu-map transition or explicit visible-regression observation was supplied. | [Continuous map generations PARTIAL 006](evidence/GATE2C_DEVICE_CONTINUOUS_MAP_GENERATIONS_PARTIAL_006.md) |
| V2-G2C-CONTINUOUS-MAP-REPRODUCIBILITY-PARTIAL-007 | 2026-08-19 | same exact `.4` artifact/source; raw dylib SHA-256 `95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677`; Mach-O/dSYM UUID `7CB1B073-D9A5-39E0-BDD3-2638B0618B28` | A second cumulative process log: requests/completions `seq 13/15 @ 20338/20388`, `26/28 @ 47805/47851`, `30/32 @ 57705/57752`; discovery `1->2->3`; world `1->2->2`; prior discovery `not-applicable/yes/yes`; prior world invalidated `no/yes/no`. Engine/Viewport/World/GWorld/definitions, present class-validated GameMode/GameState and normal null NetDriver passed throughout. | PARTIAL PASS: continuous generation/relationship behavior independently reproduced; Gate 2C not closed | Hooks/calls/mutation stayed zero; no error, stale identity or raw address. The transcript does not label the visible state/action of each capture, all lifecycle fields are `map`, and no explicit visible-regression observation was supplied. Menu transition closure is not inferred from object counts. | [Continuous map reproducibility PARTIAL 007](evidence/GATE2C_DEVICE_CONTINUOUS_MAP_REPRODUCIBILITY_PARTIAL_007.md) |
| V2-G2C-CONTINUOUS-MENU-MAP-DEVICE-PASS-008 | 2026-08-21 | same exact `.4` artifact/source and immutable `.007` transcript; raw dylib SHA-256 `95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677`; Mach-O/dSYM UUID `7CB1B073-D9A5-39E0-BDD3-2638B0618B28` | User contextual confirmation: capture 1 main menu; capture 2 TheIsland after natural entry; capture 3 same TheIsland without travel; visible gameplay/input/audio regressions none. `.007` supplies one-process seq/uptime, discovery `1->2->3`, world `1->2->2`, prior discovery `not-applicable/yes/yes`, prior world invalidation `no/yes/no`, every relationship and zero capabilities. | PASS: Gate 2C device verified and closed | Natural menu-to-map replacement invalidated old world-bound identities; same-map repeat retained world generation; Engine/Viewport/World/GWorld/definitions and optional base-class relationships remained valid; pre-host NetDriver remained none; no errors, stale reuse or raw-address leak; `hooks=0 engine_calls=0 mutation=0`. Runtime lifecycle strings remain `map`; visible menu context is external evidence. | [Continuous menu-to-map closure PASS 008](evidence/GATE2C_DEVICE_MENU_MAP_CLOSURE_PASS_008.md) |

The old `.build` paths above are historical and no longer exist in the source
tree. Current outputs use ignored `.artifacts/v2` paths.

Archive note: the historical Gate 2A `.deb` SHA in `V2-G2A-BUILD-006` remains
the original receipt. During Gate 2B packaging its ignored local path was
accidentally regenerated, then restored with the original control and exact
Gate 2A raw dylib payload. Content inspection passes, but the current container
SHA is `46264cbf9471acb4eef9c28a35c25ac74972b91f50ae1dd8761bad514a4194db`,
not the historical byte SHA. The Gate 2A injection dylib and manifest remain at
their recorded hashes.

The first Gate 2C packaging attempt was rejected because stale Gate 2B control
metadata generated the wrong expected path, but Theos had already replaced the
ignored Gate 2B `.3` archive container. The canonical `.3` raw dylib/dSYM/
manifest remain unchanged at their recorded hashes. The archive path was
restored with that exact raw dylib and original metadata and passes inspection;
its current container SHA is `e3054a9e8408ee280dccb802ac203c68202384d9c88ee36d67fd307ab33891fe`,
not the historical `e1147e8f…c8f8`. The immutable build row is not rewritten.

## PLAN-G1.5-SIDELOAD-001 exact protocol

Artifact identity before Sideloadly re-signing:

```text
build ID: gate1.5-diagnostic-ui-20260818.1
dylib: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.1/ServerHostV2.dylib
SHA-256: 780dee2a824b9e37f39a60870e140596be21fa08edbfc6a95e96d063b3f6e48b
dSYM: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.1/ServerHostV2.dylib.dSYM
```

Procedure:

1. Start from a clean application containing no Legacy `ServerHost.dylib` or
   other Server-Host injection. In Sideloadly inject only the exact raw V2 dylib
   above; Sideloadly may re-sign it.
2. Launch the app and wait up to 10 seconds after the first active game window
   for the local V2 diagnostic button.
3. Open `Status`. Capture a screenshot showing build ID, source revision,
   startup/profile/Legacy states and `Hooks 0`, `Engine calls 0`, `Mutation 0`.
4. Open `Logs`, use `Copy logs`, retain the copied text and capture a screenshot.
5. Press `Close`. Confirm the game receives touches outside the now-closed UI
   and that the overlay has no continuing visible/Metal rendering activity.
6. Reopen Logs once to confirm the panel can reopen normally, then close it.
7. Leave the unmodified game at its normal menu for 10 minutes. Enter a normal
   local world without invoking any V2 capability and leave it for 10 minutes.
   Record crashes, exits, visual/audio/input changes or unusual resource use.

PASS requires all of the following:

- one draggable local icon appears and opens the two-tab diagnostic window;
- Status identifies the exact build and shows the expected missing-identity or
  other explicit refusal reason with all three capability counters equal to 0;
- Logs are bounded, structured, copyable and contain no secret or raw address;
- no Host, Client, administration or disabled placeholder control exists;
- touches outside the icon/open panel pass through, and closing the panel stops
  continuous overlay rendering;
- both 10-minute menu and local-world intervals complete without crash/exit or
  visible game behavior regression.

FAIL is any missing icon after the bounded wait, blank/unopenable Status/Logs,
nonzero capability, raw address/secret, extra gameplay control, touch capture
outside the allowed regions, continuing closed overlay rendering, unbounded log,
crash/exit/hang, or visible game regression. Return both screenshots, copied
logs and any Console/crash artifact. Do not start Gate 2 on failure.

## V2 device failure report template

Use this only after an actual V2 raw dylib was executed on a device:

```text
V2 test/protocol ID:
Date/time and timezone:
Input dylib absolute path, pre-injection SHA-256, build ID, dSYM and manifest path:
Archival package path/SHA-256, if present:
Source revision and enabled capabilities:
Host/client hardware, OS/runtime and exact app build:
Map, starting state and network topology:
Exact numbered actions and timing:
Expected result:
Observed result:
Reproducibility (x/y):
V2 logs, console/crash paths and timestamps:
Affected V2 claim/workflow:
Anything that still worked:
```

A failure in an archived Legacy workflow is recorded in the Legacy archive and
does not change this matrix or block V2 unless the user explicitly selects that
Legacy investigation.

## PLAN-G1.5-SIDELOAD-002 exact protocol

Artifact identity before Sideloadly re-signing:

```text
build ID: gate1.5-diagnostic-ui-20260818.2
dylib: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/ServerHostV2.dylib
SHA-256: 4212111d133f961f3b9f1676ab73d87966e82f69e54f0a1ee0feadf17cc58c32
dSYM: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/ServerHostV2.dylib.dSYM
manifest: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate1.5-diagnostic-ui-20260818.2/manifest.txt
```

Procedure:

1. Use a clean application with no Legacy dylib or other Server-Host injection;
   inject only the corrected raw V2 dylib through Sideloadly.
2. Launch and confirm the floating V2 icon appears.
3. Tap the icon once; report whether it visibly changes to its accepted/open
   state.
4. Confirm exactly one of these outcomes: the styled dark cyan/teal Status/Logs
   panel appears, or a UIKit fallback visibly names the failed stage.
5. Capture a screenshot of the panel or fallback. A fallback is useful failure
   evidence, never PASS.
6. If the panel opened, switch between Status and Logs, use `Copy logs`, press
   `Close`, and reopen once with a single tap.
7. Only after open/close/reopen passes, leave the panel closed for two minutes
   at the normal menu and confirm touches pass through with no continuing
   visible overlay rendering. Then spend five minutes in a normal local world
   without invoking any V2 runtime capability and note crashes, exits, input or
   visible behavior changes.
8. Return the screenshot, copied logs, button-change result and any fallback
   stage, Console output or crash artifact. Do not infer device/OS details that
   were not captured.

PASS requires every item below:

- the icon appears, acknowledges one accepted tap, and opens the visible styled
  panel rather than the fallback;
- the panel exposes exactly Status and Logs with usable navigation, readable
  diagnostic values, working `Copy logs` and `Close`;
- Status identifies the exact build and keeps `hooks=0`, `engine_calls=0` and
  `mutation=0`; Logs stay bounded/redacted and contain no raw address;
- touches outside the icon/open panel pass through; Close stops continuous
  rendering; one-tap reopen succeeds cleanly;
- the bounded closed-menu and local-world checks complete without crash, exit,
  hang, touch regression or visible game regression.

FAIL is a missing icon, no accepted-action visual change, no visible panel, any
UIKit fallback, wrong/extra controls, broken navigation/copy/close/reopen,
nonzero capability, raw address/secret, touch capture outside allowed regions,
continuing closed overlay rendering, crash/exit/hang or visible regression.

Execution `V2-G1.5-SIDELOAD-PASS-002` satisfied the functional icon/panel/
Status/Logs/Copy/Close/reopen portion and explicitly did not report the longer
step 7 soak or independent outside-window touch check. Those checks were not
inferred; the user authorized Gate 2A and they are carried below.

## PLAN-G2A-SIDELOAD-001 exact protocol

Use only the final raw artifact and manifest under:

```text
build ID: gate2a-exact-identity-20260818.1
dylib: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate2a-exact-identity-20260818.1/ServerHostV2.dylib
dSYM: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate2a-exact-identity-20260818.1/ServerHostV2.dylib.dSYM
manifest: /Users/grimreaper31/Desktop/Dev/MHGA/Server-Host/packages/v2/injection/gate2a-exact-identity-20260818.1/manifest.txt
```

Procedure:

1. Start from clean ShooterGame 1.10280 with no Legacy/other Server-Host dylib;
   inject only the manifested raw Gate 2A dylib through Sideloadly.
2. Open Status and capture the selected image/product `ShooterGame`, `arm64`,
   UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC`, the five segment sizes, a
   shortened fingerprint beginning `8bfc1fd248a5`, and `exact-match` profile.
3. Confirm Status and copied Logs contain no ASLR slide, pointer, RVA or absolute
   address and show `scans_started=0`, `hooks=0`, `engine_calls=0`, `mutation=0`.
4. Close and reopen once. While the panel is open, operate one ordinary game
   control outside its window and confirm the game receives the touch; Close
   must again stop Metal rendering.
5. With the panel closed, remain at the normal menu for two minutes, then enter
   an ordinary local world for five minutes. Do not invoke any V2 runtime
   capability. Record crash, exit, hang, input/audio/visual or gameplay change.
6. Wrong-profile negative: use the same single dylib against a known non-1.10280
   ShooterGame build. It must report mismatch/refusal with no scan or capability;
   do not substitute a second Gate 2A dylib variant.
7. Return target and mismatch screenshots, copied bounded logs, exact app build/
   device/OS details and any Console/crash artifact.

PASS requires exact profile match on the named target; UUID/fingerprint/segments
visible without addresses; `scans_started=0` and all capability counters zero;
the wrong build fail-closes; panel open/close/reopen and outside-window touch
pass-through work; and the two-minute menu plus five-minute local-world checks
complete without crash or visible game regression.

No Gate 2B name/object scan or Gate 2C relationship is part of this protocol.

Execution produced `V2-G2A-IDENTITY-PASS-001` for the positive exact-target
identity sub-contract and `V2-G2A-DEATH-SIGNAL-EXIT-001` for extended stability.
It did not execute the wrong-profile negative. The signal exit is handled by
the causal protocol below before any Gate 2B work.

## PLAN-G2A-DEATH-CAUSAL-001 exact protocol

Status: closed after arm A. `V2-G2A-DEATH-BASELINE-002` reproduced the symptom
without injection. Arms B/C below are retained only as the immutable original
plan and are not required by user decision.

Purpose: classify the death/respawn signal exit using the existing application
and exact Gate 2A dylib only. Build no replacement, A/B or diagnostic package.
Use the same ShooterGame 1.10280 save/map and character in all arms. Do not log
into EOS and do not run hosting, client travel or any other mod.

### A — baseline without injection

1. Remove every injected ServerHost dylib and fully launch the application.
2. Bring the same character to death.
3. Record whether respawn UI appears, whether the process exits, wall-clock
   time, approximate process uptime, Console tail and any new `.ips`.

### B — exact Gate 2A with UI closed

1. Inject only the existing raw artifact:
   `packages/v2/injection/gate2a-exact-identity-20260818.1/ServerHostV2.dylib`.
2. Open the panel once, verify build ID
   `gate2a-exact-identity-20260818.1`, then close it.
3. Wait at least 30 seconds with the panel closed.
4. Bring the same character to death and capture the same evidence as A.

### C — exact Gate 2A with UI open

1. Fully restart the application with the same Gate 2A dylib injected.
2. Leave the panel open and bring the same character to death.
3. Capture the same evidence as A and B.

Run each arm once. Do not change artifact, save, map, EOS state or other mods
between arms. For each arm report respawn UI yes/no, exit yes/no, exact times,
`GASignalHandler entered` yes/no, Console tail and `.ips` path if one appears.

Interpret exactly as follows:

- A exits at death: strong base-game/EOS/save-path evidence; repeat A once. If
  reproduced, record an external baseline limitation and Gate 2B may continue.
- A and B stable, C exits: open Metal/ImGui presentation path is implicated;
  Gate 2B stays blocked until the UI is fixed.
- A stable, B and C exit: V2 injection/bootstrap/identity delta is implicated;
  define a Gate 1.5 `.2` versus Gate 2A control only after this result.
- A and B exit: ambiguous; repeat baseline A before attribution.
- All three stable: intermittent result; do not patch code without a second
  reproduction.

## PLAN-G2B-DISCOVERY-001 exact protocol

Closed by `V2-G2B-MULTIREGION-DEVICE-PASS-004`. Required menu and TheIsland
captures completed. The optional return-menu capture was not reported and does
not block this scoped PASS.

Use only the single manifested raw artifact under
`packages/v2/injection/gate2b-readonly-contracts-20260818.3/`. Do not inject
Legacy or another mod and do not start hosting, client travel or death/respawn.

1. Launch ShooterGame 1.10280 and open Status in the main menu.
2. Confirm exact profile, UUID/fingerprint/segments, `scans_started=0` and zero
   hooks/engine calls/mutation.
3. Open Contracts and press **Capture read-only contracts** once.
4. Wait for `complete`, copy report/logs and confirm ten known FNames plus nine
   exact core object/function validators pass without any displayed address.
5. Enter an ordinary TheIsland local world and capture again.
6. Confirm discovery generation changed, previous generation is invalidated,
   object count is reported, and hooks/engine calls/mutation remain zero.
7. Return to menu naturally if possible and perform a third capture.
8. If a capture aborts, copy the exact stage-prefixed reason and stop that run.
9. Report any retry, timeout, malformed relationship, crash or UI regression
   with the bounded output and Console tail.

Death/respawn is not a Gate 2B PASS/FAIL condition because the same exit is a
reproduced no-injection baseline limitation. PASS does not authorize Gate 2C or
hosting; it closes only the read-only name/object/reflection snapshot contract.
