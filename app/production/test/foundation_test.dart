import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/main.dart';
import 'package:nexus_app/platform/nexus_platform.dart';

RuntimeStatus unavailable() => RuntimeStatus(
  state: RuntimeState.unavailable,
  code: 'runtime_unavailable',
  message: 'Game runtime is not integrated yet.',
  changedAtMillis: 1,
);
DeviceProfile device() => DeviceProfile(
  androidApi: 36,
  targetApi: 36,
  model: 'Xiaomi test',
  hardware: 'qcom',
  board: 'canoe',
  socModel: 'SM8850',
  cpuAbis: ['arm64-v8a'],
  ramBytes: 11556110336,
  renderer: 'Adreno 840',
  vulkanVersion: '1.4.295',
);

class FakeHost extends NexusHostApi {
  bool failProfile = false;
  @override
  Future<DeviceProfile> getDeviceProfile() async {
    if (failProfile) {
      throw PlatformException(
        code: 'native_error',
        message: 'Profile unavailable',
      );
    }
    return device();
  }

  @override
  Future<RuntimeStatus> getRuntimeStatus() async => unavailable();
  @override
  Future<ExecutionProbeResult> probePackagedExecution() async =>
      ExecutionProbeResult(
        passed: true,
        details: 'Only packaged execution verified.',
      );
  @override
  Future<RuntimeStatus> prepareRuntime(LaunchRequest request) async {
    throw PlatformException(code: 'runtime_unavailable');
  }

  @override
  Future<RuntimeStatus> launchGame(LaunchRequest request) =>
      prepareRuntime(request);
  @override
  Future<RuntimeStatus> stopGame() async => unavailable();
  @override
  Future<List<RuntimeLog>> getRecentLogs(int limit) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generated channel round-trips 64-bit RAM and nullable GPU fields',
    () async {
      final codec = NexusHostApi.pigeonChannelCodec;
      final channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.nexus_app.NexusHostApi.getDeviceProfile',
        codec,
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockDecodedMessageHandler(
        channel,
        (message) async => [device()],
      );
      addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
      final result = await NexusHostApi().getDeviceProfile();
      expect(result.ramBytes, 11556110336);
      expect(result.cpuAbis, ['arm64-v8a']);
      final partial = device()..renderer = null;
      final decoded =
          codec.decodeMessage(codec.encodeMessage(partial))! as DeviceProfile;
      expect(decoded.renderer, isNull);
    },
  );

  test('generated host channel preserves structured native errors', () async {
    final channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.nexus_app.NexusHostApi.launchGame',
      NexusHostApi.pigeonChannelCodec,
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler(
      channel,
      (message) async => ['runtime_unavailable', 'Not integrated', null],
    );
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    await expectLater(
      NexusHostApi().launchGame(
        LaunchRequest(gameId: 'demo', executableRelativePath: 'game.exe'),
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'runtime_unavailable',
        ),
      ),
    );
  });

  test(
    'native unavailable errors remain errors rather than launch success',
    () async {
      final platform = PigeonNexusPlatform(host: FakeHost());
      addTearDown(platform.close);
      expect(
        (await platform.getRuntimeStatus()).state,
        RuntimeState.unavailable,
      );
      await expectLater(
        platform.launchGame(
          LaunchRequest(gameId: 'demo', executableRelativePath: 'game.exe'),
        ),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'runtime_unavailable',
          ),
        ),
      );
      expect((await platform.stopGame()).state, RuntimeState.unavailable);
    },
  );

  test('typed native event callbacks forward status and logs', () async {
    final platform = PigeonNexusPlatform(host: FakeHost());
    addTearDown(platform.close);
    final statuses = platform.statuses.first;
    final logs = platform.logs.first;
    await platform.onRuntimeStatus(unavailable());
    await platform.onRuntimeLog(
      RuntimeLog(
        timestampMillis: 1,
        level: LogLevel.warning,
        code: 'runtime_unavailable',
        message: 'Not integrated',
      ),
    );
    expect((await statuses).state, RuntimeState.unavailable);
    expect((await logs).level, LogLevel.warning);
  });

  testWidgets('shows native failure and permits a successful retry', (
    tester,
  ) async {
    final host = FakeHost()..failProfile = true;
    final platform = PigeonNexusPlatform(host: host);
    addTearDown(platform.close);
    await tester.pumpWidget(NexusApp(platform: platform));
    await tester.pumpAndSettle();
    expect(find.textContaining('Device check failed:'), findsOneWidget);
    host.failProfile = false;
    await tester.tap(find.text('Refresh device'));
    await tester.pumpAndSettle();
    expect(find.text('Xiaomi test'), findsOneWidget);
    expect(find.text('Runtime: unavailable'), findsOneWidget);
    await tester.tap(find.text('Verify packaged execution'));
    await tester.pumpAndSettle();
    expect(find.text('Packaged execution passed'), findsOneWidget);
    expect(find.text('Runtime: unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'disposing while a native profile is pending does not update stale UI',
    (tester) async {
      final completer = Completer<DeviceProfile>();
      final platform = PigeonNexusPlatform(host: PendingHost(completer));
      addTearDown(platform.close);
      await tester.pumpWidget(NexusApp(platform: platform));
      await tester.pumpWidget(const SizedBox());
      completer.complete(device());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class PendingHost extends FakeHost {
  PendingHost(this.completer);
  final Completer<DeviceProfile> completer;
  @override
  Future<DeviceProfile> getDeviceProfile() => completer.future;
}
