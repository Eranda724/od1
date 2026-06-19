import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
import '../app_settings.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

// ── Mock leaderboard data ─────────────────────────────────────────────────────
const _mockLeaderboard = [
  {'name': 'CoachPotato', 'avatar': '🥇', 'streak': 143, 'uid': 'mock_1'},
  {'name': 'IronCouch', 'avatar': '🥈', 'streak': 98, 'uid': 'mock_2'},
  {'name': 'SquatKing', 'avatar': '🥉', 'streak': 87, 'uid': 'mock_3'},
  {'name': 'PushUpQueen', 'avatar': '💪', 'streak': 72, 'uid': 'mock_4'},
  {'name': 'LazyStar', 'avatar': '⭐', 'streak': 61, 'uid': 'mock_5'},
  {'name': 'SofaSurfer', 'avatar': '🏄', 'streak': 55, 'uid': 'mock_6'},
  {'name': 'GrumpyRep', 'avatar': '😤', 'streak': 44, 'uid': 'mock_7'},
  {'name': 'TinyGains', 'avatar': '🌱', 'streak': 33, 'uid': 'mock_8'},
  {'name': 'OneMoreRep', 'avatar': '🔥', 'streak': 21, 'uid': 'mock_9'},
  {'name': 'JustStarted', 'avatar': '🐣', 'streak': 7, 'uid': 'mock_10'},
];

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
          _ExerciseTab(user: user),
          _LeaderboardTab(currentUid: user?.uid),
        ],
      ),
    );
  }

  // ── Hamburger menu ──────────────────────────────────────────────────────────
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
              MaterialPageRoute(
                  builder: (context) => const SettingsScreen()),
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

// ── Exercise Tab ──────────────────────────────────────────────────────────────
class _ExerciseTab extends StatelessWidget {
  final User? user;
  const _ExerciseTab({required this.user});

  String _fallbackName(String id) {
    switch (id) {
      case 'pushups':
        return 'Push-Up';
      case 'squats':
        return 'Squat';
      case 'situps':
        return 'Sit-Up';
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = userSnapshot.data!.data() as Map<String, dynamic>?;

        final selectedExercises =
            data == null || (data['selectedExercises'] ?? []).isEmpty
                ? ['pushups', 'squats', 'situps']
                : List<String>.from(data['selectedExercises']);

        final exercises = data == null
            ? {
                'pushups': {'currentStreak': 47, 'lifetimeTotal': 12450},
                'squats': {'currentStreak': 0, 'lifetimeTotal': 647},
                'situps': {'currentStreak': 3, 'lifetimeTotal': 1210},
              }
            : Map<String, dynamic>.from(data['exercises'] ?? {});

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('exercises')
              .snapshots(),
          builder: (context, exerciseSnapshot) {
            final exerciseDefs = <String, ExerciseItem>{};
            if (exerciseSnapshot.hasData) {
              for (final doc in exerciseSnapshot.data!.docs) {
                exerciseDefs[doc.id] = ExerciseItem.fromMap(
                    doc.id, doc.data() as Map<String, dynamic>);
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: selectedExercises.length,
              itemBuilder: (context, index) {
                final id = selectedExercises[index];
                final exerciseData =
                    Map<String, dynamic>.from(exercises[id] ?? {});
                final streak = exerciseData['currentStreak'] ?? 0;
                final lifetime = exerciseData['lifetimeTotal'] ?? 0;

                final def = exerciseDefs[id];
                final displayName = def?.name ?? _fallbackName(id);
                final icon = def?.icon ?? '💪';
                final unit = def?.unit ?? 'reps';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          streak > 0
                              ? '🔥 $streak-Day $displayName Streak'
                              : '😔 0-Day $displayName Streak',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('$icon $lifetime Total $displayName ($unit)'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Start Exercise'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Leaderboard Tab ───────────────────────────────────────────────────────────
class _LeaderboardTab extends StatelessWidget {
  final String? currentUid;
  const _LeaderboardTab({this.currentUid});

  @override
  Widget build(BuildContext context) {
    // Sort mock data by streak descending (already sorted, but just in case)
    final sorted = [..._mockLeaderboard]
      ..sort((a, b) => (b['streak'] as int).compareTo(a['streak'] as int));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      itemCount: sorted.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context, sorted);
        }
        final entry = sorted[index - 1];
        final rank = index; // 1-based
        final isCurrentUser = entry['uid'] == currentUid;
        return _buildLeaderboardRow(context, rank, entry, isCurrentUser);
      },
    );
  }

  // Top 3 podium header
  Widget _buildHeader(
      BuildContext context, List<Map<String, Object>> sorted) {
    return Column(
      children: [
        const Text(
          '🏆 Top Streakers',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Who\'s been most consistent?',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 20),
        // Podium row — 2nd | 1st | 3rd
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _podiumItem(context, 2, sorted[1], 80, const Color(0xFFB0BEC5)),
            const SizedBox(width: 12),
            _podiumItem(context, 1, sorted[0], 100, const Color(0xFFFFC72C)),
            const SizedBox(width: 12),
            _podiumItem(context, 3, sorted[2], 70, const Color(0xFFCD7F32)),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _podiumItem(BuildContext context, int rank, Map<String, Object> entry,
      double height, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entry['avatar'] as String, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text(
          entry['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        Text(
          '${entry['streak']}🔥',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(height: 4),
        Container(
          width: 72,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: Colors.black, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(BuildContext context, int rank,
      Map<String, Object> entry, bool isCurrentUser) {
    final streak = entry['streak'] as int;
    final color = rank == 1
        ? const Color(0xFFFFC72C)
        : rank == 2
            ? const Color(0xFFB0BEC5)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFFFFC72C)
              : Theme.of(context).dividerColor,
          width: isCurrentUser ? 2.5 : 1.5,
        ),
        color: isCurrentUser
            ? const Color(0xFFFFC72C).withOpacity(0.08)
            : Theme.of(context).cardColor,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: (color ?? Theme.of(context).colorScheme.primary)
              .withOpacity(0.2),
          child: Text(
            entry['avatar'] as String,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Text(
              entry['name'] as String,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isCurrentUser ? const Color(0xFFB8860B) : null,
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC72C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '$streak day streak 🔥',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Text(
          '#$rank',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}