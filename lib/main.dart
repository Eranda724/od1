import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Potato Couch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.potatoCouchTheme,
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
      // Already logged in → go straight to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (!hasSeenOnboarding) {
      // Brand new user → show onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      // Returning user, not logged in → go to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a simple loading screen while routing
    return const Scaffold(
      backgroundColor: Color(0xFFFFF8F0),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF8C42),
        ),
      ),
    );
  }
}