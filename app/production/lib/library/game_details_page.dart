import 'dart:async';
import 'package:flutter/material.dart';
import '../platform/nexus_platform.dart';
import '../shell/shell_widgets.dart';
import '../theme/nexus_theme.dart';
import 'library_controller.dart';

class GameDetailsPage extends StatefulWidget {
  const GameDetailsPage({
    super.key,
    required this.api,
    required this.gameId,
    this.platform,
    this.initialTitle,
  });
  final NexusLibraryApi api;
  final String gameId;
  final NexusPlatform? platform;

  /// Known from the library list, so the header and artwork can appear
  /// (and animate from the list) before details finish loading.
  final String? initialTitle;

  @override
  State<GameDetailsPage> createState() => _GameDetailsPageState();
}

class _GameDetailsPageState extends State<GameDetailsPage> {
  final title = TextEditingController();
  GameDetails? details;
  String? executable;
  String? error;
  bool loading = true;
  bool saving = false;
  bool requestingRuntime = false;
  RuntimeStatus? runtime;
  StreamSubscription<RuntimeStatus>? runtimeEvents;
  bool get unsavedChanges =>
      details != null &&
      (title.text.trim() != details!.game.title ||
          executable != details!.game.executableRelativePath);
  bool get runtimeBusy =>
      runtime?.code == 'runtime_cleanup_pending' ||
      requestingRuntime ||
      [
        RuntimeState.preparing,
        RuntimeState.running,
        RuntimeState.stopping,
      ].contains(runtime?.state);

  @override
  void initState() {
    super.initState();
    load();
    runtimeEvents = widget.platform?.statuses.listen((status) {
      if (mounted) setState(() => runtime = status);
    });
    readRuntime();
  }

