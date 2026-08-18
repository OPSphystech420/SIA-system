# Server-Host V2 status

The active project is Server-Host V2. The detailed workflow authority is
[`docs/v2/STATUS.md`](docs/v2/STATUS.md).

Gate 1 foundation hardening is complete. Gate 1.5 diagnostic UI/raw Sideloadly
artifact `gate1.5-diagnostic-ui-20260818.1` is
`failed-under-investigation`: the user saw the floating icon, but tapping it
opened no visible panel. The failed raw dylib, dSYM, manifest and archive remain
preserved under `packages/v2`; its compile/static claims still stand while
visible opening is contradicted.

The active correction stays inside Gate 1.5: hierarchy/input/first-frame
instrumentation, visible UIKit failed-stage fallback and a compact styled
Status/Logs panel. Gate 2 has not started. It remains limited to later read-only loaded-image,
FNamePool, GUObjectArray, reflection, Engine and World discovery; hooks,
`ProcessEvent`, hosting, client travel and gameplay mutation remain excluded.

Legacy failure/status material is preserved under
[`docs/v2/archive/legacy/`](docs/v2/archive/legacy/README.md). It is historical
evidence and does not block V2 unless the user explicitly selects a Legacy
investigation.
