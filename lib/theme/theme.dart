// lib/theme/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Modern Green color palette
  static const Color primaryGreen = Color(0xFF10B981); // Emerald 500
  static const Color primaryColor = Color(0xFF059669); // Emerald 600
  static const Color primaryGreenDark = Color(0xFF047857); // Emerald 700
  static const Color primaryGreenLight = Color(0xFF34D399); // Emerald 400
  static const Color accentYellow = Color(0xFFFBBF24); // Amber 400
  static const Color accentOrange = Color(0xFFF97316); // Orange 500
  static const Color backgroundLight = Color(0xFFF3F4F6); // Gray 100
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white
  static const Color textDark = Color(0xFF111827); // Gray 900
  static const Color textGrey = Color(0xFF6B7280); // Gray 500
  static const Color textLight = Color(0xFFFFFFFF); // White
  static const Color borderColor = Color(0xFFE5E7EB); // Gray 200

  // Functional colors
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);

  // Spacing constants
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;

  // Border radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 24.0;
  static const double radiusXL = 32.0;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentYellow,
      surface: surfaceLight,
      surfaceContainerHighest: Colors.white,
      onPrimary: textLight,
      tertiary: accentOrange,
    ),
    scaffoldBackgroundColor: backgroundLight,
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundLight,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textDark,
        letterSpacing: -0.5,
      ),
      toolbarTextStyle: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textDark,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLG),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.05),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingLG,
        vertical: spacingMD,
      ),
      hintStyle: GoogleFonts.inter(
        color: textGrey,
        fontWeight: FontWeight.w400,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: textLight,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXL,
          vertical: spacingLG,
        ),
        elevation: 4,
        shadowColor: primaryColor.withValues(alpha: 0.4),
        textStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXL,
          vertical: spacingLG,
        ),
        textStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLG,
          vertical: spacingMD,
        ),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: textDark,
        letterSpacing: -1,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textDark,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textDark,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textDark,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textDark,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textGrey,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textDark,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textDark,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textGrey,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: textGrey,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceLight,
      selectedItemColor: primaryColor,
      unselectedItemColor: Color(0xFF9CA3AF),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
    ),
  );

  // Helper methods for shadows
  static List<BoxShadow> get shadowSM {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> get shadowMD {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> get shadowLG {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }
  
  // Custom Gradients for Cards
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1F2937), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