  Future<void> readRuntime() async {
    if (widget.platform == null) return;
    try {
      final value = await widget.platform!.getRuntimeStatus();
      if (mounted) setState(() => runtime = value);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not read runtime status. Reopen this screen to retry.',
        );
      }
    }
  }

  Future<void> runGame({bool stop = false}) async {
    if (requestingRuntime || widget.platform == null) return;
    setState(() {
      requestingRuntime = true;
      error = null;
    });
    try {
      final value = stop
          ? await widget.platform!.stopGame()
          : await widget.platform!.launchGame(
              LaunchRequest(
                gameId: widget.gameId,
                executableRelativePath: details!.game.executableRelativePath!,
              ),
            );
      if (mounted) setState(() => runtime = value);
    } catch (failure) {
      if (mounted) {
        setState(() => error = libraryFailure(failure));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error!)));
      }
    } finally {
      if (mounted) setState(() => requestingRuntime = false);
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.getGame(widget.gameId);
      if (!mounted) return;
      setState(() {
        details = result;
        title.text = result.game.title;
        executable = result.game.executableRelativePath;
      });
    } catch (failure) {
      if (mounted) setState(() => error = libraryFailure(failure));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (saving || executable == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final game = await widget.api.updateGame(
        widget.gameId,
        title.text,
        executable!,
      );
      if (!mounted) return;
      setState(() {
        details!.game = game;
        title.text = game.title;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Game details saved')));
    } catch (failure) {
      if (mounted) {
        setState(() => error = libraryFailure(failure));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error!)));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove imported copy?'),
        content: const Text(
          'This deletes the copy stored by Nexus-PC. Your original folder or ZIP stays at its source.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep game'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove copy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.removeGame(widget.gameId);
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = libraryFailure(failure);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error!)));
      }
    }
  }

  @override
  void dispose() {
    runtimeEvents?.cancel();
    title.dispose();
    super.dispose();
  }

  Widget runtimeCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = runtime!;
    final available = status.state != RuntimeState.unavailable;
    final visual = runtimeVisual(scheme, status.state);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              Color.lerp(scheme.surfaceContainer, visual.color, 0.12)!,
              scheme.surfaceContainer,
            ],
          ),
          border: Border.all(color: visual.color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBadge(visual.icon, color: visual.color, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Play',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status.message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!available) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play'),
                ),
                const SizedBox(height: 8),
                const NoteText(
                  'Playing needs the experimental Windows runtime build. Your library still works without it.',
                ),
              ],
              if (available) ...[
                const SizedBox(height: 16),
                const NoteText(
                  'Only run games you trust. The Windows runtime can access Nexus-PC app data. Keep this screen open during preparation.',
                  icon: Icons.shield_outlined,
                ),
                if (unsavedChanges) ...[
                  const SizedBox(height: 8),
                  const NoteText(
                    'Save your changes before launching.',
                    icon: Icons.edit_note,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Launch and Stop stay pinned above the system bar while the page scrolls.
  Widget launchBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = runtime!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: AnimatedSize(
          duration: NexusMotion.medium,
          curve: NexusMotion.curve,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed:
                    saving ||
                        runtimeBusy ||
                        unsavedChanges ||
                        details!.game.executableRelativePath == null ||
                        details!.game.architecture != 'x86_64'
                    ? null
                    : () => runGame(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Launch game (experimental)'),
              ),
              if (runtimeBusy) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed:
                      requestingRuntime ||
                          status.state == RuntimeState.preparing
                      ? null
                      : () => runGame(stop: true),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop game'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canLaunch =
        details != null &&
        runtime != null &&
        runtime!.state != RuntimeState.unavailable;
    return PopScope(
      canPop: !saving && !requestingRuntime,
      child: NexusBackdrop(
        tint: GameArtwork.accentOf(
          details?.game.title ?? widget.initialTitle ?? '',
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Game details'),
            automaticallyImplyLeading: !saving && !requestingRuntime,
          ),
          bottomNavigationBar: canLaunch ? launchBar(context) : null,
          body: SafeArea(
            bottom: !canLaunch,
            child: ShellPage(
              showTitle: details == null && widget.initialTitle == null,
              banner: switch (details?.game.title ?? widget.initialTitle) {
                final coverTitle? => _GameBanner(
                  title: coverTitle,
                  heroTag: 'game-art-${widget.gameId}',
                  ready: details?.game.executableRelativePath != null,
                  loaded: details != null,
                ),
                null => null,
              },
              title:
                  details?.game.title ?? widget.initialTitle ?? 'Imported game',
              description:
                  'Stored on this device. Windows launching is experimental and compatibility is unverified.',
              children: [
                if (loading || saving) ...[
                  const LinearProgressIndicator(
                    semanticsLabel: 'Updating game details',
                  ),
                  const SizedBox(height: 16),
                ],
                if (error case final message?) ...[
                  Semantics(
                    liveRegion: true,
                    child: NoteText(message, icon: Icons.error_outline),
                  ),
                  if (details == null && !loading) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry details'),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                if (details case final data?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _StatStrip(
                      stats: [
                        (
                          Icons.folder_outlined,
                          'Size',
                          formatLibraryBytes(data.game.sizeBytes),
                        ),
                        (
                          Icons.description_outlined,
                          'Files',
                          '${data.game.fileCount}',
                        ),
                        (
                          Icons.schedule,
                          'Imported',
                          formatImportedAt(data.game.importedAtMillis),
                        ),
                        if (data.game.architecture case final arch?)
                          (Icons.memory, 'Arch', arch),
                      ],
                    ),
                  ),
                if (details case final data?) ...[
                  if (runtime != null)
                    AnimatedSize(
                      duration: NexusMotion.medium,
                      curve: NexusMotion.curve,
                      alignment: Alignment.topCenter,
                      child: runtimeCard(context),
                    ),
                  SectionCard(
                    title: 'Details',
                    icon: Icons.tune,
                    children: [
                      TextField(
                        controller: title,
                        enabled: !saving && !runtimeBusy,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Game title',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: executable,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Windows executable',
                        ),
                        hint: const Text('Choose an executable'),
                        items: [
                          for (final candidate in data.executables)
                            DropdownMenuItem(
                              value: candidate.relativePath,
                              child: Text(
                                candidate.relativePath,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: saving || runtimeBusy
                            ? null
                            : (value) => setState(() => executable = value),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: saving || runtimeBusy || executable == null
                            ? null
                            : save,
                        icon: const Icon(Icons.check),
                        label: const Text('Save details'),
                      ),
                    ],
                  ),
                  SectionCard(
                    title: 'File information',
                    icon: Icons.fingerprint,
                    children: [
                      DeviceField(
                        'Imported copy',
                        '${formatFileCount(data.game.fileCount)} · ${formatLibraryBytes(data.game.sizeBytes)}',
                      ),
                      DeviceField(
                        'Imported',
                        formatImportedAt(data.game.importedAtMillis),
                      ),
                      DeviceField(
                        'Tree SHA-256',
                        data.game.contentHash,
                        selectable: true,
                      ),
                      for (final candidate in data.executables.where(
                        (candidate) => candidate.relativePath == executable,
                      )) ...[
                        DeviceField(
                          'Executable path',
                          candidate.relativePath,
                          selectable: true,
                        ),
                        DeviceField('Architecture', candidate.architecture),
                        DeviceField(
                          'Executable SHA-256',
                          candidate.sha256,
                          selectable: true,
                        ),
                      ],
                      const NoteText(
                        'Executable headers and hashes identify files. They do not establish game compatibility or file safety.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: saving || runtimeBusy ? null : remove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove imported copy'),
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

/// The wide cover at the top of a game page, with the title laid over it.
class _GameBanner extends StatelessWidget {
  const _GameBanner({
    required this.title,
    required this.heroTag,
    required this.ready,
    required this.loaded,
  });
  final String title;
  final Object heroTag;
  final bool ready;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameArtwork(
              title: title,
              heroTag: heroTag,
              radius: 0,
              showTitle: false,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loaded)
                      StatusPill(
                        label: ready ? 'Ready' : 'Needs setup',
                        color: ready ? scheme.primary : scheme.tertiary,
                        icon: ready
                            ? Icons.check_circle_rounded
                            : Icons.build_outlined,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label/value pairs in one row, like the stats under a SteamOS game banner.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});
  final List<(IconData, String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Wrap(
        runSpacing: 12,
        children: [
          for (final (icon, label, value) in stats)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 96),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: scheme.secondary),
                        const SizedBox(width: 6),
                        Text(
                          label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(value, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String formatImportedAt(int millis) {
  final t = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

String formatFileCount(int count) => count == 1 ? '1 file' : '$count files';

String formatLibraryBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
}
