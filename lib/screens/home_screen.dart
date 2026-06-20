import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_settings.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'exercise_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _settings = AppSettings();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _buildMenuButton(user),
        title: const Text('Potato 🥔'),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Exercise'),
            Tab(text: 'Leaderboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ExerciseScreen(user: user),
          LeaderboardScreen(currentUid: user?.uid),
        ],
      ),
    );
  }

  Widget _buildMenuButton(User? user) {
    final isDark = _settings.themeMode == ThemeMode.dark;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 48),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            _showProfileDialog(user);
            break;
          case 'settings':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
            break;
          case 'theme_light':
            await _settings.setThemeMode(ThemeMode.light);
            break;
          case 'theme_dark':
            await _settings.setThemeMode(ThemeMode.dark);
            break;
          case 'logout':
            _logout();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(children: [
            const Icon(Icons.person_outline_rounded, size: 20),
            const SizedBox(width: 10),
            Text(
              user?.email?.split('@').first ?? 'Profile',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          height: 36,
          child: Row(children: [
            const Icon(Icons.language_rounded, size: 18, color: Colors.grey),
            const SizedBox(width: 10),
            Text(
              AppSettings.supportedLanguages[_settings.languageCode] ??
                  '🇬🇧  English',
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: isDark ? 'theme_light' : 'theme_dark',
          child: Row(children: [
            Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(isDark ? 'Light Mode' : 'Dark Mode'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(children: [
            Icon(Icons.settings_outlined, size: 20),
            SizedBox(width: 10),
            Text('Settings'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 20, color: Colors.red),
            SizedBox(width: 10),
            Text('Log Out',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    );
  }

  void _showProfileDialog(User? user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              child: Icon(Icons.person, size: 36),
            ),
            const SizedBox(height: 12),
            Text(user?.email ?? 'Unknown',
                style: const TextStyle(fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}