import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../models/exercise_icons.dart';
import '../models/exercise_item.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/month_calendar_widget.dart';
import '../widgets/week_streak_row.dart';
import '../services/streak_service.dart';
import 'exercise_start_screen.dart';

class StreakScreen extends StatefulWidget {
  final VoidCallback? onStartRoutine;
  final TabController? tabController;

  const StreakScreen({super.key, this.onStartRoutine, this.tabController});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> with AutomaticKeepAliveClientMixin {
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
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  children: [
                    // ── Overall streak hero card ────────────────────────────────
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? PCColors.yellow
                            : Colors.black87,
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

// ─────────────────────────────────────────────────────────────────────────────
// Overall Streak Hero Card
// ─────────────────────────────────────────────────────────────────────────────
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
    // Revert to week view if a new page is pushed on top.
    // Tab switching is now explicitly handled by TabController listener above.
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
    final isActiveToday = widget.lastDate == widget.today;
    final isStreakActive = widget.overallStreak > 0;
    
    int displayFreezes = widget.freezesAvailable;
    bool usingProvisionalFreeze = false;
    
    if (!isActiveToday && isStreakActive && widget.freezesAvailable > 0) {
      usingProvisionalFreeze = true;
      displayFreezes -= 1;
    }

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
              const Icon(Icons.emoji_events, color: PCColors.yellow, size: 22),
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
            ],
          ),

          const SizedBox(height: 12),

          // Big streak number
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.overallStreak}',
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

          const SizedBox(height: 24),

          // Toggle Calendar View
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: WeekStreakRow(
                activeDates: widget.activeDates,
                frozenDates: widget.frozenDates,
                today: DateTime.now(),
                freezesAvailable: widget.freezesAvailable,
                streak: widget.overallStreak,
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

          const SizedBox(height: 16),

          // Streak Freeze Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black26, // Low dark background matching the image
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1.5),
            ),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(2, (index) {
                    final hasFreeze = index < displayFreezes;
                    return Container(
                      margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
                      width: 44, // Allocate same width to keep alignment
                      height: 44,
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // The hole container
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black26,
                            ),
                          ),
                          // The ice cube (filled or silhouette)
                          Transform.translate(
                            offset: const Offset(
                              0,
                              4,
                            ), // Shift down to vertically center
                            child: hasFreeze
                                ? Image.asset(
                                    'assets/images/ice_cube_3d.png',
                                    width: 52,
                                    height: 52,
                                  )
                                : Image.asset(
                                    'assets/images/ice_cube_3d.png',
                                    width: 52,
                                    height: 52,
                                    color: Colors.black54,
                                  ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Streak Freeze',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayFreezes == 2
                          ? '2 Freezes Available'
                          : displayFreezes == 1
                              ? '1 Freeze Available'
                              : usingProvisionalFreeze
                                  ? 'Last freeze is going on'
                                  : 'No freezes left!',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini Week Row for individual exercise cards
// ─────────────────────────────────────────────────────────────────────────────
class _MiniWeekRow extends StatelessWidget {
  final List<String> activeDates;
  final List<String> frozenDates;
  final int freezesAvailable;
  final int streak;

  const _MiniWeekRow({
    required this.activeDates,
    required this.frozenDates,
    required this.freezesAvailable,
    required this.streak,
  });

  String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((date) {
        final key = _dateKey(date);
        final isActive = activeDates.contains(key);
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        bool isFrozen = frozenDates.contains(key);

        if (isToday && !isActive && streak > 0 && freezesAvailable > 0) {
          isFrozen = true;
        }

        if (isActive) {
          return SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Image.asset(
                'assets/images/fire_3d.png',
                width: 28,
                height: 28,
              ),
            ),
          );
        }

        if (isFrozen) {
          return SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, 6), // move below slightly
                child: OverflowBox(
                  maxWidth: 80,
                  maxHeight: 80,
                  child: Image.asset(
                    'assets/images/ice_cube_3d.png',
                    width: 36,
                    height: 46,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.black.withOpacity(0.06),
          ),
        );
      }).toList(),
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MiniWeekRow(
            activeDates: activeDates,
            frozenDates: frozenDates,
            freezesAvailable: freezesAvailable,
            streak: streak,
          ),
        ],
      ),
    );
  }
}
