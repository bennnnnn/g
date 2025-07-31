// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  bool get isLightMode => _themeMode == ThemeMode.light;
  
  bool get isSystemMode => _themeMode == ThemeMode.system;
  
  /// Toggle between light and dark theme
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
  
  /// Set specific theme mode
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
  
  /// Set light theme
  void setLightTheme() {
    setThemeMode(ThemeMode.light);
  }
  
  /// Set dark theme
  void setDarkTheme() {
    setThemeMode(ThemeMode.dark);
  }
  
  /// Set system theme (follows system preference)
  void setSystemTheme() {
    setThemeMode(ThemeMode.system);
  }
  
  /// Get theme mode display name
  String get themeModeDisplayName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
  
  /// Get theme icon
  IconData get themeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}