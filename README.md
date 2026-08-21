# Server-Host V2

Server-Host V2 is the separate, evidence-backed iOS architecture for an
in-process ShooterGame 1.10280 host/client integration layer. The repository
preserves the complete tracked Server-Host source and its Legacy regression
material, but V2 is built from the explicit `SourceV2.mk` source lists and does
not link the Legacy runtime.

## Current state

Gate 2C is device verified and closed by
`V2-G2C-CONTINUOUS-MENU-MAP-DEVICE-PASS-008`. Gate 3 is unblocked but has not
started. Its next authorized unit is Gate 3A, evidence-only research for the
current `FIOSAsyncTask` scheduler contract (`ABI-015`); this repository does not
claim that a dispatcher, hosting, travel, save or administration workflow is
implemented or verified.

Start every task with [`docs/v2/README.md`](docs/v2/README.md) and follow its
mandatory reading order. The detailed active authority is
[`docs/v2/STATUS.md`](docs/v2/STATUS.md); [`STATUS.md`](STATUS.md) is the short
entry point.

## Host-local verification

From the repository root:

```sh
make -f SourceV2.mk serverhost_v2_core_tests
make -f SourceV2.mk test
make -f SourceV2.mk boundary-audit
```

The optional iOS packaging entry point is `make -f SourceV2.mk ios-package` in
a correctly configured local Theos environment. It first runs the V2 host tests
and boundary audit and requires a clean committed tree. Package, dSYM and raw
injection outputs are intentionally ignored and are not repository content.
Do not use the Legacy root `make clean all` as a V2 verification command.

## Manual iOS test path

The canonical manual test input is the locally produced raw
`packages/v2/injection/<build-id>/ServerHostV2.dylib`, with its sibling dSYM and
pre-injection manifest. Inject only that raw dylib into a clean application with
Sideloadly; Sideloadly may re-sign it. The `.deb` is an archival/package-
inspection output and is not installed by this workflow.

## External evidence and portability limits

IDA databases, decrypted applications, game/EOS binaries, packages and signing
material are intentionally absent. Sishen, ProjDragon and SEA inputs also
remain external because their local license/provenance does not authorize
copying them into this repository. Exact expected paths, sizes, SHA-256 values,
path mappings and purposes are recorded in
[`Research/EXTERNAL_INPUTS.md`](Research/EXTERNAL_INPUTS.md).

Android/emulator/VPS work remains deferred until the ordered iOS gates pass and
the exact Android binary/database authority is supplied. This repository is the
portable buildable Server-Host source plus its existing tracked evidence—not a
copy of the wider MHGA workspace.
