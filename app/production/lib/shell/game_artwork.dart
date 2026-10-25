import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Generated poster art until real artwork exists. Each title seeds one of
/// several painted scenes (mountain dusk, synthwave grid, deep space, night
/// city, crystal shards) and a palette, so every game keeps a stable,
/// store-like identity. Everything is painted, so the art adds no duplicate
/// text to semantics or widget lookups.
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

  /// Paint the title as a poster logo; off when the caller overlays text.
  final bool showTitle;

  /// Square edge length; null fills the parent.
  final double? size;
  final Object? heroTag;
  final double radius;

  /// Sky top, sky horizon, sun/glow, far ridge, near ridge.
  static const palettes = <List<Color>>[
    [
      Color(0xFF0B1A3A),
      Color(0xFFE0705A),
      Color(0xFFFFD27A),
      Color(0xFF5A3A6E),
      Color(0xFF1C1430),
    ],
    [
      Color(0xFF061A2E),
      Color(0xFF1A9FFF),
      Color(0xFFB9F0FF),
      Color(0xFF16466E),
      Color(0xFF07182A),
    ],
    [
      Color(0xFF14082A),
      Color(0xFFD4377E),
      Color(0xFFFFB347),
      Color(0xFF5B1F5E),
      Color(0xFF1A0A24),
    ],
    [
      Color(0xFF07160C),
      Color(0xFF7CC04A),
      Color(0xFFE6FF9E),
      Color(0xFF2C5A2A),
      Color(0xFF0B1F10),
    ],
    [
      Color(0xFF1A1032),
      Color(0xFF8063D6),
      Color(0xFFE0D2FF),
      Color(0xFF3C2C78),
      Color(0xFF120B26),
    ],
    [
      Color(0xFF1E0E06),
      Color(0xFFE8873A),
      Color(0xFFFFE3A3),
      Color(0xFF7A3A1C),
      Color(0xFF26110A),
    ],
  ];

  /// FNV-1a: stable across launches and well spread across styles.
  static int seedOf(String title) => title.codeUnits.fold(
    0x811c9dc5,
    (hash, unit) => ((hash ^ unit) * 0x01000193) & 0xffffffff,
  );

  static List<Color> paletteOf(String title) =>
      palettes[seedOf(title) % palettes.length];

  /// The scene's brightest colour, for tinting a backdrop or glow.
  static Color accentOf(String title) => paletteOf(title)[1];

  @override
  Widget build(BuildContext context) {
    final seed = seedOf(title);
    Widget art = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ScenePainter(
            seed: seed,
            colors: palettes[seed % palettes.length],
            title: title.trim().isEmpty ? '?' : title.trim(),
            showTitle: showTitle,
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    if (size case final edge?) {
      art = SizedBox.square(dimension: edge, child: art);
    }
    if (heroTag case final tag?) art = Hero(tag: tag, child: art);
    return ExcludeSemantics(child: art);
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
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

  Color get skyTop => colors[0];
  Color get horizon => colors[1];
  Color get glow => colors[2];
  Color get far => colors[3];
  Color get near => colors[4];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final random = math.Random(seed);
    final horizonY = size.height * (0.56 + random.nextDouble() * 0.1);
    switch ((seed >> 5) % 5) {
      case 0:
        _peaks(canvas, size, random, horizonY);
      case 1:
        _synthwave(canvas, size, random, horizonY);
      case 2:
        _space(canvas, size, random);
      case 3:
        _city(canvas, size, random, horizonY);
      default:
        _shards(canvas, size, random);
    }
    // Vignette and a bottom scrim give every scene depth and keep overlaid
    // text legible.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.5, 1],
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
        ).createShader(rect),
    );
    if (showTitle) _logo(canvas, size);
  }

  void _sky(Canvas canvas, Size size, double horizonY) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, horizonY / size.height, 1],
          colors: [skyTop, horizon, near],
        ).createShader(Offset.zero & size),
    );
  }

  void _sun(Canvas canvas, Offset center, double radius, {bool bands = false}) {
    canvas.drawCircle(
      center,
      radius * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [glow.withValues(alpha: 0.55), glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.6)),
    );
    final disc = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [glow, horizon],
      ).createShader(disc);
    if (!bands) {
      canvas.drawCircle(center, radius, paint);
      return;
    }
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    final band = radius * 0.13;
    for (var y = disc.top; y < disc.bottom; y += band) {
      final progress = (y - disc.top) / disc.height;
      final gap = progress < 0.45 ? 0.0 : band * (progress - 0.4) * 1.1;
      canvas.drawRect(
        Rect.fromLTRB(disc.left, y, disc.right, y + band - gap),
        paint,
      );
    }
    canvas.restore();
  }

  /// A jagged ridge from left to right, filled down to the bottom edge.
  Path _ridge(Size size, math.Random random, double base, double height) {
    final path = Path()..moveTo(0, size.height);
    final steps = 7 + random.nextInt(5);
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final y = base - height * (0.25 + random.nextDouble() * 0.75);
      path.lineTo(x, y);
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }

  void _stars(Canvas canvas, Size size, math.Random random, double maxY) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 46; i++) {
      final p = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * maxY,
      );
      paint.color = Colors.white.withValues(
        alpha: 0.25 + random.nextDouble() * 0.6,
      );
      canvas.drawCircle(
        p,
        size.shortestSide * (0.002 + random.nextDouble() * 0.005),
        paint,
      );
    }
  }

  void _peaks(Canvas canvas, Size size, math.Random random, double horizonY) {
    _sky(canvas, size, horizonY);
    _stars(canvas, size, random, horizonY * 0.5);
    _sun(
      canvas,
      Offset(size.width * (0.3 + random.nextDouble() * 0.4), horizonY * 0.82),
      size.shortestSide * 0.17,
    );
    final layers = [far, Color.lerp(far, near, 0.55)!, near];
    for (var i = 0; i < layers.length; i++) {
      final base = horizonY + size.height * 0.07 * i;
      canvas.drawPath(
        _ridge(size, random, base, size.height * (0.28 - i * 0.06)),
        Paint()..color = layers[i],
      );
      // A thin haze line on each ridge suggests atmosphere.
      canvas.drawRect(
        Rect.fromLTWH(0, base - 2, size.width, size.height * 0.04),
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [horizon.withValues(alpha: 0.18), Colors.transparent],
              ).createShader(
                Rect.fromLTWH(0, base, size.width, size.height * 0.04),
              ),
      );
    }
  }

  void _synthwave(
    Canvas canvas,
    Size size,
    math.Random random,
    double horizonY,
  ) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, horizonY / size.height, 1],
          colors: [skyTop, Color.lerp(horizon, skyTop, 0.35)!, skyTop],
        ).createShader(Offset.zero & size),
    );
    _stars(canvas, size, random, horizonY * 0.6);
    _sun(
      canvas,
      Offset(size.width / 2, horizonY - size.shortestSide * 0.06),
      size.shortestSide * 0.24,
      bands: true,
    );
    canvas.drawPath(
      _ridge(size, random, horizonY, size.height * 0.1),
      Paint()..color = far,
    );
    final floor = Rect.fromLTRB(0, horizonY, size.width, size.height);
    canvas.drawRect(floor, Paint()..color = skyTop);
    final line = Paint()
      ..color = horizon.withValues(alpha: 0.8)
      ..strokeWidth = math.max(1, size.shortestSide * 0.006);
    final vanish = Offset(size.width / 2, horizonY);
    for (var i = -10; i <= 10; i++) {
      canvas.drawLine(
        vanish,
        Offset(size.width / 2 + i * size.width * 0.16, size.height),
        line,
      );
    }
    for (var k = 1; k <= 9; k++) {
      final t = math.pow(k / 9, 2.2).toDouble();
      final y = horizonY + (size.height - horizonY) * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - 3, size.width, 6),
      Paint()
        ..color = glow.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _space(Canvas canvas, Size size, math.Random random) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = skyTop);
    for (var i = 0; i < 3; i++) {
      final c = Offset(
        size.width * random.nextDouble(),
        size.height * random.nextDouble() * 0.8,
      );
      final r = size.longestSide * (0.3 + random.nextDouble() * 0.3);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              (i.isEven ? horizon : far).withValues(alpha: 0.45),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    _stars(canvas, size, random, size.height);
    final planet = Offset(
      size.width * (0.55 + random.nextDouble() * 0.25),
      size.height * (0.32 + random.nextDouble() * 0.15),
    );
    final r = size.shortestSide * (0.24 + random.nextDouble() * 0.08);
    final ring = Rect.fromCenter(
      center: planet,
      width: r * 3.4,
      height: r * 0.9,
    );
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..color = glow.withValues(alpha: 0.65);
    canvas.save();
    canvas.translate(planet.dx, planet.dy);
    canvas.rotate(-0.35);
    canvas.translate(-planet.dx, -planet.dy);
    canvas.drawArc(ring, math.pi, math.pi, false, ringPaint);
    canvas.drawCircle(
      planet,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [glow, horizon, near],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: planet, radius: r)),
    );
    canvas.drawArc(ring, 0, math.pi, false, ringPaint);
    canvas.restore();
    // A small moon for scale.
    final moon = Offset(size.width * 0.2, size.height * 0.62);
    canvas.drawCircle(
      moon,
      r * 0.22,
      Paint()..color = Color.lerp(glow, far, 0.5)!,
    );
  }

  void _city(Canvas canvas, Size size, math.Random random, double horizonY) {
    _sky(canvas, size, horizonY);
    _stars(canvas, size, random, horizonY * 0.55);
    final moon = Offset(size.width * 0.75, size.height * 0.2);
    canvas.drawCircle(
      moon,
      size.shortestSide * 0.3,
      Paint()
        ..shader =
            RadialGradient(
              colors: [glow.withValues(alpha: 0.35), Colors.transparent],
            ).createShader(
              Rect.fromCircle(center: moon, radius: size.shortestSide * 0.3),
            ),
    );
    canvas.drawCircle(moon, size.shortestSide * 0.08, Paint()..color = glow);
    for (final (layer, color) in [(0, far), (1, near)]) {
      var x = -random.nextDouble() * size.width * 0.05;
      while (x < size.width) {
        final w = size.width * (0.07 + random.nextDouble() * 0.1);
        final h =
            size.height * (0.12 + random.nextDouble() * (0.3 - layer * 0.08));
        final top = horizonY + size.height * 0.08 * layer - h;
        final building = Rect.fromLTWH(x, top, w, size.height - top);
        canvas.drawRect(building, Paint()..color = color);
        if (layer == 1) {
          final window = Paint();
          final cell = w / 4;
          for (
            var wy = top + cell;
            wy < horizonY + cell * 3;
            wy += cell * 1.4
          ) {
            for (var wx = x + cell * 0.6; wx < x + w - cell; wx += cell * 1.2) {
              if (random.nextDouble() < 0.4) continue;
              window.color = glow.withValues(
                alpha: 0.4 + random.nextDouble() * 0.5,
              );
              canvas.drawRect(
                Rect.fromLTWH(wx, wy, cell * 0.5, cell * 0.6),
                window,
              );
            }
          }
        }
        x += w + size.width * 0.01;
      }
    }
  }

  void _shards(Canvas canvas, Size size, math.Random random) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [horizon, far, skyTop],
        ).createShader(rect),
    );
    for (var i = 0; i < 9; i++) {
      final c = Offset(
        size.width * random.nextDouble(),
        size.height * random.nextDouble(),
      );
      final r = size.shortestSide * (0.15 + random.nextDouble() * 0.35);
      final a = random.nextDouble() * math.pi;
      final path = Path();
      for (var k = 0; k < 3; k++) {
        final angle = a + k * 2 * math.pi / 3 + random.nextDouble() * 0.4;
        final p = c + Offset(math.cos(angle), math.sin(angle)) * r;
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              glow.withValues(alpha: 0.5),
              horizon.withValues(alpha: 0.05),
            ],
          ).createShader(path.getBounds()),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.25),
      );
    }
    final c = Offset(size.width * 0.5, size.height * 0.4);
    canvas.drawCircle(
      c,
      size.shortestSide * 0.45,
      Paint()
        ..shader =
            RadialGradient(
              colors: [glow.withValues(alpha: 0.5), Colors.transparent],
            ).createShader(
              Rect.fromCircle(center: c, radius: size.shortestSide * 0.45),
            ),
    );
  }

  /// The title as a poster logo: heavy, tracked capitals with a soft glow.
  void _logo(Canvas canvas, Size size) {
    final edge = size.shortestSide;
    final large = edge >= 96;
    final style = TextStyle(
      fontFamily: fontFamily,
      color: Colors.white,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: large ? edge * 0.012 : 0,
      fontSize: large ? (edge * 0.14).clamp(14, 44) : edge * 0.44,
      shadows: [
        Shadow(color: horizon.withValues(alpha: 0.9), blurRadius: 18),
        const Shadow(color: Color(0xB3000000), blurRadius: 6),
      ],
    );
    final painter = TextPainter(
      text: TextSpan(
        text: large
            ? title.toUpperCase()
            : title.characters.first.toUpperCase(),
        style: style,
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: size.width * 0.86);
    final offset = Offset(
      (size.width - painter.width) / 2,
      large
          ? size.height * 0.78 - painter.height / 2
          : (size.height - painter.height) / 2,
    );
    painter.paint(canvas, offset);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.seed != seed ||
      old.title != title ||
      old.showTitle != showTitle ||
      old.fontFamily != fontFamily;
}

/// The art of the focused game, blurred and dimmed into a full backdrop,
/// cross-fading when focus moves, as on the SteamOS home screen.
class ArtBackdrop extends StatelessWidget {
  const ArtBackdrop({super.key, required this.title, required this.fade});
  final String? title;

  /// The colour the art fades into at the bottom.
  final Color fade;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? Duration.zero
        : const Duration(milliseconds: 600),
    child: SizedBox.expand(
      key: ValueKey(title),
      child: title == null
          ? const SizedBox.shrink()
          : Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: GameArtwork(
                    title: title!,
                    radius: 0,
                    showTitle: false,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.45, 1],
                      colors: [
                        fade.withValues(alpha: 0.25),
                        fade.withValues(alpha: 0.55),
                        fade,
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}
