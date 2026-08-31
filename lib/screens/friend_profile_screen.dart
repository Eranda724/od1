import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_info.dart';
import '../services/friends_service.dart';
import '../app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/streak_service.dart';

class FriendProfileScreen extends StatelessWidget {
  final FriendInfo friend;
  final bool isFriend;

  const FriendProfileScreen({
    super.key,
    required this.friend,
    this.isFriend = true,
  });

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<String> _last7Days() {
    final days = <String>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      days.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = _todayKey();
    final last7 = _last7Days();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final pairId = FriendsService.getPairId(currentUid, friend.uid);

    return Scaffold(
      backgroundColor: context.background,

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(friend.uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: PCColors.yellowDark),
            );
          }
          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};

          final rawFreezesAvailable =
              (userData['freezesAvailable'] ?? 2) as int;
          final rawFrozenDates = List<String>.from(
            userData['frozenDates'] ?? [],
          );
          final rawLastEvaluatedDate =
              userData['overallLastEvaluatedDate'] as String?;

          final effectiveData = StreakService.getEffectiveStreakData(
            streak: (userData['overallStreak'] ?? 0) as int,
            freezesAvailable: rawFreezesAvailable,
            frozenDates: rawFrozenDates,
            lastEvaluatedDate: rawLastEvaluatedDate,
          );

          final frozenDates = effectiveData.frozenDates.toSet();
          final overallStreak = effectiveData.streak;

          final activeDaysList = List<String>.from(
            userData['activeDates'] ?? [],
          );
          final activeDays = activeDaysList.toSet();

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // USER DETAILS
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: context.cardColor,
                        backgroundImage: friend.photoUrl != null
                            ? CachedNetworkImageProvider(friend.photoUrl!)
                            : null,
                        child: friend.photoUrl == null
                            ? Icon(
                                Icons.person,
                                size: 32,
                                color: context.textPrimary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          friend.displayName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/fire_3d.png',
                            width: 28,
                            height: 28,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$overallStreak',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('friendPairs')
                        .doc(pairId)
                        .snapshots(),
                    builder: (context, pairSnap) {
                      final actuallyFriends =
                          pairSnap.hasData && pairSnap.data!.exists;

                      final pairData =
                          pairSnap.data?.data() as Map<String, dynamic>? ?? {};
                      final liveSharedStreak =
                          (pairData['sharedStreak'] ?? 0) as int;

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // TOP YELLOW TIER (Personal Streak)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(
                                left: 24,
                                top: 24,
                                right: 16,
                                bottom: 24,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFffc226),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // FRIEND STREAK label
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'friend_streak_caps'.tr(),
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF5A3D00),
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        // Fire + Number + DAY STREAK
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 74,
                                              height: 60,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 0,
                                                    child: Image.asset(
                                                      'assets/images/fire_3d.png',
                                                      width: 60,
                                                      height: 60,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    left: 14,
                                                    child: Image.asset(
                                                      'assets/images/fire_3d.png',
                                                      width: 60,
                                                      height: 60,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Number + DAY STREAK stacked
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '$liveSharedStreak',
                                                      style: const TextStyle(
                                                        fontSize: 68,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Color(
                                                          0xFF332200,
                                                        ),
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      'day_streak_caps'.tr(),
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(
                                                          0xFF7A5000,
                                                        ),
                                                        letterSpacing: 2.0,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(8, -8),
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.rotationY(math.pi),
                                      child: Image.asset(
                                        'assets/images/login.png',
                                        height: 160,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // MIDDLE SECTION (Weekly Activity)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: last7.map((day) {
                                  final isActive = activeDays.contains(day);
                                  final isToday = day == today;
                                  bool isFrozen = frozenDates.contains(day);

                                  return _DayDot(
                                    label: _shortDay(context, day),
                                    active: isActive,
                                    isFrozen: isFrozen,
                                    isToday: isToday,
                                  );
                                }).toList(),
                              ),
                            ),

                            // BOTTOM SECTION (Together Streak)
                            if (actuallyFriends) ...[
                              Divider(
                                color: isDark ? Colors.white12 : Colors.black12,
                                thickness: 1,
                                height: 1,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'shared_streak_header'
                                              .tr()
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: isDark
                                                ? Colors.orangeAccent
                                                : PCColors.brownDark,
                                            letterSpacing: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'shared_streak_sentence'.tr(
                                        args: [
                                          friend.displayName,
                                          '$liveSharedStreak',
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  _FriendshipActionButtons(
                    currentUid: currentUid,
                    friend: friend,
                    pairId: pairId,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _shortDay(BuildContext context, String key) {
    final d = DateTime.parse(key);
    return DateFormat.E(context.locale.languageCode).format(d);
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool isFrozen;
  final bool isToday;

  const _DayDot({
    required this.label,
    required this.active,
    required this.isFrozen,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;

    if (active) {
      iconWidget = SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Image.asset(
            'assets/images/fire_3d.png',
            width: 28,
            height: 28,
          ),
        ),
      );
    } else if (isFrozen) {
      iconWidget = SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, 6),
            child: OverflowBox(
              maxWidth: 80,
              maxHeight: 80,
              child: Image.asset(
                'assets/images/ice_cube_3d.png',
                width: 36,
                height: 46,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
      );
    } else {
      iconWidget = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      );
    }

    return Column(
      children: [
        iconWidget,
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
            color: isToday
                ? Colors.red
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : PCColors.brownDark.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

class _FriendshipActionButtons extends StatefulWidget {
  final String currentUid;
  final FriendInfo friend;
  final String pairId;

  const _FriendshipActionButtons({
    required this.currentUid,
    required this.friend,
    required this.pairId,
  });

  @override
  State<_FriendshipActionButtons> createState() =>
      _FriendshipActionButtonsState();
}

class _FriendshipActionButtonsState extends State<_FriendshipActionButtons> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.currentUid.isEmpty || widget.currentUid == widget.friend.uid)
      return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friendPairs')
          .doc(widget.pairId)
          .snapshots(),
      builder: (context, pairSnap) {
        if (pairSnap.hasError) {
          debugPrint('Error loading pair: ${pairSnap.error}');
        }
        if (!pairSnap.hasData && !pairSnap.hasError)
          return const Center(
            child: CircularProgressIndicator(color: PCColors.yellowDark),
          );

        final isFriend = pairSnap.data?.exists ?? false;

        if (isFriend) {
          return SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('remove_friend_title'.tr()),
                          content: Text('remove_friend_confirm_msg'.tr()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text('cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(
                                'remove'.tr(),
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setState(() => _isLoading = true);
                        try {
                          await FriendsService.instance.removeFriend(
                            widget.currentUid,
                            widget.friend.uid,
                          );
                          if (context.mounted) Navigator.pop(context);
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      }
                    },
              icon: Icon(
                Icons.delete_outline,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              label: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    )
                  : Text(
                      'remove_friend_title'.tr().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.05),
                foregroundColor: isDark ? Colors.white70 : Colors.black54,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friendRequests')
              .where('fromUid', isEqualTo: widget.currentUid)
              .where('toUid', isEqualTo: widget.friend.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, reqSnap) {
            if (reqSnap.hasError) {
              debugPrint('Error loading requests: ${reqSnap.error}');
            }
            if (!reqSnap.hasData && !reqSnap.hasError)
              return const Center(
                child: CircularProgressIndicator(color: PCColors.yellowDark),
              );

            final hasSentRequest = reqSnap.data?.docs.isNotEmpty ?? false;

            if (hasSentRequest) {
              return SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          try {
                            await FriendsService.instance.removeFriendRequest(
                              widget.currentUid,
                              widget.friend.uid,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('request_removed'.tr()),
                                  backgroundColor: Colors.grey,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'error_msg'.tr(
                                      args: [
                                        e.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                      ],
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  label: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        )
                      : Text(
                          'remove_request'.tr().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.05),
                    foregroundColor: isDark ? Colors.white70 : Colors.black54,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF997300)
                        : const Color(0xFFE5A600),
                    offset: const Offset(0, 5),
                    blurRadius: 0,
                  ),
                  const BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 8),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser != null) {
                            await FriendsService.instance.sendFriendRequest(
                              fromUid: currentUser.uid,
                              fromName:
                                  currentUser.displayName ?? 'a_user'.tr(),
                              toUsername: widget.friend.displayName,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('friend_request_sent'.tr()),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'error_msg'.tr(
                                    args: [
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    ],
                                  ),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PCColors.yellow,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black87,
                        ),
                      )
                    : Text(
                        'send_request'.tr().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
