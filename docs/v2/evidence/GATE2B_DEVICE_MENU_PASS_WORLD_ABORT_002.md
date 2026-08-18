# Gate 2B menu PASS and world VM-region abort 002

```text
PASS result ID: V2-G2B-MENU-CAPTURE-PASS-003
Abort result ID: V2-G2B-WORLD-VM-REGION-ABORT-002
Date: 2026-08-18
Build ID: gate2b-readonly-contracts-20260818.2
Source revision: 739f274c5b01c29703bbc9b34b40ad6a167c24af
Input dylib SHA-256: 56e9ebb0d4453b90e4d63ccfa5431a142d8d94bc42b043b0e45b24e819203a6c
Mach-O / dSYM UUID: F02EC54E-DEB7-35AA-B91C-C868547BCD03
```

## Menu capture — device PASS

The exact ShooterGame 1.10280 profile matched before capture with
`scans_started=0`. One explicit main-menu capture completed at generation 1 in
49 ms and copied 24,675,046 bytes into owned snapshots:

```text
FName blocks / entries: 178 / 390585
Objects num / max: 61171 / 25231360
Chunks num / max: 1 / 385
Valid / null / malformed: 61171 / 0 / 0
Pending / unreachable: 29 / 0
```

All ten required FName round trips passed. All nine exact core class/function
full-name and class-relationship checks passed. The owned UObject `0x28`
metadata validators and UFunction `FunctionFlags +0xB0` check passed.
`NumParms`, `ParmsSize` and `ReturnValueOffset` correctly remained unavailable;
native dispatch was not used. Runtime retained:

```text
scans_started=1
hooks=0
engine_calls=0
mutation=0
```

This is a device PASS for ABI-005, ABI-006 and the bounded ABI-007 subset in a
main-menu snapshot. It also device-validates the `.2` capacity correction:
reserved capacity `25231360 / 385` is accepted while live work remains bounded
to `61171 / 1`. It does not close repeated map-state capture or Gate 2B as a
whole.

## TheIsland capture — immutable fail-closed abort

After entering TheIsland, generation 2 was explicitly requested. The UI marked
the previous generation invalidated, then the capture aborted after 37 ms:

```text
requested bytes are not contained in one readable VM region
```

The aborted report displays zero partial counters because failure discards the
in-progress candidate. Those zeros do not mean the live name pool or object
array was empty. No generation-2 owned snapshot or changed object count is
claimed. The abort retained `scans_started=1` and zero hooks, engine calls and
mutation. The supplied log continues through the bounded report copy at
`uptime_ms=70039` and contains no crash.

## Screenshot receipt

The temporary screenshots available at intake were:

```text
/var/folders/n0/y5h0f9qs3053tyzp2mq0vc040000gn/T/TemporaryItems/NSIRD_screencaptureui_jf6pLF/Снимок экрана — 2026-08-18 в 21.48.21.png
SHA-256: 14c6265948b75ec80c6660418b813645b4a235824d9fc2225001578f8a434b9d
Size: 714x492

/var/folders/n0/y5h0f9qs3053tyzp2mq0vc040000gn/T/TemporaryItems/NSIRD_screencaptureui_rIr0uz/Снимок экрана — 2026-08-18 в 21.48.37.png
SHA-256: a6eb666bce7eb6ce2561f20d9efad4e7d808c98eb3024f6e3ad82f6656bc28c6
Size: 738x304
```

They visibly confirm the `.2` build/source, exact identity card,
`scans_started=1` after the explicit action and zero active capabilities. The
full contract values come from the user-supplied bounded text report, not from
the cropped screenshots.

## Boundary audit and correction

The `.2` error does not include the derived type, so it cannot prove whether a
world-state FName block, FUObjectItem chunk or metadata copy met the VM-region
edge. Source audit does prove the immediate rejection policy: one logical owned
copy was required to fit inside one Mach VM region even when its token extent
continued through adjacent readable regions.

The correction does not permit an unchecked crossing. It:

- retains the exact-profile token extent, overflow and provenance checks;
- walks the requested range through consecutive VM-region queries;
- checks readable permission, representable extent and forward progress for
  every part;
- issues each `vm_read_overwrite` only for bytes inside that one queried
  region;
- rejects gaps, unreadable regions and copy/unmap failures;
- returns the composed owned buffer only after every part succeeds;
- prefixes derived-copy failures with a bounded type name, never an address.

Synthetic tests cover a successful adjacent-readable split plus gap,
non-readable and unmap/copy failures. Normal and UBSan-only suites each pass 290
assertions and the raw-address boundary audit passes. This remains a static
correction until a single replacement artifact completes the same TheIsland
capture. Gate 2C, Engine/World discovery, hooks, UE calls and mutation remain
unstarted.

Replacement receipt: `V2-G2B-MULTIREGION-BUILD-009`, build
`gate2b-readonly-contracts-20260818.3`, source
`852e260d353c9a67a18e5763f358f1242b6e7947`, raw dylib SHA-256
`b5e5f0edf47ebb5b71c0c08d947bd6d186538ea2a9f9bc9722c4076ee0e07829`,
Mach-O/dSYM UUID `48EB7BC3-7222-3F27-8A09-4224B980EF8C`, manifest SHA-256
`29eaa59a1fbe428213c8f75b1b0a6453ab062467ae929f364915857b45cff89e`.
