import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/main.dart';
import 'package:nexus_app/platform/nexus_platform.dart';
import 'package:nexus_app/shell/diagnostic_report.dart';
import 'foundation_test.dart' show FakeHost;
import 'library_fakes.dart';

class LoggingHost extends FakeHost {
  bool failBuild = false;
  @override
  Future<BuildInfo> getBuildInfo() async {
    if (failBuild) throw PlatformException(code: 'native_error');
    return super.getBuildInfo();
  }

  @override
  Future<List<RuntimeLog>> getRecentLogs(int limit) async => [
    RuntimeLog(
      timestampMillis: 0,
      level: LogLevel.warning,
      code: 'runtime_unavailable',
      message: 'Launch rejected',
    ),
  ];
}

Future<PigeonNexusPlatform> mountApp(
  WidgetTester tester,
  FakeHost host, {
  bool restore = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final platform = PigeonNexusPlatform(host: host);
  addTearDown(platform.close);
  await tester.pumpWidget(
    NexusApp(
      platform: platform,
      libraryApi: FakeLibraryApi(),
      restoreAppearance: restore,
    ),
  );
  await tester.pumpAndSettle();
  return platform;
}

Future<void> openSettingsAt(WidgetTester tester, String text) async {
  await tester.tap(find.text('Settings').last);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const PageStorageKey('Settings')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('diagnostic report lists build, device, runtime and logs', () async {
    final platform = PigeonNexusPlatform(host: LoggingHost());
    addTearDown(platform.close);
    final report = await collectDiagnosticReport(
      platform,
      now: DateTime.utc(2026, 10, 24),
    );
    expect(report, contains('Generated: 2026-10-24T00:00:00.000Z'));
    expect(report, contains('Version: 0.3.0 (2)'));
    expect(report, contains('Build: release, commit abc123def456'));
    expect(report, contains('Windows runtime: not included'));
    expect(report, contains('Model: Xiaomi test'));
    expect(report, contains('Graphics: Adreno 840, Vulkan 1.4.295'));
    expect(report, contains('unavailable (runtime_unavailable)'));
    expect(report, contains('WARNING runtime_unavailable: Launch rejected'));
  });

  test('one failing section still produces the rest of the report', () async {
    final platform = PigeonNexusPlatform(
      host: LoggingHost()
        ..failBuild = true
        ..failProfile = true,
    );
    addTearDown(platform.close);
    final report = await collectDiagnosticReport(platform);
    expect(report, contains('## App\nUnavailable:'));
    expect(report, contains('## Device\nUnavailable:'));
    expect(report, contains('Launch rejected'));
  });

  testWidgets('settings shows build details and shares a reviewed report', (
    tester,
  ) async {
    final host = LoggingHost();
    await mountApp(tester, host);
    await openSettingsAt(tester, 'Share diagnostic report');
    expect(find.text('0.3.0 (2)'), findsOneWidget);
    expect(find.text('abc123def456'), findsOneWidget);
    expect(find.text('Not included'), findsOneWidget);
    await tester.tap(find.text('Share diagnostic report'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnostic report'), findsOneWidget);
    expect(host.shared, isEmpty, reason: 'Nothing is sent before review');
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(host.shared.single.$1, 'Nexus-PC diagnostic report');
    expect(host.shared.single.$2, contains('Model: Xiaomi test'));
    expect(find.text('Diagnostic report'), findsNothing);
  });

  testWidgets('missing build details are reported, not invented', (
    tester,
  ) async {
    await mountApp(tester, LoggingHost()..failBuild = true);
    await openSettingsAt(tester, 'Build details are unavailable.');
    expect(find.text('Build details are unavailable.'), findsOneWidget);
  });

  testWidgets('saved theme is restored and new choices are saved', (
    tester,
  ) async {
    final host = FakeHost()..savedAppearance = AppearanceMode.dark;
    await mountApp(tester, host, restore: true);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(host.savedAppearance, AppearanceMode.light);
  });
}
