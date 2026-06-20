import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  ThemeMode _themeMode = ThemeMode.light;
  String _languageCode = 'en';

  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);

  static const _keyTheme = 'themeMode';
  static const _keyLang = 'languageCode';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_keyTheme) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _languageCode = prefs.getString(_keyLang) ?? 'en';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTheme, mode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLang, code);
    notifyListeners();
  }

  /// Supported languages: code -> native label
  static const Map<String, String> supportedLanguages = {
    'en': '🇬🇧  English',
  };
}

class PCColors {
  static const Color yellow     = Color(0xFFFFC93C);
  static const Color yellowDark = Color(0xFFF4A41E);
  static const Color brown      = Color(0xFF6D4C2C);
  static const Color brownDark  = Color(0xFF4A3219);
  static const Color cream      = Color(0xFFFFF6E5);
  static const Color green      = Color(0xFF4CAF7D);
  static const Color greenDark  = Color(0xFF2E8B57);
  static const Color background = Color(0xFFFAF1E4);
}

