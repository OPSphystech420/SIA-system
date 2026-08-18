# Server-Host V2 Gate 2C live relationships

This is the separate Server-Host V2 implementation. Gate 1 provides the
portable typed foundation. Gate 1.5 added the UE-free Sideloadly diagnostic
surface. Gate 2A added exact Mach-O image/profile identity. Gate 2B added one
explicit bounded capture of names, object items and minimal reflection identity.
Gate 2C adds value-only Engine, GameViewport, World, NetDriver and
NetDriverDefinitions relationships inside a fresh Gate 2B owned snapshot.

The iOS dylib contains a bounded structured/redacted logger, immutable
diagnostic snapshots, a scene-safe UIKit floating button and a transparent
Metal/ImGui panel with `Status`, `Contracts` and `Logs`. A missing/unsupported profile or
Legacy guard or identity mismatch disables later discovery but does not hide
the diagnostic button. Before capture `scans_started=0`; after an explicit
request it is `1`. Hooks, engine calls and mutation remain exactly zero.

The corrected Gate 1.5 presentation revalidates and reattaches its active
window/root hierarchy on lifecycle and open requests, puts the overlay above
later game views and the button above the overlay, separates drag from touch-up
and primary actions, and visibly changes the button when an action is accepted.
The first frame is requested explicitly. Bounded stage logs distinguish action,
hierarchy, drawable/descriptor and ImGui submission; a failed first frame shows
a local UIKit status card naming the exact stage instead of becoming a silent
no-op.

The ImGui surface uses a compact dark cyan/teal palette with an ordinary
left-hand Status/Contracts/Logs navigation rail and right content panel. It imports no
Dragon/Sishen widget, image, font, authentication, network or gameplay code.
Continuous rendering starts only after the first command buffer succeeds and
stops completely on Close; the closed `MTKView` remains hidden and paused.

Build and test only the selected V2 target from the project root:

```sh
make -f SourceV2.mk test boundary-audit
make -f SourceV2.mk ios-package
```

The second command produces two forms from one final dylib:

- archival `.deb` under `packages/v2` for package/content inspection;
- the canonical manual-device handoff at
  `packages/v2/injection/<build-id>/ServerHostV2.dylib`, with matching dSYM and
  `manifest.txt`.

Codex builds and inspects the `.deb`; it does not install it. The raw dylib is
the Sideloadly input. Sideloadly may re-sign it, so the manifest identifies the
pre-injection input by SHA-256 and Mach-O UUID. The manifest also records the
matching dSYM UUID, Git revision, mandatory clean source-tree state and compiler
flags. Packaging refuses a modified source tree.

Host objects live under ignored `.artifacts/v2/host`; iOS Theos state lives
under ignored `.artifacts/v2/ios`. The package uses ID
`com.mhga.serverhost.v2`, declares a conflict with the Legacy package, and the
dylib refuses runtime capabilities when exact `ServerHost.dylib` is already
loaded. No Legacy source, Menu/MenuLoad implementation or `HostingRuntime` is
linked.

`BoundaryAudit.sh` enforces raw/include layering, V2 UI isolation, explicit
source lists and the rule that raw address/ASLR/Mach-O operations stay in
the approved low Bindings boundary. Host-local tests use synthetic Mach-O and
sparse memory buffers for malformed/ambiguous/mismatch, mutation/retry,
unmap/read failure, overflow/permission, relationship, world-generation and
limit cases; they never read arbitrary host-process addresses.

The exact 1.10280 profile uses UUID plus stable segment identity and the full
`__TEXT,__text` SHA-256. `CheckedMemoryReader` can be created only from a unique
exact-match proof. Gate 2B derives heap tokens only from checked root copies,
uses the checked platform copier for owned bytes, double-samples mutable headers and
publishes only an immutable bounded report. Gate 2C first creates that fresh
owned snapshot, then independently cross-checks exact GEngine/GWorld roots and
typed same-snapshot relationships. It never retains a heap pointer between
captures. Hosting has not started. There is no hook, native engine call,
host/client behavior or gameplay mutation.
