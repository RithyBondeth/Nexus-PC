import 'package:flutter/material.dart';
import '../shell_controller.dart';
import '../shell_widgets.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({
    super.key,
    required this.controller,
    required this.onDiagnostics,
  });
  final ShellController controller;
  final VoidCallback onDiagnostics;

  @override
  Widget build(BuildContext context) => ShellPage(
    title: 'Your device',
    description:
        'Measured by Android and the stock Vulkan driver. These are observations, not a compatibility rating.',
    children: [
      DeviceReadState(controller: controller),
      if (controller.profile case final device?) ...[
        DeviceField('Model', device.model),
        DeviceField(
          'Android / app target',
          'API ${device.androidApi} / API ${device.targetApi}',
        ),
        DeviceField(
          'Chipset / board',
          '${device.socModel.isEmpty ? 'Not reported' : device.socModel} / ${device.board}',
        ),
        DeviceField('Architecture', device.cpuAbis.join(', ')),
        DeviceField(
          'Usable system RAM',
          '${(device.ramBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB',
        ),
        DeviceField('Stock graphics', device.renderer ?? 'Not reported'),
        DeviceField('Vulkan', device.vulkanVersion ?? 'Not reported'),
      ],
      OutlinedButton(
        onPressed: controller.refreshing ? null : controller.refresh,
        child: const Text('Refresh device'),
      ),
      const SizedBox(height: 24),
      RuntimeSummary(controller: controller),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: onDiagnostics,
        child: const Text('Open native diagnostics'),
      ),
      const SizedBox(height: 8),
      const Text(
        'The diagnostic helper verifies packaged native execution only. It does not launch a Windows game.',
      ),
    ],
  );
}
