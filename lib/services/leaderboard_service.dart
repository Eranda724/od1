import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Represents one leaderboard entry.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String avatar;

  /// Score for the period this entry was fetched for (primary sort key).
  final int score;

  /// All-period scores — always populated so the podium can switch labels
  /// when the user changes tabs without re-fetching.
  final int dailyScore;
  final int weeklyScore;
  final int monthlyScore;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.score,
    required this.dailyScore,
    required this.weeklyScore,
    required this.monthlyScore,
  });

  /// Returns the score for the requested period.
  int scoreFor(LeaderboardPeriod period) {
    switch (period) {
      case LeaderboardPeriod.daily:
        return dailyScore;
      case LeaderboardPeriod.weekly:
        return weeklyScore;
      case LeaderboardPeriod.monthly:
        return monthlyScore;
    }
  }
}

/// Leaderboard period
enum LeaderboardPeriod { daily, weekly, monthly }

extension LeaderboardPeriodExt on LeaderboardPeriod {
  String get scoreField {
    switch (this) {
      case LeaderboardPeriod.daily:
        return 'scores.daily';
      case LeaderboardPeriod.weekly:
        return 'scores.weekly';
      case LeaderboardPeriod.monthly:
        return 'scores.monthly';
    }
  }

  String get label {
    switch (this) {
      case LeaderboardPeriod.daily:
        return 'Daily';
      case LeaderboardPeriod.weekly:
        return 'Weekly';
      case LeaderboardPeriod.monthly:
        return 'Monthly';
    }
  }
}

class LeaderboardService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Avatars based on score rank ──────────────────────────────────────────────
  static String _avatarFor(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '💪';
    }
  }

  /// Returns a stream of the top 50 users sorted by the given period's score.
  static Stream<List<LeaderboardEntry>> stream(LeaderboardPeriod period) {
    return _db
        .collection('users')
        .orderBy(period.scoreField, descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      final entries = <LeaderboardEntry>[];
      int rank = 0;
      for (final doc in snap.docs) {
        rank++;
        final data = doc.data();
        final scores = data['scores'] as Map<String, dynamic>? ?? {};
        final daily = (scores['daily'] as num?)?.toInt() ?? 0;
        final weekly = (scores['weekly'] as num?)?.toInt() ?? 0;
        final monthly = (scores['monthly'] as num?)?.toInt() ?? 0;
        final score = _scoreForPeriod(scores, period);
        if (score == 0 && rank > 3) continue; // hide zero scorers below podium
        final name = (data['displayName'] as String?)?.trim().isNotEmpty == true
            ? data['displayName'] as String
            : (data['email'] as String?)?.split('@').first ?? 'User';
        entries.add(LeaderboardEntry(
          uid: doc.id,
          displayName: name,
          avatar: _avatarFor(rank),
          score: score,
          dailyScore: daily,
          weeklyScore: weekly,
          monthlyScore: monthly,
        ));
      }
      return entries;
    });
  }

  static int _scoreForPeriod(
      Map<String, dynamic> scores, LeaderboardPeriod period) {
    switch (period) {
      case LeaderboardPeriod.daily:
        return (scores['daily'] as num?)?.toInt() ?? 0;
      case LeaderboardPeriod.weekly:
        return (scores['weekly'] as num?)?.toInt() ?? 0;
      case LeaderboardPeriod.monthly:
        return (scores['monthly'] as num?)?.toInt() ?? 0;
    }
  }

  // ── Score update helpers (call these when an exercise is completed) ──────────

  /// Adds [points] to the current user's daily, weekly, and monthly scores.
  /// Call this from ExerciseScreen after a workout is completed.
  static Future<void> addScore(int points) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};
      final existing = Map<String, dynamic>.from(
          (data['scores'] as Map<String, dynamic>?) ?? {});

      // Reset stale periods
      final lastUpdated = (existing['lastUpdated'] as Timestamp?)?.toDate();
      existing['daily'] = _resetIfStale(
            existing['daily'],
            lastUpdated,
            _isSameDay,
          ) +
          points;
      existing['weekly'] = _resetIfStale(
            existing['weekly'],
            lastUpdated,
            _isSameWeek,
          ) +
          points;
      existing['monthly'] = _resetIfStale(
            existing['monthly'],
            lastUpdated,
            _isSameMonth,
          ) +
          points;
      existing['lastUpdated'] = Timestamp.fromDate(now);

      tx.set(userRef, {'scores': existing}, SetOptions(merge: true));
    });
  }

  static int _resetIfStale(
    dynamic current,
    DateTime? lastUpdated,
    bool Function(DateTime, DateTime) isSamePeriod,
  ) {
    if (current == null || lastUpdated == null) return 0;
    final now = DateTime.now();
    return isSamePeriod(lastUpdated, now) ? (current as num).toInt() : 0;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isSameWeek(DateTime a, DateTime b) {
    final aMonday = a.subtract(Duration(days: a.weekday - 1));
    final bMonday = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(aMonday, bMonday);
  }

  static bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}
