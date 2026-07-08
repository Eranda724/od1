import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../models/exercise_icons.dart';
import '../models/exercise_item.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // Returns last 7 day keys (oldest → newest)
  List<String> _last7Days() {
    final days = <String>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      days.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not signed in'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return Center(child: Text('Error: ${userSnap.error}'));
        }
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: PCColors.yellow));
        }

        final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final overallStreak = (data['overallStreak'] ?? 0) as int;
        final overallLastDate = data['overallLastDate'] as String?;
        final freezesAvailable = (data['freezesAvailable'] ?? 0) as int;
        final freezeLastRefillDate = data['freezeLastRefillDate'] as String?;
        final today = _todayKey();
        final last7 = _last7Days();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('exercises').snapshots(),
          builder: (context, userExSnap) {
            if (userExSnap.hasError) {
              return Center(child: Text('Error: ${userExSnap.error}'));
            }
            final exercisesMap = <String, dynamic>{};
            if (userExSnap.hasData) {
              for (final doc in userExSnap.data!.docs) {
                exercisesMap[doc.id] = doc.data() as Map<String, dynamic>;
              }
            }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
          builder: (context, exSnap) {
            if (exSnap.hasError) {
              return Center(child: Text('Error: ${exSnap.error}'));
            }
            final defs = <String, ExerciseItem>{};
            if (exSnap.hasData) {
              for (final doc in exSnap.data!.docs) {
                defs[doc.id] = ExerciseItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // ── Overall streak hero card ────────────────────────────────
                _OverallStreakCard(
                  overallStreak: overallStreak,
                  lastDate: overallLastDate,
                  today: today,
                  last7Days: last7,
                  exercisesMap: exercisesMap,
                  freezesAvailable: freezesAvailable,
                  freezeLastRefillDate: freezeLastRefillDate,
                ),

                const SizedBox(height: 24),

                // ── Section title ────────────────────────────────────────────
                const Text(
                  'EXERCISE STREAKS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: PCColors.yellow,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Per-exercise streak cards ─────────────────────────────────
                if (defs.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('No exercises yet.'),
                    ),
                  )
                else
                  ...defs.entries.map((entry) {
                    final id = entry.key;
                    final def = entry.value;
                    final exData = Map<String, dynamic>.from(exercisesMap[id] ?? {});
                    final streak = (exData['currentStreak'] ?? 0) as int;
                    final lifetime = (exData['lifetimeTotal'] ?? 0) as int;
                    final lastDate = exData['lastCompletedDate'] as String?;
                    final doneToday = lastDate == today;

                    // Which of the last 7 days has this exercise been done?
                    // We only know today/yesterday with certainty from streak data.
                    // Build a simplified dot row from streak count.
                    return _ExerciseStreakCard(
                      def: def,
                      streak: streak,
                      lifetime: lifetime,
                      doneToday: doneToday,
                      last7Days: last7,
                      lastCompletedDate: lastDate,
                    );
                  }),
              ],
            );
          },
        );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overall Streak Hero Card
// ─────────────────────────────────────────────────────────────────────────────
class _OverallStreakCard extends StatelessWidget {
  final int overallStreak;
  final String? lastDate;
  final String today;
  final List<String> last7Days;
  final Map<String, dynamic> exercisesMap;
  final int freezesAvailable;
  final String? freezeLastRefillDate;

  const _OverallStreakCard({
    required this.overallStreak,
    required this.lastDate,
    required this.today,
    required this.last7Days,
    required this.exercisesMap,
    required this.freezesAvailable,
    required this.freezeLastRefillDate,
  });

  // A day is "active" in the overall streak if any exercise was done that day.
  // We use the per-exercise lastCompletedDate to detect which days had activity.
  Set<String> _activeDays() {
    final active = <String>{};
    for (final exData in exercisesMap.values) {
      if (exData is Map) {
        final d = exData['lastCompletedDate'] as String?;
        if (d != null) active.add(d);
      }
    }
    return active;
  }

