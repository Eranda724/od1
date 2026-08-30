import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  final String? currentUid;
  final VoidCallback? onSwitchToSocial;

  const LeaderboardScreen({super.key, this.currentUid, this.onSwitchToSocial});

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
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: widget.currentUid == null
          ? const Stream.empty()
          : FirebaseFirestore.instance
                .collection('friendPairs')
                .where('uids', arrayContains: widget.currentUid!)
                .snapshots(),
      builder: (context, pairsSnapshot) {
        final friendCount = pairsSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<List<LeaderboardEntry>>(
          stream: widget.currentUid != null
              ? LeaderboardService.friendsStream(
                  _activePeriod,
                  widget.currentUid!,
                )
              : LeaderboardService.stream(_activePeriod),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? [];

            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                entries.isEmpty;

            return Column(
              children: [
                // ============================================================
                // 1. TITLE & BUTTON
                // ============================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'leaderboard_title'.tr(),
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFC72C,
                              ).withValues(alpha: 0.15),
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
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => widget.onSwitchToSocial?.call(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 18,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'add_friends_subtitle'.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ============================================================
                // 2. DAILY / WEEKLY / MONTHLY TABS
                // ============================================================
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
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: const Color(0xFFFFC72C),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFFC72C,
                            ).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      labelColor: Colors.black,
                      unselectedLabelColor: colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
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

                // ============================================================
                // DIVIDER
                // ============================================================
                Container(
                  height: 1,
                  color: colorScheme.onSurface.withValues(alpha: 0.07),
                ),

                // ============================================================
                // RANKED LIST
                // ============================================================
                Expanded(
                  child: _buildList(
                    context,
                    entries,
                    isLoading,
                    snapshot.hasError,
                    snapshot.error,
                  ),
                ),
              ],
            );
          },
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
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ================================================================
        // PODIUM
        // ================================================================
        SliverToBoxAdapter(
          child: _PodiumOnlySection(
            period: _activePeriod,
            entries: entries,
            isLoading: isLoading,
            currentUid: widget.currentUid,
          ),
        ),

        // ================================================================
        // LOADING
        // ================================================================
        if (isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFC72C),
                strokeWidth: 3,
              ),
            ),
          )
        // ================================================================
        // ERROR
        // ================================================================
        else if (hasError)
          SliverFillRemaining(
            child: Center(
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
            ),
          )
        // ================================================================
        // EMPTY
        // ================================================================
        else if (entries.isEmpty)
          SliverFillRemaining(child: _EmptyState(period: _activePeriod))
        // ================================================================
        // RANKED USERS
        // ================================================================
        else
          Builder(
            builder: (context) {
              final listEntries = entries.length > 3
                  ? entries.sublist(3)
                  : <LeaderboardEntry>[];

              if (listEntries.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = listEntries[index];
                    final rank = index + 4;
                    final isMe = entry.uid == widget.currentUid;

                    return _LeaderboardRow(
                      rank: rank,
                      entry: entry,
                      isCurrentUser: isMe,
                      period: _activePeriod,
                    );
                  }, childCount: listEntries.length),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ============================================================================
// PODIUM SECTION
// ============================================================================

class _PodiumOnlySection extends StatelessWidget {
  final LeaderboardPeriod period;
  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final String? currentUid;

  const _PodiumOnlySection({
    required this.period,
    required this.entries,
    required this.isLoading,
    this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // ==================================================================
          // PODIUM
          // ==================================================================
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
            Container(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ==========================================================
                  // SECOND PLACE
                  // ==========================================================
                  if (entries.length >= 2)
                    Expanded(
                      child: _PodiumBar(
                        rank: 2,
                        entry: entries[1],
                        period: period,
                        isCurrentUser: entries[1].uid == currentUid,
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),

                  const SizedBox(width: 10),

                  // ==========================================================
                  // FIRST PLACE
                  // ==========================================================
                  Expanded(
                    child: _PodiumBar(
                      rank: 1,
                      entry: entries[0],
                      period: period,
                      isCurrentUser: entries[0].uid == currentUid,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ==========================================================
                  // THIRD PLACE
                  // ==========================================================
                  if (entries.length >= 3)
                    Expanded(
                      child: _PodiumBar(
                        rank: 3,
                        entry: entries[2],
                        period: period,
                        isCurrentUser: entries[2].uid == currentUid,
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

// ============================================================================
// PODIUM CARD
// ============================================================================

class _PodiumBar extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final LeaderboardPeriod period;
  final bool isCurrentUser;

  const _PodiumBar({
    required this.rank,
    required this.entry,
    required this.period,
    this.isCurrentUser = false,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: EdgeInsets.only(top: isFirst ? 18 : 22),
          padding: EdgeInsets.fromLTRB(8, isFirst ? 16 : 14, 8, 14),
          decoration: BoxDecoration(
            color: _cardColor(isDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCurrentUser
                  ? const Color(0xFFFFC72C)
                  : (isFirst
                        ? const Color(0xFFFFC72C).withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.04)),
              width: isCurrentUser ? 2 : 1,
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
              // ============================================================
              // MEDAL / RANK LABEL
              // ============================================================
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

              // ============================================================
              // AVATAR
              // ============================================================
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
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

              // ============================================================
              // NAME
              // ============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
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
                  ),
                ],
              ),

              const SizedBox(height: 3),

              // ============================================================
              // CURRENT USER LABEL
              // ============================================================
              SizedBox(
                height: 16,
                child: isCurrentUser
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC72C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'you'.tr().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      )
                    : null,
              ),

              const SizedBox(height: 5),

              // ============================================================
              // SCORE
              // ============================================================
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                },
              ),

              // ============================================================
              // EXTRA PODIUM STEP HEIGHT
              // ============================================================
              if (rank == 1) const SizedBox(height: 40),
              if (rank == 2) const SizedBox(height: 20),
              if (rank == 3) const SizedBox(height: 8),
            ],
          ),
        ),

        // ==================================================================
        // CROWN
        // ==================================================================
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

// ============================================================================
// LEADERBOARD ROW
// ============================================================================

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

    final borderColor = isCurrentUser
        ? const Color(0xFFFFC72C)
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isCurrentUser ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // ==============================================================
            // RANK NUMBER
            // ==============================================================
            SizedBox(
              width: 42,
              child: Text(
                '#$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ==============================================================
            // AVATAR
            // ==============================================================
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
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
                                ? const Color(0xFFE6A700)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.35,
                                  ),
                          );
                        },
                        errorWidget: (context, url, error) {
                          return Icon(
                            Icons.person_rounded,
                            color: isCurrentUser
                                ? const Color(0xFFE6A700)
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
                            ? const Color(0xFFE6A700)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
                      ),
              ),
            ),

            const SizedBox(width: 14),

            // ==============================================================
            // USER NAME + SCORE
            // ==============================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
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
                            color: const Color(0xFFFFC72C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'you'.tr().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
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
                          ? const Color(0xFFD69E00)
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

// ============================================================================
// EMPTY STATE
// ============================================================================

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
            // ==================================================================
            // ICON CONTAINER
            // ==================================================================
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

            // ==================================================================
            // TITLE
            // ==================================================================
            Text(
              'no_scores_yet'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 8),

            // ==================================================================
            // DESCRIPTION
            // ==================================================================
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
