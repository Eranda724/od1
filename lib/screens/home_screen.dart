import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'exercise_screen.dart';
import 'streak_screen.dart';
import 'leaderboard_screen.dart';
import 'social_screen.dart';
import 'admin_screen.dart';
import 'premium_upgrade_screen.dart';
import 'package:easy_localization/easy_localization.dart';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        title: Text('home_title'.tr()),
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

                child: Text('admin_panel'.tr()),
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
          tabs: [
            Tab(icon: const Icon(Icons.fitness_center_rounded), text: 'exercise_tab'.tr()),
            Tab(icon: const Icon(Icons.local_fire_department_rounded), text: 'streaks_tab'.tr()),
            Tab(icon: const Icon(Icons.leaderboard_rounded), text: 'rankings_tab'.tr()),
            Tab(
              text: 'social_tab'.tr(),
              icon: StreamBuilder<QuerySnapshot>(
                stream: user == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('friendRequests')
                        .where('toUid', isEqualTo: user.uid)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                builder: (context, snap) {
                  final hasPending = (snap.data?.docs.isNotEmpty) == true;
                  return Badge(
                    isLabelVisible: hasPending,
                    backgroundColor: Colors.red,
                    smallSize: 8,
                    child: const Icon(Icons.people_rounded),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ExerciseScreen(user: user),
          StreakScreen(onStartRoutine: () {
            _tabController.animateTo(0);
          }),
          LeaderboardScreen(currentUid: user?.uid),
          const SocialScreen(),
        ],
      ),
    );
  }

  Widget _buildMenuButton(User? user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final isPremium = data?['isPremium'] == true;

        // Prefer Firestore displayName (kept in sync on profile save) over
        // the cached Auth user object, which won't update mid-session.
        String dispName = (data?['displayName'] as String? ?? '').trim();
        if (dispName.isEmpty) {
          dispName = (user?.displayName ?? '').trim();
        }
        if (dispName.isEmpty) {
          dispName = 'profile_menu'.tr();
        }

        return ListenableBuilder(
          listenable: _settings,
          builder: (context, _) {
            final isDark = _settings.themeMode == ThemeMode.dark;
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
                  case 'remove_ads':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PremiumUpgradeScreen()),
                    );
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dispName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (isPremium)
                          Text(
                            'premium_user_badge'.tr(),
                            style: const TextStyle(
                              color: PCColors.yellow,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
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
                    Text(isDark ? 'light_mode'.tr() : 'dark_mode'.tr()),
                  ]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(children: [
                    const Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('settings'.tr()),
                  ]),
                ),
                if (!isPremium) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'remove_ads',
                    child: Row(children: [
                      const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFFC72C)),
                      const SizedBox(width: 10),
                      Text('remove_ads_menu'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(children: [
                    const Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                    const SizedBox(width: 10),
                    Text('logout'.tr(),
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            );
          },
        );
      },
    );
  }
}