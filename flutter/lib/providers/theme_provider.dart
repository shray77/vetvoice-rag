import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Провайдер темы — управляет переключением светлая/тёмная/системная.
/// Состояние сохраняется в SharedPreferences.
///
/// Режимы:
/// - system (по умолчанию) — следует системной теме
/// - light — всегда светлая
/// - dark — всегда тёмная
/// - night — тёмная + принудительно для ночных дежурств
class ThemeProvider extends ChangeNotifier {
  String _mode = 'system'; // system | light | dark | night

  String get mode => _mode;
  bool get isDarkMode => _mode == 'dark' || _mode == 'night';
  bool get isNightMode => _mode == 'night';
  ThemeMode get themeMode {
    switch (_mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      case 'night':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  ThemeProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString('theme_mode') ?? 'system';
    notifyListeners();
  }

  Future<void> setMode(String value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', value);
  }

  void setSystem() => setMode('system');
  void setLight() => setMode('light');
  void setDark() => setMode('dark');
  void setNight() => setMode('night');

  void toggleTheme() {
    if (_mode == 'light') {
      setDark();
    } else if (_mode == 'dark' || _mode == 'night') {
      setLight();
    } else {
      // system → dark
      setDark();
    }
  }
}
