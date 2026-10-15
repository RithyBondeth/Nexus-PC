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

## Native persistence and picker ownership

The second slice adds the SQLite schema, paged literal-title search, validated
metadata edits, duplicate rejection, staged publication and deletion recovery.
A process-lifetime IO worker serializes operations and exposes typed progress
through a separate Pigeon API. It owns picker-returned read grants, never persists
source URIs, and keeps copying/SQLite off the UI thread. Replacing the Flutter
engine does not create another recovery worker. Closing an outstanding picker
owner cancels that selection; a running copy stays with the process. Keep the app
open: there is no foreground service or resumable background-import claim.
Cancellation during copying is cooperative; publication itself is non-cancellable.
Library reads/edits are rejected as busy while an import is active.

On 2026-10-15, all 13 Android integration checks passed on an isolated ARM64
API 37 emulator: single-candidate metadata/hash, reopen persistence, parameterized
literal search, duplicate/source preservation, validated executable/title edits,
changed-executable rejection, no-follow removal, unfinished-stage cleanup,
orphan-rename recovery, transactional rollback, deletion-journal recovery,
tampered-ownership refusal, and incomplete unused-marker cleanup. The debug-only
harness uses a fresh private sandbox, never the real library, and does not ship
in release builds. Fixtures are synthetic headers, not playable games.

Reproduce after building the production debug ARM64 APK:

```sh
ADB=/path/to/adb bash tools/run-library-storage-check.sh EXPLICIT_DEVICE_SERIAL
```

The script installs the debug APK and launches only the isolated harness on the
explicit device. It requires a fresh matching report nonce; stale success cannot
satisfy the check. Three additional Flutter tests cover library DTO/channel sizes,
nullable candidate selection, import states and native errors. The real picker
flow, provider behavior, library UI and physical Xiaomi/HyperOS checks are still
pending. The owner's phone was busy; it was not connected or interrupted for these
checks. User imports remain disabled until the next UI slice.

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
