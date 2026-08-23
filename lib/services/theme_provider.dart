import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool get isDarkMode => true; // Fixed dark mode

  ThemeMode get themeMode => ThemeMode.dark; // Fixed dark mode

  // Custom Colors matching Gambar 1:
  // Dark background: #0F0F0F
  // Dark card background: #1E1E1E
  // Green accent: #D5FF40
  // Black text/thumb: #0F0F0F
  static const Color darkBgColor = Color(0xFF0F0F0F);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color blackColor = Color(0xFF0F0F0F);
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color greenAccentColor = Color(0xFFD5FF40);

  void toggleDarkMode(bool value) {
    // Fixed Dark Mode - No-op
    notifyListeners();
  }

  ThemeData get darkThemeData {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Utendo',
      brightness: Brightness.dark,
      primaryColor: greenAccentColor,
      scaffoldBackgroundColor: darkBgColor,
      colorScheme: const ColorScheme.dark(
        primary: greenAccentColor,
        secondary: greenAccentColor,
        surface: darkCardColor,
        onPrimary: blackColor,
        onSurface: whiteColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBgColor,
        foregroundColor: whiteColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Utendo',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: whiteColor,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBgColor,
        selectedItemColor: greenAccentColor,
        unselectedItemColor: Color(0xFF9CA3AF),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
