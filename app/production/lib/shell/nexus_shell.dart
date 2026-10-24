import 'dart:async';
import 'package:flutter/material.dart';
import '../foundation/foundation_screen.dart';
import '../platform/nexus_platform.dart';
import 'pages/device_page.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'shell_controller.dart';

class NexusShell extends StatefulWidget {
  const NexusShell({
    super.key,
    required this.platform,
    this.libraryApi,
    required this.appearance,
    required this.onAppearanceChanged,
  });
  final NexusPlatform platform;
  final NexusLibraryApi? libraryApi;
  final ThemeMode appearance;
  final ValueChanged<ThemeMode> onAppearanceChanged;
  @override
  State<NexusShell> createState() => _NexusShellState();
}

class _NexusShellState extends State<NexusShell> {
  static const destinations = [
    (label: 'Home', icon: Icons.home_outlined),
    (label: 'Library', icon: Icons.folder_open_outlined),
    (label: 'Device', icon: Icons.memory_outlined),
    (label: 'Settings', icon: Icons.settings_outlined),
  ];
  late final ShellController controller;
  int selected = 0;

  @override
  void initState() {
    super.initState();
    controller = ShellController(widget.platform);
    unawaited(controller.refresh());
  }

  void select(int index) {
    setState(() => selected = index);
  }

  void openDiagnostics() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FoundationScreen(platform: widget.platform),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: selected == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && selected != 0) select(0);
    },
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final pages = IndexedStack(
            index: selected,
            children: [
              HomePage(
                controller: controller,
                onLibrary: () => select(1),
                onDevice: () => select(2),
              ),
              LibraryPage(api: widget.libraryApi, platform: widget.platform),
              DevicePage(
                controller: controller,
                onDiagnostics: openDiagnostics,
              ),
              SettingsPage(
                appearance: widget.appearance,
                onAppearanceChanged: widget.onAppearanceChanged,
              ),
            ],
          );
          return Scaffold(
            appBar: AppBar(title: const Text('Nexus-PC')),
            body: SafeArea(
              top: false,
              child: wide
                  ? Row(
                      children: [
                        NavigationRail(
                          scrollable: true,
                          selectedIndex: selected,
                          onDestinationSelected: select,
                          labelType: NavigationRailLabelType.all,
                          destinations: [
                            for (final destination in destinations)
                              NavigationRailDestination(
                                icon: Icon(destination.icon),
                                label: Text(destination.label),
                              ),
                          ],
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: pages),
                      ],
                    )
                  : pages,
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: select,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      for (final destination in destinations)
                        NavigationDestination(
                          icon: Icon(destination.icon),
                          label: destination.label,
                        ),
                    ],
                  ),
          );
        },
      ),
    ),
  );
}
