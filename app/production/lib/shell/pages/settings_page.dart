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

  static const _themes = [
    (ThemeMode.system, 'Follow system', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) => ShellPage(
    eyebrow: 'Preferences',
    title: 'Settings',
    description:
        'Make this workspace yours. Only implemented preferences appear here.',
    children: [
      SectionCard(
        title: 'Appearance',
        icon: Icons.palette_outlined,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        children: [
          Text('Color theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          RadioGroup<ThemeMode>(
            groupValue: appearance,
            onChanged: (value) {
              if (value != null) onAppearanceChanged(value);
            },
            child: Column(
              children: [
                for (final (mode, label, icon) in _themes)
                  RadioListTile<ThemeMode>(
                    value: mode,
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(icon),
                    title: Text(label),
                  ),
              ],
            ),
          ),
          const NoteText(
            'Applies immediately. Saved for this session only; restarting the app follows your system theme.',
          ),
          const SizedBox(height: 8),
        ],
      ),
      const SectionCard(
        title: 'About this build',
        icon: Icons.info_outline,
        children: [
          DeviceField('Development stage', 'Phase 3 · Local library'),
          NoteText(
            'Cloud profiles are not integrated, and no runtime tuning switches are available yet. Windows launching requires the experimental runtime build.',
          ),
        ],
      ),
    ],
  );
}
