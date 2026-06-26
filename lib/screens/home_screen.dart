import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_settings.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'exercise_screen.dart';
import 'streak_screen.dart';
import 'leaderboard_screen.dart';
import 'social_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isAdmin;
  const HomeScreen({super.key, this.isAdmin = false});

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
    _tabController = TabController(length: 4, vsync: this);
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

        return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _buildMenuButton(user),
        title: const Text('Potato 🥔'),
        actions: [
          if (widget.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color.fromARGB(255, 0, 0, 0), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                child: const Text('Admin'),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center_rounded), text: 'Exercise'),
            Tab(icon: Icon(Icons.local_fire_department_rounded), text: 'Streaks'),
            Tab(icon: Icon(Icons.leaderboard_rounded), text: 'Rankings'),
            Tab(icon: Icon(Icons.people_rounded), text: 'Social'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ExerciseScreen(user: user),
          const StreakScreen(),
          LeaderboardScreen(currentUid: user?.uid),
          const SocialScreen(),
        ],
      ),
    );
      },
    );
  }

  Widget _buildMenuButton(User? user) {
    final isDark = _settings.themeMode == ThemeMode.dark;
    String dispName = user?.displayName ?? '';
    if (dispName.trim().isEmpty) {
      dispName = 'Profile';
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 48),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
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
              dispName,
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
}