  String _timeUntilNextFreeze() {
    if (freezesAvailable >= 2) return 'Freezes full';
    if (freezeLastRefillDate == null) return 'Next freeze soon';
    final refillObj = DateTime.parse(freezeLastRefillDate!);
    final todayObj = DateTime.parse(today);
    final daysSince = todayObj.difference(refillObj).inDays;
    final daysLeft = 7 - daysSince;
    if (daysLeft <= 0) return 'Next freeze today!';
    return 'Next freeze in $daysLeft day${daysLeft > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final isActiveToday = lastDate == today;
    final activeDays = _activeDays();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PCColors.brownDark, Color(0xFF3A2010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'OVERALL STREAK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: PCColors.yellow,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (freezesAvailable > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent, width: 1),
                  ),
                  child: Text(
                    '❄️ $freezesAvailable/2',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (isActiveToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PCColors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✓ Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Big streak number
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$overallStreak',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: PCColors.yellow,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'consecutive\ndays',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _timeUntilNextFreeze(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 7-day dot calendar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: last7Days.map((day) {
              final isActive = activeDays.contains(day);
              final isToday = day == today;
              return _DayDot(
                label: _shortDay(day),
                active: isActive,
                isToday: isToday,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _shortDay(String key) {
    final d = DateTime.parse(key);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day dot widget (used in the 7-day mini calendar)
// ─────────────────────────────────────────────────────────────────────────────
class _DayDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool isToday;

  const _DayDot({required this.label, required this.active, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? PCColors.yellow : Colors.white12,
            border: isToday
                ? Border.all(color: PCColors.yellow, width: 2)
                : null,
          ),
          child: active
              ? const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 16)),
                )
              : isToday
                  ? const Center(
                      child: Text('•', style: TextStyle(color: PCColors.yellow, fontSize: 22, height: 1)),
                    )
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? PCColors.yellow : Colors.white38,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-exercise streak card
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseStreakCard extends StatelessWidget {
  final ExerciseItem def;
  final int streak;
  final int lifetime;
  final bool doneToday;
  final List<String> last7Days;
  final String? lastCompletedDate;

  const _ExerciseStreakCard({
    required this.def,
    required this.streak,
    required this.lifetime,
    required this.doneToday,
    required this.last7Days,
    required this.lastCompletedDate,
  });

  // Build a simple set of active days based on the streak count.
  // Since we only store lastCompletedDate (not full history), we reconstruct
  // approximately: fill back `streak` consecutive days ending at lastCompletedDate.
  Set<String> _estimatedActiveDays() {
    if (lastCompletedDate == null || streak == 0) return {};
    final active = <String>{};
    final last = DateTime.parse(lastCompletedDate!);
    for (int i = 0; i < streak && i < 7; i++) {
      final d = last.subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      active.add(key);
    }
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final activeDays = _estimatedActiveDays();
    final today = last7Days.last;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: doneToday ? PCColors.green : Theme.of(context).dividerColor,
          width: doneToday ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PCColors.yellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: buildExerciseIconWidget(def.icon, size: 24, iconColor: PCColors.brownDark),
                ),
              ),
              const SizedBox(width: 12),

              // Name + streak
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$lifetime total ${def.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Streak badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 2),
                      Text(
                        '$streak',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    streak == 1 ? 'day' : 'days',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 7-day mini dots
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: last7Days.map((day) {
              final isActive = activeDays.contains(day);
              final isToday = day == today;
              return _SmallDot(active: isActive, isToday: isToday);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SmallDot extends StatelessWidget {
  final bool active;
  final bool isToday;

  const _SmallDot({required this.active, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? PCColors.yellow
            : isToday
                ? PCColors.yellow.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.12),
        border: isToday && !active
            ? Border.all(color: PCColors.yellow, width: 1.5)
            : null,
      ),
      child: active
          ? const Center(child: Text('🔥', style: TextStyle(fontSize: 13)))
          : null,
    );
  }
}
