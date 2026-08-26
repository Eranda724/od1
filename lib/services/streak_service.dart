import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'leaderboard_service.dart';

class StreakService {
  // Date helpers

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _todayKey() => _dateKey(DateTime.now());

  static ({int freezesAvailable, String? nextFreezeRechargeDate}) _recalculateFreezes({
    required List<String> frozenDates,
    required int freezeRechargePeriod,
    required DateTime currentDay,
  }) {
    int maxFreezes = 2;
    int usedInWindow = 0;
    DateTime? oldestInWindow;

    for (String dateStr in frozenDates) {
      DateTime frozenDate = DateTime.parse(dateStr);
      int daysSince = currentDay.difference(frozenDate).inDays;
      
      // If the freeze was used strictly less than 'freezeRechargePeriod' days ago, it is still recharging
      if (daysSince >= 0 && daysSince < freezeRechargePeriod) {
        usedInWindow++;
        if (oldestInWindow == null || frozenDate.isBefore(oldestInWindow)) {
          oldestInWindow = frozenDate;
        }
      }
    }

    int available = maxFreezes - usedInWindow;
    if (available < 0) available = 0;
    if (available > maxFreezes) available = maxFreezes;

    String? nextRecharge;
    if (available < maxFreezes && oldestInWindow != null) {
      nextRecharge = _dateKey(oldestInWindow.add(Duration(days: freezeRechargePeriod)));
    }

    return (freezesAvailable: available, nextFreezeRechargeDate: nextRecharge);
  }

  // Core freeze helper
  static ({
    int freezesAvailable,
    List<String> frozenDates,
    bool streakBroken,
    String? nextFreezeRechargeDate,
  })
  _applyMissedDays({
    required DateTime fromDate,
    required DateTime toDate,
    required List<String> frozenDates,
    required int freezeRechargePeriod,
  }) {
    bool streakBroken = false;
    final totalDays = toDate.difference(fromDate).inDays;

    for (int i = 1; i <= totalDays; i++) {
      final currentDay = fromDate.add(Duration(days: i));
      final currentKey = _dateKey(currentDay);
      final isToday = i == totalDays;

      // 1. Recalculate available freezes for the current day based on past frozenDates
      final freezeData = _recalculateFreezes(
        frozenDates: frozenDates,
        freezeRechargePeriod: freezeRechargePeriod,
        currentDay: currentDay,
      );
      int currentFreezes = freezeData.freezesAvailable;

      // 2. Process Missed Days (Skip today, as today is not yet missed)
      if (!isToday && !streakBroken) {
        if (currentFreezes > 0) {
          if (!frozenDates.contains(currentKey)) {
            frozenDates.add(currentKey);
          }
        } else {
          streakBroken = true;
        }
      }
    }

    // Final calculation for the end date (toDate)
    final finalData = _recalculateFreezes(
      frozenDates: frozenDates,
      freezeRechargePeriod: freezeRechargePeriod,
      currentDay: toDate,
    );

    return (
      freezesAvailable: finalData.freezesAvailable,
      frozenDates: frozenDates,
      streakBroken: streakBroken,
      nextFreezeRechargeDate: finalData.nextFreezeRechargeDate,
    );
  }

