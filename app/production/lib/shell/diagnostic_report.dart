import 'dart:async';
import '../platform/nexus_platform.dart';

/// Plain-text report for testers to send: build, device, runtime status and
/// recent native log entries. It never reads game files or the library list;
/// native messages are shown in full so the tester can review them first.
/// Each section fails independently so a partial report is still useful.
Future<String> collectDiagnosticReport(
  NexusPlatform platform, {
  DateTime? now,
}) async {
  const timeout = Duration(seconds: 5);
  Future<T?> read<T>(
    Future<T> Function() operation,
    List<String> errors,
  ) async {
    try {
      return await operation().timeout(timeout);
    } catch (error) {
      errors.add('$error');
      return null;
    }
  }

  final buildErrors = <String>[];
  final deviceErrors = <String>[];
  final statusErrors = <String>[];
  final logErrors = <String>[];
  final (build, device, status, logs) = await (
    read(platform.getBuildInfo, buildErrors),
    read(platform.getDeviceProfile, deviceErrors),
    read(platform.getRuntimeStatus, statusErrors),
    read(() => platform.getRecentLogs(128), logErrors),
  ).wait;

  final lines = <String>[
    'Nexus-PC diagnostic report',
    'Generated: ${(now ?? DateTime.now()).toUtc().toIso8601String()}',
    '',
    '## App',
    if (build != null) ...[
      'Version: ${build.versionName} (${build.versionCode})',
      'Build: ${build.buildType}, commit ${build.commit}',
      'Windows runtime: ${build.runtimePackaged ? 'included (experimental)' : 'not included'}',
    ] else
      'Unavailable: ${buildErrors.join('; ')}',
    '',
    '## Device',
    if (device != null) ...[
      'Model: ${device.model}',
      'Android API: ${device.androidApi} (app target ${device.targetApi})',
      'Chipset: ${device.socModel.isEmpty ? 'not reported' : device.socModel} / ${device.board} / ${device.hardware}',
      'ABIs: ${device.cpuAbis.join(', ')}',
      'RAM: ${(device.ramBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB',
      'Graphics: ${device.renderer ?? 'not reported'}, Vulkan ${device.vulkanVersion ?? 'not reported'}',
    ] else
      'Unavailable: ${deviceErrors.join('; ')}',
    '',
    '## Runtime',
    if (status != null)
      '${status.state.name} (${status.code}): ${status.message}'
    else
      'Unavailable: ${statusErrors.join('; ')}',
    '',
    '## Recent native log',
    if (logs == null)
      'Unavailable: ${logErrors.join('; ')}'
    else if (logs.isEmpty)
      'No entries.'
    else
      for (final log in logs)
        '${DateTime.fromMillisecondsSinceEpoch(log.timestampMillis, isUtc: true).toIso8601String()} '
            '${log.level.name.toUpperCase()} ${log.code}: ${log.message}',
    '',
    'No game files or library list are included. Review before sharing.',
  ];
  return lines.join('\n');
}
