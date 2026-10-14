import 'dart:async';
import 'package:flutter/material.dart';
import '../platform/nexus_platform.dart';

class FoundationScreen extends StatefulWidget {
  const FoundationScreen({super.key, required this.platform});
  final NexusPlatform platform;
  @override
  State<FoundationScreen> createState() => _FoundationScreenState();
}

class _FoundationScreenState extends State<FoundationScreen> {
  DeviceProfile? profile;
  RuntimeStatus? status;
  ExecutionProbeResult? probe;
  String? error;
  bool busy = false;
  final List<RuntimeLog> logs = [];
  StreamSubscription<RuntimeStatus>? statusSubscription;
  StreamSubscription<RuntimeLog>? logSubscription;
  @override
  void initState() {
    super.initState();
    statusSubscription = widget.platform.statuses.listen((value) {
      if (mounted) setState(() => status = value);
    });
    logSubscription = widget.platform.logs.listen((value) {
      if (mounted) {
        setState(() {
          logs.insert(0, value);
          if (logs.length > 20) logs.removeLast();
        });
      }
    });
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final device = await widget.platform.getDeviceProfile();
      final runtime = await widget.platform.getRuntimeStatus();
      if (mounted) {
        setState(() {
          profile = device;
          status = runtime;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = 'Device check failed: $failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyExecution() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.platform.probePackagedExecution();
      if (mounted) setState(() => probe = result);
    } catch (failure) {
      if (mounted) setState(() => error = 'Execution check failed: $failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    statusSubscription?.cancel();
    logSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nexus-PC')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Production foundation',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'The library and game launcher will arrive in later phases.',
        ),
        const SizedBox(height: 20),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SelectableText(error!),
          ),
        if (profile case final device?)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.model,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Android API ${device.androidApi} • App target ${device.targetApi}',
                  ),
                  Text('${device.socModel} • ${device.cpuAbis.join(', ')}'),
                  Text(
                    '${(device.ramBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB usable RAM',
                  ),
                  Text(
                    '${device.renderer ?? 'GPU unknown'} • Vulkan ${device.vulkanVersion ?? 'unavailable'}',
                  ),
                ],
              ),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Runtime: ${status?.state.name ?? 'checking'}'),
          subtitle: Text(status?.message ?? 'Checking native capabilities…'),
        ),
        OutlinedButton(
          onPressed: busy ? null : refresh,
          child: const Text('Refresh device'),
        ),
        FilledButton(
          onPressed: busy ? null : verifyExecution,
          child: const Text('Verify packaged execution'),
        ),
        if (probe case final result?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              result.passed
                  ? 'Packaged execution passed'
                  : 'Packaged execution failed',
            ),
            subtitle: SelectableText(result.details),
          ),
        const SizedBox(height: 12),
        const Text(
          'This check verifies a bundled native helper. It does not launch a Windows game.',
        ),
        if (logs.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Diagnostics', style: Theme.of(context).textTheme.titleMedium),
          for (final log in logs)
            Text('${log.level.name}: ${log.code} — ${log.message}'),
        ],
      ],
    ),
  );
}
