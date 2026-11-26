// ignore: deprecated_member_use
import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.dark,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.muted,
    required this.heroBg,
    required this.heroCard,
    required this.heroBorder,
    required this.heroText,
    required this.tealPale,
    required this.tealInk,
    required this.rosePale,
    required this.roseInk,
    required this.amberPale,
    required this.amberInk,
  });

  final bool dark;
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color muted;
  final Color heroBg;
  final Color heroCard;
  final Color heroBorder;
  final Color heroText;
  final Color tealPale;
  final Color tealInk;
  final Color rosePale;
  final Color roseInk;
  final Color amberPale;
  final Color amberInk;

  static const Color teal = Color(0xFF0D9488);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);
  static const Color sky = Color(0xFF38BDF8);

  static const lightPalette = AppPalette(
    dark: false,
    canvas: Color(0xFFF4F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    ink: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
    heroBg: Color(0xFF0F172A),
    heroCard: Color(0xFF1E293B),
    heroBorder: Color(0xFF334155),
    heroText: Color(0xFFF8FAFC),
    tealPale: Color(0xFFCCFBF1),
    tealInk: Color(0xFF0F766E),
    rosePale: Color(0xFFFFE4E6),
    roseInk: Color(0xFFBE123C),
    amberPale: Color(0xFFFEF3C7),
    amberInk: Color(0xFFB45309),
  );

  static const darkPalette = AppPalette(
    dark: true,
    canvas: Color(0xFF0B1220),
    surface: Color(0xFF111C2E),
    surfaceAlt: Color(0xFF17253B),
    border: Color(0xFF24354F),
    ink: Color(0xFFF1F5F9),
    muted: Color(0xFF94A3B8),
    heroBg: Color(0xFF09101D),
    heroCard: Color(0xFF17243A),
    heroBorder: Color(0xFF273A57),
    heroText: Color(0xFFF8FAFC),
    tealPale: Color(0xFF0F3430),
    tealInk: Color(0xFF5EEAD4),
    rosePale: Color(0xFF3B1822),
    roseInk: Color(0xFFFDA4AF),
    amberPale: Color(0xFF3D2808),
    amberInk: Color(0xFFFCD34D),
  );

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: canvas,
      dividerColor: border,
    );
  }
}

