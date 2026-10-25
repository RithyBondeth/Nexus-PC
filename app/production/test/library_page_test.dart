import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/library/game_details_page.dart';
import 'package:nexus_app/platform/nexus_platform.dart';
import 'foundation_test.dart' show FakeHost;
import 'package:nexus_app/shell/pages/library_page.dart';
import 'library_fakes.dart';

class EditingLibrary extends FakeLibraryApi {
  int saves = 0;
  int removes = 0;
  Object? failure;
  @override
  Future<GameDetails> getGame(String gameId) async => GameDetails(
    game: records.single,
    executables: [
      ExecutableRecord(
        relativePath: 'game.exe',
        architecture: 'x86_64',
        sha256: 'hash-one',
      ),
      ExecutableRecord(
        relativePath: 'bin/other.exe',
        architecture: 'x86',
        sha256: 'hash-two',
      ),
    ],
  );
  @override
  Future<GameRecord> updateGame(
    String gameId,
    String title,
    String executableRelativePath,
  ) async {
    saves++;
    if (failure != null) throw failure!;
    return records.single
      ..title = title
      ..executableRelativePath = executableRelativePath;
  }

  @override
  Future<void> removeGame(String gameId) async {
    removes++;
    if (failure != null) throw failure!;
    records.clear();
  }
}

class LaunchHost extends FakeHost {
  LaunchRequest? launched;
  int stops = 0;
  RuntimeStatus current = RuntimeStatus(
    state: RuntimeState.idle,
    code: 'experimental',
    message: 'Experimental runtime',
    changedAtMillis: 0,
  );
  @override
  Future<RuntimeStatus> getRuntimeStatus() async => current;
  @override
  Future<RuntimeStatus> launchGame(LaunchRequest request) async {
    launched = request;
    return current = RuntimeStatus(
      state: RuntimeState.running,
      code: 'running',
      message: 'Process requested',
      changedAtMillis: 1,
    );
  }

  @override
  Future<RuntimeStatus> stopGame() async {
    stops++;
    return current = RuntimeStatus(
      state: RuntimeState.idle,
      code: 'stopped',
      message: 'Stopped',
      changedAtMillis: 2,
    );
  }
}

