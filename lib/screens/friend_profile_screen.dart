import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_info.dart';
import '../app_settings.dart';

class FriendProfileScreen extends StatelessWidget {
  final FriendInfo friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PCColors.background,
      appBar: AppBar(
        title: Text(friend.displayName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero Section: Streaks ──
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: PCColors.yellow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text('PERSONAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PCColors.brownDark)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: PCColors.brownDark, size: 28),
                            const SizedBox(width: 8),
                            Text('${friend.overallStreak}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: PCColors.brownDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: PCColors.cream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PCColors.yellowDark, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Text('SHARED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PCColors.brownDark)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.handshake_rounded, color: PCColors.brownDark, size: 28),
                            const SizedBox(width: 8),
                            Text('${friend.sharedStreak}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: PCColors.brownDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            const Text(
              'LIFETIME TOTALS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: PCColors.brown,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // ── Friend's Exercises Stream ──
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friend.uid)
                  .collection('exercises')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: PCColors.yellowDark));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text("They haven't done any exercises yet.", style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final name = data['exerciseName'] ?? 'Unknown Exercise';
                    final lifetime = data['lifetimeTotal'] ?? 0;
                    final streak = data['currentStreak'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Lifetime: $lifetime reps', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: PCColors.cream,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, size: 16, color: PCColors.yellowDark),
                                  const SizedBox(width: 4),
                                  Text('$streak', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
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
        ),
      ),
    );
  }
}
