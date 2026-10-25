import 'dart:async';
import 'package:flutter/material.dart';
import '../../library/library_controller.dart';
import '../../library/game_details_page.dart';
import '../../platform/nexus_platform.dart';
import '../shell_widgets.dart';
import '../../theme/nexus_theme.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, this.api, this.platform, this.controller});
  final NexusLibraryApi? api;
  final NexusPlatform? platform;

  /// Shared with Home when provided; its owner disposes it.
  final LibraryController? controller;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

enum _Filter { all, ready, setup }

class _LibraryPageState extends State<LibraryPage> with WidgetsBindingObserver {
  late final LibraryController controller;
  _Filter filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller =
        widget.controller ?? LibraryController(widget.api ?? NexusLibraryApi());
    unawaited(controller.synchronize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.synchronize(reload: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  Future<void> openGame(GameRecord game) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GameDetailsPage(
          api: controller.api,
          gameId: game.id,
          platform: widget.platform,
          initialTitle: game.title,
        ),
      ),
    );
    if (mounted) await controller.synchronize(reload: true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final showProgress =
          controller.starting ||
          controller.progress?.state != ImportState.idle &&
              controller.progress != null;
      return ShellPage(
        eyebrow: 'Games',
        title: 'Your library',
        showTitle: false,
        hero: _LibraryHero(
          art: controller.games.isEmpty ? null : controller.games.first.title,
          total: controller.total,
          ready: controller.games
              .where((game) => game.executableRelativePath != null)
              .length,
          onImport: controller.canImport ? controller.begin : null,
        ),
        description: '',
        children: [
          AnimatedSize(
            duration: NexusMotion.medium,
            curve: NexusMotion.curve,
            alignment: Alignment.topCenter,
            child: !showProgress
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  controller.starting
                                      ? 'Opening the system picker…'
                                      : controller.progress!.message,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              if (controller.busy) ...[
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(
                                  minHeight: 6,
                                  semanticsLabel: 'Import in progress',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${formatFileCount(controller.progress?.filesCopied ?? 0)} · ${formatLibraryBytes(controller.progress?.bytesCopied ?? 0)} copied',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                const NoteText(
                                  'Your original files stay at their source.',
                                  icon: Icons.shield_outlined,
                                ),
                              ],
                              if (controller.canCancel) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: controller.cancel,
                                  icon: const Icon(Icons.close),
                                  label: const Text('Cancel import'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          TextField(
            enabled: !controller.busy,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Search your library',
              floatingLabelBehavior: FloatingLabelBehavior.never,
              prefixIcon: Icon(Icons.search),
              counterText: '',
            ),
            onChanged: controller.search,
          ),
          const SizedBox(height: 16),
          if (controller.error case final error?) ...[
            Semantics(
              liveRegion: true,
              child: NoteText(error, icon: Icons.error_outline),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.busy
                  ? controller.synchronize
                  : () => controller.synchronize(reload: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry library'),
            ),
            const SizedBox(height: 16),
          ],
          if (controller.loading)
            const LinearProgressIndicator(semanticsLabel: 'Loading library'),
          if (controller.initialized &&
              !controller.loading &&
              controller.error == null &&
              !controller.busy) ...[
            if (controller.games.isEmpty)
              controller.query.isEmpty
                  ? const EmptyState(
                      icon: Icons.sports_esports_outlined,
                      title: 'No games yet',
                      message:
                          'Import a game folder or ZIP to see it here. Nexus-PC keeps a private copy.',
                    )
                  : const EmptyState(
                      icon: Icons.search_off,
                      title: 'No matching games',
                      message: 'Try a different title.',
                    ),
            if (controller.games.isNotEmpty) ...[
              _FilterTabs(
                selected: filter,
                counts: {
                  _Filter.all: controller.games.length,
                  _Filter.ready: controller.games
                      .where((game) => game.executableRelativePath != null)
                      .length,
                  _Filter.setup: controller.games
                      .where((game) => game.executableRelativePath == null)
                      .length,
                },
                onSelected: (value) => setState(() => filter = value),
              ),
              const SizedBox(height: 14),
              switch ([
                for (final game in controller.games)
                  if (switch (filter) {
                    _Filter.all => true,
                    _Filter.ready => game.executableRelativePath != null,
                    _Filter.setup => game.executableRelativePath == null,
                  })
                    game,
              ]) {
                final shown when shown.isEmpty => const EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nothing in this view',
                  message: 'Games on this page are all in another view.',
                ),
                final shown => _GameGrid(games: shown, onOpen: openGame),
              },
            ],
            if (controller.total > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${controller.offset + 1}–${controller.offset + controller.games.length} of ${controller.total}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.offset > 0
                        ? () => controller.load(
                            pageOffset:
                                controller.offset - LibraryController.pageSize,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous page'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        controller.offset + LibraryController.pageSize <
                            controller.total
                        ? () => controller.load(
                            pageOffset:
                                controller.offset + LibraryController.pageSize,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next page'),
                  ),
                ],
              ),
            ],
          ],
        ],
      );
    },
  );
}

