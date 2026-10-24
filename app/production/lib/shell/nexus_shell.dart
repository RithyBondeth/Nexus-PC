import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../foundation/foundation_screen.dart';
import '../platform/nexus_platform.dart';
import 'pages/device_page.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'shell_controller.dart';
import '../library/library_controller.dart';
import '../theme/nexus_theme.dart';

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
  late final LibraryController library;
  int selected = 0;

  @override
  void initState() {
    super.initState();
    controller = ShellController(widget.platform);
    library = LibraryController(widget.libraryApi ?? NexusLibraryApi());
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
    library.dispose();
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
          final pages = _FadeThroughStack(
            index: selected,
            children: [
              HomePage(
                controller: controller,
                library: library,
                onImport: (kind) {
                  select(1);
                  unawaited(library.begin(kind));
                },
                onLibrary: () => select(1),
                onDevice: () => select(2),
              ),
              LibraryPage(controller: library, platform: widget.platform),
              DevicePage(
                controller: controller,
                onDiagnostics: openDiagnostics,
              ),
              SettingsPage(
                platform: widget.platform,
                appearance: widget.appearance,
                onAppearanceChanged: widget.onAppearanceChanged,
              ),
            ],
          );
          return Scaffold(
            // Pages scroll beneath the floating bar; they pad for it.
            extendBody: !wide,
            appBar: AppBar(title: const Text('Nexus-PC')),
            body: SafeArea(
              top: false,
              bottom: false,
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
                : _FloatingNavBar(
                    selected: selected,
                    onSelected: select,
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

/// Keeps every tab alive like [IndexedStack] (scroll and state survive), and
/// fades the newly selected tab up into place.
class _FadeThroughStack extends StatefulWidget {
  const _FadeThroughStack({required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<_FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<_FadeThroughStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NexusMotion.medium,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: NexusMotion.curve,
  );

  @override
  void didUpdateWidget(_FadeThroughStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (NexusMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.015),
        end: Offset.zero,
      ).animate(_curve),
      child: IndexedStack(index: widget.index, children: widget.children),
    ),
  );
}

/// A blurred pill floating above the page, with a lime highlight that slides
/// to the selected destination. Built on [NavigationBar] for semantics and
/// keyboard behaviour.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selected,
    required this.onSelected,
    required this.destinations,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = destinations.length;
    final selectedColor = scheme.onPrimary;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.28 : 0.08,
              ),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainer.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedAlign(
                      alignment: Alignment(
                        count == 1 ? 0 : -1 + 2 * selected / (count - 1),
                        0,
                      ),
                      duration: NexusMotion.reduced(context)
                          ? Duration.zero
                          : NexusMotion.medium,
                      curve: Curves.easeOutBack,
                      child: FractionallySizedBox(
                        widthFactor: 1 / count,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  NavigationBarTheme(
                    data: theme.navigationBarTheme.copyWith(
                      backgroundColor: Colors.transparent,
                      indicatorColor: Colors.transparent,
                      height: 68,
                      iconTheme: WidgetStateProperty.resolveWith(
                        (states) => IconThemeData(
                          color: states.contains(WidgetState.selected)
                              ? selectedColor
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      labelTextStyle: WidgetStateProperty.resolveWith(
                        (states) => theme.textTheme.labelMedium?.copyWith(
                          color: states.contains(WidgetState.selected)
                              ? selectedColor
                              : scheme.onSurfaceVariant,
                          fontWeight: states.contains(WidgetState.selected)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    // Labels are short and the pill is narrow: cap their
                    // growth (as system bars do) so large text cannot
                    // overflow the floating bar.
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: NavigationBar(
                        selectedIndex: selected,
                        onDestinationSelected: onSelected,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        destinations: destinations,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
