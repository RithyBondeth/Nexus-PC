import 'package:flutter/material.dart';
import 'shell/nexus_shell.dart';
import 'platform/nexus_platform.dart';

void main() => runApp(const NexusApp());

class NexusApp extends StatefulWidget {
  const NexusApp({super.key, this.platform});
  final NexusPlatform? platform;
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
    theme: ThemeData(
      colorSchemeSeed: Colors.blue,
      brightness: Brightness.light,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.blue,
      brightness: Brightness.dark,
    ),
    themeMode: appearance,
    home: NexusShell(
      platform: platform,
      appearance: appearance,
      onAppearanceChanged: (value) => setState(() => appearance = value),
    ),
  );
}
