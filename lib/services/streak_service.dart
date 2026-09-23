import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'leaderboard_service.dart';

class StreakService {
  // Date helpers

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _todayKey() => _dateKey(DateTime.now());

  // ─── Core Simulation Engine ────────────────────────────────────────────────

  /// Simulates the streak and freeze state day-by-day, covering every past day
  /// from [fromDate]+1 up to (but NOT including) [toDate] (i.e. yesterday).
  ///
  /// For each day D in that range:
  ///   STEP 1 — Evaluate missed day:
  ///     • Skip if D is in [activeDates] or already in [frozenDates].
  ///     • If streak > 0 and D was missed:
  ///         – freeze available  → consume one; add D to frozenDates.
  ///                               If balance hits 0, start 15-day recharge timer.
  ///         – no freeze left    → streak = 0 (D stays grey blank).
  ///   STEP 2 — End-of-day recharge (fires AFTER miss evaluation):
  ///     • If nextFreezeRechargeDate ≤ D → restore freezesAvailable = 2.
  ///
  /// Today is never evaluated; it is passed only as the exclusive upper bound.
  static ({
    int streak,
    int freezesAvailable,
    List<String> frozenDates,
    String? nextFreezeRechargeDate,
  })
  _simulateForward({
    required int streak,
    required int freezesAvailable,
    required List<String> frozenDates,
    required String? nextFreezeRechargeDate,
    required List<String> activeDates,
    required DateTime fromDate,
    required DateTime toDate, // today — exclusive upper bound
    int freezeRechargePeriod = 15,
  }) {
    // Run from fromDate+1 through yesterday (toDate-1), inclusive.
    final DateTime yesterday = toDate.subtract(const Duration(days: 1));
    final int totalDays = yesterday.difference(fromDate).inDays;

    for (int i = 1; i <= totalDays; i++) {
      final DateTime day = fromDate.add(Duration(days: i));
      final String dayKey = _dateKey(day);

      final bool isActive = activeDates.contains(dayKey);
      final bool isAlreadyFrozen = frozenDates.contains(dayKey);

      // STEP 1 — Missed-day evaluation
      if (!isActive && !isAlreadyFrozen && streak > 0) {
        if (freezesAvailable > 0) {
          freezesAvailable--;
          frozenDates.add(dayKey);
          if (nextFreezeRechargeDate == null) {
            // First freeze consumed — start the recharge countdown.
            nextFreezeRechargeDate =
                _dateKey(day.add(Duration(days: freezeRechargePeriod)));
          }
        } else {
          // No freeze left — streak breaks; day stays a grey blank.
          streak = 0;
        }
      }

      // STEP 2 — End-of-day recharge (fires AFTER miss evaluation)
      if (nextFreezeRechargeDate != null) {
        final DateTime rechargeDate = DateTime.parse(nextFreezeRechargeDate);
        if (!day.isBefore(rechargeDate)) {
          freezesAvailable = 2;
          nextFreezeRechargeDate = null;
        }
      }
    }

    return (
      streak: streak,
      freezesAvailable: freezesAvailable,
      frozenDates: frozenDates,
      nextFreezeRechargeDate: nextFreezeRechargeDate,
    );
  }

  // ─── Public Display Helper ─────────────────────────────────────────────────

  /// Returns the effective (in-memory) state for UI display.
  ///
  /// Computes what the state would be right now without writing to Firestore.
  /// Requires [activeDates] to correctly skip exercise days.
  static ({
    int streak,
    int freezesAvailable,
    List<String> frozenDates,
    String? nextFreezeRechargeDate,
  })
  getEffectiveDisplayState({
    required int streak,
    required int freezesAvailable,
    required List<String> frozenDates,
    required String? nextFreezeRechargeDate,
    required List<String> activeDates,
    required String? lastEvaluatedDate,
    int freezeRechargePeriod = 15,
    DateTime? todayOverride,
  }) {
    if (lastEvaluatedDate == null) {
      return (
        streak: streak,
        freezesAvailable: freezesAvailable,
        frozenDates: frozenDates,
        nextFreezeRechargeDate: nextFreezeRechargeDate,
      );
    }

    final DateTime fromDate = DateTime.parse(lastEvaluatedDate);
    final DateTime todayObj = todayOverride ?? DateTime.parse(_todayKey());

    if (!fromDate.isBefore(todayObj)) {
      return (
        streak: streak,
        freezesAvailable: freezesAvailable,
        frozenDates: frozenDates,
        nextFreezeRechargeDate: nextFreezeRechargeDate,
      );
    }

    return _simulateForward(
      streak: streak,
      freezesAvailable: freezesAvailable,
      frozenDates: List<String>.from(frozenDates),
      nextFreezeRechargeDate: nextFreezeRechargeDate,
      activeDates: activeDates,
      fromDate: fromDate,
      toDate: todayObj,
      freezeRechargePeriod: freezeRechargePeriod,
    );
  }

