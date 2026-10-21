import 'dart:async';
import 'package:flutter/material.dart';
import '../../library/library_controller.dart';
import '../../library/game_details_page.dart';
import '../../platform/nexus_platform.dart';
import '../shell_widgets.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, this.api, this.platform});
  final NexusLibraryApi? api;
  final NexusPlatform? platform;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with WidgetsBindingObserver {
  late final LibraryController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = LibraryController(widget.api ?? NexusLibraryApi());
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
    controller.dispose();
    super.dispose();
  }

  Future<void> openGame(GameRecord game) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GameDetailsPage(
          api: controller.api,
          gameId: game.id,
          platform: widget.platform,
        ),
      ),
    );
    if (mounted) await controller.synchronize(reload: true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => ShellPage(
      title: 'Your library',
      description:
          'Import a DRM-free game folder or ZIP as a private copy. Keep Nexus-PC open while copying. Launching requires the experimental Windows runtime build.',
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
        const SizedBox(height: 16),
        if (controller.starting ||
            controller.progress?.state != ImportState.idle &&
                controller.progress != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              controller.starting
                  ? 'Opening the system picker…'
                  : controller.progress!.message,
            ),
          ),
          if (controller.busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(semanticsLabel: 'Import in progress'),
            const SizedBox(height: 8),
            Text(
              '${controller.progress?.filesCopied ?? 0} files · ${formatLibraryBytes(controller.progress?.bytesCopied ?? 0)} copied',
            ),
            const Text('Your original files stay at their source.'),
          ],
          if (controller.canCancel)
            OutlinedButton(
              onPressed: controller.cancel,
              child: const Text('Cancel import'),
            ),
          const SizedBox(height: 16),
        ],
        TextField(
          enabled: !controller.busy,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Search your library',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: controller.search,
        ),
        const SizedBox(height: 16),
        if (controller.error case final error?) ...[
          Semantics(liveRegion: true, child: Text(error)),
          OutlinedButton(
            onPressed: controller.busy
                ? controller.synchronize
                : () => controller.synchronize(reload: true),
            child: const Text('Retry library'),
          ),
        ],
        if (controller.loading)
          const LinearProgressIndicator(semanticsLabel: 'Loading library'),
        if (controller.initialized &&
            !controller.loading &&
            controller.error == null &&
            !controller.busy) ...[
          if (controller.games.isEmpty)
            Text(
              controller.query.isEmpty ? 'No games yet' : 'No matching games',
            ),
          for (final game in controller.games)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: () => openGame(game),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${game.fileCount} files · ${formatLibraryBytes(game.sizeBytes)}',
                      ),
                      Text(
                        game.executableRelativePath ?? 'Choose an executable',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (controller.total > 0) ...[
            Text(
              '${controller.offset + 1}–${controller.offset + controller.games.length} of ${controller.total}',
            ),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: controller.offset > 0
                      ? () => controller.load(
                          pageOffset:
                              controller.offset - LibraryController.pageSize,
                        )
                      : null,
                  child: const Text('Previous page'),
                ),
                OutlinedButton(
                  onPressed:
                      controller.offset + LibraryController.pageSize <
                          controller.total
                      ? () => controller.load(
                          pageOffset:
                              controller.offset + LibraryController.pageSize,
                        )
                      : null,
                  child: const Text('Next page'),
                ),
              ],
            ),
          ],
        ],
      ],
    ),
  );
}
