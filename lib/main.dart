import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'app_theme.dart';
import 'app_settings.dart';
import 'admin/admin_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'services/ad_service.dart';
import 'services/iap_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'services/image_bank.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

import 'services/superwall_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Load persisted settings before first frame
  await AppSettings().load();
  // Initialize notifications and schedule daily reminders
  await NotificationService.instance.init();
  await NotificationService.instance.refreshSchedule();
  // Initialize Google Mobile Ads
  await AdService.instance.initialize();
  // Initialize In-App Purchases listener
  IapService.instance.initialize();
  // Warm up image bank pools from Firestore
  await ImageBank.initialize();
  
  // Initialize Superwall SDK
  await SuperwallService.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('es')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.refreshSchedule();
    }
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Potato',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _settings.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const StartRouter(),
    );
  }
}

// Decides where to send the user on launch
class StartRouter extends StatefulWidget {
  const StartRouter({super.key});

  @override
  State<StartRouter> createState() => _StartRouterState();
}

class _StartRouterState extends State<StartRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    
    // Wait for Firebase Auth to initialize from disk
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(milliseconds: 1500),
        );
      } catch (_) {
        // Fallback if timeout happens
        user = FirebaseAuth.instance.currentUser;
      }
    }

    if (!mounted) return;

    if (user != null) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FutureBuilder<bool>(
            future: checkIsAdmin(user!.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFC72C)),
                  ),
                );
              }
              final isAdmin = snapshot.data ?? false;
              return HomeScreen(isAdmin: isAdmin);
            },
          ),
        ),
      );
    } else if (!hasSeenOnboarding) {
      try {
        final handler = PaywallPresentationHandler();
        handler.onError((String error) {
          debugPrint('Superwall presentation error: $error');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          }
        });
        handler.onSkip((PaywallSkippedReason reason) {
          debugPrint('Superwall presentation skipped: $reason');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          }
        });

        Superwall.shared.registerPlacement(
          'onboarding_start',
          handler: handler,
        );
      } catch (e) {
        debugPrint('Superwall registerEvent error: $e');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: const Color(0xFFFFC72C)),
      ),
    );
  }
}
