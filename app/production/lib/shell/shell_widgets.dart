import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../platform/nexus_platform.dart';
import '../theme/nexus_theme.dart';
import 'shell_controller.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.eyebrow,
    this.banner,
    this.showTitle = true,
  });
  final String title;
  final String description;
  final List<Widget> children;
  final String? eyebrow;

  /// Shown above the heading, e.g. a game's cover.
  final Widget? banner;

  /// False when the banner already shows the title; it stays a semantic
  /// heading for screen readers.
  final bool showTitle;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final _opened = Stopwatch()..start();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Stagger sections in when the page first appears, not when they are
    // rebuilt later by scrolling or state changes.
    final entering = _opened.elapsedMilliseconds < 700;
    var index = 0;
    Widget reveal(Widget child) =>
        Reveal(index: index++, animate: entering, child: child);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          primary: false,
          key: PageStorageKey(widget.title),
          // Includes room for a floating bar when the page scrolls beneath it.
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (widget.banner case final banner?)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: banner,
              ),
            reveal(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.eyebrow case final label?) ...[
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (widget.showTitle) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ] else
                    Semantics(
                      header: true,
                      label: widget.title,
                      child: const SizedBox.shrink(),
                    ),
                  Text(
                    widget.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            for (final child in widget.children) reveal(child),
          ],
        ),
      ),
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
    final tint = color ?? scheme.primary;
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

/// Generated cover art until real artwork exists. A gradient and geometric
/// pattern seeded from the title give each game a stable identity; large
/// covers carry the title, small ones its initial. Everything is painted, so
/// the cover adds no duplicate text to semantics or widget lookups.
class GameArtwork extends StatelessWidget {
  const GameArtwork({
    super.key,
    required this.title,
    this.size,
    this.heroTag,
    this.radius = 14,
    this.showTitle = true,
  });
  final String title;

  /// Paint the title on large covers; off when the caller overlays text.
  final bool showTitle;

  /// Square edge length; null fills the parent.
  final double? size;
  final Object? heroTag;
  final double radius;

  static const _gradients = [
    [Color(0xFF1E340A), Color(0xFF86B83A)],
    [Color(0xFF0C2F2D), Color(0xFF2E8A7F)],
    [Color(0xFF3F250D), Color(0xFFBC7B2E)],
    [Color(0xFF211740), Color(0xFF7458BF)],
    [Color(0xFF3D1021), Color(0xFFB9466A)],
  ];

  /// FNV-1a: stable across launches and well spread across styles.
  static int seedOf(String title) => title.codeUnits.fold(
    0x811c9dc5,
    (hash, unit) => ((hash ^ unit) * 0x01000193) & 0xffffffff,
  );

  @override
  Widget build(BuildContext context) {
    final seed = seedOf(title);
    Widget art = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _CoverPainter(
          seed: seed,
          colors: _gradients[seed % _gradients.length],
          title: title.trim().isEmpty ? '?' : title.trim(),
          showTitle: showTitle,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
        child: const SizedBox.expand(),
      ),
    );
    if (size case final edge?) {
      art = SizedBox.square(dimension: edge, child: art);
    }
    if (heroTag case final tag?) art = Hero(tag: tag, child: art);
    return ExcludeSemantics(child: art);
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter({
    required this.seed,
    required this.colors,
    required this.title,
    required this.showTitle,
    required this.fontFamily,
  });
  final int seed;
  final List<Color> colors;
  final String title;
  final bool showTitle;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final random = math.Random(seed);
    final edge = size.shortestSide;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: colors,
        ).createShader(rect),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = math.max(1, edge * 0.018);
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.09);
    switch ((seed >> 4) % 3) {
      case 0: // Concentric rings from a corner.
        final center = Offset(
          size.width * (0.7 + random.nextDouble() * 0.4),
          size.height * (random.nextDouble() * 0.3),
        );
        for (var ring = 1; ring <= 6; ring++) {
          canvas.drawCircle(center, edge * 0.16 * ring, line);
        }
        canvas.drawCircle(center, edge * 0.12, fill);
      case 1: // Diagonal stripes.
        final gap = edge * (0.09 + random.nextDouble() * 0.05);
        canvas.save();
        canvas.translate(size.width * 0.55, 0);
        canvas.rotate(-math.pi / 4);
        for (var x = -size.longestSide; x < size.longestSide * 2; x += gap) {
          if (random.nextDouble() < 0.35) continue;
          canvas.drawLine(
            Offset(x, -size.longestSide),
            Offset(x, size.longestSide * 2),
            line,
          );
        }
        canvas.restore();
      default: // Scattered triangles and dots.
        for (var i = 0; i < 9; i++) {
          final c = Offset(
            size.width * (0.35 + random.nextDouble() * 0.7),
            size.height * random.nextDouble() * 0.75,
          );
          final r = edge * (0.04 + random.nextDouble() * 0.12);
          if (i.isEven) {
            final angle = random.nextDouble() * math.pi;
            final path = Path();
            for (var k = 0; k < 3; k++) {
              final a = angle + k * 2 * math.pi / 3;
              final point = c + Offset(math.cos(a), math.sin(a)) * r;
              k == 0
                  ? path.moveTo(point.dx, point.dy)
                  : path.lineTo(point.dx, point.dy);
            }
            canvas.drawPath(path..close(), i % 4 == 0 ? fill : line);
          } else {
            canvas.drawCircle(c, r * 0.35, fill);
          }
        }
    }
    // A soft light source plus a bottom scrim keeps the title legible.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.7, -0.8),
          radius: 0.9,
          colors: [Colors.white.withValues(alpha: 0.14), Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.45, 1],
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.62)],
        ).createShader(rect),
    );
    final large = edge >= 96;
    if (large && !showTitle) return;
    final painter = TextPainter(
      text: TextSpan(
        text: large ? title : title.characters.first.toUpperCase(),
        style: TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w700,
          height: 1.1,
          letterSpacing: large ? -0.3 : 0,
          fontSize: large ? (edge * 0.15).clamp(14, 34) : edge * 0.44,
          shadows: const [Shadow(color: Color(0x80000000), blurRadius: 10)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: size.width * (large ? 0.84 : 1));
    final inset = edge * 0.08;
    painter.paint(
      canvas,
      large
          ? Offset(inset, size.height - painter.height - inset)
          : Offset(
              (size.width - painter.width) / 2,
              (size.height - painter.height) / 2,
            ),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.seed != seed ||
      old.title != title ||
      old.showTitle != showTitle ||
      old.fontFamily != fontFamily;
}
