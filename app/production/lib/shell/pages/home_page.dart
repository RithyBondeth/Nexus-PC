import 'dart:async';
import 'package:flutter/material.dart';
import '../../library/game_details_page.dart';
import '../../library/library_controller.dart';
import '../../platform/nexus_platform.dart';
import '../../theme/nexus_theme.dart';
import '../shell_controller.dart';
import '../shell_widgets.dart';

class HomePage extends StatefulWidget {
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// The game the hero shows; follows taps and keyboard/controller focus.
  String? focusedId;

  Future<void> open(GameRecord game) async {
    final library = widget.library;
    if (library == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GameDetailsPage(
          api: library.api,
          gameId: game.id,
          platform: widget.platform,
          initialTitle: game.title,
        ),
      ),
    );
    unawaited(library.synchronize(reload: true));
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    if (library == null) return _build(context, const []);
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) =>
          _build(context, library.query.isEmpty ? library.games : const []),
    );
  }

  Widget _build(BuildContext context, List<GameRecord> games) {
    final controller = widget.controller;
    final focused = games.isEmpty
        ? null
        : games.firstWhere(
            (game) => game.id == focusedId,
            orElse: () => games.first,
          );
    return ShellPage(
      title: 'Your gaming workspace',
      description: '',
      showTitle: false,
      hero: focused == null
          ? _WelcomeHero(
              library: widget.library,
              onLibrary: widget.onLibrary,
              onImport: widget.onImport,
            )
          : _GameHero(
              games: games,
              focused: focused,
              total: widget.library?.total ?? games.length,
              onFocus: (game) => setState(() => focusedId = game.id),
              onOpen: open,
              onLibrary: widget.onLibrary,
            ),
      children: [
        if (games.isNotEmpty) ...[
          _QuickStats(games: games, total: widget.library?.total ?? 0),
          const SizedBox(height: 20),
        ],
        SectionHeader('System', action: 'Details', onAction: widget.onDevice),
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
              onPressed: widget.onDevice,
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

/// Room the hero leaves under the transparent top bar.
double _heroTop(BuildContext context) => MediaQuery.paddingOf(context).top;

/// The full-bleed top of Home: the focused game's art, its title as a poster
/// headline, Play, and a row of covers overlapping the hero's lower edge.
class _GameHero extends StatelessWidget {
  const _GameHero({
    required this.games,
    required this.focused,
    required this.total,
    required this.onFocus,
    required this.onOpen,
    required this.onLibrary,
  });
  final List<GameRecord> games;
  final GameRecord focused;
  final int total;
  final ValueChanged<GameRecord> onFocus;
  final ValueChanged<GameRecord> onOpen;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = focused.executableRelativePath != null;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    final coverWidth = 104.0 * scale;
    final shelfHeight = coverWidth * 1.5 + 24;
    final reduced = NexusMotion.reduced(context);
    return DarkHero(
      art: AnimatedSwitcher(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 550),
        child: GameArtwork(
          key: ValueKey(focused.id),
          title: focused.title,
          radius: 0,
          showTitle: false,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: _heroTop(context) + 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSwitcher(
                duration: reduced ? Duration.zero : NexusMotion.medium,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.bottomLeft,
                  children: [...previous, ?current],
                ),
                child: Column(
                  key: ValueKey(focused.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your gaming workspace',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      focused.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 40,
                        letterSpacing: 1.5,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: GameArtwork.accentOf(
                              focused.title,
                            ).withValues(alpha: 0.8),
                            blurRadius: 24,
                          ),
                          const Shadow(color: Color(0x99000000), blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(
                          label: ready ? 'Ready' : 'Needs setup',
                          color: ready ? scheme.primary : scheme.tertiary,
                          icon: ready
                              ? Icons.check_circle_rounded
                              : Icons.build_outlined,
                        ),
                        StatusPill(
                          label: formatLibraryBytes(focused.sizeBytes),
                          color: Colors.white,
                          icon: Icons.save_outlined,
                        ),
                        StatusPill(
                          label: total == 1 ? '1 game' : '$total games',
                          color: Colors.white,
                          icon: Icons.grid_view_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 56),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      onPressed: () => onOpen(focused),
                      icon: Icon(
                        ready ? Icons.play_arrow_rounded : Icons.tune_rounded,
                        size: 26,
                      ),
                      label: Text(ready ? 'PLAY' : 'SET UP'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    tooltip: 'View library',
                    onPressed: onLibrary,
                    icon: const Icon(Icons.grid_view_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: SectionHeader(
                'Your games',
                action: 'See all',
                onAction: onLibrary,
              ),
            ),
            SizedBox(
              height: shelfHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                itemCount: games.length.clamp(0, 20),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final game = games[index];
                  final selected = game.id == focused.id;
                  return SizedBox(
                    width: coverWidth,
                    child: GameCoverTile(
                      title: game.title,
                      heroTag: 'shelf-art-${game.id}',
                      ready: game.executableRelativePath != null,
                      subtitle: formatLibraryBytes(game.sizeBytes),
                      selected: selected,
                      onFocused: () => onFocus(game),
                      // First tap features the game; a second opens it.
                      onOpen: () => selected ? onOpen(game) : onFocus(game),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero before any import: showcase art and the first steps.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({
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
    final canImport = library?.canImport ?? false;
    return DarkHero(
      art: const GameArtwork(title: 'Nexus-PC', radius: 0, showTitle: false),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, _heroTop(context) + 120, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WELCOME',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your gaming workspace',
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bring your DRM-free PC games to Android. Import a game folder or ZIP and Nexus-PC keeps a private copy, ready for the Windows runtime.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 22),
            // Browsing comes first in focus order; importing follows.
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 54)),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    onPressed: canImport ? () => import(ImportKind.zip) : null,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: const Text('Import ZIP'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Big-number tiles, like the stats on a SteamOS library overview.
class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.games, required this.total});
  final List<GameRecord> games;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = games.where((g) => g.executableRelativePath != null).length;
    final bytes = games.fold<int>(0, (sum, g) => sum + g.sizeBytes);
    final stats = [
      (Icons.sports_esports_rounded, '$total', 'Games', scheme.secondary),
      (Icons.play_circle_outline_rounded, '$ready', 'Ready', scheme.primary),
      (
        Icons.save_outlined,
        formatLibraryBytes(bytes),
        'On device',
        scheme.tertiary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final large = MediaQuery.textScalerOf(context).scale(10) > 13;
        final columns = constraints.maxWidth < 340 || large ? 1 : 3;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (icon, value, label, color) in stats)
              Container(
                width: width,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(height: 10),
                    // Sizes like "935.9 KiB" shrink to fit rather than truncate.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: theme.textTheme.headlineSmall),
                    ),
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
