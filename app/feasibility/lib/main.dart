import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const ProbeApp());

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.blue, brightness: Brightness.dark),
    home: const ProbeScreen(),
  );
}

class ProbeScreen extends StatefulWidget {
  const ProbeScreen({super.key});
  @override
  State<ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<ProbeScreen> {
  static const channel = MethodChannel('nexuspc/feasibility');
  String report = 'Run the device probe to collect hardware evidence.';
  bool busy = false;
  Future<void> probe() async {
    setState(() => busy = true);
    try {
      final result = await channel.invokeMapMethod<String, dynamic>('profile');
      if (mounted) {
        setState(
          () => report = const JsonEncoder.withIndent('  ').convert(result),
        );
      }
    } catch (error) {
      if (mounted) setState(() => report = 'Probe failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nexus-PC feasibility probe')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('Phase 0: hardware diagnostics. Game runtime is pending.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : probe,
            child: Text(busy ? 'Collecting…' : 'Run device probe'),
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                await channel.invokeMethod<void>('surface');
              } catch (error) {
                if (mounted) {
                  setState(() => report = 'Surface probe failed: $error');
                }
              }
            },
            child: const Text('Probe native Vulkan surface'),
          ),
          OutlinedButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: report)),
            child: const Text('Copy report'),
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                await channel.invokeMethod<void>('runtime');
              } catch (error) {
                if (mounted) setState(() => report = 'Runtime failed: $error');
              }
            },
            child: const Text('Run Windows smoke game'),
          ),
          const SizedBox(height: 16),
          SelectableText(report),
        ],
      ),
    ),
  );
}
