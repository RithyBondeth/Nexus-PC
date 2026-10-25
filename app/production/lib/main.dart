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
  runApp(const NexusApp());
}

class NexusApp extends StatefulWidget {
  const NexusApp({super.key, this.platform, this.libraryApi});
  final NexusPlatform? platform;
  final NexusLibraryApi? libraryApi;
  @override
  State<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends State<NexusApp> {
  late final NexusPlatform platform = widget.platform ?? PigeonNexusPlatform();
  ThemeMode appearance = ThemeMode.system;
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
      onAppearanceChanged: (value) => setState(() => appearance = value),
    ),
  );
}
