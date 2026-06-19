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
