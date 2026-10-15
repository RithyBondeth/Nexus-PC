import 'dart:async';
import 'package:flutter/material.dart';
import '../platform/nexus_api.g.dart';
import '../shell/shell_widgets.dart';
import 'game_details_form.dart';
import 'library_controller.dart';
import 'library_widgets.dart';

class GameDetailsScreen extends StatefulWidget {
  const GameDetailsScreen({super.key, required this.api, required this.gameId});
  final NexusLibraryApi api;
  final String gameId;
  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  final title = TextEditingController();
  final form = GlobalKey<FormState>();
  GameDetails? details;
  String? selection;
  String? error;
  String? notice;
  bool loading = true;
  bool mutating = false;
  @override
  void initState() {
    super.initState();
    unawaited(read());
  }

  Future<void> read() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.getGame(widget.gameId);
      if (mounted) {
        setState(() {
          details = result;
          title.text = result.game.title;
          selection = result.game.executableRelativePath;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = libraryFailure(failure));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (mutating ||
        selection == null ||
        form.currentState?.validate() != true) {
      return;
    }
    setState(() {
      mutating = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.api.updateGame(
        widget.gameId,
        title.text,
        selection!,
      );
      if (mounted) {
        setState(() {
          details = GameDetails(
            game: result,
            executables: details!.executables,
          );
          title.text = result.title;
          notice = 'Details saved.';
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = libraryFailure(failure));
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove imported copy?'),
        scrollable: true,
        content: const Text(
          'This deletes all files in this app’s copy. Your source folder or ZIP is not changed. This cannot be undone; you can import the source again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove copy'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || mutating) return;
    setState(() {
      mutating = true;
      error = null;
      notice = null;
    });
    try {
      await widget.api.removeGame(widget.gameId);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = libraryFailure(failure));
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !mutating,
    child: Scaffold(
      appBar: AppBar(title: const Text('Imported copy')),
      body: SafeArea(
        top: false,
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: LibraryLoading(),
              )
            : details == null
            ? ShellPage(
                title: 'Game details',
                description: error ?? 'This copy could not be read.',
                children: [
                  OutlinedButton(
                    onPressed: read,
                    child: const Text('Retry details'),
                  ),
                ],
              )
            : GameDetailsForm(
                details: details!,
                formKey: form,
                title: title,
                selection: selection,
                onSelection: (value) => setState(() => selection = value),
                onSave: save,
                onRemove: remove,
                busy: mutating,
                error: error,
                notice: notice,
              ),
      ),
    ),
  );
}
