import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One set of colors for a brightness. Screens read colors through [AppTheme]
/// so the whole app switches when the palette changes.
class AppPalette {
  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgCard;
  final Color bgCardHover;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Main foreground: white on the dark theme, black on the light theme.
  final Color ink;

  /// Opposite of [ink], used for content placed on an [ink]-colored surface.
  final Color inkInverse;
  final Color success;
  final Color warning;
  final Color danger;

  const AppPalette({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgCard,
    required this.bgCardHover,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.ink,
    required this.inkInverse,
    required this.success,
    required this.warning,
    required this.danger,
  });

  // Pure black industrial look
  static const dark = AppPalette(
    bgPrimary: Color(0xFF000000),
    bgSecondary: Color(0xFF0A0A0A),
    bgCard: Color(0xFF121212),
    bgCardHover: Color(0xFF1E1E1E),
    borderSubtle: Color(0xFF262626),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA3A3A3),
    textMuted: Color(0xFF737373),
    ink: Color(0xFFFFFFFF),
    inkInverse: Color(0xFF000000),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
  );

  // Clean white counterpart; status colors darkened for contrast on white
  static const light = AppPalette(
    bgPrimary: Color(0xFFF4F4F5),
    bgSecondary: Color(0xFFEDEDEF),
    bgCard: Color(0xFFFFFFFF),
    bgCardHover: Color(0xFFF0F0F1),
    borderSubtle: Color(0xFFE2E2E5),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF525252),
    textMuted: Color(0xFF6B6B6B),
    ink: Color(0xFF000000),
    inkInverse: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
  );
}

class AppTheme {
  static AppPalette _p = AppPalette.dark;

  static bool get isDark => identical(_p, AppPalette.dark);

  /// Switch the active palette. Call before rebuilding the widget tree.
  static void use(Brightness brightness) {
    _p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  }

  static Color get bgPrimary => _p.bgPrimary;
  static Color get bgSecondary => _p.bgSecondary;
  static Color get bgCard => _p.bgCard;
  static Color get bgCardHover => _p.bgCardHover;
  static Color get borderSubtle => _p.borderSubtle;
  static Color get borderFocus => _p.ink;

  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textMuted => _p.textMuted;
  static Color get textAccent => _p.ink;

  static Color get ink => _p.ink;
  static Color get inkInverse => _p.inkInverse;

  /// Text/icons on a green or red button stay white in both themes.
  static const Color onAccent = Color(0xFFFFFFFF);

  static Color get primary => _p.ink;

  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get danger => _p.danger;
  static const Color purple = Color(0xFFA855F7);
  static const Color cyan = Color(0xFF06B6D4);

  // Sharp Corner Radii: Almost Square!
  static final BorderRadius radiusSmall = BorderRadius.circular(2.0);
  static final BorderRadius radiusMedium = BorderRadius.circular(4.0);
  static final BorderRadius radiusCard = BorderRadius.circular(4.0);

  static ThemeData themeFor(Brightness brightness) {
    final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final scheme = brightness == Brightness.dark
        ? ColorScheme.dark(primary: p.ink, onPrimary: p.inkInverse, secondary: p.textSecondary, surface: p.bgSecondary, error: p.danger)
        : ColorScheme.light(primary: p.ink, onPrimary: p.inkInverse, secondary: p.textSecondary, surface: p.bgCard, error: p.danger);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: p.bgPrimary,
      primaryColor: p.ink,
      colorScheme: scheme,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bgPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Almost square
          side: BorderSide(color: p.borderSubtle, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.bgCard),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.inkInverse,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.borderSubtle, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.textPrimary)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bgCard,
        hintStyle: TextStyle(color: p.textMuted, fontSize: 13),
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: p.borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: p.borderSubtle)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: p.ink, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      // Snackbars often get a green/red background, so text stays white
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF262626),
        contentTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(checkmarkColor: p.inkInverse),
    );
  }
}