Future<void> mount(
  WidgetTester tester,
  FakeLibraryApi api, {
  double width = 390,
  double scale = 1,
  NexusPlatform? platform,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LibraryPage(api: api, platform: platform),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder pageScrollable() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// Lazily built page sections may sit above the viewport.
Future<void> scrollToTop(WidgetTester tester) async {
  tester.state<ScrollableState>(pageScrollable()).position.jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await scrollToTop(tester);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: pageScrollable(),
      );
    }
  } else {
    await tester.ensureVisible(target.last);
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(target.last);
  await tester.pumpAndSettle();
  await tester.tap(target.last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('native failure stays visible and retry loads the library', (
    tester,
  ) async {
    final api = FakeLibraryApi()
      ..read = (_, _, _) async =>
          throw PlatformException(code: 'channel-error');
    await mount(tester, api);
    expect(find.text('No games yet'), findsNothing);
    expect(find.textContaining('Could not access'), findsOneWidget);
    api.read = null;
    await tapVisible(tester, 'Retry library');
    expect(find.text('No games yet'), findsOneWidget);
  });

  testWidgets(
    'import progress blocks reads and cancellation uses native state',
    (tester) async {
      final api = FakeLibraryApi();
      await mount(tester, api);
      await tester.tap(find.text('Import ZIP'));
      await tester.pump();
      // Let the progress panel finish expanding before tapping inside it.
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.begins, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Import folder'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Cancel import'), findsOneWidget);
      await tester.tap(find.text('Cancel import'));
      await tester.pumpAndSettle();
      expect(api.cancellations, ['job-1']);
      expect(find.text('Native import state: cancelled'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('completion refreshes records and search filters them', (
    tester,
  ) async {
    final api = FakeLibraryApi();
    await mount(tester, api);
    await tester.tap(find.text('Import folder'));
    await tester.pump();
    api.records = [
      libraryGame('one', title: 'First'),
      libraryGame('two', title: 'Second'),
    ];
    api.progress = libraryProgress(ImportState.completed);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Second');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second', findRichText: false).last, findsOneWidget);
  });

  testWidgets(
    'title and selected executable are saved through the native API',
    (tester) async {
      final api = EditingLibrary()..records = [libraryGame('one')];
      await mount(tester, api);
      await tapVisible(tester, 'Test game');
      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('bin/other.exe').last);
      await tester.pumpAndSettle();
      expect(find.text('hash-two'), findsOneWidget);
      await tapVisible(tester, 'Save details');
      expect(api.saves, 1);
      expect(api.records.single.title, 'Renamed');
      expect(api.records.single.executableRelativePath, 'bin/other.exe');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed'), findsOneWidget);
    },
  );

  testWidgets('removal needs confirmation and preserves errors for retry', (
    tester,
  ) async {
    final api = EditingLibrary()..records = [libraryGame('one')];
    await mount(tester, api);
    await tapVisible(tester, 'Test game');
    await tapVisible(tester, 'Remove imported copy');
    await tapVisible(tester, 'Keep game');
    expect(api.removes, 0);
    api.failure = PlatformException(
      code: 'library_storage',
      message: 'Could not remove this copy.',
    );
    await tapVisible(tester, 'Remove imported copy');
    await tapVisible(tester, 'Remove copy');
    expect(find.text('Could not remove this copy.'), findsWidgets);
    expect(api.records, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    api.failure = null;
    await tapVisible(tester, 'Remove imported copy');
    await tapVisible(tester, 'Remove copy');
    expect(find.text('No games yet'), findsOneWidget);
    expect(api.removes, 2);
  });

  testWidgets('view tabs filter the page by setup state', (tester) async {
    final api = FakeLibraryApi()
      ..records = [
        libraryGame('one', title: 'Ready one'),
        libraryGame('two', title: 'Unset two')..executableRelativePath = null,
        libraryGame('three', title: 'Ready three'),
      ];
    await mount(tester, api);
    expect(find.text('All games · 3'), findsOneWidget);
    await tapVisible(tester, 'Needs setup · 1');
    await tester.pumpAndSettle();
    expect(find.text('Unset two'), findsOneWidget);
    expect(find.text('Ready one'), findsNothing);
    await tapVisible(tester, 'Ready · 2');
    await tester.pumpAndSettle();
    expect(find.text('Unset two'), findsNothing);
    expect(find.text('Ready three'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paging renders the last page', (tester) async {
    final api = FakeLibraryApi()
      ..records = List.generate(51, (i) => libraryGame('$i', title: 'Game $i'));
    await mount(tester, api);
    await tester.scrollUntilVisible(
      find.text('Next page'),
      1000,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapVisible(tester, 'Next page');
    await tester.scrollUntilVisible(
      find.text('Game 50'),
      -1000,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Game 50'), findsOneWidget);
  });

  testWidgets(
    'experimental launch uses saved selection and blocks edits until stopped',
    (tester) async {
      final host = LaunchHost();
      final platform = PigeonNexusPlatform(host: host);
      addTearDown(platform.close);
      final api = EditingLibrary()..records = [libraryGame('one')];
      await mount(tester, api, platform: platform);
      await tapVisible(tester, 'Test game');
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>),
        200,
        scrollable: pageScrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('bin/other.exe').last);
      await tester.pumpAndSettle();
      await scrollToTop(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Launch game (experimental)'),
            )
            .onPressed,
        isNull,
      );
      await tapVisible(tester, 'Save details');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Launch game (experimental)');
      expect(host.launched!.gameId, 'one');
      expect(host.launched!.executableRelativePath, 'bin/other.exe');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save details'),
            )
            .onPressed,
        isNull,
      );
      await tapVisible(tester, 'Stop game');
      expect(host.stops, 1);
      await scrollToTop(tester);
      expect(find.text('Stopped'), findsOneWidget);
    },
  );

  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('library and details fit $width with 200% text', (
      tester,
    ) async {
      final api = EditingLibrary()
        ..records = [
          libraryGame(
            'one',
            title: 'A long game title that wraps across several lines',
          ),
        ];
      await mount(tester, api, width: width, scale: 2);
      await tapVisible(tester, api.records.single.title);
      expect(find.byType(GameDetailsPage), findsOneWidget);
      // Drag the page margin so selectable hashes cannot consume the gesture.
      for (
        var i = 0;
        i < 30 && find.text('Remove imported copy').evaluate().isEmpty;
        i++
      ) {
        await tester.dragFrom(
          Offset(width / 2 + (width < 960 ? width : 960) / 2 - 8, 700),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Remove imported copy'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(GameDetailsPage), findsOneWidget);
    });
  }
}
