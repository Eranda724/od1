import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_info.dart';
import 'notification_service.dart';

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

  static String _getPairId(String uid1, String uid2) {
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

    final pairId = _getPairId(fromUid, toUid);

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
    final pairId = _getPairId(fromUid, toUid);

    final batch = FirebaseFirestore.instance.batch();

    // 1. Mark request as accepted
    final reqRef = FirebaseFirestore.instance.collection('friendRequests').doc(docId);
    batch.update(reqRef, {'status': 'accepted'});

    // 2. Create pair document
    final pairRef = FirebaseFirestore.instance.collection('friendPairs').doc(pairId);
    batch.set(pairRef, {
      'uids': [fromUid, toUid],
      'sharedStreak': 0,
      'sharedLastDate': null,
      '${fromUid}_doneToday': false,
      '${toUid}_doneToday': false,
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

  // ── Get Friends List ──
  Stream<List<FriendInfo>> getFriendsList(String currentUid) {
    return FirebaseFirestore.instance
        .collection('friendPairs')
        .where('uids', arrayContains: currentUid)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<FriendInfo> friends = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final uids = List<String>.from(data['uids']);
        final friendUid = uids.firstWhere((id) => id != currentUid);

        // Fetch friend's public profile stats
        final friendDoc = await FirebaseFirestore.instance.collection('users').doc(friendUid).get();
        if (!friendDoc.exists) continue;

        final fData = friendDoc.data()!;
        final friendName = fData['displayName'] ?? 'Unknown';
        final overallStreak = fData['overallStreak'] ?? 0;

        friends.add(FriendInfo(
          uid: friendUid,
          displayName: friendName,
          overallStreak: overallStreak,
          sharedStreak: data['sharedStreak'] ?? 0,
          sharedLastDate: data['sharedLastDate'],
          friendDoneToday: data['${friendUid}_doneToday'] ?? false,
          pairId: doc.id,
        ));
      }
      return friends;
    });
  }

  // ── Record Exercise Done ──
  Future<void> recordExerciseDone(String uid) async {
    final pairsSnap = await FirebaseFirestore.instance
        .collection('friendPairs')
        .where('uids', arrayContains: uid)
        .get();

    if (pairsSnap.docs.isEmpty) return;

    final today = _todayKey();
    final yesterday = _yesterdayKey();
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in pairsSnap.docs) {
      final data = doc.data();
      final uids = List<String>.from(data['uids']);
      final friendUid = uids.firstWhere((id) => id != uid);

      final friendDone = data['${friendUid}_doneToday'] ?? false;
      final sharedLastDate = data['sharedLastDate'];
      int sharedStreak = data['sharedStreak'] ?? 0;

      if (friendDone) {
        // Both have done it today! Increment/set shared streak
        if (sharedLastDate == today) {
          // already incremented today, do nothing to streak
        } else if (sharedLastDate == yesterday) {
          sharedStreak++;
        } else {
          sharedStreak = 1;
        }

        batch.update(doc.reference, {
          'sharedStreak': sharedStreak,
          'sharedLastDate': today,
          '${uid}_doneToday': false,
          '${friendUid}_doneToday': false, // reset for tomorrow
        });
      } else {
        // Only this user has done it today
        // If they missed yesterday and didn't complete today, streak resets if we were checking strictly.
        // For shared streak without freeze, we wait for both. If sharedLastDate < yesterday,
        // it will naturally reset to 1 when both complete it.
        batch.update(doc.reference, {
          '${uid}_doneToday': true,
        });
      }
    }

    await batch.commit();
  }

  // ── Daily Friend Notification ──
  Future<void> maybeSendFriendActivityNotification({
    required String currentUid,
    required String exerciseName,
    required String detail,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUid);
    final userDoc = await userRef.get();
    if (!userDoc.exists) return;

    final today = _todayKey();
    final notifiedDate = userDoc.data()?['friendActivityNotifiedDate'];

    if (notifiedDate == today) return;

    // Send to ALL friends that this user did an exercise today?
    // Wait, the requirement: "One daily friend-activity notification — e.g. "Maria did 15 push-ups today"
    // Which means if CURRENT user does an exercise, we notify their friends.
    // BUT local notifications are fired ON the device.
    // So if Maria does push-ups, we can't trigger a local notification on John's phone from Maria's phone.
    // We would need Firebase Cloud Messaging (FCM) to push to John's phone.
    // Instead, if John opens his app or triggers a background sync, his app checks if Maria did it.
    // Wait, the client requirement: "One daily friend-activity notification... not real-time".
    // If we only have local notifications, the only way John sees Maria did pushups is if John's app schedules it or fires it when John opens the app.
    // If we want John to get a notification when Maria finishes, without FCM, it's impossible.
    // Actually, I can check if ANY friend did an exercise today when the current user opens the app or finishes an exercise, and notify them then.
    // Let's implement it so when John OPENS the app or finishes an exercise, it checks if any friend did an exercise today. If yes, and John hasn't been notified today, show local notification immediately.

    final pairsSnap = await FirebaseFirestore.instance
        .collection('friendPairs')
        .where('uids', arrayContains: currentUid)
        .get();

    for (final doc in pairsSnap.docs) {
      final uids = List<String>.from(doc.data()['uids']);
      final friendUid = uids.firstWhere((id) => id != currentUid);

      final friendDoc = await FirebaseFirestore.instance.collection('users').doc(friendUid).get();
      if (!friendDoc.exists) continue;

      final friendData = friendDoc.data()!;
      if (friendData['overallLastDate'] == today) {
        final fName = friendData['displayName'] ?? 'A friend';
        await NotificationService.instance.showFriendActivityNotification(
          fName,
          'completed their workout today! 👏',
        );

        // Mark as notified
        await userRef.update({'friendActivityNotifiedDate': today});
        return; // Only 1 notification per day
      }
    }
  }
}
