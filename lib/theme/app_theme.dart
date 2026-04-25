import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextTheme get _textTheme {
    return TextTheme(
      // Display – large editorial hero text
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 60, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1,
        color: AppColors.onSurface,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1,
        color: AppColors.onSurface,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1,
        color: AppColors.onSurface,
      ),

      // Headlines – section titles, card headers
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2,
        color: AppColors.onSurface,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.25,
        color: AppColors.onSurface,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.3,
        color: AppColors.onSurface,
      ),

      // Title – card names, list items
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w800, height: 1.3,
        color: AppColors.onSurface,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 18, fontWeight: FontWeight.w700, height: 1.4,
        color: AppColors.onSurface,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w700, height: 1.4,
        color: AppColors.onSurface,
      ),

      // Body – descriptions, metadata
      bodyLarge: GoogleFonts.beVietnamPro(
        fontSize: 17, fontWeight: FontWeight.w500, height: 1.6,
        color: AppColors.onSurface,
      ),
      bodyMedium: GoogleFonts.beVietnamPro(
        fontSize: 15, fontWeight: FontWeight.w500, height: 1.6,
        color: AppColors.onSurface,
      ),
      bodySmall: GoogleFonts.beVietnamPro(
        fontSize: 13, fontWeight: FontWeight.w500, height: 1.5,
        color: AppColors.onSurfaceVariant,
      ),

      // Label – uppercase metadata, badges
      labelLarge: GoogleFonts.beVietnamPro(
        fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.6,
        color: AppColors.onSurface,
      ),
      labelMedium: GoogleFonts.beVietnamPro(
        fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8,
        color: AppColors.onSurface,
      ),
      labelSmall: GoogleFonts.beVietnamPro(
        fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2,
        color: AppColors.onSurface,
      ),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
      ),
      textTheme: _textTheme,
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
    );
  }
}
