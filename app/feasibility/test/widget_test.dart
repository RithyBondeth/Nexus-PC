import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_probe/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nexuspc/feasibility');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets('displays device evidence returned by Android', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => {'hardware': 'test-board', 'ramBytes': 1234},
        );
    await tester.pumpWidget(const ProbeApp());
    await tester.tap(find.text('Run device probe'));
    await tester.pumpAndSettle();
    expect(find.textContaining('test-board'), findsOneWidget);
  });
  testWidgets('shows native failures and allows retry', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'probe_failed',
            message: 'No Vulkan device',
          );
        });
    await tester.pumpWidget(const ProbeApp());
    await tester.tap(find.text('Run device probe'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Probe failed:'), findsOneWidget);
    expect(find.text('Run device probe'), findsOneWidget);
  });
}