  /// Calculates the effective streak and freezes for a user based on their last evaluated date.
  /// This is purely read-only and in-memory. It computes what the streak WOULD be
  /// if they evaluated right now, without writing to the database.
  static ({
    int streak,
    int freezesAvailable,
    List<String> frozenDates,
    String? nextFreezeRechargeDate,
  })
  getEffectiveStreakData({
    required int streak,
    required int freezesAvailable,
    required List<String> frozenDates,
    required String? lastEvaluatedDate,
    int freezeRechargePeriod = 15,
    String? nextFreezeRechargeDate,
  }) {
    if (streak == 0 || lastEvaluatedDate == null) {
      return (
        streak: streak,
        freezesAvailable: freezesAvailable,
        frozenDates: frozenDates,
        nextFreezeRechargeDate: nextFreezeRechargeDate,
      );
    }

    final fromDate = DateTime.parse(lastEvaluatedDate);
    final todayObj = DateTime.parse(_todayKey());

    if (fromDate.isAtSameMomentAs(todayObj) || fromDate.isAfter(todayObj)) {
      return (
        streak: streak,
        freezesAvailable: freezesAvailable,
        frozenDates: frozenDates,
        nextFreezeRechargeDate: nextFreezeRechargeDate,
      );
    }

    final result = _applyMissedDays(
      fromDate: fromDate,
      toDate: todayObj,
      frozenDates: List.from(frozenDates),
      freezeRechargePeriod: freezeRechargePeriod,
    );

    return (
      streak: result.streakBroken ? 0 : streak,
      freezesAvailable: result.freezesAvailable,
      frozenDates: result.frozenDates,
      nextFreezeRechargeDate: result.nextFreezeRechargeDate,
    );
  }

  // Log Exercise

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

    final today = _todayKey();
    final settingsSnap = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('settings')
        .get();
    final freezeRechargePeriod =
        (settingsSnap.data()?['freezeRechargePeriodDays'] ?? 15) as int;

    final result = await FirebaseFirestore.instance.runTransaction<Map<String, int>>((
      tx,
    ) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};

      final exSnap = await tx.get(exRef);
      final exerciseData = exSnap.data() ?? {};

      // Exercise-specific stats
      final prevLifetime = (exerciseData['lifetimeTotal'] ?? 0) as int;

      final currentMonthStr = today.substring(0, 7); // e.g. '2026-08'
      final lastMonthStr = exerciseData['lastMonthStr'] as String?;
      int prevMonthly = (exerciseData['monthlyTotal'] ?? 0) as int;
      if (lastMonthStr != currentMonthStr) {
        prevMonthly = 0;
      }
      final newMonthly = prevMonthly + reps;

      final prevStreak = (exerciseData['currentStreak'] ?? 0) as int;
      final lastDate = exerciseData['lastCompletedDate'] as String?;
      final prevTodayReps = (exerciseData['todayReps'] ?? 0) as int;

      int newStreak = prevStreak;
      int newTodayReps = prevTodayReps;

      int exFreezesAvailable = (exerciseData['freezesAvailable'] ?? 2) as int;
      List<String> exFrozenDates = List<String>.from(
        exerciseData['frozenDates'] ?? [],
      );
      List<String> exActiveDates = List<String>.from(
        exerciseData['activeDates'] ?? [],
      );
      String? newExNextFreezeRechargeDate =
          exerciseData['nextFreezeRechargeDate'] as String?;

      if (lastDate == today) {
        newTodayReps = prevTodayReps + reps;
      } else {
        newTodayReps = reps;

        final todayObj = DateTime.parse(today);

        final lastEvaluatedDate =
            (exerciseData['lastEvaluatedDate'] as String?) ?? lastDate;
        if (lastDate == null) {
          // First ever exercise
          newStreak = 1;
          exFreezesAvailable = 2;
          newExNextFreezeRechargeDate = null;
        } else {
          // Sequential freeze evaluation for this exercise
          final fromDate = DateTime.parse(lastEvaluatedDate!);
          final result = _applyMissedDays(
            fromDate: fromDate,
            toDate: todayObj,
            frozenDates: exFrozenDates,
            freezeRechargePeriod: freezeRechargePeriod,
          );
          exFreezesAvailable = result.freezesAvailable;
          exFrozenDates = result.frozenDates;
          newExNextFreezeRechargeDate = result.nextFreezeRechargeDate;
          newStreak = result.streakBroken ? 1 : prevStreak + 1;
        }

        if (!exActiveDates.contains(today)) {
          exActiveDates.add(today);
        }
      }

      final newLifetime = prevLifetime + reps;

