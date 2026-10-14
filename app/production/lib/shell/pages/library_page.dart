import 'package:flutter/material.dart';
import '../shell_widgets.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.onDevice});
  final VoidCallback onDevice;

  @override
  Widget build(BuildContext context) => ShellPage(
    title: 'Your library',
    description: 'Your PC game collection starts here.',
    children: [
      const Icon(Icons.folder_open_outlined, size: 64),
      const SizedBox(height: 24),
      Text('No games yet', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'Importing DRM-free game folders and archives is planned for Phase 3. Nothing has been imported or stored in this phase.',
      ),
      const SizedBox(height: 24),
      const FilledButton(
        onPressed: null,
        child: Text('Import games · Phase 3'),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: onDevice,
        child: const Text('Check your device'),
      ),
    ],
  );
}
