import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../library/library_controller.dart';
import '../../platform/nexus_api.g.dart';
import '../shell_controller.dart';
import '../shell_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onLibrary,
    required this.onDevice,
    this.library,
    this.onImport,
  });
  final ShellController controller;
  final VoidCallback onLibrary;
  final VoidCallback onDevice;
  final LibraryController? library;
  final ValueChanged<ImportKind>? onImport;

  @override
  Widget build(BuildContext context) => ShellPage(
    eyebrow: 'Overview',
    title: 'Your gaming workspace',
    description:
        'A home for your PC game library on Android. We’re building it one phase at a time.',
    children: [
      if (library case final games?)
        ListenableBuilder(
          listenable: games,
          builder: (context, _) =>
              _Hero(library: games, onLibrary: onLibrary, onImport: onImport),
        )
      else
        _Hero(library: null, onLibrary: onLibrary, onImport: onImport),
      SectionCard(
        title: 'Device snapshot',
        icon: Icons.memory_outlined,
        children: [
          DeviceReadState(controller: controller),
          if (controller.profile case final device?)
            SpecGrid(
              specs: [
                ('Device', device.model),
                (
                  'Chipset',
                  device.socModel.isEmpty ? 'Not reported' : device.socModel,
                ),
                ('Graphics', device.renderer ?? 'Not reported'),
              ],
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onDevice,
            icon: const Icon(Icons.chevron_right),
            label: const Text('View device'),
          ),
        ],
      ),
      RuntimeSummary(controller: controller),
      const NoteText(
        'A detected device does not establish Windows-game compatibility. Windows launching is experimental and requires the optional runtime build.',
      ),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.library, required this.onLibrary, this.onImport});
  final LibraryController? library;
  final VoidCallback onLibrary;
  final ValueChanged<ImportKind>? onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final games = library;
    final canImport = games?.canImport ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.surfaceContainer],
          ),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CustomPaint(
            painter: _HeroRings(scheme.primary),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(Icons.sports_esports_outlined, size: 44),
                      const SizedBox(width: 12),
                      if (games != null && games.initialized)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                games.total == 1
                                    ? '1 game'
                                    : '${games.total} games',
                                style: theme.textTheme.labelLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Start with your library',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import a DRM-free game folder or ZIP, manage your local copies, and check runtime status below before launching.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onLibrary,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View library'),
                  ),
                  if (onImport case final import?) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: canImport
                              ? () => import(ImportKind.folder)
                              : null,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('Import folder'),
                        ),
                        OutlinedButton.icon(
                          onPressed: canImport
                              ? () => import(ImportKind.zip)
                              : null,
                          icon: const Icon(Icons.folder_zip_outlined),
                          label: const Text('Import ZIP'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative concentric rings in the hero's top-right corner.
class _HeroRings extends CustomPainter {
  _HeroRings(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.95, size.height * 0.05);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var ring = 1; ring <= 7; ring++) {
      paint.color = color.withValues(alpha: 0.24 - ring * 0.028);
      canvas.drawCircle(center, ring * math.min(size.width, 420) * 0.09, paint);
    }
  }

  @override
  bool shouldRepaint(_HeroRings old) => old.color != color;
}
