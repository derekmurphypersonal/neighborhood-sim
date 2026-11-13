# data/historical

Sourced records about the real Linden: streets, parcels, buildings (exteriors), establishments, institutions, timeline events and pattern tables.

**This directory is intentionally empty of records.** Nothing has been verified yet (see `docs/research/FINDINGS.md`).

Rules, enforced by the validator (`game/sim/io/data_validator.gd`):

- Every file is `{"layer": "historical", "records": [...]}`.
- Every record has `provenance` with status `verified`, `probable` or `hypothesis`, and at least one source registered in `docs/research/SOURCES.md` that is not a tertiary source.
- A `hypothesis` states its reasoning.
- Nothing here is ever modified by the running game.
