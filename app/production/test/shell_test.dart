import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/main.dart';
import 'package:nexus_app/platform/nexus_platform.dart';
import 'package:nexus_app/shell/shell_controller.dart';
import 'foundation_test.dart' show FakeHost, device, unavailable;

class CountingHost extends FakeHost {
  int profiles = 0;
  bool failStatus = false;
  Completer<RuntimeStatus>? pendingStatus;
  @override
  Future<DeviceProfile> getDeviceProfile() {
    profiles++;
    return super.getDeviceProfile();
  }

  @override
  Future<RuntimeStatus> getRuntimeStatus() async {
    if (failStatus) throw PlatformException(code: 'native_error');
    return pendingStatus == null ? unavailable() : await pendingStatus!.future;
  }
}

Future<PigeonNexusPlatform> mountShell(
  WidgetTester tester,
  CountingHost host, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final platform = PigeonNexusPlatform(host: host);
  addTearDown(platform.close);
  await tester.pumpWidget(NexusApp(platform: platform));
  await tester.pumpAndSettle();
  return platform;
}

void main() {
  Future<void> reveal(WidgetTester tester, String text) async {
    final target = find.text(text);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('Your gaming workspace')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('four destinations share one profile and Back returns Home', (
    tester,
  ) async {
    final host = CountingHost();
    await mountShell(tester, host);
    expect(find.text('Your gaming workspace'), findsOneWidget);
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    expect(find.text('No games yet'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Import games · Phase 3'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Device').last);
    await tester.pumpAndSettle();
    expect(find.text('Xiaomi test'), findsOneWidget);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Color theme'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your gaming workspace'), findsOneWidget);
    expect(host.profiles, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab changes preserve independent scroll positions', (
    tester,
  ) async {
    await mountShell(tester, CountingHost(), size: const Size(390, 500));
    Finder scrollable(String title) => find
        .descendant(
          of: find.byKey(PageStorageKey(title)),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(
      scrollable('Your gaming workspace'),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    final homeOffset = tester
        .state<ScrollableState>(scrollable('Your gaming workspace'))
        .position
        .pixels;
    expect(homeOffset, greaterThan(0));
    await tester.tap(find.text('Device').last);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable('Your device')).position.pixels,
      0,
    );
    await tester.drag(scrollable('Your device'), const Offset(0, -150));
    await tester.pumpAndSettle();
    final deviceOffset = tester
        .state<ScrollableState>(scrollable('Your device'))
        .position
        .pixels;
    expect(deviceOffset, greaterThan(0));
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(scrollable('Your gaming workspace'))
          .position
          .pixels,
      closeTo(homeOffset, 0.1),
    );
    await tester.tap(find.text('Device').last);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable('Your device')).position.pixels,
      closeTo(deviceOffset, 0.1),
    );
  });

  testWidgets('appearance changes immediately and survives tab changes', (
    tester,
  ) async {
    final host = CountingHost();
    await mountShell(tester, host);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
    expect(host.profiles, 1);
  });

  testWidgets('profile failure does not hide runtime status; retry recovers', (
    tester,
  ) async {
    final host = CountingHost()..failProfile = true;
    await mountShell(tester, host);
    expect(
      find.text('Could not read this device. Please try again.'),
      findsOneWidget,
    );
    host.failProfile = false;
    await reveal(tester, 'Retry device check');
    await tester.tap(find.text('Retry device check'));
    await tester.pumpAndSettle();
    expect(find.text('Xiaomi test'), findsOneWidget);
    expect(host.profiles, 2);
    await reveal(tester, 'Runtime: unavailable');
    expect(find.text('Runtime: unavailable'), findsOneWidget);
  });

  testWidgets(
    'runtime read failure is unknown, not fabricated unavailability',
    (tester) async {
      final host = CountingHost()..failStatus = true;
      await mountShell(tester, host);
      await reveal(tester, 'Runtime: unknown');
      expect(
        find.text('Could not read runtime status. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Runtime: unavailable'), findsNothing);
      host.failStatus = false;
      await reveal(tester, 'Retry status check');
      await tester.tap(find.text('Retry status check'));
      await tester.pumpAndSettle();
      await reveal(tester, 'Runtime: unavailable');
      expect(find.text('Runtime: unavailable'), findsOneWidget);
    },
  );

  testWidgets('keyboard activation opens the library', (tester) async {
    await mountShell(tester, CountingHost());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('No games yet'), findsOneWidget);
  });

  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('responsive navigation at width $width with 200% text', (
      tester,
    ) async {
      final host = CountingHost();
      await mountShell(tester, host, size: Size(width, 900), scale: 2);
      expect(
        find.byType(width < 600 ? NavigationBar : NavigationRail),
        findsOneWidget,
      );
      for (final label in ['Library', 'Device', 'Settings', 'Home']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      expect(host.profiles, 1);
    });
  }

  testWidgets('compact navigation meets tap-target and labeling guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mountShell(tester, CountingHost());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('landscape rail remains usable with large text', (tester) async {
    await mountShell(
      tester,
      CountingHost(),
      size: const Size(844, 390),
      scale: 2,
    );
    final target = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('Settings'),
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      3,
    );
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<ThemeMode>),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('Settings')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Color theme'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diagnostics returns to Device without resetting tab state', (
    tester,
  ) async {
    final host = CountingHost();
    await mountShell(tester, host);
    await tester.tap(find.text('Device').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Open native diagnostics'),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('Your device')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open native diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Production foundation'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(
      host.profiles,
      2,
    ); // One shell read and one explicit diagnostic read.
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible content meets text contrast guidance in both themes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mountShell(tester, CountingHost());
      for (final theme in ['Light', 'Dark']) {
        await tester.tap(find.text('Settings').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(theme).last);
        await tester.pumpAndSettle();
        for (final page in ['Home', 'Library', 'Device', 'Settings']) {
          await tester.tap(find.text(page).last);
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  test('late refresh cannot overwrite a newer runtime event', () async {
    final host = CountingHost()..pendingStatus = Completer<RuntimeStatus>();
    final platform = PigeonNexusPlatform(host: host);
    final controller = ShellController(platform);
    addTearDown(platform.close);
    addTearDown(controller.dispose);
    final refreshing = controller.refresh();
    final updated = unavailable()..message = 'Newer native status';
    await platform.onRuntimeStatus(updated);
    await Future<void>.delayed(Duration.zero);
    host.pendingStatus!.complete(unavailable());
    await refreshing;
    expect(controller.status?.message, 'Newer native status');
    expect(controller.profile?.ramBytes, device().ramBytes);
  });
}
