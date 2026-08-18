# Server-Host V2 Gate 1.5 diagnostics

This is the separate Server-Host V2 implementation. Gate 1 provides the
portable typed foundation. Gate 1.5 adds a UE-free diagnostic surface for the
actual manual test path: raw dylib injection with Sideloadly.

The iOS dylib contains a bounded structured/redacted logger, immutable
diagnostic snapshots, a scene-safe UIKit floating button and a transparent
Metal/ImGui panel with only `Status` and `Logs`. A missing/unsupported profile or
Legacy guard refusal disables runtime capabilities but does not hide the
diagnostic button. Hooks, engine calls and mutation remain exactly zero.

The corrected Gate 1.5 presentation revalidates and reattaches its active
window/root hierarchy on lifecycle and open requests, puts the overlay above
later game views and the button above the overlay, separates drag from touch-up
and primary actions, and visibly changes the button when an action is accepted.
The first frame is requested explicitly. Bounded stage logs distinguish action,
hierarchy, drawable/descriptor and ImGui submission; a failed first frame shows
a local UIKit status card naming the exact stage instead of becoming a silent
no-op.

The ImGui surface uses a compact dark cyan/teal palette with an ordinary
left-hand Status/Logs navigation rail and right content panel. It imports no
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

`BoundaryAudit.sh` enforces raw/include layering, V2 UI isolation and explicit
source lists. Host-local tests cover the Gate 1 foundation plus logger bounds,
redaction, concurrent addition, immutable snapshots, refusal presentation and
the bounded presentation state machine/first-frame fallback decisions. They are
static evidence, not UIKit/Metal device verification.

Gate 2 remains a later workflow. Gate 1.5 contains no image reader, live UE
discovery, hook, `ProcessEvent`, host/client behavior or gameplay mutation.
