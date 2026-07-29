import 'package:cloud_firestore/cloud_firestore.dart';
import 'leaderboard_service.dart';

class StreakService {
  // ─── Date helpers ───────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _todayKey() => _dateKey(DateTime.now());

  static String _yesterdayKey() =>
      _dateKey(DateTime.now().subtract(const Duration(days: 1)));

  // ─── Core freeze helper ─────────────────────────────────────────────────────

  /// Evaluates missed days between [fromDate] (exclusive) and [toDate] (exclusive).
  /// For each missed day: deducts 1 freeze if available, otherwise marks streak broken.
  static ({int freezesAvailable, List<String> frozenDates, bool streakBroken})
      _applyMissedDays({
    required DateTime fromDate,
    required DateTime toDate,
    required int freezesAvailable,
    required List<String> frozenDates,
  }) {
    bool streakBroken = false;
    final missedDayCount = toDate.difference(fromDate).inDays - 1;

    for (int i = 1; i <= missedDayCount; i++) {
      final missedDay = fromDate.add(Duration(days: i));
      final missedKey = _dateKey(missedDay);

      if (freezesAvailable > 0) {
        freezesAvailable -= 1;
        if (!frozenDates.contains(missedKey)) {
          frozenDates.add(missedKey);
        }
      } else {
        streakBroken = true;
        break;
      }
    }

    return (
      freezesAvailable: freezesAvailable,
      frozenDates: frozenDates,
      streakBroken: streakBroken,
    );
  }

  // ─── Log Exercise ────────────────────────────────────────────────────────────

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

    return await FirebaseFirestore.instance.runTransaction<Map<String, int>>((tx) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};

      final exSnap = await tx.get(exRef);
      final exerciseData = exSnap.data() ?? {};

      // ── Exercise-specific stats ──
      final prevLifetime = (exerciseData['lifetimeTotal'] ?? 0) as int;
      final prevStreak = (exerciseData['currentStreak'] ?? 0) as int;
      final lastDate = exerciseData['lastCompletedDate'] as String?;
      final prevTodayReps = (exerciseData['todayReps'] ?? 0) as int;
      final yesterday = _yesterdayKey();

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
        existing: Map<String, dynamic>.from(
          userData['scores'] as Map<String, dynamic>? ?? {},
        ),
        points: reps,
        now: DateTime.now(),
      );

      // ── Overall Streak Logic ──
      final overallLastDate = userData['overallLastDate'] as String?;
      final prevOverallStreak = (userData['overallStreak'] ?? 0) as int;

      int newOverallStreak = prevOverallStreak;
      // Default: same-day exercise — only update scores, no streak/freeze changes
      Map<String, dynamic> overallStreakUpdate = {'scores': newScores};

      if (overallLastDate != today) {
        // First exercise today — process any missed days since last evaluation
        final lastEvaluatedDate =
            (userData['overallLastEvaluatedDate'] as String?) ?? overallLastDate;

        int freezesAvailable = (userData['freezesAvailable'] ?? 2) as int;
        List<String> frozenDates = List<String>.from(userData['frozenDates'] ?? []);
        List<String> activeDates = List<String>.from(userData['activeDates'] ?? []);

        final todayObj = DateTime.parse(today);

        if (overallLastDate == null) {
          // First ever exercise
          newOverallStreak = 1;
        } else {
          // Sequential freeze evaluation — unified path, no special cases
          final fromDate = DateTime.parse(lastEvaluatedDate!);
          final result = _applyMissedDays(
            fromDate: fromDate,
            toDate: todayObj,
            freezesAvailable: freezesAvailable,
            frozenDates: frozenDates,
          );
          freezesAvailable = result.freezesAvailable;
          frozenDates = result.frozenDates;
          newOverallStreak = result.streakBroken ? 1 : prevOverallStreak + 1;
        }

        if (!activeDates.contains(today)) {
          activeDates.add(today);
        }

        overallStreakUpdate = {
          'scores': newScores,
          'overallStreak': newOverallStreak,
          'overallLastDate': today,
          'overallLastEvaluatedDate': today,
          'freezesAvailable': 2,
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

  // ─── Check Routine Completion ────────────────────────────────────────────────

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

    final today = _todayKey();
    int completed = 0;
    for (final id in idsToShow) {
      if (userExData[id]?['lastCompletedDate'] == today) {
        completed++;
      }
    }

    return completed == idsToShow.length;
  }

  // ─── Log Routine Completion ──────────────────────────────────────────────────

  /// Logs the completion of the full routine and updates the overall streak.
  static Future<Map<String, int>> logRoutineCompletion(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final today = _todayKey();

    return await FirebaseFirestore.instance.runTransaction<Map<String, int>>((tx) async {
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
      List<String> frozenDates = List<String>.from(userData['frozenDates'] ?? []);
      List<String> activeDates = List<String>.from(userData['activeDates'] ?? []);

      final todayObj = DateTime.parse(today);

      int newOverallStreak;
      if (overallLastDate == null) {
        newOverallStreak = 1;
      } else {
        final fromDate = DateTime.parse(lastEvaluatedDate!);
        final result = _applyMissedDays(
          fromDate: fromDate,
          toDate: todayObj,
          freezesAvailable: freezesAvailable,
          frozenDates: frozenDates,
        );
        freezesAvailable = result.freezesAvailable;
        frozenDates = result.frozenDates;
        newOverallStreak = result.streakBroken ? 1 : prevOverallStreak + 1;
      }

      if (!activeDates.contains(today)) {
        activeDates.add(today);
      }

      tx.set(userRef, {
        'overallStreak': newOverallStreak,
        'overallLastDate': today,
        'overallLastEvaluatedDate': today,
        'freezesAvailable': 2,
        'activeDates': activeDates,
        'frozenDates': frozenDates,
      }, SetOptions(merge: true));

      return {'overallStreak': newOverallStreak};
    });
  }

  // ─── Check & Update Streak (app-open) ───────────────────────────────────────

  /// Runs on every app-open. Lazily evaluates any missed days since last check.
  /// Deducts freezes one-per-missed-day sequentially. Breaks streak only when
  /// a missed day has no freeze available. Wrapped in a transaction to prevent
  /// race conditions with logExercise.
  static Future<void> checkAndUpdateStreak(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    await FirebaseFirestore.instance.runTransaction<void>((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) return;

      final userData = userSnap.data() ?? {};
      final overallLastDate = userData['overallLastDate'] as String?;

      if (overallLastDate == null) return;

      final lastEvaluatedDate =
          (userData['overallLastEvaluatedDate'] as String?) ?? overallLastDate;

      final now = DateTime.now();
      final todayObj = DateTime(now.year, now.month, now.day);
      final fromDate = DateTime.parse(lastEvaluatedDate);

      if (!fromDate.isBefore(todayObj.subtract(const Duration(days: 1)))) return;

      int freezesAvailable = (userData['freezesAvailable'] ?? 2) as int;
      List<String> frozenDates = List<String>.from(userData['frozenDates'] ?? []);

      final result = _applyMissedDays(
        fromDate: fromDate,
        toDate: todayObj,
        freezesAvailable: freezesAvailable,
        frozenDates: frozenDates,
      );

      final yesterday = todayObj.subtract(const Duration(days: 1));
      final Map<String, dynamic> updates = {
        'freezesAvailable': result.freezesAvailable,
        'frozenDates': result.frozenDates,
        'overallLastEvaluatedDate': _dateKey(yesterday),
      };

      if (result.streakBroken) {
        updates['overallStreak'] = 0;
      }

      tx.set(userRef, updates, SetOptions(merge: true));
    });
  }
}
