import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../models/friend_info.dart';
import '../services/friends_service.dart';
import 'friend_profile_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _searchController = TextEditingController();
  TextEditingController? _autoCompleteController;
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendFriendRequest() async {
    final query = (_autoCompleteController?.text ?? _searchController.text).trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('not_signed_in'.tr());

      await FriendsService.instance.sendFriendRequest(
        fromUid: user.uid,
        fromName: user.displayName ?? 'A user',
        toUsername: query,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('friend_request_sent'.tr()), backgroundColor: Colors.green),
        );
        _searchController.clear();
        _autoCompleteController?.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Center(child: Text('not_signed_in'.tr()));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Search & Add ──
            Text('add_a_friend'.tr(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface, letterSpacing: 1.4)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      final queryStr = textEditingValue.text.trim();
                      if (queryStr.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      try {
                        String queryLower = queryStr.toLowerCase();
                        String queryCapitalized = '${queryStr[0].toUpperCase()}${queryStr.substring(1).toLowerCase()}';
                        
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
                          final data = d.data();
                          data['uid'] = d.id;
                          final name = (data['displayName'] ?? data['username']) as String?;
                          if (name != null && name.isNotEmpty) {
                            data['display_name_resolved'] = name;
                            uniqueUsers[d.id] = data;
                          }
                        }
                        
                        return uniqueUsers.values.take(6);
                      } catch (e) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                    },
                    displayStringForOption: (option) => option['display_name_resolved'] as String,
                    onSelected: (Map<String, dynamic> selection) {
                      _autoCompleteController?.text = selection['display_name_resolved'] as String;
                      
                      final friend = FriendInfo(
                        uid: selection['uid'] as String,
                        displayName: selection['display_name_resolved'] as String,
                        pairId: '',
                        sharedStreak: 0,
                        overallStreak: (selection['overallStreak'] as num?)?.toInt() ?? 0,
                        friendDoneToday: false,
                      );
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FriendProfileScreen(
                            friend: friend,
                            isFriend: false,
                          ),
                        ),
                      );
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      _autoCompleteController = textEditingController;
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onSubmitted: (String value) {
                          onFieldSubmitted();
                          _sendFriendRequest();
                        },
                        decoration: InputDecoration(
                          hintText: 'search_username_hint'.tr(),
                          errorText: _searchError,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(color: PCColors.yellowDark),
                      )
                    : ElevatedButton(
                        onPressed: _sendFriendRequest,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('find'.tr()),
                      ),
              ],
            ),
            const SizedBox(height: 32),

            // ── 2. Incoming Requests ──
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('friendRequests')
                  .where('toUid', isEqualTo: uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

                final docs = snapshot.data!.docs;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('friend_requests'.tr(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface, letterSpacing: 1.4)),
                    const SizedBox(height: 12),
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: PCColors.yellow.withValues(alpha: 0.3),
                            child: Icon(Icons.person, color: context.textPrimary),
                          ),
                          title: Text(data['fromName'] ?? 'someone'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('wants_to_be_friends'.tr()),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => FriendsService.instance.rejectRequest(doc.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () => FriendsService.instance.acceptRequest(doc.id, data['fromUid'], uid),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),

            // ── 3. Friends List ──
            Text('your_friends'.tr(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface, letterSpacing: 1.4)),
            const SizedBox(height: 12),
            StreamBuilder<List<FriendInfo>>(
              stream: FriendsService.instance.getFriendsList(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: PCColors.yellowDark),
                  ));
                }

                final friends = snapshot.data ?? [];
                if (friends.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('no_friends_yet'.tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final f = friends[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FriendProfileScreen(friend: f),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: f.friendDoneToday ? PCColors.green : context.cardColor,
                              child: Icon(Icons.person, color: f.friendDoneToday ? Colors.white : context.textPrimary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('personal_streak'.tr(args: [f.overallStreak.toString()]), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: PCColors.yellow.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: PCColors.yellowDark, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.handshake_rounded, size: 16, color: context.textPrimary),
                                  const SizedBox(width: 6),
                                  Text('${f.sharedStreak}', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
