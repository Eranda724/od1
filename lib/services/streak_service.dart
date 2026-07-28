import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'leaderboard_service.dart';

class StreakService {
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayKey() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  /// Logs an exercise and returns a map of the updated stats.
  /// Completing any single exercise counts as a valid day for the overall streak.
  /// Throws an exception if the transaction fails.
  static Future<Map<String, int>> logExercise({
    required String uid,
    required String exerciseId,
    required String exerciseName,
    required int reps,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final exRef = userRef.collection('exercises').doc(exerciseId);

    final today = _todayKey();
    final yesterday = _yesterdayKey();

    return await FirebaseFirestore.instance.runTransaction<Map<String, int>>((tx) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};

      final exSnap = await tx.get(exRef);
      final exerciseData = exSnap.data() ?? {};

      // ── Exercise specific stats ──
      final prevLifetime = (exerciseData['lifetimeTotal'] ?? 0) as int;
      final prevStreak = (exerciseData['currentStreak'] ?? 0) as int;
      final lastDate = exerciseData['lastCompletedDate'] as String?;
      final prevTodayReps = (exerciseData['todayReps'] ?? 0) as int;

      int newStreak;
      int newTodayReps;

      if (lastDate == today) {
        newStreak = prevStreak;
        newTodayReps = prevTodayReps + reps;
      } else if (lastDate == yesterday) {
        newStreak = prevStreak + 1;
        newTodayReps = reps;
      } else {
        newStreak = 1;
        newTodayReps = reps;
      }

      final newLifetime = prevLifetime + reps;

      tx.set(exRef, {
        'lifetimeTotal': newLifetime,
        'currentStreak': newStreak,
        'lastCompletedDate': today,
        'todayReps': newTodayReps,
        'exerciseName': exerciseName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ── Leaderboard Scores ──
      final newScores = LeaderboardService.calculateNewScores(
        existing: Map<String, dynamic>.from(userData['scores'] as Map<String, dynamic>? ?? {}),
        points: reps,
        now: DateTime.now(),
      );

      // ── Overall Streak Logic ──
      // GUARD FIRST: if we already counted today, skip all streak calculation.
      final overallLastDate = userData['overallLastDate'] as String?;
      final prevOverallStreak = (userData['overallStreak'] ?? 0) as int;

      int newOverallStreak = prevOverallStreak;
      Map<String, dynamic> overallStreakUpdate = {'scores': newScores};

      if (overallLastDate != today) {
        // This is the first exercise completed today — count the day.
        int freezesAvailable = (userData['freezesAvailable'] ?? 0) as int;
        String? freezeLastRefillDate = userData['freezeLastRefillDate'] as String?;
        List<String> frozenDates = List<String>.from(userData['frozenDates'] ?? []);
        List<String> activeDates = List<String>.from(userData['activeDates'] ?? []);

        final todayObj = DateTime.parse(today);

        // Freeze refill: one freeze back every 7 days (max 2)
        if (freezeLastRefillDate == null) {
          freezeLastRefillDate = today;
        } else {
          final refillDateObj = DateTime.parse(freezeLastRefillDate);
          if (todayObj.difference(refillDateObj).inDays >= 7) {
            freezesAvailable = math.min(2, freezesAvailable + 1);
            freezeLastRefillDate = today;
          }
        }

        // Consecutive-day calculation
        if (overallLastDate == null) {
          newOverallStreak = 1;
        } else {
          final lastDateObj = DateTime.parse(overallLastDate);

          if (overallLastDate == yesterday) {
            // Perfect consecutive day
            newOverallStreak = prevOverallStreak + 1;
          } else {
            // Gap detected — how many days were missed?
            final daysMissed = todayObj.difference(lastDateObj).inDays - 1;

            if (daysMissed > 0 && freezesAvailable >= daysMissed) {
              // Enough freezes to cover the gap
              freezesAvailable -= daysMissed;
              newOverallStreak = prevOverallStreak + 1;

              // Record each frozen (missed) day
              for (int i = 1; i <= daysMissed; i++) {
                final missingDay = lastDateObj.add(Duration(days: i));
                final missingDayStr =
                    '${missingDay.year}-${missingDay.month.toString().padLeft(2, '0')}-${missingDay.day.toString().padLeft(2, '0')}';
                if (!frozenDates.contains(missingDayStr)) {
                  frozenDates.add(missingDayStr);
                }
              }
            } else {
              // Streak broken — not enough freezes
              newOverallStreak = 1;
            }
          }
        }

        // Record today as an active date
        if (!activeDates.contains(today)) {
          activeDates.add(today);
        }

        overallStreakUpdate = {
          'scores': newScores,
          'overallStreak': newOverallStreak,
          'overallLastDate': today,
          'freezesAvailable': freezesAvailable,
          'freezeLastRefillDate': freezeLastRefillDate,
          'activeDates': activeDates,
          'frozenDates': frozenDates,
        };
      }

      tx.set(userRef, overallStreakUpdate, SetOptions(merge: true));

      return {
        'lifetimeTotal': newLifetime,
        'currentStreak': newStreak,
        'todayReps': newTodayReps,
        'overallStreak': newOverallStreak,
      };
    });
  }

  /// Checks if the user has completed their configured routine today.
  static Future<bool> checkRoutineCompletion(String uid) async {
    final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!userSnap.exists) return false;
    final userData = userSnap.data() ?? {};

    final rawSelected = userData['selectedExercises'];
    final neverConfigured = rawSelected == null;

    List<String> idsToShow;
    if (neverConfigured) {
      final defsSnap = await FirebaseFirestore.instance.collection('exercises').get();
      idsToShow = defsSnap.docs.map((d) => d.id).toList();
    } else {
      idsToShow = List<String>.from(rawSelected);
    }

    if (idsToShow.isEmpty) return false;

    final userExSnap = await FirebaseFirestore.instance.collection('users').doc(uid).collection('exercises').get();
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

  /// Logs the completion of the full routine and updates the overall streak.
  static Future<Map<String, int>> logRoutineCompletion(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final today = _todayKey();
    final yesterday = _yesterdayKey();

    return await FirebaseFirestore.instance.runTransaction<Map<String, int>>((tx) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};
      
      final prevOverallStreak = (userData['overallStreak'] ?? 0) as int;
      final overallLastDate = userData['overallLastDate'] as String?;
      
      if (overallLastDate == today) {
        // Already logged today
        return {'overallStreak': prevOverallStreak};
      }

      int freezesAvailable = (userData['freezesAvailable'] ?? 0) as int;
      String? freezeLastRefillDate = userData['freezeLastRefillDate'] as String?;
      List<String> frozenDates = List<String>.from(userData['frozenDates'] ?? []);
      List<String> activeDates = List<String>.from(userData['activeDates'] ?? []);

      final todayObj = DateTime.parse(today);

      if (freezeLastRefillDate == null) {
        freezeLastRefillDate = today;
      } else {
        final refillDateObj = DateTime.parse(freezeLastRefillDate);
        if (todayObj.difference(refillDateObj).inDays >= 7) {
          freezesAvailable = math.min(2, freezesAvailable + 1);
          freezeLastRefillDate = today;
        }
      }

      int newOverallStreak;
      if (overallLastDate == null) {
        newOverallStreak = 1;
      } else {
        final lastDateObj = DateTime.parse(overallLastDate);
        
        // Month change resets streak to 1
        if (todayObj.month != lastDateObj.month || todayObj.year != lastDateObj.year) {
          newOverallStreak = 1;
        } else if (overallLastDate == yesterday) {
          newOverallStreak = prevOverallStreak + 1;
        } else {
          final daysMissed = todayObj.difference(lastDateObj).inDays - 1;
          
          if (daysMissed > 0 && freezesAvailable >= daysMissed) {
            freezesAvailable -= daysMissed;
            newOverallStreak = prevOverallStreak + 1;
            
            for (int i = 1; i <= daysMissed; i++) {
              final missingDay = lastDateObj.add(Duration(days: i));
              final missingDayStr = '${missingDay.year}-${missingDay.month.toString().padLeft(2, '0')}-${missingDay.day.toString().padLeft(2, '0')}';
              if (!frozenDates.contains(missingDayStr)) {
                frozenDates.add(missingDayStr);
              }
            }
          } else {
            newOverallStreak = 1;
          }
        }
      }

      if (!activeDates.contains(today)) {
        activeDates.add(today);
      }

      tx.set(userRef, {
        'overallStreak': newOverallStreak,
        'overallLastDate': today,
        'freezesAvailable': freezesAvailable,
        'freezeLastRefillDate': freezeLastRefillDate,
        'activeDates': activeDates,
        'frozenDates': frozenDates,
      }, SetOptions(merge: true));

      return {'overallStreak': newOverallStreak};
    });
  }

  /// Checks if the streak is broken and updates the database if necessary.
  static Future<void> checkAndUpdateStreak(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;

    final userData = userSnap.data() ?? {};
    final overallStreak = (userData['overallStreak'] ?? 0) as int;
    if (overallStreak <= 0) return;

    final overallLastDate = userData['overallLastDate'] as String?;
    if (overallLastDate == null) return;

    final freezesAvailable = (userData['freezesAvailable'] ?? 0) as int;
    final today = _todayKey();
    final todayObj = DateTime.parse(today);
    final lastDateObj = DateTime.parse(overallLastDate);

    // If it's a new month, reset the streak
    if (todayObj.month != lastDateObj.month || todayObj.year != lastDateObj.year) {
      await userRef.set({
        'overallStreak': 0, // Reset for new month
      }, SetOptions(merge: true));
      return;
    }

    final daysMissed = todayObj.difference(lastDateObj).inDays - 1;

    // If we missed 1 or more days (yesterday was missed) and we don't have enough freezes
    if (daysMissed > 0 && freezesAvailable < daysMissed) {
      await userRef.set({
        'overallStreak': 0, // Broken streak
      }, SetOptions(merge: true));
    }
  }
}
