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

class _LibraryPageState extends State<LibraryPage> with WidgetsBindingObserver {
  late final LibraryController controller;

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
        description:
            'Import a DRM-free game folder or ZIP as a private copy. Keep Nexus-PC open while copying. Launching requires the experimental Windows runtime build.',
        children: [
          SectionCard(
            title: 'Add a game',
            icon: Icons.add_box_outlined,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: controller.canImport
                        ? () => controller.begin(ImportKind.folder)
                        : null,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Import folder'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.canImport
                        ? () => controller.begin(ImportKind.zip)
                        : null,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: const Text('Import ZIP'),
                  ),
                ],
              ),
              AnimatedSize(
                duration: NexusMotion.medium,
                curve: NexusMotion.curve,
                alignment: Alignment.topCenter,
                child: !showProgress
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
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
            ],
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
            if (controller.games.isNotEmpty)
              _GameGrid(games: controller.games, onOpen: openGame),
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

/// Poster-style tiles in equal-height rows; columns follow width and text size.
class _GameGrid extends StatelessWidget {
  const _GameGrid({required this.games, required this.onOpen});
  final List<GameRecord> games;
  final ValueChanged<GameRecord> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final large = MediaQuery.textScalerOf(context).scale(10) > 13;
      final columns = width >= 720
          ? 4
          : width >= 520
          ? 3
          : width >= 260 && !(large && width < 500)
          ? 2
          : 1;
      const gap = 12.0;
      return Column(
        children: [
          for (var start = 0; start < games.length; start += columns)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < start + columns; i++) ...[
                      if (i > start) const SizedBox(width: gap),
                      Expanded(
                        child: i < games.length
                            ? Reveal(
                                index: i - start,
                                child: _GameTile(
                                  game: games[i],
                                  onOpen: () => onOpen(games[i]),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.onOpen});
  final GameRecord game;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final executable = game.executableRelativePath;
    return PressScale(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GameArtwork(
                      title: game.title,
                      heroTag: 'game-art-${game.id}',
                      radius: 0,
                      showTitle: false,
                    ),
                    // The title is real text on the cover, so it stays
                    // readable by screen readers and searchable.
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        game.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          shadows: const [
                            Shadow(color: Color(0x99000000), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatFileCount(game.fileCount)} · ${formatLibraryBytes(game.sizeBytes)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          executable == null
                              ? Icons.error_outline
                              : Icons.check_circle,
                          size: 14,
                          color: executable == null
                              ? scheme.error
                              : scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            executable ?? 'Choose an executable',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: executable == null
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
