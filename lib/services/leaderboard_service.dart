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
    final now = DateTime.now();
    switch (this) {
      case LeaderboardPeriod.daily:
        return 'scores.daily_scores.${LeaderboardService.localDailyKey(now)}';
      case LeaderboardPeriod.weekly:
        return 'scores.weekly_scores.${LeaderboardService.localWeekKey(now)}';
      case LeaderboardPeriod.monthly:
        return 'scores.monthly_scores.${LeaderboardService.localMonthKey(now)}';
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

  // Local Date Key Helpers

  static String localDailyKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String localMonthKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static String localWeekKey(DateTime d) {
    // Shift to Thursday of the same week to determine the ISO week year.
    // weekday is 1 for Monday, 7 for Sunday. Thursday is 4.
    final thursday = d.add(Duration(days: 4 - d.weekday));
    // The ISO week year is the year of this Thursday.
    final isoYear = thursday.year;
    // Week number is calculated by days from the Thursday in the first week of the year.
    // The first week of the year is the week containing Jan 4th.
    final jan4 = DateTime(isoYear, 1, 4);
    final jan4Thursday = jan4.add(Duration(days: 4 - jan4.weekday));
    final weekNumber = 1 + (thursday.difference(jan4Thursday).inDays / 7).round();
    
    return '${isoYear}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  // Avatars based on score rank
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
        .snapshots()
        .map((snap) {
      final allEntries = <LeaderboardEntry>[];
      
      final now = DateTime.now();
      final dKey = localDailyKey(now);
      final wKey = localWeekKey(now);
      final mKey = localMonthKey(now);

      for (final doc in snap.docs) {
        final data = doc.data();
        final scores = data['scores'] as Map<String, dynamic>? ?? {};
        
        final dMap = scores['daily_scores'] as Map<String, dynamic>? ?? {};
        final wMap = scores['weekly_scores'] as Map<String, dynamic>? ?? {};
        final mMap = scores['monthly_scores'] as Map<String, dynamic>? ?? {};
        
        final daily = (dMap[dKey] as num?)?.toInt() ?? 0;
        final weekly = (wMap[wKey] as num?)?.toInt() ?? 0;
        final monthly = (mMap[mKey] as num?)?.toInt() ?? 0;

        final score = _scoreForPeriod(period, daily, weekly, monthly);
        // We only show users with a score > 0 on the leaderboard.
        if (score == 0) continue; 
        
        // Name resolution priority: displayName → username → email prefix → 'User'
        final name = _resolveName(data);
        allEntries.add(LeaderboardEntry(
          uid: doc.id,
          displayName: name,
          avatar: '', // We'll assign this after sorting
          score: score,
          dailyScore: daily,
          weeklyScore: weekly,
          monthlyScore: monthly,
          photoUrl: data['photoUrl'] as String?,
        ));
      }

      // Sort descending by score
      allEntries.sort((a, b) => b.score.compareTo(a.score));

      // Limit to top 50
      final topEntries = allEntries.take(50).toList();

      // Assign ranks and avatars
      final rankedEntries = <LeaderboardEntry>[];
      for (int i = 0; i < topEntries.length; i++) {
        final entry = topEntries[i];
        final rank = i + 1;
        rankedEntries.add(LeaderboardEntry(
          uid: entry.uid,
          displayName: entry.displayName,
          avatar: _avatarFor(rank),
          score: entry.score,
          dailyScore: entry.dailyScore,
          weeklyScore: entry.weeklyScore,
          monthlyScore: entry.monthlyScore,
          photoUrl: entry.photoUrl,
        ));
      }

      return rankedEntries;
    });
  }

  static int _scoreForPeriod(LeaderboardPeriod period, int daily, int weekly, int monthly) {
    switch (period) {
      case LeaderboardPeriod.daily:
        return daily;
      case LeaderboardPeriod.weekly:
        return weekly;
      case LeaderboardPeriod.monthly:
        return monthly;
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

  // Score update helpers (call these when an exercise is completed)

  /// Pure function to calculate new scores based on previous scores and points added.
  static Map<String, dynamic> calculateNewScores({
    required Map<String, dynamic> existing,
    required int points,
    required DateTime now,
  }) {
    final newScores = Map<String, dynamic>.from(existing);
    
    final dKey = localDailyKey(now);
    final wKey = localWeekKey(now);
    final mKey = localMonthKey(now);

    final dMap = Map<String, dynamic>.from(newScores['daily_scores'] as Map? ?? {});
    final wMap = Map<String, dynamic>.from(newScores['weekly_scores'] as Map? ?? {});
    final mMap = Map<String, dynamic>.from(newScores['monthly_scores'] as Map? ?? {});

    dMap[dKey] = ((dMap[dKey] as num?)?.toInt() ?? 0) + points;
    wMap[wKey] = ((wMap[wKey] as num?)?.toInt() ?? 0) + points;
    mMap[mKey] = ((mMap[mKey] as num?)?.toInt() ?? 0) + points;

    newScores['daily_scores'] = dMap;
    newScores['weekly_scores'] = wMap;
    newScores['monthly_scores'] = mMap;
    
    // Maintain lifetime overall score
    newScores['lifetime'] = (existing['lifetime'] as num? ?? 0).toInt() + points;
    newScores['lastUpdated'] = Timestamp.fromDate(now);

    return newScores;
  }
}