      tx.set(exRef, {
        'lifetimeTotal': newLifetime,
        'monthlyTotal': newMonthly,
        'lastMonthStr': currentMonthStr,
        'currentStreak': newStreak,
        'lastCompletedDate': today,
        'lastEvaluatedDate': today,
        'freezesAvailable': exFreezesAvailable,
        'nextFreezeRechargeDate': newExNextFreezeRechargeDate,
        'frozenDates': exFrozenDates,
        'activeDates': exActiveDates,
        'todayReps': newTodayReps,
        'exerciseName': exerciseName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Leaderboard Scores
      final newScores = LeaderboardService.calculateNewScores(
        existing: Map<String, dynamic>.from(
          userData['scores'] as Map<String, dynamic>? ?? {},
        ),
        points: reps,
        now: DateTime.now(),
      );

      // Overall Streak Logic
      final overallLastDate = userData['overallLastDate'] as String?;
      final prevOverallStreak = (userData['overallStreak'] ?? 0) as int;

      int newOverallStreak = prevOverallStreak;
      int prevTodayTimeSpent = (userData['todayTimeSpent'] ?? 0) as int;
      int newTodayTimeSpent = prevTodayTimeSpent + timeSpentSeconds;

      // Default: same-day exercise — only update scores, time spent, no streak/freeze changes
      Map<String, dynamic> overallStreakUpdate = {
        'scores': newScores,
        'todayTimeSpent': newTodayTimeSpent,
      };

      if (overallLastDate != today) {
        // First exercise today — process any missed days since last evaluation
        final lastEvaluatedDate =
            (userData['overallLastEvaluatedDate'] as String?) ??
            overallLastDate;

        int freezesAvailable = (userData['freezesAvailable'] ?? 2) as int;
        List<String> frozenDates = List<String>.from(
          userData['frozenDates'] ?? [],
        );
        List<String> activeDates = List<String>.from(
          userData['activeDates'] ?? [],
        );
        String? newOverallNextFreezeRechargeDate =
            userData['nextFreezeRechargeDate'] as String?;

        final todayObj = DateTime.parse(today);

        if (overallLastDate == null) {
          // First ever exercise
          newOverallStreak = 1;
          freezesAvailable = 2;
          newOverallNextFreezeRechargeDate = null;
        } else {
          // Sequential freeze evaluation — unified path, no special cases
          final fromDate = DateTime.parse(lastEvaluatedDate!);
          final result = _applyMissedDays(
            fromDate: fromDate,
            toDate: todayObj,
            frozenDates: frozenDates,
            freezeRechargePeriod: freezeRechargePeriod,
          );
          freezesAvailable = result.freezesAvailable;
          frozenDates = result.frozenDates;
          newOverallNextFreezeRechargeDate = result.nextFreezeRechargeDate;
          newOverallStreak = result.streakBroken ? 1 : prevOverallStreak + 1;
        }

        if (!activeDates.contains(today)) {
          activeDates.add(today);
        }

        newTodayTimeSpent = timeSpentSeconds; // Reset for the new day

        final currentYear = todayObj.year.toString();
        final lastActiveYear = userData['lastActiveYear'] as String?;
        int prevYearlyActiveDays = (userData['yearlyActiveDays'] ?? 0) as int;

        if (lastActiveYear != currentYear) {
          prevYearlyActiveDays = 0;
        }
        final newYearlyActiveDays = prevYearlyActiveDays + 1;

        overallStreakUpdate = {
          'scores': newScores,
          'todayTimeSpent': newTodayTimeSpent,
          'overallStreak': newOverallStreak,
          'overallLastDate': today,
          'overallLastEvaluatedDate': today,
          'freezesAvailable': freezesAvailable,
          'nextFreezeRechargeDate': newOverallNextFreezeRechargeDate,
          'activeDates': activeDates,
          'frozenDates': frozenDates,
          'yearlyActiveDays': newYearlyActiveDays,
          'lastActiveYear': currentYear,
        };
      }

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
      final friendUid = uids.firstWhere((id) => id != uid, orElse: () => '');
      if (friendUid.isEmpty) continue;

      final friendSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendUid)
          .get();
      if (!friendSnap.exists) continue;
      
      final friendData = friendSnap.data()!;
      final fEffective = getEffectiveStreakData(
        streak: (friendData['overallStreak'] ?? 0) as int,
        freezesAvailable: (friendData['freezesAvailable'] ?? 2) as int,
        frozenDates: List<String>.from(friendData['frozenDates'] ?? []),
        lastEvaluatedDate: friendData['overallLastEvaluatedDate'] as String?,
      );

      final sharedStreak = math.min(newOverallStreak, fEffective.streak);
      batch.update(pairDoc.reference, {'sharedStreak': sharedStreak});
    }

