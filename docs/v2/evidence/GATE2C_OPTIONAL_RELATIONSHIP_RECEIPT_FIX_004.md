# Gate 2C `.4` optional relationship receipt correction

Result ID: `V2-G2C-OPTIONAL-RELATIONSHIP-RECEIPT-BUILD-013`

Date recorded: 2026-08-19.

## Trigger and disposition

The exact `.3` TheIsland result
`V2-G2C-MAP-RELATIONSHIPS-PASS-003` proved that the capture internally read and
validated the optional `UWorld::AuthorityGameMode` and `UWorld::GameState`
fields whenever non-null. Its public redacted report, however, published only
NetDriver presence. It therefore could not satisfy the requested device receipt
for optional relationship presence.

This is a presentation/receipt gap, not a new ABI failure. The `.3` relationship
PASS remains immutable and valid for the fields it reported. It is not promoted
to a complete Gate 2C PASS.

## Narrow correction

`.4` copies the already-owned, generation-bound optional-view presence into two
bounded state fields and displays them under `World`:

```text
AuthorityGameMode=present: GameModeBase class validated | none | not-applicable: world=none
GameState=present: GameStateBase class validated | none | not-applicable: world=none
```

No new process-memory read, root, offset, object lookup or cache is introduced.
The strings pass the existing address/credential redaction boundary. No raw
full name, pointer, RVA, slide or heap value enters feature/UI code.

## Static verification

- normal SourceV2 host suite: 399 assertions, 0 failures;
- independent UBSan-only SourceV2 suite: 399 assertions, 0 failures;
- raw/include-layer boundary audit: PASS;
- arm64 iOS compile/link: PASS;
- package metadata/payload/build/source inspection: PASS;
- raw dylib/dSYM UUID match: PASS;
- injection Legacy/gameplay isolation audit: PASS.

The correction adds tests for present/none rendering and redaction of both new
state fields. Existing relationship tests still cover optional null, present and
wrong-class behavior inside the fresh owned snapshot.

## Clean source and artifact receipt

```text
build_id=gate2c-live-relationships-20260819.4
source_revision=4db2599d25350b1eadd9d704afcba2fe76743473
source_tag=v2-gate2c-live-relationships-20260819.4-source
package_version=0.4.3~gate2c.20260819.4
raw_dylib=packages/v2/injection/gate2c-live-relationships-20260819.4/ServerHostV2.dylib
dylib_sha256=95c0fe69f420250e22b850f9fa124859ba545bd0dc27b0effc719d9d5fa94677
macho_dsym_uuid=7CB1B073-D9A5-39E0-BDD3-2638B0618B28
dsym_dwarf_sha256=2d1f7bac4560cae4fbff566702289507d5b7ec25baf5b26565692fafb9d5719b
manifest=packages/v2/injection/gate2c-live-relationships-20260819.4/manifest.txt
manifest_sha256=0a7cd36e23430cc616cfb91608964f60267ca2e1e75f69f9d17c5d677bb99387
archival_deb=packages/v2/com.mhga.serverhost.v2_0.4.3~gate2c.20260819.4_iphoneos-arm.deb
archival_deb_sha256=190ffbb9addb5e1b3a388d5e5cda168042e0df7738c34e1203f4b8259f78bbcb
```

The `.3` raw dylib and archive retain their prior exact hashes. They are
`4b7ddd7cf68cd089c69ca632415ec0a56594e49f60be0dccabc438dd471e2ae3`
for the raw dylib and
`18d4dd6dab7d02325d4e2ce3f513cf1cbe0403d7263424669b2a5bcae674e8f6`
for the archive. No old package was rebuilt.

## Required `.4` device protocol

Use only the `.4` raw dylib above for the remaining Gate 2C evidence:

1. Start in the main menu and Capture once.
2. Confirm Engine/Viewport/definitions, the reported lifecycle and both
   optional-presence rows. If World is absent, each row must say
   `not-applicable: world=none`.
3. Enter ordinary TheIsland and Capture.
4. Confirm live World, `GWorld/ViewportWorld=match`, NetDriver state and explicit
   AuthorityGameMode/GameState presence/validated-class state.
5. Confirm a world-generation transition and prior-world invalidation when the
   validated world identity changes.
6. Capture again in the same TheIsland world. Discovery generation advances;
   world generation does not; previous-world-invalidated remains no.
7. If naturally possible, return to menu and Capture once more. Record the
   actual lifecycle/root state without assuming null.
8. In every capture confirm `hooks=0 engine_calls=0 mutation=0`.

Death/respawn is not PASS/FAIL. Gate 3, Host research, hosting, travel, hooks,
GetNetMode policy, calls and mutation remain closed.
