import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  final String? currentUid;
  const LeaderboardScreen({super.key, this.currentUid});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // We load ALL periods so the podium can show the right score when switching tabs
  // without waiting for a new stream each time.
  LeaderboardPeriod _activePeriod = LeaderboardPeriod.daily;

  static const _periods = LeaderboardPeriod.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) return;
        setState(() {
          _activePeriod = _periods[_tabController.index];
        });
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<LeaderboardEntry>>(
      // Stream sorted by the active period — gives us top-3 + ranked list
      stream: LeaderboardService.stream(_activePeriod),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting && entries.isEmpty;

        return Column(
          children: [
            // ── Fixed podium (always visible) ──────────────────────────────
            _PodiumSection(
              period: _activePeriod,
              entries: entries,
              isLoading: isLoading,
            ),

            // ── Period tab bar ──────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFFFC72C),
                  borderRadius: BorderRadius.circular(11),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                unselectedLabelColor:
                    cs.onSurface.withValues(alpha: 0.6),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                padding: const EdgeInsets.all(4),
                tabs: _periods
                    .map((p) => Tab(text: p.label, height: 36))
                    .toList(),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // ── Ranked list (scrollable) ────────────────────────────────────
            Expanded(
              child: _buildList(context, entries, isLoading, snapshot.hasError),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(BuildContext context, List<LeaderboardEntry> entries,
      bool isLoading, bool hasError) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFC72C)));
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Could not load leaderboard',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (entries.isEmpty) {
      return _EmptyState(period: _activePeriod);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final rank = index + 1;
        final isMe = entry.uid == widget.currentUid;
        return _LeaderboardRow(
          rank: rank,
          entry: entry,
          isCurrentUser: isMe,
          period: _activePeriod,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Always-visible podium section (top 3 bars)
// ─────────────────────────────────────────────────────────────────────────────
class _PodiumSection extends StatelessWidget {
  final LeaderboardPeriod period;
  final List<LeaderboardEntry> entries;
  final bool isLoading;

  const _PodiumSection({
    required this.period,
    required this.entries,
    required this.isLoading,
  });

  String get _emoji {
    switch (period) {
      case LeaderboardPeriod.daily:
        return '';
      case LeaderboardPeriod.weekly:
        return '';
      case LeaderboardPeriod.monthly:
        return '';
    }
  }

  String get _subtitle {
    switch (period) {
      case LeaderboardPeriod.daily:
        return "Today's top performers";
      case LeaderboardPeriod.weekly:
        return "This week's top performers";
      case LeaderboardPeriod.monthly:
        return "This month's legends";
    }
  }

  @override
  Widget build(BuildContext context) {
    final has3 = entries.length >= 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // Title
          Text(
            '$_emoji ${period.label} Leaderboard',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),

          // Podium bars — always rendered, placeholders if loading/empty
          if (isLoading)
            const SizedBox(
              height: 140,
              child: Center(
                child:
                    CircularProgressIndicator(color: Color(0xFFFFC72C)),
              ),
            )
          else if (!has3)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  '🏆 Be the first to top the podium!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _PodiumBar(
                  rank: 2,
                  entry: entries[1],
                  barHeight: 80,
                  color: const Color(0xFFB0BEC5),
                  period: period,
                ),
                const SizedBox(width: 12),
                _PodiumBar(
                  rank: 1,
                  entry: entries[0],
                  barHeight: 100,
                  color: const Color(0xFFFFC72C),
                  period: period,
                ),
                const SizedBox(width: 12),
                _PodiumBar(
                  rank: 3,
                  entry: entries[2],
                  barHeight: 70,
                  color: const Color(0xFFCD7F32),
                  period: period,
                ),
              ],
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual podium bar
// ─────────────────────────────────────────────────────────────────────────────
class _PodiumBar extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final double barHeight;
  final Color color;
  final LeaderboardPeriod period;

  const _PodiumBar({
    required this.rank,
    required this.entry,
    required this.barHeight,
    required this.color,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    // Show the score for whichever period is active
    final score = entry.scoreFor(period);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar emoji
        Text(entry.avatar, style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 2),
        // Name
        SizedBox(
          width: 80,
          child: Text(
            entry.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Score label
        Text(
          '$score pts',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        // Bar
        Container(
          width: 72,
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: Colors.black, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single ranked row
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final LeaderboardPeriod period;

  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
    required this.period,
  });

  Color? get _rankColor {
    if (rank == 1) return const Color(0xFFFFC72C);
    if (rank == 2) return const Color(0xFFB0BEC5);
    if (rank == 3) return const Color(0xFFCD7F32);
    return null;
  }

  String get _scoreLabel {
    final score = entry.scoreFor(period);
    switch (period) {
      case LeaderboardPeriod.daily:
        return '$score pts today';
      case LeaderboardPeriod.weekly:
        return '$score pts this week';
      case LeaderboardPeriod.monthly:
        return '$score pts this month';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _rankColor;

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
            ? const Color(0xFFFFC72C).withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor:
              (color ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.2),
          child: Text(
            entry.avatar,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                entry.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isCurrentUser ? const Color(0xFFB8860B) : null,
                ),
                overflow: TextOverflow.ellipsis,
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
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          _scoreLabel,
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

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final LeaderboardPeriod period;
  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏋️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No scores yet!',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete exercises to appear\non the ${period.label.toLowerCase()} leaderboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
