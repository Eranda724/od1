import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../models/friend_info.dart';
import '../services/friends_service.dart';
import 'friend_profile_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  String? _searchError;
  List<Map<String, dynamic>> _searchResults = [];

  Set<String> _friendUids = {};
  StreamSubscription? _friendsSub;
  Set<String> _sentRequests = {}; // To track sent state locally for UI
  StreamSubscription? _requestsSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _friendsSub = FirebaseFirestore.instance
          .collection('friendPairs')
          .where('uids', arrayContains: uid)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              final uids = <String>{};
              for (var doc in snapshot.docs) {
                final array = List<String>.from(doc.data()['uids'] ?? []);
                uids.addAll(array);
              }
              setState(() {
                _friendUids = uids;
              });
            }
          });

      _requestsSub = FirebaseFirestore.instance
          .collection('friendRequests')
          .where('fromUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              final sent = <String>{};
              for (var doc in snapshot.docs) {
                sent.add(doc.data()['toUid'] as String);
              }
              setState(() {
                _sentRequests = sent;
              });
            }
          });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String queryStr) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (queryStr.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _performSearch(queryStr.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> _performSearch(String queryStr) async {
    try {
      String queryLower = queryStr.toLowerCase();
      String queryCapitalized =
          '${queryStr[0].toUpperCase()}${queryStr.substring(1).toLowerCase()}';

      final snap1 = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: queryLower)
          .where('displayName', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(4)
          .get();

      final snap2 = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: queryCapitalized)
          .where('displayName', isLessThanOrEqualTo: '$queryCapitalized\uf8ff')
          .limit(4)
          .get();

      final snap3 = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: queryLower)
          .where('username', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(4)
          .get();

      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      final allDocs = [...snap1.docs, ...snap2.docs, ...snap3.docs];
      final Map<String, Map<String, dynamic>> uniqueUsers = {};

      for (var d in allDocs) {
        if (d.id == currentUid) continue; // Exclude current user
        if (_friendUids.contains(d.id)) continue; // Exclude current friends

        final data = d.data();
        data['uid'] = d.id;
        final name = (data['displayName'] ?? data['username']) as String?;
        if (name != null && name.isNotEmpty) {
          data['display_name_resolved'] = name;
          uniqueUsers[d.id] = data;
        }
      }

      return uniqueUsers.values.take(6).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _sendFriendRequest(String toUid, String toUsername) async {
    setState(() {
      _searchError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('not_signed_in'.tr());

      await FriendsService.instance.sendFriendRequest(
        fromUid: user.uid,
        fromName: user.displayName ?? 'A user',
        toUsername: toUsername,
      );

      if (mounted) {
        setState(() {
          _sentRequests.add(toUid);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('friend_request_sent'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_searchError ?? ''),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Center(child: Text('not_signed_in'.tr()));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Screen Header
              Text(
                'add_friends_title'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),

              // 2. Search Bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onTapOutside: (event) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'search_user_hint'.tr(),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white54 : Colors.grey,
                    size: 22,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white54 : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF2F2F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Search Results
              if (_isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      color: PCColors.yellowDark,
                    ),
                  ),
                )
              else if (_searchController.text.isNotEmpty &&
                  _searchResults.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'no_users_found'.tr(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else if (_searchController.text.isNotEmpty &&
                  _searchResults.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final userId = user['uid'] as String;
                    final isSent = _sentRequests.contains(userId);

                    return GestureDetector(
                      onTap: () {
                        final currentUid =
                            FirebaseAuth.instance.currentUser?.uid ?? '';
                        final f = FriendInfo(
                          uid: userId,
                          displayName: user['display_name_resolved'] as String,
                          overallStreak:
                              (user['overallStreak'] as num?)?.toInt() ?? 0,
                          yearlyActiveDays:
                              (user['activeDates'] as List?)?.length ?? 0,
                          sharedStreak: 0,
                          friendDoneToday: false,
                          pairId: FriendsService.getPairId(currentUid, userId),
                          photoUrl: user['photoUrl'] as String?,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FriendProfileScreen(
                              friend: f,
                              isFriend:
                                  false, // Not friends since they appeared in search
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _UserSearchResultRow(
                          uid: userId,
                          name: user['display_name_resolved'] as String,
                          photoUrl: user['photoUrl'] as String?,
                          streak: (user['overallStreak'] as num?)?.toInt() ?? 0,
                          isSent: isSent,
                          onAdd: () => _sendFriendRequest(
                            userId,
                            user['display_name_resolved'],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              if (_searchController.text.isEmpty) ...[
                // 4. Incoming Requests
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('friendRequests')
                      .where('toUid', isEqualTo: uid)
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      return const SizedBox.shrink();

                    final docs = snapshot.data!.docs;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'friend_requests'.tr().toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: context.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: PCColors.yellow.withValues(
                                    alpha: 0.3,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['fromName'] ?? 'someone'.tr(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'wants_to_be_friends'.tr(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => FriendsService.instance
                                          .rejectRequest(doc.id),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white24 : Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: isDark ? Colors.white70 : Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () =>
                                          FriendsService.instance.acceptRequest(
                                            doc.id,
                                            data['fromUid'],
                                            uid,
                                          ),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: PCColors.yellow,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.black,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),

                // 5. Friends List
                Text(
                  'your_friends'.tr().toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<FriendInfo>>(
                  stream: FriendsService.instance.getFriendsList(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(
                            color: PCColors.yellowDark,
                          ),
                        ),
                      );
                    }

                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'no_friends_yet'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: friends.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final f = friends[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FriendProfileScreen(friend: f),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: f.friendDoneToday
                                          ? PCColors.green
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                    backgroundImage: f.photoUrl != null
                                        ? CachedNetworkImageProvider(
                                            f.photoUrl!,
                                          )
                                        : null,
                                    child: f.photoUrl == null
                                        ? Icon(
                                            Icons.person,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Name & Streak
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          f.displayName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: context.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Image.asset(
                                        'assets/images/fire_3d.png',
                                        width: 18,
                                        height: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${f.overallStreak}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Row(
                                  children: [
                                    SizedBox(
                                      width: 38,
                                      height: 28,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 0,
                                            child: Image.asset(
                                              'assets/images/fire_3d.png',
                                              width: 28,
                                              height: 28,
                                            ),
                                          ),
                                          Positioned(
                                            left: 10,
                                            child: Image.asset(
                                              'assets/images/fire_3d.png',
                                              width: 28,
                                              height: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${f.sharedStreak}',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// NEW BORDERLESS RESULT ROW WIDGET

class _UserSearchResultRow extends StatelessWidget {
  final String uid;
  final String name;
  final String? photoUrl;
  final int streak;
  final bool isSent;
  final VoidCallback onAdd;

  const _UserSearchResultRow({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.streak,
    required this.isSent,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          backgroundImage: photoUrl != null
              ? CachedNetworkImageProvider(photoUrl!)
              : null,
          child: photoUrl == null
              ? Icon(Icons.person, color: isDark ? Colors.white38 : Colors.black38)
              : null,
        ),
        const SizedBox(width: 16),

        // Name & Subtitle
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Image.asset('assets/images/fire_3d.png', width: 18, height: 18),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Add Button
        const SizedBox(width: 12),
        SizedBox(
          width: 100, // Fixed width for alignment
          height: 36,
          child: ElevatedButton(
            onPressed: isSent ? null : onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: isSent ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300) : PCColors.yellow,
              foregroundColor: isSent ? Colors.grey : Colors.black,
              elevation: 0,
              padding: EdgeInsets.zero, // Adjust padding inside text
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              isSent ? 'sent_caps'.tr() : 'add_caps'.tr(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
