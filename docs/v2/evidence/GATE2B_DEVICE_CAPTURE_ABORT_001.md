# Gate 2B device capture abort 001

```text
Result ID: V2-G2B-CAPTURE-ABORT-001
Date: 2026-08-18
Build ID: gate2b-readonly-contracts-20260818.1
Source revision: ff9637b34b308117208555482c5a8a872c8b94c9
Input dylib SHA-256: e7f6c3c932c2af759547d69b46359b2e1004c51dbd5f2f5a7c9fbd25729afb79
Classification: deterministic fail-closed object-header rejection
```

## Device receipt

The exact image/profile matched ShooterGame 1.10280 with UUID
`E52A980C-9C36-34C7-84B0-DD6E846328DC`, expected segment sizes and shortened
fingerprint `8bfc1fd248a5...`. Before capture, `scans_started=0`. The panel opened,
closed, reopened and presented Metal/ImGui frames normally; Close stopped Metal
rendering and bounded Copy logs worked.

Three explicit captures were accepted at generations 1, 2 and 3. Each aborted
within 47, 39 and 38 milliseconds respectively with:

```text
invalid TUObjectArray num/max/chunk relationship
```

The failure remained fail-closed:

```text
scans_started=1
hooks=0
engine_calls=0
mutation=0
```

No name/object/reflection PASS is inferred. The `.1` error path discarded the
partial capture report, so its displayed zero FName/object counters do not prove
an empty runtime pool or object array. The supplied transcript continues through
`uptime_ms=260014`; it does not contain a crash report.

Temporary screenshots were available at intake:

```text
/var/folders/n0/y5h0f9qs3053tyzp2mq0vc040000gn/T/TemporaryItems/NSIRD_screencaptureui_Zpo3X7/Снимок экрана — 2026-08-18 в 21.22.46.png
SHA-256 cf9e0cf6d20383aa32e1c6e7fe0c91ed044f9adf704b37831ecfd12436cb0392
748x580

/var/folders/n0/y5h0f9qs3053tyzp2mq0vc040000gn/T/TemporaryItems/NSIRD_screencaptureui_EsHP9Z/Снимок экрана — 2026-08-18 в 21.23.00.png
SHA-256 ea0bb3d97b2939d4d815fb1035d892022d482873ddadf362e37870a24f62deed
732x450
```

They visibly confirm the `.1` build/source identity, exact profile card,
`scans_started=1` after the explicit action, and zero capability counters.

## Source and exact-binary audit

The direct root remains correct. Exact IDA lookup data flow uses the pointer
table at direct root `+0x0`, `NumElements` at `+0x14`, 65536 items per chunk and
24-byte items. FreshSDK independently records `MaxElements +0x10`,
`NumElements +0x14`, `MaxChunks +0x18` and `NumChunks +0x1C`.

The `.1` validator conflated two different concepts:

- live `NumElements`/`NumChunks`, which bound work and copied bytes;
- reserved `MaxElements`/`MaxChunks`, which describe capacity but are not copied.

It applied the operational `maximumObjectChunks=128` limit to both `NumChunks`
and `MaxChunks`, and separately rejected any `MaxElements > 4,000,000`. Neither
arbitrary capacity ceiling was part of ABI-006. Because `.1` emitted one generic
reason, the transcript cannot prove which capacity comparison fired.

## Corrective contract

The replacement keeps `NumElements`, allocated `NumChunks`, total bytes and
duration bounded. Reserved capacity is instead checked semantically:

- non-negative ordered `num <= max` and `num_chunks <= max_chunks`;
- enough allocated chunks for current objects;
- enough reserved chunks for reserved elements;
- `MaxChunks` remains inside the complete signed 32-bit index domain;
- pointer table and item chunks are copied only for the live bounded range.

All rejection reasons now include only the four integer counters and the named
limit/relationship; no pointer, address or ASLR value is exposed. A repeat on
the single replacement artifact is required. The correction passes 280 normal
and 280 UBSan-only assertions, the boundary audit and iOS arm64 compile. Gate 2C
and hosting remain unstarted.
