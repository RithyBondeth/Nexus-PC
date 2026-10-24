import 'dart:async';
import 'package:flutter/material.dart';
import '../platform/nexus_platform.dart';
import '../shell/shell_widgets.dart';
import 'library_controller.dart';

class GameDetailsPage extends StatefulWidget {
  const GameDetailsPage({
    super.key,
    required this.api,
    required this.gameId,
    this.platform,
  });
  final NexusLibraryApi api;
  final String gameId;
  final NexusPlatform? platform;

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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !requestingRuntime,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Game details'),
        automaticallyImplyLeading: !saving && !requestingRuntime,
      ),
      body: SafeArea(
        child: ShellPage(
          title: details?.game.title ?? 'Imported game',
          description:
              'Stored on this device. Windows launching is experimental and compatibility is unverified.',
          children: [
            if (loading || saving)
              const LinearProgressIndicator(
                semanticsLabel: 'Updating game details',
              ),
            if (error case final message?) ...[
              Semantics(liveRegion: true, child: Text(message)),
              if (details == null && !loading)
                OutlinedButton(
                  onPressed: load,
                  child: const Text('Retry details'),
                ),
              const SizedBox(height: 16),
            ],
            if (details case final data?) ...[
              TextField(
                controller: title,
                enabled: !saving && !runtimeBusy,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Game title'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
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
              FilledButton(
                onPressed: saving || runtimeBusy || executable == null
                    ? null
                    : save,
                child: const Text('Save details'),
              ),
              if (runtime?.state == RuntimeState.unavailable)
                Text(runtime!.message),
              if (runtime != null &&
                  runtime!.state != RuntimeState.unavailable) ...[
                const SizedBox(height: 16),
                Text(runtime!.message),
                const Text(
                  'Only run games you trust. The Windows runtime can access Nexus-PC app data. Keep this screen open during preparation.',
                ),
                if (unsavedChanges)
                  const Text('Save your changes before launching.'),
                FilledButton(
                  onPressed:
                      saving ||
                          runtimeBusy ||
                          unsavedChanges ||
                          details!.game.executableRelativePath == null ||
                          details!.game.architecture != 'x86_64'
                      ? null
                      : () => runGame(),
                  child: const Text('Launch game (experimental)'),
                ),
                if (runtimeBusy)
                  OutlinedButton(
                    onPressed:
                        requestingRuntime ||
                            runtime!.state == RuntimeState.preparing
                        ? null
                        : () => runGame(stop: true),
                    child: const Text('Stop game'),
                  ),
              ],
              const SizedBox(height: 24),
              DeviceField(
                'Imported copy',
                '${data.game.fileCount} files · ${formatLibraryBytes(data.game.sizeBytes)}',
              ),
              DeviceField(
                'Imported',
                DateTime.fromMillisecondsSinceEpoch(
                  data.game.importedAtMillis,
                ).toLocal().toString(),
              ),
              DeviceField('Tree SHA-256', data.game.contentHash),
              for (final candidate in data.executables.where(
                (candidate) => candidate.relativePath == executable,
              )) ...[
                DeviceField('Executable path', candidate.relativePath),
                DeviceField('Architecture', candidate.architecture),
                DeviceField('Executable SHA-256', candidate.sha256),
              ],
              const Text(
                'Executable headers and hashes identify files. They do not establish game compatibility or file safety.',
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: saving || runtimeBusy ? null : remove,
                child: const Text('Remove imported copy'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String formatLibraryBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
}
