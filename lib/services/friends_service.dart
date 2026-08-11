import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_info.dart';
import 'notification_service.dart';
import 'streak_service.dart';
import 'dart:math' as math;

class FriendsService {
  FriendsService._();
  static final FriendsService instance = FriendsService._();

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayKey() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  static String getPairId(String uid1, String uid2) {
    final uids = [uid1, uid2]..sort();
    return '${uids[0]}_${uids[1]}';
  }

  // ── Send Friend Request ──
  Future<void> sendFriendRequest({
    required String fromUid,
    required String fromName,
    required String toUsername,
  }) async {
    // 1. Find user by username
    final usersRef = FirebaseFirestore.instance.collection('users');
    var query = await usersRef.where('displayName', isEqualTo: toUsername).limit(1).get();

    if (query.docs.isEmpty) {
      // Fallback: check legacy 'username' field
      query = await usersRef.where('username', isEqualTo: toUsername).limit(1).get();
    }

    if (query.docs.isEmpty) {
      throw Exception('User not found.');
    }
    
    final toUid = query.docs.first.id;
    if (toUid == fromUid) {
      throw Exception("You can't add yourself as a friend.");
    }

    final pairId = getPairId(fromUid, toUid);

    // 2. Check if already friends
    final pairDoc = await FirebaseFirestore.instance.collection('friendPairs').doc(pairId).get();
    if (pairDoc.exists) {
      throw Exception('You are already friends.');
    }

    // 3. Check for existing request
    final reqsQuery = await FirebaseFirestore.instance
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (reqsQuery.docs.isNotEmpty) {
      throw Exception('Friend request already sent.');
    }

    // 4. Create request
    await FirebaseFirestore.instance.collection('friendRequests').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'fromName': fromName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Accept Friend Request ──
  Future<void> acceptRequest(String docId, String fromUid, String toUid) async {
    final pairId = getPairId(fromUid, toUid);

    final batch = FirebaseFirestore.instance.batch();

    // 1. Mark request as accepted
    final reqRef = FirebaseFirestore.instance.collection('friendRequests').doc(docId);
    batch.update(reqRef, {'status': 'accepted'});

    // 2. Create pair document
    final pairRef = FirebaseFirestore.instance.collection('friendPairs').doc(pairId);
    batch.set(pairRef, {
      'uids': [fromUid, toUid],
    });

    await batch.commit();
  }

  // ── Reject Friend Request ──
  Future<void> rejectRequest(String docId) async {
    await FirebaseFirestore.instance
        .collection('friendRequests')
        .doc(docId)
        .update({'status': 'rejected'});
  }

  // ── Remove Friend Request ──
  Future<void> removeFriendRequest(String fromUid, String toUid) async {
    final reqsQuery = await FirebaseFirestore.instance
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in reqsQuery.docs) {
      await doc.reference.delete();
    }
  }

  // ── Remove Friend ──
  Future<void> removeFriend(String uid1, String uid2) async {
    final pairId = getPairId(uid1, uid2);
    await FirebaseFirestore.instance.collection('friendPairs').doc(pairId).delete();
  }

  // ── Get Friends List ──
  Stream<List<FriendInfo>> getFriendsList(String currentUid) {
    return FirebaseFirestore.instance
        .collection('friendPairs')
        .where('uids', arrayContains: currentUid)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<FriendInfo> friends = [];
      
      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final cData = currentUserDoc.data() ?? {};
      final cRawStreak = (cData['overallStreak'] ?? 0) as int;
      final cRawFreezes = (cData['freezesAvailable'] ?? 2) as int;
      final cRawFrozen = List<String>.from(cData['frozenDates'] ?? []);
      final cRawLastDate = cData['overallLastEvaluatedDate'] as String?;

      final cEffective = StreakService.getEffectiveStreakData(
        streak: cRawStreak,
        freezesAvailable: cRawFreezes,
        frozenDates: cRawFrozen,
        lastEvaluatedDate: cRawLastDate,
      );
      final currentUserStreak = cEffective.streak;
      final today = _todayKey();

      final friendUids = <String>[];
      final pairIdsByFriendUid = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final uids = List<String>.from(data['uids']);
        final friendUid = uids.firstWhere((id) => id != currentUid);
        friendUids.add(friendUid);
        pairIdsByFriendUid[friendUid] = doc.id;
      }

      final friendDocs = <DocumentSnapshot>[];
      for (var i = 0; i < friendUids.length; i += 10) {
        final chunk = friendUids.sublist(i, math.min(i + 10, friendUids.length));
        if (chunk.isEmpty) continue;
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        friendDocs.addAll(snap.docs);
      }

      for (final friendDoc in friendDocs) {
        final fData = friendDoc.data() as Map<String, dynamic>;
        final friendUid = friendDoc.id;
        final friendName = fData['displayName'] ?? 'Unknown';
        final rawOverallStreak = fData['overallStreak'] ?? 0;
        final rawFreezesAvailable = fData['freezesAvailable'] ?? 2;
        final rawFrozenDates = List<String>.from(fData['frozenDates'] ?? []);
        final rawLastEvaluatedDate = fData['overallLastEvaluatedDate'] as String?;

        final effectiveData = StreakService.getEffectiveStreakData(
          streak: rawOverallStreak,
          freezesAvailable: rawFreezesAvailable,
          frozenDates: rawFrozenDates,
          lastEvaluatedDate: rawLastEvaluatedDate,
        );

        final overallStreak = effectiveData.streak;
        final friendDoneToday = (fData['overallLastDate'] as String?) == today;

        friends.add(FriendInfo(
          uid: friendUid,
          displayName: friendName,
          overallStreak: overallStreak,
          yearlyActiveDays: (fData['yearlyActiveDays'] as num?)?.toInt() ?? 0,
          sharedStreak: math.min(currentUserStreak, overallStreak),
          sharedLastDate: null,
          friendDoneToday: friendDoneToday,
          pairId: pairIdsByFriendUid[friendUid]!,
          photoUrl: fData['photoUrl'],
        ));
      }
      return friends;
    });
  }

}
