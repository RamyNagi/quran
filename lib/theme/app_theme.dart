import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const String _displayFont = 'serif';
  static const String _bodyFont = 'sans-serif';

  // ── Brand Colours ──────────────────────────────────────────────────────────
  static const Color primaryNight = Color(0xFF003527);
  static const Color backgroundNight = Color(0xFF060D0A);
  static const Color surfaceNight = Color(0xFF010807);
  static const Color goldNight = Color(0xFFD4AF37);
  static const Color goldAccentNight = Color(0xFFFFE088);
  static const Color textNight = Color(0xFFD9E3F6);
  static const Color textVariantNight = Color(0xFF80BEA6);

  static const Color primaryLight = Color(0xFF003527);
  static const Color backgroundLight = Color(0xFFFAF8F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color goldLight = Color(0xFF9E722C);
  static const Color goldAccentLight = Color(0xFFEED2A0);
  static const Color textLight = Color(0xFF121C2A);
  static const Color textVariantLight = Color(0xFF404944);


// لون البار العلوى
  static const Color statusBarDark = Color(0xFF003527);
  static const Color statusBarLight = Color.fromARGB(255, 255, 255, 255);

  // لون البار السفلى
  static const Color appBarDark = Color(0xFF003527);
  static const Color appBarLight = Color.fromARGB(255, 255, 255, 255);

  // ── Night (Dark) Theme ─────────────────────────────────────────────────────
  static ThemeData get nightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundNight,
      colorScheme: const ColorScheme.dark(
        primary: primaryNight,
        secondary: goldNight,
        surface: surfaceNight,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textNight,
        onSurfaceVariant: textVariantNight,
        inversePrimary: Color(0xFF95D3BA),
        primaryContainer: Color(0xFF064E3B),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: _displayFont,
          fontSize: 52.sp,
          fontWeight: FontWeight.w500,
          color: textNight,
        ),
        headlineLarge: TextStyle(
          fontFamily: _displayFont,
          fontSize: 32.sp,
          fontWeight: FontWeight.w600,
          color: textNight,
        ),
        headlineMedium: TextStyle(
          fontFamily: _displayFont,
          fontSize: 24.sp,
          fontWeight: FontWeight.w500,
          color: goldNight,
        ),
        bodyLarge: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 18.sp,
          fontWeight: FontWeight.w400,
          color: textNight,
        ),
        bodyMedium: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 16.sp,
          fontWeight: FontWeight.w400,
          color: textNight.withValues(alpha: 0.8),
        ),
        labelMedium: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: goldNight,
        ),
        bodySmall: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: textVariantNight,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0x26064E3B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0x1AD4AF37)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: statusBarDark,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
    );
  }

  // ── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: goldLight,
        surface: surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textLight,
        onSurfaceVariant: textVariantLight,
        inversePrimary: Color(0xFFD1F2E5),
        primaryContainer: Color(0xFF064E3B),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: _displayFont,
          fontSize: 48.sp,
          fontWeight: FontWeight.w600,
          color: primaryLight,
        ),
        headlineLarge: TextStyle(
          fontFamily: _displayFont,
          fontSize: 32.sp,
          fontWeight: FontWeight.w600,
          color: primaryLight,
        ),
        headlineMedium: TextStyle(
          fontFamily: _displayFont,
          fontSize: 24.sp,
          fontWeight: FontWeight.w500,
          color: goldLight,
        ),
        bodyLarge: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 18.sp,
          fontWeight: FontWeight.w400,
          color: textLight,
        ),
        bodyMedium: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 16.sp,
          fontWeight: FontWeight.w400,
          color: textLight.withValues(alpha: 0.8),
        ),
        labelMedium: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: goldLight,
        ),
        bodySmall: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: textVariantLight,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0x1AC5A059)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: statusBarLight,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
    );
  }
}
