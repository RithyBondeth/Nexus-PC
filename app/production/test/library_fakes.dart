import 'package:nexus_app/platform/nexus_api.g.dart';

GameRecord libraryGame(String id, {String title = 'Test game'}) => GameRecord(
  id: id,
  title: title,
  contentHash: 'test-tree-hash',
  sizeBytes: 512,
  fileCount: 1,
  importedAtMillis: 1792036800000,
  executableCount: 1,
  executableRelativePath: 'game.exe',
  architecture: 'x86_64',
  sha256: 'test-sha256',
);

ImportProgress libraryProgress(
  ImportState state, {
  String code = 'test',
  String? jobId = 'job-1',
}) => ImportProgress(
  state: state,
  code: code,
  message: 'Native import state: ${state.name}',
  bytesCopied: 512,
  filesCopied: 1,
  jobId: jobId,
);

/// Explicit test fixture only; production never substitutes mock library data.
class FakeLibraryApi extends NexusLibraryApi {
  List<GameRecord> records = [];
  ImportProgress progress = libraryProgress(ImportState.idle, jobId: null);
  Future<LibraryResult> Function(int, int, String)? read;
  Future<ImportProgress> Function()? readProgress;
  Future<void> Function(String)? cancelRequest;
  Object? beginFailure;
  Object? detailFailure;
  Object? updateFailure;
  Object? removeFailure;
  ImportProgress? beginResult;
  final candidates = <String, List<ExecutableRecord>>{};
  final updates = <(String, String, String)>[];
  final removals = <String>[];
  int begins = 0;
  final requests = <(int, int, String)>[];
  final cancellations = <String>[];
  @override
  Future<LibraryResult> listGames(int offset, int limit, String query) async {
    requests.add((offset, limit, query));
    if (read != null) return read!(offset, limit, query);
    final matches = records
        .where((game) => game.title.contains(query))
        .toList();
    return LibraryResult(
      games: matches.skip(offset).take(limit).toList(),
      total: matches.length,
    );
  }

  @override
  Future<ImportProgress> getImportProgress() async =>
      readProgress == null ? progress : await readProgress!();
  @override
  Future<ImportProgress> beginImport(ImportKind kind) async {
    begins++;
    if (beginFailure != null) throw beginFailure!;
    progress =
        beginResult ??
        libraryProgress(ImportState.choosing, jobId: 'job-$begins');
    return progress;
  }

  @override
  Future<void> cancelImport(String jobId) async {
    cancellations.add(jobId);
    if (cancelRequest != null) return cancelRequest!(jobId);
    progress = libraryProgress(ImportState.cancelled, jobId: jobId);
  }

  @override
  Future<GameDetails> getGame(String gameId) async {
    if (detailFailure != null) throw detailFailure!;
    final game = records.singleWhere((record) => record.id == gameId);
    return GameDetails(
      game: game,
      executables:
          candidates[gameId] ??
          [
            ExecutableRecord(
              relativePath: game.executableRelativePath!,
              architecture: game.architecture!,
              sha256: game.sha256!,
            ),
          ],
    );
  }

  @override
  Future<GameRecord> updateGame(
    String gameId,
    String title,
    String executableRelativePath,
  ) async {
    updates.add((gameId, title, executableRelativePath));
    if (updateFailure != null) throw updateFailure!;
    final details = await getGame(gameId);
    final chosen = details.executables.singleWhere(
      (entry) => entry.relativePath == executableRelativePath,
    );
    return details.game
      ..title = title.trim()
      ..executableRelativePath = chosen.relativePath
      ..architecture = chosen.architecture
      ..sha256 = chosen.sha256;
  }

  @override
  Future<void> removeGame(String gameId) async {
    if (removeFailure != null) throw removeFailure!;
    removals.add(gameId);
    records.removeWhere((record) => record.id == gameId);
  }
}
