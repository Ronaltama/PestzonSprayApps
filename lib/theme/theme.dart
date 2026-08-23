import 'package:flutter/material.dart';

class AppTheme {
  // Electric Neon Green & Charcoal Black color palette matching dark theme
  static const Color primaryGreen = Color(0xFFD5FF40); // Electric Neon Green #D5FF40
  static const Color primaryColor = Color(0xFFD5FF40); // Electric Neon Green #D5FF40
  static const Color primaryGreenDark = Color(0xFF0F0F0F); // Black #0F0F0F
  static const Color primaryGreenLight = Color(0xFFE5FF80); // Light Electric Green
  static const Color accentYellow = Color(0xFFFBBF24); // Amber 400
  static const Color accentOrange = Color(0xFFF97316); // Orange 500
  static const Color backgroundLight = Color(0xFFF6F8F6); // Soft tint
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white
  static const Color textDark = Color(0xFF0F0F0F); // Custom Black #0F0F0F
  static const Color textGrey = Color(0xFF6B7280); // Gray 500
  static const Color textLight = Color(0xFFFFFFFF); // White
  static const Color borderColor = Color(0xFFE5E7EB); // Gray 200

  // Functional colors
  static const Color successColor = Color(0xFFD5FF40);
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
    fontFamily: 'Utendo',
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentYellow,
      surface: surfaceLight,
      surfaceContainerHighest: Colors.white,
      onPrimary: textDark,
      onSurface: textDark,
      tertiary: accentOrange,
    ),
    scaffoldBackgroundColor: backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundLight,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Utendo',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textDark,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: textDark,
      unselectedItemColor: Color(0xFF9CA3AF),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontFamily: 'Utendo', fontSize: 32, fontWeight: FontWeight.bold, color: textDark),
      titleLarge: TextStyle(fontFamily: 'Utendo', fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
      titleMedium: TextStyle(fontFamily: 'Utendo', fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
      bodyLarge: TextStyle(fontFamily: 'Utendo', fontSize: 16, color: textDark),
      bodyMedium: TextStyle(fontFamily: 'Utendo', fontSize: 14, color: textDark),
      bodySmall: TextStyle(fontFamily: 'Utendo', fontSize: 12, color: textGrey),
      labelLarge: TextStyle(fontFamily: 'Utendo', fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
    ),
  );

  static const List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
}