    await batch.commit();
  }

  // Check Routine Completion

  /// Checks if the user has completed their configured routine today.
  static Future<bool> checkRoutineCompletion(String uid) async {
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!userSnap.exists) return false;
    final userData = userSnap.data() ?? {};

    final rawSelected = userData['selectedExercises'];
    final neverConfigured = rawSelected == null;

    List<String> idsToShow;
    if (neverConfigured) {
      final defsSnap = await FirebaseFirestore.instance
          .collection('exercises')
          .get();
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

    final today = _todayKey();
    int completed = 0;
    for (final id in idsToShow) {
      if (userExData[id]?['lastCompletedDate'] == today) {
        completed++;
      }
    }

    return completed == idsToShow.length;
  }

  // Log Routine Completion

  /// Logs the completion of the full routine and updates the overall streak.
  static Future<Map<String, int>> logRoutineCompletion(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final today = _todayKey();

    final settingsSnap = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('settings')
        .get();
    final freezeRechargePeriod =
        (settingsSnap.data()?['freezeRechargePeriodDays'] ?? 15) as int;

    return await FirebaseFirestore.instance.runTransaction<Map<String, int>>((
      tx,
    ) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};

      final prevOverallStreak = (userData['overallStreak'] ?? 0) as int;
      final overallLastDate = userData['overallLastDate'] as String?;

      if (overallLastDate == today) {
        return {'overallStreak': prevOverallStreak};
      }

      final lastEvaluatedDate =
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

      final todayObj = DateTime.parse(today);

      int newOverallStreak;
      if (overallLastDate == null || prevOverallStreak == 0) {
        newOverallStreak = 1;
        freezesAvailable = 2;
        newOverallNextFreezeRechargeDate = null;
      } else {
        final fromDate = DateTime.parse(lastEvaluatedDate!);
        final result = _applyMissedDays(
          fromDate: fromDate,
          toDate: todayObj,
          frozenDates: frozenDates,
          freezeRechargePeriod: freezeRechargePeriod,
        );
        freezesAvailable = result.freezesAvailable;
        frozenDates = result.frozenDates;
        newOverallNextFreezeRechargeDate = result.nextFreezeRechargeDate;
        newOverallStreak = result.streakBroken ? 1 : prevOverallStreak + 1;
      }

      if (!activeDates.contains(today)) {
        activeDates.add(today);
      }

      tx.set(userRef, {
        'overallStreak': newOverallStreak,
        'overallLastDate': today,
        'overallLastEvaluatedDate': today,
        'freezesAvailable': freezesAvailable,
        'nextFreezeRechargeDate': newOverallNextFreezeRechargeDate,
        'activeDates': activeDates,
        'frozenDates': frozenDates,
      }, SetOptions(merge: true));

      return {'overallStreak': newOverallStreak};
    });
  }

  // Check & Update Streak (app-open)

  /// Runs on every app-open. Lazily evaluates any missed days since last check.
  /// Deducts freezes one-per-missed-day sequentially. Breaks streak only when
  /// a missed day has no freeze available. Wrapped in a transaction to prevent
  /// race conditions with logExercise.
  static Future<void> checkAndUpdateStreak(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      final settingsSnap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();
      final freezeRechargePeriod =
          (settingsSnap.data()?['freezeRechargePeriodDays'] ?? 15) as int;

      // PRE-TRANSACTION QUERY
      // Fetch references outside the transaction to prevent breaking the transaction's async lifecycle.
      final exercisesQuerySnap = await userRef.collection('exercises').get();
      final exerciseRefs = exercisesQuerySnap.docs
          .map((d) => d.reference)
          .toList();

      await FirebaseFirestore.instance.runTransaction<void>((tx) async {
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) return;

        final exerciseDocs = <DocumentSnapshot>[];
        for (final ref in exerciseRefs) {
          exerciseDocs.add(await tx.get(ref));
        }

        // LOGIC & WRITE PHASE
        final userData = userSnap.data() ?? {};
        final now = DateTime.now();
        final todayObj = DateTime(now.year, now.month, now.day);
        final yesterday = todayObj.subtract(const Duration(days: 1));

        final Map<String, dynamic> updates = {};

        // 1. Evaluate Overall Streak
        final overallLastDate = userData['overallLastDate'] as String?;
        final overallStreak = (userData['overallStreak'] ?? 0) as int;
        if (overallLastDate != null && overallStreak > 0) {
          final lastEvaluatedDate =
              (userData['overallLastEvaluatedDate'] as String?) ??
              overallLastDate;
          final fromDate = DateTime.parse(lastEvaluatedDate);

          if (fromDate.isBefore(yesterday)) {

            List<String> frozenDates = List<String>.from(
              userData['frozenDates'] ?? [],
            );

            final result = _applyMissedDays(
              fromDate: fromDate,
              toDate: todayObj,
              frozenDates: frozenDates,
              freezeRechargePeriod: freezeRechargePeriod,
            );

            updates['freezesAvailable'] = result.freezesAvailable;
            updates['frozenDates'] = result.frozenDates;
            updates['nextFreezeRechargeDate'] = result.nextFreezeRechargeDate;
            updates['overallLastEvaluatedDate'] = _dateKey(yesterday);

            if (result.streakBroken) {
              updates['overallStreak'] = 0;
            }
            // Note: Do NOT tx.set here! All tx.get must happen before any tx.set.
          }
        }

        // 2. Evaluate Individual Exercises
        for (final doc in exerciseDocs) {
          if (!doc.exists) continue;

          final exData = doc.data() as Map<String, dynamic>? ?? {};
          final lastCompletedDate = exData['lastCompletedDate'] as String?;
          final currentStreak = (exData['currentStreak'] ?? 0) as int;
          if (lastCompletedDate == null || currentStreak == 0) continue;

          final lastEvaluatedDate =
              (exData['lastEvaluatedDate'] as String?) ?? lastCompletedDate;
          final fromDate = DateTime.parse(lastEvaluatedDate);

          if (fromDate.isBefore(yesterday)) {

            List<String> exFrozenDates = List<String>.from(
              exData['frozenDates'] ?? [],
            );

            final result = _applyMissedDays(
              fromDate: fromDate,
              toDate: todayObj,
              frozenDates: exFrozenDates,
              freezeRechargePeriod: freezeRechargePeriod,
            );

            final Map<String, dynamic> exUpdates = {
              'freezesAvailable': result.freezesAvailable,
              'frozenDates': result.frozenDates,
              'nextFreezeRechargeDate': result.nextFreezeRechargeDate,
              'lastEvaluatedDate': _dateKey(yesterday),
            };

            if (result.streakBroken) {
              exUpdates['currentStreak'] = 0;
            }

            tx.set(doc.reference, exUpdates, SetOptions(merge: true));
          }
        }

        // Perform the userRef write at the very end (if updates exist)
        if (updates.isNotEmpty) {
          tx.set(userRef, updates, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('Error in checkAndUpdateStreak: $e');
    }
  }
}
