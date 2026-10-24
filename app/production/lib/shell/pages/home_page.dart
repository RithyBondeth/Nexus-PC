import 'package:flutter/material.dart';
import '../shell_controller.dart';
import '../shell_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onLibrary,
    required this.onDevice,
  });
  final ShellController controller;
  final VoidCallback onLibrary;
  final VoidCallback onDevice;

  @override
  Widget build(BuildContext context) => ShellPage(
    title: 'Your gaming workspace',
    description:
        'A home for your PC game library on Android. We’re building it one phase at a time.',
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.folder_open_outlined, size: 32),
            const SizedBox(height: 16),
            Text(
              'Start with your library',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Import a DRM-free game folder or ZIP, manage your local copies, and check runtime status below before launching.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onLibrary,
              child: const Text('View library'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Semantics(
        header: true,
        child: Text(
          'Device snapshot',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 16),
      DeviceReadState(controller: controller),
      if (controller.profile case final device?) ...[
        DeviceField('Device', device.model),
        DeviceField(
          'Chipset',
          device.socModel.isEmpty ? 'Not reported' : device.socModel,
        ),
        DeviceField('Graphics', device.renderer ?? 'Not reported'),
      ],
      OutlinedButton(onPressed: onDevice, child: const Text('View device')),
      const SizedBox(height: 24),
      RuntimeSummary(controller: controller),
      const SizedBox(height: 16),
      const Text(
        'A detected device does not establish Windows-game compatibility. Windows launching is experimental and requires the optional runtime build.',
      ),
    ],
  );
}
