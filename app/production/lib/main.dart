import 'package:flutter/material.dart';
import 'foundation/foundation_screen.dart';
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
  @override
  void dispose() {
    if (widget.platform == null) platform.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nexus-PC',
    theme: ThemeData(colorSchemeSeed: Colors.blue, brightness: Brightness.dark),
    home: FoundationScreen(platform: platform),
  );
}
