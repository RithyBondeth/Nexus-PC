# Phase 3: local library and safe imports

Status: in progress. Library screens and imports are now connected. Emulator
validation passes; physical Xiaomi/HyperOS acceptance remains pending. This phase
is not complete.

The owner approved Android SQLite in place of the planned Isar database. See
[ADR 0002](architecture/0002-local-library.md) for the safety contract, alternatives,
limits and trust model. The review skill keeps implementation in small sequential
PRs: import policy/copier tests, native persistence/picker ownership, Flutter
library state/tests, then screens and end-to-end acceptance. All belong to Phase 3; Phase 4 does not start
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
If import cleanup fails, new imports are blocked until a cold restart can recover
the workspace; repeated retries cannot accumulate more unfinished copies.

On 2026-10-15, all 14 Android integration checks passed on an isolated ARM64
API 37 emulator: single-candidate metadata/hash, reopen persistence, parameterized
literal search, duplicate/source preservation, validated executable/title edits,
changed-executable rejection, no-follow removal, unfinished-stage cleanup,
orphan-rename recovery, transactional rollback, deletion-journal recovery,
tampered-ownership refusal, incomplete unused-marker cleanup, and isolated import
job ownership/cleanup-failure latch checks. The latter fault-injects state through
debug-only reflection, without touching the real singleton or library. The debug-only
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

## Flutter library state

The next reviewable slice adds the UI state controller without yet enabling
imports or changing the shell. It uses the generated native library API directly;
only tests inject fixtures. It reads pages of 50, debounces title searches,
rejects stale list/progress responses, discovers process-owned imports, and polls
only while an import is active. It refreshes on completion and keeps native
failures visible rather than replacing them with an empty library. Cancellation
uses the native job ID and outcome; committing is not cancellable. Disposing UI
state stops its timers, not the Android-owned copy.

Eighteen controller tests cover paging, missing channels, busy-library guards,
overlapping imports, obsolete responses, completion, cancellation, title searches,
deleted last pages, retry, cleanup-pending restrictions, picker failure, debouncing,
and disposal. Regression cases cover an obsolete failed progress read stopping a
new job's polling and inconsistent empty-page metadata causing recursive reads.
That controller slice brought the Flutter suite to 42 tests. The controller is
now wired into production screens as described below; physical acceptance remains
pending.

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

## Library screens and emulator validation (2026-10-20)

The Library uses the native API in production; fixture injection is test-only.
Folder and ZIP buttons open the Android system picker. Native job snapshots drive
visible progress, cancellation, completion and failure messages. Search is
bounded and debounced, with 50-record pages. Returning from the picker or resuming
the app synchronizes the native job. Library reads and detail navigation are
unavailable during active imports. The details screen reads native executable
candidates, requires a selection before saving, shows architecture and SHA-256,
and offers title editing and confirmed removal. Save/removal failures remain
visible and are announced in a snackbar. The ordinary build offers no launch
action. The later opt-in runtime experiment adds launch controls; see
[runtime validation](runtime-emulator.md).

Local validation: static analysis, all 52 Flutter tests, 24 native JVM tests,
Android debug lint, ARM64 debug build and unsigned release compilation passed.
The ten new widget cases cover native errors/retry, progress/cancellation,
completion/search, saving a title and executable, removal confirmation/failure,
paging and layouts at widths 320/768/1024/1440 with 200% text. Selectable hashes
support copying; the narrow-layout test scrolls the page margin past them.

On the existing Pixel_10 ARM64 emulator (Android API 37, 16 KiB pages), all 14
isolated native storage/recovery checks passed again. The normal debug APK was
also tested through the real system pickers using synthetic PE headers, not
playable games:

1. Import a ZIP containing two executable candidates and a text file.
2. Select an executable, save, cold-stop/reopen, and verify the record and selection.
3. Select the identical source folder; verify duplicate rejection and existing record.
4. Add a distinct source text file and import that folder through its read grant.
5. Edit its title, select the second executable and save; verify the list refreshes.
6. Open another picker and back out; verify cancellation publishes no new record.
7. Confirm removal of the folder's imported copy; verify only the ZIP record remains,
   and the original folder/ZIP and executable hashes are unchanged.

Storage report: `docs/evidence/phase-3-emulator-storage.json`. Local visual evidence:
`app/production/build/library-evidence/library.png` (ignored build output), inspected
for the normal populated Library screen. The UI steps above were exercised with
Android UI automation; the native storage script remains the repeatable automated
storage gate. This is emulator evidence, not physical-device or game-compatibility
evidence. Real third-party providers, large imports, hardware interruption behavior,
Xiaomi/HyperOS UI acceptance and final-head CI/review/merge remain outstanding.
The updated `tools/run-shell-device-check.sh emulator-5554` integration run also
passed against the populated native library, including all four tabs, actual
device data, dark theme and Back navigation. Report:
`docs/evidence/phase-3-emulator-shell.json`. Its screenshot outputs are under
`app/production/build/shell-device.4npGDH/`. The normal `lib/main.dart` debug APK
was rebuilt and restored after this integration run.
Release signing and Windows runtime integration are still absent.
