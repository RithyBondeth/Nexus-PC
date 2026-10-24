import 'package:flutter/material.dart';

/// Brand palette shared with the landing page: graphite surfaces, lime accent.
class NexusPalette {
  const NexusPalette._({
    required this.surface,
    required this.raised,
    required this.subtle,
    required this.text,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.chip,
  });
  final Color surface;
  final Color raised;
  final Color subtle;
  final Color text;
  final Color muted;
  final Color line;
  final Color accent;
  final Color accentInk;
  final Color chip;

  static const dark = NexusPalette._(
    surface: Color(0xFF0B0D0B),
    raised: Color(0xFF151815),
    subtle: Color(0xFF1B1F1A),
    text: Color(0xFFF2F5EE),
    muted: Color(0xFFA3AA9F),
    line: Color(0xFF242923),
    accent: Color(0xFFC3ED72),
    accentInk: Color(0xFF172507),
    chip: Color(0xFF232A21),
  );
  static const light = NexusPalette._(
    surface: Color(0xFFF3F5EF),
    raised: Color(0xFFFFFFFF),
    subtle: Color(0xFFECEFE6),
    text: Color(0xFF1A2116),
    muted: Color(0xFF525C4B),
    line: Color(0xFFDCE2D3),
    accent: Color(0xFF3F6B17),
    accentInk: Color(0xFFF4F8EE),
    chip: Color(0xFFE1E8D7),
  );
}

ThemeData nexusTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? NexusPalette.dark : NexusPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.accentInk,
        primaryContainer: dark
            ? const Color(0xFF2B3A16)
            : const Color(0xFFD5EBB4),
        onPrimaryContainer: dark
            ? const Color(0xFFDDF5AE)
            : const Color(0xFF1B2B08),
        secondaryContainer: p.chip,
        onSecondaryContainer: p.text,
        surface: p.surface,
        onSurface: p.text,
        onSurfaceVariant: p.muted,
        surfaceContainerLowest: p.subtle,
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
    borderRadius: BorderRadius.circular(12),
  );
  const buttonSize = Size(48, 48);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18);
  return base.copyWith(
    scaffoldBackgroundColor: p.surface,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.15,
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
      bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
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
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: rounded,
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: rounded,
        foregroundColor: p.text,
        side: BorderSide(color: p.line),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      fillColor: p.subtle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.chip,
      borderRadius: BorderRadius.circular(4),
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
      backgroundColor: p.raised,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: p.muted),
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        color: p.text,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: text.labelMedium?.copyWith(color: p.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.raised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

/// Shared motion: short, decelerating, and skipped when the user reduces motion.
abstract final class NexusMotion {
  static const quick = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
