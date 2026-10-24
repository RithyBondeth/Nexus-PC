import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/library/library_controller.dart';
import 'package:nexus_app/platform/nexus_api.g.dart';
import 'library_fakes.dart';

void main() {
  late FakeLibraryApi api;
  late LibraryController controller;
  setUp(() {
    api = FakeLibraryApi();
    controller = LibraryController(api);
  });
  tearDown(() => controller.dispose());

  test('loads a bounded page from the real API boundary', () async {
    api.records = List.generate(51, (i) => libraryGame('$i'));
    await controller.synchronize();
    expect(controller.games.length, 50);
    expect(controller.total, 51);
    expect(api.requests.single, (0, 50, ''));
    await controller.load(pageOffset: 50);
    expect(controller.games.single.id, '50');
  });

  test('channel failure is an error, not a fabricated empty library', () async {
    api.read = (_, _, _) async =>
        throw PlatformException(code: 'channel-error');
    await controller.synchronize();
    expect(controller.error, contains('Could not access'));
    expect(controller.initialized, false);
    expect(controller.loading, false);
  });

  test(
    'rediscovers Android-owned work without reading a busy library',
    () async {
      api.progress = libraryProgress(ImportState.copying);
      await controller.synchronize();
      expect(controller.busy, true);
      expect(controller.canCancel, true);
      expect(api.requests, isEmpty);
    },
  );

  test(
    'begin prevents double imports and invalidates a pending list',
    () async {
      final pending = Completer<LibraryResult>();
      api.read = (_, _, _) => pending.future;
      final reading = controller.load();
      await controller.begin(ImportKind.folder);
      await controller.begin(ImportKind.zip);
      pending.complete(LibraryResult(games: [libraryGame('stale')], total: 1));
      await reading;
      expect(api.begins, 1);
      expect(controller.games, isEmpty);
      expect(controller.busy, true);
      expect(controller.loading, false);
    },
  );

  test('obsolete progress cannot overwrite a newer import', () async {
    final pending = Completer<ImportProgress>();
    api.readProgress = () => pending.future;
    final syncing = controller.synchronize();
    await controller.begin(ImportKind.zip);
    pending.complete(libraryProgress(ImportState.idle));
    await syncing;
    expect(controller.progress!.state, ImportState.choosing);
    expect(controller.progress!.jobId, 'job-1');
  });

  test(
    'completion reloads once and does not fabricate a playable runtime',
    () async {
      await controller.synchronize();
      await controller.begin(ImportKind.zip);
      api.records = [libraryGame('new')];
      api.progress = libraryProgress(ImportState.completed);
      await controller.synchronize();
      expect(controller.games.single.id, 'new');
      expect(api.requests.length, 2);
      await controller.synchronize();
      expect(api.requests.length, 2);
      expect(controller.busy, false);
    },
  );

  test('cancellation uses the current native job and native outcome', () async {
    await controller.synchronize();
    await controller.begin(ImportKind.folder);
    await controller.cancel();
    expect(api.cancellations, ['job-1']);
    expect(controller.progress!.state, ImportState.cancelled);
    expect(controller.canImport, true);
    api.progress = libraryProgress(ImportState.committing);
    await controller.synchronize();
    await controller.cancel();
    expect(api.cancellations.length, 1);
    expect(controller.canCancel, false);
  });

  test(
    'a stale cancellation failure cannot overwrite a newer import',
    () async {
      final pending = Completer<void>();
      api.cancelRequest = (_) => pending.future;
      await controller.begin(ImportKind.folder);
      final cancelling = controller.cancel();
      api.progress = libraryProgress(ImportState.cancelled);
      await controller.synchronize();
      await controller.begin(ImportKind.zip);
      pending.completeError(
        PlatformException(code: 'invalid_job', message: 'Old job'),
      );
      await cancelling;
      expect(controller.progress!.jobId, 'job-2');
      expect(controller.error, isNull);
      expect(controller.cancelling, false);
    },
  );

  test('a late search response cannot overwrite the newest search', () async {
    final old = Completer<LibraryResult>();
    api.read = (_, _, query) async => query == 'old'
        ? await old.future
        : LibraryResult(games: [libraryGame('new')], total: 1);
    controller.search('old');
    final oldRead = controller.load();
    controller.search('new');
    await controller.load();
    old.complete(LibraryResult(games: [libraryGame('old')], total: 1));
    await oldRead;
    expect(controller.games.single.id, 'new');
    expect(controller.query, 'new');
  });

  test('removal of a last-page entry returns to a valid page', () async {
    api.records = List.generate(51, (i) => libraryGame('$i'));
    await controller.load(pageOffset: 50);
    api.records = [libraryGame('0')];
    await controller.load();
    expect(controller.offset, 0);
    expect(controller.games.single.id, '0');
    expect(controller.loading, false);
  });

  test('progress errors preserve records and a retry reloads', () async {
    api.records = [libraryGame('saved')];
    await controller.synchronize();
    api.readProgress = () async =>
        throw PlatformException(code: 'channel-error');
    await controller.synchronize(reload: true);
    expect(controller.games.single.id, 'saved');
    expect(controller.error, isNotNull);
    api.readProgress = null;
    await controller.synchronize(reload: true);
    expect(controller.error, isNull);
    expect(controller.games.single.id, 'saved');
  });

  test('cleanup failure blocks new import attempts until restart', () async {
    api.progress = libraryProgress(ImportState.failed, code: 'cleanup_pending');
    await controller.synchronize();
    await controller.begin(ImportKind.folder);
    expect(controller.canImport, false);
    expect(api.begins, 0);
  });

  test(
    'a progress retry also retries a failed initialized library read',
    () async {
      api.records = [libraryGame('saved')];
      await controller.synchronize();
      api.read = (_, _, _) async =>
          throw PlatformException(code: 'channel-error');
      await controller.load();
      expect(controller.error, isNotNull);
      api.read = null;
      await controller.synchronize();
      expect(api.requests.length, 3);
      expect(controller.error, isNull);
      expect(controller.games.single.id, 'saved');
    },
  );

  test(
    'picker command failure is visible and never reports completion',
    () async {
      api.beginFailure = PlatformException(code: 'channel-error');
      await controller.begin(ImportKind.zip);
      expect(controller.starting, false);
      expect(controller.progress, isNull);
      expect(controller.error, isNotNull);
    },
  );

  testWidgets(
    'an obsolete failed progress read cannot stop polling a new job',
    (tester) async {
      final pending = Completer<ImportProgress>();
      api.readProgress = () => pending.future;
      final syncing = controller.synchronize();
      await controller.begin(ImportKind.folder);
      await tester.pump(const Duration(milliseconds: 500));
      pending.completeError(PlatformException(code: 'channel-error'));
      await syncing;
      api.readProgress = null;
      api.records = [libraryGame('imported')];
      api.progress = libraryProgress(ImportState.completed);
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.games.single.id, 'imported');
      expect(controller.error, isNull);
    },
  );

  test(
    'inconsistent empty last-page metadata cannot cause recursive reads',
    () async {
      api.read = (_, _, _) async => LibraryResult(games: [], total: 51);
      await controller.load(pageOffset: 50);
      expect(api.requests.length, 2);
      expect(controller.offset, 0);
      expect(controller.loading, false);
    },
  );

  testWidgets('search is debounced to the latest text', (tester) async {
    controller.search('a');
    controller.search('ab');
    controller.search('abc');
    await tester.pump(const Duration(milliseconds: 299));
    expect(api.requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(api.requests.single, (0, 50, 'abc'));
  });

  test(
    'disposing ignores late responses without cancelling native work',
    () async {
      final pending = Completer<LibraryResult>();
      api.read = (_, _, _) => pending.future;
      final reading = controller.load();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      pending.complete(LibraryResult(games: [libraryGame('late')], total: 1));
      await reading;
      expect(notifications, 0);
      expect(api.cancellations, isEmpty);
      // Replace the disposed fixture so tearDown owns exactly one live controller.
      controller = LibraryController(api);
    },
  );
}
