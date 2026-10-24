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

enum AppearanceMode { system, light, dark }

enum ImportKind { folder, zip }

enum ImportState {
  idle,
  choosing,
  copying,
  committing,
  completed,
  cancelled,
  failed,
}

class GameRecord {
  GameRecord({
    required this.id,
    required this.title,
    required this.contentHash,
    required this.sizeBytes,
    required this.fileCount,
    required this.importedAtMillis,
    required this.executableCount,
    this.executableRelativePath,
    this.architecture,
    this.sha256,
  });
  String id;
  String title;
  String contentHash;
  int sizeBytes;
  int fileCount;
  int importedAtMillis;
  int executableCount;
  String? executableRelativePath;
  String? architecture;
  String? sha256;
}

class ExecutableRecord {
  ExecutableRecord({
    required this.relativePath,
    required this.architecture,
    required this.sha256,
  });
  String relativePath;
  String architecture;
  String sha256;
}

class GameDetails {
  GameDetails({required this.game, required this.executables});
  GameRecord game;
  List<ExecutableRecord> executables;
}

class LibraryResult {
  LibraryResult({required this.games, required this.total});
  List<GameRecord> games;
  int total;
}

class ImportProgress {
  ImportProgress({
    required this.state,
    required this.code,
    required this.message,
    required this.bytesCopied,
    required this.filesCopied,
    this.jobId,
    this.gameId,
  });
  ImportState state;
  String code;
  String message;
  int bytesCopied;
  int filesCopied;
  String? jobId;
  String? gameId;
}

@HostApi()
abstract class NexusLibraryApi {
  @asyncCallback
  LibraryResult listGames(int offset, int limit, String query);
  @asyncCallback
  GameDetails getGame(String gameId);
  @asyncCallback
  GameRecord updateGame(
    String gameId,
    String title,
    String executableRelativePath,
  );
  @asyncCallback
  void removeGame(String gameId);
  ImportProgress beginImport(ImportKind kind);
  ImportProgress getImportProgress();
  void cancelImport(String jobId);
}

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

class BuildInfo {
  BuildInfo({
    required this.versionName,
    required this.versionCode,
    required this.commit,
    required this.buildType,
    required this.runtimePackaged,
  });
  String versionName;
  int versionCode;

  /// Short git revision, with "-dirty" when built from local edits.
  String commit;

  /// Android build type: debug, profile or release.
  String buildType;

  /// Whether the experimental Windows runtime is packaged.
  bool runtimePackaged;
}

@HostApi()
abstract class NexusHostApi {
  BuildInfo getBuildInfo();
  AppearanceMode getAppearance();
  void setAppearance(AppearanceMode mode);

  /// Opens the Android share sheet; nothing leaves the device unless the
  /// user picks a destination.
  void shareText(String subject, String text);
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
