import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/month_calendar_widget.dart';
import '../widgets/week_streak_row.dart';
import '../services/streak_service.dart';
import '../widgets/exercise_thumbnail.dart';
import '../app_settings.dart';
import 'exercise_start_screen.dart';
import '../models/session_item.dart';

class StreakScreen extends StatefulWidget {
  final VoidCallback? onStartRoutine;
  final TabController? tabController;

  const StreakScreen({super.key, this.onStartRoutine, this.tabController});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<_OverallStreakCardState> _overallCardKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      StreakService.checkAndUpdateStreak(uid);
    }
    widget.tabController?.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant StreakScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabController != widget.tabController) {
      oldWidget.tabController?.removeListener(_onTabChanged);
      widget.tabController?.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    widget.tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    // If the tab is changed away from the Streak tab (index 1), collapse the month view
    if (widget.tabController != null && widget.tabController!.index != 1) {
      _overallCardKey.currentState?.collapse();
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            key: ValueKey('userSnap_loading'),
            child: CircularProgressIndicator(),
          );
        }

        final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final overallStreak = (data['overallStreak'] ?? 0) as int;
        final overallLastDate = data['overallLastDate'] as String?;
        final freezesAvailable = (data['freezesAvailable'] ?? 2) as int;
        final activeDates = List<String>.from(data['activeDates'] ?? []);
        final frozenDates = List<String>.from(data['frozenDates'] ?? []);
        final nextFreezeRechargeDate =
            data['nextFreezeRechargeDate'] as String?;
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
            if (!userExSnap.hasData) {
              return const Center(
                key: ValueKey('userExSnap_loading'),
                child: CircularProgressIndicator(),
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
                if (!exSnap.hasData) {
                  return const Center(
                    key: ValueKey('exSnap_loading'),
                    child: CircularProgressIndicator(),
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
                final doneExercises = <String>[];
                for (final id in idsToShow) {
                  if (!defs.containsKey(id)) continue;
                  final exData = Map<String, dynamic>.from(
                    exercisesMap[id] ?? {},
                  );
                  if (exData['lastCompletedDate'] == today) {
                    doneExercises.add(id);
                  } else {
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
                  final currentStreak = (exData['currentStreak'] ?? 0) as int;
                  return currentStreak > 0;
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    // Overall streak hero card
                    _OverallStreakCard(
                      key: _overallCardKey,
                      overallStreak: overallStreak,
                      lastDate: overallLastDate,
                      today: today,
                      activeDates: activeDates,
                      frozenDates: frozenDates,
                      freezesAvailable: freezesAvailable,
                      totalRoutine: totalRoutine,
                      completedRoutine: completedRoutine,
                      userStartDate: userStartDate,
                      nextFreezeRechargeDate: nextFreezeRechargeDate,
                    ),

                    const SizedBox(
                      height: 16,
                    ), // Added gap between hero card and Start Routine button
                    // Start My Routine button
                    if (todoExercises.isNotEmpty)
                      Builder(
                        builder: (context) {
                          return Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFF3D8B5D),
                                  offset: Offset(0, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                if (todoExercises.isNotEmpty) {
                                  final targetId = todoExercises.first;
                                  final targetDef = defs[targetId];
                                  if (targetDef != null) {
                                    final targetExData =
                                        Map<String, dynamic>.from(
                                          exercisesMap[targetId] ?? {},
                                        );
                                    final targetStreak =
                                        targetExData['currentStreak'] ?? 0;
                                    final targetMonthlyTotal =
                                        targetExData['monthlyTotal'] ?? 0;

                                    List<SessionItem> queue = [];
                                    int totalTodos = todoExercises.length;

                                    for (
                                      int i = 1;
                                      i < todoExercises.length;
                                      i++
                                    ) {
                                      final nextId = todoExercises[i];
                                      final nEx = Map<String, dynamic>.from(
                                        exercisesMap[nextId] ?? {},
                                      );
                                      final nDef = defs[nextId];
                                      queue.add(
                                        SessionItem(
                                          exerciseId: nextId,
                                          exerciseName: nDef?.name ?? nextId,
                                          description:
                                              (nDef?.description?.isNotEmpty ==
                                                  true)
                                              ? nDef!.description
                                              : 'default_exercise_description'
                                                    .tr(),
                                          streak: nEx['currentStreak'] ?? 0,
                                          monthlyTotal:
                                              nEx['monthlyTotal'] ?? 0,
                                          defaultReps: nDef?.defaultReps ?? 0,
                                          defaultTimer: nDef?.defaultTimer ?? 0,
                                          unit: nDef?.unit ?? 'reps',
                                          exerciseDef: nDef,
                                        ),
                                      );
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ExerciseStartScreen(
                                          exerciseId: targetId,
                                          exerciseName: targetDef.name,
                                          description:
                                              (targetDef
                                                      .description
                                                      ?.isNotEmpty ==
                                                  true)
                                              ? targetDef.description
                                              : 'default_exercise_description'
                                                    .tr(),
                                          streak: targetStreak,
                                          monthlyTotal: targetMonthlyTotal,
                                          defaultReps: targetDef.defaultReps,
                                          defaultTimer: targetDef.defaultTimer,
                                          unit: targetDef.unit,
                                          exerciseDef: targetDef,
                                          sessionQueue: queue,
                                          exerciseIndex: 1,
                                          totalExercises: totalTodos,
                                        ),
                                      ),
                                    );
                                  }
                                } else if (widget.onStartRoutine != null) {
                                  widget.onStartRoutine!();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF55AB78),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                'start_my_routine'.tr().toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // START AGAIN button (all exercises done today)
                    if (todoExercises.isEmpty && doneExercises.isNotEmpty)
                      Builder(
                        builder: (context) {
                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xFF3D8B5D),
                                      offset: Offset(0, 4),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (doneExercises.isNotEmpty) {
                                      final targetId = doneExercises.first;
                                      final targetDef = defs[targetId];
                                      if (targetDef != null) {
                                        final targetExData =
                                            Map<String, dynamic>.from(
                                              exercisesMap[targetId] ?? {},
                                            );
                                        // Build full queue so all done exercises replay
                                        final List<SessionItem> fullQueue = [];
                                        for (
                                          int i = 1;
                                          i < doneExercises.length;
                                          i++
                                        ) {
                                          final nextId = doneExercises[i];
                                          final nEx = Map<String, dynamic>.from(
                                            exercisesMap[nextId] ?? {},
                                          );
                                          final nDef = defs[nextId];
                                          fullQueue.add(
                                            SessionItem(
                                              exerciseId: nextId,
                                              exerciseName:
                                                  nDef?.name ?? nextId,
                                              description:
                                                  (nDef
                                                          ?.description
                                                          ?.isNotEmpty ==
                                                      true)
                                                  ? nDef!.description
                                                  : 'default_exercise_description'
                                                        .tr(),
                                              streak: nEx['currentStreak'] ?? 0,
                                              monthlyTotal:
                                                  nEx['monthlyTotal'] ?? 0,
                                              defaultReps:
                                                  nDef?.defaultReps ?? 0,
                                              defaultTimer:
                                                  nDef?.defaultTimer ?? 0,
                                              unit: nDef?.unit ?? 'reps',
                                              exerciseDef: nDef,
                                            ),
                                          );
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ExerciseStartScreen(
                                              exerciseId: targetId,
                                              exerciseName: targetDef.name,
                                              description:
                                                  (targetDef
                                                          .description
                                                          ?.isNotEmpty ==
                                                      true)
                                                  ? targetDef.description
                                                  : 'default_exercise_description'
                                                        .tr(),
                                              streak:
                                                  targetExData['currentStreak'] ??
                                                  0,
                                              monthlyTotal:
                                                  targetExData['monthlyTotal'] ??
                                                  0,
                                              defaultReps:
                                                  targetDef.defaultReps,
                                              defaultTimer:
                                                  targetDef.defaultTimer,
                                              unit: targetDef.unit,
                                              exerciseDef: targetDef,
                                              sessionQueue: fullQueue,
                                              exerciseIndex: 1,
                                              totalExercises:
                                                  doneExercises.length,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF55AB78),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    'start_again'.tr().toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    // Section title
                    if (userExercises.isNotEmpty)
                      Builder(
                        builder: (context) {
                          int estimatedSeconds = 0;
                          for (final entry in userExercises) {
                            final def = entry.value;
                            estimatedSeconds += (def.defaultTimer > 0)
                                ? def.defaultTimer
                                : 60;
                          }
                          final estimatedMins = (estimatedSeconds / 60).ceil();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'exercises_title'.tr().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${'exercises_count'.tr(args: [userExercises.length.toString()])} - ~$estimatedMins min',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),

                    // Per-exercise streak cards
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

                        List<String> exActiveDates = List<String>.from(
                          exData['activeDates'] ?? [],
                        );
                        final List<String> exFrozenDates = List<String>.from(
                          exData['frozenDates'] ?? [],
                        );
                        final int exFreezesAvailable =
                            (exData['freezesAvailable'] ?? 2) as int;

                        // Fallback: If database has a legacy streak number but no saved dates yet, fill the UI to match
                        if (streak > 0 &&
                            lastDate != null &&
                            exActiveDates.length < streak) {
                          try {
                            final lastDateObj = DateTime.parse(lastDate);
                            final int fillCount = streak > 7 ? 7 : streak;
                            for (int i = 0; i < fillCount; i++) {
                              final d = lastDateObj.subtract(Duration(days: i));
                              final key =
                                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                              if (!exActiveDates.contains(key) &&
                                  !exFrozenDates.contains(key)) {
                                exActiveDates.add(key);
                              }
                            }
                          } catch (_) {}
                        }

                        return _ExerciseStreakCard(
                          def: def,
                          streak: streak,
                          lifetime: lifetime,
                          doneToday: doneToday,
                          lastCompletedDate: lastDate,
                          activeDates: exActiveDates,
                          frozenDates: exFrozenDates,
                          freezesAvailable: exFreezesAvailable,
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

// Overall Streak Hero Card
class _OverallStreakCard extends StatefulWidget {
  final int overallStreak;
  final String? lastDate;
  final String today;
  final List<String> activeDates;
  final List<String> frozenDates;
  final int freezesAvailable;
  final int totalRoutine;
  final int completedRoutine;
  final String? userStartDate;
  final String? nextFreezeRechargeDate;

  const _OverallStreakCard({
    super.key,
    required this.overallStreak,
    required this.lastDate,
    required this.today,
    required this.activeDates,
    required this.frozenDates,
    required this.freezesAvailable,
    required this.totalRoutine,
    required this.completedRoutine,
    this.userStartDate,
    this.nextFreezeRechargeDate,
  });

  @override
  State<_OverallStreakCard> createState() => _OverallStreakCardState();
}

class _OverallStreakCardState extends State<_OverallStreakCard> {
  bool _isExpanded = false;

  void collapse() {
    if (mounted && _isExpanded) {
      setState(() {
        _isExpanded = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;

    if (!isCurrentRoute && _isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isExpanded) {
          setState(() {
            _isExpanded = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int displayFreezes = widget.freezesAvailable;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomColor = isDark
        ? (Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor)
        : Colors.white;

    String? countdownText;
    if (displayFreezes < 2 && widget.nextFreezeRechargeDate != null) {
      try {
        final rechargeDate = DateTime.parse(widget.nextFreezeRechargeDate!);
        final todayObj = DateTime.parse(widget.today);
        final diff = rechargeDate.difference(todayObj).inDays;
        if (diff > 0) {
          countdownText = 'next_freeze_in_days'.tr(args: [diff.toString()]);
        } else if (diff == 0) {
          countdownText = 'next_freeze_tomorrow'.tr();
        }
      } catch (_) {}
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bottomColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  left: 20,
                  top: 18,
                  right: 8,
                  bottom: 18,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFffc226),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Streak Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // PERSONAL label
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'personal_caps'.tr(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF5A3D00),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          // Fire + Number + DAY STREAK
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/fire_3d.png',
                                height: 52,
                                width: 52,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              // Number + DAY STREAK stacked
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        widget.overallStreak.toString(),
                                        style: const TextStyle(
                                          fontSize: 68,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF332200),
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'day_streak_caps'.tr(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF7A5000),
                                          letterSpacing: 2.0,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Right Column: Mascot
                    Transform.translate(
                      offset: const Offset(8, -8),
                      child: Image.asset(
                        'assets/images/potato_home_screen.png',
                        height: 170,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. TOGGLE CALENDAR VIEW (Bottom White Box)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: 16,
                    bottom: 16,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: bottomColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WeekStreakRow(
                          activeDates: widget.activeDates,
                          frozenDates: widget.frozenDates,
                          today: DateTime.now(),
                          freezesAvailable: widget.freezesAvailable,
                          streak: widget.overallStreak,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(2, (index) {
                                final hasFreeze = index < displayFreezes;
                                return Container(
                                  margin: EdgeInsets.only(
                                    right: index == 0 ? 4 : 0,
                                  ),
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  child: Image.asset(
                                    'assets/images/ice_cube_3d.png',
                                    width: 28,
                                    height: 28,
                                    color: hasFreeze ? null : Colors.black26,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'streak_freeze_title'.tr(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  displayFreezes == 2
                                      ? 'two_freezes_available'.tr()
                                      : displayFreezes == 1
                                      ? 'one_freeze_available'.tr()
                                      : 'no_freezes_left'.tr(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.blueAccent.shade200
                                        : Colors.blueAccent,
                                  ),
                                ),
                                if (countdownText != null)
                                  Text(
                                    countdownText,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.orangeAccent.shade200
                                          : Colors.orangeAccent.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    secondChild: MonthCalendarWidget(
                      activeDates: widget.activeDates,
                      frozenDates: widget.frozenDates,
                      userStartDate: widget.userStartDate,
                      freezesAvailable: widget.freezesAvailable,
                      streak: widget.overallStreak,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Per-exercise streak card
class _ExerciseStreakCard extends StatelessWidget {
  final ExerciseItem def;
  final int streak;
  final int lifetime;
  final bool doneToday;
  final String? lastCompletedDate;
  final List<String> activeDates;
  final List<String> frozenDates;
  final int freezesAvailable;

  const _ExerciseStreakCard({
    required this.def,
    required this.streak,
    required this.lifetime,
    required this.doneToday,
    required this.lastCompletedDate,
    required this.activeDates,
    required this.frozenDates,
    required this.freezesAvailable,
  });

  @override
  Widget build(BuildContext context) {
    int displayFreezes = freezesAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ExerciseThumbnail(def: def, width: 56, height: 56, iconSize: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.name,
                        style: TextStyle(
                          fontSize: 18,
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
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    streak == 1
                        ? '${'day_unit'.tr()} streak'
                        : '${'days_unit'.tr()} streak',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (freezesAvailable > 0) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, 1.5),
                            child: Image.asset(
                              'assets/images/ice_cube_3d.png',
                              width: 12,
                              height: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$displayFreezes/2',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          WeekStreakRow(
            activeDates: activeDates,
            frozenDates: frozenDates,
            today: DateTime.now(),
            freezesAvailable: freezesAvailable,
            streak: streak,
          ),
        ],
      ),
    );
  }
}
