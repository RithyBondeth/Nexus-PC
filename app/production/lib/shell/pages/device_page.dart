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
    eyebrow: 'Hardware',
    title: 'Your device',
    description:
        'Measured by Android and the stock Vulkan driver. These are observations, not a compatibility rating.',
    children: [
      SectionCard(
        title: 'Specifications',
        icon: Icons.smartphone_outlined,
        children: [
          DeviceReadState(controller: controller),
          if (controller.profile case final device?) ...[
            SpecGrid(
              specs: [
                ('Model', device.model),
                (
                  'Android / app target',
                  'API ${device.androidApi} / API ${device.targetApi}',
                ),
                (
                  'Chipset / board',
                  '${device.socModel.isEmpty ? 'Not reported' : device.socModel} / ${device.board}',
                ),
                ('Architecture', device.cpuAbis.join(', ')),
                (
                  'Usable system RAM',
                  '${(device.ramBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB',
                ),
                ('Stock graphics', device.renderer ?? 'Not reported'),
                ('Vulkan', device.vulkanVersion ?? 'Not reported'),
              ],
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            onPressed: controller.refreshing ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh device'),
          ),
        ],
      ),
      RuntimeSummary(controller: controller),
      SectionCard(
        title: 'Diagnostics',
        icon: Icons.troubleshoot_outlined,
        children: [
          const NoteText(
            'The diagnostic helper verifies packaged native execution only. It does not launch a Windows game.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onDiagnostics,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Open native diagnostics'),
          ),
        ],
      ),
    ],
  );
}
