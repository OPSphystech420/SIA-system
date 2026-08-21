# External research policy

`Research/` contains manifests only. It is not a production include directory,
is absent from `SourceV2.mk`, and must never become a V2 or Legacy build
dependency.

No Sishen, ProjDragon, SEA, IDA, game, EOS, package or font payload is vendored
here. The reviewed local Sishen tree has no recoverable Git provenance or
license file. ProjDragon has an upstream Git remote, but no license file, and
several relevant local files differ from its recorded `HEAD`. The SEA guide has
neither repository provenance nor a license grant. Those facts are insufficient
to redistribute the inputs, even in a private repository.

[`EXTERNAL_INPUTS.md`](EXTERNAL_INPUTS.md) records the exact local research
subset and fingerprints needed to restore a developer workspace without making
it part of this repository.
