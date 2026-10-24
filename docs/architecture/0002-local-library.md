# ADR 0002: Android-owned local library and safe copied imports

Status: accepted storage decision; implementation in progress.
Date: 2026-10-14 (Asia/Phnom_Penh).
Deciders: project owner approved Android SQLite instead of planned Isar in chat.

## Context

The original brief proposes Isar and PE fingerprints. The production architecture
now assigns filesystem work to Android behind Pigeon. Phase 3 needs persistent
local records and imported copies, without integrating a Windows engine or cloud
service. Untrusted filenames, document providers and ZIP bytes must never become
arbitrary filesystem paths, shell commands or executable code.

## Decision

Use Android's built-in SQLiteOpenHelper, with an explicit version-1 schema and
parameterized queries. Store metadata, copied content and recovery workspaces
under `Context.noBackupFilesDir/library-v1`. No new production dependency is needed.
Expose a separate typed Pigeon library API so the runtime API remains unchanged.
The IO worker owns both the file-copy lifecycle and database publication.

Use system-selected folder/document grants and make independent app-private
copies. Do not store source URIs or request broad storage permissions. Sources
are never renamed, overwritten or deleted. Support folders and single-disk ZIP32
archives; encryption, ZIP64, RAR, TAR and 7z are explicitly unsupported here.

Copies are staged beneath a fresh UUID with an ownership marker in a separate
`owners` directory, outside both imported content and removable UUID leaves.
Successful validation precedes rename and database publication. Recovery
removes owned unfinished workspaces and orphan copies; deletion is journaled in
SQLite and touches only an owned UUID leaf. No-follow traversal deletes links
themselves, not their targets. This relies on app-private storage being writable
only by this app; it is not a sandbox for future code executing under the same UID.
Recovery covers process interruption; this is not a power-loss durability promise
for every filesystem rename. Database publication uses a SQLite transaction.

Paths reject traversal, absolute/drive/UNC paths, control characters, Windows
reserved names, trailing dots/spaces and case/Unicode aliases. ZIP metadata is
bounded before opening ZipFile. Declared UNIX links/special files are rejected;
the copier never creates links. Actual streamed sizes and CRC are checked rather
than trusting archive/provider metadata. Import limits are 20,000 entries,
32 levels, 2 GiB per file, 8 GiB expanded data, 4 GiB ZIP input, 200:1 compression,
128 executable candidates, and a 64 MiB free-space reserve. Cooperative work has
a 15-minute deadline. Cancellation closes the current stream off the UI thread;
an uncooperative provider may delay stopping, so cancellation is not claimed as
a hard process-level deadline.

Inspect x86/x86-64 PE headers and hash full executable contents with SHA-256.
Fingerprint the copied file tree for duplicate-import detection. PE structure and
hashes identify candidates; they are not malware, signature or compatibility
checks. Imported content is never executed. A single candidate may be selected
by default; multiple candidates require the user to choose. Runtime launch stays
unavailable in Phase 3.

## Options considered

- Android SQLite: existing SDK, one native owner for recovery and publication;
  Android-specific implementation behind the typed boundary. Chosen.
- Isar / community Isar: fits the original Dart-centric cache proposal, but adds
  a native database binary and code generation, with separate coordination between
  Dart metadata and Android copy/recovery. Deferred rather than silently added.
- A JSON manifest: fewer API calls, but weaker transactional updates, searching,
  schema migration and deletion recovery. Not chosen.

## Threat model and abuse tests

The assets are the user's source files, existing library copies, app-private
records and device storage. Trust boundaries are the system picker result,
provider metadata/streams, ZIP headers/payloads and library mutation requests.
Test traversal/symlinks, path aliases, duplicate entries, parser metadata bounds,
decompression bombs, lying sizes, CRC/truncation, fake PE files, cancellation and
invalid IDs. On-device tests must also cover SQLite persistence, duplicate copies,
publication rollback and recovery, and deletion preserving source files.

## Consequences and action items

- Native code grows, but Flutter receives only typed records and job snapshots.
- Metadata and copies remain offline and outside Android backup. Uninstalling
  the app removes them; originals remain at the source.
- Phase 3 must remain incomplete until native persistence/recovery and the real
  picker/library UI pass device checks. Screenshot limitations from Phase 2 are
  not grounds to claim unobserved visual acceptance.
- Future schema versions require migrations; no destructive upgrade fallback.
- Revisit archive formats/limits and runtime isolation in their own reviewed work.

## References

- [Android document access](https://developer.android.com/training/data-storage/shared/documents-files)
- [Android ZIP traversal guidance](https://developer.android.com/privacy-and-security/risks/zip-path-traversal)
- [SQLiteOpenHelper](https://developer.android.com/reference/android/database/sqlite/SQLiteOpenHelper)
- [Original Isar package](https://pub.dev/packages/isar), [community fork](https://pub.dev/packages/isar_community)
- [Local Android unit tests](https://developer.android.com/training/testing/local-tests)
