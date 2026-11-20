import 'package:flutter/material.dart';

/// Research Hop colours. One restrained accent (forest / mint) and a single
/// gold used only for small highlights.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.accent,
    required this.accent2,
    required this.accentInk,
    required this.gold,
    required this.softBg,
    required this.softInk,
    required this.warnBg,
    required this.warnInk,
    required this.onAccentBg,
    required this.onAccentInk,
    required this.danger,
    required this.dangerBg,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color ink;
  final Color ink2;
  final Color accent;
  final Color accent2;
  final Color accentInk;
  final Color gold;
  final Color softBg;
  final Color softInk;
  final Color warnBg;
  final Color warnInk;
  final Color onAccentBg;
  final Color onAccentInk;
  final Color danger;
  final Color dangerBg;

  static const AppPalette light = AppPalette(
    bg: Color(0xFFF5EFE3),
    surface: Color(0xFFFFFBF3),
    surface2: Color(0xFFEDE5D4),
    line: Color(0xFFDDD3BF),
    ink: Color(0xFF0F2742),
    ink2: Color(0xFF58667A),
    accent: Color(0xFF016E3A),
    accent2: Color(0xFF5DA841),
    accentInk: Color(0xFFFFFFFF),
    gold: Color(0xFFD99A1E),
    softBg: Color(0xFFE1ECDD),
    softInk: Color(0xFF016E3A),
    warnBg: Color(0xFFF6E5BD),
    warnInk: Color(0xFF6B4A00),
    onAccentBg: Color(0xFFFFFBF3),
    onAccentInk: Color(0xFF016E3A),
    danger: Color(0xFFA8372C),
    dangerBg: Color(0xFFF8E1DE),
  );

  static const AppPalette dark = AppPalette(
    bg: Color(0xFF101512),
    surface: Color(0xFF19201B),
    surface2: Color(0xFF222B25),
    line: Color(0xFF2B352E),
    ink: Color(0xFFEFEADF),
    ink2: Color(0xFFA3AEA6),
    accent: Color(0xFF6CCB8C),
    accent2: Color(0xFF4FA86B),
    accentInk: Color(0xFF0E1913),
    gold: Color(0xFFF0B646),
    softBg: Color(0xFF1E2F26),
    softInk: Color(0xFF6CCB8C),
    warnBg: Color(0xFF3A2F14),
    warnInk: Color(0xFFF0B646),
    onAccentBg: Color(0xFF0E1913),
    onAccentInk: Color(0xFF6CCB8C),
    danger: Color(0xFFF2A39B),
    dangerBg: Color(0xFF3B1E1B),
  );

  // The palette is fixed, so copyWith has nothing to change.
  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      accent: l(accent, other.accent),
      accent2: l(accent2, other.accent2),
      accentInk: l(accentInk, other.accentInk),
      gold: l(gold, other.gold),
      softBg: l(softBg, other.softBg),
      softInk: l(softInk, other.softInk),
      warnBg: l(warnBg, other.warnBg),
      warnInk: l(warnInk, other.warnInk),
      onAccentBg: l(onAccentBg, other.onAccentBg),
      onAccentInk: l(onAccentInk, other.onAccentInk),
      danger: l(danger, other.danger),
      dangerBg: l(dangerBg, other.dangerBg),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
