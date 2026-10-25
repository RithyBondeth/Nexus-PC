import 'package:flutter/material.dart';
import '../platform/nexus_platform.dart';
import '../theme/nexus_theme.dart';
import 'game_artwork.dart';
import 'shell_controller.dart';

export 'game_artwork.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.eyebrow,
    this.banner,
    this.hero,
    this.showTitle = true,
  });
  final String title;
  final String description;
  final List<Widget> children;
  final String? eyebrow;

  /// Shown above the heading inside the page margins, e.g. a game's cover.
  final Widget? banner;

  /// Edge-to-edge artwork at the very top, drawn beneath the transparent top
  /// bar. It pads itself for the bar using [MediaQuery.paddingOf].
  final Widget? hero;

  /// False when the banner or hero already shows the title; it stays a
  /// semantic heading for screen readers.
  final bool showTitle;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final _opened = Stopwatch()..start();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.paddingOf(context);
    // Stagger sections in when the page first appears, not when they are
    // rebuilt later by scrolling or state changes.
    final entering = _opened.elapsedMilliseconds < 700;
    var index = 0;
    Widget reveal(Widget child) =>
        Reveal(index: index++, animate: entering, child: child);
    // Page content keeps a readable measure on tablets; the hero spans all.
    Widget measure(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
      ),
    );
    return ListView(
      primary: false,
      key: PageStorageKey(widget.title),
      // Includes room for the top bar and the docked bar it scrolls beneath.
      padding: EdgeInsets.only(
        top: widget.hero == null ? insets.top + 8 : 0,
        bottom: 28 + insets.bottom,
      ),
      children: [
        ?widget.hero,
        if (widget.banner case final banner?)
          measure(
            Padding(padding: const EdgeInsets.only(bottom: 16), child: banner),
          ),
        measure(
          reveal(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.eyebrow case final label? when widget.showTitle) ...[
                  Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (widget.showTitle) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else
                  Semantics(
                    header: true,
                    label: widget.title,
                    child: const SizedBox.shrink(),
                  ),
                if (widget.description.isNotEmpty)
                  Text(
                    widget.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        for (final child in widget.children) measure(reveal(child)),
      ],
    );
  }
}

/// Fades and lifts a child into place once, staggered by [index].
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.animate = true,
  });
  final Widget child;
  final int index;
  final bool animate;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  static const _step = 40;
  late final int _delay = _step * widget.index.clamp(0, 8);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NexusMotion.medium + Duration(milliseconds: _delay),
  );
  // The stagger is part of the curve, so no timers outlive the widget.
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay / _controller.duration!.inMilliseconds,
      1,
      curve: NexusMotion.curve,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (!widget.animate || NexusMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
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
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Shrinks slightly while pressed, for tactile cards and tiles.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});
  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;
  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _pressed && !NexusMotion.reduced(context) ? 0.97 : 1,
      duration: NexusMotion.quick,
      curve: NexusMotion.curve,
      child: widget.child,
    ),
  );
}

/// A bordered surface grouping one task or topic.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.children,
    this.title,
    this.icon,
    this.padding = const EdgeInsets.all(16),
  });
  final String? title;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title case final heading?) ...[
              Row(
                children: [
                  if (icon case final symbol?) ...[
                    IconBadge(symbol, size: 32),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        heading,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    ),
  );
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 40});
  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.secondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.55, color: tint),
    );
  }
}

/// Secondary explanatory copy with an information marker.
class NoteText extends StatelessWidget {
  const NoteText(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ExcludeSemantics(child: Icon(icon, size: 18, color: color)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

({IconData icon, Color color}) runtimeVisual(
  ColorScheme scheme,
  RuntimeState? state,
) => switch (state) {
  RuntimeState.running => (
    icon: Icons.play_circle_outline,
    color: scheme.primary,
  ),
  RuntimeState.preparing ||
  RuntimeState.stopping => (icon: Icons.sync, color: scheme.tertiary),
  RuntimeState.idle => (
    icon: Icons.check_circle_outline,
    color: scheme.primary,
  ),
  RuntimeState.failed => (icon: Icons.error_outline, color: scheme.error),
  _ => (icon: Icons.power_off_outlined, color: scheme.onSurfaceVariant),
};

class RuntimeSummary extends StatelessWidget {
  const RuntimeSummary({super.key, required this.controller});
  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = runtimeVisual(
      theme.colorScheme,
      controller.statusError == null ? controller.status?.state : null,
    );
    return SectionCard(
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: NexusMotion.medium,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: IconBadge(
                  visual.icon,
                  key: ValueKey(visual.icon),
                  color: visual.color,
                  size: 36,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Runtime: ${controller.status?.state.name ?? 'unknown'}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.statusError ??
                          controller.status?.message ??
                          'Reading native runtime status…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (controller.statusError != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: controller.refreshing ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry status check'),
          ),
        ],
      ],
    );
  }
}

class DeviceField extends StatelessWidget {
  const DeviceField(
    this.label,
    this.value, {
    super.key,
    this.selectable = false,
  });
  final String label;
  final String value;

  /// For identifiers worth copying, such as hashes and paths.
  final bool selectable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
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
        if (selectable)
          SelectableText(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          )
        else
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    ),
  );
}

/// Label/value tiles that reflow from one to three columns.
class SpecGrid extends StatelessWidget {
  const SpecGrid({super.key, required this.specs});
  final List<(String, String)> specs;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Two columns on phones at normal text sizes; one when text is enlarged.
      final large = MediaQuery.textScalerOf(context).scale(10) > 13;
      final columns = constraints.maxWidth >= 720
          ? 3
          : constraints.maxWidth >= 280 && !large
          ? 2
          : 1;
      const gap = 8.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      final scheme = Theme.of(context).colorScheme;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (label, value) in specs)
            Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: DeviceField(label, value),
            ),
        ],
      );
    },
  );
}

