import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF0F5238);
  static const Color primaryContainer = Color(0xFF2D6A4F);
  static const Color primaryFixed = Color(0xFFB1F0CE);
  static const Color onPrimaryFixed = Color(0xFF002114);
  static const Color primaryFixedDim = Color(0xFF95D4B3);
  static const Color onPrimaryContainer = Color(0xFFA8E7C5);
  static const Color onPrimaryFixedVariant = Color(0xFF0E5138);

  static const Color secondary = Color(0xFF006C48);
  static const Color secondaryContainer = Color(0xFF92F7C3);
  static const Color secondaryFixed = Color(0xFF92F7C3);
  static const Color onSecondaryContainer = Color(0xFF00734D);
  static const Color onSecondaryFixedVariant = Color(0xFF005235);
  static const Color userBubble = Color(0xFF52B788);

  static const Color tertiary = Color(0xFF464A30);
  static const Color tertiaryFixed = Color(0xFFE1E6C2);
  static const Color tertiaryContainer = Color(0xFF5D6246);
  static const Color onTertiaryFixed = Color(0xFF1A1D07);
  static const Color onTertiaryFixedVariant = Color(0xFF45492F);

  static const Color background = Color(0xFFE8FFF0);
  static const Color surface = Color(0xFFE8FFF0);
  static const Color surfaceBright = Color(0xFFE8FFF0);
  static const Color surfaceDim = Color(0xFFB8E4CC);
  static const Color surfaceVariant = Color(0xFFC1ECD4);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFD1FEE5);
  static const Color surfaceContainer = Color(0xFFCCF8DF);
  static const Color surfaceContainerHigh = Color(0xFFC6F2DA);
  static const Color surfaceContainerHighest = Color(0xFFC1ECD4);

  static const Color onSurface = Color(0xFF002114);
  static const Color onBackground = Color(0xFF002114);
  static const Color onSurfaceVariant = Color(0xFF404943);
  static const Color outline = Color(0xFF707973);
  static const Color outlineVariant = Color(0xFFBFC9C1);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color inverseSurface = Color(0xFF0E3727);
  static const Color inverseOnSurface = Color(0xFFCFFBE2);
  static const Color inversePrimary = Color(0xFF95D4B3);

  static TextStyle _headline(double size, FontWeight w, Color c,
          {double letterSpacing = -0.2}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: letterSpacing,
      );

  static TextStyle _body(double size, FontWeight w, Color c,
          {double height = 1.5}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: w,
        color: c,
        height: height,
      );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: Colors.white,
        error: error,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerLowest: surfaceContainerLowest,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
        outline: outline,
        outlineVariant: outlineVariant,
        inverseSurface: inverseSurface,
        onInverseSurface: inverseOnSurface,
        inversePrimary: inversePrimary,
      ),
      textTheme: TextTheme(
        displayLarge: _headline(32, FontWeight.w800, onPrimaryFixed),
        displayMedium: _headline(28, FontWeight.w800, onPrimaryFixed),
        headlineLarge: _headline(26, FontWeight.w800, primary),
        headlineMedium: _headline(22, FontWeight.w700, primary),
        headlineSmall: _headline(18, FontWeight.w700, primary),
        titleLarge: _headline(20, FontWeight.w700, primary),
        titleMedium: _headline(16, FontWeight.w700, onSurface),
        titleSmall: _headline(14, FontWeight.w700, onSurface),
        bodyLarge: _body(16, FontWeight.w500, onSurface),
        bodyMedium: _body(14, FontWeight.w500, onSurfaceVariant),
        bodySmall: _body(12, FontWeight.w500, onSurfaceVariant),
        labelLarge: _headline(14, FontWeight.w700, primary, letterSpacing: 0.2),
        labelMedium: _headline(12, FontWeight.w700, onSurfaceVariant,
            letterSpacing: 1.2),
        labelSmall: _headline(10, FontWeight.w700, onSurfaceVariant,
            letterSpacing: 1.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background.withOpacity(0.7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: onPrimaryFixed),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: onPrimaryFixed,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceContainerLow.withOpacity(0.95),
        selectedItemColor: primary,
        unselectedItemColor: primary.withOpacity(0.55),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: outlineVariant.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: _body(14, FontWeight.w500, onSurfaceVariant.withOpacity(0.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant.withOpacity(0.3),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLowest,
        selectedColor: primary,
        labelStyle: _headline(12, FontWeight.w700, primary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  static TextStyle displayXL({Color? color}) =>
      _headline(40, FontWeight.w800, color ?? onPrimaryFixed);
  static TextStyle display({Color? color}) =>
      _headline(32, FontWeight.w800, color ?? onPrimaryFixed);
  static TextStyle h1({Color? color}) =>
      _headline(26, FontWeight.w800, color ?? primary);
  static TextStyle h2({Color? color}) =>
      _headline(20, FontWeight.w700, color ?? primary);
  static TextStyle h3({Color? color}) =>
      _headline(16, FontWeight.w700, color ?? onSurface);
  static TextStyle label({Color? color}) => _headline(
      10, FontWeight.w700, color ?? onSurfaceVariant,
      letterSpacing: 1.5);
  static TextStyle body({Color? color}) =>
      _body(14, FontWeight.w500, color ?? onSurfaceVariant);
  static TextStyle bodyBold({Color? color}) =>
      _body(14, FontWeight.w700, color ?? onSurface);
}
