import 'package:flutter/material.dart';
import '../platform/nexus_api.g.dart';
import '../shell/shell_widgets.dart';
import 'library_widgets.dart';

class GameDetailsForm extends StatelessWidget {
  const GameDetailsForm({
    super.key,
    required this.details,
    required this.formKey,
    required this.title,
    required this.selection,
    required this.onSelection,
    required this.onSave,
    required this.onRemove,
    required this.busy,
    this.error,
    this.notice,
  });
  final GameDetails details;
  final GlobalKey<FormState> formKey;
  final TextEditingController title;
  final String? selection;
  final ValueChanged<String?> onSelection;
  final VoidCallback onSave;
  final VoidCallback onRemove;
  final bool busy;
  final String? error;
  final String? notice;
  @override
  Widget build(BuildContext context) {
    final candidates = {
      for (final entry in details.executables) entry.relativePath: entry,
    };
    final candidate = candidates[selection];
    return ShellPage(
      title: 'Game details',
      description: details.game.title,
      children: [
        const Text(
          'Stored locally. Runtime is not integrated; importing does not establish compatibility.',
        ),
        const SizedBox(height: 16),
        if (error != null) Semantics(liveRegion: true, child: Text(error!)),
        if (notice != null) Semantics(liveRegion: true, child: Text(notice!)),
        if (busy)
          Semantics(liveRegion: true, child: const Text('Saving changes…')),
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: title,
                enabled: !busy,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Library title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        value.length > 120 ||
                        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)
                    ? 'Enter a title of 1–120 characters without control characters.'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(selection),
                initialValue: selection,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(
                  labelText: 'Windows executable',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Choose an imported executable'),
                items: [
                  for (final entry in details.executables)
                    DropdownMenuItem(
                      value: entry.relativePath,
                      child: Text(entry.relativePath),
                    ),
                ],
                onChanged: busy ? null : onSelection,
              ),
              if (selection == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Choose an executable before saving. No candidate is assumed for a multi-executable import.',
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: busy || selection == null ? null : onSave,
                    child: const Text('Save details'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : onRemove,
                    child: const Text('Remove imported copy'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (candidate != null) ...[
          DeviceField('Candidate path', candidate.relativePath),
          DeviceField('Candidate architecture', candidate.architecture),
          DeviceField('Candidate SHA-256', candidate.sha256),
        ],
        DeviceField('Copied size', libraryBytes(details.game.sizeBytes)),
        DeviceField('Copied files', details.game.fileCount.toString()),
        DeviceField('Copied tree SHA-256', details.game.contentHash),
        DeviceField(
          'Imported on',
          DateTime.fromMillisecondsSinceEpoch(
            details.game.importedAtMillis,
          ).toLocal().toIso8601String().split('T').first,
        ),
      ],
    );
  }
}
