import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LeaderboardScreen extends StatefulWidget {
  final String? currentUid;

  const LeaderboardScreen({super.key, this.currentUid});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  LeaderboardPeriod _activePeriod = LeaderboardPeriod.daily;

  // IMPORTANT:
  // Global is intentionally NOT included here.
  // Only Daily, Weekly and Monthly are displayed.
  static const List<LeaderboardPeriod> _periods = [
    LeaderboardPeriod.daily,
    LeaderboardPeriod.weekly,
    LeaderboardPeriod.monthly,
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _periods.length, vsync: this);

    _tabController.addListener(() {
      // Only update when the tab has fully settled (not mid-animation).
      // This prevents the stream from resetting prematurely during swipe.
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activePeriod = _periods[_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<LeaderboardEntry>>(
      stream: LeaderboardService.stream(_activePeriod),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];

        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            entries.isEmpty;

        return Column(
          children: [
            // ─────────────────────────────────────────────────────────────
            // HEADER + PODIUM
            // ─────────────────────────────────────────────────────────────
            _PodiumSection(
              period: _activePeriod,
              entries: entries,
              isLoading: isLoading,
            ),

            const SizedBox(height: 12),

            // ─────────────────────────────────────────────────────────────
            // DAILY / WEEKLY / MONTHLY TABS
            // ─────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1EBDD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TabBar(
                  controller: _tabController,

                  // No divider
                  dividerColor: Colors.transparent,

                  // Full width indicator
                  indicatorSize: TabBarIndicatorSize.tab,

                  // Modern pill indicator
                  indicator: BoxDecoration(
                    color: const Color(0xFFFFC72C),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC72C).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),

                  labelColor: Colors.black,
                  unselectedLabelColor: cs.onSurface.withValues(alpha: 0.55),

                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),

                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),

                  tabs: _periods
                      .map((period) => Tab(text: period.label))
                      .toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─────────────────────────────────────────────────────────────
            // DIVIDER
            // ─────────────────────────────────────────────────────────────
            Container(height: 1, color: cs.onSurface.withValues(alpha: 0.07)),

            // ─────────────────────────────────────────────────────────────
            // RANKED LIST
            // ─────────────────────────────────────────────────────────────
            Expanded(
              child: _buildList(context, entries, isLoading, snapshot.hasError, snapshot.error),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<LeaderboardEntry> entries,
    bool isLoading,
    bool hasError,
    Object? error,
  ) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFC72C),
          strokeWidth: 3,
        ),
      );
    }

    if (hasError) {
      print('Leaderboard Stream Error: $error');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 30,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'could_not_load_leaderboard'.tr(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (entries.isEmpty) {
      return _EmptyState(period: _activePeriod);
    }

    // Top 3 are displayed in the podium.
    // The normal list starts at rank 4.
    final listEntries = entries.length > 3
        ? entries.sublist(3)
        : <LeaderboardEntry>[];

    if (listEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: listEntries.length,
      itemBuilder: (context, index) {
        final entry = listEntries[index];
        final rank = index + 4;
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

// ═══════════════════════════════════════════════════════════════════════════
// PODIUM SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _PodiumSection extends StatelessWidget {
  final LeaderboardPeriod period;
  final List<LeaderboardEntry> entries;
  final bool isLoading;

  const _PodiumSection({
    required this.period,
    required this.entries,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // ─────────────────────────────────────────────────────────────
          // TITLE
          // ─────────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'leaderboard_title'.tr(),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      period.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Small trophy icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC72C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFB800),
                  size: 25,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─────────────────────────────────────────────────────────────
          // PODIUM
          // ─────────────────────────────────────────────────────────────
          if (isLoading)
            const SizedBox(
              height: 230,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFFC72C)),
              ),
            )
          else if (entries.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'be_first_podium'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 245,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // SECOND PLACE
                  if (entries.length >= 2)
                    Expanded(
                      child: _PodiumBar(
                        rank: 2,
                        entry: entries[1],
                        period: period,
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),

                  const SizedBox(width: 10),

                  // FIRST PLACE
                  Expanded(
                    child: _PodiumBar(
                      rank: 1,
                      entry: entries[0],
                      period: period,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // THIRD PLACE
                  if (entries.length >= 3)
                    Expanded(
                      child: _PodiumBar(
                        rank: 3,
                        entry: entries[2],
                        period: period,
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PODIUM CARD
// ═══════════════════════════════════════════════════════════════════════════

class _PodiumBar extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final LeaderboardPeriod period;

  const _PodiumBar({
    required this.rank,
    required this.entry,
    required this.period,
  });

  Color get _badgeColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB800);
      case 2:
        return const Color(0xFF9AA4AE);
      case 3:
        return const Color(0xFFB87333);
      default:
        return Colors.grey;
    }
  }

  Color _cardColor(bool isDark) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFC72C).withValues(alpha: isDark ? 0.22 : 0.18);
      case 2:
        return isDark
            ? Colors.white.withValues(alpha: 0.09)
            : const Color(0xFFE7EAED).withValues(alpha: 0.65);
      case 3:
        return isDark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFEBD9CA).withValues(alpha: 0.65);
      default:
        return Colors.grey.withValues(alpha: isDark ? 0.15 : 0.1);
    }
  }

  String get _rankText {
    switch (rank) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = entry.scoreFor(period);
    final isFirst = rank == 1;
    final avatarSize = isFirst ? 58.0 : 50.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: EdgeInsets.only(top: isFirst ? 18 : 22),
          padding: EdgeInsets.fromLTRB(8, isFirst ? 16 : 14, 8, 14),
          decoration: BoxDecoration(
            color: _cardColor(Theme.of(context).brightness == Brightness.dark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFirst
                  ? const Color(0xFFFFC72C).withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.04),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isFirst ? 0.06 : 0.025),
                blurRadius: isFirst ? 18 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─────────────────────────────────────────────────────────────
              // MEDAL / RANK LABEL
              //
              // IMPORTANT:
              // The rank is NOT placed underneath the avatar anymore.
              // It is now a clean pill above the profile picture.
              // ─────────────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _badgeColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _badgeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rank == 1)
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 13,
                        color: Colors.white,
                      ),

                    if (rank == 1) const SizedBox(width: 3),

                    Text(
                      _rankText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ─────────────────────────────────────────────────────────────
              // AVATAR
              // ─────────────────────────────────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Avatar outer ring
                  Container(
                    width: avatarSize + 10,
                    height: avatarSize + 10,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _badgeColor.withValues(alpha: 0.45),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: entry.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: entry.photoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: avatarSize * 0.55,
                                    color: Colors.black38,
                                  ),
                                );
                              },
                              errorWidget: (context, url, error) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: avatarSize * 0.55,
                                    color: Colors.black38,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.person_rounded,
                                size: avatarSize * 0.55,
                                color: Colors.black38,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ─────────────────────────────────────────────────────────────
              // NAME
              // ─────────────────────────────────────────────────────────────
              Text(
                entry.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isFirst ? 14 : 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 5),

              // ─────────────────────────────────────────────────────────────
              // SCORE
              // ─────────────────────────────────────────────────────────────
              Builder(
                builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'pts_count'.tr(args: [score.toString()]),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (isFirst)
          Positioned(
            top: -20,
            child: Image.asset(
              'assets/images/crown.png',
              width: 58,
              height: 58,
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LEADERBOARD ROW
// ═══════════════════════════════════════════════════════════════════════════

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

  String get _scoreLabel {
    final score = entry.scoreFor(period);

    switch (period) {
      case LeaderboardPeriod.daily:
        return 'pts_today'.tr(args: [score.toString()]);

      case LeaderboardPeriod.weekly:
        return 'pts_this_week'.tr(args: [score.toString()]);

      case LeaderboardPeriod.monthly:
        return 'pts_this_month'.tr(args: [score.toString()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isCurrentUser ? const Color(0xFFFFC72C) : theme.cardColor;

    final borderColor = isCurrentUser
        ? const Color(0xFFFFC72C)
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isCurrentUser ? 0 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isCurrentUser ? 0.07 : 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // ───────────────────────────────────────────────────────────
            // RANK NUMBER
            // ───────────────────────────────────────────────────────────
            SizedBox(
              width: 42,
              child: Text(
                '#$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isCurrentUser
                      ? Colors.black
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ───────────────────────────────────────────────────────────
            // AVATAR
            // ───────────────────────────────────────────────────────────
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? Colors.white.withValues(alpha: 0.8)
                    : theme.colorScheme.surfaceContainerHighest,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: entry.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: entry.photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) {
                          return Icon(
                            Icons.person_rounded,
                            color: isCurrentUser
                                ? Colors.black45
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.35,
                                  ),
                          );
                        },
                        errorWidget: (context, url, error) {
                          return Icon(
                            Icons.person_rounded,
                            color: isCurrentUser
                                ? Colors.black45
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.35,
                                  ),
                          );
                        },
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 25,
                        color: isCurrentUser
                            ? Colors.black45
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
                      ),
              ),
            ),

            const SizedBox(width: 14),

            // ───────────────────────────────────────────────────────────
            // USER NAME + SCORE
            // ───────────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isCurrentUser ? 'you'.tr() : entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isCurrentUser
                                ? Colors.black
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),

                      if (isCurrentUser) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    _scoreLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser
                          ? Colors.black.withValues(alpha: 0.65)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final LeaderboardPeriod period;

  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC72C).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 40,
                color: Color(0xFFFFB800),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'no_scores_yet'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'complete_exercises_appear_leaderboard'.tr(
                args: [period.label.toLowerCase()],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
