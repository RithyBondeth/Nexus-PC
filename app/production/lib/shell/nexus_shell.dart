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
import 'shell_widgets.dart';
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
    (
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    (
      label: 'Library',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
    (
      label: 'Device',
      icon: Icons.memory_outlined,
      selectedIcon: Icons.memory_rounded,
    ),
    (
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
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
                platform: widget.platform,
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
          return NexusBackdrop(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              // Pages scroll beneath the docked bar; they pad for it.
              extendBody: !wide,
              // Heroes run edge to edge beneath the scrimmed top bar.
              extendBodyBehindAppBar: true,
              appBar: _TopBar(
                controller: controller,
                wide: wide,
                // Home and Library open with a dark hero beneath the bar.
                overHero: selected <= 1,
              ),
              body: SafeArea(
                top: false,
                bottom: false,
                child: wide
                    ? Row(
                        children: [
                          _SideMenu(selected: selected, onSelected: select),
                          Expanded(child: pages),
                        ],
                      )
                    : pages,
              ),
              bottomNavigationBar: wide
                  ? null
                  : _DockBar(
                      selected: selected,
                      onSelected: select,
                      destinations: [
                        for (final destination in destinations)
                          NavigationDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: destination.label,
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
    ),
  );
}

/// SteamOS-style header: a wordmark on the left and live status on the right.
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.controller,
    required this.wide,
    required this.overHero,
  });
  final ShellController controller;
  final bool wide;

  /// Uses light text over a dark scrim to match the hero's art.
  final bool overHero;

  @override
  // Shorter beside the side menu, where landscape height is scarce.
  Size get preferredSize => Size.fromHeight(wide ? 52 : 60);

  @override
  Widget build(BuildContext context) => overHero
      ? Theme(
          data: nexusTheme(Brightness.dark),
          child: Builder(builder: _bar),
        )
      : _bar(context);

  Widget _bar(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = controller.statusError == null
        ? controller.status?.state
        : null;
    final visual = runtimeVisual(scheme, state);
    final runtimeLabel = switch (state) {
      RuntimeState.running => 'Game running',
      RuntimeState.preparing => 'Preparing',
      RuntimeState.stopping => 'Stopping',
      RuntimeState.idle => 'Runtime ready',
      RuntimeState.failed => 'Runtime error',
      RuntimeState.unavailable => 'Runtime off',
      null when controller.statusError != null => 'Status unknown',
      null => 'Checking…',
    };
    final fade = scheme.surfaceContainerLowest;
    return AppBar(
      toolbarHeight: wide ? 52 : 60,
      // A scrim instead of a solid bar: art shows through at the top while
      // the title and status stay readable over any page.
      flexibleSpace: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fade.withValues(alpha: 0.92), fade.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
      titleSpacing: 20,
      title: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary],
                ),
              ),
              child: Icon(
                Icons.sports_esports_rounded,
                size: 18,
                color: scheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text('Nexus-PC', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Tooltip(
            message: controller.status?.message ?? 'Windows runtime status',
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              // On narrow screens the dot alone carries the state; the
              // tooltip and Device page give the details.
              child: MediaQuery.sizeOf(context).width < 400
                  ? Semantics(
                      label: runtimeLabel,
                      child: StatusPill(label: '', color: visual.color),
                    )
                  : StatusPill(label: runtimeLabel, color: visual.color),
            ),
          ),
        ),
      ],
    );
  }
}

/// The landscape and tablet menu: a column of large destinations on a glass
/// panel, like the SteamOS main menu. Scrolls when enlarged text overflows.
class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top,
        0,
        12,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: NavigationRail(
          scrollable: true,
          minWidth: 84,
          groupAlignment: -1,
          selectedIndex: selected,
          onDestinationSelected: onSelected,
          labelType: NavigationRailLabelType.all,
          destinations: [
            for (final destination in _NexusShellState.destinations)
              NavigationRailDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: Text(destination.label),
              ),
          ],
        ),
      ),
    );
  }
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

/// A docked glass bar, as on the Steam Deck: the selected destination is lit
/// lime with a short bar that slides along the top edge. Built on
/// [NavigationBar] for semantics and keyboard behaviour.
class _DockBar extends StatelessWidget {
  const _DockBar({
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer.withValues(alpha: 0.82),
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: Alignment(
                      count == 1 ? 0 : -1 + 2 * selected / (count - 1),
                      -1,
                    ),
                    duration: NexusMotion.reduced(context)
                        ? Duration.zero
                        : NexusMotion.medium,
                    curve: NexusMotion.curve,
                    child: FractionallySizedBox(
                      widthFactor: 1 / count,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 36,
                          height: 3,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.6),
                                blurRadius: 10,
                              ),
                            ],
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
                    height: 64,
                    iconTheme: WidgetStateProperty.resolveWith(
                      (states) => IconThemeData(
                        color: states.contains(WidgetState.selected)
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    labelTextStyle: WidgetStateProperty.resolveWith(
                      (states) => theme.textTheme.labelMedium?.copyWith(
                        color: states.contains(WidgetState.selected)
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontWeight: states.contains(WidgetState.selected)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  // Labels are short: cap their growth (as system bars do)
                  // so large text cannot overflow the bar.
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
    );
  }
}
