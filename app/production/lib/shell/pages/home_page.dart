import 'dart:async';
import 'package:flutter/material.dart';
import '../../library/game_details_page.dart';
import '../../library/library_controller.dart';
import '../../platform/nexus_platform.dart';
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
    this.platform,
  });
  final ShellController controller;
  final VoidCallback onLibrary;
  final VoidCallback onDevice;
  final LibraryController? library;
  final ValueChanged<ImportKind>? onImport;
  final NexusPlatform? platform;

  @override
  Widget build(BuildContext context) {
    Widget games(Widget Function(LibraryController? games) build) =>
        switch (library) {
          final value? => ListenableBuilder(
            listenable: value,
            builder: (context, _) => build(value),
          ),
          null => build(null),
        };
    return ShellPage(
      eyebrow: 'Overview',
      title: 'Your gaming workspace',
      description:
          'A home for your PC game library on Android. We’re building it one phase at a time.',
      children: [
        games(
          (value) => _Spotlight(
            library: value,
            platform: platform,
            onLibrary: onLibrary,
            onImport: onImport,
          ),
        ),
        games(
          (value) =>
              _Shelf(library: value, platform: platform, onLibrary: onLibrary),
        ),
        SectionHeader('System', action: 'Details', onAction: onDevice),
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
}

Future<void> _openGame(
  BuildContext context,
  LibraryController library,
  NexusPlatform? platform,
  GameRecord game,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => GameDetailsPage(
        api: library.api,
        gameId: game.id,
        platform: platform,
        initialTitle: game.title,
      ),
    ),
  );
  unawaited(library.synchronize(reload: true));
}

/// The large card at the top of Home. With games, it features the newest
/// import like the SteamOS hero; without, it invites the first import.
class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.library,
    required this.platform,
    required this.onLibrary,
    this.onImport,
  });
  final LibraryController? library;
  final NexusPlatform? platform;
  final VoidCallback onLibrary;
  final ValueChanged<ImportKind>? onImport;

  @override
  Widget build(BuildContext context) {
    final games = library;
    final featured =
        games != null && games.query.isEmpty && games.games.isNotEmpty
        ? games.games.first
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: featured == null
          ? _Welcome(library: games, onLibrary: onLibrary, onImport: onImport)
          : _Featured(
              game: featured,
              total: games!.total,
              onOpen: () => _openGame(context, games, platform, featured),
              onLibrary: onLibrary,
            ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({
    required this.game,
    required this.total,
    required this.onOpen,
    required this.onLibrary,
  });
  final GameRecord game;
  final int total;
  final VoidCallback onOpen;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = game.executableRelativePath != null;
    return FocusGlow(
      onTap: onOpen,
      radius: 20,
      child: Stack(
        children: [
          Positioned.fill(
            child: GameArtwork(
              title: game.title,
              heroTag: 'home-art-${game.id}',
              radius: 0,
              showTitle: false,
            ),
          ),
          // Darken the left and bottom so text stays legible on any cover.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'RECENTLY ADDED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    StatusPill(
                      label: total == 1 ? '1 game' : '$total games',
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 72),
                Text(
                  game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatFileCount(game.fileCount)} · ${formatLibraryBytes(game.sizeBytes)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onOpen,
                      icon: Icon(
                        ready ? Icons.play_arrow_rounded : Icons.tune_rounded,
                      ),
                      label: Text(ready ? 'Open game' : 'Set up game'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      onPressed: onLibrary,
                      icon: const Icon(Icons.grid_view_rounded),
                      label: const Text('View library'),
                    ),
                  ],
                ),
                if (!ready) ...[
                  const SizedBox(height: 12),
                  StatusPill(
                    label: 'Choose an executable to finish setup',
                    color: scheme.tertiary,
                    icon: Icons.build_outlined,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.library,
    required this.onLibrary,
    this.onImport,
  });
  final LibraryController? library;
  final VoidCallback onLibrary;
  final ValueChanged<ImportKind>? onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final games = library;
    final canImport = games?.canImport ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(scheme.surfaceContainer, scheme.secondary, 0.22)!,
            scheme.surfaceContainer,
          ],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: _HeroGrid(scheme.secondary),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                          child: StatusPill(
                            label: games.total == 1
                                ? '1 game'
                                : '${games.total} games',
                            color: scheme.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Start with your library',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Import a DRM-free game folder or ZIP, manage your local copies, and check runtime status below before launching.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                // Browsing comes first in focus order; importing follows.
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
    );
  }
}

/// A horizontal row of covers, newest first, like a SteamOS shelf.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.library,
    required this.platform,
    required this.onLibrary,
  });
  final LibraryController? library;
  final NexusPlatform? platform;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final games = library;
    if (games == null || games.query.isNotEmpty || games.games.length < 2) {
      return const SizedBox.shrink();
    }
    final shown = games.games.take(12).toList();
    // Covers grow a little with text size so their titles stay readable.
    final width =
        124 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Your games', action: 'See all', onAction: onLibrary),
        SizedBox(
          height: width * 1.5 + 12,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final game = shown[index];
              return SizedBox(
                width: width,
                child: GameCoverTile(
                  title: game.title,
                  heroTag: 'shelf-art-${game.id}',
                  ready: game.executableRelativePath != null,
                  subtitle: formatLibraryBytes(game.sizeBytes),
                  onOpen: () => _openGame(context, games, platform, game),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// A faint perspective grid in the welcome card, fading to the right.
class _HeroGrid extends CustomPainter {
  _HeroGrid(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.22)],
      ).createShader(Offset.zero & size);
    const step = 28.0;
    for (var x = size.width * 0.35; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(
        Offset(size.width * 0.35, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HeroGrid old) => old.color != color;
}
