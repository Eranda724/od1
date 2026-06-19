import 'package:flutter/material.dart';

// ── Mock leaderboard data ─────────────────────────────────────────────────────
const mockLeaderboard = [
  {'name': 'CoachPotato', 'avatar': '🥇', 'streak': 143, 'uid': 'mock_1'},
  {'name': 'IronCouch', 'avatar': '🥈', 'streak': 98, 'uid': 'mock_2'},
  {'name': 'SquatKing', 'avatar': '🥉', 'streak': 87, 'uid': 'mock_3'},
  {'name': 'PushUpQueen', 'avatar': '💪', 'streak': 72, 'uid': 'mock_4'},
  {'name': 'LazyStar', 'avatar': '⭐', 'streak': 61, 'uid': 'mock_5'},
  {'name': 'SofaSurfer', 'avatar': '🏄', 'streak': 55, 'uid': 'mock_6'},
  {'name': 'GrumpyRep', 'avatar': '😤', 'streak': 44, 'uid': 'mock_7'},
  {'name': 'TinyGains', 'avatar': '🌱', 'streak': 33, 'uid': 'mock_8'},
  {'name': 'OneMoreRep', 'avatar': '🔥', 'streak': 21, 'uid': 'mock_9'},
  {'name': 'JustStarted', 'avatar': '🐣', 'streak': 7, 'uid': 'mock_10'},
];

class LeaderboardScreen extends StatelessWidget {
  final String? currentUid;
  const LeaderboardScreen({super.key, this.currentUid});

  @override
  Widget build(BuildContext context) {
    final sorted = [...mockLeaderboard]
      ..sort((a, b) => (b['streak'] as int).compareTo(a['streak'] as int));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      itemCount: sorted.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context, sorted);
        }
        final entry = sorted[index - 1];
        final rank = index; // 1-based
        final isCurrentUser = entry['uid'] == currentUid;
        return _buildLeaderboardRow(context, rank, entry, isCurrentUser);
      },
    );
  }

  // ── Top 3 podium ─────────────────────────────────────────────────────────────
  Widget _buildHeader(
      BuildContext context, List<Map<String, Object>> sorted) {
    return Column(
      children: [
        const Text(
          '🏆 Top Streakers',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          "Who's been most consistent?",
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _podiumItem(context, 2, sorted[1], 80, const Color(0xFFB0BEC5)),
            const SizedBox(width: 12),
            _podiumItem(context, 1, sorted[0], 100, const Color(0xFFFFC72C)),
            const SizedBox(width: 12),
            _podiumItem(context, 3, sorted[2], 70, const Color(0xFFCD7F32)),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _podiumItem(BuildContext context, int rank, Map<String, Object> entry,
      double height, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entry['avatar'] as String, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text(
          entry['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        Text(
          '${entry['streak']}🔥',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(height: 4),
        Container(
          width: 72,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: Colors.black, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black),
          ),
        ),
      ],
    );
  }

  // ── Ranked list row ───────────────────────────────────────────────────────────
  Widget _buildLeaderboardRow(BuildContext context, int rank,
      Map<String, Object> entry, bool isCurrentUser) {
    final streak = entry['streak'] as int;
    final color = rank == 1
        ? const Color(0xFFFFC72C)
        : rank == 2
            ? const Color(0xFFB0BEC5)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFFFFC72C)
              : Theme.of(context).dividerColor,
          width: isCurrentUser ? 2.5 : 1.5,
        ),
        color: isCurrentUser
            ? const Color(0xFFFFC72C).withOpacity(0.08)
            : Theme.of(context).cardColor,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: (color ?? Theme.of(context).colorScheme.primary)
              .withOpacity(0.2),
          child: Text(
            entry['avatar'] as String,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Text(
              entry['name'] as String,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isCurrentUser ? const Color(0xFFB8860B) : null,
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC72C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '$streak day streak 🔥',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Text(
          '#$rank',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
