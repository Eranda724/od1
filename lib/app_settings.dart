import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  ThemeMode _themeMode = ThemeMode.light;
  bool _notificationsEnabled = true;
  bool _isFirstLaunch = true;

  final ValueNotifier<bool> gridViewNotifier = ValueNotifier<bool>(false);

  ThemeMode get themeMode => _themeMode;
  bool get isGridView => gridViewNotifier.value;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isFirstLaunch => _isFirstLaunch;

  static const _keyTheme = 'themeMode';
  static const _keyGrid = 'isGridView';
  static const _keyNotifications = 'notificationsEnabled';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_keyTheme) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    gridViewNotifier.value = prefs.getBool(_keyGrid) ?? false; // default: list view
    _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
    _isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    if (_isFirstLaunch) {
      await prefs.setBool('isFirstLaunch', false);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTheme, mode == ThemeMode.dark);
    notifyListeners();
  }



  Future<void> setGridView(bool value) async {
    gridViewNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGrid, value);
    // Don't call notifyListeners() here to prevent full app rebuilds (MyApp listens to this)
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
    notifyListeners();
  }

  /// Supported languages: code -> native label
  static const Map<String, String> supportedLanguages = {
    'en': '🇬🇧 English',
    'fr': '🇫🇷 Français',
    'es': '🇪🇸 Español',
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

/// Convenience extension — use `context.appColors` in any widget instead of
/// repeating `Theme.of(context).brightness == Brightness.dark ? x : y`.
extension AppColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  /// Main scaffold / page background
  Color get surface => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF4ECE1);

  /// Card / sheet surface
  Color get cardColor => isDark ? const Color(0xFF2A2A2A) : Colors.white;

  /// Text field fill colour
  Color get inputFill => isDark ? const Color(0xFF2A2A2A) : Colors.white;

  /// Subtle border / divider colour
  Color get borderColor => isDark ? const Color(0xFF3A3A3A) : Colors.black12;

  // Text
  Color get textPrimary   => isDark ? Colors.white        : Colors.black87;
  Color get textSecondary => isDark ? Colors.white60      : Colors.black54;

  // Brand
  Color get yellow => PCColors.yellow;

  /// General page background (respects dark mode, unlike PCColors.background)
  Color get background => isDark ? const Color(0xFF1A1A1A) : PCColors.background;

  /// AppBar / header surface
  Color get appBarColor => isDark ? const Color(0xFF2A2A2A) : PCColors.yellow;
}

