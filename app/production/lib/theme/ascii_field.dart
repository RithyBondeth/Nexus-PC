import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'nexus_theme.dart';

/// The landing page's flowing ASCII background (landing/dist/app.js,
/// `asciiField`): a noise field drawn as monospace characters that lights up
/// lime around a touch. Runs at 15 fps, pauses in the background, and holds
/// still when the user reduces motion.
class AsciiField extends StatefulWidget {
  const AsciiField({super.key, required this.child});
  final Widget child;

  /// Off in widget tests (test/flutter_test_config.dart), so `pumpAndSettle`
  /// can settle; the field still paints its first frame.
  static bool animate = true;

  /// Same ramp as the web field, from empty to dense.
  static const ramp = ' .\'`:-~=+*cox%#@';

  @override
  State<AsciiField> createState() => _AsciiFieldState();
}

class _AsciiFieldState extends State<AsciiField> with WidgetsBindingObserver {
  final _clock = Stopwatch()..start();
  final _frame = ValueNotifier<double>(0);
  final _touch = _Touch();
  Timer? _timer;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = NexusMotion.reduced(context);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync(state);

  void _sync([AppLifecycleState? state]) {
    final running =
        AsciiField.animate &&
        !_reduced &&
        (state ?? WidgetsBinding.instance.lifecycleState) !=
            AppLifecycleState.paused;
    if (running && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 66), (_) {
        _touch.decay();
        _frame.value = _clock.elapsedMilliseconds / 1000;
      });
    } else if (!running) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = NexusPalette.of(context);
    return Listener(
      // Sees touches without taking them from the page.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _timer == null ? null : (e) => _touch.at(e.localPosition),
      onPointerMove: _timer == null ? null : (e) => _touch.at(e.localPosition),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _AsciiPainter(
                    time: _frame,
                    touch: _touch,
                    base: dark
                        ? const Color(0x1FC8DCF5)
                        : const Color(0x1C142846),
                    highlight: p.accent,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Touch {
  Offset position = const Offset(-9999, -9999);
  double energy = 0;
  void at(Offset value) {
    position = value;
    energy = 1;
  }

  void decay() => energy *= 0.9;
}

class _AsciiPainter extends CustomPainter {
  _AsciiPainter({
    required this.time,
    required this.touch,
    required this.base,
    required this.highlight,
  }) : super(repaint: time);
  final ValueListenable<double> time;
  final _Touch touch;
  final Color base;
  final Color highlight;

  static const _fontSize = 11.0;
  static const _cellHeight = _fontSize * 1.18;

  ui.Paragraph _row(String text, Color color) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontFamily: 'monospace',
              fontSize: _fontSize,
              height: 1,
              maxLines: 1,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);
    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.value;
    final probe = _row('M', base);
    final cellWidth = probe.maxIntrinsicWidth;
    probe.dispose();
    if (cellWidth <= 0) return;
    final cols = (size.width / cellWidth).ceil() + 1;
    final rows = (size.height / _cellHeight).ceil() + 1;
    final ramp = AsciiField.ramp;
    final dim = StringBuffer();
    final lit = StringBuffer();
    for (var r = 0; r < rows; r++) {
      dim.clear();
      lit.clear();
      var anyLit = false;
      final y = r / rows;
      // Strongest at the top, easing off so page text stays clear below.
      final fade = math.min(1.0, (1 - y) * 1.6) * 0.85 + 0.15;
      for (var c = 0; c < cols; c++) {
        final x = c / cols;
        final warp =
            math.sin(y * 5.2 + t * 0.5) * 0.9 +
            math.sin(x * 3.1 - t * 0.3) * 0.6;
        var v =
            0.5 +
            0.25 * math.sin(x * 7.5 + warp + t * 0.45) +
            0.25 * math.cos(y * 9 - warp * 1.3 + t * 0.35);
        v = v * v * fade * (0.55 + 0.45 * x);
        var ripple = 0.0;
        if (touch.energy > 0.02) {
          final dx = c * cellWidth - touch.position.dx;
          final dy = (r * _cellHeight - touch.position.dy) * 1.2;
          final distance = math.sqrt(dx * dx + dy * dy);
          ripple =
              touch.energy *
              math.exp(-distance * distance / 9000) *
              (0.6 + 0.4 * math.sin(distance * 0.08 - t * 6));
        }
        final level = math.min(0.999, v + math.max(0, ripple));
        final char = ramp[(level * ramp.length).floor()];
        if (ripple > 0.22 && char != ' ') {
          lit.write(char);
          dim.write(' ');
          anyLit = true;
        } else {
          dim.write(char);
          lit.write(' ');
        }
      }
      final top = r * _cellHeight;
      _draw(canvas, _row(dim.toString(), base), top);
      if (anyLit) _draw(canvas, _row(lit.toString(), highlight), top);
    }
  }

  void _draw(Canvas canvas, ui.Paragraph row, double top) {
    canvas.drawParagraph(row, Offset(0, top));
    row.dispose();
  }

  @override
  bool shouldRepaint(_AsciiPainter old) =>
      old.base != base || old.highlight != highlight;
}
