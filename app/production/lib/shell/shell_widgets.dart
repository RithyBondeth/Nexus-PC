import 'package:flutter/material.dart';
import 'shell_controller.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({
    super.key,
    required this.title,
    required this.description,
    required this.children,
  });
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: ListView(
        primary: false,
        key: PageStorageKey(title),
        padding: const EdgeInsets.all(24),
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    ),
  );
}

class RuntimeSummary extends StatelessWidget {
  const RuntimeSummary({super.key, required this.controller});
  final ShellController controller;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Runtime: ${controller.status?.state.name ?? 'unknown'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          controller.statusError ??
              controller.status?.message ??
              'Reading native runtime status…',
        ),
        if (controller.statusError != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: controller.refreshing ? null : controller.refresh,
            child: const Text('Retry status check'),
          ),
        ],
      ],
    ),
  );
}

class DeviceField extends StatelessWidget {
  const DeviceField(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class DeviceReadState extends StatelessWidget {
  const DeviceReadState({super.key, required this.controller});
  final ShellController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (controller.refreshing)
        const LinearProgressIndicator(
          semanticsLabel: 'Reading device information',
        ),
      if (controller.profileError case final error?) ...[
        Semantics(liveRegion: true, child: Text(error)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: controller.refreshing ? null : controller.refresh,
          child: const Text('Retry device check'),
        ),
      ],
    ],
  );
}
