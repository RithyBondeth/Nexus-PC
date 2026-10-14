import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/nexus_api.g.dart',
    dartPackageName: 'nexus_app',
    kotlinOut: 'android/app/src/main/kotlin/com/nexuspc/app/NexusApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.nexuspc.app'),
  ),
)
enum RuntimeState { unavailable, idle, preparing, running, stopping, failed }

enum LogLevel { debug, info, warning, error }

class DeviceProfile {
  DeviceProfile({
    required this.androidApi,
    required this.targetApi,
    required this.model,
    required this.hardware,
    required this.board,
    required this.socModel,
    required this.cpuAbis,
    required this.ramBytes,
    this.renderer,
    this.vulkanVersion,
  });
  int androidApi;
  int targetApi;
  String model;
  String hardware;
  String board;
  String socModel;
  List<String> cpuAbis;
  int ramBytes;
  String? renderer;
  String? vulkanVersion;
}

class RuntimeStatus {
  RuntimeStatus({
    required this.state,
    required this.code,
    required this.message,
    required this.changedAtMillis,
    this.sessionId,
  });
  RuntimeState state;
  String code;
  String message;
  int changedAtMillis;
  String? sessionId;
}

class LaunchRequest {
  LaunchRequest({required this.gameId, required this.executableRelativePath});
  String gameId;
  String executableRelativePath;
}

class RuntimeLog {
  RuntimeLog({
    required this.timestampMillis,
    required this.level,
    required this.code,
    required this.message,
  });
  int timestampMillis;
  LogLevel level;
  String code;
  String message;
}

class ExecutionProbeResult {
  ExecutionProbeResult({
    required this.passed,
    required this.details,
    this.exitCode,
    this.nativeLibraryPath,
  });
  bool passed;
  String details;
  int? exitCode;
  String? nativeLibraryPath;
}

@HostApi()
abstract class NexusHostApi {
  @asyncCallback
  DeviceProfile getDeviceProfile();
  @asyncCallback
  ExecutionProbeResult probePackagedExecution();
  RuntimeStatus getRuntimeStatus();
  @asyncCallback
  RuntimeStatus prepareRuntime(LaunchRequest request);
  @asyncCallback
  RuntimeStatus launchGame(LaunchRequest request);
  @asyncCallback
  RuntimeStatus stopGame();
  List<RuntimeLog> getRecentLogs(int limit);
}

@FlutterApi()
abstract class NexusEventApi {
  @asyncCallback
  void onRuntimeStatus(RuntimeStatus status);
  @asyncCallback
  void onRuntimeLog(RuntimeLog log);
}
