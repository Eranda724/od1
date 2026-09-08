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
import '../widgets/notification_bell.dart';

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
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: _settings.isFirstLaunch ? 1 : 2,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
        title: StreamBuilder<DocumentSnapshot>(
          stream: user == null
              ? const Stream.empty()
              : FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
          builder: (context, snapshot) {
            final data =
                snapshot.data?.data() as Map<String, dynamic>?;
            final isPremium = data?['isPremium'] == true;
            if (isPremium) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PremiumUpgradeScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        size: 14,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.80)
                                : Colors.black.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'go_premium_banner'.tr(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.black.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        centerTitle: true,
        actions: [
          if (widget.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                  foregroundColor: Colors.white,
                  side: const BorderSide(
                    color: Color.fromARGB(255, 0, 0, 0),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                child: Text('admin_panel'.tr()),
              ),
            ),
          NotificationBell(
            onNavigateTab: (index) {
              _tabController.animateTo(index);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabController.index,
        onTap: (index) {
          _tabController.animateTo(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromARGB(255, 224, 138, 58),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            label: 'profile_menu'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.fitness_center_rounded),
            label: 'exercise_tab'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_fire_department_rounded),
            label: 'streaks_tab'.tr(),
          ),
          BottomNavigationBarItem(
            label: 'social_tab'.tr(),
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
          BottomNavigationBarItem(
            icon: const Icon(Icons.leaderboard_rounded),
            label: 'rankings_tab'.tr(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const ProfileScreen(isTab: true),
          ExerciseScreen(user: user),
          StreakScreen(
            tabController: _tabController,
            onStartRoutine: () {
              _tabController.animateTo(1);
            },
          ),
          const SocialScreen(),
          LeaderboardScreen(
            currentUid: user?.uid,
            onSwitchToSocial: () => _tabController.animateTo(3),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(User? user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              offset: const Offset(0, 48),
              onSelected: (value) async {
                switch (value) {
                  case 'profile':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                    break;
                  case 'settings':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
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
                      MaterialPageRoute(
                        builder: (context) => const PremiumUpgradeScreen(),
                      ),
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
                  child: Row(
                    children: [
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
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: isDark ? 'theme_light' : 'theme_dark',
                  child: Row(
                    children: [
                      Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(isDark ? 'light_mode'.tr() : 'dark_mode'.tr()),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('settings'.tr()),
                    ],
                  ),
                ),
                if (!isPremium) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'remove_ads',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: Color(0xFFFFC72C),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'remove_ads_menu'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'logout'.tr(),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
