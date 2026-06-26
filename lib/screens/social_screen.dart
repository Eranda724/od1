import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_settings.dart';
import '../models/friend_info.dart';
import '../services/friends_service.dart';
import 'friend_profile_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendFriendRequest() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not signed in");

      await FriendsService.instance.sendFriendRequest(
        fromUid: user.uid,
        fromName: user.displayName ?? 'A user',
        toUsername: query,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!'), backgroundColor: Colors.green),
        );
        _searchController.clear();
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
    if (uid == null) return const Center(child: Text('Not logged in'));

    return Scaffold(
      backgroundColor: PCColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Search & Add ──
            const Text('ADD A FRIEND',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: PCColors.brown, letterSpacing: 1.4)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Enter exact username...',
                      errorText: _searchError,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
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
                        child: const Text('Find'),
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
                    const Text('FRIEND REQUESTS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: PCColors.brown, letterSpacing: 1.4)),
                    const SizedBox(height: 12),
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: PCColors.cream,
                            child: Icon(Icons.person, color: PCColors.brownDark),
                          ),
                          title: Text(data['fromName'] ?? 'Someone', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Wants to be friends'),
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
            const Text('YOUR FRIENDS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: PCColors.brown, letterSpacing: 1.4)),
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('You have no friends yet.\nAdd someone above!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
                              backgroundColor: f.friendDoneToday ? PCColors.green : PCColors.cream,
                              child: Icon(Icons.person, color: f.friendDoneToday ? Colors.white : PCColors.brownDark),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Personal Streak: ${f.overallStreak} 🔥', style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                                  const Icon(Icons.handshake_rounded, size: 16, color: PCColors.brownDark),
                                  const SizedBox(width: 6),
                                  Text('${f.sharedStreak}', style: const TextStyle(fontWeight: FontWeight.bold, color: PCColors.brownDark)),
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
