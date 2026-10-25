import 'package:flutter/material.dart';

/// SteamOS-inspired palette: deep blue-slate surfaces, a cool blue for focus
/// and selection, and the brand lime kept for primary "play" actions.
class NexusPalette {
  const NexusPalette._({
    required this.backdrop,
    required this.surface,
    required this.raised,
    required this.subtle,
    required this.text,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.focus,
    required this.onFocus,
    required this.chip,
  });

  /// Deepest layer, behind the glow of [NexusBackdrop].
  final Color backdrop;
  final Color surface;
  final Color raised;
  final Color subtle;
  final Color text;
  final Color muted;
  final Color line;

  /// Brand lime: Play, primary actions and the selected destination.
  final Color accent;
  final Color accentInk;

  /// Steam-style blue: focus rings, selection highlights, links.
  final Color focus;
  final Color onFocus;
  final Color chip;

  static const dark = NexusPalette._(
    backdrop: Color(0xFF0A0E14),
    surface: Color(0xFF0E141B),
    raised: Color(0xFF161E28),
    subtle: Color(0xFF1B2430),
    text: Color(0xFFEEF3F8),
    muted: Color(0xFF8F9CAD),
    line: Color(0xFF263241),
    accent: Color(0xFFC3ED72),
    accentInk: Color(0xFF14210A),
    focus: Color(0xFF1A9FFF),
    onFocus: Color(0xFFFFFFFF),
    chip: Color(0xFF223041),
  );
  static const light = NexusPalette._(
    backdrop: Color(0xFFE6EBF1),
    surface: Color(0xFFEEF2F6),
    raised: Color(0xFFFFFFFF),
    subtle: Color(0xFFE5EBF1),
    text: Color(0xFF111923),
    muted: Color(0xFF4E5C6C),
    line: Color(0xFFD2DBE5),
    accent: Color(0xFF3F6B17),
    accentInk: Color(0xFFF4F8EE),
    focus: Color(0xFF0A72C7),
    onFocus: Color(0xFFFFFFFF),
    chip: Color(0xFFDCE4ED),
  );

  static NexusPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData nexusTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? NexusPalette.dark : NexusPalette.light;
  final scheme =
      ColorScheme.fromSeed(seedColor: p.focus, brightness: brightness).copyWith(
        primary: p.accent,
        onPrimary: p.accentInk,
        primaryContainer: dark
            ? const Color(0xFF26361A)
            : const Color(0xFFD5EBB4),
        onPrimaryContainer: dark
            ? const Color(0xFFDDF5AE)
            : const Color(0xFF1B2B08),
        secondary: p.focus,
        onSecondary: p.onFocus,
        secondaryContainer: p.chip,
        onSecondaryContainer: p.text,
        tertiary: dark ? const Color(0xFFFFC857) : const Color(0xFF8A5A00),
        surface: p.surface,
        onSurface: p.text,
        onSurfaceVariant: p.muted,
        surfaceContainerLowest: p.backdrop,
        surfaceContainerLow: p.subtle,
        surfaceContainer: p.raised,
        surfaceContainerHigh: p.chip,
        surfaceContainerHighest: p.chip,
        outline: p.muted,
        outlineVariant: p.line,
      );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Ubuntu',
  );
  final text = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );
  const buttonSize = Size(48, 48);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20);
  return base.copyWith(
    scaffoldBackgroundColor: p.surface,
    splashFactory: InkSparkle.splashFactory,
    focusColor: p.focus.withValues(alpha: 0.18),
    hoverColor: p.focus.withValues(alpha: 0.08),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.05,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.1,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: text.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.text,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: rounded,
        textStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: rounded,
        foregroundColor: p.text,
        backgroundColor: p.subtle.withValues(alpha: 0.6),
        side: BorderSide(color: p.line),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: p.focus,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      fillColor: p.subtle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.focus, width: 2),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.focus,
      linearTrackColor: p.chip,
      borderRadius: BorderRadius.circular(4),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.focus : p.muted,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      selectedColor: p.text,
      shape: rounded,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : p.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected) ? p.text : p.muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: p.accent,
      selectedIconTheme: IconThemeData(color: p.accentInk),
      unselectedIconTheme: IconThemeData(color: p.muted),
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        color: p.text,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: text.labelMedium?.copyWith(color: p.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.chip,
      contentTextStyle: text.bodyMedium?.copyWith(color: p.text),
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.raised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

/// The layered background behind every page: a deep base with a cool glow
/// from the top and a faint lime one from the bottom, as on SteamOS.
class NexusBackdrop extends StatelessWidget {
  const NexusBackdrop({super.key, required this.child, this.tint});
  final Widget child;

  /// Replaces the top glow, e.g. with a game's cover colour.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = NexusPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glow = tint ?? p.focus;
    return DecoratedBox(
      decoration: BoxDecoration(color: p.backdrop),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.6, -1.15),
            radius: 1.3,
            colors: [
              glow.withValues(alpha: dark ? 0.22 : 0.14),
              Colors.transparent,
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.1, 1.2),
              radius: 1.1,
              colors: [
                p.accent.withValues(alpha: dark ? 0.07 : 0.08),
                Colors.transparent,
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shared motion: short, decelerating, and skipped when the user reduces motion.
abstract final class NexusMotion {
  static const quick = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
