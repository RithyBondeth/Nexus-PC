import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/library/game_details_screen.dart';
import 'package:nexus_app/platform/nexus_api.g.dart';
import 'library_fakes.dart';

Future<void> mountEditor(
  WidgetTester tester,
  FakeLibraryApi api, {
  Size size = const Size(390, 844),
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.blue, brightness: brightness),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => GameDetailsScreen(api: api, gameId: 'game'),
              ),
            ),
            child: const Text('Open copy'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open copy'));
  await tester.pumpAndSettle();
}

Future<void> editorTap(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('Game details')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'explicit executable choice and a valid title are required before saving',
    (tester) async {
      final game = libraryGame('game')
        ..executableCount = 2
        ..executableRelativePath = null
        ..architecture = null
        ..sha256 = null;
      final api = FakeLibraryApi()..records = [game];
      api.candidates['game'] = [
        ExecutableRecord(
          relativePath: 'game.exe',
          architecture: 'x86_64',
          sha256: 'one',
        ),
        ExecutableRecord(
          relativePath: 'tools/legacy.exe',
          architecture: 'x86',
          sha256: 'two',
        ),
      ];
      await mountEditor(tester, api);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save details'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await editorTap(tester, 'tools/legacy.exe');
      await tester.enterText(find.byType(TextFormField), ' ');
      await editorTap(tester, 'Save details');
      expect(api.updates, isEmpty);
      await tester.enterText(find.byType(TextFormField), ' Renamed ');
      await editorTap(tester, 'Save details');
      expect(api.updates.single, ('game', ' Renamed ', 'tools/legacy.exe'));
      expect(find.text('Details saved.'), findsOneWidget);
    },
  );

  testWidgets('read errors are visible and can be retried', (tester) async {
    final api = FakeLibraryApi()
      ..records = [libraryGame('game')]
      ..detailFailure = PlatformException(
        code: 'library_error',
        message: 'Copy unavailable.',
      );
    await mountEditor(tester, api);
    expect(find.text('Copy unavailable.'), findsOneWidget);
    api.detailFailure = null;
    await editorTap(tester, 'Retry details');
    expect(find.text('Library title'), findsOneWidget);
  });

  testWidgets('a native save failure never shows a saved result', (
    tester,
  ) async {
    final api = FakeLibraryApi()
      ..records = [libraryGame('game')]
      ..updateFailure = PlatformException(
        code: 'executable_changed',
        message: 'Executable changed. Reimport this copy.',
      );
    await mountEditor(tester, api);
    await editorTap(tester, 'Save details');
    expect(
      find.text('Executable changed. Reimport this copy.'),
      findsOneWidget,
    );
    expect(find.text('Details saved.'), findsNothing);
  });

  testWidgets(
    'removal requires confirmation and returns only after native success',
    (tester) async {
      final api = FakeLibraryApi()..records = [libraryGame('game')];
      await mountEditor(tester, api);
      await editorTap(tester, 'Remove imported copy');
      expect(
        find.textContaining('Your source folder or ZIP is not changed.'),
        findsOneWidget,
      );
      await editorTap(tester, 'Keep copy');
      expect(api.removals, isEmpty);
      await editorTap(tester, 'Remove imported copy');
      await editorTap(tester, 'Remove copy');
      expect(api.removals, ['game']);
      expect(find.text('Open copy'), findsOneWidget);
    },
  );

  for (final width in [320.0, 1440.0]) {
    testWidgets('long candidate details fit $width at 200% text', (
      tester,
    ) async {
      final game =
          libraryGame('game', title: List.filled(10, 'Long title').join(' '))
            ..executableRelativePath =
                'bin/${List.filled(30, 'name').join()}.exe'
            ..sha256 = List.filled(64, 'a').join();
      await mountEditor(
        tester,
        FakeLibraryApi()..records = [game],
        size: Size(width, 900),
        scale: 2,
      );
      await editorTap(tester, 'Save details');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('editor controls are accessible in ${brightness.name}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await mountEditor(
        tester,
        FakeLibraryApi()..records = [libraryGame('game')],
        brightness: brightness,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }
}
