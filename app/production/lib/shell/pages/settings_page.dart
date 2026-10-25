import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../platform/nexus_platform.dart';
import '../diagnostic_report.dart';
import '../shell_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.appearance,
    required this.onAppearanceChanged,
    this.platform,
  });
  final ThemeMode appearance;
  final ValueChanged<ThemeMode> onAppearanceChanged;
  final NexusPlatform? platform;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _themes = [
    (ThemeMode.system, 'Follow system', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];
  BuildInfo? buildInfo;
  bool buildFailed = false;
  bool collecting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_readBuild());
  }

  Future<void> _readBuild() async {
    final platform = widget.platform;
    if (platform == null) return;
    try {
      final value = await platform.getBuildInfo().timeout(
        const Duration(seconds: 5),
      );
      if (mounted) setState(() => buildInfo = value);
    } catch (_) {
      if (mounted) setState(() => buildFailed = true);
    }
  }

  Future<void> _report() async {
    final platform = widget.platform;
    if (platform == null || collecting) return;
    setState(() => collecting = true);
    final report = await collectDiagnosticReport(platform);
    if (!mounted) return;
    setState(() => collecting = false);
    await showDialog<void>(
      context: context,
      builder: (context) => _ReportPreview(report: report, platform: platform),
    );
  }

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
            groupValue: widget.appearance,
            onChanged: (value) {
              if (value != null) widget.onAppearanceChanged(value);
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
            'Applies immediately and is remembered on this device.',
          ),
          const SizedBox(height: 8),
        ],
      ),
      SectionCard(
        title: 'About this build',
        icon: Icons.info_outline,
        children: [
          if (buildInfo case final info?)
            SpecGrid(
              specs: [
                ('Version', '${info.versionName} (${info.versionCode})'),
                ('Build', info.buildType),
                ('Source', info.commit),
                (
                  'Windows runtime',
                  info.runtimePackaged
                      ? 'Included (experimental)'
                      : 'Not included',
                ),
              ],
            )
          else if (buildFailed)
            const NoteText(
              'Build details are unavailable.',
              icon: Icons.error_outline,
            ),
          const SizedBox(height: 12),
          const DeviceField('Development stage', 'Phase 3 · Local library'),
          const NoteText(
            'Cloud profiles are not integrated, and no runtime tuning switches are available yet. Windows launching requires the experimental runtime build.',
          ),
        ],
      ),
      if (widget.platform != null)
        SectionCard(
          title: 'Help & feedback',
          icon: Icons.bug_report_outlined,
          children: [
            const NoteText(
              'Found a problem? Share a diagnostic report with the Nexus-PC team. You can review it before anything is sent.',
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: collecting ? null : _report,
              icon: collecting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.description_outlined),
              label: const Text('Share diagnostic report'),
            ),
          ],
        ),
    ],
  );
}

/// Shows exactly what would be shared, then copies or hands it to Android.
class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.report, required this.platform});
  final String report;
  final NexusPlatform platform;

  void _notify(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Diagnostic report'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NoteText(
              'Contains build, device and recent app log details. No game files or library list.',
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    report,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: report));
            if (context.mounted) {
              Navigator.pop(context);
              _notify(context, 'Report copied');
            }
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await platform.shareText('Nexus-PC diagnostic report', report);
              if (context.mounted) Navigator.pop(context);
            } catch (_) {
              if (context.mounted) {
                _notify(
                  context,
                  'Sharing is unavailable. Copy the report instead.',
                );
              }
            }
          },
          child: const Text('Share'),
        ),
      ],
    );
  }
}
