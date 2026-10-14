# Phase 3: local library and safe imports

Status: in progress. This phase is not complete and the Phase 2 UI still disables import.

The owner approved Android SQLite in place of the planned Isar database. See
[ADR 0002](architecture/0002-local-library.md) for the safety contract, alternatives,
limits and trust model. The review skill keeps implementation in small sequential
PRs: import policy/copier tests, native persistence/picker ownership, then library
screens and end-to-end acceptance. All belong to Phase 3; Phase 4 does not start
until they are merged and the full gate passes.

## Safety primitives

The first slice adds bounded streaming file/ZIP copies into empty private
directories, canonical path and filename-alias validation, bounded ZIP32 metadata
preflight, CRC/actual-size checks, cooperative cancellation, PE candidate inspection
and SHA-256 executable/tree fingerprints. These primitives do not yet enable user
imports or claim a complete persistent library.

The 24 local JVM tests use tiny synthetic PE structures as parser fixtures, not
Windows games. They test unsafe names, depth/length limits, symlink containment,
duplicate/case/Unicode aliases, file-directory conflicts, byte/entry/candidate
bounds, fake/truncated/unsupported PE headers, cancellation, folder/ZIP fingerprint
equivalence, corrupt archives, CRC checks, ZIP encryption/ZIP64/link rejection,
metadata bounds and compression-ratio rejection.

Run with the project's JDK 17, from `app/production/android`:

```sh
JAVA_HOME=/path/to/jdk17 ./gradlew testDebugUnitTest lintDebug
```

JUnit 4.13.2 (EPL-1.0) and transitive Hamcrest are pinned test-only dependencies;
they do not ship in the app. OSV lookups on 2026-10-14 found no known advisories
for those exact test dependencies; this is not a proof against supply-chain risk.
All existing Flutter/bridge/build/lint/release gates
remain; CI now additionally runs the native unit tests. The unchanged toolchain
advisories documented in earlier phases remain separate from this feature.

## Remaining full-phase acceptance

- [ ] Persistent, paged/searchable SQLite records survive cold restart.
- [ ] Real system folder and ZIP pickers grant only selected source access.
- [ ] Visible import progress/cancellation; failure leaves no published partial game.
- [ ] Executable choice, title editing and SHA-256 details are honest and validated.
- [ ] Identical imports are rejected without changing existing copies.
- [ ] Confirmed removal deletes only the imported copy, never its source.
- [ ] Recovery handles interruption/publication/deletion safely.
- [ ] Accessible responsive loading/error/empty/populated library UI.
- [ ] Physical Xiaomi checks and final-head CI/review pass; normal APK is restored.
- [ ] Final Phase 3 PRs are merged into develop before Phase 4 begins.
