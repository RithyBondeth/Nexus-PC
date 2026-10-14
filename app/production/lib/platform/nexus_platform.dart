import 'dart:async';
import 'nexus_api.g.dart';
export 'nexus_api.g.dart';

abstract interface class NexusPlatform {
  Stream<RuntimeStatus> get statuses;
  Stream<RuntimeLog> get logs;
  Future<DeviceProfile> getDeviceProfile();
  Future<ExecutionProbeResult> probePackagedExecution();
  Future<RuntimeStatus> getRuntimeStatus();
  Future<RuntimeStatus> prepareRuntime(LaunchRequest request);
  Future<RuntimeStatus> launchGame(LaunchRequest request);
  Future<RuntimeStatus> stopGame();
  Future<List<RuntimeLog>> getRecentLogs(int limit);
  Future<void> close();
}

class PigeonNexusPlatform implements NexusPlatform, NexusEventApi {
  PigeonNexusPlatform({NexusHostApi? host}) : _host = host ?? NexusHostApi() {
    NexusEventApi.setUp(this);
  }
  final NexusHostApi _host;
  final _statuses = StreamController<RuntimeStatus>.broadcast();
  final _logs = StreamController<RuntimeLog>.broadcast();
  @override
  Stream<RuntimeStatus> get statuses => _statuses.stream;
  @override
  Stream<RuntimeLog> get logs => _logs.stream;
  @override
  Future<DeviceProfile> getDeviceProfile() => _host.getDeviceProfile();
  @override
  Future<ExecutionProbeResult> probePackagedExecution() =>
      _host.probePackagedExecution();
  @override
  Future<RuntimeStatus> getRuntimeStatus() => _host.getRuntimeStatus();
  @override
  Future<RuntimeStatus> prepareRuntime(LaunchRequest request) =>
      _host.prepareRuntime(request);
  @override
  Future<RuntimeStatus> launchGame(LaunchRequest request) =>
      _host.launchGame(request);
  @override
  Future<RuntimeStatus> stopGame() => _host.stopGame();
  @override
  Future<List<RuntimeLog>> getRecentLogs(int limit) =>
      _host.getRecentLogs(limit);
  @override
  Future<void> onRuntimeStatus(RuntimeStatus status) async {
    if (!_statuses.isClosed) _statuses.add(status);
  }

  @override
  Future<void> onRuntimeLog(RuntimeLog log) async {
    if (!_logs.isClosed) _logs.add(log);
  }

  @override
  Future<void> close() async {
    NexusEventApi.setUp(null);
    await _statuses.close();
    await _logs.close();
  }
}