class DeviceReadState extends StatelessWidget {
  const DeviceReadState({super.key, required this.controller});
  final ShellController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.refreshing) ...[
        const LinearProgressIndicator(
          semanticsLabel: 'Reading device information',
        ),
        const SizedBox(height: 16),
      ],
      if (controller.profileError case final error?) ...[
        Semantics(
          liveRegion: true,
          child: NoteText(error, icon: Icons.error_outline),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: controller.refreshing ? null : controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry device check'),
        ),
        const SizedBox(height: 16),
      ],
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          IconBadge(icon, size: 64),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// An uppercase shelf heading, as above SteamOS rows, with an optional action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.action, this.onAction});
  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (action case final text?)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(text),
            ),
        ],
      ),
    );
  }
}

/// The Nexus-PC mark: three slanted bars, the middle one short. Matches the
/// landing page logo and favicon (landing/dist/assets/favicon.svg).
class NexusMark extends StatelessWidget {
  const NexusMark({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _NexusMarkPainter(color));
}

class _NexusMarkPainter extends CustomPainter {
  _NexusMarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final bar = s * 0.23;
    final gap = s * 0.16;
    final paint = Paint()..color = color;
    canvas
      ..translate(s / 2, s / 2)
      // skew(-22deg), as on the web mark.
      ..transform(Matrix4.skewX(-0.384).storage);
    for (final (i, height) in [(-1, 0.9), (0, 0.55), (1, 0.9)]) {
      final center = Offset(i * (bar + gap), 0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: bar, height: s * height),
          Radius.circular(s * 0.08),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NexusMarkPainter old) => old.color != color;
}

/// A compact rounded status label with a coloured dot or icon.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final symbol?)
            Icon(symbol, size: 14, color: color)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps a tappable surface with SteamOS-style focus: a blue ring, a soft
/// glow and a slight lift when focused by keyboard/controller or hovered.
class FocusGlow extends StatefulWidget {
  const FocusGlow({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 12,
    this.semanticLabel,
    this.selected = false,
    this.onFocused,
  });
  final Widget child;
  final VoidCallback onTap;
  final double radius;
  final String? semanticLabel;

  /// Keeps a lime ring while this is the chosen item, e.g. the hero's game.
  final bool selected;

  /// Called when keyboard or controller focus lands here.
  final VoidCallback? onFocused;

  @override
  State<FocusGlow> createState() => _FocusGlowState();
}

class _FocusGlowState extends State<FocusGlow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lit = _focused || _hovered;
    final reduced = NexusMotion.reduced(context);
    final radius = BorderRadius.circular(widget.radius);
    return PressScale(
      child: AnimatedScale(
        scale: lit && !reduced ? 1.03 : 1,
        duration: NexusMotion.quick,
        curve: NexusMotion.curve,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : NexusMotion.quick,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: lit
                ? [
                    BoxShadow(
                      color: scheme.secondary.withValues(alpha: 0.45),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: _focused
                  ? scheme.secondary
                  : widget.selected
                  ? scheme.primary
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              onFocusChange: (value) {
                setState(() => _focused = value);
                if (value) widget.onFocused?.call();
              },
              onHover: (value) => setState(() => _hovered = value),
              child: Semantics(
                button: true,
                label: widget.semanticLabel,
                child: ClipRRect(borderRadius: radius, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A portrait game cover in the SteamOS library style: generated artwork,
/// the title as real text and a readiness marker.
class GameCoverTile extends StatelessWidget {
  const GameCoverTile({
    super.key,
    required this.title,
    required this.heroTag,
    required this.ready,
    required this.subtitle,
    required this.onOpen,
    this.selected = false,
    this.onFocused,
  });
  final String title;
  final Object heroTag;
  final bool selected;
  final VoidCallback? onFocused;

  /// True once an executable is chosen.
  final bool ready;
  final String subtitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusGlow(
      onTap: onOpen,
      selected: selected,
      onFocused: onFocused,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameArtwork(
              title: title,
              heroTag: heroTag,
              radius: 0,
              showTitle: false,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    ready ? Icons.play_arrow_rounded : Icons.build_outlined,
                    size: 14,
                    color: ready ? NexusPalette.dark.accent : Colors.white70,
                  ),
                ),
              ),
            ),
            // The title is real text on the cover, so it stays readable by
            // screen readers and searchable.
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      shadows: const [
                        Shadow(color: Color(0x99000000), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ready ? Colors.white70 : const Color(0xFFFFB4A8),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cinematic header: art behind a dark scrim, always in the dark theme so
/// overlaid text stays legible, blending into the page below in either theme.
class DarkHero extends StatelessWidget {
  const DarkHero({super.key, required this.art, required this.child});

  /// Fills the hero behind the scrim.
  final Widget art;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const dark = NexusPalette.dark;
    final page = NexusPalette.of(context).backdrop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Theme(
          data: nexusTheme(Brightness.dark),
          child: Stack(
            children: [
              Positioned.fill(child: art),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.28, 0.62, 1],
                      colors: [
                        dark.backdrop.withValues(alpha: 0.55),
                        dark.backdrop.withValues(alpha: 0.05),
                        dark.backdrop.withValues(alpha: 0.82),
                        dark.backdrop,
                      ],
                    ),
                  ),
                ),
              ),
              DefaultTextStyle.merge(
                style: TextStyle(color: dark.text),
                child: child,
              ),
            ],
          ),
        ),
        // Blends the dark hero into a light page; invisible in dark mode.
        Container(
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [dark.backdrop, page.withValues(alpha: 0)],
            ),
          ),
        ),
      ],
    );
  }
}