/// SteamOS-style view tabs over the current page of games.
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });
  final _Filter selected;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onSelected;

  static const _labels = {
    _Filter.all: 'All games',
    _Filter.ready: 'Ready',
    _Filter.setup: 'Needs setup',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Full width, so the tabs start at the left edge like the rest of the page.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in _Filter.values)
            ChoiceChip(
              selected: value == selected,
              onSelected: (_) => onSelected(value),
              showCheckmark: false,
              label: Text('${_labels[value]} · ${counts[value] ?? 0}'),
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: value == selected
                    ? scheme.onSecondary
                    : scheme.onSurfaceVariant,
              ),
              selectedColor: scheme.secondary,
              backgroundColor: scheme.surfaceContainerLow,
              side: BorderSide(
                color: value == selected
                    ? scheme.secondary
                    : scheme.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
        ],
      ),
    );
  }
}

/// Portrait covers in rows; columns follow width and text size.
class _GameGrid extends StatelessWidget {
  const _GameGrid({required this.games, required this.onOpen});
  final List<GameRecord> games;
  final ValueChanged<GameRecord> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
      const gap = 12.0;
      // Covers stay at least ~104 dp wide (three across a phone), more with enlarged text.
      final columns = ((width + gap) / (104 * scale + gap)).floor().clamp(1, 6);
      return Column(
        children: [
          for (var start = 0; start < games.length; start += columns)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: gap),
                    Expanded(
                      child: i < games.length
                          ? Reveal(
                              index: i - start,
                              child: GameCoverTile(
                                title: games[i].title,
                                heroTag: 'game-art-${games[i].id}',
                                ready: games[i].executableRelativePath != null,
                                subtitle:
                                    games[i].executableRelativePath ??
                                    'Choose an executable',
                                onOpen: () => onOpen(games[i]),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// A blurred wash of your newest cover behind a large title and counts.
class _LibraryHero extends StatelessWidget {
  const _LibraryHero({
    required this.art,
    required this.total,
    required this.ready,
    required this.onImport,
  });
  final String? art;
  final int total;
  final int ready;

  /// Null while an import runs or cleanup is pending.
  final ValueChanged<ImportKind>? onImport;

  @override
  Widget build(BuildContext context) => DarkHero(
    art: art == null
        ? const GameArtwork(title: 'Library', radius: 0, showTitle: false)
        : ArtBackdrop(title: art, fade: NexusPalette.dark.backdrop),
    // Reads the hero's dark theme, so the title stays light in light mode.
    child: Builder(builder: _content),
  );

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final import = onImport;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GAMES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Your library', style: theme.textTheme.displaySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: total == 1 ? '1 game' : '$total games',
                color: scheme.secondary,
                icon: Icons.grid_view_rounded,
              ),
              if (total > 0)
                StatusPill(
                  label: '$ready ready to play',
                  color: scheme.primary,
                  icon: Icons.play_arrow_rounded,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Private copies of your DRM-free games. Keep Nexus-PC open while importing.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: import == null
                    ? null
                    : () => import(ImportKind.folder),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Import folder'),
              ),
              OutlinedButton.icon(
                onPressed: import == null ? null : () => import(ImportKind.zip),
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('Import ZIP'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
