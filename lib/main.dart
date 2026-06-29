import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'app_theme.dart';
import 'app_settings.dart';
import 'admin/admin_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Load persisted settings before first frame
  await AppSettings().load();
  // Initialize notifications and schedule daily reminders
  await NotificationService.instance.init();
  await NotificationService.instance.refreshSchedule();
  // Initialize Google Mobile Ads
  await AdService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Potato',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _settings.themeMode,
      locale: _settings.locale,
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
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FutureBuilder<bool>(
            future: checkIsAdmin(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  backgroundColor: Color(0xFFFAF1E4),
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFC93C)),
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF4ECE1),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFC72C),
        ),
      ),
    );
  }
}