import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

class AppTheme {
  const AppTheme._();

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final p = isLight ? AppPalette.light : AppPalette.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.accentInk,
      primaryContainer: p.softBg,
      onPrimaryContainer: p.softInk,
      secondary: p.accent2,
      onSecondary: p.accentInk,
      error: p.danger,
      onError: isLight ? Colors.white : const Color(0xFF3B1E1B),
      errorContainer: p.dangerBg,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.ink2,
      surfaceContainerHighest: p.surface2,
      outline: p.line,
      outlineVariant: p.line,
    );

    final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    final body = GoogleFonts.instrumentSansTextTheme(base)
        .apply(bodyColor: p.ink, displayColor: p.ink);

    TextStyle display(double size, {double height = 1.1}) =>
        GoogleFonts.fraunces(
          fontSize: size,
          fontWeight: FontWeight.w500,
          height: height,
          color: p.ink,
          letterSpacing: -0.2,
        );

    final textTheme = body.copyWith(
      displayLarge: display(56, height: 1.02),
      displayMedium: display(44, height: 1.04),
      displaySmall: display(36),
      headlineLarge: display(32),
      headlineMedium: display(28),
      headlineSmall: display(24),
      titleLarge: display(21, height: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[p],
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: body.bodyMedium?.copyWith(color: p.bg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.softBg,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return body.labelMedium!.copyWith(
            color: selected ? p.accent : p.ink2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: selected ? p.accent : p.ink2);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.softBg,
        selectedIconTheme: IconThemeData(color: p.accent),
        unselectedIconTheme: IconThemeData(color: p.ink2),
        selectedLabelTextStyle: body.labelMedium!
            .copyWith(color: p.accent, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle:
            body.labelMedium!.copyWith(color: p.ink2),
      ),
    );
  }
}
