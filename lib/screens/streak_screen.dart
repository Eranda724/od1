import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../models/exercise_icons.dart';
import '../models/exercise_item.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/session_item.dart';
import '../services/streak_service.dart';
import 'exercise_start_screen.dart';

class StreakScreen extends StatefulWidget {
  final VoidCallback? onStartRoutine;

  const StreakScreen({super.key, this.onStartRoutine});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      StreakService.checkAndUpdateStreak(uid);
    }
  }

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
      return Center(child: Text('not_signed_in'.tr()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return Center(child: Text('error_loading'.tr(args: [userSnap.error.toString()])));
        }
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: PCColors.yellow));
        }

        final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final overallStreak = (data['overallStreak'] ?? 0) as int;
        final overallLastDate = data['overallLastDate'] as String?;
        final freezesAvailable = (data['freezesAvailable'] ?? 0) as int;
        final freezeLastRefillDate = data['freezeLastRefillDate'] as String?;
        final activeDates = List<String>.from(data['activeDates'] ?? []);
        final frozenDates = List<String>.from(data['frozenDates'] ?? []);
        final today = _todayKey();
        final last7 = _last7Days();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('exercises').snapshots(),
          builder: (context, userExSnap) {
            if (userExSnap.hasError) {
              return Center(child: Text('error_loading'.tr(args: [userExSnap.error.toString()])));
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
              return Center(child: Text('error_loading'.tr(args: [exSnap.error.toString()])));
            }
            final defs = <String, ExerciseItem>{};
            if (exSnap.hasData) {
              for (final doc in exSnap.data!.docs) {
                defs[doc.id] = ExerciseItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              }
            }

            final neverConfigured = data['selectedExercises'] == null;
            final selectedExercises = (data['selectedExercises'] as List<dynamic>?)?.map((e) => e.toString()).toList();
            final idsToShow = neverConfigured ? defs.keys.toList() : (selectedExercises ?? []);
            
            final todoExercises = <String>[];
            for (final id in idsToShow) {
              if (!defs.containsKey(id)) continue;
              final exData = Map<String, dynamic>.from(exercisesMap[id] ?? {});
              if (exData['lastCompletedDate'] != today) {
                todoExercises.add(id);
              }
            }

            final routineExercises = idsToShow.where((id) => defs.containsKey(id)).toList();
            final totalRoutine = routineExercises.length;
            final completedRoutine = totalRoutine - todoExercises.length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                // ── Overall streak hero card ────────────────────────────────
                _OverallStreakCard(
                  overallStreak: overallStreak,
                  lastDate: overallLastDate,
                  today: today,
                  last7Days: last7,
                  activeDates: activeDates,
                  frozenDates: frozenDates,
                  freezesAvailable: freezesAvailable,
                  freezeLastRefillDate: freezeLastRefillDate,
                  totalRoutine: totalRoutine,
                  completedRoutine: completedRoutine,
                ),

                const SizedBox(height: 16),

                // ── Start My Routine button ────────────────────────────
                Builder(
                  builder: (context) {

                    return Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(
                          bottom: BorderSide(
                            color: PCColors.greenDark,
                            width: 4,
                          ),
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (widget.onStartRoutine != null) {
                            widget.onStartRoutine!();
                          }
                          
                          if (idsToShow.isEmpty || defs.isEmpty) return;
                          
                          final targetList = todoExercises.isNotEmpty ? todoExercises : idsToShow;
                          List<SessionItem> queue = [];
                          for (final nextId in targetList) {
                            if (!defs.containsKey(nextId)) continue;
                            final exData = Map<String, dynamic>.from(exercisesMap[nextId] ?? {});
                            final tDef = defs[nextId]!;
                            queue.add(SessionItem(
                              exerciseId: nextId,
                              exerciseName: tDef.name,
                              streak: (exData['currentStreak'] ?? 0) as int,
                              lifetimeTotal: (exData['lifetimeTotal'] ?? 0) as int,
                              defaultReps: tDef.defaultReps,
                              defaultTimer: tDef.defaultTimer,
                              unit: tDef.unit,
                              exerciseDef: tDef,
                            ));
                          }
                          
                          if (queue.isEmpty) return;
                          
                          final first = queue.first;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExerciseStartScreen(
                                exerciseId: first.exerciseId,
                                exerciseName: first.exerciseName,
                                streak: first.streak,
                                lifetimeTotal: first.lifetimeTotal,
                                defaultReps: first.defaultReps,
                                defaultTimer: first.defaultTimer,
                                unit: first.unit,
                                exerciseDef: first.exerciseDef,
                                sessionQueue: queue,
                                exerciseIndex: 1,
                                totalExercises: queue.length,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PCColors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'start_my_routine'.tr().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── Section title ────────────────────────────────────────────
                Text(
                  'streaks_tab'.tr().toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: PCColors.yellow,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Per-exercise streak cards ─────────────────────────────────
                if (defs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('no_exercises_available'.tr()),
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
  final List<String> activeDates;
  final List<String> frozenDates;
  final int freezesAvailable;
  final String? freezeLastRefillDate;
  final int totalRoutine;
  final int completedRoutine;

  const _OverallStreakCard({
    required this.overallStreak,
    required this.lastDate,
    required this.today,
    required this.last7Days,
    required this.activeDates,
    required this.frozenDates,
    required this.freezesAvailable,
    required this.freezeLastRefillDate,
    required this.totalRoutine,
    required this.completedRoutine,
  });

  String _timeUntilNextFreeze() {
    if (freezesAvailable >= 2) return 'freezes_full'.tr();
    if (freezeLastRefillDate == null) return 'next_freeze_soon'.tr();
    final refillObj = DateTime.parse(freezeLastRefillDate!);
    final todayObj = DateTime.parse(today);
    final daysSince = todayObj.difference(refillObj).inDays;
    final daysLeft = 7 - daysSince;
    if (daysLeft <= 0) return 'next_freeze_today'.tr();
    return daysLeft > 1 ? 'next_freeze_in_days'.tr(args: [daysLeft.toString()]) : 'next_freeze_in_day'.tr();
  }

  Widget _buildFreezeSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Two freeze shield slots
          Row(
            children: List.generate(2, (index) {
              final isFilled = index < freezesAvailable;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FreezeShield(filled: isFilled),
              );
            }),
          ),
          const SizedBox(width: 12),
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'streak_freeze'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeUntilNextFreeze(),
                  style: TextStyle(
                    color: Colors.blueAccent.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActiveToday = lastDate == today;

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
              Text(
                'overall_streak'.tr().toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: PCColors.yellow,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (totalRoutine == 0 && isActiveToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PCColors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '✓ ${'today_label'.tr()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                )
              else if (totalRoutine > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: completedRoutine == totalRoutine ? PCColors.green : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    completedRoutine == totalRoutine ? '✓ ${'today_label'.tr()}' : '$completedRoutine/$totalRoutine',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: completedRoutine == totalRoutine ? Colors.white : Colors.white70,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'consecutive_days'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),

          const SizedBox(height: 16),

          // 7-day dot calendar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: last7Days.map((day) {
              final isActive = activeDates.contains(day);
              final isFrozen = frozenDates.contains(day);
              final isToday = day == today;
              return _DayDot(
                label: _shortDay(context, day),
                active: isActive,
                isFrozen: isFrozen,
                isToday: isToday,
              );
            }).toList(),
          ),

          _buildFreezeSection(context),
        ],
      ),
    );
  }

  String _shortDay(BuildContext context, String key) {
    final d = DateTime.parse(key);
    return DateFormat.E(context.locale.languageCode).format(d);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day dot widget (used in the 7-day mini calendar)
// ─────────────────────────────────────────────────────────────────────────────
class _DayDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool isFrozen;
  final bool isToday;

  const _DayDot({required this.label, required this.active, required this.isFrozen, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? PCColors.yellow : (isFrozen ? Colors.blue.withValues(alpha: 0.15) : Colors.white12),
            border: isToday
                ? Border.all(color: PCColors.yellow, width: 2)
                : (isFrozen ? Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 1) : null),
          ),
          child: active
              ? const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 16)),
                )
              : isFrozen 
                  ? const Center(
                      child: Text('❄️', style: TextStyle(fontSize: 14)),
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
            color: active ? PCColors.yellow : (isFrozen ? Colors.blueAccent : Colors.white38),
          ),
        ),
      ],
    );
  }
}

class _FreezeShield extends StatelessWidget {
  final bool filled;
  const _FreezeShield({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? Colors.blueAccent.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: filled
              ? Colors.blueAccent
              : Colors.white24,
          width: 2,
        ),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          filled ? '❄️' : '○',
          style: TextStyle(
            fontSize: filled ? 20 : 16,
            color: filled ? null : Colors.white24,
          ),
        ),
      ),
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
                      'total_streak_lifetime'.tr(args: [lifetime.toString(), def.unit]),
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
                    streak == 1 ? 'day_unit'.tr() : 'days_unit'.tr(),
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
