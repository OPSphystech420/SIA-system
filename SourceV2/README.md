# Server-Host V2 Gate 1 foundation

This tree is the separate Server-Host V2 implementation. Gate 1 is deliberately
host-local and inert: it contains portable values, curated UE layout evidence,
safe borrowed views, reflection descriptors, strict profile validation and
tests. The optional iOS package adds a one-shot inert entry that reports its
fail-closed profile state to the device console. It contains no hooks, native
engine calls, `ProcessEvent`, hosting, client travel, save, administration, UI,
or legacy runtime linkage.

Build and run only the selected V2 target from the project root:

```sh
make -f SourceV2.mk clean
make -f SourceV2.mk all test boundary-audit
make -f SourceV2.mk ios-package
```

Host objects and dependency files live under ignored `.artifacts/v2/host`; iOS
Theos state lives under ignored `.artifacts/v2/ios`. The package uses the
separate ID `com.mhga.serverhost.v2`, writes only to `packages/v2`, declares a
conflict with `com.mhga.serverhost`, and refuses startup if the exact Legacy
`ServerHost.dylib` is loaded. Packaging requires a clean Server-Host Git
revision, inspects the payload, and writes a read-only SHA-addressed manifest
next to the package.

`BoundaryAudit.sh` is a regex/include-layer boundary check, not live dependency
or runtime validation. The original 56 host-local foundation assertions remain;
additional guard assertions are also host-local. The curated layout assertions
compile in both the host and iOS V2 targets.

`OwnedFString` is portable host ownership only and cannot be transferred to UE.
The real iOS 1.10280 profile intentionally fails closed because its loaded
Mach-O UUID, image size and text fingerprint are Gate 2 evidence. The current
FreshSDK does not expose the `FUObjectItem` serial offset or raw
`UFunction::NumParms`/`ParmsSize` offsets, so Gate 1 validates those semantics
through snapshots/descriptors rather than inventing live memory access.

Gate 2 is a later, separate workflow. No image reader, live UE discovery, hook,
`ProcessEvent`, host/client behavior or gameplay mutation is added by this
foundation target.
