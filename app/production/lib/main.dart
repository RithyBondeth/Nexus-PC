import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shell/nexus_shell.dart';
import 'platform/nexus_platform.dart';
import 'theme/nexus_theme.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Ubuntu font',
    ], await rootBundle.loadString('assets/fonts/ubuntu/UFL.txt'));
  });
  runApp(const NexusApp(restoreAppearance: true));
}

class NexusApp extends StatefulWidget {
  const NexusApp({
    super.key,
    this.platform,
    this.libraryApi,
    this.restoreAppearance = false,
  });
  final NexusPlatform? platform;
  final NexusLibraryApi? libraryApi;

  /// Apply the saved theme choice once it is read from Android.
  final bool restoreAppearance;
  @override
  State<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends State<NexusApp> {
  late final NexusPlatform platform = widget.platform ?? PigeonNexusPlatform();
  ThemeMode appearance = ThemeMode.system;
  bool _chosen = false;

  @override
  void initState() {
    super.initState();
    if (widget.restoreAppearance) unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final saved = await platform.getAppearance().timeout(
        const Duration(seconds: 2),
      );
      // A choice made while reading wins over the stored one.
      if (mounted && !_chosen) setState(() => appearance = saved);
    } catch (_) {
      // Keep following the system theme if the preference cannot be read.
    }
  }

  void _choose(ThemeMode value) {
    _chosen = true;
    setState(() => appearance = value);
    unawaited(
      platform.setAppearance(value).catchError((Object _) {
        // The choice still applies for this session.
      }),
    );
  }

  @override
  void dispose() {
    if (widget.platform == null) platform.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nexus-PC',
    theme: nexusTheme(Brightness.light),
    darkTheme: nexusTheme(Brightness.dark),
    themeMode: appearance,
    home: NexusShell(
      platform: platform,
      libraryApi: widget.libraryApi,
      appearance: appearance,
      onAppearanceChanged: _choose,
    ),
  );
}
