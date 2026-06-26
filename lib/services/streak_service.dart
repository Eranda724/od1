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

      // ── Overall streak & Freeze Logic ──
      final prevOverallStreak = (userData['overallStreak'] ?? 0) as int;
      final overallLastDate = userData['overallLastDate'] as String?;
      int freezesAvailable = (userData['freezesAvailable'] ?? 0) as int;
      String? freezeLastRefillDate = userData['freezeLastRefillDate'] as String?;

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
      } else if (overallLastDate == today) {
        newOverallStreak = prevOverallStreak;
      } else if (overallLastDate == yesterday) {
        newOverallStreak = prevOverallStreak + 1;
      } else {
        final lastDateObj = DateTime.parse(overallLastDate);
        final daysMissed = todayObj.difference(lastDateObj).inDays - 1;
        
        if (daysMissed > 0 && freezesAvailable >= daysMissed) {
          freezesAvailable -= daysMissed;
          newOverallStreak = prevOverallStreak + 1;
        } else {
          newOverallStreak = 1;
        }
      }

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

      tx.set(userRef, {
        'overallStreak': newOverallStreak,
        'overallLastDate': today,
        'freezesAvailable': freezesAvailable,
        'freezeLastRefillDate': freezeLastRefillDate,
        'scores': newScores,
      }, SetOptions(merge: true));

      return {
        'lifetimeTotal': newLifetime,
        'currentStreak': newStreak,
        'todayReps': newTodayReps,
        'overallStreak': newOverallStreak,
      };
    });
  }
}
