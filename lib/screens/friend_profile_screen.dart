import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_info.dart';
import '../services/friends_service.dart';
import '../app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FriendProfileScreen extends StatelessWidget {
  final FriendInfo friend;
  final bool isFriend;

  const FriendProfileScreen({super.key, required this.friend, this.isFriend = true});

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<String> _last7Days() {
    final days = <String>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      days.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayKey();
    final last7 = _last7Days();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final pairId = FriendsService.getPairId(currentUid, friend.uid);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: context.appBarColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(friend.uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator(color: PCColors.yellowDark));
          }
          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final overallStreak = (userData['overallStreak'] ?? friend.overallStreak) as int;
          final freezesAvailable = (userData['freezesAvailable'] ?? 0) as int;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(friend.uid).collection('exercises').snapshots(),
            builder: (context, exSnap) {
              final activeDays = <String>{};
              if (exSnap.hasData) {
                for (final doc in exSnap.data!.docs) {
                  final exData = doc.data() as Map<String, dynamic>;
                  final d = exData['lastCompletedDate'] as String?;
                  if (d != null) activeDays.add(d);
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── USER DETAILS ──
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: context.cardColor,
                          backgroundImage: friend.photoUrl != null ? CachedNetworkImageProvider(friend.photoUrl!) : null,
                          child: friend.photoUrl == null ? Icon(Icons.person, size: 32, color: context.textPrimary) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                friend.displayName,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('friendPairs').doc(pairId).snapshots(),
                      builder: (context, pairSnap) {
                        final actuallyFriends = pairSnap.hasData && pairSnap.data!.exists;
                        
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [PCColors.brownDark, Color(0xFF3A2010)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // TOP SECTION (Numbers)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Half: Current Streak
                                  Expanded(
                                    child: Column(
                                      children: [
                                        const Text('🔥', style: TextStyle(fontSize: 28)),
                                        const SizedBox(height: 12),
                                        Text(
                                          '$overallStreak',
                                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: PCColors.yellow, height: 1),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'current_streak'.tr(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, height: 1.2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  if (actuallyFriends) ...[
                                    Container(width: 1, height: 100, color: Colors.white12),
                                    
                                    // Right Half: Shared Streak
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text('🤝', style: TextStyle(fontSize: 28)),
                                          const SizedBox(height: 12),
                                          Text(
                                            '${friend.sharedStreak}',
                                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: PCColors.yellow, height: 1),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'together_streak'.tr(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, height: 1.2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                              
                              if (actuallyFriends) ...[
                                const SizedBox(height: 24),
                                const Divider(color: Colors.white12, thickness: 1),
                                const SizedBox(height: 24),
                                
                                // MIDDLE SECTION (Shared Context)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🤝', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'shared_streak_header'.tr().toUpperCase(),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PCColors.yellow, letterSpacing: 1.4),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'shared_streak_sentence'.tr(args: [friend.displayName, '${friend.sharedStreak}']),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70, height: 1.4),
                                ),
                              ],
                              
                              const SizedBox(height: 24),
                              const Divider(color: Colors.white12, thickness: 1),
                              const SizedBox(height: 24),
                              
                              // BOTTOM SECTION (Weekly Activity)
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: Colors.white54, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'weekly_activity'.tr().toUpperCase(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.4),
                                  ),
                                  const Spacer(),
                                  if (freezesAvailable > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.blueAccent, width: 1),
                                      ),
                                      child: Text(
                                        '❄️ $freezesAvailable/2',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueAccent),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: last7.map((day) {
                                  final isActive = activeDays.contains(day);
                                  final isToday = day == today;
                                  return _DayDot(
                                    label: _shortDay(context, day),
                                    active: isActive,
                                    isToday: isToday,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),
                    _FriendshipActionButtons(currentUid: currentUid, friend: friend, pairId: pairId),
                  ],
                ),
              );
            },
          );
        }
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
  final bool isToday;

  const _DayDot({required this.label, required this.active, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? PCColors.yellow : Colors.white12,
            border: isToday ? Border.all(color: PCColors.yellow, width: 2) : null,
          ),
          child: active
              ? const Center(child: Text('🔥', style: TextStyle(fontSize: 16)))
              : isToday
                  ? const Center(child: Text('•', style: TextStyle(color: PCColors.yellow, fontSize: 22, height: 1)))
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? PCColors.yellow : Colors.white38,
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

  const _FriendshipActionButtons({required this.currentUid, required this.friend, required this.pairId});

  @override
  State<_FriendshipActionButtons> createState() => _FriendshipActionButtonsState();
}

class _FriendshipActionButtonsState extends State<_FriendshipActionButtons> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (widget.currentUid.isEmpty || widget.currentUid == widget.friend.uid) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('friendPairs').doc(widget.pairId).snapshots(),
      builder: (context, pairSnap) {
        if (pairSnap.hasError) {
          debugPrint('Error loading pair: ${pairSnap.error}');
        }
        if (!pairSnap.hasData && !pairSnap.hasError) return const Center(child: CircularProgressIndicator(color: PCColors.yellowDark));
        
        final isFriend = pairSnap.data?.exists ?? false;

        if (isFriend) {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: PCColors.brown, width: 2),
                  ),
                  child: Text('back'.tr(), style: const TextStyle(color: PCColors.brownDark, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('remove_friend_title'.tr()),
                        content: Text('remove_friend_confirm_msg'.tr()),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('cancel'.tr())),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('remove'.tr(), style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      setState(() => _isLoading = true);
                      try {
                        await FriendsService.instance.removeFriend(widget.currentUid, widget.friend.uid);
                        if (context.mounted) Navigator.pop(context);
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                      : Text('remove_friend_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
            if (!reqSnap.hasData && !reqSnap.hasError) return const Center(child: CircularProgressIndicator(color: PCColors.yellowDark));
            
            final hasSentRequest = reqSnap.data?.docs.isNotEmpty ?? false;

            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: PCColors.brown, width: 2),
                    ),
                    child: Text('back'.tr(), style: const TextStyle(color: PCColors.brownDark, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      try {
                        if (hasSentRequest) {
                          await FriendsService.instance.removeFriendRequest(widget.currentUid, widget.friend.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('request_removed'.tr()), backgroundColor: Colors.grey),
                            );
                          }
                        } else {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser != null) {
                            await FriendsService.instance.sendFriendRequest(
                              fromUid: currentUser.uid,
                              fromName: currentUser.displayName ?? 'A user',
                              toUsername: widget.friend.displayName,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('friend_request_sent'.tr()), backgroundColor: Colors.green),
                              );
                            }
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('error_msg'.tr(args: [e.toString().replaceFirst('Exception: ', '')])), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasSentRequest ? Colors.grey.shade300 : PCColors.yellow,
                      foregroundColor: hasSentRequest ? Colors.black54 : PCColors.brownDark,
                      elevation: hasSentRequest ? 0 : 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: hasSentRequest ? Colors.black54 : PCColors.brownDark))
                        : Text(hasSentRequest ? 'remove_request'.tr() : 'send_request'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
