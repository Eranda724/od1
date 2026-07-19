import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

/// Represents one leaderboard entry.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String avatar;
  final String? photoUrl;

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
    this.photoUrl,
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
        return 'daily_period'.tr();
      case LeaderboardPeriod.weekly:
        return 'weekly_period'.tr();
      case LeaderboardPeriod.monthly:
        return 'monthly_period'.tr();
    }
  }
}

class LeaderboardService {
  static final _db = FirebaseFirestore.instance;

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
        // Name resolution priority: displayName → username → email prefix → 'User'
        final name = _resolveName(data);
        entries.add(LeaderboardEntry(
          uid: doc.id,
          displayName: name,
          avatar: _avatarFor(rank),
          score: score,
          dailyScore: daily,
          weeklyScore: weekly,
          monthlyScore: monthly,
          photoUrl: data['photoUrl'] as String?,
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

  /// Resolves the best available display name for a user document.
  /// Priority: displayName → username → email prefix → 'User'
  static String _resolveName(Map<String, dynamic> data) {
    final displayName = (data['displayName'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final username = (data['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;

    final email = data['email'] as String?;
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'User';
  }

  // ── Score update helpers (call these when an exercise is completed) ──────────

  /// Pure function to calculate new scores based on previous scores and points added.
  static Map<String, dynamic> calculateNewScores({
    required Map<String, dynamic> existing,
    required int points,
    required DateTime now,
  }) {
    final lastUpdated = (existing['lastUpdated'] as Timestamp?)?.toDate();
    final newScores = Map<String, dynamic>.from(existing);

    newScores['daily'] = _resetIfStale(
          existing['daily'],
          lastUpdated,
          _isSameDay,
          now,
        ) +
        points;
    newScores['weekly'] = _resetIfStale(
          existing['weekly'],
          lastUpdated,
          _isSameWeek,
          now,
        ) +
        points;
    newScores['monthly'] = _resetIfStale(
          existing['monthly'],
          lastUpdated,
          _isSameMonth,
          now,
        ) +
        points;
    newScores['lastUpdated'] = Timestamp.fromDate(now);

    return newScores;
  }

  static int _resetIfStale(
    dynamic current,
    DateTime? lastUpdated,
    bool Function(DateTime, DateTime) isSamePeriod,
    DateTime now,
  ) {
    if (current == null || lastUpdated == null) return 0;
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
