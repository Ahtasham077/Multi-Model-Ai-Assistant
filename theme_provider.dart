// lib/providers/theme_provider.dart
// Application Logic: Theme management

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _customThemeKey = 'system';
  static const String _themeKey = 'theme_mode';

  ThemeMode get themeMode => _themeMode;
  bool get solarFlareSelected => false; // Retained from original code

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_themeKey);

      if (theme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (theme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> setTheme(ThemeMode mode, {bool isSolarFlare = false}) async {
    try {
      _themeMode = mode;
      String key = mode.toString().split('.').last;

      if (mode == ThemeMode.dark) {
        key = 'dark';
      }
      _customThemeKey = key;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, key);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting theme: $e');
    }
  }

  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF6B7280),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6B7280),
          secondary: Color(0xFF9CA3AF),
          surface: Colors.white,
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
      );

  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF6B7280),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6B7280),
          secondary: Color(0xFF9CA3AF),
          surface: Color(0xFF1E293B),
          error: Color(0xFFFCA5A5),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1E293B),
        ),
      );
}
