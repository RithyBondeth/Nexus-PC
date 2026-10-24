import 'package:flutter/material.dart';
import '../shell_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.appearance,
    required this.onAppearanceChanged,
  });
  final ThemeMode appearance;
  final ValueChanged<ThemeMode> onAppearanceChanged;

  @override
  Widget build(BuildContext context) => ShellPage(
    title: 'Settings',
    description:
        'Make this workspace yours. Only implemented preferences appear here.',
    children: [
      Semantics(
        header: true,
        child: Text(
          'Appearance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<ThemeMode>(
        key: ValueKey(appearance),
        initialValue: appearance,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Color theme',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('Follow system'),
          ),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
        ],
        onChanged: (value) {
          if (value != null) onAppearanceChanged(value);
        },
      ),
      const SizedBox(height: 12),
      const Text(
        'Applies immediately. Saved for this session only; restarting the app follows your system theme.',
      ),
      const SizedBox(height: 32),
      Semantics(
        header: true,
        child: Text(
          'About this build',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 16),
      const DeviceField('Development stage', 'Phase 2 · Application shell'),
      const Text(
        'Game import, cloud profiles and the Windows engine are not integrated. No runtime tuning switches are available yet.',
      ),
    ],
  );
}
