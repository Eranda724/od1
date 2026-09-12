import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../main.dart'; // To access navigatorKey
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AppSuperwallDelegate extends SuperwallDelegate {
  Widget? _pendingScreen;

  @override
  void handleCustomPaywallAction(String name) {
    switch (name) {
      case 'register':
        _pendingScreen = const RegisterScreen();
        break;
      case 'login':
        _pendingScreen = const LoginScreen();
        break;
      case 'select_language':
        _showLanguagePicker();
        break;
    }
  }

  void _showLanguagePicker() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                title: const Text('English'),
                onTap: () {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇫🇷', style: TextStyle(fontSize: 24)),
                title: const Text('Français'),
                onTap: () {
                  context.setLocale(const Locale('fr'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇪🇸', style: TextStyle(fontSize: 24)),
                title: const Text('Español'),
                onTap: () {
                  context.setLocale(const Locale('es'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void didDismissPaywall(PaywallInfo paywallInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    // If the user tapped Register or Login inside Superwall, _pendingScreen is set.
    // If they dismissed without tapping anything, send them to LoginScreen.
    final screen = _pendingScreen ?? const LoginScreen();
    _pendingScreen = null;

    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void subscriptionStatusDidChange(SubscriptionStatus newValue) {}

  @override
  void handleSuperwallEvent(SuperwallEventInfo eventInfo) {}

  @override
  void willDismissPaywall(PaywallInfo paywallInfo) {}

  @override
  void willPresentPaywall(PaywallInfo paywallInfo) {}

  @override
  void didPresentPaywall(PaywallInfo paywallInfo) {}

  @override
  void paywallWillOpenURL(Uri url) {}

  @override
  void paywallWillOpenDeepLink(Uri url) {}

  @override
  void handleLog(
    String level,
    String scope,
    String? message,
    Map<dynamic, dynamic>? info,
    String? error,
  ) {}

  @override
  void handleSuperwallDeepLink(
    Uri fullURL,
    List<String> pathComponents,
    Map<String, String> queryParameters,
  ) {}
}

class SuperwallService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('Superwall already initialized, skipping.');
      return;
    }
    try {
      final apiKey = Platform.isIOS
          ? dotenv.env['SUPERWALL_IOS_KEY']
          : dotenv.env['SUPERWALL_ANDROID_KEY'];

      if (apiKey != null && apiKey.isNotEmpty) {
        Superwall.configure(apiKey);
        Superwall.shared.setDelegate(AppSuperwallDelegate());
        _initialized = true;
        debugPrint('Superwall initialized successfully.');
      } else {
        debugPrint('Superwall API key is missing from .env');
      }
    } catch (e) {
      debugPrint('Superwall initialization error: $e');
    }
  }
}
