# Gate 2C `.2` Engine full-name abort 002

Report ID: `V2-G2C-ENGINE-FULLNAME-ABORT-002`

Workflow / ABI backlog IDs: Gate 2C, ABI-009, ABI-010

Date: 2026-08-18

Exact platform and build identity: ShooterGame iOS 1.10280, arm64,
LC_UUID `E52A980C-9C36-34C7-84B0-DD6E846328DC`

Device artifact: `gate2c-live-relationships-20260818.2`

Source revision: `4a53ab940e8085c2e13c00489b4ab6ab9e95764c`

Raw input dylib SHA-256:
`ee6f6d9014fa98171a105fa009750e4d078a099a8ecf4a969dce98c704b60cae`

Exact database:
`/Users/grimreaper31/Desktop/Dev/MHGA/Extra_For_Host/110280.i64`

FreshSDK:
`Reference/FreshSDK/4.26.2-0+++UE4+Release-4.26-ShooterGame/`

Closest source:
`/Users/grimreaper31/Desktop/Dev/extra/engines/UE4.17`

Claim status before: corrected direct-UClass lookup was statically validated;
live relationships remained unverified.

Claim status after: `.2` live relationship capture is contradicted. It refined
the failure to the Engine instance full-name predicate, but did not reach the
direct-UClass, ancestry, Engine field or other relationship reads.

## Device observation

The user ran the exact `.2` artifact in an ordinary local TheIsland world. The
fresh Gate 2B prerequisite snapshot completed and every named validator passed:

```text
Capture=aborted
Relationship capture=aborted
Profile roots=exact-profile-rva-roots
Lifecycle=unavailable
Previous invalidated=not applicable
FName blocks / entries=180 / 399365
Objects num / max=107279 / 25231360
Chunks num / max=2 / 385
Valid / null / malformed=107279 / 0 / 0
Pending / unreachable=9 / 0
Copied bytes / duration ms=26050080 / 46
Retry / abort=native Engine full name is not ShooterEngine Transient.ShooterEngine_<number>
Generation discovery / world=1 / 0
Relationship bytes / duration ms=0 / 0
hooks=0 engine_calls=0 mutation=0
```

All ten required FName round trips, all nine core object/function validators,
the owned `UObject` metadata layout and `UFunction::FunctionFlags` checks passed.
Function parameter ABI remained unavailable and native dispatch remained
unused. No Engine, Viewport, World, NetDriver or NetDriverDefinitions value was
accepted.

The bounded logs show one explicit capture request at uptime 41336 ms and a
fail-closed abort at 41384 ms. The UI opened and presented normally and copied
the bounded report. There was no reported crash.

## Classification

This is an immutable Gate 2C FAIL, not a partial relationship PASS. The `.2`
split diagnostic establishes that the native GEngine root resolved to a fresh
live object whose runtime class name was exactly `ShooterEngine`; otherwise the
preceding class-name error would have fired. In `.2` ordering, however, the
full-name predicate ran before CDO, exact direct-UClass and ancestry checks.
Those later predicates are therefore not device-proven by this attempt.

The result preserves the important negative properties: the candidate was
discarded, world generation remained zero, no relationship handle was
published, and hooks, engine calls and mutation stayed zero.

## Evidence review and bounded correction

FreshSDK's exact dump records both:

```text
Package Transient
ShooterEngine Transient.ShooterEngine_2147482613
```

Its generated `UObject::GetFullName` walks typed `Outer` links and composes the
outer names. Crucially, the same generated `FName::ToString` selects the text
after the final `/`, so raw `/Engine/Transient` is presented as `Transient` in
the dump. Exact IDA shows the GEngine construction path storing the newly
constructed object into the inline pointer slot at RVA `0x5DB8CF0`; its
construction parameters use the transient-package owner and `NAME_None`, so a
generated ShooterEngine instance name is expected. UE 4.17 separately creates
the transient package using `/Engine/Transient`. These sources support one
narrow canonicalization: the exact package-path spelling `/Engine/Transient`
is the same transient owner label used as `Transient` in the required dump
full-name shape.

The `.3` correction does not weaken the required identity. It:

- accepts only the exact transient owner spellings `Transient` and
  `/Engine/Transient`, canonicalizing the latter to `Transient`;
- still requires runtime class `ShooterEngine`, non-CDO, exact direct
  `Class ShooterGame.ShooterEngine`, and GameEngine/Engine ancestry;
- moves the instance full-name predicate after those class checks;
- still requires `ShooterEngine Transient.ShooterEngine_<digits>`;
- if the predicate still fails, emits only bounded printable name components,
  never a pointer, RVA or ASLR value.

An unnumbered `ShooterEngine Transient.ShooterEngine` fixture remains rejected.
A `/Engine/Transient` owner fixture canonicalizes to the exact required full
name. No relationship offset, root or runtime capability changes.

The correction is packaged as clean receipt
`V2-G2C-ENGINE-FULLNAME-FIX-BUILD-012`: source
`f4598395efeadcd882af5f257b1e6d72a78de6d3`, tag
`v2-gate2c-live-relationships-20260818.3-source`, raw dylib SHA-256
`4b7ddd7cf68cd089c69ca632415ec0a56594e49f60be0dccabc438dd471e2ae3`,
UUID `78EAF0B0-9C08-39BE-B37B-25E4A8EC7629`, and manifest SHA-256
`a821b4a88a8228b1f3b81d4c00da063b7103aa2ca35854ec24f95d369bc6749b`.

## Preserved limitations

- Gate 2C remains open and no live relationship is device-proven.
- The `.1` direct-UClass-index abort and this `.2` full-name abort remain
  separate immutable results.
- Return-to-menu capture and longer soak are not claimed.
- `Class Engine.World` is reflection metadata, not a live UWorld.
- Parameter ABI and native dispatch remain unavailable.
- Gate 3, hosting, travel, hooks, calls and mutation remain closed.
