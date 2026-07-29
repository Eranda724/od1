import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../models/exercise_icons.dart';
import '../models/exercise_item.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/month_calendar_widget.dart';
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Center(child: Text('not_signed_in'.tr()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return Center(
            child: Text('error_loading'.tr(args: [userSnap.error.toString()])),
          );
        }
        if (!userSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: PCColors.yellow),
          );
        }

        final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final overallStreak = (data['overallStreak'] ?? 0) as int;
        final overallLastDate = data['overallLastDate'] as String?;
        final freezesAvailable = (data['freezesAvailable'] ?? 2) as int;
        final activeDates = List<String>.from(data['activeDates'] ?? []);
        final frozenDates = List<String>.from(data['frozenDates'] ?? []);
        final today = _todayKey();

        // Earliest active date = first day the user ever logged an exercise
        final String? userStartDate = activeDates.isNotEmpty
            ? (List<String>.from(activeDates)..sort()).first
            : null;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('exercises')
              .snapshots(),
          builder: (context, userExSnap) {
            if (userExSnap.hasError) {
              return Center(
                child: Text(
                  'error_loading'.tr(args: [userExSnap.error.toString()]),
                ),
              );
            }
            final exercisesMap = <String, dynamic>{};
            if (userExSnap.hasData) {
              for (final doc in userExSnap.data!.docs) {
                exercisesMap[doc.id] = doc.data() as Map<String, dynamic>;
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('exercises')
                  .snapshots(),
              builder: (context, exSnap) {
                if (exSnap.hasError) {
                  return Center(
                    child: Text(
                      'error_loading'.tr(args: [exSnap.error.toString()]),
                    ),
                  );
                }
                final defs = <String, ExerciseItem>{};
                if (exSnap.hasData) {
                  for (final doc in exSnap.data!.docs) {
                    defs[doc.id] = ExerciseItem.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    );
                  }
                }

                final neverConfigured = data['selectedExercises'] == null;
                final selectedExercises =
                    (data['selectedExercises'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList();
                final idsToShow = neverConfigured
                    ? defs.keys.toList()
                    : (selectedExercises ?? []);

                final todoExercises = <String>[];
                for (final id in idsToShow) {
                  if (!defs.containsKey(id)) continue;
                  final exData = Map<String, dynamic>.from(
                    exercisesMap[id] ?? {},
                  );
                  if (exData['lastCompletedDate'] != today) {
                    todoExercises.add(id);
                  }
                }

                final routineExercises = idsToShow
                    .where((id) => defs.containsKey(id))
                    .toList();
                final totalRoutine = routineExercises.length;
                final completedRoutine = totalRoutine - todoExercises.length;

                final userExercises = defs.entries.where((entry) {
                  final id = entry.key;
                  final exData = Map<String, dynamic>.from(
                    exercisesMap[id] ?? {},
                  );
                  final lastCompletedDate =
                      exData['lastCompletedDate'] as String?;
                  return lastCompletedDate == today;
                }).toList();

                userExercises.sort((a, b) {
                  final aData = Map<String, dynamic>.from(
                    exercisesMap[a.key] ?? {},
                  );
                  final bData = Map<String, dynamic>.from(
                    exercisesMap[b.key] ?? {},
                  );
                  final aStreak = (aData['currentStreak'] ?? 0) as int;
                  final bStreak = (bData['currentStreak'] ?? 0) as int;

                  if (aStreak > 0 && bStreak == 0) return -1;
                  if (bStreak > 0 && aStreak == 0) return 1;

                  if (aStreak != bStreak) return bStreak.compareTo(aStreak);

                  return a.value.name.compareTo(b.value.name);
                });

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  children: [
                    // ── Overall streak hero card ────────────────────────────────
                    _OverallStreakCard(
                      overallStreak: overallStreak,
                      lastDate: overallLastDate,
                      today: today,
                      activeDates: activeDates,
                      frozenDates: frozenDates,
                      freezesAvailable: freezesAvailable,
                      totalRoutine: totalRoutine,
                      completedRoutine: completedRoutine,
                      userStartDate: userStartDate,
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
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PCColors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'start_my_routine'.tr().toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
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
                    if (userExercises.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text('no_exercises_started_yet'.tr()),
                        ),
                      )
                    else
                      ...userExercises.map((entry) {
                        final id = entry.key;
                        final def = entry.value;
                        final exData = Map<String, dynamic>.from(
                          exercisesMap[id] ?? {},
                        );
                        final streak = (exData['currentStreak'] ?? 0) as int;
                        final lifetime = (exData['lifetimeTotal'] ?? 0) as int;
                        final lastDate = exData['lastCompletedDate'] as String?;
                        final doneToday = lastDate == today;

                        // Which of the last 7 days has this exercise been done?
                        // We only know today/yesterday with certainty from streak data.
                        return _ExerciseStreakCard(
                          def: def,
                          streak: streak,
                          lifetime: lifetime,
                          doneToday: doneToday,
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
  final List<String> activeDates;
  final List<String> frozenDates;
  final int freezesAvailable;
  final int totalRoutine;
  final int completedRoutine;
  final String? userStartDate;

  const _OverallStreakCard({
    required this.overallStreak,
    required this.lastDate,
    required this.today,
    required this.activeDates,
    required this.frozenDates,
    required this.freezesAvailable,
    required this.totalRoutine,
    required this.completedRoutine,
    this.userStartDate,
  });

  @override
  Widget build(BuildContext context) {
    final isActiveToday = lastDate == today;
    // isActiveToday is available for future use

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
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'freezes_label'.tr().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueAccent,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(2, (index) {
                      final hasFreeze = index < freezesAvailable;
                      return Container(
                        margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12, width: 1.5),
                          boxShadow: hasFreeze
                              ? [
                                  const BoxShadow(
                                    color: Colors.blueAccent,
                                    blurRadius: 6,
                                    spreadRadius: -3,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: hasFreeze
                              ? const Text('🧊', style: TextStyle(fontSize: 26))
                              : const SizedBox(),
                        ),
                      );
                    }),
                  ),
                ],
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
            ],
          ),

          MonthCalendarWidget(
            activeDates: activeDates,
            frozenDates: frozenDates,
            userStartDate: userStartDate,
          ),
        ],
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
  final String? lastCompletedDate;

  const _ExerciseStreakCard({
    required this.def,
    required this.streak,
    required this.lifetime,
    required this.doneToday,
    required this.lastCompletedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
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
                  child: buildExerciseIconWidget(
                    def.icon,
                    size: 24,
                    iconColor: PCColors.brownDark,
                  ),
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
                      'total_streak_lifetime'.tr(
                        args: [lifetime.toString(), def.unit],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
