import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexus_app/main.dart';
import 'package:nexus_app/platform/nexus_platform.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('shell navigation and real native data on Android', (
    tester,
  ) async {
    final native = NexusHostApi();
    final profile = await native.getDeviceProfile();
    expect(profile.androidApi, greaterThanOrEqualTo(31));
    expect(profile.targetApi, 36);
    expect(profile.ramBytes, greaterThan(0));
    final runtime = await native.getRuntimeStatus();
    expect(runtime.state, RuntimeState.unavailable);
    await tester.pumpWidget(const NexusApp());
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    expect(find.text('Your gaming workspace'), findsOneWidget);
    await binding.takeScreenshot('home');
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    final library = await NexusLibraryApi().listGames(0, 50, '');
    expect(
      find.text(
        library.games.isEmpty ? 'No games yet' : library.games.first.title,
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Import folder'),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('Import ZIP'), findsOneWidget);
    await binding.takeScreenshot('library');
    await tester.tap(find.text('Device').last);
    await tester.pumpAndSettle();
    expect(find.text(profile.model), findsOneWidget);
    await binding.takeScreenshot('device');
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
    await binding.takeScreenshot('settings');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your gaming workspace'), findsOneWidget);
    binding.reportData ??= {};
    binding.reportData!.addAll({
      'model': profile.model,
      'socModel': profile.socModel,
      'renderer': profile.renderer,
      'androidApi': profile.androidApi,
      'targetApi': profile.targetApi,
      'runtimeState': runtime.state.name,
      'verified': [
        'Home',
        'Library',
        'Device',
        'Settings',
        'Dark theme',
        'Back to Home',
      ],
    });
  });
}
