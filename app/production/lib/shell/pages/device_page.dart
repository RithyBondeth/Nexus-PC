import 'package:flutter/material.dart';
import '../../platform/nexus_platform.dart';
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
      if (controller.profile case final device?) _ChipHero(device: device),
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

/// The chipset front and centre, like the SteamOS performance overlay.
class _ChipHero extends StatelessWidget {
  const _ChipHero({required this.device});
  final DeviceProfile device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ramGiB = device.ramBytes / (1024 * 1024 * 1024);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(scheme.surfaceContainer, scheme.secondary, 0.25)!,
              scheme.surfaceContainer,
            ],
          ),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: CustomPaint(
                      size: const Size.square(64),
                      painter: _ChipPainter(scheme.secondary, scheme.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHIPSET',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          device.socModel.isEmpty
                              ? device.hardware
                              : device.socModel,
                          style: theme.textTheme.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (device.renderer case final gpu?)
                    StatusPill(
                      label: gpu,
                      color: scheme.primary,
                      icon: Icons.videogame_asset_outlined,
                    ),
                  if (device.vulkanVersion case final vulkan?)
                    StatusPill(
                      label: 'Vulkan $vulkan',
                      color: scheme.secondary,
                      icon: Icons.layers_outlined,
                    ),
                  StatusPill(
                    label: '${ramGiB.toStringAsFixed(0)} GiB RAM',
                    color: scheme.tertiary,
                    icon: Icons.sd_storage_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stylised processor package with pins and a glowing die.
class _ChipPainter extends CustomPainter {
  _ChipPainter(this.edge, this.die);
  final Color edge;
  final Color die;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final pin = Paint()
      ..color = edge.withValues(alpha: 0.7)
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final t = s * (0.3 + i * 0.13);
      canvas
        ..drawLine(Offset(t, 0), Offset(t, s * 0.14), pin)
        ..drawLine(Offset(t, s * 0.86), Offset(t, s), pin)
        ..drawLine(Offset(0, t), Offset(s * 0.14, t), pin)
        ..drawLine(Offset(s * 0.86, t), Offset(s, t), pin);
    }
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.14, s * 0.14, s * 0.72, s * 0.72),
      Radius.circular(s * 0.12),
    );
    canvas.drawRRect(body, Paint()..color = edge.withValues(alpha: 0.18));
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.03
        ..color = edge,
    );
    final core = Rect.fromCenter(
      center: Offset(s / 2, s / 2),
      width: s * 0.34,
      height: s * 0.34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(core, Radius.circular(s * 0.06)),
      Paint()
        ..color = die
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
  }

  @override
  bool shouldRepaint(_ChipPainter old) => old.edge != edge || old.die != die;
}
