import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/platform/nexus_api.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final codec = NexusLibraryApi.pigeonChannelCodec;

  test(
    'library channel preserves 64-bit sizes and unselected candidates',
    () async {
      final game = GameRecord(
        id: 'test-id',
        title: '日本語 game',
        contentHash: 'tree-hash',
        sizeBytes: 8589934592,
        fileCount: 20000,
        importedAtMillis: 1792036800000,
        executableCount: 2,
      );
      final channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.nexus_app.NexusLibraryApi.listGames',
        codec,
      );
      messenger.setMockDecodedMessageHandler(channel, (message) async {
        expect(message, [50, 50, '%_']);
        return [
          LibraryResult(games: [game], total: 51),
        ];
      });
      addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
      final page = await NexusLibraryApi().listGames(50, 50, '%_');
      expect(page.total, 51);
      expect(page.games.single.sizeBytes, 8589934592);
      expect(page.games.single.title, '日本語 game');
      expect(page.games.single.executableRelativePath, isNull);
      final details = GameDetails(
        game: game,
        executables: [
          ExecutableRecord(
            relativePath: 'bin/game.exe',
            architecture: 'x86_64',
            sha256: 'executable-hash',
          ),
        ],
      );
      final decoded =
          codec.decodeMessage(codec.encodeMessage(details))! as GameDetails;
      expect(decoded.executables.single.relativePath, 'bin/game.exe');
      expect(decoded.game.sha256, isNull);
    },
  );

  test('import channel preserves enum states and job identity', () async {
    final channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.nexus_app.NexusLibraryApi.beginImport',
      codec,
    );
    messenger.setMockDecodedMessageHandler(channel, (message) async {
      expect(message, [ImportKind.zip]);
      return [
        ImportProgress(
          state: ImportState.choosing,
          code: 'choosing',
          message: 'Choose a source.',
          bytesCopied: 0,
          filesCopied: 0,
          jobId: 'job-id',
        ),
      ];
    });
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    final progress = await NexusLibraryApi().beginImport(ImportKind.zip);
    expect(progress.state, ImportState.choosing);
    expect(progress.jobId, 'job-id');
    expect(progress.gameId, isNull);
    for (final state in ImportState.values) {
      progress.state = state;
      final decoded =
          codec.decodeMessage(codec.encodeMessage(progress))! as ImportProgress;
      expect(decoded.state, state);
    }
  });

  test('library errors remain structured errors, not empty results', () async {
    final channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.nexus_app.NexusLibraryApi.getGame',
      codec,
    );
    messenger.setMockDecodedMessageHandler(
      channel,
      (message) async => ['game_missing', 'No longer in the library.', null],
    );
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    await expectLater(
      NexusLibraryApi().getGame('removed-id'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'game_missing',
        ),
      ),
    );
  });
}