  /// Returns the effective exercise-specific streak, protected by global frozen dates.
  ///
  /// A per-exercise missed day is forgiven only if that day is globally frozen.
  static ({int streak}) getEffectiveExerciseStreakData({
    required int streak,
    required String? lastEvaluatedDate,
    required List<String> globalFrozenDates,
  }) {
    if (streak == 0 || lastEvaluatedDate == null) {
      return (streak: streak);
    }

    final DateTime fromDate = DateTime.parse(lastEvaluatedDate);
    final DateTime todayObj = DateTime.parse(_todayKey());

    if (!fromDate.isBefore(todayObj)) {
      return (streak: streak);
    }

    final DateTime yesterday = todayObj.subtract(const Duration(days: 1));
    final int totalDays = yesterday.difference(fromDate).inDays;

    for (int i = 1; i <= totalDays; i++) {
      final DateTime day = fromDate.add(Duration(days: i));
      final String dayKey = _dateKey(day);
      if (!globalFrozenDates.contains(dayKey)) {
        // Missed and not globally frozen → exercise streak breaks.
        return (streak: 0);
      }
    }

    return (streak: streak);
  }

  // ─── Log Exercise ──────────────────────────────────────────────────────────

  /// Logs an exercise and returns a map of the updated stats.
  /// Completing any single exercise counts as a valid day for the overall streak.
  /// Throws an exception if the transaction fails.
  static Future<Map<String, int>> logExercise({
    required String uid,
    required String exerciseId,
    required String exerciseName,
    required int reps,
    int timeSpentSeconds = 0,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final exRef = userRef.collection('exercises').doc(exerciseId);

    final String today = _todayKey();
    final settingsSnap = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('settings')
        .get();
    final int freezeRechargePeriod =
        (settingsSnap.data()?['freezeRechargePeriodDays'] ?? 15) as int;

    final result = await FirebaseFirestore.instance
        .runTransaction<Map<String, int>>((tx) async {
      final snaps = await Future.wait([tx.get(userRef), tx.get(exRef)]);
      final userSnap = snaps[0];
      final userData = userSnap.data() ?? {};
      final exSnap = snaps[1];
      final exerciseData = exSnap.data() ?? {};

      // ── 1. Overall Streak ──
      final String? overallLastDate = userData['overallLastDate'] as String?;
      final int prevOverallStreak = (userData['overallStreak'] ?? 0) as int;

      int newOverallStreak = prevOverallStreak;
      final int prevTodayTimeSpent = (userData['todayTimeSpent'] ?? 0) as int;
      int newTodayTimeSpent = prevTodayTimeSpent + timeSpentSeconds;

      final newScores = LeaderboardService.calculateNewScores(
        existing: Map<String, dynamic>.from(
          userData['scores'] as Map<String, dynamic>? ?? {},
        ),
        points: reps,
        now: DateTime.now(),
      );

      // Default: same-day exercise — only update scores/time spent.
      Map<String, dynamic> overallStreakUpdate = {
        'scores': newScores,
        'todayTimeSpent': newTodayTimeSpent,
      };

      int globalFreezesAvailable = (userData['freezesAvailable'] ?? 2) as int;
      List<String> globalFrozenDates = List<String>.from(
        userData['frozenDates'] ?? [],
      );
      List<String> activeDates = List<String>.from(
        userData['activeDates'] ?? [],
      );
      String? newOverallNextFreezeRechargeDate =
          userData['nextFreezeRechargeDate'] as String?;

      final DateTime todayObj = DateTime.parse(today);

      if (overallLastDate != today) {
        // First exercise today — process any missed days since last evaluation.
        final String? lastEvaluatedDate =
            (userData['overallLastEvaluatedDate'] as String?) ?? overallLastDate;

        if (overallLastDate == null) {
          // TRUE first-ever exercise.
          newOverallStreak = 1;
          globalFreezesAvailable = 2;
          newOverallNextFreezeRechargeDate = null;
          globalFrozenDates.clear();
        } else if (prevOverallStreak == 0) {
          // Fresh restart after a broken streak.
          newOverallStreak = 1;
          // Still run simulation to catch any pending recharge.
          final sim = _simulateForward(
            streak: 0,
            freezesAvailable: globalFreezesAvailable,
            frozenDates: globalFrozenDates,
            nextFreezeRechargeDate: newOverallNextFreezeRechargeDate,
            activeDates: activeDates,
            fromDate: DateTime.parse(lastEvaluatedDate!),
            toDate: todayObj,
            freezeRechargePeriod: freezeRechargePeriod,
          );
          globalFreezesAvailable = sim.freezesAvailable;
          globalFrozenDates = sim.frozenDates;
          newOverallNextFreezeRechargeDate = sim.nextFreezeRechargeDate;
        } else {
          // Streak was alive — simulate forward and carry the result.
          final sim = _simulateForward(
            streak: prevOverallStreak,
            freezesAvailable: globalFreezesAvailable,
            frozenDates: globalFrozenDates,
            nextFreezeRechargeDate: newOverallNextFreezeRechargeDate,
            activeDates: activeDates,
            fromDate: DateTime.parse(lastEvaluatedDate!),
            toDate: todayObj,
            freezeRechargePeriod: freezeRechargePeriod,
          );
          globalFreezesAvailable = sim.freezesAvailable;
          globalFrozenDates = sim.frozenDates;
          newOverallNextFreezeRechargeDate = sim.nextFreezeRechargeDate;

          if (sim.streak == 0) {
            // Streak broke during the missed days — restart at 1 today.
            newOverallStreak = 1;
          } else {
            // Streak survived — increment.
            newOverallStreak = sim.streak + 1;
          }
        }

        if (!activeDates.contains(today)) {
          activeDates.add(today);
        }

        newTodayTimeSpent = timeSpentSeconds; // Reset for the new day.

        final String currentYear = todayObj.year.toString();
        final String? lastActiveYear = userData['lastActiveYear'] as String?;
        int prevYearlyActiveDays = (userData['yearlyActiveDays'] ?? 0) as int;
        if (lastActiveYear != currentYear) {
          prevYearlyActiveDays = 0;
        }
        final int newYearlyActiveDays = prevYearlyActiveDays + 1;

        overallStreakUpdate = {
          'scores': newScores,
          'todayTimeSpent': newTodayTimeSpent,
          'overallStreak': newOverallStreak,
          'overallLastDate': today,
          'overallLastEvaluatedDate': today,
          'freezesAvailable': globalFreezesAvailable,
          'nextFreezeRechargeDate': newOverallNextFreezeRechargeDate,
          'activeDates': activeDates,
          'frozenDates': globalFrozenDates,
          'yearlyActiveDays': newYearlyActiveDays,
          'lastActiveYear': currentYear,
        };
      }

      // ── 2. Exercise-specific stats ──
      final int prevLifetime = (exerciseData['lifetimeTotal'] ?? 0) as int;

      final String currentMonthStr = today.substring(0, 7);
      final String? lastMonthStr = exerciseData['lastMonthStr'] as String?;
      int prevMonthly = (exerciseData['monthlyTotal'] ?? 0) as int;
      if (lastMonthStr != currentMonthStr) {
        prevMonthly = 0;
      }
      final int newMonthly = prevMonthly + reps;

      final int prevStreak = (exerciseData['currentStreak'] ?? 0) as int;
      final String? lastDate = exerciseData['lastCompletedDate'] as String?;
      final int prevTodayReps = (exerciseData['todayReps'] ?? 0) as int;

      int newStreak = prevStreak;
      int newTodayReps = prevTodayReps;

      List<String> exActiveDates = List<String>.from(
        exerciseData['activeDates'] ?? [],
      );

      if (lastDate == today) {
        newTodayReps = prevTodayReps + reps;
      } else {
        newTodayReps = reps;

        final String? lastEvaluatedDate =
            (exerciseData['lastEvaluatedDate'] as String?) ?? lastDate;

        if (lastDate == null) {
          newStreak = 1;
        } else {
          final exResult = getEffectiveExerciseStreakData(
            streak: prevStreak,
            lastEvaluatedDate: lastEvaluatedDate,
            globalFrozenDates: globalFrozenDates, // use updated global dates
          );
          newStreak = exResult.streak == 0 ? 1 : prevStreak + 1;
        }

        if (!exActiveDates.contains(today)) {
          exActiveDates.add(today);
        }
      }

      final int newLifetime = prevLifetime + reps;

      tx.set(
        exRef,
        {
          'lifetimeTotal': newLifetime,
          'monthlyTotal': newMonthly,
          'lastMonthStr': currentMonthStr,
          'currentStreak': newStreak,
          'lastCompletedDate': today,
          'lastEvaluatedDate': today,
          'activeDates': exActiveDates,
          'todayReps': newTodayReps,
          'exerciseName': exerciseName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(userRef, overallStreakUpdate, SetOptions(merge: true));

      return {
        'lifetimeTotal': newLifetime,
        'monthlyTotal': newMonthly,
        'currentStreak': newStreak,
        'todayReps': newTodayReps,
        'overallStreak': newOverallStreak,
      };
    });

    try {
      await _updateSharedStreaks(
        uid: uid,
        newOverallStreak: result['overallStreak'] ?? 0,
      );
    } catch (e) {
      debugPrint('Error updating shared streaks: $e');
    }

    return result;
  }

  static Future<void> _updateSharedStreaks({
    required String uid,
    required int newOverallStreak,
  }) async {
    final pairsSnap = await FirebaseFirestore.instance
        .collection('friendPairs')
        .where('uids', arrayContains: uid)
        .get();

    if (pairsSnap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final pairDoc in pairsSnap.docs) {
      final uids = List<String>.from(pairDoc.data()['uids'] ?? []);
      final String friendUid =
          uids.firstWhere((id) => id != uid, orElse: () => '');
      if (friendUid.isEmpty) continue;

      final friendSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendUid)
          .get();
      if (!friendSnap.exists) continue;

      final friendData = friendSnap.data()!;
      final fEffective = getEffectiveDisplayState(
        streak: (friendData['overallStreak'] ?? 0) as int,
        freezesAvailable: (friendData['freezesAvailable'] ?? 2) as int,
        frozenDates: List<String>.from(friendData['frozenDates'] ?? []),
        nextFreezeRechargeDate:
            friendData['nextFreezeRechargeDate'] as String?,
        activeDates: List<String>.from(friendData['activeDates'] ?? []),
        lastEvaluatedDate:
            friendData['overallLastEvaluatedDate'] as String?,
      );

      final int sharedStreak = math.min(newOverallStreak, fEffective.streak);
      batch.update(pairDoc.reference, {'sharedStreak': sharedStreak});
    }

    await batch.commit();
  }

  // ─── Check Routine Completion ──────────────────────────────────────────────

  /// Checks if the user has completed their configured routine today.
  static Future<bool> checkRoutineCompletion(String uid) async {
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!userSnap.exists) return false;
    final userData = userSnap.data() ?? {};

    final rawSelected = userData['selectedExercises'];
    final bool neverConfigured = rawSelected == null;

    List<String> idsToShow;
    if (neverConfigured) {
      final defsSnap =
          await FirebaseFirestore.instance.collection('exercises').get();
      idsToShow = defsSnap.docs.map((d) => d.id).toList();
    } else {
      idsToShow = List<String>.from(rawSelected);
    }

    if (idsToShow.isEmpty) return false;

    final userExSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('exercises')
        .get();
    final userExData = <String, Map<String, dynamic>>{};
    for (final doc in userExSnap.docs) {
      userExData[doc.id] = doc.data();
    }

    final String today = _todayKey();
    int completed = 0;
    for (final id in idsToShow) {
      if (userExData[id]?['lastCompletedDate'] == today) {
        completed++;
      }
    }

    return completed == idsToShow.length;
  }

  // ─── Log Routine Completion ────────────────────────────────────────────────

  /// Logs the completion of the full routine and updates the overall streak.
  static Future<Map<String, int>> logRoutineCompletion(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final String today = _todayKey();

    final settingsSnap = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('settings')
        .get();
    final int freezeRechargePeriod =
        (settingsSnap.data()?['freezeRechargePeriodDays'] ?? 15) as int;

    return await FirebaseFirestore.instance
        .runTransaction<Map<String, int>>((tx) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};

      final int prevOverallStreak = (userData['overallStreak'] ?? 0) as int;
      final String? overallLastDate = userData['overallLastDate'] as String?;

      if (overallLastDate == today) {
        return {'overallStreak': prevOverallStreak};
      }

      final String? lastEvaluatedDate =
          (userData['overallLastEvaluatedDate'] as String?) ?? overallLastDate;

      int freezesAvailable = (userData['freezesAvailable'] ?? 2) as int;
      List<String> frozenDates = List<String>.from(
        userData['frozenDates'] ?? [],
      );
      List<String> activeDates = List<String>.from(
        userData['activeDates'] ?? [],
      );
      String? newOverallNextFreezeRechargeDate =
          userData['nextFreezeRechargeDate'] as String?;

      final DateTime todayObj = DateTime.parse(today);
      int newOverallStreak;

      if (overallLastDate == null) {
        newOverallStreak = 1;
        freezesAvailable = 2;
        newOverallNextFreezeRechargeDate = null;
        frozenDates.clear();
      } else if (prevOverallStreak == 0) {
        newOverallStreak = 1;
        final sim = _simulateForward(
          streak: 0,
          freezesAvailable: freezesAvailable,
          frozenDates: frozenDates,
          nextFreezeRechargeDate: newOverallNextFreezeRechargeDate,
          activeDates: activeDates,
          fromDate: DateTime.parse(lastEvaluatedDate!),
          toDate: todayObj,
          freezeRechargePeriod: freezeRechargePeriod,
        );
        freezesAvailable = sim.freezesAvailable;
        frozenDates = sim.frozenDates;
        newOverallNextFreezeRechargeDate = sim.nextFreezeRechargeDate;
      } else {
        final sim = _simulateForward(
          streak: prevOverallStreak,
          freezesAvailable: freezesAvailable,
          frozenDates: frozenDates,
          nextFreezeRechargeDate: newOverallNextFreezeRechargeDate,
          activeDates: activeDates,
          fromDate: DateTime.parse(lastEvaluatedDate!),
          toDate: todayObj,
          freezeRechargePeriod: freezeRechargePeriod,
        );
        freezesAvailable = sim.freezesAvailable;
        frozenDates = sim.frozenDates;
        newOverallNextFreezeRechargeDate = sim.nextFreezeRechargeDate;
        newOverallStreak = sim.streak == 0 ? 1 : prevOverallStreak + 1;
      }

      if (!activeDates.contains(today)) {
        activeDates.add(today);
      }

      tx.set(
        userRef,
        {
          'overallStreak': newOverallStreak,
          'overallLastDate': today,
          'overallLastEvaluatedDate': today,
          'freezesAvailable': freezesAvailable,
          'nextFreezeRechargeDate': newOverallNextFreezeRechargeDate,
          'activeDates': activeDates,
          'frozenDates': frozenDates,
        },
        SetOptions(merge: true),
      );

      return {'overallStreak': newOverallStreak};
    });
  }

  // ─── Check & Update Streak (app-open) ──────────────────────────────────────

  static Future<void>? _activeCheck;

  /// Runs on every app-open. Evaluates all missed past days (never today)
  /// and writes the updated state to Firestore.
  static Future<void> checkAndUpdateStreak(String uid) async {
    if (_activeCheck != null) {
      await _activeCheck;
      return;
    }
    _activeCheck = _doCheckAndUpdateStreak(uid);
    try {
      await _activeCheck;
    } finally {
      _activeCheck = null;
    }
  }

  static Future<void> _doCheckAndUpdateStreak(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      final settingsSnap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();
      final int freezeRechargePeriod =
          (settingsSnap.data()?['freezeRechargePeriodDays'] ?? 15) as int;

      // Pre-fetch exercise refs outside the transaction.
      final exercisesQuerySnap =
          await userRef.collection('exercises').get();
      final exerciseRefs =
          exercisesQuerySnap.docs.map((d) => d.reference).toList();

      int? updatedOverallStreak;

      await FirebaseFirestore.instance.runTransaction<void>((tx) async {
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) return;

        final exerciseDocs = await Future.wait(
          exerciseRefs.map((ref) => tx.get(ref)),
        );

        final userData = userSnap.data() ?? {};
        final DateTime todayObj = DateTime.parse(_todayKey());
        final Map<String, dynamic> updates = {};

        // ── 1. Overall Streak ──
        final String? overallLastDate =
            userData['overallLastDate'] as String?;
        final int overallStreak = (userData['overallStreak'] ?? 0) as int;
        List<String> frozenDates = List<String>.from(
          userData['frozenDates'] ?? [],
        );
        int freezesAvailable = (userData['freezesAvailable'] ?? 2) as int;
        String? nextFreezeRechargeDate =
            userData['nextFreezeRechargeDate'] as String?;

        if (overallLastDate != null) {
          final String lastEvaluatedDate =
              (userData['overallLastEvaluatedDate'] as String?) ??
              overallLastDate;
          final DateTime fromDate = DateTime.parse(lastEvaluatedDate);

          if (fromDate.isBefore(todayObj)) {
            final List<String> activeDates = List<String>.from(
              userData['activeDates'] ?? [],
            );

            final sim = _simulateForward(
              streak: overallStreak,
              freezesAvailable: freezesAvailable,
              frozenDates: frozenDates,
              nextFreezeRechargeDate: nextFreezeRechargeDate,
              activeDates: activeDates,
              fromDate: fromDate,
              toDate: todayObj,
              freezeRechargePeriod: freezeRechargePeriod,
            );

            updates['freezesAvailable'] = sim.freezesAvailable;
            updates['frozenDates'] = sim.frozenDates;
            updates['nextFreezeRechargeDate'] = sim.nextFreezeRechargeDate;

            // Advance the evaluation cursor to yesterday so that tomorrow's
            // run will pick up today as a potential missed day.
            final DateTime yesterday =
                todayObj.subtract(const Duration(days: 1));
            updates['overallLastEvaluatedDate'] = _dateKey(yesterday);

            if (sim.streak == 0 && overallStreak > 0) {
              updates['overallStreak'] = 0;
              updatedOverallStreak = 0;
            }

            // Keep local vars up-to-date for exercise evaluation below.
            frozenDates = List<String>.from(sim.frozenDates);
            freezesAvailable = sim.freezesAvailable;
          }
        }

        // ── 2. Individual Exercise Streaks ──
        for (final doc in exerciseDocs) {
          if (!doc.exists) continue;

          final exData = doc.data() ?? {};
          final String? lastCompletedDate =
              exData['lastCompletedDate'] as String?;
          final int currentStreak = (exData['currentStreak'] ?? 0) as int;
          if (lastCompletedDate == null || currentStreak == 0) continue;

          final String lastEvaluatedDate =
              (exData['lastEvaluatedDate'] as String?) ?? lastCompletedDate;
          final DateTime fromDate = DateTime.parse(lastEvaluatedDate);

          if (fromDate.isBefore(todayObj)) {
            final exResult = getEffectiveExerciseStreakData(
              streak: currentStreak,
              lastEvaluatedDate: lastEvaluatedDate,
              globalFrozenDates: frozenDates,
            );

            final DateTime exYesterday =
                todayObj.subtract(const Duration(days: 1));
            final Map<String, dynamic> exUpdates = {
              'lastEvaluatedDate': _dateKey(exYesterday),
            };

            if (exResult.streak == 0) {
              exUpdates['currentStreak'] = 0;
            }

            tx.set(doc.reference, exUpdates, SetOptions(merge: true));
          }
        }

        if (updates.isNotEmpty) {
          tx.set(userRef, updates, SetOptions(merge: true));
        }
      });

      // If the overall streak broke, update shared streaks.
      if (updatedOverallStreak != null) {
        await _updateSharedStreaks(
          uid: uid,
          newOverallStreak: updatedOverallStreak!,
        );
      }
    } catch (e) {
      debugPrint('Error in checkAndUpdateStreak: $e');
    }
  }
}
